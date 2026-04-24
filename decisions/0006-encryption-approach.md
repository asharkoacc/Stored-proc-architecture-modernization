---
# ADR 0006 — PII Encryption Approach

**Status:** Accepted  
**Date:** 2026-04-24  
**Author:** Architecture Team  

---

## Context

The legacy `Employees` table stores Social Security Numbers in a `VARCHAR(11)` column as plain text (`123-45-6789`). There is no encryption at the column, row, or application level. The `Web.config` uses Windows Integrated Security for the database connection — any user with SQL Server read access can query SSNs directly.

Other PII fields that require protection:
- `DateOfBirth` (DATE) — health-related inference risk
- `Address1`, `Address2`, `City`, `StateAddr`, `Zip` — home address
- `Email`, `Phone` — contact PII

Applicable requirements:
- **SOC 2 Type II readiness** — PII must be protected at rest.
- **Internal policy** — SSN must not appear in application logs, error messages, or debug output.
- **SQL injection risk** — `usp_Employee_Search` is vulnerable to SQL injection (ADR 0007). Until the legacy app is fully retired, an attacker who exploits that vulnerability must not obtain plaintext SSNs.
- **Database access control** — DBAs and support personnel access the database directly. Plaintext SSNs are visible to anyone with `SELECT` permission on `Employees`.

---

## Decision

**Apply application-level authenticated encryption (AES-256-GCM) to the SSN field, managed through an `IEncryptionService` in the Application layer with key material sourced from Azure Key Vault (production) or environment variables / DPAPI (local development).**

### What is encrypted

| Field | Level | Rationale |
|---|---|---|
| `Employees.SSN` | **Encrypted** (AES-256-GCM) | High-value PII; regulatory risk if exposed |
| `Employees.DateOfBirth` | Stored as-is (DATE) | Low marginal risk; needed for payroll tax calculations; no direct compliance mandate |
| `Employees.Address*` | Stored as-is | Address data is lower sensitivity; encrypt if compliance scope expands |
| `Employees.Email` | Stored as-is | Used for notifications; must be readable in plaintext |
| `W2Records.*` | Not encrypted | Aggregate numbers; no direct PII beyond EmployeeId FK |

The SSN column in the database is changed to `VARBINARY(256)` (or `NVARCHAR(512)` for base-64 encoded ciphertext). The column stores: `Base64(IV || Ciphertext || AuthTag)`.

### Architecture

```
Web Layer (PageModel)
  │  Receives SSN as string from user input (HTTPS only)
  │
Application Layer (Command Handler)
  │  Passes SSN to Domain as-is inside command DTO
  │  Never logs SSN; FluentValidation strips it from error messages
  │
Infrastructure Layer (IEncryptionService impl)
  │  EncryptionService.Encrypt(plaintext) → EncryptedValue
  │  EncryptionService.Decrypt(encryptedValue) → plaintext
  │  Calls Azure Key Vault to retrieve the data encryption key (DEK)
  │  Key Vault caches the key in memory for 5 minutes
  │
Database
     Employees.SSN stored as NVARCHAR(512) with base-64 encoded AES-256-GCM ciphertext
```

### Key hierarchy

```
Azure Key Vault
  └── Key Encryption Key (KEK) — RSA 2048, rotated annually
        └── Data Encryption Key (DEK) — AES-256, wrapped by KEK
              └── Encrypted SSN values
```

The DEK is stored in Azure Key Vault as a secret. The infrastructure `EncryptionService` fetches the DEK on startup (or on cache miss) and uses it for AES-256-GCM operations. If the KEK is rotated, the DEK is re-wrapped without re-encrypting every row.

### Local development / CI

For local development and CI, the DEK is provided as an environment variable (`PAYROLL_ENCRYPTION_KEY`). The `IEncryptionService` implementation is the same; only the key source differs. No real SSN data is used in development.

### EF Core integration

```csharp
// EncryptedSSN value object
public sealed class EncryptedSSN
{
    public string CiphertextBase64 { get; }

    public static EncryptedSSN Encrypt(string plainSsn, IEncryptionService svc)
        => new(svc.Encrypt(plainSsn));

    public string Decrypt(IEncryptionService svc)
        => svc.Decrypt(CiphertextBase64);
}

// Entity configuration
builder.Property(e => e.Ssn)
    .HasConversion(
        v => v.CiphertextBase64,
        v => EncryptedSSN.FromCiphertext(v))
    .HasColumnName("SSN")
    .HasMaxLength(512);
```

Decryption happens only when code explicitly calls `.Decrypt(encryptionService)`. The SSN ciphertext is never logged by EF Core (it logs parameterised values, not decrypted strings).

### Access policy

- The `IEncryptionService` is only available in the Infrastructure layer. Razor Pages never call it directly.
- Access to the Azure Key Vault DEK secret is restricted to the application's managed identity. DBAs do not have Key Vault access.
- A separate read-only Azure Key Vault role is defined for the payroll reconciliation process (W-2 generation). This role has `GET` but not `LIST` or `DELETE`.

---

## Consequences

**Positive:**
- A direct SQL query on `Employees.SSN` returns ciphertext, not plaintext. A SQL injection exploit yields only base64-encoded, encrypted bytes.
- SSNs are never present in application logs, EF Core query logs, or exception messages.
- Key rotation does not require re-encrypting every row — only the DEK wrapper in Key Vault is re-encrypted with the new KEK.
- The `IEncryptionService` abstraction can be swapped for a different provider (AWS KMS, HashiCorp Vault) without changing Domain or Application code.

**Negative / Trade-offs:**
- SSN cannot be used in a SQL `WHERE` clause for lookup. If searching by SSN is required, encrypt the search term and compare ciphertexts — only works with **deterministic** encryption (using a fixed IV), which is weaker than probabilistic AES-GCM.
  - **Decision:** SSN is never a search key in the application. Employees are looked up by `EmployeeNumber` or name. If SSN lookup is needed (e.g., duplicate-check on hire), a separate deterministic-encrypted hash column (`SSNHash` — HMAC-SHA256 of SSN) will be added for indexing without exposing the plaintext.
- Performance: decrypt on every `Employee` read. Mitigated by not decrypting in list queries; only decrypt in single-employee detail views.
- Local development requires either a shared DEK or a mock `IEncryptionService` that returns plaintext (only for local; never in staging/production).

---

## Alternatives Considered

### Option A: Transparent Data Encryption (TDE)

TDE encrypts the database files on disk. It is transparent to the application — no code changes needed. SQL Server Enterprise / Standard supports TDE natively.

**Rejected as sole control:** TDE protects against physical disk theft or backup file access. It does **not** protect against:
- SQL injection — an attacker using the application's own DB connection sees plaintext.
- DBA / admin access — anyone with `SELECT` on `Employees` sees plaintext.
- Application log leakage — if SSN is ever concatenated into a log message, TDE provides no help.

**TDE is still enabled** as a defence-in-depth measure alongside application-level encryption.

### Option B: SQL Server Column-Level Encryption (Always Encrypted)

SQL Server Always Encrypted (AE) encrypts column data such that the key never leaves the client. The database never sees plaintext; the column master key is stored in Windows Certificate Store or Azure Key Vault.

**Considered seriously:** Always Encrypted provides strong guarantees and is well-supported by the SQL Server .NET driver. Key concerns:
- AE has limitations: encrypted columns cannot be used in `GROUP BY`, `ORDER BY`, or `JOIN` without deterministic encryption. Several payroll report queries join on employee data.
- AE requires specific driver version and connection string settings (`Column Encryption Setting=Enabled`). This couples the infrastructure to SQL Server in a way that complicates future database portability.
- AE's key management (CMK → CEK hierarchy) is more complex to rotate than a Key Vault DEK.

**Rejected in favour of application-level encryption** due to query flexibility constraints. If the compliance scope expands to require Always Encrypted, it can be layered on top.

### Option C: No Encryption — Access Controls Only

Rely on Windows Integrated Security, SQL Server row-level security, and network segmentation to prevent unauthorised SSN access. No encryption.

**Rejected:** Access control is a necessary but insufficient control. It is bypassable by SQL injection, credential theft, or insider threat. Defence-in-depth requires encryption so that even if access control is breached, the data remains unreadable.
