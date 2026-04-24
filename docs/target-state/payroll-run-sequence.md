# Target State — Payroll Run Lifecycle Sequence Diagram (PayrollModern)

> This diagram shows the same workflow as [the legacy sequence](../current-state/payroll-run-sequence.md),  
> now distributed across the Clean Architecture layers with explicit error handling,  
> parallelism, and domain-owned state transitions.

---

## Full Lifecycle

```mermaid
sequenceDiagram
    actor Admin as Payroll Admin
    participant UI as Razor Page<br/>(PageModel)
    participant MediatR as MediatR<br/>Pipeline
    participant Handler as Command Handler<br/>(Application Layer)
    participant Domain as Domain Entities<br/>& Services
    participant Repo as Repositories<br/>(Infrastructure)
    participant DB as SQL Server<br/>(EF Core / Dapper)

    Note over Admin,DB: ── PHASE 1: Initiate Run ──────────────────────────────────────

    Admin->>UI: POST /payroll/runs<br/>{payPeriodId, runType}
    UI->>MediatR: IMediator.Send(InitiatePayrollRunCommand)
    MediatR->>MediatR: ValidationBehaviour:<br/>FluentValidation validates command.<br/>Returns 422 if invalid (no handler called)
    MediatR->>Handler: InitiatePayrollRunCommandHandler.Handle()
    Handler->>Repo: IPayPeriodRepository.GetByIdAsync(payPeriodId)
    Repo->>DB: SELECT PayPeriod WHERE Id=X (AsNoTracking)
    DB-->>Repo: PayPeriod entity
    Repo-->>Handler: PayPeriod

    Handler->>Domain: PayrollRun.Initiate(payPeriod, runType, createdBy)
    Domain->>Domain: Validate: period.Status ∈ {Open, Reopened}
    Domain->>Domain: Validate: no duplicate Regular run for period
    alt Validation fails
        Domain-->>Handler: Result.Failure(PayrollErrors.PeriodNotOpen)
        Handler-->>UI: Result.Failure
        UI-->>Admin: Error message shown (no stack trace)
    else Validation passes
        Domain-->>Handler: Result.Success(new PayrollRun{Status=Draft})
        Handler->>Repo: IPayrollRunRepository.AddAsync(run)
        Handler->>Repo: IPayPeriodRepository.UpdateAsync(period{Status=Processing})
        Handler->>Repo: IUnitOfWork.CommitAsync()<br/>[single transaction: run + period atomically]
        Handler-->>UI: Result.Success(runId)
        UI-->>Admin: Redirect to /payroll/runs/{runId}
    end

    Note over Admin,DB: ── PHASE 2: Calculate / Process ──────────────────────────────

    Admin->>UI: POST /payroll/runs/{id}/calculate
    UI->>MediatR: IMediator.Send(ProcessPayrollRunCommand{runId})
    MediatR->>Handler: ProcessPayrollRunCommandHandler.Handle()

    Handler->>Repo: IPayrollRunRepository.GetByIdAsync(runId)
    Repo-->>Handler: PayrollRun{Status=Draft|Calculated}
    Handler->>Domain: run.MarkProcessing()
    Domain->>Domain: Validate: Status ∈ {Draft, Calculated}
    alt Invalid status
        Domain-->>Handler: Result.Failure(PayrollErrors.RunNotInDraftState)
        Handler-->>UI: Result.Failure
        UI-->>Admin: Error message
    end

    Handler->>Repo: IPayrollRunRepository.UpdateAsync(run{Status=Processing})
    Handler->>Repo: IUnitOfWork.CommitAsync()

    Handler->>Repo: IEmployeeRepository.GetActiveForPeriodAsync(payPeriodId)
    Repo->>DB: SELECT employees WHERE Status IN (Active, OnLeave)
    DB-->>Repo: List<Employee>

    Handler->>Repo: ITaxBracketRepository.GetFederalBracketsAsync(year, allFilingStatuses)
    Handler->>Repo: ITaxBracketRepository.GetStateRatesAsync(year)
    Note over Handler: Brackets loaded once per run — not per employee

    par Parallel calculation — Task.WhenAll(employees.Select(...))
        loop For each employee (concurrent tasks)

            Handler->>Repo: ITimeEntryRepository.GetApprovedAsync(employeeId, payPeriodId)
            Repo->>DB: SELECT TimeEntries WHERE EmployeeId=X<br/>AND PayPeriodId=Y AND Status=Approved
            DB-->>Repo: List<TimeEntry>

            Handler->>Repo: IDeductionRepository.GetActiveForEmployeeAsync(employeeId)
            Repo->>DB: SELECT EmployeeDeductions WHERE EmployeeId=X<br/>AND IsActive=1 AND (EndDate IS NULL OR EndDate >= today)
            DB-->>Repo: List<EmployeeDeduction>

            Handler->>Domain: PayrollCalculationService.Calculate(<br/>  employee, timeEntries, deductions,<br/>  federalBrackets, stateRates)

            activate Domain
            Domain->>Domain: OvertimeCalculator.Calculate(hours, rate, payGrade)<br/>→ {regularPay, overtimePay}
            Domain->>Domain: earningsTotals = regular + overtime +<br/>holiday + vacation + sick
            Domain->>Domain: DeductionCalculationService.Calculate(deductions, gross)<br/>→ {preTaxTotal, postTaxTotal}
            Domain->>Domain: taxableGross = gross - preTaxTotal
            Domain->>Domain: TaxCalculationService.CalculateFederal(<br/>  taxableGross, filingStatus, brackets, periodsPerYear)<br/>→ perPeriodFedTax
            Domain->>Domain: TaxCalculationService.CalculateState(<br/>  taxableGross, stateCode, rates, periodsPerYear)<br/>→ perPeriodStateTax
            Domain->>Domain: FicaCalculationService.Calculate(<br/>  taxableGross, employee.YtdSocialSecurity)<br/>→ {socialSecurity, medicare}<br/>[respects $168,600 SS wage base cap]
            Domain->>Domain: netPay = gross - preTax - fedTax - stateTax - SS - Medicare - postTax
            Domain-->>Handler: Result.Success(PayrollRunDetail)
            deactivate Domain

            Handler->>Repo: IPayrollRunRepository.AddDetailAsync(detail)
        end
    end

    Note over Handler: All employee tasks complete (parallel)

    Handler->>Domain: run.MarkCalculated(totalGross, totalFedTax, ...)<br/>[aggregated from all details]
    Handler->>Repo: IPayrollRunRepository.UpdateAsync(run{Status=Calculated})
    Handler->>Repo: IUnitOfWork.CommitAsync()<br/>[all details + run update atomic]
    Handler-->>UI: Result.Success(runId)
    UI-->>Admin: Show run details with totals

    Note over Admin,DB: ── PHASE 3: Approve ──────────────────────────────────────────

    Admin->>UI: POST /payroll/runs/{id}/approve
    UI->>MediatR: IMediator.Send(ApprovePayrollRunCommand{runId, approvedBy})
    MediatR->>Handler: ApprovePayrollRunCommandHandler.Handle()
    Handler->>Repo: IPayrollRunRepository.GetWithDetailsAsync(runId)
    Repo->>DB: SELECT PayrollRun + PayrollRunDetails WHERE RunId=X
    DB-->>Repo: PayrollRun with Details collection
    Handler->>Domain: run.Approve(approvedBy)
    Domain->>Domain: Validate: Status = Calculated
    alt Not Calculated
        Domain-->>Handler: Result.Failure(PayrollErrors.RunNotCalculated)
        Handler-->>UI: Result.Failure → Error message
    else Status = Calculated
        Domain->>Domain: Status = Approved; ApprovedDate = now; ApprovedBy = approvedBy
        Domain->>Domain: Each detail.Status = Approved
        Domain-->>Handler: Result.Success(run)
        Handler->>Repo: IPayrollRunRepository.UpdateAsync(run)
        Handler->>Repo: IUnitOfWork.CommitAsync()<br/>[run + all details atomic]
        Handler-->>UI: Result.Success
        UI-->>Admin: "Run approved."
    end

    Note over Admin,DB: ── PHASE 4: Post ─────────────────────────────────────────────

    Admin->>UI: POST /payroll/runs/{id}/post
    UI->>MediatR: IMediator.Send(PostPayrollRunCommand{runId, postedBy})
    MediatR->>Handler: PostPayrollRunCommandHandler.Handle()
    Handler->>Repo: IPayrollRunRepository.GetWithDetailsAsync(runId)
    Repo-->>Handler: PayrollRun{Status=Approved} + details

    Handler->>Domain: run.Post(postedBy)
    Domain->>Domain: Validate: Status = Approved
    Domain-->>Handler: Result.Success(run)

    Handler->>Repo: IEmployeeRepository.GetByIdsAsync(employeeIds from details)
    loop For each employee's detail
        Handler->>Domain: employee.ApplyYtdUpdate(detail)<br/>[domain method — not raw SQL UPDATE]
        Domain->>Domain: YtdGross += detail.GrossPay<br/>YtdFederalTax += detail.FederalTax<br/>YtdStateTax += detail.StateTax<br/>YtdSocialSecurity += detail.SocialSecurity<br/>YtdMedicare += detail.Medicare<br/>YtdDeductions += detail.PreTax + detail.PostTax
    end

    Handler->>Repo: IPayrollRunRepository.UpdateAsync(run)
    Handler->>Repo: IEmployeeRepository.UpdateRangeAsync(employees)
    Handler->>Repo: IUnitOfWork.CommitAsync()<br/>[run + all employee YTD updates atomic]
    Handler-->>UI: Result.Success
    UI-->>Admin: "Run posted. YTD balances updated."

    Note over Admin,DB: ── PHASE 5: Accruals (decoupled from payroll calc) ───────────

    Admin->>UI: POST /periods/{id}/accruals
    UI->>MediatR: IMediator.Send(ProcessAccrualsCommand{payPeriodId})
    MediatR->>Handler: ProcessAccrualsCommandHandler.Handle()
    Handler->>Repo: IEmployeeRepository.GetActiveFullAndPartTimeAsync()
    loop For each employee
        Handler->>Domain: AccrualCalculationService.CalculateVacation(<br/>  employee.HireDate, today) → hoursThisPeriod
        Handler->>Domain: AccrualCalculationService.CalculateSick() → 1.54 hrs
        Handler->>Domain: employee.ApplyAccrual(vacHours, sickHours)
        Handler->>Repo: IAccrualLedgerRepository.AddAsync(ledgerEntry)
    end
    Handler->>Repo: IUnitOfWork.CommitAsync()
    Handler-->>UI: Result.Success

    Note over Admin,DB: ── ALTERNATE PATH: Void ──────────────────────────────────────

    Admin->>UI: POST /payroll/runs/{id}/void
    UI->>MediatR: IMediator.Send(VoidPayrollRunCommand{runId, voidedBy, reason})
    MediatR->>Handler: VoidPayrollRunCommandHandler.Handle()
    Handler->>Repo: IPayrollRunRepository.GetWithDetailsAsync(runId)
    Repo-->>Handler: PayrollRun + details

    alt Run was Posted (Status = Posted)
        Handler->>Repo: IEmployeeRepository.GetByIdsAsync(employeeIds)
        loop For each employee's detail
            Handler->>Domain: employee.ReverseYtdUpdate(detail)
        end
    end

    Handler->>Domain: run.Void(voidedBy, reason)
    Domain->>Domain: Status = Voided; VoidedDate = now; VoidReason = reason
    Domain->>Domain: Each detail.Status = Voided

    Handler->>Repo: IPayrollRunRepository.UpdateAsync(run)
    Handler->>Repo: IEmployeeRepository.UpdateRangeAsync(employees)
    Handler->>Repo: IUnitOfWork.CommitAsync()<br/>[always atomic — posted reversal and void together]
    Handler-->>UI: Result.Success
    UI-->>Admin: "Run voided."
```

---

## Key Improvements vs. Legacy

| Concern | Legacy (`usp_Payroll_ProcessRun`) | Modern (`ProcessPayrollRunCommandHandler`) |
|---|---|---|
| **Logic location** | 260-line god procedure in T-SQL | Distributed across Domain services (C# classes) |
| **Parallelism** | Sequential cursor (N employees × M queries) | `Task.WhenAll` — employees calculated concurrently |
| **Duplicate logic** | Tax/deduction logic copied 3× across SQL | Single `TaxCalculationService`; no duplication |
| **Accruals coupling** | Accruals run inline inside payroll calc | `ProcessAccrualsCommand` is a separate, explicit operation |
| **Error handling** | No outer transaction; partial results on crash | `IUnitOfWork.CommitAsync()` — all-or-nothing per phase |
| **Testability** | Requires live SQL Server to test any rule | Domain services are pure C# functions; unit tests in milliseconds |
| **HTTP timeout** | CommandTimeout=300s (5-minute blocking request) | Async handlers; long runs can use background job (future) |
| **Void transaction** | No transaction for non-posted void | Always transactional regardless of run status |
| **Magic numbers** | FICA rates, accrual tiers hardcoded in SQL | `TaxConstants.cs`, `AccrualPolicy` value object |
