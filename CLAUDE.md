#This project contains a legacy ASP.NET Framework 4.8 Web Forms application that needs to be modernized. 

##Legacy app description:
###Architecture:
ASP.NET Framework 4.8 Web Forms (thin shell — no business logic in code-behind, only UI wiring and ADO.NET SqlCommand calls)
SQL Server 2019 — all business logic lives exclusively in stored procedures

###Deliverables:
schema.sql — tables, constraints, indexes, seed data
procedures.sql — at least 40 T-SQL stored procedures covering: CRUD operations, multi-step business workflows, calculations (e.g., tax, deductions, accruals), validation logic, status state machines, batch/period-close operations, and reporting queries
ASP.NET Web Forms project (.aspx + code-behind .cs) with 5–8 pages that call the procs via ADO.NET
README.md with setup instructions (DB restore + IIS Express run steps)

###Legacy patterns:
Business logic duplicated across procs and code-behind
Raw string concatenation in dynamic SQL (with a comment flagging it)
God procedures (200+ lines, multiple responsibilities)
No error handling or transaction rollback in several procs
Magic numbers and undocumented status codes

##The key improvements :

-Updated ASP.NET Framework 4.8 Web Forms to Razor Views with .NET 10
-Spreads files and logic across application layers and code libraries
-Moves business logic from T-SQL procedures into domain layer
-Improves page design