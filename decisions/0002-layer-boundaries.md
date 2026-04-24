---
# ADR 0002 — Clean Architecture Layer Boundaries

**Status:** Accepted  
**Date:** 2026-04-24  
**Author:** Architecture Team  

---

## Context

The legacy system has no layers. All business logic lives in 49 T-SQL stored procedures; the ASP.NET Web Forms code-behind files call those procedures directly via ADO.NET. The result is:

- Logic is impossible to unit-test (requires a live SQL Server database).
- Tax calculation is duplicated across `usp_Tax_CalculateFederal`, `usp_Payroll_ProcessRun` (inline), and `EmployeeDetail.aspx.cs` (`CalculateEstimatedTax()`). A tax bracket change must be made in at least three places.
- A UI change can accidentally alter business behavior (e.g., the 80-hour overtime cap hardcoded in `PayrollRun.aspx.cs`).
- There is no defined contract between "what the system does" (use cases) and "how it does it" (SQL, HTTP, file I/O).

The modernized solution must allow the domain rules (payroll calculation, tax computation, accrual logic) to be tested in isolation, without a database, without HTTP, and without any third-party dependency.

---

## Decision

**Adopt Clean Architecture** with four projects corresponding to the four concentric rings:

| Project | Ring | Dependency rule |
|---|---|---|
| `PayrollModern.Domain` | Innermost | No references to any other project; no NuGet dependencies except primitives |
| `PayrollModern.Application` | Use-case ring | References Domain only; defines interfaces (ports) for Infrastructure |
| `PayrollModern.Infrastructure` | Adapter ring | References Application and Domain; implements all interfaces (EF Core, external services) |
| `PayrollModern.Web` | Outermost | References Application only (never Infrastructure directly); all wiring via DI container |

The **Dependency Rule** is enforced by project references: inner rings cannot reference outer rings. Infrastructure depends on Application; Application depends on Domain. Web depends on Application. No project knows about the one outside it.

---

## Consequences

**Positive:**
- Domain entities (`Employee`, `PayrollRun`, `TaxBracket`) and domain services (`PayrollCalculationService`, `TaxCalculationService`) can be tested with plain `dotnet test` — no database, no HTTP server.
- Swapping Infrastructure implementations (SQL Server → PostgreSQL; real tax brackets → stub) requires changing only `Program.cs` DI wiring and the Infrastructure project.
- Use-case logic lives in Application command/query handlers (MediatR). A handler has explicit inputs, explicit outputs, and no hidden side effects via global state.
- The Application layer defines interfaces (`IEmployeeRepository`, `ITaxBracketRepository`) that are owned by the domain/application side. Infrastructure implements them. This inverts the legacy dependency where the database owned the rules.

**Negative / Trade-offs:**
- More projects than a flat solution; developers must know which layer owns what.
- CRUD-only operations (lookup data with no business rules) require the same ceremony as complex domain operations. This verbosity is acceptable given it enables a consistent contribution model.
- Initial scaffolding takes longer than a traditional 3-tier MVC project.

---

## Layer Responsibilities

### Domain (`PayrollModern.Domain`)
- **Entities:** `Employee`, `PayrollRun`, `PayrollRunDetail`, `PayPeriod`, `TimeEntry`, `EmployeeDeduction`
- **Value Objects:** `Money`, `EmployeeStatus`, `FilingStatus`, `EncryptedSSN`
- **Domain Services:** `PayrollCalculationService`, `TaxCalculationService`, `OvertimeCalculator`, `AccrualCalculationService`
- **Domain Events:** `PayrollRunPostedEvent`, `EmployeeTerminatedEvent`
- **Enums:** `EmployeeStatusCode`, `PayrollRunStatus`, `RunType`, `PayPeriodStatus`, `EmploymentType`
- **Rules:** No entity may transition to an invalid state; domain services enforce invariants and throw `DomainException`.

### Application (`PayrollModern.Application`)
- **Commands:** `InitiatePayrollRunCommand`, `ProcessPayrollRunCommand`, `ApprovePayrollRunCommand`, `PostPayrollRunCommand`, `TerminateEmployeeCommand`, etc.
- **Queries:** `GetEmployeeListQuery`, `GetPayrollRunDetailsQuery`, `GetPayrollSummaryReportQuery`, etc.
- **Handlers:** One handler per command/query (MediatR `IRequestHandler<,>`).
- **Interfaces (Ports):** `IEmployeeRepository`, `IPayrollRunRepository`, `ITaxBracketRepository`, `IDeductionRepository`, `IUnitOfWork`, `IEncryptionService`
- **DTOs:** `EmployeeDto`, `PayrollRunSummaryDto`, `PayrollRunDetailDto`
- **No framework references** beyond MediatR and FluentValidation.

### Infrastructure (`PayrollModern.Infrastructure`)
- EF Core `DbContext` (`PayrollDbContext`), entity configurations, migrations.
- Repository implementations: `EfEmployeeRepository`, `EfPayrollRunRepository`, etc.
- `EncryptionService` (AES-256-GCM + Azure Key Vault).
- `UnitOfWork` wrapping `DbContext.SaveChangesAsync()`.
- Any future external integrations (ACH file export, email notifications).

### Web (`PayrollModern.Web`)
- Razor Pages (`Index.cshtml`, `Employees/Index.cshtml`, `Payroll/Run.cshtml`, etc.)
- PageModel classes dispatch to MediatR; no business logic inline.
- Tag helpers, layout, CSS/JS bundles.
- `Program.cs`: DI composition root, middleware pipeline, authentication configuration.

---

## Alternatives Considered

### Option A: Traditional 3-Tier (Presentation / Business / Data)

Classic N-tier with a `BusinessLogicLayer` project calling a `DataAccessLayer`. This is an improvement over the current 1-tier approach but does not invert the dependency. The BLL ends up referencing data-transfer objects from the DAL, coupling them at the type level. Testing the BLL still requires a running database unless you add mocking everywhere.

**Rejected:** Does not achieve the testability goal cleanly; leads back to the same coupling over time.

### Option B: Modular Monolith with Vertical Slices

Each feature (Employee, Payroll, Accruals) is a self-contained slice with its own controller, service, and repository in one folder. Minimal shared infrastructure. CQRS is optional per slice.

This is a valid pattern — easier to navigate for small teams and evolves more naturally into microservices. However, it does not enforce the dependency rule at the compiler level; discipline alone keeps business logic out of the HTTP layer.

**Considered:** We will adopt vertical slices *within* Clean Architecture layers (each feature has its own command/handler/validator folder inside Application) to get both benefits.

### Option C: Microservices from Day One

Extract Employee, Tax, Payroll, and Accruals into separate deployable services immediately. This matches the long-term decomposition target.

**Rejected for v1:** The monolith seams are not yet proven. Distributed transactions across services (payroll posting must update both `PayrollRuns` and `Employees.YTD` atomically) are significantly harder to manage without shared infrastructure. Start as a clean modular monolith; extract services once the boundaries are stable. See ADR 0007 for decomposition plan.
