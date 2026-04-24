---
# ADR 0003 — ORM and Data Access Strategy

**Status:** Accepted  
**Date:** 2026-04-24  
**Author:** Architecture Team  

---

## Context

The legacy system executes all data operations through 49 T-SQL stored procedures called via `SqlCommand` / `SqlDataAdapter` in ADO.NET. There is no mapping layer; `DataTable` objects are passed from ADO.NET directly to GridView controls. This approach:

- Makes it impossible to test data access logic without a live SQL Server instance.
- Means schema changes must be hand-applied to the database; there is no migration history.
- Forces business logic into T-SQL, where it cannot be unit-tested and is duplicated across procedures.
- Relies on `DataTable` (late-bound, untyped) instead of strongly-typed domain entities.

The migration must achieve: strongly-typed entities, database schema tracked in source control, and data access logic testable with EF Core's in-memory or SQLite provider.

The database is SQL Server 2019 in production. The team has no DBA who will write stored procedures for the new system.

---

## Decision

**Use Entity Framework Core 10** (Code-First, repository pattern) as the primary data access technology.

- **Migrations** — all schema changes are committed as EF Core migration files alongside the C# code. The database is always reproducible from source.
- **Repository pattern** — `IEmployeeRepository`, `IPayrollRunRepository`, etc. are defined in the Application layer and implemented in Infrastructure using `DbContext`. The Application layer never references `DbContext` directly.
- **Unit of Work** — a thin `IUnitOfWork` wraps `DbContext.SaveChangesAsync()`. All changes within a command handler are committed atomically at the end of the handler, not per-repository-call.
- **LINQ queries** replace stored procedures for all CRUD and domain-logic queries. Raw SQL or Dapper is permitted for complex reporting queries where LINQ generates unacceptable query plans (see below).
- **No stored procedures** for business logic. Any remaining stored procedures (e.g., reporting aggregations) are invoked through `context.Database.SqlQueryRaw<T>()` and are documented as infrastructure-level concerns, not business logic.

---

## Consequences

**Positive:**
- Domain entities are mapped to database tables by EF Core; no manual `DataTable` parsing.
- Migrations are version-controlled; CI/CD can apply them automatically.
- Repositories can be mocked or replaced with `UseInMemoryDatabase()` in unit tests.
- EF Core change tracking eliminates the need for explicit UPDATE statements in most cases.
- `HasConversion<>` value converters allow EF Core to transparently encrypt/decrypt PII fields (SSN) at the boundary — see ADR 0006.
- Strongly-typed LINQ queries are checked by the C# compiler; column rename in migration breaks compilation immediately rather than silently at runtime.

**Negative / Trade-offs:**
- EF Core-generated SQL is not always as efficient as hand-tuned T-SQL for complex aggregations. The five reporting queries (`usp_Report_*`) will be implemented using Dapper with raw SQL in the Infrastructure layer to preserve query control.
- EF Core migrations add friction for large schema changes on tables with millions of rows (online index rebuilds require custom migration scripts). Acceptable given current data volume.
- Developers must learn EF Core fluent configuration and the repository pattern.
- EF Core's `InMemoryDatabase` provider does not support transactions or raw SQL, meaning some integration tests must target a real SQL Server or SQLite. The CI pipeline provisions a SQL Server container for integration tests.

---

## EF Core Configuration Decisions

| Decision | Choice | Reason |
|---|---|---|
| Mapping style | Fluent API in `IEntityTypeConfiguration<T>` classes | Keeps entity classes free of EF attributes; domain stays pure |
| Table naming | Explicit `.ToTable("Employees")` calls | Prevents EF from pluralizing entity names differently across versions |
| Lazy loading | Disabled | Lazy loading hides N+1 queries; all includes must be explicit |
| Tracking | AsNoTracking() on all query handlers | Read-side handlers never mutate; tracking adds overhead |
| Concurrency | Row version / `rowversion` column on PayrollRuns | Prevents two admins from approving the same run simultaneously |

---

## Alternatives Considered

### Option A: Dapper (Micro-ORM)

Dapper maps SQL query results to C# objects with minimal ceremony. It gives full control over SQL and is faster than EF Core for read-heavy workloads. However:

- Migrations are not built in; schema changes still require hand-maintained SQL scripts.
- No change tracking; every UPDATE must be written by hand.
- Repository implementations become large files of raw SQL strings.
- Testing requires either a live database or significant SQL mocking infrastructure.

**Partially adopted:** Dapper is used for the five reporting queries in `Infrastructure/Reporting/`. It is not used for command (write) paths.

### Option B: Keep Stored Procedures + ADO.NET

Retain the 49 stored procedures but add C# wrappers that call them. This eliminates the hardest part of the migration (rewriting SQL logic to C#) but defeats the primary goal: moving business logic to the Domain layer where it can be tested.

**Rejected:** Contradicts the core modernization objective.

### Option C: Stored Procedures + EF Core DbContext (EF Core calling SPs)

EF Core can call stored procedures via `FromSqlRaw()` and `ExecuteSqlRaw()`. This allows incremental migration: port stored procedures one by one. However, it leaves the logic fragmented across SQL and C# for an extended period, making the system harder to reason about during the transition.

**Rejected:** Acceptable as a transitional tactic only. All stored procedure logic should be ported to C# domain/application services before the modernized application is considered "done."

### Option D: NHibernate

NHibernate is a mature ORM with excellent proxy-based lazy loading and an HQL query language. The .NET ecosystem has largely moved to EF Core; NHibernate has a smaller community, fewer learning resources, and less tooling (no dotnet-ef migrations CLI equivalent that is widely used).

**Rejected:** EF Core is the ecosystem standard; NHibernate adds onboarding friction with no offsetting benefit for this project.
