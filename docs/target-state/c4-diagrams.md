# Target State — C4 Architecture Diagrams (PayrollModern)

> All diagrams use [Mermaid](https://mermaid.js.org/) and render in GitHub Markdown.

---

## Level 2 — Container Diagram

```mermaid
C4Container
    title Container Diagram — PayrollModern (.NET 10)

    Person(hrAdmin, "HR Administrator", "Manages employees,<br/>deductions, and pay periods")
    Person(payrollAdmin, "Payroll Administrator", "Initiates, calculates,<br/>approves, and posts payroll runs")

    System_Boundary(payrollModern, "PayrollModern") {

        Container(web, "PayrollModern.Web", ".NET 10 Razor Pages<br/>ASP.NET Core 10",
            "Presentation layer only.<br/>PageModel classes dispatch<br/>MediatR commands/queries.<br/>No business logic.<br/>Tag helpers, Razor views,<br/>Bootstrap layout.")

        Container(application, "PayrollModern.Application", ".NET 10 Class Library",
            "Use-case layer.<br/>MediatR command + query handlers.<br/>FluentValidation pipeline behaviour.<br/>Repository and service interfaces<br/>(ports). DTOs for cross-layer data.<br/>No EF Core reference.")

        Container(domain, "PayrollModern.Domain", ".NET 10 Class Library",
            "Business rules and domain logic.<br/>Entities: Employee, PayrollRun,<br/>PayPeriod, TimeEntry.<br/>Domain services: PayrollCalculationService,<br/>TaxCalculationService, AccrualCalculationService.<br/>Enums, Value Objects, Result<T>.<br/>Zero external dependencies.")

        Container(infrastructure, "PayrollModern.Infrastructure", ".NET 10 Class Library",
            "EF Core 10 DbContext + migrations.<br/>Repository implementations.<br/>EncryptionService (AES-256-GCM).<br/>Dapper reporting queries.<br/>UnitOfWork.<br/>Azure Key Vault client.")

        ContainerDb(sqlDb, "PayrollModern Database", "SQL Server 2019 / Azure SQL",
            "Schema managed by EF Core migrations.<br/>SSN stored as encrypted NVARCHAR(512).<br/>Enums stored as int with EF converters.<br/>No stored procedures (except<br/>5 optional reporting sprocs via Dapper).")

        Container(keyVault, "Azure Key Vault", "Azure PaaS",
            "Stores Data Encryption Key (DEK)<br/>for AES-256-GCM SSN encryption.<br/>RSA 2048 Key Encryption Key (KEK).<br/>Access via Managed Identity only.")
    }

    System_Ext(ad, "Azure AD / Active Directory", "Identity provider for user auth")
    System_Ext(bank, "Bank / ACH Processor", "Net pay disbursements (file export)")
    System_Ext(irs, "IRS / Tax Authority", "W-2 / 941 filing (file export)")

    Rel(hrAdmin, web, "Uses", "HTTPS")
    Rel(payrollAdmin, web, "Uses", "HTTPS")
    Rel(web, application, "Dispatches commands/queries", "MediatR in-process")
    Rel(application, domain, "Invokes domain services,<br/>mutates entities via repositories")
    Rel(application, infrastructure, "Resolves at runtime via DI<br/>(IEmployeeRepository, etc.)")
    Rel(infrastructure, sqlDb, "EF Core + Dapper", "SQL/TCP")
    Rel(infrastructure, keyVault, "Fetches DEK for SSN encryption", "HTTPS / Managed Identity")
    Rel(web, ad, "Authenticates users", "OpenID Connect / OAuth 2")
    Rel(web, bank, "Net pay export (CSV/NACHA)", "HTTPS / SFTP")
    Rel(web, irs, "W-2 / 941 export", "HTTPS / SFTP")
```

---

## Level 3 — Component Diagram: PayrollModern.Web

```mermaid
C4Component
    title Component Diagram — PayrollModern.Web (Razor Pages)

    Container_Boundary(web, "PayrollModern.Web") {

        Component(program, "Program.cs", "ASP.NET Core Entry Point",
            "DI composition root.<br/>Configures middleware pipeline:<br/>HTTPS, auth, exception handler,<br/>HSTS, static files. Registers<br/>MediatR, FluentValidation, EF Core,<br/>EncryptionService, repositories.")

        Component(employeePages, "Pages/Employees/", "Razor Pages",
            "Index.cshtml — list with server-side<br/>filtering (no SQL injection).<br/>Detail.cshtml — add/edit employee.<br/>No tax calculation logic;<br/>dispatches GetTaxEstimateQuery.")

        Component(payrollPages, "Pages/Payroll/", "Razor Pages",
            "Run.cshtml — payroll run workflow.<br/>No business rules inline.<br/>Dispatches InitiateRunCommand,<br/>ProcessRunCommand, ApproveRunCommand,<br/>PostRunCommand, VoidRunCommand.<br/>Displays Result<T> success/failure.")

        Component(deductionPages, "Pages/Deductions/", "Razor Pages",
            "Index.cshtml — manage enrollments.<br/>Dispatches EnrollDeductionCommand,<br/>DeactivateDeductionCommand.")

        Component(periodPages, "Pages/Periods/", "Razor Pages",
            "Close.cshtml — period close + accruals.<br/>YearEnd.cshtml — year-end processing.<br/>Dispatches ClosePeriodCommand,<br/>ProcessAccrualsCommand,<br/>RunYearEndCommand.")

        Component(reportPages, "Pages/Reports/", "Razor Pages",
            "Summary.cshtml, Earnings.cshtml,<br/>TaxLiability.cshtml, Headcount.cshtml,<br/>Deductions.cshtml — read-only report views.<br/>Dispatches Get*ReportQuery.")

        Component(authMiddleware, "Auth & Authorization", "ASP.NET Core Middleware",
            "OpenID Connect authentication<br/>against Azure AD.<br/>Policy-based authorization:<br/>HRAdmin, PayrollAdmin,<br/>PayrollSupervisor roles.")

        Component(errorMiddleware, "Exception Middleware", "ASP.NET Core Middleware",
            "Catches unhandled exceptions.<br/>Logs full trace to ILogger.<br/>Returns generic error page (no<br/>stack traces to browser).<br/>Developer exception page in<br/>Development environment only.")
    }

    Container(application, "PayrollModern.Application", ".NET 10", "MediatR handlers")

    Rel(employeePages, application, "IMediator.Send(command/query)", "MediatR")
    Rel(payrollPages, application, "IMediator.Send(command/query)", "MediatR")
    Rel(deductionPages, application, "IMediator.Send(command/query)", "MediatR")
    Rel(periodPages, application, "IMediator.Send(command/query)", "MediatR")
    Rel(reportPages, application, "IMediator.Send(query)", "MediatR")
    Rel(authMiddleware, payrollPages, "Enforces PayrollAdmin policy")
    Rel(authMiddleware, periodPages, "Enforces PayrollSupervisor policy")
```

---

## Level 3 — Component Diagram: PayrollModern.Application

```mermaid
C4Component
    title Component Diagram — PayrollModern.Application (Use-Case Layer)

    Container_Boundary(app, "PayrollModern.Application") {

        Component(empCommands, "Employees/Commands/", "MediatR Command Handlers",
            "HireEmployeeCommandHandler<br/>UpdateEmployeeCommandHandler<br/>ChangeEmployeeStatusCommandHandler<br/>TerminateEmployeeCommandHandler<br/>RehireEmployeeCommandHandler<br/>Each validates via FluentValidation,<br/>calls domain entity methods,<br/>commits via IUnitOfWork.")

        Component(empQueries, "Employees/Queries/", "MediatR Query Handlers",
            "GetEmployeeListQueryHandler<br/>GetEmployeeByIdQueryHandler<br/>GetTaxEstimateQueryHandler<br/>Read-only; AsNoTracking();<br/>return DTOs not entities.")

        Component(payrollCommands, "Payroll/Commands/", "MediatR Command Handlers",
            "InitiatePayrollRunCommandHandler<br/>ProcessPayrollRunCommandHandler<br/>  → calls PayrollCalculationService<br/>  → parallel Task.WhenAll per employee<br/>ApprovePayrollRunCommandHandler<br/>PostPayrollRunCommandHandler<br/>VoidPayrollRunCommandHandler")

        Component(payrollQueries, "Payroll/Queries/", "MediatR Query Handlers",
            "GetPayrollRunDetailsQueryHandler<br/>GetPayrollRunSummaryQueryHandler")

        Component(deductionCommands, "Deductions/Commands/", "MediatR Command Handlers",
            "EnrollDeductionCommandHandler<br/>DeactivateDeductionCommandHandler")

        Component(periodCommands, "Periods/Commands/", "MediatR Command Handlers",
            "ClosePeriodCommandHandler<br/>ProcessAccrualsCommandHandler<br/>RunYearEndCommandHandler")

        Component(reportQueries, "Reports/Queries/", "MediatR Query Handlers",
            "GetPayrollSummaryReportQueryHandler<br/>GetEmployeeEarningsReportQueryHandler<br/>GetTaxLiabilityReportQueryHandler<br/>GetHeadcountReportQueryHandler<br/>GetDeductionsSummaryReportQueryHandler<br/>Uses IReportingRepository (Dapper).")

        Component(ports, "Interfaces/ (Ports)", "C# Interfaces",
            "IEmployeeRepository<br/>IPayrollRunRepository<br/>IPayPeriodRepository<br/>IDeductionRepository<br/>ITaxBracketRepository<br/>ITimeEntryRepository<br/>IAccrualLedgerRepository<br/>IReportingRepository<br/>IUnitOfWork<br/>IEncryptionService")

        Component(validation, "Validation/", "FluentValidation",
            "HireEmployeeCommandValidator<br/>InitiatePayrollRunCommandValidator<br/>TerminateEmployeeCommandValidator<br/>ValidationBehaviour (MediatR pipeline)<br/>— runs before every handler.")
    }

    Container(domain, "PayrollModern.Domain", ".NET 10", "Entities and domain services")
    Container(infrastructure, "PayrollModern.Infrastructure", ".NET 10", "EF Core, encryption")

    Rel(payrollCommands, domain, "Calls PayrollCalculationService,<br/>TaxCalculationService,<br/>AccrualCalculationService")
    Rel(empCommands, domain, "Mutates Employee entity<br/>(ChangeStatus, Terminate, Hire)")
    Rel(payrollCommands, ports, "IPayrollRunRepository,<br/>IEmployeeRepository,<br/>IUnitOfWork")
    Rel(empCommands, ports, "IEmployeeRepository, IUnitOfWork")
    Rel(reportQueries, ports, "IReportingRepository (Dapper)")
    Rel(infrastructure, ports, "Implements all interfaces")
```

---

## Level 3 — Component Diagram: PayrollModern.Domain

```mermaid
C4Component
    title Component Diagram — PayrollModern.Domain (Business Rules Layer)

    Container_Boundary(domain, "PayrollModern.Domain") {

        Component(empEntity, "Employee (Aggregate Root)", "Domain Entity",
            "Properties: EmployeeNumber, Name,<br/>EncryptedSSN, Status (enum),<br/>EmploymentType (enum), Salary, HireDate.<br/>Methods: Hire(), ChangeStatus(),<br/>Terminate(), Rehire().<br/>Enforces status transition rules.<br/>Raises DomainEvents.")

        Component(payrollRunEntity, "PayrollRun (Aggregate Root)", "Domain Entity",
            "Properties: PayPeriodId, RunType (enum),<br/>Status (enum), TotalGross, etc.<br/>Methods: Initiate(), MarkProcessing(),<br/>MarkCalculated(), Approve(), Post(), Void().<br/>Each method returns Result<PayrollRun>.<br/>State machine enforced here — not in SQL.")

        Component(payrollDetailEntity, "PayrollRunDetail", "Domain Entity",
            "Per-employee pay detail.<br/>Properties: GrossPay, PreTaxDeductions,<br/>TaxableGross, FedTax, StateTax,<br/>SocialSecurity, Medicare, NetPay.<br/>Status (enum).")

        Component(timeEntryEntity, "TimeEntry", "Domain Entity",
            "Per-employee, per-period hours.<br/>Properties: RegularHours, OvertimeHours,<br/>HolidayHours, VacationHours, SickHours.<br/>Status (enum).<br/>Validate() enforces max hours rules.")

        Component(calcService, "PayrollCalculationService", "Domain Service",
            "Orchestrates per-employee calculation.<br/>Calls OvertimeCalculator,<br/>TaxCalculationService,<br/>DeductionCalculationService,<br/>FicaCalculationService.<br/>Returns PayrollRunDetail.<br/>Pure function — no I/O, fully unit-testable.")

        Component(taxService, "TaxCalculationService", "Domain Service",
            "CalculateFederal(annualizedIncome,<br/>filingStatus, brackets) → Money.<br/>CalculateState(annualizedIncome,<br/>stateCode, rate) → Money.<br/>Takes brackets as parameter (injected).<br/>No database calls — testable in isolation.")

        Component(deductionService, "DeductionCalculationService", "Domain Service",
            "Calculate(deductions, grossPay)<br/>→ (preTaxTotal, postTaxTotal).<br/>Handles percentage and flat amounts.<br/>Checks MaxAnnualAmount cap.")

        Component(accrualService, "AccrualCalculationService", "Domain Service",
            "CalculateVacationAccrual(tenureYears)<br/>→ hoursThisPeriod.<br/>CalculateSickAccrual() → 1.54 hrs.<br/>Accrual tiers loaded from<br/>AccrualPolicy — no magic numbers.")

        Component(ficaService, "FicaCalculationService", "Domain Service",
            "Calculate(taxableGross, ytdSS)<br/>→ (socialSecurity, medicare).<br/>Applies SS wage base cap ($168,600).<br/>Constants in TaxConstants.cs.")

        Component(enums, "Enums/", "C# Enums",
            "EmployeeStatus, EmploymentType,<br/>PayrollRunStatus, PayrollRunType,<br/>PayPeriodStatus, TimeEntryStatus,<br/>PayrollDetailStatus.<br/>Integer values pinned to match legacy DB.")

        Component(valueObjects, "ValueObjects/", "C# Records",
            "EncryptedSSN — wraps ciphertext;<br/>only decrypts when explicitly called.<br/>Money — decimal with currency.<br/>AccrualPolicy — tier configuration.")

        Component(resultType, "Result<T>", "Generic Type",
            "Success/Failure discriminated return.<br/>Error type with Code + Description.<br/>PayrollErrors, EmployeeErrors,<br/>TaxErrors static constants.")
    }
```

---

## Level 3 — Component Diagram: PayrollModern.Infrastructure

```mermaid
C4Component
    title Component Diagram — PayrollModern.Infrastructure (Adapter Layer)

    Container_Boundary(infra, "PayrollModern.Infrastructure") {

        Component(dbContext, "PayrollDbContext", "EF Core DbContext",
            "DbSet<Employee>, DbSet<PayrollRun>,<br/>DbSet<PayrollRunDetail>,<br/>DbSet<PayPeriod>, DbSet<TimeEntry>,<br/>DbSet<EmployeeDeduction>, etc.<br/>Applies all IEntityTypeConfiguration<T>.")

        Component(empConfig, "EntityConfigurations/", "EF Fluent API",
            "EmployeeConfiguration — maps<br/>EncryptedSSN via HasConversion,<br/>enums via HasConversion<int>,<br/>table/column names.<br/>PayrollRunConfiguration — row version<br/>for optimistic concurrency.<br/>All configurations: no EF attributes<br/>on domain entities.")

        Component(empRepo, "EfEmployeeRepository", "Repository",
            "Implements IEmployeeRepository.<br/>GetById, GetAll, GetActiveForPeriod.<br/>Query handlers use AsNoTracking().<br/>Command handlers use tracking.")

        Component(payrollRepo, "EfPayrollRunRepository", "Repository",
            "Implements IPayrollRunRepository.<br/>Includes related PayrollRunDetails.<br/>GetRunWithDetails for approval/post.")

        Component(reportRepo, "DapperReportingRepository", "Repository",
            "Implements IReportingRepository.<br/>5 complex reporting queries via Dapper.<br/>Raw SQL — tuned for reporting workload.<br/>ReadOnly connection string.")

        Component(uow, "UnitOfWork", "Unit of Work",
            "Wraps PayrollDbContext.SaveChangesAsync().<br/>Single commit per command handler.<br/>IUnitOfWork interface owned by Application.")

        Component(encryptionSvc, "EncryptionService", "Infrastructure Service",
            "Implements IEncryptionService.<br/>AES-256-GCM Encrypt/Decrypt.<br/>Fetches DEK from Azure Key Vault<br/>(or env var in Development).<br/>Caches DEK in memory for 5 minutes.")

        Component(migrations, "Migrations/", "EF Core Migrations",
            "Version-controlled schema history.<br/>Initial migration from legacy schema.<br/>Includes data migration for<br/>Status int values (already correct).<br/>SSN column change: VARCHAR → NVARCHAR(512).")
    }

    ContainerDb(sqlDb, "SQL Server", "Database")
    Container(keyVault, "Azure Key Vault", "PaaS")

    Rel(empRepo, dbContext, "Uses")
    Rel(payrollRepo, dbContext, "Uses")
    Rel(uow, dbContext, "SaveChangesAsync()")
    Rel(dbContext, sqlDb, "EF Core / SQL", "TCP")
    Rel(reportRepo, sqlDb, "Dapper / raw SQL", "TCP")
    Rel(encryptionSvc, keyVault, "GetSecret (DEK)", "HTTPS / Managed Identity")
    Rel(dbContext, encryptionSvc, "EncryptedSSN.HasConversion<br/>calls IEncryptionService")
```
