---
# ADR 0001 — Target Web Framework Selection

**Status:** Accepted  
**Date:** 2026-04-24  
**Author:** Architecture Team  

---

## Context

The legacy application is built on ASP.NET 4.8 Web Forms. Web Forms reached end of active development with .NET Framework 4.8; it is not available on .NET 5+. The project goal is to migrate to the .NET 10 LTS platform, which unlocks modern runtime performance, cross-platform deployment, and first-class tooling support.

The migration must preserve the existing page-level mental model (one URL = one workflow screen) while enabling server-side rendering with clean separation of concerns. The team has experience with C# and Razor syntax but no Blazor or React production experience.

Key constraints:
- All payroll UI is CRUD-heavy with forms, grids, and server-side filtering — no real-time requirements.
- The primary users are internal HR and payroll administrators; a rich client-side SPA experience is not a priority.
- The codebase has zero tests today; the target architecture must be unit-testable.
- PII compliance requires server-side rendering with no sensitive data leaking to browser state.

---

## Decision

**Use ASP.NET Core 10 Razor Pages** as the presentation framework for PayrollModern.Web.

Razor Pages maps one `.cshtml` + one `PageModel` class to each URL. PageModel classes are thin: they validate input, dispatch commands/queries to the Application layer, and bind results to the view. No business logic lives in PageModel classes.

---

## Consequences

**Positive:**
- Each page is a self-contained unit; easy to locate, read, and test in isolation.
- PageModel classes are plain C# — they can be unit-tested without spinning up HTTP.
- Built-in model binding and tag helpers eliminate the `<asp:*>` control ceremony.
- The ASP.NET Core middleware pipeline gives us HTTPS enforcement, authentication, authorization, and logging out of the box.
- .NET 10 LTS receives security patches through November 2028.
- Razor Pages works natively with EF Core, MediatR, and the rest of the chosen stack.

**Negative / Trade-offs:**
- Developers familiar only with Web Forms postback model need to learn the Razor Pages request/response model.
- No ViewState — all transient state must be passed explicitly (query string, TempData, or session). This is an improvement architecturally but requires intentional design.
- Complex client-side interactivity (e.g., inline grid editing) requires Alpine.js or HTMX; acceptable for the current scope.

---

## Alternatives Considered

### Option A: ASP.NET Core MVC

MVC separates controller, view, and model, which suits large teams and many routes per controller. For this application, the page-per-workflow pattern makes Razor Pages a better fit — MVC's controller abstraction adds indirection with no benefit. Razor Pages is the Microsoft-recommended approach for page-centric apps.

**Rejected:** MVC imposes unnecessary structure for CRUD-page workflows.

### Option B: Blazor Server

Blazor Server keeps a SignalR connection open per user and pushes UI diffs over the wire. It enables a reactive UI without JavaScript. However, SignalR connections are not suitable for long-running payroll processing operations (payroll run timeout = 5 min); session affinity requirements complicate load balancing; and the team has no Blazor experience.

**Rejected:** Operational complexity outweighs the reactive UI benefit for this workload.

### Option C: Blazor WebAssembly / Blazor WASM

WASM runs the .NET runtime in the browser. PII fields (SSN) must not be processed client-side due to compliance requirements. A WASM SPA would require a separate API project, doubling the surface area.

**Rejected:** PII compliance and team readiness eliminate this option.

### Option D: React / Angular SPA + Web API

A full SPA with a separate API is the standard for new greenfield consumer products. For an internal HR tool with ~10 concurrent users, the complexity (separate deployment, CORS, JWT management, two codebases) is disproportionate. Razor Pages delivers the same outcome with half the moving parts.

**Rejected:** Operational and team-capability overhead not justified for this scope.

### Option E: Remain on ASP.NET 4.8 / Web Forms (Lift-and-Shift)

Rewriting only the data access layer while keeping Web Forms would eliminate the SQL injection risks and logic duplication, but would not address the testability gap, the tech debt ceiling, or the platform EOL. Running .NET Framework 4.8 on production servers indefinitely creates a growing security patching lag.

**Rejected:** Does not meet the modernization goals; just defers the problem.
