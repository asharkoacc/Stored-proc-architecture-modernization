---
# ADR 0007 — Monolith Decomposition: Seam Identification and Extraction Risk Ranking

**Status:** Accepted  
**Date:** 2026-04-24  
**Author:** Architecture Team  

---

## Context

The PayrollLegacy system is a classic single-database monolith. All 17 tables, 49 stored procedures, and 8 Web Forms pages share one SQL Server database and one IIS application process. The business logic is entirely in T-SQL, which means:

- There are no natural API boundaries — any procedure can read or write any table.
- Several procedures have **cross-domain side effects**: `usp_Payroll_ProcessRun` both calculates pay and updates vacation accrual balances on the `Employees` table.
- Year-end processing (`usp_YearEnd_Process`) mutates at least four conceptually separate domains: W-2 generation, YTD reset, vacation balance cap, and audit logging — all in sequence with no transaction boundary between them.

This ADR identifies the natural seams in the monolith, ranks each potential service boundary by **extraction risk** (not by size or business priority), and documents what we chose not to do and why.

The immediate deliverable is **PayrollModern as a clean modular monolith** (see ADR 0002). This ADR describes the domain boundaries that should be respected inside that monolith and which boundaries are viable candidates for future extraction into separate services.

---

## Seam Identification

The monolith contains six identifiable domain clusters:

### Domain 1 — Employee Management
**Tables:** `Employees`, `EmployeeStatusHistory`, `Departments`, `PayGrades`  
**Procedures:** `usp_Employee_*` (9), `usp_Department_*` (3), `usp_PayGrade_GetAll`  
**Pages:** `Employees.aspx`, `EmployeeDetail.aspx`  
**Responsibilities:** Employee lifecycle (hire, status transitions, termination, rehire), department structure, pay grade definitions.  
**Outbound dependencies:** Referenced as FK source by almost every other domain. Payroll reads `AnnualSalary`, `PayFrequency`, `Status`, `FilingStatus`. Accruals read tenure (via `HireDate`). Tax reads `StateCode`, `FilingStatus`.

### Domain 2 — Time & Attendance
**Tables:** `TimeEntries`  
**Procedures:** `usp_TimeEntry_Insert`, `usp_TimeEntry_GetByEmployee`, `usp_TimeEntry_Approve`  
**Pages:** No dedicated page (time entry editing is not in the current UI; entries are assumed pre-loaded)  
**Responsibilities:** Recording and approving employee time entries per pay period.  
**Outbound dependencies:** Consumed by payroll calculation — `usp_Payroll_ProcessRun` queries `TimeEntries WHERE Status = 2 AND PayPeriodId = @PId`. This is the primary coupling point.

### Domain 3 — Payroll Processing
**Tables:** `PayPeriods`, `PayrollRuns`, `PayrollRunDetails`  
**Procedures:** `usp_Payroll_*` (6), `usp_PayPeriod_*` (4), `usp_PayrollRun_UpdateStatus`  
**Pages:** `PayrollRun.aspx`, `PeriodClose.aspx`  
**Responsibilities:** Payroll run lifecycle (initiate → calculate → approve → post → void), pay period management, period close.  
**Outbound dependencies:** Reads from Employee Management (salary, status), Time & Attendance (approved hours), Tax Engine (brackets), Benefits/Deductions (deduction amounts). Writes YTD back to `Employees` on post — tight coupling to Employee Management.

### Domain 4 — Tax Engine
**Tables:** `FederalTaxBrackets`, `StateTaxRates`  
**Procedures:** `usp_Tax_CalculateFederal`, `usp_Tax_CalculateState`  
**Pages:** `EmployeeDetail.aspx` (tax estimation)  
**Responsibilities:** Federal and state tax bracket lookup and calculation.  
**Outbound dependencies:** None — pure calculation service. Input: `(annualizedIncome, filingStatus, stateCode, taxYear)`. Output: `taxAmount`.

### Domain 5 — Benefits & Deductions
**Tables:** `EmployeeDeductions`, `DeductionTypes`, `EarningsTypes`, `VacationAccrualLedger`  
**Procedures:** `usp_DeductionType_*` (2), `usp_EmployeeDeduction_*` (4), `usp_Deduction_CalculateForEmployee`, `usp_Earnings_CalculateOvertime`, `usp_Benefits_CalculateEmployerShare`, `usp_Accrual_ProcessVacation`, `usp_Accrual_ProcessSickTime`  
**Pages:** `Deductions.aspx`, `PeriodClose.aspx`  
**Responsibilities:** Employee deduction enrollment, deduction calculation, vacation/sick accrual processing.  
**Outbound dependencies:** Reads `Employees.HireDate` for tenure-based accrual tiers. Writes `VacationBalance`, `SickBalance` back to `Employees`. Accrual is triggered inline inside `usp_Payroll_ProcessRun` (tight coupling).

### Domain 6 — Compliance & Reporting
**Tables:** `W2Records`, `AuditLog`  
**Procedures:** `usp_W2_Generate`, `usp_YearEnd_Process`, `usp_Report_*` (5)  
**Pages:** `Reports.aspx`, `PeriodClose.aspx`  
**Responsibilities:** W-2 generation, year-end YTD reset, payroll summary and operational reports.  
**Outbound dependencies:** Reads across all tables (reporting reads everything). `usp_YearEnd_Process` resets YTD on `Employees` and caps vacation balance — writes to Employee Management and Benefits domains.

---

## Extraction Risk Ranking

Risk is scored on three factors:
- **Coupling** — how many cross-domain reads/writes does this domain perform or receive?
- **Shared mutation** — does this domain write to tables owned by another domain?
- **Data consistency requirement** — does extraction require distributed transactions?

| Rank | Domain | Extraction Risk | Coupling | Shared Mutation | Distributed Txn Needed? |
|------|---------|-----------------|----------|-----------------|--------------------------|
| 1 (Lowest) | **Tax Engine** | Low | Reads only FederalTaxBrackets, StateTaxRates | None | No — pure function |
| 2 | **Time & Attendance** | Low–Medium | Reads Employees FK; consumed by Payroll | None (writes only its own TimeEntries) | No — Payroll can call via API |
| 3 | **Benefits & Deductions** | Medium | Reads Employees; writes VacationBalance back to Employees | Yes — writes Employees.VacationBalance | Yes — accrual + employee update must be atomic |
| 4 | **Compliance & Reporting** | Medium | Reads everything; writes W2Records, resets YTD | Yes — YearEnd writes Employees.YTDGross=0 | Yes — W2 gen + YTD reset must be atomic |
| 5 | **Employee Management** | High | FK source for everything; all other domains read it | Yes — PostRun writes YTD back here | Yes — YTD update during post must be atomic |
| 6 (Highest) | **Payroll Processing** | Very High | Reads all domains; orchestrates the full run | Yes — posts YTD to Employees, triggers accruals | Yes — the entire run post is one unit of work |

---

## Recommended Extraction Sequence

Phase 1 (modular monolith — current deliverable):
- Enforce domain boundaries as C# namespaces / feature folders inside PayrollModern.
- No shared `DbContext` between domains; each domain has its own repository interfaces.
- Cross-domain reads go through the Application layer (query handlers that aggregate DTOs from multiple repositories).
- Eliminate cross-domain writes: move YTD update logic into the Payroll domain; have it call an `IEmployeeYtdUpdater` port rather than writing directly to `Employees`.

Phase 2 (optional service extraction, 6–12 months post-launch):
1. **Tax Engine** — extract to a stateless microservice or NuGet library. No data ownership, pure function. Can be shared across future payroll platforms.
2. **Time & Attendance** — extract once the Payroll domain consumes it through the `ITimeEntryReader` port (already enforced in Phase 1). Replace port with HTTP call to the T&A service.
3. **Benefits & Deductions** — extract after the cross-domain write (VacationBalance) is eliminated by event-driven accrual: Payroll emits `PayrollRunProcessedEvent`; Benefits service handles it and updates its own `EmployeeAccrualBalance` table (not the shared `Employees` table).

Phase 3 (only if business justifies it):
4. **Compliance & Reporting** — once Year-End no longer writes to `Employees` (moved to Phase 2's Benefits service), Compliance becomes read-only and can be a separate reporting database (CQRS read side).
5. **Employee Management** + **Payroll Processing** — extract last; these two domains are the most coupled in the current design. Extract only after Phases 1–3 have eliminated most cross-domain writes.

---

## What We Chose Not To Do

### Not doing: Microservices from day one

The natural instinct when seeing the decomposition map above is to extract all six domains immediately. We chose not to because:

1. **The seam boundaries are not yet proven.** We identified them by reading the stored procedure names and table FKs. We have not run the application under production load. The real coupling hotspots may be different once we see actual query patterns.

2. **Distributed transactions are expensive.** Posting a payroll run must update `PayrollRuns`, `PayrollRunDetails`, and `Employees.YTD` atomically. In a monolith, this is a `SaveChangesAsync()` call. In microservices, it requires either a Saga/choreography pattern or a two-phase commit. Both are significantly more complex than the problem they solve, until the bounded contexts are stable.

3. **Team size does not justify it.** Microservices pay off when different teams need to deploy independently. A single team running a modular monolith gets 90% of the benefit (clear boundaries, testable modules) at 10% of the operational cost (no service mesh, no distributed tracing, no independent deployment pipelines needed on day one).

### Not doing: Strangler Fig with the legacy app

The Strangler Fig pattern would intercept requests to the legacy Web Forms app and redirect individual pages to the new application incrementally. We chose a full cut-over instead because:

- The legacy and modern apps do not share an API boundary — they share a database. A strangler fig would require both apps to write to the same `Employees` and `PayrollRuns` tables simultaneously, creating a split-brain migration risk.
- The legacy app is being replaced wholesale. It is not a live production system with thousands of daily users that cannot afford downtime.

### Not doing: Rewriting the stored procedures into new stored procedures

Some teams migrate by rewriting T-SQL into "cleaner" T-SQL — adding TRY/CATCH, breaking up god procedures. We explicitly chose not to do this because it preserves the core problem: logic in SQL cannot be unit-tested, cannot be reasoned about as a domain model, and cannot be extracted into a separate service later without a second full rewrite.

### Not doing: Keeping the existing database schema unchanged

Zero schema changes would allow running legacy and modern apps against the same database during transition. We chose against this because:

- The `Employees.Status` magic integer requires an enum migration (ADR 0005) that changes conceptual ownership.
- The `Employees.SSN` column must change to `NVARCHAR(512)` for encrypted ciphertext (ADR 0006).
- YTD denormalized columns (`YTDGross`, etc.) on the `Employees` table violate the domain boundary: Payroll Processing should own YTD state, not Employee Management.
- A clean schema enables clean EF Core mappings with no workarounds for legacy column conventions.

### Not doing: Event sourcing

Event sourcing — storing every state change as an immutable event log — would give a complete audit trail for payroll runs and employee changes. The current `AuditLog` table is a poor approximation of this. However:

- Event sourcing requires a significant shift in query model (projections, read-side rebuilds) that the team is not yet equipped for.
- The compliance requirement is met by the existing `AuditLog` table and `EmployeeStatusHistory`.
- Event sourcing is the right long-term target for the Payroll Processing domain; it should be introduced in a later phase once the team has experience with the CQRS read/write split that Clean Architecture already establishes.
