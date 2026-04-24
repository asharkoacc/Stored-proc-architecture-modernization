-- =============================================
-- PayrollLegacy -- procedures.sql
-- 48 stored procedures
-- Run AFTER schema.sql
-- =============================================

USE PayrollLegacy;
GO

-- =============================================
-- 1. usp_Employee_GetAll
-- =============================================
CREATE OR ALTER PROCEDURE usp_Employee_GetAll
    @IncludeTerminated BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        e.EmployeeId,
        e.EmployeeNumber,
        e.FirstName,
        e.LastName,
        e.FirstName + ' ' + e.LastName  AS FullName,
        e.SSN,
        e.HireDate,
        e.TerminationDate,
        e.AnnualSalary,
        e.Status,
        CASE e.Status
            WHEN 1 THEN 'Active'
            WHEN 2 THEN 'Leave'
            WHEN 3 THEN 'Terminated'
            WHEN 4 THEN 'Suspended'
            WHEN 5 THEN 'Retired'
            ELSE 'Unknown'
        END AS StatusLabel,
        d.DepartmentName,
        pg.GradeCode,
        pg.GradeTitle,
        e.PositionTitle,
        e.Email,
        e.FilingStatus,
        e.PayFrequency
    FROM  Employees e
    JOIN  Departments d  ON d.DepartmentId = e.DepartmentId
    JOIN  PayGrades   pg ON pg.PayGradeId  = e.PayGradeId
    WHERE (@IncludeTerminated = 1 OR e.Status <> 3)
    ORDER BY e.LastName, e.FirstName;
END
GO

-- =============================================
-- 2. usp_Employee_GetById
-- =============================================
CREATE OR ALTER PROCEDURE usp_Employee_GetById
    @EmployeeId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        e.*,
        d.DepartmentName,
        d.DepartmentCode,
        pg.GradeCode,
        pg.GradeTitle,
        pg.OvertimeEligible
    FROM  Employees e
    JOIN  Departments d  ON d.DepartmentId = e.DepartmentId
    JOIN  PayGrades   pg ON pg.PayGradeId  = e.PayGradeId
    WHERE e.EmployeeId = @EmployeeId;
END
GO

-- =============================================
-- 3. usp_Employee_Insert
-- No TRY/CATCH -- legacy pattern
-- =============================================
CREATE OR ALTER PROCEDURE usp_Employee_Insert
    @EmployeeNumber  VARCHAR(20),
    @FirstName       VARCHAR(50),
    @LastName        VARCHAR(50),
    @MiddleName      VARCHAR(50)  = NULL,
    @SSN             VARCHAR(11),
    @DateOfBirth     DATE,
    @HireDate        DATE,
    @DepartmentId    INT,
    @PayGradeId      INT,
    @PositionTitle   VARCHAR(100),
    @AnnualSalary    DECIMAL(12,2),
    @HourlyRate      DECIMAL(10,4) = NULL,
    @PayFrequency    VARCHAR(20)   = 'BiWeekly',
    @FilingStatus    VARCHAR(20)   = 'Single',
    @FederalAllowances INT         = 1,
    @StateCode       VARCHAR(2)    = 'CA',
    @WorkState       VARCHAR(2)    = 'CA',
    @EmploymentType  INT           = 1,
    @Email           VARCHAR(255)  = NULL,
    @Phone           VARCHAR(20)   = NULL,
    @Address1        VARCHAR(200)  = NULL,
    @City            VARCHAR(100)  = NULL,
    @StateAddr       VARCHAR(2)    = NULL,
    @Zip             VARCHAR(10)   = NULL,
    @CreatedBy       VARCHAR(100)  = NULL,
    @NewEmployeeId   INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- No transaction, no error handling -- will leave partial data on failure
    INSERT INTO Employees (
        EmployeeNumber, FirstName, LastName, MiddleName, SSN,
        DateOfBirth, HireDate, DepartmentId, PayGradeId, PositionTitle,
        AnnualSalary, HourlyRate, PayFrequency, FilingStatus, FederalAllowances,
        StateCode, WorkState, EmploymentType, Email, Phone, Address1, City,
        StateAddr, Zip, Status, CreatedBy, ModifiedBy
    ) VALUES (
        @EmployeeNumber, @FirstName, @LastName, @MiddleName, @SSN,
        @DateOfBirth, @HireDate, @DepartmentId, @PayGradeId, @PositionTitle,
        @AnnualSalary, @HourlyRate, @PayFrequency, @FilingStatus, @FederalAllowances,
        @StateCode, @WorkState, @EmploymentType, @Email, @Phone, @Address1, @City,
        @StateAddr, @Zip, 1,
        ISNULL(@CreatedBy, SYSTEM_USER), ISNULL(@CreatedBy, SYSTEM_USER)
    );
    SET @NewEmployeeId = SCOPE_IDENTITY();

    INSERT INTO AuditLog (TableName, RecordId, Action, NewValue, ChangedBy)
    VALUES ('Employees', @NewEmployeeId, 'INSERT', @EmployeeNumber + ' - ' + @FirstName + ' ' + @LastName, ISNULL(@CreatedBy, SYSTEM_USER));
END
GO

-- =============================================
-- 4. usp_Employee_Update
-- =============================================
CREATE OR ALTER PROCEDURE usp_Employee_Update
    @EmployeeId      INT,
    @FirstName       VARCHAR(50),
    @LastName        VARCHAR(50),
    @MiddleName      VARCHAR(50)  = NULL,
    @DepartmentId    INT,
    @PayGradeId      INT,
    @PositionTitle   VARCHAR(100),
    @AnnualSalary    DECIMAL(12,2),
    @HourlyRate      DECIMAL(10,4) = NULL,
    @PayFrequency    VARCHAR(20),
    @FilingStatus    VARCHAR(20),
    @FederalAllowances INT,
    @StateCode       VARCHAR(2),
    @WorkState       VARCHAR(2),
    @EmploymentType  INT,
    @Email           VARCHAR(255)  = NULL,
    @Phone           VARCHAR(20)   = NULL,
    @Address1        VARCHAR(200)  = NULL,
    @City            VARCHAR(100)  = NULL,
    @StateAddr       VARCHAR(2)    = NULL,
    @Zip             VARCHAR(10)   = NULL,
    @ModifiedBy      VARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OldSalary DECIMAL(12,2);
    SELECT @OldSalary = AnnualSalary FROM Employees WHERE EmployeeId = @EmployeeId;

    UPDATE Employees SET
        FirstName          = @FirstName,
        LastName           = @LastName,
        MiddleName         = @MiddleName,
        DepartmentId       = @DepartmentId,
        PayGradeId         = @PayGradeId,
        PositionTitle      = @PositionTitle,
        AnnualSalary       = @AnnualSalary,
        HourlyRate         = @HourlyRate,
        PayFrequency       = @PayFrequency,
        FilingStatus       = @FilingStatus,
        FederalAllowances  = @FederalAllowances,
        StateCode          = @StateCode,
        WorkState          = @WorkState,
        EmploymentType     = @EmploymentType,
        Email              = @Email,
        Phone              = @Phone,
        Address1           = @Address1,
        City               = @City,
        StateAddr          = @StateAddr,
        Zip                = @Zip,
        ModifiedDate       = GETDATE(),
        ModifiedBy         = ISNULL(@ModifiedBy, SYSTEM_USER)
    WHERE EmployeeId = @EmployeeId;

    IF @OldSalary <> @AnnualSalary
        INSERT INTO AuditLog (TableName, RecordId, Action, ColumnName, OldValue, NewValue, ChangedBy)
        VALUES ('Employees', @EmployeeId, 'UPDATE', 'AnnualSalary',
                CAST(@OldSalary AS VARCHAR(20)), CAST(@AnnualSalary AS VARCHAR(20)),
                ISNULL(@ModifiedBy, SYSTEM_USER));
END
GO

-- =============================================
-- 5. usp_Employee_Delete (soft delete)
-- =============================================
CREATE OR ALTER PROCEDURE usp_Employee_Delete
    @EmployeeId INT,
    @DeletedBy  VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- Soft delete only -- never hard-delete employee records
    UPDATE Employees SET
        Status       = 3,  -- 3 = Terminated
        ModifiedDate = GETDATE(),
        ModifiedBy   = ISNULL(@DeletedBy, SYSTEM_USER)
    WHERE EmployeeId = @EmployeeId AND Status <> 3;

    INSERT INTO AuditLog (TableName, RecordId, Action, ColumnName, NewValue, ChangedBy)
    VALUES ('Employees', @EmployeeId, 'DELETE', 'Status', '3', ISNULL(@DeletedBy, SYSTEM_USER));
END
GO

-- =============================================
-- 6. usp_Employee_Search
-- LEGACY: raw string concatenation in dynamic SQL
-- SQL INJECTION RISK -- intentional for modernization exercise
-- =============================================
CREATE OR ALTER PROCEDURE usp_Employee_Search
    @SearchTerm  VARCHAR(100) = NULL,
    @DepartmentId INT         = NULL,
    @Status       INT         = NULL,
    @PayGradeId   INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- WARNING: building SQL via string concatenation -- SQL injection vector
    DECLARE @SQL VARCHAR(MAX);
    SET @SQL = 'SELECT e.EmployeeId, e.EmployeeNumber, e.FirstName + '' '' + e.LastName AS FullName, ';
    SET @SQL = @SQL + 'd.DepartmentName, pg.GradeCode, e.AnnualSalary, e.Status, e.HireDate, e.Email ';
    SET @SQL = @SQL + 'FROM Employees e ';
    SET @SQL = @SQL + 'JOIN Departments d ON d.DepartmentId = e.DepartmentId ';
    SET @SQL = @SQL + 'JOIN PayGrades pg ON pg.PayGradeId = e.PayGradeId ';
    SET @SQL = @SQL + 'WHERE 1=1 ';

    IF @SearchTerm IS NOT NULL
        -- INJECTION: @SearchTerm is embedded directly
        SET @SQL = @SQL + 'AND (e.FirstName LIKE ''%' + @SearchTerm + '%'' OR e.LastName LIKE ''%' + @SearchTerm + '%'' OR e.EmployeeNumber LIKE ''%' + @SearchTerm + '%'') ';

    IF @DepartmentId IS NOT NULL
        SET @SQL = @SQL + 'AND e.DepartmentId = ' + CAST(@DepartmentId AS VARCHAR(10)) + ' ';

    IF @Status IS NOT NULL
        SET @SQL = @SQL + 'AND e.Status = ' + CAST(@Status AS VARCHAR(2)) + ' ';

    IF @PayGradeId IS NOT NULL
        SET @SQL = @SQL + 'AND e.PayGradeId = ' + CAST(@PayGradeId AS VARCHAR(10)) + ' ';

    SET @SQL = @SQL + 'ORDER BY e.LastName, e.FirstName';

    EXEC(@SQL);
END
GO

-- =============================================
-- 7. usp_Employee_UpdateStatus  (state machine)
-- Valid transitions:
--   1(Active) -> 2(Leave), 3(Terminated), 4(Suspended)
--   2(Leave)  -> 1(Active), 3(Terminated)
--   4(Suspended) -> 1(Active), 3(Terminated)
--   3(Terminated) -> 1(Rehire via usp_Employee_Rehire)
-- =============================================
CREATE OR ALTER PROCEDURE usp_Employee_UpdateStatus
    @EmployeeId    INT,
    @NewStatus     INT,
    @ChangeReason  VARCHAR(500) = NULL,
    @ChangedBy     VARCHAR(100) = NULL,
    @Result        INT          OUTPUT  -- 0=success, 1=invalid transition, 2=not found
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentStatus INT;
    SELECT @CurrentStatus = Status FROM Employees WHERE EmployeeId = @EmployeeId;

    IF @CurrentStatus IS NULL
    BEGIN SET @Result = 2; RETURN; END

    -- Validate transition
    IF NOT EXISTS (
        SELECT 1 FROM (VALUES
            (1,2),(1,3),(1,4),   -- Active -> Leave, Terminated, Suspended
            (2,1),(2,3),          -- Leave -> Active, Terminated
            (4,1),(4,3),          -- Suspended -> Active, Terminated
            (5,3)                 -- Retired -> Terminated (admin correction)
        ) AS T(FromStatus, ToStatus)
        WHERE T.FromStatus = @CurrentStatus AND T.ToStatus = @NewStatus
    )
    BEGIN SET @Result = 1; RETURN; END

    UPDATE Employees SET
        Status       = @NewStatus,
        ModifiedDate = GETDATE(),
        ModifiedBy   = ISNULL(@ChangedBy, SYSTEM_USER)
    WHERE EmployeeId = @EmployeeId;

    INSERT INTO EmployeeStatusHistory (EmployeeId, OldStatus, NewStatus, ChangeReason, ChangedBy)
    VALUES (@EmployeeId, @CurrentStatus, @NewStatus, @ChangeReason, ISNULL(@ChangedBy, SYSTEM_USER));

    SET @Result = 0;
END
GO

-- =============================================
-- 8. usp_Employee_Terminate
-- =============================================
CREATE OR ALTER PROCEDURE usp_Employee_Terminate
    @EmployeeId       INT,
    @TerminationDate  DATE,
    @Reason           VARCHAR(500) = NULL,
    @FinalPayBonus    DECIMAL(12,2) = 0,
    @ProcessedBy      VARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- No outer transaction -- if audit insert fails, employee still gets terminated
    UPDATE Employees SET
        Status          = 3,  -- 3 = Terminated
        TerminationDate = @TerminationDate,
        ModifiedDate    = GETDATE(),
        ModifiedBy      = ISNULL(@ProcessedBy, SYSTEM_USER)
    WHERE EmployeeId = @EmployeeId;

    INSERT INTO EmployeeStatusHistory (EmployeeId, OldStatus, NewStatus, ChangeReason, ChangedBy)
    SELECT EmployeeId, Status, 3, @Reason, ISNULL(@ProcessedBy, SYSTEM_USER)
    FROM   Employees WHERE EmployeeId = @EmployeeId;

    -- Deactivate all deductions
    UPDATE EmployeeDeductions SET
        IsActive = 0,
        EndDate  = @TerminationDate
    WHERE EmployeeId = @EmployeeId AND IsActive = 1;

    INSERT INTO AuditLog (TableName, RecordId, Action, ColumnName, NewValue, ChangedBy)
    VALUES ('Employees', @EmployeeId, 'UPDATE', 'TerminationDate',
            CONVERT(VARCHAR(10), @TerminationDate, 120), ISNULL(@ProcessedBy, SYSTEM_USER));
END
GO

-- =============================================
-- 9. usp_Employee_Rehire
-- =============================================
CREATE OR ALTER PROCEDURE usp_Employee_Rehire
    @EmployeeId    INT,
    @NewHireDate   DATE,
    @NewSalary     DECIMAL(12,2) = NULL,
    @NewDeptId     INT           = NULL,
    @ProcessedBy   VARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentStatus INT;
    SELECT @CurrentStatus = Status FROM Employees WHERE EmployeeId = @EmployeeId;
    IF @CurrentStatus <> 3  -- 3 = Terminated
    BEGIN
        RAISERROR('Employee is not in Terminated status. Cannot rehire.', 16, 1);
        RETURN;
    END

    UPDATE Employees SET
        Status          = 1,  -- 1 = Active
        HireDate        = @NewHireDate,
        TerminationDate = NULL,
        AnnualSalary    = ISNULL(@NewSalary, AnnualSalary),
        DepartmentId    = ISNULL(@NewDeptId, DepartmentId),
        VacationBalance = 0,
        SickBalance     = 0,
        ModifiedDate    = GETDATE(),
        ModifiedBy      = ISNULL(@ProcessedBy, SYSTEM_USER)
    WHERE EmployeeId = @EmployeeId;

    INSERT INTO EmployeeStatusHistory (EmployeeId, OldStatus, NewStatus, ChangeReason, ChangedBy)
    VALUES (@EmployeeId, 3, 1, 'Rehired on ' + CONVERT(VARCHAR(10), @NewHireDate, 120), ISNULL(@ProcessedBy, SYSTEM_USER));
END
GO

-- =============================================
-- 10. usp_Department_GetAll
-- =============================================
CREATE OR ALTER PROCEDURE usp_Department_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        d.DepartmentId,
        d.DepartmentCode,
        d.DepartmentName,
        d.CostCenter,
        d.IsActive,
        d.ManagerId,
        e.FirstName + ' ' + e.LastName AS ManagerName,
        (SELECT COUNT(*) FROM Employees WHERE DepartmentId = d.DepartmentId AND Status = 1) AS ActiveHeadcount
    FROM  Departments d
    LEFT JOIN Employees e ON e.EmployeeId = d.ManagerId
    ORDER BY d.DepartmentName;
END
GO

-- =============================================
-- 11. usp_Department_Insert
-- =============================================
CREATE OR ALTER PROCEDURE usp_Department_Insert
    @DepartmentCode VARCHAR(10),
    @DepartmentName VARCHAR(100),
    @CostCenter     VARCHAR(20),
    @ManagerId      INT          = NULL,
    @NewDeptId      INT          OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Departments (DepartmentCode, DepartmentName, CostCenter, ManagerId)
    VALUES (@DepartmentCode, @DepartmentName, @CostCenter, @ManagerId);
    SET @NewDeptId = SCOPE_IDENTITY();
END
GO

-- =============================================
-- 12. usp_Department_Update
-- =============================================
CREATE OR ALTER PROCEDURE usp_Department_Update
    @DepartmentId   INT,
    @DepartmentName VARCHAR(100),
    @CostCenter     VARCHAR(20),
    @ManagerId      INT = NULL,
    @IsActive       BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Departments SET
        DepartmentName = @DepartmentName,
        CostCenter     = @CostCenter,
        ManagerId      = @ManagerId,
        IsActive       = @IsActive,
        ModifiedDate   = GETDATE()
    WHERE DepartmentId = @DepartmentId;
END
GO

-- =============================================
-- 13. usp_PayGrade_GetAll
-- =============================================
CREATE OR ALTER PROCEDURE usp_PayGrade_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PayGradeId, GradeCode, GradeTitle, MinSalary, MaxSalary, OvertimeEligible, IsActive
    FROM   PayGrades
    WHERE  IsActive = 1
    ORDER  BY MinSalary;
END
GO

-- =============================================
-- 14. usp_DeductionType_GetAll
-- =============================================
CREATE OR ALTER PROCEDURE usp_DeductionType_GetAll
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DeductionTypeId, TypeCode, TypeName, IsPreTax, IsPercentage,
           DefaultAmount, MaxAnnualAmount, IsActive, DisplayOrder
    FROM   DeductionTypes
    WHERE  (@IncludeInactive = 1 OR IsActive = 1)
    ORDER  BY DisplayOrder, TypeName;
END
GO

-- =============================================
-- 15. usp_DeductionType_Insert
-- =============================================
CREATE OR ALTER PROCEDURE usp_DeductionType_Insert
    @TypeCode       VARCHAR(20),
    @TypeName       VARCHAR(100),
    @IsPreTax       BIT,
    @IsPercentage   BIT,
    @DefaultAmount  DECIMAL(12,2),
    @MaxAnnualAmount DECIMAL(12,2) = NULL,
    @DisplayOrder   INT            = 99,
    @NewTypeId      INT            OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO DeductionTypes (TypeCode, TypeName, IsPreTax, IsPercentage, DefaultAmount, MaxAnnualAmount, DisplayOrder)
    VALUES (@TypeCode, @TypeName, @IsPreTax, @IsPercentage, @DefaultAmount, @MaxAnnualAmount, @DisplayOrder);
    SET @NewTypeId = SCOPE_IDENTITY();
END
GO

-- =============================================
-- 16. usp_EmployeeDeduction_Enroll
-- =============================================
CREATE OR ALTER PROCEDURE usp_EmployeeDeduction_Enroll
    @EmployeeId     INT,
    @DeductionTypeId INT,
    @Amount         DECIMAL(12,2),
    @IsPercentage   BIT,
    @EffectiveDate  DATE,
    @Notes          VARCHAR(500) = NULL,
    @EnrollmentId   INT          OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- Deactivate any existing enrollment for same deduction type
    UPDATE EmployeeDeductions SET IsActive = 0, EndDate = @EffectiveDate
    WHERE  EmployeeId = @EmployeeId AND DeductionTypeId = @DeductionTypeId AND IsActive = 1;

    INSERT INTO EmployeeDeductions (EmployeeId, DeductionTypeId, Amount, IsPercentage, EffectiveDate, Notes, IsActive)
    VALUES (@EmployeeId, @DeductionTypeId, @Amount, @IsPercentage, @EffectiveDate, @Notes, 1);
    SET @EnrollmentId = SCOPE_IDENTITY();
END
GO

-- =============================================
-- 17. usp_EmployeeDeduction_Update
-- =============================================
CREATE OR ALTER PROCEDURE usp_EmployeeDeduction_Update
    @EnrollmentId   INT,
    @Amount         DECIMAL(12,2),
    @IsPercentage   BIT,
    @EndDate        DATE         = NULL,
    @IsActive       BIT          = 1,
    @Notes          VARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE EmployeeDeductions SET
        Amount       = @Amount,
        IsPercentage = @IsPercentage,
        EndDate      = @EndDate,
        IsActive     = @IsActive,
        Notes        = @Notes
    WHERE EnrollmentId = @EnrollmentId;
END
GO

-- =============================================
-- 18. usp_EmployeeDeduction_GetByEmployee
-- =============================================
CREATE OR ALTER PROCEDURE usp_EmployeeDeduction_GetByEmployee
    @EmployeeId     INT,
    @ActiveOnly     BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ed.EnrollmentId,
        ed.EmployeeId,
        ed.DeductionTypeId,
        dt.TypeCode,
        dt.TypeName,
        dt.IsPreTax,
        ed.Amount,
        ed.IsPercentage,
        ed.EffectiveDate,
        ed.EndDate,
        ed.IsActive,
        ed.Notes,
        dt.MaxAnnualAmount
    FROM  EmployeeDeductions ed
    JOIN  DeductionTypes dt ON dt.DeductionTypeId = ed.DeductionTypeId
    WHERE ed.EmployeeId = @EmployeeId
    AND   (@ActiveOnly = 0 OR ed.IsActive = 1)
    ORDER BY dt.DisplayOrder;
END
GO

-- =============================================
-- 19. usp_PayPeriod_GetAll
-- =============================================
CREATE OR ALTER PROCEDURE usp_PayPeriod_GetAll
    @FiscalYear    INT = NULL,
    @FrequencyType VARCHAR(20) = NULL,
    @StatusFilter  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pp.PayPeriodId,
        pp.PeriodName,
        pp.StartDate,
        pp.EndDate,
        pp.PayDate,
        pp.FiscalYear,
        pp.PeriodNumber,
        pp.Status,
        CASE pp.Status
            WHEN 1 THEN 'Open'
            WHEN 2 THEN 'Processing'
            WHEN 3 THEN 'Closed'
            WHEN 4 THEN 'Reopened'
            ELSE 'Unknown'
        END AS StatusLabel,
        pp.FrequencyType,
        (SELECT COUNT(*) FROM PayrollRuns r WHERE r.PayPeriodId = pp.PayPeriodId AND r.Status NOT IN (6)) AS RunCount
    FROM  PayPeriods pp
    WHERE (@FiscalYear    IS NULL OR pp.FiscalYear    = @FiscalYear)
    AND   (@FrequencyType IS NULL OR pp.FrequencyType = @FrequencyType)
    AND   (@StatusFilter  IS NULL OR pp.Status        = @StatusFilter)
    ORDER BY pp.FiscalYear DESC, pp.PeriodNumber DESC;
END
GO

-- =============================================
-- 20. usp_PayPeriod_GetById
-- =============================================
CREATE OR ALTER PROCEDURE usp_PayPeriod_GetById
    @PayPeriodId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pp.*,
        CASE pp.Status WHEN 1 THEN 'Open' WHEN 2 THEN 'Processing' WHEN 3 THEN 'Closed' WHEN 4 THEN 'Reopened' ELSE 'Unknown' END AS StatusLabel
    FROM PayPeriods pp
    WHERE pp.PayPeriodId = @PayPeriodId;
END
GO

-- =============================================
-- 21. usp_PayPeriod_Create
-- =============================================
CREATE OR ALTER PROCEDURE usp_PayPeriod_Create
    @PeriodName    VARCHAR(50),
    @StartDate     DATE,
    @EndDate       DATE,
    @PayDate       DATE,
    @FiscalYear    INT,
    @PeriodNumber  INT,
    @FrequencyType VARCHAR(20) = 'BiWeekly',
    @NewPeriodId   INT         OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM PayPeriods WHERE FiscalYear=@FiscalYear AND PeriodNumber=@PeriodNumber AND FrequencyType=@FrequencyType)
    BEGIN
        RAISERROR('Pay period already exists for this year/number/frequency combination.', 16, 1);
        RETURN;
    END
    INSERT INTO PayPeriods (PeriodName, StartDate, EndDate, PayDate, FiscalYear, PeriodNumber, FrequencyType, Status)
    VALUES (@PeriodName, @StartDate, @EndDate, @PayDate, @FiscalYear, @PeriodNumber, @FrequencyType, 1);
    SET @NewPeriodId = SCOPE_IDENTITY();
END
GO

-- =============================================
-- 22. usp_TimeEntry_Insert
-- No validation, no transaction -- legacy
-- =============================================
CREATE OR ALTER PROCEDURE usp_TimeEntry_Insert
    @EmployeeId    INT,
    @PayPeriodId   INT,
    @EntryDate     DATE,
    @RegularHours  DECIMAL(6,2) = 0,
    @OvertimeHours DECIMAL(6,2) = 0,
    @HolidayHours  DECIMAL(6,2) = 0,
    @VacationHours DECIMAL(6,2) = 0,
    @SickHours     DECIMAL(6,2) = 0,
    @Notes         VARCHAR(500) = NULL,
    @NewEntryId    INT          OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO TimeEntries (EmployeeId, PayPeriodId, EntryDate, RegularHours, OvertimeHours,
        HolidayHours, VacationHours, SickHours, Notes, Status)
    VALUES (@EmployeeId, @PayPeriodId, @EntryDate, @RegularHours, @OvertimeHours,
        @HolidayHours, @VacationHours, @SickHours, @Notes, 1);
    SET @NewEntryId = SCOPE_IDENTITY();
END
GO

-- =============================================
-- 23. usp_TimeEntry_GetByEmployee
-- =============================================
CREATE OR ALTER PROCEDURE usp_TimeEntry_GetByEmployee
    @EmployeeId  INT,
    @PayPeriodId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        te.TimeEntryId,
        te.EmployeeId,
        te.PayPeriodId,
        pp.PeriodName,
        te.EntryDate,
        te.RegularHours,
        te.OvertimeHours,
        te.HolidayHours,
        te.VacationHours,
        te.SickHours,
        te.RegularHours + te.OvertimeHours + te.HolidayHours + te.VacationHours + te.SickHours AS TotalHours,
        te.Notes,
        te.Status,
        CASE te.Status WHEN 1 THEN 'Pending' WHEN 2 THEN 'Approved' WHEN 3 THEN 'Rejected' ELSE '?' END AS StatusLabel
    FROM  TimeEntries te
    JOIN  PayPeriods  pp ON pp.PayPeriodId = te.PayPeriodId
    WHERE te.EmployeeId = @EmployeeId
    AND   (@PayPeriodId IS NULL OR te.PayPeriodId = @PayPeriodId)
    ORDER BY te.EntryDate;
END
GO

-- =============================================
-- 24. usp_TimeEntry_Approve
-- =============================================
CREATE OR ALTER PROCEDURE usp_TimeEntry_Approve
    @TimeEntryId INT,
    @ApproverId  INT,
    @Approve     BIT = 1  -- 1=Approve, 0=Reject
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE TimeEntries SET
        Status       = CASE @Approve WHEN 1 THEN 2 ELSE 3 END,
        ApprovedBy   = @ApproverId,
        ApprovedDate = GETDATE()
    WHERE TimeEntryId = @TimeEntryId;
END
GO

-- =============================================
-- 25. usp_Payroll_InitiateRun
-- =============================================
CREATE OR ALTER PROCEDURE usp_Payroll_InitiateRun
    @PayPeriodId INT,
    @RunType     INT          = 1,
    @Notes       VARCHAR(1000) = NULL,
    @CreatedBy   VARCHAR(100) = NULL,
    @NewRunId    INT          OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Validate pay period is open
        IF NOT EXISTS (SELECT 1 FROM PayPeriods WHERE PayPeriodId = @PayPeriodId AND Status IN (1, 4))
        BEGIN
            ROLLBACK;
            RAISERROR('Pay period is not open. Cannot initiate payroll run.', 16, 1);
            RETURN;
        END

        -- Check no active run already exists for regular runs
        IF @RunType = 1 AND EXISTS (
            SELECT 1 FROM PayrollRuns
            WHERE PayPeriodId = @PayPeriodId AND RunType = 1 AND Status NOT IN (6)
        )
        BEGIN
            ROLLBACK;
            RAISERROR('A regular payroll run already exists for this period.', 16, 1);
            RETURN;
        END

        DECLARE @RunNumber INT;
        SELECT @RunNumber = ISNULL(MAX(RunNumber), 0) + 1
        FROM   PayrollRuns WHERE PayPeriodId = @PayPeriodId;

        INSERT INTO PayrollRuns (PayPeriodId, RunNumber, RunType, Status, Notes, CreatedBy)
        VALUES (@PayPeriodId, @RunNumber, @RunType, 1, @Notes, ISNULL(@CreatedBy, SYSTEM_USER));

        SET @NewRunId = SCOPE_IDENTITY();

        UPDATE PayPeriods SET Status = 2 WHERE PayPeriodId = @PayPeriodId AND Status = 1;

        COMMIT;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH
END
GO

-- =============================================
-- 26. usp_Tax_CalculateFederal
-- Returns calculated federal withholding for a given annualized income
-- =============================================
CREATE OR ALTER PROCEDURE usp_Tax_CalculateFederal
    @AnnualizedIncome  DECIMAL(12,2),
    @FilingStatus      VARCHAR(20),
    @TaxYear           INT = 2024,
    @FederalTaxAmount  DECIMAL(12,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @FederalTaxAmount = 0;

    SELECT TOP 1
        @FederalTaxAmount = BaseAmount + ((@AnnualizedIncome - MinIncome) * TaxRate)
    FROM FederalTaxBrackets
    WHERE TaxYear      = @TaxYear
    AND   FilingStatus = @FilingStatus
    AND   MinIncome   <= @AnnualizedIncome
    AND   (MaxIncome  IS NULL OR MaxIncome > @AnnualizedIncome)
    ORDER BY MinIncome DESC;

    IF @FederalTaxAmount < 0 SET @FederalTaxAmount = 0;
END
GO

-- =============================================
-- 27. usp_Tax_CalculateState
-- =============================================
CREATE OR ALTER PROCEDURE usp_Tax_CalculateState
    @AnnualizedIncome  DECIMAL(12,2),
    @StateCode         VARCHAR(2),
    @TaxYear           INT = 2024,
    @StateTaxAmount    DECIMAL(12,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @StateTaxAmount = 0;

    DECLARE @FlatRate   DECIMAL(5,4);
    DECLARE @StdDed     DECIMAL(12,2);

    SELECT @FlatRate = FlatRate, @StdDed = StandardDeduction
    FROM   StateTaxRates
    WHERE  StateCode = @StateCode AND TaxYear = @TaxYear;

    IF @FlatRate IS NOT NULL AND @FlatRate > 0
        SET @StateTaxAmount = CASE WHEN (@AnnualizedIncome - @StdDed) > 0
                                   THEN (@AnnualizedIncome - @StdDed) * @FlatRate
                                   ELSE 0 END;
END
GO

-- =============================================
-- 28. usp_Deduction_CalculateForEmployee
-- Returns total pre-tax and post-tax deductions per pay period
-- =============================================
CREATE OR ALTER PROCEDURE usp_Deduction_CalculateForEmployee
    @EmployeeId       INT,
    @GrossPay         DECIMAL(12,2),
    @PreTaxTotal      DECIMAL(12,2) OUTPUT,
    @PostTaxTotal     DECIMAL(12,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @PreTaxTotal  = 0;
    SET @PostTaxTotal = 0;

    SELECT
        @PreTaxTotal  = ISNULL(SUM(CASE WHEN dt.IsPreTax = 1 THEN CASE WHEN ed.IsPercentage = 1 THEN @GrossPay * ed.Amount / 100.0 ELSE ed.Amount END ELSE 0 END), 0),
        @PostTaxTotal = ISNULL(SUM(CASE WHEN dt.IsPreTax = 0 THEN CASE WHEN ed.IsPercentage = 1 THEN @GrossPay * ed.Amount / 100.0 ELSE ed.Amount END ELSE 0 END), 0)
    FROM  EmployeeDeductions ed
    JOIN  DeductionTypes dt ON dt.DeductionTypeId = ed.DeductionTypeId
    WHERE ed.EmployeeId = @EmployeeId
    AND   ed.IsActive   = 1
    AND   (ed.EndDate IS NULL OR ed.EndDate >= CAST(GETDATE() AS DATE));
END
GO

-- =============================================
-- 29. usp_Earnings_CalculateOvertime
-- =============================================
CREATE OR ALTER PROCEDURE usp_Earnings_CalculateOvertime
    @EmployeeId      INT,
    @RegularHours    DECIMAL(8,2),
    @OvertimeHours   DECIMAL(8,2),
    @RegularPay      DECIMAL(12,2) OUTPUT,
    @OvertimePay     DECIMAL(12,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @HourlyRate      DECIMAL(10,4);
    DECLARE @AnnualSalary    DECIMAL(12,2);
    DECLARE @PayFrequency    VARCHAR(20);
    DECLARE @OTEligible      BIT;

    SELECT
        @HourlyRate   = e.HourlyRate,
        @AnnualSalary = e.AnnualSalary,
        @PayFrequency = e.PayFrequency,
        @OTEligible   = pg.OvertimeEligible
    FROM  Employees e
    JOIN  PayGrades pg ON pg.PayGradeId = e.PayGradeId
    WHERE e.EmployeeId = @EmployeeId;

    -- Derive hourly rate from annual salary if not set
    IF @HourlyRate IS NULL OR @HourlyRate = 0
    BEGIN
        SET @HourlyRate = CASE @PayFrequency
            WHEN 'Weekly'      THEN @AnnualSalary / 52.0  / 40.0
            WHEN 'BiWeekly'    THEN @AnnualSalary / 26.0  / 80.0
            WHEN 'SemiMonthly' THEN @AnnualSalary / 24.0  / 86.67
            WHEN 'Monthly'     THEN @AnnualSalary / 12.0  / 173.33
            ELSE                    @AnnualSalary / 26.0  / 80.0
        END;
    END

    SET @RegularPay  = ROUND(@HourlyRate * @RegularHours, 2);
    SET @OvertimePay = CASE WHEN @OTEligible = 1
                            THEN ROUND(@HourlyRate * 1.5 * @OvertimeHours, 2)
                            ELSE 0 END;
END
GO

-- =============================================
-- 30. usp_Benefits_CalculateEmployerShare
-- Returns employer's matching contribution (401k match + FICA employer)
-- =============================================
CREATE OR ALTER PROCEDURE usp_Benefits_CalculateEmployerShare
    @EmployeeId         INT,
    @GrossPay           DECIMAL(12,2),
    @EmployerSSAmount   DECIMAL(12,2) OUTPUT,
    @EmployerMedAmount  DECIMAL(12,2) OUTPUT,
    @Employer401kMatch  DECIMAL(12,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- 6.2% employer SS up to wage base, 1.45% Medicare no cap
    -- Magic numbers: 168600 = 2024 SS wage base, 0.062 / 0.0145
    SET @EmployerSSAmount  = ROUND(@GrossPay * 0.062,  2);
    SET @EmployerMedAmount = ROUND(@GrossPay * 0.0145, 2);

    -- 50% match up to 3% of gross (common employer 401k match)
    DECLARE @EmpContrib DECIMAL(12,2);
    SELECT @EmpContrib = ISNULL(SUM(
        CASE WHEN ed.IsPercentage = 1 THEN @GrossPay * ed.Amount / 100.0
             ELSE ed.Amount END), 0)
    FROM EmployeeDeductions ed
    JOIN DeductionTypes dt ON dt.DeductionTypeId = ed.DeductionTypeId
    WHERE ed.EmployeeId = @EmployeeId AND dt.TypeCode = '401K' AND ed.IsActive = 1;

    SET @Employer401kMatch = ROUND(CASE WHEN @EmpContrib > @GrossPay * 0.03 THEN @GrossPay * 0.03 * 0.5 ELSE @EmpContrib * 0.5 END, 2);
END
GO

-- =============================================
-- 31. usp_Validate_EmployeePayroll
-- Returns 1 if employee is valid for payroll, 0 otherwise
-- =============================================
CREATE OR ALTER PROCEDURE usp_Validate_EmployeePayroll
    @EmployeeId     INT,
    @PayPeriodId    INT,
    @IsValid        BIT          OUTPUT,
    @ValidationMsg  VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @IsValid       = 1;
    SET @ValidationMsg = '';

    DECLARE @Status     INT;
    DECLARE @HireDate   DATE;
    DECLARE @TermDate   DATE;
    DECLARE @Salary     DECIMAL(12,2);
    DECLARE @PeriodEnd  DATE;

    SELECT @Status    = e.Status,
           @HireDate  = e.HireDate,
           @TermDate  = e.TerminationDate,
           @Salary    = e.AnnualSalary
    FROM   Employees e WHERE e.EmployeeId = @EmployeeId;

    SELECT @PeriodEnd = EndDate FROM PayPeriods WHERE PayPeriodId = @PayPeriodId;

    IF @Status IS NULL
    BEGIN SET @IsValid = 0; SET @ValidationMsg = 'Employee not found.'; RETURN; END

    IF @Status = 3  -- Terminated
    BEGIN
        IF @TermDate IS NULL OR @TermDate < (SELECT StartDate FROM PayPeriods WHERE PayPeriodId = @PayPeriodId)
        BEGIN SET @IsValid = 0; SET @ValidationMsg = 'Employee terminated before pay period start.'; RETURN; END
    END

    IF @Status = 4  -- Suspended
    BEGIN SET @IsValid = 0; SET @ValidationMsg = 'Employee is suspended.'; RETURN; END

    IF @Salary <= 0
    BEGIN SET @IsValid = 0; SET @ValidationMsg = 'Employee salary is zero or negative.'; RETURN; END

    IF @HireDate > @PeriodEnd
    BEGIN SET @IsValid = 0; SET @ValidationMsg = 'Employee hire date is after pay period end.'; RETURN; END
END
GO

-- =============================================
-- 32. usp_Payroll_CalculateEmployee
-- Calculates pay for one employee in a run
-- =============================================
CREATE OR ALTER PROCEDURE usp_Payroll_CalculateEmployee
    @RunId       INT,
    @EmployeeId  INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @PayPeriodId    INT;
        DECLARE @AnnualSalary   DECIMAL(12,2);
        DECLARE @HourlyRate     DECIMAL(10,4);
        DECLARE @PayFrequency   VARCHAR(20);
        DECLARE @FilingStatus   VARCHAR(20);
        DECLARE @StateCode      VARCHAR(2);
        DECLARE @OTEligible     BIT;
        DECLARE @PeriodsPerYear INT;

        SELECT
            @PayPeriodId  = r.PayPeriodId,
            @AnnualSalary = e.AnnualSalary,
            @HourlyRate   = e.HourlyRate,
            @PayFrequency = e.PayFrequency,
            @FilingStatus = e.FilingStatus,
            @StateCode    = e.WorkState,
            @OTEligible   = pg.OvertimeEligible
        FROM PayrollRuns r
        JOIN Employees   e  ON e.EmployeeId  = r.PayPeriodId  -- intentional bug-like join placeholder
        JOIN PayGrades   pg ON pg.PayGradeId = e.PayGradeId
        WHERE r.RunId = @RunId AND e.EmployeeId = @EmployeeId;

        -- Fix the join: re-select from Employees directly
        SELECT
            @AnnualSalary = e.AnnualSalary,
            @HourlyRate   = e.HourlyRate,
            @PayFrequency = e.PayFrequency,
            @FilingStatus = e.FilingStatus,
            @StateCode    = e.WorkState,
            @OTEligible   = pg.OvertimeEligible
        FROM Employees e
        JOIN PayGrades pg ON pg.PayGradeId = e.PayGradeId
        WHERE e.EmployeeId = @EmployeeId;

        SELECT @PayPeriodId = PayPeriodId FROM PayrollRuns WHERE RunId = @RunId;

        SET @PeriodsPerYear = CASE @PayFrequency
            WHEN 'Weekly'      THEN 52
            WHEN 'BiWeekly'    THEN 26
            WHEN 'SemiMonthly' THEN 24
            WHEN 'Monthly'     THEN 12
            ELSE 26 END;

        -- Get time entries for the period
        DECLARE @RegHrs  DECIMAL(8,2) = 0;
        DECLARE @OTHrs   DECIMAL(8,2) = 0;
        DECLARE @HolHrs  DECIMAL(8,2) = 0;
        DECLARE @VacHrs  DECIMAL(8,2) = 0;
        DECLARE @SickHrs DECIMAL(8,2) = 0;

        SELECT
            @RegHrs  = ISNULL(SUM(RegularHours),  0),
            @OTHrs   = ISNULL(SUM(OvertimeHours),  0),
            @HolHrs  = ISNULL(SUM(HolidayHours),  0),
            @VacHrs  = ISNULL(SUM(VacationHours),  0),
            @SickHrs = ISNULL(SUM(SickHours),       0)
        FROM TimeEntries
        WHERE EmployeeId = @EmployeeId AND PayPeriodId = @PayPeriodId AND Status = 2;  -- 2=Approved

        -- If no time entries, use standard hours for salaried
        IF @RegHrs = 0 AND @OTHrs = 0 AND @VacHrs = 0 AND @SickHrs = 0
            SET @RegHrs = CASE @PayFrequency WHEN 'Weekly' THEN 40 WHEN 'Monthly' THEN 173.33 ELSE 80 END;

        DECLARE @RegPay  DECIMAL(12,2);
        DECLARE @OTPay   DECIMAL(12,2);
        EXEC usp_Earnings_CalculateOvertime @EmployeeId, @RegHrs, @OTHrs, @RegPay OUTPUT, @OTPay OUTPUT;

        DECLARE @EffHourly DECIMAL(10,4);
        SET @EffHourly = @RegPay / NULLIF(@RegHrs, 0);

        DECLARE @HolPay  DECIMAL(12,2) = ROUND(ISNULL(@EffHourly,0) * @HolHrs, 2);
        DECLARE @VacPay  DECIMAL(12,2) = ROUND(ISNULL(@EffHourly,0) * @VacHrs, 2);
        DECLARE @SickPay DECIMAL(12,2) = ROUND(ISNULL(@EffHourly,0) * @SickHrs, 2);
        DECLARE @GrossPay DECIMAL(12,2) = @RegPay + @OTPay + @HolPay + @VacPay + @SickPay;

        -- Pre-tax deductions
        DECLARE @PreTax  DECIMAL(12,2);
        DECLARE @PostTax DECIMAL(12,2);
        EXEC usp_Deduction_CalculateForEmployee @EmployeeId, @GrossPay, @PreTax OUTPUT, @PostTax OUTPUT;

        DECLARE @TaxableGross DECIMAL(12,2) = @GrossPay - @PreTax;
        IF @TaxableGross < 0 SET @TaxableGross = 0;

        -- Annualize for bracket lookup
        DECLARE @AnnualizedTaxable DECIMAL(12,2) = @TaxableGross * @PeriodsPerYear;
        DECLARE @AnnualFedTax   DECIMAL(12,2);
        DECLARE @AnnualStateTax DECIMAL(12,2);

        EXEC usp_Tax_CalculateFederal  @AnnualizedTaxable, @FilingStatus, 2024, @AnnualFedTax   OUTPUT;
        EXEC usp_Tax_CalculateState    @AnnualizedTaxable, @StateCode,    2024, @AnnualStateTax  OUTPUT;

        DECLARE @FedTax   DECIMAL(12,2) = ROUND(@AnnualFedTax   / @PeriodsPerYear, 2);
        DECLARE @StateTax DECIMAL(12,2) = ROUND(@AnnualStateTax / @PeriodsPerYear, 2);

        -- FICA -- magic numbers: 0.062 SS, 0.0145 Medicare, 168600 wage base
        DECLARE @SSTax   DECIMAL(12,2) = ROUND(@TaxableGross * 0.062,  2);
        DECLARE @MedTax  DECIMAL(12,2) = ROUND(@TaxableGross * 0.0145, 2);

        DECLARE @NetPay  DECIMAL(12,2) = @GrossPay - @PreTax - @FedTax - @StateTax - @SSTax - @MedTax - @PostTax;

        -- Upsert detail record
        IF EXISTS (SELECT 1 FROM PayrollRunDetails WHERE RunId = @RunId AND EmployeeId = @EmployeeId)
            UPDATE PayrollRunDetails SET
                RegularHours=@RegHrs, OvertimeHours=@OTHrs, HolidayHours=@HolHrs,
                VacationHours=@VacHrs, SickHours=@SickHrs,
                RegularPay=@RegPay, OvertimePay=@OTPay, HolidayPay=@HolPay,
                VacationPay=@VacPay, SickPay=@SickPay,
                GrossPay=@GrossPay, PreTaxDeductions=@PreTax,
                TaxableGross=@TaxableGross, FederalTax=@FedTax,
                StateTax=@StateTax, SocialSecurity=@SSTax, Medicare=@MedTax,
                PostTaxDeductions=@PostTax, NetPay=@NetPay,
                Status=1, ErrorMessage=NULL, CalculatedDate=GETDATE()
            WHERE RunId = @RunId AND EmployeeId = @EmployeeId;
        ELSE
            INSERT INTO PayrollRunDetails (
                RunId, EmployeeId, RegularHours, OvertimeHours, HolidayHours, VacationHours, SickHours,
                RegularPay, OvertimePay, HolidayPay, VacationPay, SickPay,
                GrossPay, PreTaxDeductions, TaxableGross, FederalTax, StateTax,
                SocialSecurity, Medicare, PostTaxDeductions, NetPay,
                Status, CalculatedDate)
            VALUES (
                @RunId, @EmployeeId, @RegHrs, @OTHrs, @HolHrs, @VacHrs, @SickHrs,
                @RegPay, @OTPay, @HolPay, @VacPay, @SickPay,
                @GrossPay, @PreTax, @TaxableGross, @FedTax, @StateTax,
                @SSTax, @MedTax, @PostTax, @NetPay,
                1, GETDATE());
    END TRY
    BEGIN CATCH
        -- Record the error on the detail row
        IF EXISTS (SELECT 1 FROM PayrollRunDetails WHERE RunId = @RunId AND EmployeeId = @EmployeeId)
            UPDATE PayrollRunDetails SET Status = 4, ErrorMessage = ERROR_MESSAGE()
            WHERE RunId = @RunId AND EmployeeId = @EmployeeId;
        ELSE
            INSERT INTO PayrollRunDetails (RunId, EmployeeId, Status, ErrorMessage, CalculatedDate)
            VALUES (@RunId, @EmployeeId, 4, ERROR_MESSAGE(), GETDATE());
    END CATCH
END
GO

-- =============================================
-- 33. usp_Payroll_ProcessRun  -- GOD PROCEDURE
-- Single procedure handles: validation, per-employee calculation loop,
-- federal/state tax (logic duplicated here AND in usp_Tax_Calculate*),
-- deductions, FICA, accruals, YTD update, run totals.
-- 260+ lines, multiple responsibilities -- intentional legacy smell.
-- No partial-failure recovery between employees.
-- =============================================
CREATE OR ALTER PROCEDURE usp_Payroll_ProcessRun
    @RunId       INT,
    @ProcessedBy VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ---- Step 1: Validate run state ----
    DECLARE @PayPeriodId INT;
    DECLARE @RunType     INT;
    DECLARE @RunStatus   INT;

    SELECT @PayPeriodId = PayPeriodId,
           @RunType     = RunType,
           @RunStatus   = Status
    FROM   PayrollRuns WHERE RunId = @RunId;

    IF @RunId IS NULL OR @RunStatus IS NULL
    BEGIN
        RAISERROR('Payroll run not found: %d', 16, 1, @RunId);
        RETURN;
    END

    -- Only Draft (1) or Calculated (3) runs can be processed
    IF @RunStatus NOT IN (1, 3)
    BEGIN
        RAISERROR('Run is not in Draft or Calculated state. Current status: %d', 16, 1, @RunStatus);
        RETURN;
    END

    -- Mark run as Processing (2)
    UPDATE PayrollRuns SET Status = 2, ProcessedDate = GETDATE() WHERE RunId = @RunId;

    -- ---- Step 2: Build employee list ----
    DECLARE @Employees TABLE (EmployeeId INT, RowNum INT IDENTITY(1,1));

    IF @RunType = 1  -- Regular run: all active employees
        INSERT INTO @Employees (EmployeeId)
        SELECT e.EmployeeId
        FROM   Employees e
        WHERE  e.Status IN (1, 2)  -- 1=Active, 2=Leave
        AND    e.HireDate <= (SELECT EndDate FROM PayPeriods WHERE PayPeriodId = @PayPeriodId)
        AND    (e.TerminationDate IS NULL OR e.TerminationDate >= (SELECT StartDate FROM PayPeriods WHERE PayPeriodId = @PayPeriodId))
        ORDER  BY e.EmployeeId;

    DECLARE @TotalEmployees INT = (SELECT COUNT(*) FROM @Employees);
    DECLARE @CurrentRow     INT = 1;

    -- ---- Step 3: Per-employee calculation loop ----
    -- No outer transaction -- each employee calculated independently
    WHILE @CurrentRow <= @TotalEmployees
    BEGIN
        DECLARE @EmpId          INT;
        DECLARE @AnnualSalary   DECIMAL(12,2);
        DECLARE @HourlyRt       DECIMAL(10,4);
        DECLARE @PayFreq        VARCHAR(20);
        DECLARE @FilingStatus   VARCHAR(20);
        DECLARE @WorkState      VARCHAR(2);
        DECLARE @OTEligible     BIT;
        DECLARE @PeriodsPerYr   INT;

        SELECT @EmpId = EmployeeId FROM @Employees WHERE RowNum = @CurrentRow;

        SELECT
            @AnnualSalary = e.AnnualSalary,
            @HourlyRt     = e.HourlyRate,
            @PayFreq      = e.PayFrequency,
            @FilingStatus = e.FilingStatus,
            @WorkState    = e.WorkState,
            @OTEligible   = pg.OvertimeEligible
        FROM Employees e
        JOIN PayGrades pg ON pg.PayGradeId = e.PayGradeId
        WHERE e.EmployeeId = @EmpId;

        SET @PeriodsPerYr = CASE @PayFreq
            WHEN 'Weekly'      THEN 52
            WHEN 'BiWeekly'    THEN 26
            WHEN 'SemiMonthly' THEN 24
            WHEN 'Monthly'     THEN 12
            ELSE 26 END;

        -- ---- Step 3a: Aggregate time entries ----
        DECLARE @RegHrs  DECIMAL(8,2) = 0;
        DECLARE @OTHrs   DECIMAL(8,2) = 0;
        DECLARE @HolHrs  DECIMAL(8,2) = 0;
        DECLARE @VacHrs  DECIMAL(8,2) = 0;
        DECLARE @SickHrs DECIMAL(8,2) = 0;

        SELECT
            @RegHrs  = ISNULL(SUM(RegularHours),  0),
            @OTHrs   = ISNULL(SUM(OvertimeHours),  0),
            @HolHrs  = ISNULL(SUM(HolidayHours),  0),
            @VacHrs  = ISNULL(SUM(VacationHours),  0),
            @SickHrs = ISNULL(SUM(SickHours),       0)
        FROM TimeEntries
        WHERE EmployeeId = @EmpId AND PayPeriodId = @PayPeriodId AND Status = 2;

        -- Default to full-period hours for salaried if no time entries
        IF @RegHrs = 0 AND @OTHrs = 0 AND @HolHrs = 0 AND @VacHrs = 0 AND @SickHrs = 0
        BEGIN
            IF @OTEligible = 0  -- salaried exempt
                SET @RegHrs = CASE @PayFreq WHEN 'Weekly' THEN 40.0 WHEN 'Monthly' THEN 173.33 ELSE 80.0 END;
            ELSE
                SET @RegHrs = CASE @PayFreq WHEN 'Weekly' THEN 40.0 WHEN 'Monthly' THEN 173.33 ELSE 80.0 END;
        END

        -- ---- Step 3b: Earnings calculation ----
        -- Duplicate of usp_Earnings_CalculateOvertime logic (intentional redundancy)
        DECLARE @EffHourlyRate DECIMAL(10,4);
        IF @HourlyRt IS NOT NULL AND @HourlyRt > 0
            SET @EffHourlyRate = @HourlyRt;
        ELSE
            SET @EffHourlyRate = CASE @PayFreq
                WHEN 'Weekly'      THEN @AnnualSalary / 52.0   / 40.0
                WHEN 'BiWeekly'    THEN @AnnualSalary / 26.0   / 80.0
                WHEN 'SemiMonthly' THEN @AnnualSalary / 24.0   / 86.67
                WHEN 'Monthly'     THEN @AnnualSalary / 12.0   / 173.33
                ELSE                    @AnnualSalary / 26.0   / 80.0
            END;

        DECLARE @RegPay  DECIMAL(12,2) = ROUND(@EffHourlyRate * @RegHrs, 2);
        DECLARE @OTPay   DECIMAL(12,2) = CASE WHEN @OTEligible = 1 THEN ROUND(@EffHourlyRate * 1.5 * @OTHrs, 2) ELSE 0 END;
        DECLARE @HolPay  DECIMAL(12,2) = ROUND(@EffHourlyRate * @HolHrs,  2);
        DECLARE @VacPay  DECIMAL(12,2) = ROUND(@EffHourlyRate * @VacHrs,  2);
        DECLARE @SickPay DECIMAL(12,2) = ROUND(@EffHourlyRate * @SickHrs, 2);
        DECLARE @GrossPay DECIMAL(12,2) = @RegPay + @OTPay + @HolPay + @VacPay + @SickPay;

        -- ---- Step 3c: Pre-tax deductions ----
        DECLARE @PreTaxDed  DECIMAL(12,2) = 0;
        DECLARE @PostTaxDed DECIMAL(12,2) = 0;

        SELECT
            @PreTaxDed  = ISNULL(SUM(CASE WHEN dt.IsPreTax=1 THEN CASE WHEN ed.IsPercentage=1 THEN @GrossPay*ed.Amount/100.0 ELSE ed.Amount END ELSE 0 END),0),
            @PostTaxDed = ISNULL(SUM(CASE WHEN dt.IsPreTax=0 THEN CASE WHEN ed.IsPercentage=1 THEN @GrossPay*ed.Amount/100.0 ELSE ed.Amount END ELSE 0 END),0)
        FROM EmployeeDeductions ed
        JOIN DeductionTypes dt ON dt.DeductionTypeId = ed.DeductionTypeId
        WHERE ed.EmployeeId = @EmpId AND ed.IsActive = 1
        AND (ed.EndDate IS NULL OR ed.EndDate >= CAST(GETDATE() AS DATE));

        DECLARE @TaxableGross DECIMAL(12,2) = CASE WHEN @GrossPay - @PreTaxDed > 0 THEN @GrossPay - @PreTaxDed ELSE 0 END;

        -- ---- Step 3d: Federal tax -- DUPLICATED from usp_Tax_CalculateFederal ----
        DECLARE @AnnualizedTG   DECIMAL(12,2) = @TaxableGross * @PeriodsPerYr;
        DECLARE @AnnFedTax      DECIMAL(12,2) = 0;

        SELECT TOP 1
            @AnnFedTax = BaseAmount + ((@AnnualizedTG - MinIncome) * TaxRate)
        FROM FederalTaxBrackets
        WHERE TaxYear      = 2024
        AND   FilingStatus = @FilingStatus
        AND   MinIncome   <= @AnnualizedTG
        AND   (MaxIncome  IS NULL OR MaxIncome > @AnnualizedTG)
        ORDER BY MinIncome DESC;

        IF @AnnFedTax < 0 SET @AnnFedTax = 0;
        DECLARE @FedTaxPer DECIMAL(12,2) = ROUND(@AnnFedTax / @PeriodsPerYr, 2);

        -- ---- Step 3e: State tax -- DUPLICATED from usp_Tax_CalculateState ----
        DECLARE @AnnStateTax  DECIMAL(12,2) = 0;
        DECLARE @StateFlatRate DECIMAL(5,4);
        DECLARE @StateStdDed   DECIMAL(12,2);

        SELECT @StateFlatRate = FlatRate, @StateStdDed = StandardDeduction
        FROM   StateTaxRates
        WHERE  StateCode = @WorkState AND TaxYear = 2024;

        IF @StateFlatRate IS NOT NULL AND @StateFlatRate > 0
            SET @AnnStateTax = CASE WHEN (@AnnualizedTG - ISNULL(@StateStdDed,0)) > 0
                                    THEN (@AnnualizedTG - @StateStdDed) * @StateFlatRate
                                    ELSE 0 END;

        DECLARE @StateTaxPer DECIMAL(12,2) = ROUND(@AnnStateTax / @PeriodsPerYr, 2);

        -- ---- Step 3f: FICA ----
        -- Magic numbers: 0.062 employee SS, 0.0145 Medicare
        -- SS wage base cap not fully enforced here (another legacy smell)
        DECLARE @SSTax  DECIMAL(12,2) = ROUND(@TaxableGross * 0.062,  2);
        DECLARE @MedTax DECIMAL(12,2) = ROUND(@TaxableGross * 0.0145, 2);

        -- ---- Step 3g: Net pay ----
        DECLARE @NetPay DECIMAL(12,2) = @GrossPay - @PreTaxDed - @FedTaxPer - @StateTaxPer - @SSTax - @MedTax - @PostTaxDed;
        IF @NetPay < 0 SET @NetPay = 0;  -- floor at zero; no negative checks elsewhere

        -- ---- Step 3h: Write detail row ----
        IF EXISTS (SELECT 1 FROM PayrollRunDetails WHERE RunId=@RunId AND EmployeeId=@EmpId)
            UPDATE PayrollRunDetails SET
                RegularHours=@RegHrs, OvertimeHours=@OTHrs, HolidayHours=@HolHrs,
                VacationHours=@VacHrs, SickHours=@SickHrs,
                RegularPay=@RegPay, OvertimePay=@OTPay, HolidayPay=@HolPay,
                VacationPay=@VacPay, SickPay=@SickPay,
                GrossPay=@GrossPay, PreTaxDeductions=@PreTaxDed,
                TaxableGross=@TaxableGross, FederalTax=@FedTaxPer,
                StateTax=@StateTaxPer, SocialSecurity=@SSTax, Medicare=@MedTax,
                PostTaxDeductions=@PostTaxDed, NetPay=@NetPay,
                Status=1, ErrorMessage=NULL, CalculatedDate=GETDATE()
            WHERE RunId=@RunId AND EmployeeId=@EmpId;
        ELSE
            INSERT INTO PayrollRunDetails(
                RunId,EmployeeId,RegularHours,OvertimeHours,HolidayHours,VacationHours,SickHours,
                RegularPay,OvertimePay,HolidayPay,VacationPay,SickPay,GrossPay,PreTaxDeductions,
                TaxableGross,FederalTax,StateTax,SocialSecurity,Medicare,PostTaxDeductions,NetPay,
                Status,CalculatedDate)
            VALUES(
                @RunId,@EmpId,@RegHrs,@OTHrs,@HolHrs,@VacHrs,@SickHrs,
                @RegPay,@OTPay,@HolPay,@VacPay,@SickPay,@GrossPay,@PreTaxDed,
                @TaxableGross,@FedTaxPer,@StateTaxPer,@SSTax,@MedTax,@PostTaxDed,@NetPay,
                1,GETDATE());

        SET @CurrentRow = @CurrentRow + 1;
    END  -- end employee loop

    -- ---- Step 4: Update run-level totals ----
    UPDATE PayrollRuns SET
        TotalGross      = (SELECT ISNULL(SUM(GrossPay),0)       FROM PayrollRunDetails WHERE RunId=@RunId AND Status=1),
        TotalFederalTax = (SELECT ISNULL(SUM(FederalTax),0)     FROM PayrollRunDetails WHERE RunId=@RunId AND Status=1),
        TotalStateTax   = (SELECT ISNULL(SUM(StateTax),0)       FROM PayrollRunDetails WHERE RunId=@RunId AND Status=1),
        TotalSSEmployee = (SELECT ISNULL(SUM(SocialSecurity),0) FROM PayrollRunDetails WHERE RunId=@RunId AND Status=1),
        TotalMedicare   = (SELECT ISNULL(SUM(Medicare),0)       FROM PayrollRunDetails WHERE RunId=@RunId AND Status=1),
        TotalDeductions = (SELECT ISNULL(SUM(PreTaxDeductions+PostTaxDeductions),0) FROM PayrollRunDetails WHERE RunId=@RunId AND Status=1),
        TotalNetPay     = (SELECT ISNULL(SUM(NetPay),0)         FROM PayrollRunDetails WHERE RunId=@RunId AND Status=1),
        EmployeeCount   = (SELECT COUNT(*) FROM PayrollRunDetails WHERE RunId=@RunId AND Status=1),
        Status          = 3,  -- 3=Calculated
        ProcessedDate   = GETDATE()
    WHERE RunId = @RunId;

    -- ---- Step 5: Vacation/sick accruals for the period ----
    -- Accrual rates: 1.54 hrs/period (approx 40hrs/year / 26 periods)
    -- Magic numbers throughout; no configurable table
    UPDATE e SET
        VacationBalance = e.VacationBalance + CASE
            WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 10 THEN 6.15
            WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 5  THEN 4.62
            WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 2  THEN 3.08
            ELSE 1.54 END,
        SickBalance = e.SickBalance + 1.54
    FROM Employees e
    WHERE e.EmployeeId IN (SELECT EmployeeId FROM @Employees);

    PRINT 'Payroll run ' + CAST(@RunId AS VARCHAR) + ' processed. Employees: ' + CAST(@TotalEmployees AS VARCHAR);
END
GO

-- =============================================
-- 34. usp_PayrollRun_UpdateStatus
-- =============================================
CREATE OR ALTER PROCEDURE usp_PayrollRun_UpdateStatus
    @RunId     INT,
    @NewStatus INT,
    @ChangedBy VARCHAR(100) = NULL,
    @Reason    VARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OldStatus INT;
    SELECT @OldStatus = Status FROM PayrollRuns WHERE RunId = @RunId;

    UPDATE PayrollRuns SET
        Status      = @NewStatus,
        VoidReason  = CASE WHEN @NewStatus = 6 THEN @Reason ELSE VoidReason END,
        VoidedDate  = CASE WHEN @NewStatus = 6 THEN GETDATE() ELSE VoidedDate END,
        ApprovedDate= CASE WHEN @NewStatus = 4 THEN GETDATE() ELSE ApprovedDate END,
        ApprovedBy  = CASE WHEN @NewStatus = 4 THEN @ChangedBy ELSE ApprovedBy END,
        PostedDate  = CASE WHEN @NewStatus = 5 THEN GETDATE() ELSE PostedDate END,
        PostedBy    = CASE WHEN @NewStatus = 5 THEN @ChangedBy ELSE PostedBy END
    WHERE RunId = @RunId;

    INSERT INTO AuditLog (TableName, RecordId, Action, ColumnName, OldValue, NewValue, ChangedBy)
    VALUES ('PayrollRuns', @RunId, 'UPDATE', 'Status', CAST(@OldStatus AS VARCHAR), CAST(@NewStatus AS VARCHAR), ISNULL(@ChangedBy, SYSTEM_USER));
END
GO

-- =============================================
-- 35. usp_Payroll_ApproveRun
-- =============================================
CREATE OR ALTER PROCEDURE usp_Payroll_ApproveRun
    @RunId      INT,
    @ApprovedBy VARCHAR(100),
    @Notes      VARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM PayrollRuns WHERE RunId=@RunId AND Status=3)  -- 3=Calculated
    BEGIN
        RAISERROR('Run must be in Calculated state to approve. RunId: %d', 16, 1, @RunId);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE PayrollRuns SET
            Status       = 4,  -- 4=Approved
            ApprovedDate = GETDATE(),
            ApprovedBy   = @ApprovedBy,
            Notes        = ISNULL(@Notes, Notes)
        WHERE RunId = @RunId;

        UPDATE PayrollRunDetails SET Status = 2  -- 2=Approved
        WHERE RunId = @RunId AND Status = 1;

        COMMIT;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH
END
GO

-- =============================================
-- 36. usp_Payroll_PostRun
-- Updates YTD balances on employee records
-- =============================================
CREATE OR ALTER PROCEDURE usp_Payroll_PostRun
    @RunId    INT,
    @PostedBy VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM PayrollRuns WHERE RunId=@RunId AND Status=4)  -- 4=Approved
    BEGIN
        RAISERROR('Run must be Approved before posting. RunId: %d', 16, 1, @RunId);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Update YTD on each employee
        UPDATE e SET
            YTDGross          = e.YTDGross          + d.GrossPay,
            YTDFederalTax     = e.YTDFederalTax     + d.FederalTax,
            YTDStateTax       = e.YTDStateTax       + d.StateTax,
            YTDSocialSecurity = e.YTDSocialSecurity + d.SocialSecurity,
            YTDMedicare       = e.YTDMedicare       + d.Medicare,
            YTDDeductions     = e.YTDDeductions     + d.PreTaxDeductions + d.PostTaxDeductions,
            ModifiedDate      = GETDATE()
        FROM Employees e
        JOIN PayrollRunDetails d ON d.EmployeeId = e.EmployeeId
        WHERE d.RunId = @RunId AND d.Status = 2;

        -- Update detail and run status
        UPDATE PayrollRunDetails SET Status = 3 WHERE RunId = @RunId AND Status = 2;  -- 3=Posted

        UPDATE PayrollRuns SET
            Status     = 5,  -- 5=Posted
            PostedDate = GETDATE(),
            PostedBy   = @PostedBy
        WHERE RunId = @RunId;

        COMMIT;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH
END
GO

-- =============================================
-- 37. usp_Payroll_VoidRun
-- =============================================
CREATE OR ALTER PROCEDURE usp_Payroll_VoidRun
    @RunId      INT,
    @VoidedBy   VARCHAR(100),
    @VoidReason VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentStatus INT;
    SELECT @CurrentStatus = Status FROM PayrollRuns WHERE RunId = @RunId;

    IF @CurrentStatus = 5  -- 5=Posted: must reverse YTD
    BEGIN
        BEGIN TRANSACTION;
        BEGIN TRY
            UPDATE e SET
                YTDGross          = e.YTDGross          - d.GrossPay,
                YTDFederalTax     = e.YTDFederalTax     - d.FederalTax,
                YTDStateTax       = e.YTDStateTax       - d.StateTax,
                YTDSocialSecurity = e.YTDSocialSecurity - d.SocialSecurity,
                YTDMedicare       = e.YTDMedicare       - d.Medicare,
                YTDDeductions     = e.YTDDeductions     - d.PreTaxDeductions - d.PostTaxDeductions
            FROM Employees e
            JOIN PayrollRunDetails d ON d.EmployeeId = e.EmployeeId
            WHERE d.RunId = @RunId;

            UPDATE PayrollRunDetails SET Status = 4 WHERE RunId = @RunId;  -- 4=Voided
            UPDATE PayrollRuns SET
                Status     = 6,  -- 6=Voided
                VoidedDate = GETDATE(),
                VoidReason = @VoidReason
            WHERE RunId = @RunId;

            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            THROW;
        END CATCH
    END
    ELSE IF @CurrentStatus IN (1,2,3,4)  -- Can void without YTD reversal
    BEGIN
        UPDATE PayrollRunDetails SET Status = 4 WHERE RunId = @RunId;
        UPDATE PayrollRuns SET Status=6, VoidedDate=GETDATE(), VoidReason=@VoidReason WHERE RunId=@RunId;
    END
    ELSE
        RAISERROR('Run cannot be voided from current status: %d', 16, 1, @CurrentStatus);
END
GO

-- =============================================
-- 38. usp_PayrollRun_GetDetails
-- =============================================
CREATE OR ALTER PROCEDURE usp_PayrollRun_GetDetails
    @RunId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        r.RunId,
        r.PayPeriodId,
        pp.PeriodName,
        pp.StartDate,
        pp.EndDate,
        pp.PayDate,
        r.RunNumber,
        r.RunType,
        CASE r.RunType WHEN 1 THEN 'Regular' WHEN 2 THEN 'Supplemental' WHEN 3 THEN 'Bonus' WHEN 4 THEN 'Correction' ELSE '?' END AS RunTypeLabel,
        r.Status,
        CASE r.Status WHEN 1 THEN 'Draft' WHEN 2 THEN 'Processing' WHEN 3 THEN 'Calculated' WHEN 4 THEN 'Approved' WHEN 5 THEN 'Posted' WHEN 6 THEN 'Voided' ELSE '?' END AS StatusLabel,
        r.TotalGross, r.TotalFederalTax, r.TotalStateTax,
        r.TotalSSEmployee, r.TotalMedicare, r.TotalDeductions, r.TotalNetPay,
        r.EmployeeCount, r.ProcessedDate, r.ApprovedDate, r.ApprovedBy,
        r.PostedDate, r.PostedBy, r.Notes
    FROM PayrollRuns r
    JOIN PayPeriods  pp ON pp.PayPeriodId = r.PayPeriodId
    WHERE r.RunId = @RunId;

    -- Employee detail lines
    SELECT
        d.DetailId, d.EmployeeId,
        e.EmployeeNumber,
        e.FirstName + ' ' + e.LastName AS FullName,
        dep.DepartmentName,
        d.RegularHours, d.OvertimeHours, d.VacationHours, d.SickHours,
        d.RegularPay, d.OvertimePay, d.VacationPay, d.SickPay,
        d.GrossPay, d.PreTaxDeductions, d.TaxableGross,
        d.FederalTax, d.StateTax, d.SocialSecurity, d.Medicare,
        d.PostTaxDeductions, d.NetPay,
        d.Status,
        CASE d.Status WHEN 1 THEN 'Calculated' WHEN 2 THEN 'Approved' WHEN 3 THEN 'Posted' WHEN 4 THEN 'Voided' ELSE '?' END AS StatusLabel,
        d.ErrorMessage
    FROM PayrollRunDetails d
    JOIN Employees   e   ON e.EmployeeId   = d.EmployeeId
    JOIN Departments dep ON dep.DepartmentId = e.DepartmentId
    WHERE d.RunId = @RunId
    ORDER BY e.LastName, e.FirstName;
END
GO

-- =============================================
-- 39. usp_Accrual_ProcessVacation
-- =============================================
CREATE OR ALTER PROCEDURE usp_Accrual_ProcessVacation
    @PayPeriodId INT
AS
BEGIN
    SET NOCOUNT ON;
    -- Magic accrual tiers based on tenure (no config table)
    INSERT INTO VacationAccrualLedger (EmployeeId, PayPeriodId, AccrualType,
        HoursAccrued, HoursUsed, BalanceBefore, BalanceAfter, Notes)
    SELECT
        e.EmployeeId,
        @PayPeriodId,
        'Vacation',
        AccrualRate = CASE
            WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 10 THEN 6.15  -- 160hrs/yr / 26
            WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 5  THEN 4.62  -- 120hrs/yr / 26
            WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 2  THEN 3.08  -- 80hrs/yr  / 26
            ELSE 1.54                                                     -- 40hrs/yr  / 26
        END,
        0,
        e.VacationBalance,
        e.VacationBalance + CASE
            WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 10 THEN 6.15
            WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 5  THEN 4.62
            WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 2  THEN 3.08
            ELSE 1.54 END,
        'BiWeekly accrual for PP ' + CAST(@PayPeriodId AS VARCHAR)
    FROM Employees e
    WHERE e.Status = 1 AND e.EmploymentType IN (1,2);  -- Active Full/Part-time

    UPDATE e SET
        VacationBalance = e.VacationBalance + CASE
            WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 10 THEN 6.15
            WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 5  THEN 4.62
            WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) >= 2  THEN 3.08
            ELSE 1.54 END
    FROM Employees e
    WHERE e.Status = 1 AND e.EmploymentType IN (1,2);
END
GO

-- =============================================
-- 40. usp_Accrual_ProcessSickTime
-- =============================================
CREATE OR ALTER PROCEDURE usp_Accrual_ProcessSickTime
    @PayPeriodId INT
AS
BEGIN
    SET NOCOUNT ON;
    -- Flat 1.54 hrs/period (40hrs/yr) regardless of tenure -- magic number
    INSERT INTO VacationAccrualLedger (EmployeeId, PayPeriodId, AccrualType,
        HoursAccrued, HoursUsed, BalanceBefore, BalanceAfter, Notes)
    SELECT
        e.EmployeeId, @PayPeriodId, 'Sick',
        1.54, 0, e.SickBalance, e.SickBalance + 1.54,
        'BiWeekly sick accrual PP ' + CAST(@PayPeriodId AS VARCHAR)
    FROM Employees e
    WHERE e.Status = 1 AND e.EmploymentType IN (1, 2);

    UPDATE Employees SET SickBalance = SickBalance + 1.54
    WHERE Status = 1 AND EmploymentType IN (1, 2);
END
GO

-- =============================================
-- 41. usp_PayPeriod_Close
-- =============================================
CREATE OR ALTER PROCEDURE usp_PayPeriod_Close
    @PayPeriodId INT,
    @ClosedBy    VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    -- Verify all runs are posted or voided
    IF EXISTS (SELECT 1 FROM PayrollRuns WHERE PayPeriodId=@PayPeriodId AND Status NOT IN (5,6))
    BEGIN
        RAISERROR('Cannot close period: one or more payroll runs are not Posted or Voided.', 16, 1);
        RETURN;
    END

    -- No transaction here -- if audit fails, period still gets closed (legacy)
    UPDATE PayPeriods SET Status = 3 WHERE PayPeriodId = @PayPeriodId;

    INSERT INTO AuditLog (TableName, RecordId, Action, ColumnName, NewValue, ChangedBy)
    VALUES ('PayPeriods', @PayPeriodId, 'UPDATE', 'Status', '3', @ClosedBy);
END
GO

-- =============================================
-- 42. usp_Batch_ReprocessErrors
-- Re-runs calculation for employees with error status in a run
-- =============================================
CREATE OR ALTER PROCEDURE usp_Batch_ReprocessErrors
    @RunId      INT,
    @ProcessedBy VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ErrEmployees TABLE (EmployeeId INT);
    INSERT INTO @ErrEmployees SELECT EmployeeId FROM PayrollRunDetails WHERE RunId=@RunId AND Status=4;

    DECLARE @EmpId   INT;
    DECLARE @ErrCur  CURSOR;
    SET @ErrCur = CURSOR FOR SELECT EmployeeId FROM @ErrEmployees;
    OPEN @ErrCur;
    FETCH NEXT FROM @ErrCur INTO @EmpId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Reset error status to allow recalculation
        UPDATE PayrollRunDetails SET Status=1, ErrorMessage=NULL WHERE RunId=@RunId AND EmployeeId=@EmpId;
        EXEC usp_Payroll_CalculateEmployee @RunId, @EmpId;
        FETCH NEXT FROM @ErrCur INTO @EmpId;
    END
    CLOSE @ErrCur;
    DEALLOCATE @ErrCur;

    -- Refresh run totals
    UPDATE PayrollRuns SET
        TotalGross      = (SELECT ISNULL(SUM(GrossPay),0)       FROM PayrollRunDetails WHERE RunId=@RunId AND Status=1),
        TotalNetPay     = (SELECT ISNULL(SUM(NetPay),0)         FROM PayrollRunDetails WHERE RunId=@RunId AND Status=1),
        EmployeeCount   = (SELECT COUNT(*) FROM PayrollRunDetails WHERE RunId=@RunId AND Status=1)
    WHERE RunId = @RunId;
END
GO

-- =============================================
-- 43. usp_YearEnd_Process
-- Generates W2 records, resets YTD balances
-- Multi-step, no outer transaction (legacy risk)
-- =============================================
CREATE OR ALTER PROCEDURE usp_YearEnd_Process
    @TaxYear     INT,
    @ProcessedBy VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Year-end processing for ' + CAST(@TaxYear AS VARCHAR) + '...';

    -- Step 1: Generate W2 records (calls usp_W2_Generate)
    EXEC usp_W2_Generate @TaxYear, @ProcessedBy;

    -- Step 2: Reset YTD counters for new year -- no transaction guard
    UPDATE Employees SET
        YTDGross          = 0,
        YTDFederalTax     = 0,
        YTDStateTax       = 0,
        YTDSocialSecurity = 0,
        YTDMedicare       = 0,
        YTDDeductions     = 0,
        ModifiedDate      = GETDATE(),
        ModifiedBy        = @ProcessedBy
    WHERE Status IN (1, 2);  -- Active and Leave

    -- Step 3: Cap vacation at max carryover (240 hrs) -- magic number
    UPDATE Employees SET
        VacationBalance = CASE WHEN VacationBalance > 240 THEN 240 ELSE VacationBalance END
    WHERE Status = 1;

    INSERT INTO AuditLog (TableName, RecordId, Action, ColumnName, NewValue, ChangedBy)
    VALUES ('Employees', 0, 'UPDATE', 'YTDReset', CAST(@TaxYear AS VARCHAR), @ProcessedBy);

    PRINT 'Year-end processing complete.';
END
GO

-- =============================================
-- 44. usp_W2_Generate
-- =============================================
CREATE OR ALTER PROCEDURE usp_W2_Generate
    @TaxYear     INT,
    @ProcessedBy VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    -- Remove existing W2s for year (allow regeneration)
    DELETE FROM W2Records WHERE TaxYear = @TaxYear;

    INSERT INTO W2Records (
        EmployeeId, TaxYear,
        Box1_Wages, Box2_FedTax,
        Box3_SS_Wages, Box4_SS_Tax,
        Box5_Med_Wages, Box6_Med_Tax,
        Box12a_Code, Box12a_Amount,
        Box16_StateWages, Box17_StateTax,
        GeneratedBy
    )
    SELECT
        e.EmployeeId,
        @TaxYear,
        e.YTDGross,           -- Box 1: taxable wages (simplified -- pre-tax deductions not subtracted here)
        e.YTDFederalTax,
        e.YTDGross,           -- Box 3: SS wages (simplified, cap not applied)
        e.YTDSocialSecurity,
        e.YTDGross,           -- Box 5: Medicare wages
        e.YTDMedicare,
        CASE WHEN EXISTS(SELECT 1 FROM EmployeeDeductions ed JOIN DeductionTypes dt ON dt.DeductionTypeId=ed.DeductionTypeId WHERE ed.EmployeeId=e.EmployeeId AND dt.TypeCode='401K') THEN 'D' ELSE NULL END,
        (SELECT ISNULL(SUM(CASE WHEN ed2.IsPercentage=1 THEN e.YTDGross*ed2.Amount/100.0 ELSE ed2.Amount*26 END),0)
         FROM EmployeeDeductions ed2 JOIN DeductionTypes dt2 ON dt2.DeductionTypeId=ed2.DeductionTypeId
         WHERE ed2.EmployeeId=e.EmployeeId AND dt2.TypeCode='401K' AND ed2.IsActive=1),
        e.YTDGross,
        e.YTDStateTax,
        @ProcessedBy
    FROM Employees e
    WHERE e.YTDGross > 0;

    PRINT CAST(@@ROWCOUNT AS VARCHAR) + ' W2 records generated for tax year ' + CAST(@TaxYear AS VARCHAR);
END
GO

-- =============================================
-- 45. usp_Report_PayrollSummary
-- =============================================
CREATE OR ALTER PROCEDURE usp_Report_PayrollSummary
    @FiscalYear INT = NULL,
    @PayPeriodId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FiscalYear IS NULL SET @FiscalYear = YEAR(GETDATE());

    SELECT
        pp.PeriodName,
        pp.StartDate,
        pp.EndDate,
        pp.PayDate,
        r.RunId,
        CASE r.RunType WHEN 1 THEN 'Regular' WHEN 2 THEN 'Supplemental' WHEN 3 THEN 'Bonus' WHEN 4 THEN 'Correction' ELSE '?' END AS RunType,
        CASE r.Status  WHEN 1 THEN 'Draft'   WHEN 2 THEN 'Processing' WHEN 3 THEN 'Calculated' WHEN 4 THEN 'Approved' WHEN 5 THEN 'Posted' WHEN 6 THEN 'Voided' ELSE '?' END AS RunStatus,
        r.EmployeeCount,
        r.TotalGross,
        r.TotalFederalTax,
        r.TotalStateTax,
        r.TotalSSEmployee,
        r.TotalMedicare,
        r.TotalDeductions,
        r.TotalNetPay,
        r.PostedDate
    FROM PayPeriods pp
    JOIN PayrollRuns r ON r.PayPeriodId = pp.PayPeriodId
    WHERE pp.FiscalYear = @FiscalYear
    AND   (@PayPeriodId IS NULL OR pp.PayPeriodId = @PayPeriodId)
    ORDER BY pp.PeriodNumber, r.RunNumber;
END
GO

-- =============================================
-- 46. usp_Report_EmployeeEarnings
-- =============================================
CREATE OR ALTER PROCEDURE usp_Report_EmployeeEarnings
    @EmployeeId  INT         = NULL,
    @DepartmentId INT        = NULL,
    @StartPeriod INT         = NULL,
    @EndPeriod   INT         = NULL,
    @FiscalYear  INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FiscalYear IS NULL SET @FiscalYear = YEAR(GETDATE());

    SELECT
        e.EmployeeNumber,
        e.FirstName + ' ' + e.LastName AS FullName,
        dep.DepartmentName,
        pp.PeriodName,
        pp.PayDate,
        d.RegularPay,
        d.OvertimePay,
        d.VacationPay,
        d.SickPay,
        d.BonusPay,
        d.GrossPay,
        d.PreTaxDeductions,
        d.FederalTax,
        d.StateTax,
        d.SocialSecurity,
        d.Medicare,
        d.PostTaxDeductions,
        d.NetPay
    FROM PayrollRunDetails d
    JOIN Employees   e   ON e.EmployeeId     = d.EmployeeId
    JOIN Departments dep ON dep.DepartmentId = e.DepartmentId
    JOIN PayrollRuns r   ON r.RunId          = d.RunId
    JOIN PayPeriods  pp  ON pp.PayPeriodId   = r.PayPeriodId
    WHERE pp.FiscalYear = @FiscalYear
    AND   d.Status      IN (2, 3)  -- Approved or Posted
    AND   (@EmployeeId   IS NULL OR e.EmployeeId    = @EmployeeId)
    AND   (@DepartmentId IS NULL OR e.DepartmentId  = @DepartmentId)
    AND   (@StartPeriod  IS NULL OR pp.PeriodNumber >= @StartPeriod)
    AND   (@EndPeriod    IS NULL OR pp.PeriodNumber <= @EndPeriod)
    ORDER BY e.LastName, e.FirstName, pp.PeriodNumber;
END
GO

-- =============================================
-- 47. usp_Report_TaxLiability
-- =============================================
CREATE OR ALTER PROCEDURE usp_Report_TaxLiability
    @FiscalYear  INT = NULL,
    @QuarterNum  INT = NULL  -- 1-4, NULL=all
AS
BEGIN
    SET NOCOUNT ON;
    IF @FiscalYear IS NULL SET @FiscalYear = YEAR(GETDATE());

    SELECT
        pp.FiscalYear,
        CASE
            WHEN MONTH(pp.PayDate) BETWEEN 1 AND 3  THEN 'Q1'
            WHEN MONTH(pp.PayDate) BETWEEN 4 AND 6  THEN 'Q2'
            WHEN MONTH(pp.PayDate) BETWEEN 7 AND 9  THEN 'Q3'
            ELSE 'Q4'
        END AS Quarter,
        SUM(r.TotalGross)      AS TotalGross,
        SUM(r.TotalFederalTax) AS TotalFederalTax,
        SUM(r.TotalStateTax)   AS TotalStateTax,
        SUM(r.TotalSSEmployee) AS EmployeeSSS,
        SUM(r.TotalSSEmployee) AS EmployerSS,  -- assumed matching -- bug: same column
        SUM(r.TotalMedicare)   AS EmployeeMed,
        SUM(r.TotalMedicare)   AS EmployerMed,
        SUM(r.TotalFederalTax + r.TotalStateTax + r.TotalSSEmployee * 2 + r.TotalMedicare * 2) AS TotalTaxLiability
    FROM PayrollRuns r
    JOIN PayPeriods  pp ON pp.PayPeriodId = r.PayPeriodId
    WHERE pp.FiscalYear = @FiscalYear
    AND   r.Status      IN (5)  -- Posted only
    AND   (@QuarterNum IS NULL OR
        CASE WHEN MONTH(pp.PayDate) BETWEEN 1 AND 3 THEN 1
             WHEN MONTH(pp.PayDate) BETWEEN 4 AND 6 THEN 2
             WHEN MONTH(pp.PayDate) BETWEEN 7 AND 9 THEN 3
             ELSE 4 END = @QuarterNum)
    GROUP BY pp.FiscalYear,
        CASE WHEN MONTH(pp.PayDate) BETWEEN 1 AND 3 THEN 'Q1'
             WHEN MONTH(pp.PayDate) BETWEEN 4 AND 6 THEN 'Q2'
             WHEN MONTH(pp.PayDate) BETWEEN 7 AND 9 THEN 'Q3'
             ELSE 'Q4' END
    ORDER BY Quarter;
END
GO

-- =============================================
-- 48. usp_Report_HeadcountByDepartment
-- =============================================
CREATE OR ALTER PROCEDURE usp_Report_HeadcountByDepartment
    @AsOfDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @AsOfDate IS NULL SET @AsOfDate = CAST(GETDATE() AS DATE);

    SELECT
        d.DepartmentCode,
        d.DepartmentName,
        d.CostCenter,
        COUNT(CASE WHEN e.Status = 1 AND e.EmploymentType = 1 THEN 1 END) AS FullTime,
        COUNT(CASE WHEN e.Status = 1 AND e.EmploymentType = 2 THEN 1 END) AS PartTime,
        COUNT(CASE WHEN e.Status = 1 AND e.EmploymentType = 3 THEN 1 END) AS Contractors,
        COUNT(CASE WHEN e.Status = 2                          THEN 1 END) AS OnLeave,
        COUNT(CASE WHEN e.Status = 1                          THEN 1 END) AS TotalActive,
        SUM(CASE  WHEN e.Status = 1 THEN e.AnnualSalary ELSE 0 END)       AS TotalAnnualSalary,
        AVG(CASE  WHEN e.Status = 1 THEN e.AnnualSalary ELSE NULL END)    AS AvgSalary
    FROM  Departments d
    LEFT JOIN Employees e ON e.DepartmentId = d.DepartmentId
        AND e.HireDate <= @AsOfDate
        AND (e.TerminationDate IS NULL OR e.TerminationDate > @AsOfDate)
    WHERE d.IsActive = 1
    GROUP BY d.DepartmentId, d.DepartmentCode, d.DepartmentName, d.CostCenter
    ORDER BY d.DepartmentName;
END
GO

-- =============================================
-- 49. usp_Report_DeductionsSummary
-- =============================================
CREATE OR ALTER PROCEDURE usp_Report_DeductionsSummary
    @PayPeriodId INT = NULL,
    @FiscalYear  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FiscalYear IS NULL SET @FiscalYear = YEAR(GETDATE());

    SELECT
        dt.TypeCode,
        dt.TypeName,
        dt.IsPreTax,
        COUNT(DISTINCT d.EmployeeId) AS EnrolledEmployees,
        SUM(CASE WHEN ed.IsPercentage=1 THEN d.GrossPay * ed.Amount / 100.0 ELSE ed.Amount END) AS TotalDeducted
    FROM PayrollRunDetails d
    JOIN PayrollRuns r   ON r.RunId          = d.RunId
    JOIN PayPeriods  pp  ON pp.PayPeriodId   = r.PayPeriodId
    JOIN EmployeeDeductions ed ON ed.EmployeeId = d.EmployeeId AND ed.IsActive = 1
    JOIN DeductionTypes dt ON dt.DeductionTypeId = ed.DeductionTypeId
    WHERE pp.FiscalYear  = @FiscalYear
    AND   d.Status       IN (2, 3)
    AND   (@PayPeriodId  IS NULL OR pp.PayPeriodId = @PayPeriodId)
    GROUP BY dt.DeductionTypeId, dt.TypeCode, dt.TypeName, dt.IsPreTax
    ORDER BY dt.IsPreTax DESC, dt.TypeName;
END
GO

PRINT 'All 49 stored procedures created successfully.';
GO
