---
# ADR 0004 — Error Handling: Result\<T\> Pattern

**Status:** Accepted  
**Date:** 2026-04-24  
**Author:** Architecture Team  

---

## Context

The legacy system has no consistent error handling strategy:

- `usp_Employee_Insert`, `usp_Employee_Update`, `usp_Employee_Terminate`, and several other CRUD procedures have **no TRY/CATCH block**. A constraint violation or arithmetic overflow leaves partially-written data in the database with no rollback.
- `usp_YearEnd_Process` calls `usp_W2_Generate` and then resets YTD fields in a **single procedure with no outer transaction**. If W2 generation fails midway, YTD resets have already been applied — data is permanently inconsistent.
- `usp_PayPeriod_Close` marks the period as closed and then writes to AuditLog; if the audit write fails, the period is already closed with **no audit trail**.
- The Web Forms code-behind wraps every ADO.NET call in a `try/catch (Exception ex)` that displays `ex.Message` to the user, including full stack traces and SQL error text in production (`customErrors mode="Off"` in Web.config).
- `usp_Employee_UpdateStatus` returns `@Result = 0/1/2` (integer result code) as an OUTPUT parameter with no documentation of what each value means. Callers must interpret undocumented magic integers.

The modernized system must distinguish between:
1. **Domain errors** — expected, recoverable, business-rule violations (e.g., "cannot approve a run that has not been calculated", "employee is suspended and cannot be enrolled in payroll").
2. **Infrastructure errors** — unexpected failures (database timeout, network partition, key vault unreachable).
3. **Programming errors** — invariant violations that should never happen in production (null reference, argument out of range).

---

## Decision

**Use a `Result<T>` type for all domain and application-layer return values.** Infrastructure and programming errors propagate as exceptions.

```csharp
// In PayrollModern.Domain
public sealed class Result<T>
{
    public bool IsSuccess { get; }
    public T Value { get; }
    public Error Error { get; }

    public static Result<T> Success(T value) => new(true, value, Error.None);
    public static Result<T> Failure(Error error) => new(false, default, error);
}

public sealed class Error
{
    public static readonly Error None = new(string.Empty, string.Empty);
    public string Code { get; }
    public string Description { get; }
}
```

Rules:
- **Domain services** return `Result<T>`. A failed transition (e.g., `PayrollRun.Approve()` called on a Draft run) returns `Result.Failure(PayrollErrors.RunNotCalculated)` rather than throwing.
- **Application command handlers** return `Result<T>`. MediatR pipeline behaviour validates commands with FluentValidation before the handler executes; validation failures return `Result.Failure` without entering the handler.
- **Razor PageModel classes** inspect the `Result`; on failure they add a `ModelState` error or set a `TempData` error message and redirect.
- **Infrastructure layer** is allowed to throw exceptions (`SqlException`, `HttpRequestException`, etc.) for genuinely exceptional conditions. The Application layer wraps infrastructure calls in try/catch and converts to `Result.Failure(InfrastructureErrors.DatabaseUnavailable)` at the boundary.
- **Exceptions are reserved for programming errors** (`ArgumentNullException`, `InvalidOperationException` for "this should never happen" invariant violations). They are caught by the ASP.NET Core exception middleware, logged, and returned as HTTP 500 with a generic error message (never a stack trace).

---

## Defined Error Catalogue

Errors are strongly-typed constants:

```csharp
public static class PayrollErrors
{
    public static readonly Error RunNotInDraftState =
        new("Payroll.RunNotInDraftState", "Payroll run must be in Draft state to process.");
    public static readonly Error RunNotCalculated =
        new("Payroll.RunNotCalculated", "Payroll run must be Calculated before it can be approved.");
    public static readonly Error RunAlreadyPosted =
        new("Payroll.RunAlreadyPosted", "Cannot modify a posted payroll run.");
    public static readonly Error PeriodNotOpen =
        new("Payroll.PeriodNotOpen", "Pay period must be Open or Reopened to initiate a run.");
    public static readonly Error DuplicateRegularRun =
        new("Payroll.DuplicateRegularRun", "A regular payroll run already exists for this period.");
}

public static class EmployeeErrors
{
    public static readonly Error NotFound = new("Employee.NotFound", "Employee not found.");
    public static readonly Error InvalidStatusTransition =
        new("Employee.InvalidStatusTransition", "The requested status transition is not permitted.");
    public static readonly Error AlreadyTerminated =
        new("Employee.AlreadyTerminated", "Employee is already terminated.");
    public static readonly Error SalaryMustBePositive =
        new("Employee.SalaryMustBePositive", "Annual salary must be greater than zero.");
}
```

---

## Consequences

**Positive:**
- Callers cannot ignore errors. `Result<T>` forces the caller to check `IsSuccess` before accessing `Value`. Exceptions can be silently swallowed; a `Result` cannot.
- Error codes are centralised and documented. No more `@Result = 2` with no documentation.
- Domain and application layers are free of try/catch noise. The error path is explicit and readable.
- Unit tests assert on `Result.Error.Code` directly: `result.Error.Should().Be(PayrollErrors.RunNotCalculated)`.
- Infrastructure errors (DB down, key vault unreachable) are converted to `Result.Failure` at the application boundary, so Razor Pages always receives a typed result — never an unhandled exception from the infrastructure layer.
- Stack traces are never shown to end users. The global exception middleware logs the full trace and returns a generic "An unexpected error occurred" page.

**Negative / Trade-offs:**
- Slightly more code than just throwing exceptions everywhere. Each command handler needs an error-check branch.
- Developers unfamiliar with the pattern need orientation before first contribution.
- `Result<T>` does not compose as naturally as C# exceptions across `await` chains. Developers must use `.Bind()` / `.Map()` helper methods (or check manually) rather than letting exceptions bubble automatically.

---

## Alternatives Considered

### Option A: Exceptions for All Error Paths

Throw `DomainException` (or subclasses) for domain errors and let them bubble to the controller, which catches and maps them to HTTP status codes. This is simpler and familiar to most .NET developers.

**Rejected:** Exceptions are used as control flow, which is expensive and hides intentionality. A business rule violation (invalid status transition) is not "exceptional" — it is an expected path. Additionally, try/catch blocks throughout the legacy system are one of the problems we are fixing; reintroducing them for domain errors recreates the same noise.

### Option B: OneOf / Discriminated Union Library

`OneOf<Success<T>, DomainError, ValidationError, NotFound>` is explicit at the call site and forces exhaustive handling. The `OneOf` NuGet package provides this today.

**Partially adopted:** For queries that can return "not found" (e.g., `GetEmployeeByIdQuery`), the return type is `Result<Employee?>` with `EmployeeErrors.NotFound` for the null case. A full discriminated union is reserved for future consideration if the error taxonomy becomes more complex.

### Option C: FluentValidation + Exceptions

Use FluentValidation for all input validation at the application boundary, throw `ValidationException` on failure, and catch it globally. No `Result<T>` needed.

**Rejected:** Validation only covers input shape (required fields, range checks). Business rules (e.g., "you cannot approve a run that failed calculation") are not input validation — they are state machine transitions. Conflating them produces a `ValidationException` for "you selected an invalid run status transition," which is confusing and loses the distinction between user errors and domain rule violations.
