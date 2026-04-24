# Current State — Anti-Pattern Inventory (PayrollLegacy)

Every entry below is a deliberate modernization target. Each one has an exact file and location reference.

---

## AP-01 — God Procedure: `usp_Payroll_ProcessRun`

**File:** `PayrollLegacy/Database/procedures.sql` — approximately lines 1138–1378  
**Severity:** Critical  
**Pattern:** Single stored procedure with 260+ lines and six distinct responsibilities.

**Responsibilities bundled inside one proc:**
1. Validate run state (must be Draft or Calculated)
2. Mark run as Processing
3. Loop over all active/on-leave employees (implicit cursor)
4. Calculate earnings, deductions, and taxes per employee (inline — duplicates three other procs)
5. Update vacation and sick accrual balances (inline — duplicates `usp_Accrual_ProcessVacation`)
6. Aggregate run-level totals and mark run as Calculated

**Impact:** A bug in any one responsibility requires understanding all six. Impossible to unit-test individual concerns. Adding a new earnings type requires editing this proc in at least two places. A 5-minute HTTP timeout is needed because of the sequential cursor over 20+ employees.

**Modernization target:** `ProcessPayrollRunCommandHandler` (Application layer) dispatches work to `PayrollCalculationService`, `TaxCalculationService`, `DeductionCalculationService`, and `AccrualCalculationService` (Domain layer) as independent, unit-testable C# classes.

---

## AP-02 — SQL Injection: `usp_Employee_Search`

**File:** `PayrollLegacy/Database/procedures.sql` — dynamic SQL construction block  
**Severity:** Critical  
**Pattern:** Dynamic SQL string built with direct concatenation of the `@SearchTerm` parameter.

```sql
-- Simplified excerpt from usp_Employee_Search
DECLARE @SQL NVARCHAR(MAX) = N'SELECT e.EmployeeId, e.FirstName ... WHERE 1=1 '
IF @SearchTerm IS NOT NULL
    SET @SQL = @SQL + N' AND (e.FirstName LIKE ''%' + @SearchTerm + N'%''
                         OR e.LastName  LIKE ''%' + @SearchTerm + N'%''
                         OR e.EmployeeNumber LIKE ''%' + @SearchTerm + N'%'')'
EXEC(@SQL)
```

A search term of `%'; DROP TABLE Employees; --` would execute arbitrary SQL. The `Employees` table contains plaintext SSNs — a successful injection leaks all PII in the database.

**Second injection site:** `PeriodClose.aspx.cs` — `btnViewW2_Click()` method, line 146:
```csharp
"FROM W2Records w JOIN Employees e ... WHERE w.TaxYear = " + year + " ORDER BY ..."
```
The `year` variable comes from a dropdown but is cast from a string — if the dropdown is manipulated or a future developer adds a free-text input here, this becomes exploitable.

**Modernization target:** LINQ queries via EF Core are parameterized by default. `PayrollDbContext.Employees.Where(e => e.LastName.Contains(term))` generates `WHERE LastName LIKE @p0` with a properly escaped parameter.

---

## AP-03 — Business Logic Duplicated Across Layers: Tax Calculation

**File 1:** `PayrollLegacy/Database/procedures.sql` — `usp_Tax_CalculateFederal` and `usp_Tax_CalculateState`  
**File 2:** `PayrollLegacy/Database/procedures.sql` — `usp_Payroll_ProcessRun` (inline, approximately lines 1279–1310)  
**File 3:** `PayrollLegacy/PayrollWeb/PayrollWeb/EmployeeDetail.aspx.cs` — `CalculateEstimatedTax()` method, lines 199–256  
**Severity:** High  
**Pattern:** Federal and state tax bracket logic exists in three separate locations. Any change to tax rates, brackets, or filing status logic must be applied to all three, or the UI estimate and the actual payroll calculation will diverge silently.

**EmployeeDetail.aspx.cs excerpt (lines 213–232):**
```csharp
if (filing == "Single")
{
    if      (salary <= 11600)  annualFed = salary * 0.10m;
    else if (salary <= 47150)  annualFed = 1160m  + (salary - 11600)  * 0.12m;
    else if (salary <= 100525) annualFed = 5426m  + (salary - 47150)  * 0.22m;
    else if (salary <= 191950) annualFed = 17168.50m + (salary - 100525) * 0.24m;
    else if (salary <= 243725) annualFed = 39110.50m + (salary - 191950) * 0.32m;
    else if (salary <= 609350) annualFed = 55678.50m + (salary - 243725) * 0.35m;
    else                        annualFed = 183647.25m + (salary - 609350) * 0.37m;
}
```

The state rate mapping immediately below (lines 236–246) also hardcodes CA, NY, TX, FL, WA, IL, GA, OH flat rates — identical to `StateTaxRates` data in the database.

**Modernization target:** Single `TaxCalculationService` in the Domain layer. Tax bracket data lives in the database (already modelled correctly as `FederalTaxBrackets` and `StateTaxRates` tables). The service reads brackets once (cacheable for a tax year) and performs the calculation. No duplication across layers.

---

## AP-04 — Magic Integer Status Codes

**File:** `PayrollLegacy/Database/schema.sql`, `procedures.sql`, and all `.aspx.cs` files  
**Severity:** High  
**Pattern:** Integer codes used for status, type, and category columns with no enum, no lookup table, and no documentation at point of use.

**Complete inventory:**

| Table.Column | Values (decoded from source) | Locations where decoded |
|---|---|---|
| `Employees.Status` | 1=Active, 2=Leave, 3=Terminated, 4=Suspended, 5=Retired | `usp_Employee_*` (6 procs), `Employees.aspx.cs` (manual switch), `Default.aspx.cs` |
| `Employees.EmploymentType` | 1=FT, 2=PT, 3=Contractor, 4=Seasonal | `usp_Payroll_ProcessRun`, `usp_Accrual_ProcessVacation` |
| `PayrollRuns.Status` | 1=Draft, 2=Processing, 3=Calculated, 4=Approved, 5=Posted, 6=Voided | `usp_Payroll_*` (5 procs), `PayrollRun.aspx.cs` |
| `PayrollRuns.RunType` | 1=Regular, 2=Supplemental, 3=Bonus, 4=Correction | `usp_Payroll_InitiateRun` |
| `PayPeriods.Status` | 1=Open, 2=Processing, 3=Closed, 4=Reopened | `usp_PayPeriod_*` (3 procs), `PeriodClose.aspx.cs` |
| `PayrollRunDetails.Status` | 1=Calculated, 2=Approved, 3=Posted, 4=Voided | `usp_Payroll_ApproveRun`, `usp_Payroll_PostRun`, `usp_Payroll_VoidRun` |
| `TimeEntries.Status` | 1=Pending, 2=Approved, 3=Rejected | `usp_TimeEntry_Approve`, `usp_Payroll_ProcessRun` |

**Modernization target:** C# enums with integer values pinned to match legacy database (no data migration needed). State transition logic moves to domain entity methods. See ADR 0005.

---

## AP-05 — Missing TRY/CATCH and ROLLBACK in CRUD Procedures

**File:** `PayrollLegacy/Database/procedures.sql`  
**Severity:** Medium–High  
**Affected procedures:** `usp_Employee_Insert`, `usp_Employee_Update`, `usp_Employee_Terminate`, `usp_TimeEntry_Insert`

**Pattern:** Multi-step INSERT/UPDATE operations with no error handling. A constraint violation mid-procedure leaves partial data written with no rollback.

**usp_Employee_Insert example (no TRY/CATCH):**
```sql
-- Inserts employee row
INSERT INTO Employees (EmployeeNumber, FirstName, ...) VALUES (@EmployeeNumber, @FirstName, ...)
SET @NewEmployeeId = SCOPE_IDENTITY()

-- Then inserts audit log row — if this fails, employee record already committed
INSERT INTO AuditLog (TableName, RecordId, Action, ...) VALUES ('Employees', @NewEmployeeId, 'INSERT', ...)
```

**usp_YearEnd_Process (no outer transaction):**
```sql
EXEC usp_W2_Generate @TaxYear, @ProcessedBy   -- Step 1: generates W2 records
-- If this succeeds but step 2 fails:
UPDATE Employees SET YTDGross = 0, YTDFederalTax = 0, ...  -- Step 2: resets YTD
UPDATE Employees SET VacationBalance = MIN(VacationBalance, 240) -- Step 3: caps vacation
-- W2 exists but YTD not reset — permanently inconsistent state
```

**usp_PayPeriod_Close (no transaction):**
```sql
UPDATE PayPeriods SET Status = 3 WHERE PayPeriodId = @PayPeriodId
INSERT INTO AuditLog (...) VALUES (...)  -- If this fails, period is closed but unaudited
```

**Modernization target:** EF Core's `SaveChangesAsync()` wraps all changes in a single database transaction. The `IUnitOfWork` pattern ensures either all changes commit or none do. Year-end processing uses a single `await unitOfWork.CommitAsync()` at the end of the command handler.

---

## AP-06 — Business Rule Hardcoded in Presentation Layer

**File:** `PayrollLegacy/PayrollWeb/PayrollWeb/PayrollRun.aspx.cs` — line 14  
**Severity:** Medium  
**Pattern:** A business rule constant defined in the UI code-behind, not enforced at the data layer.

```csharp
// PayrollRun.aspx.cs, line 14
private const int MaxOvertimeHoursPerPeriod = 80;  // Business rule in UI layer, not enforced
```

This constant is declared but not used for validation in the code-behind. No stored procedure validates overtime hours against this limit. An HR administrator entering time via a different UI (or directly via SQL) is not constrained.

**Modernization target:** Overtime limit enforced as a domain invariant in `TimeEntry` entity validation. `PayGrade.OvertimeEligible` is already modelled; the cap moves to `TimeEntryValidator` in the Application layer.

---

## AP-07 — Magic Numbers in Accrual Calculations

**File:** `PayrollLegacy/Database/procedures.sql` — `usp_Accrual_ProcessVacation` and `usp_Payroll_ProcessRun` (inline accrual section)  
**Severity:** Medium  
**Pattern:** Vacation accrual tiers and sick accrual rate hardcoded as literals with no configuration table.

```sql
-- From usp_Accrual_ProcessVacation (approximate structure):
SET @AccrualHours =
    CASE
        WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 10 THEN 6.15   -- 160 hrs/year
        WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 5  THEN 4.62   -- 120 hrs/year
        WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 2  THEN 3.08   --  80 hrs/year
        ELSE                                                   1.54   --  40 hrs/year
    END

-- Sick accrual (usp_Accrual_ProcessSickTime):
SET @SickHours = 1.54    -- 40 hrs/year, everyone

-- Year-end vacation cap (usp_YearEnd_Process):
UPDATE Employees SET VacationBalance = CASE WHEN VacationBalance > 240 THEN 240 ...
```

The same magic numbers appear **a second time** inside `usp_Payroll_ProcessRun`, where accrual is calculated inline.

**Modernization target:** `AccrualPolicy` value object in the Domain layer reads tiers from an `AccrualPolicies` configuration table (or appSettings.json for initial migration). Magic numbers eliminated; policy changes are configuration changes, not code deployments.

---

## AP-08 — Duplicate Status-Label Mapping in C# and SQL

**File 1:** `PayrollLegacy/PayrollWeb/PayrollWeb/Employees.aspx.cs` — lines 62–72  
**File 2:** `PayrollLegacy/Database/procedures.sql` — `usp_Employee_GetAll` CASE expression  
**Severity:** Medium  
**Pattern:** The C# code-behind manually decodes `Status` integers to strings after receiving them from the stored procedure — even though the stored procedure also includes a `StatusLabel` computed column.

```csharp
// Employees.aspx.cs lines 62–72
dt.Columns.Add("StatusLabel", typeof(string));
foreach (DataRow row in dt.Rows)
{
    int status = Convert.ToInt32(row["Status"]);
    row["StatusLabel"] = status == 1 ? "Active"
        : status == 2 ? "Leave"
        : status == 3 ? "Terminated"
        : status == 4 ? "Suspended" : "Unknown";
}
```

Stored proc already includes: `CASE e.Status WHEN 1 THEN 'Active' WHEN 2 THEN 'Leave' ...`

Two sources of truth for the same label. A new status value (e.g., 6=Furloughed) requires updating both the SQL CASE and the C# conditional chain.

**Modernization target:** C# enum `EmployeeStatus` with `[Display(Name = "On Leave")]` attributes (or a `DisplayNameAttribute`). `enum.GetDisplayName()` extension method used everywhere labels are needed. Single definition; no duplication.

---

## AP-09 — Incomplete W-2 Calculation

**File:** `PayrollLegacy/Database/procedures.sql` — `usp_W2_Generate`, approximately lines 1785–1802  
**Severity:** Medium (compliance risk)  
**Pattern:** W-2 Box values calculated incorrectly due to missing deduction subtraction and wage base cap.

**Known bugs:**
- **Box 1 (Wages):** Set to `YTDGross` — should be `YTDGross − PreTaxDeductions (401k, HSA, health insurance)`. Pre-tax deductions reduce Box 1 wages; the current formula overstates taxable wages.
- **Box 3 (Social Security wages):** Set to `YTDGross` — should cap at $168,600 (2024 Social Security wage base). High-earner W-2s are incorrect.
- **Box 12a (401k contributions):** Calculated inline with an approximation formula: `SUM(CASE WHEN IsPercentage=1 THEN YTDGross * Amount / 100 ELSE Amount * 26 END)`. This formula assumes everyone has 26 pay periods and that percentage-based deductions apply to total YTD gross rather than taxable gross per period.

**Modernization target:** W-2 generation reads from `PayrollRunDetails` (actual per-period deductions) rather than denormalized YTD fields. Wage base caps are domain constants in `TaxConstants.cs`. Pre-tax deductions are tracked per-period in `PayrollRunDetails.PreTaxDeductions`.

---

## AP-10 — Tax Liability Report Bug

**File:** `PayrollLegacy/Database/procedures.sql` — `usp_Report_TaxLiability`, approximately lines 1915–1917  
**Severity:** Medium (incorrect report output)  
**Pattern:** Employer FICA amounts in the report use the same column aliases as employee amounts, and the total liability formula assumes 1:1 employer/employee matching.

```sql
-- Approximate excerpt from usp_Report_TaxLiability:
SUM(SocialSecurity) AS EmployeeSS,
SUM(Medicare)       AS EmployeeMed,
SUM(SocialSecurity) AS EmployerSS,   -- Bug: same column used for both
SUM(Medicare)       AS EmployerMed,  -- Bug: same column used for both
SUM(FederalTax) + SUM(StateTax)
    + (SUM(SocialSecurity) * 2)
    + (SUM(Medicare) * 2) AS TotalTaxLiability
```

This over-counts employer SS/Medicare for employees who hit the wage base cap (no SS above $168,600) and would under-count if employer rates differed. The `TotalTaxLiability` figure shown to payroll administrators is incorrect for any company with high-earner employees.

**Modernization target:** `usp_Benefits_CalculateEmployerShare` (currently incomplete and unused) is replaced by a proper `EmployerFicaCalculationService` that respects the wage base cap. Reports read from a properly modelled `EmployerPayrollContributions` aggregate rather than doubling the employee column.

---

## AP-11 — No Role-Based Access Control

**File:** `PayrollLegacy/PayrollWeb/PayrollWeb/Web.config`  
**Severity:** Medium  
**Pattern:** Authentication uses Windows Integrated Security (`<authentication mode="Windows" />`). There are no `<authorization>` rules, no role checks in page code-behind, and no separation between HR administrator and Payroll administrator permissions.

Any authenticated Windows domain user who can reach the server can access any page, including the year-end processing page that resets all YTD balances.

**Modernization target:** ASP.NET Core authorization policies. `[Authorize(Policy = "PayrollAdmin")]` on PayrollRun pages; `[Authorize(Policy = "HRAdmin")]` on Employee pages. Roles sourced from Active Directory groups or a local roles table. Year-end operations require an additional `[Authorize(Policy = "PayrollSupervisor")]` policy.

---

## AP-12 — Stack Traces Exposed to Users

**File:** `PayrollLegacy/PayrollWeb/PayrollWeb/Web.config`  
**Severity:** Low–Medium  
**Pattern:** `<customErrors mode="Off" />` means unhandled exceptions render the full ASP.NET yellow screen of death — including stack trace, SQL query text (with table names), and in some cases partial data values — directly to the browser.

**Modernization target:** ASP.NET Core exception middleware (`app.UseExceptionHandler("/Error")`) returns a generic error page in production. `app.UseDeveloperExceptionPage()` is enabled only in the Development environment.
