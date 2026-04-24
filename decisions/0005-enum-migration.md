---
# ADR 0005 — Enum Migration from Magic Integer Status Codes

**Status:** Accepted  
**Date:** 2026-04-24  
**Author:** Architecture Team  

---

## Context

The legacy database uses undocumented integer codes throughout:

| Table | Column | Values (from source inspection) |
|---|---|---|
| `Employees` | `Status` | 1=Active, 2=Leave, 3=Terminated, 4=Suspended, 5=Retired |
| `Employees` | `EmploymentType` | 1=FullTime, 2=PartTime, 3=Contractor, 4=Seasonal |
| `PayrollRuns` | `Status` | 1=Draft, 2=Processing, 3=Calculated, 4=Approved, 5=Posted, 6=Voided |
| `PayrollRuns` | `RunType` | 1=Regular, 2=Supplemental, 3=Bonus, 4=Correction |
| `PayPeriods` | `Status` | 1=Open, 2=Processing, 3=Closed, 4=Reopened |
| `PayrollRunDetails` | `Status` | 1=Calculated, 2=Approved, 3=Posted, 4=Voided |
| `TimeEntries` | `Status` | 1=Pending, 2=Approved, 3=Rejected |

Problems:
- The values are only documented in comments scattered through `procedures.sql`. The `Employees.aspx.cs` code-behind manually re-maps them: `status == 1 ? "Active" : status == 2 ? "Leave" : ...`.
- The same mapping exists in stored procedures: `CASE Status WHEN 1 THEN 'Active' WHEN 2 THEN 'Leave' ...` — at least six locations.
- Permitted state transitions are hardcoded as TABLE VALUES in `usp_Employee_UpdateStatus` and validated by comparing integers.
- A developer adding a new status value must find and update every CASE expression across SQL and C#.

---

## Decision

**Replace every magic integer status column with a C# enum in the Domain layer, stored as an integer in the database but mapped by EF Core value converters.**

### Enum definitions (Domain layer)

```csharp
namespace PayrollModern.Domain.Enums;

public enum EmployeeStatus
{
    Active      = 1,
    OnLeave     = 2,
    Terminated  = 3,
    Suspended   = 4,
    Retired     = 5
}

public enum EmploymentType
{
    FullTime    = 1,
    PartTime    = 2,
    Contractor  = 3,
    Seasonal    = 4
}

public enum PayrollRunStatus
{
    Draft       = 1,
    Processing  = 2,
    Calculated  = 3,
    Approved    = 4,
    Posted      = 5,
    Voided      = 6
}

public enum PayrollRunType
{
    Regular         = 1,
    Supplemental    = 2,
    Bonus           = 3,
    Correction      = 4
}

public enum PayPeriodStatus
{
    Open        = 1,
    Processing  = 2,
    Closed      = 3,
    Reopened    = 4
}

public enum PayrollDetailStatus
{
    Calculated  = 1,
    Approved    = 2,
    Posted      = 3,
    Voided      = 4
}

public enum TimeEntryStatus
{
    Pending     = 1,
    Approved    = 2,
    Rejected    = 3
}
```

Integer values are **pinned** to match the legacy database. This allows a side-by-side database migration with no data conversion required — existing rows with `Status = 1` continue to be valid.

### EF Core value conversion

```csharp
// In EmployeeConfiguration.cs
builder.Property(e => e.Status)
    .HasConversion<int>()
    .HasColumnName("Status");
```

EF Core stores the integer and reads it back as the enum automatically.

### State machine enforcement

Permitted transitions move from magic TABLE VALUES in SQL to a method on the entity:

```csharp
// In Employee.cs (Domain)
public Result<Employee> ChangeStatus(EmployeeStatus newStatus, string reason, string changedBy)
{
    var permitted = _allowedTransitions[Status];
    if (!permitted.Contains(newStatus))
        return Result<Employee>.Failure(EmployeeErrors.InvalidStatusTransition);

    StatusHistory.Add(new EmployeeStatusHistory(Status, newStatus, reason, changedBy));
    Status = newStatus;
    return Result<Employee>.Success(this);
}

private static readonly Dictionary<EmployeeStatus, EmployeeStatus[]> _allowedTransitions = new()
{
    [EmployeeStatus.Active]     = [EmployeeStatus.OnLeave, EmployeeStatus.Terminated, EmployeeStatus.Suspended],
    [EmployeeStatus.OnLeave]    = [EmployeeStatus.Active, EmployeeStatus.Terminated],
    [EmployeeStatus.Suspended]  = [EmployeeStatus.Active, EmployeeStatus.Terminated],
    [EmployeeStatus.Retired]    = [EmployeeStatus.Terminated],
    [EmployeeStatus.Terminated] = []
};
```

---

## Consequences

**Positive:**
- Compile-time safety. `employee.Status = 7` is a compiler error; `employee.Status = EmployeeStatus.Active` is obvious.
- All status display strings are generated from `enum.ToString()` or a display attribute; no switch/CASE expressions scattered through the codebase.
- State machine is a domain entity method — unit-testable without a database.
- A new status value requires adding one enum member and updating the transition dictionary in one file; the compiler flags all exhaustive switches that need updating.

**Negative / Trade-offs:**
- New status values must be added to both the C# enum and (if a new integer) a database migration. They cannot be added at runtime via a lookup table.
- Serialised payloads (JSON API responses, reports) that expose integer status codes should also expose the string name to avoid coupling consumers to the integer values. Razor Pages views use `status.ToString()` or display attributes; API responses (future) should include both.

---

## Alternatives Considered

### Option A: Database Lookup Table

Replace magic integers with a `StatusCodes` reference table. The enum values live in the database and are loaded at startup. This allows adding statuses without a deployment.

**Rejected:** Status codes encode business rules (state machine transitions) and domain semantics. They are not configuration data. Putting them in a lookup table moves decision-making authority from the codebase (version-controlled, tested) to the database (mutable at runtime). The set of payroll run statuses is not expected to change frequently; compile-time safety is worth more than runtime extensibility for this use case.

### Option B: String Constants

Replace integers with string constants (`"ACTIVE"`, `"TERMINATED"`) stored in the database. No enum needed; string comparison everywhere.

**Rejected:** String constants have the same "magic value" problem as integers but are worse for storage efficiency and more fragile for comparisons (`"Active"` ≠ `"ACTIVE"`). Enums give compile-time checking that strings cannot.

### Option C: Keep Integers, Add Constants

Leave the database integers unchanged; add C# `const int` values in a static class:

```csharp
public static class EmployeeStatusCodes
{
    public const int Active = 1;
    public const int Terminated = 3;
}
```

**Partially considered:** This eliminates magic numbers at the call site but does not give the type safety of an enum. `int status = EmployeeStatusCodes.Active;` is still just an `int` — it can be passed wherever any `int` is accepted. Enums create a distinct type that cannot be accidentally passed as a different integer status.
