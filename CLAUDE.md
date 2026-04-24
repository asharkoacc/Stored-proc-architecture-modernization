# Payroll Processing — Code Modernization Showcase

This project demonstrates a full before/after code modernization scenario. The **legacy** application is an outdated ASP.NET 4.8 Web Forms + SQL Server system where all business logic lives in T-SQL stored procedures. The **modernized** application will migrate that logic into a clean, layered .NET 10 solution with Razor Views.

---

## Legacy Application

### Architecture

| Layer | Technology | Role |
|---|---|---|
| Presentation | ASP.NET Framework 4.8 Web Forms | Thin shell — UI wiring and `SqlCommand` calls only |
| Data & Logic | SQL Server 2019 stored procedures | All business logic, calculations, validations, and workflows |

### Contents

- **`schema.sql`** — tables, constraints, indexes, and seed data
- **`procedures.sql`** — 40+ T-SQL stored procedures covering:
  - CRUD operations
  - Multi-step business workflows (e.g., payroll run lifecycle)
  - Calculations (tax withholding, deductions, accruals)
  - Validation and status state machines
  - Batch and period-close operations
  - Reporting queries
- **Web Forms project** — 5–8 `.aspx` pages with code-behind `.cs` files calling procs via ADO.NET
- **`README.md`** — database setup and IIS Express run instructions

### Legacy patterns

These are deliberate — they are the modernization targets:

| Pattern | Example Location |
|---|---|
| Business logic duplicated across procs and code-behind | Tax calculation in both `usp_Tax_Calculate` and `PayrollRun.aspx.cs` |
| Dynamic SQL built with string concatenation | `usp_Employee_Search` — SQL injection risk |
| God procedures (200+ lines, multiple responsibilities) | `usp_Payroll_ProcessRun` |
| Missing `TRY/CATCH` and `ROLLBACK` | Several CRUD and batch procs |
| Magic status integers with no documentation | `1=Active`, `2=OnLeave`, `3=Terminated` — inline, undocumented |

---

## Modernized Application

### Architecture

PayrollModern/
├── PayrollModern.Web            # .NET 10 Razor Pages (presentation only)
├── PayrollModern.Application    # Use cases, command/query handlers
├── PayrollModern.Domain         # Entities, value objects, business rules
└── PayrollModern.Infrastructure # EF Core, SQL Server, external services



### Key Changes

| Legacy | Modernized |
|---|---|
| ASP.NET 4.8 Web Forms | .NET 10 Razor Pages |
| All logic in T-SQL stored procedures | Business logic in `Domain` and `Application` layers |
| ADO.NET `SqlCommand` calls in code-behind | EF Core with repository pattern in `Infrastructure` |
| Magic integer status codes | Strongly-typed C# enums |
| No error handling in procs | Structured exceptions with `Result<T>` pattern |
| Dynamic SQL string concatenation | Parameterized queries / LINQ |
| God procedures | Single-responsibility services and domain methods |
| No unit tests possible | Calculation logic fully unit-testable in C# |

### Improvements in Detail

- **Layered architecture** — presentation, application, domain, and infrastructure concerns are separated into distinct projects
- **Domain-driven logic** — payroll calculations, tax withholding, accruals, and validations live as C# domain services and entities, not SQL
- **Modern UI** — Razor Pages with a clean layout; no `<asp:*>` controls or postback model
- **Testability** — business rules are pure C# methods, independently unit-testable without a database
- **Configuration** — `appsettings.json` with secrets management replaces `Web.config`
- **Security** — parameterized queries, HTTPS enforced, PII fields encrypted at rest