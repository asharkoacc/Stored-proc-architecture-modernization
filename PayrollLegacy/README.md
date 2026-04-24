# PayrollLegacy — Legacy Modernization Showcase

A deliberately legacy ASP.NET 4.8 Web Forms + SQL Server payroll processing application used as a modernization exercise target. All business logic lives in T-SQL stored procedures; the Web Forms layer is a thin ADO.NET shell.

## Domain Coverage

- Employee master data & status lifecycle
- Pay period management & time entry
- Full payroll run workflow (Draft → Processing → Calculated → Approved → Posted)
- Federal & state tax withholding
- Pre-tax and post-tax deductions (401k, health, garnishments)
- Vacation/sick accruals
- Period close and year-end W-2 generation
- Reporting (summary, YTD earnings, tax liability, headcount)

## Legacy Anti-Patterns (Intentional — for modernization exercise)

| Location | Pattern |
|---|---|
| `usp_Employee_Search` | Raw string concatenation in dynamic SQL (SQL injection risk) |
| `usp_Payroll_ProcessRun` | God procedure — 260+ lines, 6+ responsibilities |
| `EmployeeDetail.aspx.cs` | Tax calculation logic duplicated from stored procedures |
| `Employees.aspx.cs` | String-built SQL query in code-behind |
| Several CRUD procs | No `TRY/CATCH`, no `ROLLBACK` |
| All status columns | Magic integers (1=Active, 2=Leave, etc.) — undocumented |
| `usp_YearEnd_Process` | Multi-step operation with no outer transaction |
| `PayrollRun.aspx.cs` | Business rule (max OT hours) hardcoded in UI layer |

---

## Prerequisites

- SQL Server 2019 (Developer or Express edition)
- Visual Studio 2019 or 2022 with the **ASP.NET and web development** workload
- .NET Framework 4.8 Developer Pack
- IIS Express (included with Visual Studio)

---

## Setup — Database

### Option A: Run scripts manually

1. Open **SQL Server Management Studio** and connect to your instance.
2. Run `Database\schema.sql` — creates the `PayrollLegacy` database, all tables, indexes, and seed data.
3. Run `Database\procedures.sql` — creates all 48 stored procedures.

### Option B: sqlcmd

```bat
sqlcmd -S localhost -E -i "Database\schema.sql"
sqlcmd -S localhost -E -i "Database\procedures.sql"
```

Replace `localhost` with your SQL Server instance name if different (e.g. `.\SQLEXPRESS`).

---

## Setup — Web Application

1. Open `PayrollWeb\PayrollWeb.sln` in Visual Studio.
2. Edit `PayrollWeb\Web.config` — update the `PayrollDB` connection string:
   ```xml
   <add name="PayrollDB"
        connectionString="Server=localhost;Database=PayrollLegacy;Integrated Security=True;"
        providerName="System.Data.SqlClient" />
   ```
3. Press **F5** or click **IIS Express** to run. The browser opens at `Default.aspx`.

> **Note:** The project targets `http://localhost:PORT/`. No HTTPS redirect is configured — intentionally legacy.

---

## Page Map

| URL | Purpose | Key Stored Procs Called |
|---|---|---|
| `Default.aspx` | Dashboard — live KPIs | `usp_Report_PayrollSummary`, `usp_PayPeriod_GetAll` |
| `Employees.aspx` | Employee list + search | `usp_Employee_Search`, `usp_Employee_GetAll` |
| `EmployeeDetail.aspx` | Add / edit employee | `usp_Employee_Insert`, `usp_Employee_Update`, `usp_Employee_Terminate` |
| `PayrollRun.aspx` | Run payroll for a period | `usp_Payroll_InitiateRun`, `usp_Payroll_ProcessRun`, `usp_Payroll_ApproveRun`, `usp_Payroll_PostRun` |
| `Deductions.aspx` | Enroll/update deductions | `usp_EmployeeDeduction_Enroll`, `usp_EmployeeDeduction_Update` |
| `Reports.aspx` | Payroll & tax reports | `usp_Report_*` family |
| `PeriodClose.aspx` | Close period / year-end | `usp_PayPeriod_Close`, `usp_YearEnd_Process`, `usp_W2_Generate` |

---

## Stored Procedure Inventory (48 total)

### CRUD
`usp_Employee_GetAll`, `usp_Employee_GetById`, `usp_Employee_Insert`, `usp_Employee_Update`,
`usp_Employee_Delete`, `usp_Employee_Search`, `usp_Department_GetAll`, `usp_Department_Insert`,
`usp_Department_Update`, `usp_PayGrade_GetAll`, `usp_DeductionType_GetAll`, `usp_DeductionType_Insert`,
`usp_EmployeeDeduction_Enroll`, `usp_EmployeeDeduction_Update`, `usp_EmployeeDeduction_GetByEmployee`,
`usp_PayPeriod_GetAll`, `usp_PayPeriod_GetById`, `usp_PayPeriod_Create`,
`usp_TimeEntry_Insert`, `usp_TimeEntry_GetByEmployee`, `usp_TimeEntry_Approve`

### Payroll Workflow
`usp_Payroll_InitiateRun`, `usp_Payroll_ProcessRun` (**God proc**), `usp_Payroll_CalculateEmployee`,
`usp_Payroll_ApproveRun`, `usp_Payroll_PostRun`, `usp_Payroll_VoidRun`, `usp_PayrollRun_UpdateStatus`,
`usp_PayrollRun_GetDetails`

### Calculations
`usp_Tax_CalculateFederal`, `usp_Tax_CalculateState`, `usp_Deduction_CalculateForEmployee`,
`usp_Earnings_CalculateOvertime`, `usp_Benefits_CalculateEmployerShare`

### Accruals
`usp_Accrual_ProcessVacation`, `usp_Accrual_ProcessSickTime`

### Validation / State Machine
`usp_Validate_EmployeePayroll`, `usp_Employee_UpdateStatus`, `usp_Employee_Terminate`, `usp_Employee_Rehire`

### Period Close / Batch
`usp_PayPeriod_Close`, `usp_YearEnd_Process`, `usp_W2_Generate`, `usp_Batch_ReprocessErrors`

### Reporting
`usp_Report_PayrollSummary`, `usp_Report_EmployeeEarnings`, `usp_Report_TaxLiability`,
`usp_Report_HeadcountByDepartment`, `usp_Report_DeductionsSummary`

---

## Modernization Targets

When using this repo as a modernization exercise, consider migrating toward:

- **API layer**: ASP.NET Core minimal API or Web API replacing Web Forms pages
- **ORM**: Entity Framework Core replacing raw ADO.NET
- **Business logic**: Move from T-SQL procs to C# domain services / calculation engines
- **Security**: Parameterized queries (or ORM), encrypted PII (SSN), HTTPS enforcement
- **Error handling**: Structured exceptions, Polly retry, `ILogger` instead of silent failures
- **Configuration**: `appsettings.json` + secrets management instead of `Web.config`
- **Testing**: Unit tests for calculation logic once moved to C#
