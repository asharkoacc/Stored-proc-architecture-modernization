# Target State — PII Data Flow and Encryption Map (PayrollModern)

> This document shows how PII fields (primarily Social Security Numbers) flow through  
> the modernized application layers, where encryption is applied, and where access is controlled.

---

## PII Field Classification

| Field | Table | Classification | Treatment |
|---|---|---|---|
| `SSN` | `Employees` | **High** — identity theft risk, regulatory | AES-256-GCM encrypted at application layer |
| `DateOfBirth` | `Employees` | **Medium** — health inference risk | Stored as DATE (plaintext); no search by DOB in queries |
| `FirstName`, `LastName` | `Employees` | **Medium** — name + payroll data combined is sensitive | Stored plaintext; masked in logs |
| `Address1`–`Zip` | `Employees` | **Medium** — home address | Stored plaintext; HTTPS in transit |
| `Email`, `Phone` | `Employees` | **Low–Medium** — contact PII | Stored plaintext; used for notifications |
| `AnnualSalary` | `Employees` | **Medium** — financial PII | Stored plaintext; access-controlled via authorization policy |
| `GrossPay`, `NetPay` | `PayrollRunDetails` | **Medium** — compensation data | Stored plaintext; read access limited to PayrollAdmin role |
| `Box1_Wages` through `Box17_StateTax` | `W2Records` | **Medium** — tax/compensation | Stored plaintext; PayrollAdmin only |

---

## SSN Lifecycle Data Flow

```mermaid
flowchart TD
    subgraph Browser["Browser (HTTPS only — TLS 1.2+)"]
        A[/"HR Admin enters SSN\nin EmployeeDetail form"/]
    end

    subgraph Web["PayrollModern.Web\n(Razor Pages — PageModel)"]
        B["PageModel.OnPostAsync()\nReceives SSN as plain string\nvia model binding.\n⚠️ Never logged.\n⚠️ Never stored in TempData."]
    end

    subgraph Application["PayrollModern.Application\n(Command Handler)"]
        C["HireEmployeeCommandHandler\nHolds SSN as plain string\nin HireEmployeeCommand DTO.\n⚠️ FluentValidation strips SSN\nfrom ValidationFailure messages.\n⚠️ ILogger never receives SSN."]
    end

    subgraph Domain["PayrollModern.Domain\n(Entity)"]
        D["Employee entity created.\nSSN passed to\nEncryptedSSN.Encrypt(ssn, svc).\nReturns EncryptedSSN value object\nholding only ciphertext.\nPlaintext SSN leaves scope here."]
    end

    subgraph Infrastructure["PayrollModern.Infrastructure\n(EncryptionService + EF Core)"]
        E["EncryptionService.Encrypt(plaintext)\n1. Fetch DEK from Key Vault cache\n2. Generate random 12-byte IV\n3. AES-256-GCM encrypt(plaintext, DEK, IV)\n4. Return Base64(IV ∥ Ciphertext ∥ AuthTag)"]
        F["EF Core HasConversion saves\nEncryptedSSN.CiphertextBase64\nto Employees.SSN column\nas NVARCHAR(512) ciphertext."]
    end

    subgraph KeyVault["Azure Key Vault\n(External PaaS)"]
        G["Data Encryption Key (DEK)\nAES-256 secret.\nWrapped by RSA-2048 KEK.\nAccess: App Managed Identity only."]
    end

    subgraph Database["SQL Server\n(PayrollModern DB)"]
        H[("Employees.SSN\nNVARCHAR(512)\nStores: Base64-encoded\nIV ∥ Ciphertext ∥ AuthTag\nNo plaintext ever written.")]
        I[("TDE (Transparent Data Encryption)\nenabled on the database file.\nDefence-in-depth for\nbackup/disk theft scenarios.")]
    end

    A -->|"HTTPS POST — form data\nencrypted in transit"| B
    B -->|"HireEmployeeCommand DTO\n(plain string, in-process)"| C
    C -->|"Plain SSN passed to\ndomain entity constructor"| D
    D -->|"IEncryptionService.Encrypt(ssn)"| E
    E -->|"GetSecret(DEK-name)"| G
    G -->|"DEK (cached 5 min)"| E
    E -->|"Returns EncryptedSSN"| D
    D -->|"Employee with EncryptedSSN\nsaved via IEmployeeRepository"| F
    F -->|"EF Core UPDATE/INSERT"| H
    H -.->|"TDE protects files on disk"| I

    style A fill:#fff3cd
    style H fill:#d4edda
    style G fill:#cce5ff
    style I fill:#e2e3e5
```

---

## SSN Read / Decrypt Flow

```mermaid
flowchart TD
    subgraph Trigger["Access Trigger"]
        A[/"HR Admin views\nEmployee Detail page\n(individual employee only)"/]
    end

    subgraph AuthLayer["ASP.NET Core Authorization"]
        B["[Authorize(Policy = 'HRAdmin')]\nCheck: user has HRAdmin role claim.\nIf not: HTTP 403 Forbidden.\nSSN never loaded."]
    end

    subgraph Web["PayrollModern.Web"]
        C["GetEmployeeByIdQueryHandler dispatched.\nPageModel receives EmployeeDetailDto.\nSSN field: displayed masked\nas XXX-XX-NNNN by default.\nFull SSN shown only on explicit\n'Reveal SSN' action (separate auth check)."]
    end

    subgraph Application["PayrollModern.Application"]
        D["GetEmployeeByIdQueryHandler.\nLoads Employee entity from repo.\nEmployee.Ssn is EncryptedSSN object\n(ciphertext only at this point)."]
    end

    subgraph Infrastructure["PayrollModern.Infrastructure"]
        E["EF Core reads Employees.SSN column\n→ EncryptedSSN.FromCiphertext(value)\nCiphertext is in EncryptedSSN object.\nNOT yet decrypted."]
        F["Only when DecryptSsn() explicitly called:\nEncryptedSSN.Decrypt(encryptionSvc)\n→ IEncryptionService.Decrypt(ciphertext)\n→ AES-256-GCM verify AuthTag + decrypt\n→ Returns plaintext SSN string"]
    end

    subgraph Logging["Logging & Audit"]
        G["AuditLog entry written:\n'SSN viewed for EmployeeId=X\nby User=Y at DateTime=Z'\nPlaintext SSN NOT in log.\nIP address logged."]
    end

    A --> B
    B -->|"Authorized"| C
    C --> D
    D --> E
    E -->|"Lazy — ciphertext only"| D
    D -->|"EmployeeDetailDto\n(SSN = masked string)"| C
    C -->|"Reveal SSN click\n→ explicit decrypt request"| F
    F -->|"Plaintext SSN (in-memory only,\nnever written back to DB)"| C
    C -->|"Audit access event"| G

    style A fill:#fff3cd
    style G fill:#f8d7da
    style F fill:#cce5ff
```

---

## PII Boundary Controls by Layer

```mermaid
flowchart LR
    subgraph External["External Boundary\n(Internet → Server)"]
        TLS["TLS 1.2+ (HTTPS)\nAll traffic encrypted in transit.\nHSTS header enforced.\nNo HTTP fallback."]
    end

    subgraph WebLayer["Web Layer\nPayrollModern.Web"]
        NoPII["PII fields:\n• Not logged (middleware filter)\n• Not in URL parameters\n• Not in TempData\n• Error pages show no field values\n• ModelState errors for SSN\n  use generic 'Invalid SSN format'"]
    end

    subgraph AppLayer["Application Layer\nPayrollModern.Application"]
        Commands["Commands/Queries:\n• SSN in command DTO is plain string\n• FluentValidation strips PII from\n  failure message text\n• ILogger injected never receives SSN\n• MediatR pipeline logs Command type\n  but not Command properties"]
    end

    subgraph DomainLayer["Domain Layer\nPayrollModern.Domain"]
        EncObj["EncryptedSSN value object:\n• Constructed by Encrypt() only\n• Ciphertext is the only\n  stored representation\n• Decrypt() is explicit call\n• ToString() returns '***'"]
    end

    subgraph InfraLayer["Infrastructure Layer\nPayrollModern.Infrastructure"]
        EFCore["EF Core:\n• SSN saved as ciphertext NVARCHAR(512)\n• EF query log level = Warning\n  (parameter values not logged)\n• Migrations never contain SSN data\n\nEncryptionService:\n• DEK never logged\n• IV randomized per encrypt call\n• AuthTag validates ciphertext integrity"]
    end

    subgraph DBLayer["Database Layer\nSQL Server"]
        DBControls["• SSN column: encrypted ciphertext only\n• TDE: database files encrypted at rest\n• Minimal permissions: app login\n  has no sysadmin role\n• Managed Identity auth (no passwords)\n• Audit log: access tracked\n  without storing plaintext PII"]
    end

    TLS --> WebLayer
    WebLayer --> AppLayer
    AppLayer --> DomainLayer
    DomainLayer --> InfraLayer
    InfraLayer --> DBLayer
```

---

## Encryption Key Hierarchy

```mermaid
flowchart TD
    KEK["Key Encryption Key (KEK)\nRSA-2048\nStored in Azure Key Vault HSM\nRotated annually\nAccess: Key Vault Administrator role only"]

    DEK["Data Encryption Key (DEK)\nAES-256\nStored as Azure Key Vault Secret\nWrapped (encrypted) by KEK\nAccess: App Managed Identity (GET only)\nCached in-process for 5 minutes"]

    SSN1["Employees.SSN row 1\nBase64(IV₁ ∥ AES-GCM(DEK, IV₁, SSN₁))"]
    SSN2["Employees.SSN row 2\nBase64(IV₂ ∥ AES-GCM(DEK, IV₂, SSN₂))"]
    SSNN["Employees.SSN row N\nBase64(IVₙ ∥ AES-GCM(DEK, IVₙ, SSNₙ))"]

    KEK -->|"Wraps (encrypts)"| DEK
    DEK -->|"Encrypts with unique IV per row"| SSN1
    DEK -->|"Encrypts with unique IV per row"| SSN2
    DEK -->|"Encrypts with unique IV per row"| SSNN

    note1["Key Rotation:\n• KEK rotation: re-wraps DEK only\n  (no row re-encryption needed)\n• DEK rotation: re-encrypts all SSN rows\n  (run as background migration job)\n  Planned annually"]

    note1 -.-> DEK

    style KEK fill:#cce5ff
    style DEK fill:#d4edda
    style SSN1 fill:#fff3cd
    style SSN2 fill:#fff3cd
    style SSNN fill:#fff3cd
```

---

## What Does NOT Flow to the Database in Plaintext

| Data | Plaintext in Legacy | Plaintext in Modern |
|---|---|---|
| SSN | Yes (`VARCHAR(11)`) | No — AES-256-GCM ciphertext in `NVARCHAR(512)` |
| Date of Birth | Yes | Yes (plaintext — no current mandate to encrypt) |
| Salary | Yes | Yes (access-controlled via authorization) |
| Stack traces | Yes (via customErrors=Off) | No — generic error page; traces to server logs only |
| Tax calculation inputs | Visible in SQL Profiler | Parameterized — parameter values not in EF log at Warning level |
| SSN in application logs | Possible (no filtering) | No — `ILogger` calls never receive SSN; middleware filter as backstop |
