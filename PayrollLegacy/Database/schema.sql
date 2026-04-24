-- =============================================
-- PayrollLegacy -- schema.sql
-- SQL Server 2019
-- Run this script first, then procedures.sql
-- =============================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'PayrollLegacy')
BEGIN
    ALTER DATABASE PayrollLegacy SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PayrollLegacy;
END
GO

CREATE DATABASE PayrollLegacy
    COLLATE SQL_Latin1_General_CP1_CI_AS;
GO

USE PayrollLegacy;
GO

-- =============================================
-- LOOKUP / REFERENCE TABLES
-- =============================================

CREATE TABLE Departments (
    DepartmentId    INT IDENTITY(1,1)  NOT NULL CONSTRAINT PK_Departments PRIMARY KEY,
    DepartmentCode  VARCHAR(10)        NOT NULL CONSTRAINT UQ_Departments_Code UNIQUE,
    DepartmentName  VARCHAR(100)       NOT NULL,
    ManagerId       INT                NULL,  -- FK added post-Employees creation
    CostCenter      VARCHAR(20)        NOT NULL,
    IsActive        BIT                NOT NULL CONSTRAINT DF_Departments_IsActive DEFAULT 1,
    CreatedDate     DATETIME           NOT NULL CONSTRAINT DF_Departments_Created DEFAULT GETDATE(),
    ModifiedDate    DATETIME           NOT NULL CONSTRAINT DF_Departments_Modified DEFAULT GETDATE()
);

CREATE TABLE PayGrades (
    PayGradeId       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PayGrades PRIMARY KEY,
    GradeCode        VARCHAR(10)       NOT NULL CONSTRAINT UQ_PayGrades_Code UNIQUE,
    GradeTitle       VARCHAR(50)       NOT NULL,
    MinSalary        DECIMAL(12,2)     NOT NULL,
    MaxSalary        DECIMAL(12,2)     NOT NULL,
    OvertimeEligible BIT               NOT NULL CONSTRAINT DF_PayGrades_OT DEFAULT 1,
    IsActive         BIT               NOT NULL CONSTRAINT DF_PayGrades_Active DEFAULT 1
);

CREATE TABLE EarningsTypes (
    EarningsTypeId     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EarningsTypes PRIMARY KEY,
    TypeCode           VARCHAR(20)       NOT NULL CONSTRAINT UQ_EarningsTypes_Code UNIQUE,
    TypeName           VARCHAR(100)      NOT NULL,
    IsTaxable          BIT               NOT NULL CONSTRAINT DF_EarningsTypes_Taxable  DEFAULT 1,
    IsOvertimeEligible BIT               NOT NULL CONSTRAINT DF_EarningsTypes_OTElig   DEFAULT 0,
    MultiplierRate     DECIMAL(5,4)      NOT NULL CONSTRAINT DF_EarningsTypes_Mult     DEFAULT 1.0,
    IsActive           BIT               NOT NULL CONSTRAINT DF_EarningsTypes_Active   DEFAULT 1
);

CREATE TABLE DeductionTypes (
    DeductionTypeId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DeductionTypes PRIMARY KEY,
    TypeCode        VARCHAR(20)       NOT NULL CONSTRAINT UQ_DeductionTypes_Code UNIQUE,
    TypeName        VARCHAR(100)      NOT NULL,
    IsPreTax        BIT               NOT NULL CONSTRAINT DF_DeductionTypes_PreTax  DEFAULT 0,
    IsPercentage    BIT               NOT NULL CONSTRAINT DF_DeductionTypes_Pct     DEFAULT 0,
    DefaultAmount   DECIMAL(12,2)     NOT NULL CONSTRAINT DF_DeductionTypes_Amt     DEFAULT 0,
    MaxAnnualAmount DECIMAL(12,2)     NULL,
    IsActive        BIT               NOT NULL CONSTRAINT DF_DeductionTypes_Active  DEFAULT 1,
    DisplayOrder    INT               NOT NULL CONSTRAINT DF_DeductionTypes_Order   DEFAULT 0
);

-- Federal Tax Brackets (marginal rates, 2024)
-- Status codes: 'Single', 'Married', 'MarriedSeparate', 'HeadOfHousehold'
CREATE TABLE FederalTaxBrackets (
    BracketId    INT IDENTITY(1,1)  NOT NULL CONSTRAINT PK_FederalTaxBrackets PRIMARY KEY,
    TaxYear      INT                NOT NULL,
    FilingStatus VARCHAR(20)        NOT NULL,
    MinIncome    DECIMAL(12,2)      NOT NULL,
    MaxIncome    DECIMAL(12,2)      NULL,
    TaxRate      DECIMAL(5,4)       NOT NULL,
    BaseAmount   DECIMAL(12,2)      NOT NULL CONSTRAINT DF_FedTax_Base DEFAULT 0,
    CONSTRAINT UQ_FederalTaxBrackets UNIQUE (TaxYear, FilingStatus, MinIncome)
);

CREATE TABLE StateTaxRates (
    StateRateId       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_StateTaxRates PRIMARY KEY,
    StateCode         VARCHAR(2)        NOT NULL,
    TaxYear           INT               NOT NULL,
    FlatRate          DECIMAL(5,4)      NOT NULL,
    StandardDeduction DECIMAL(12,2)     NOT NULL CONSTRAINT DF_StateTax_Ded DEFAULT 0,
    CONSTRAINT UQ_StateTaxRates UNIQUE (StateCode, TaxYear)
);

-- =============================================
-- EMPLOYEE TABLES
-- Status codes: 1=Active, 2=Leave, 3=Terminated, 4=Suspended, 5=Retired
-- EmploymentType:  1=FullTime, 2=PartTime, 3=Contractor, 4=Seasonal
-- =============================================

CREATE TABLE Employees (
    EmployeeId        INT IDENTITY(1,1)  NOT NULL CONSTRAINT PK_Employees PRIMARY KEY,
    EmployeeNumber    VARCHAR(20)        NOT NULL CONSTRAINT UQ_Employees_Number UNIQUE,
    FirstName         VARCHAR(50)        NOT NULL,
    LastName          VARCHAR(50)        NOT NULL,
    MiddleName        VARCHAR(50)        NULL,
    -- LEGACY: SSN stored as plain text -- no encryption applied
    SSN               VARCHAR(11)        NOT NULL,
    DateOfBirth       DATE               NOT NULL,
    HireDate          DATE               NOT NULL,
    TerminationDate   DATE               NULL,
    DepartmentId      INT                NOT NULL,
    PayGradeId        INT                NOT NULL,
    PositionTitle     VARCHAR(100)       NOT NULL,
    AnnualSalary      DECIMAL(12,2)      NOT NULL,
    HourlyRate        DECIMAL(10,4)      NULL,
    -- PayFrequency: 'Weekly','BiWeekly','SemiMonthly','Monthly'
    PayFrequency      VARCHAR(20)        NOT NULL CONSTRAINT DF_Emp_Freq    DEFAULT 'BiWeekly',
    FilingStatus      VARCHAR(20)        NOT NULL CONSTRAINT DF_Emp_Filing  DEFAULT 'Single',
    FederalAllowances INT                NOT NULL CONSTRAINT DF_Emp_Allow   DEFAULT 1,
    StateCode         VARCHAR(2)         NOT NULL CONSTRAINT DF_Emp_State   DEFAULT 'CA',
    WorkState         VARCHAR(2)         NOT NULL CONSTRAINT DF_Emp_WState  DEFAULT 'CA',
    -- Status magic numbers: 1=Active,2=Leave,3=Terminated,4=Suspended,5=Retired
    Status            INT                NOT NULL CONSTRAINT DF_Emp_Status  DEFAULT 1,
    -- EmploymentType: 1=FullTime,2=PartTime,3=Contractor,4=Seasonal
    EmploymentType    INT                NOT NULL CONSTRAINT DF_Emp_EmpType DEFAULT 1,
    Email             VARCHAR(255)       NULL,
    Phone             VARCHAR(20)        NULL,
    Address1          VARCHAR(200)       NULL,
    Address2          VARCHAR(200)       NULL,
    City              VARCHAR(100)       NULL,
    StateAddr         VARCHAR(2)         NULL,
    Zip               VARCHAR(10)        NULL,
    VacationBalance   DECIMAL(8,2)       NOT NULL CONSTRAINT DF_Emp_VacBal  DEFAULT 0,
    SickBalance       DECIMAL(8,2)       NOT NULL CONSTRAINT DF_Emp_SickBal DEFAULT 0,
    YTDGross          DECIMAL(12,2)      NOT NULL CONSTRAINT DF_Emp_YTDGross DEFAULT 0,
    YTDFederalTax     DECIMAL(12,2)      NOT NULL CONSTRAINT DF_Emp_YTDFed   DEFAULT 0,
    YTDStateTax       DECIMAL(12,2)      NOT NULL CONSTRAINT DF_Emp_YTDState DEFAULT 0,
    YTDSocialSecurity DECIMAL(12,2)      NOT NULL CONSTRAINT DF_Emp_YTDSS    DEFAULT 0,
    YTDMedicare       DECIMAL(12,2)      NOT NULL CONSTRAINT DF_Emp_YTDMed   DEFAULT 0,
    YTDDeductions     DECIMAL(12,2)      NOT NULL CONSTRAINT DF_Emp_YTDDed   DEFAULT 0,
    CreatedDate       DATETIME           NOT NULL CONSTRAINT DF_Emp_Created  DEFAULT GETDATE(),
    ModifiedDate      DATETIME           NOT NULL CONSTRAINT DF_Emp_Modified DEFAULT GETDATE(),
    CreatedBy         VARCHAR(100)       NOT NULL CONSTRAINT DF_Emp_CreatedBy  DEFAULT SYSTEM_USER,
    ModifiedBy        VARCHAR(100)       NOT NULL CONSTRAINT DF_Emp_ModifiedBy DEFAULT SYSTEM_USER,
    CONSTRAINT FK_Employees_Departments FOREIGN KEY (DepartmentId) REFERENCES Departments(DepartmentId),
    CONSTRAINT FK_Employees_PayGrades   FOREIGN KEY (PayGradeId)   REFERENCES PayGrades(PayGradeId)
);

CREATE TABLE EmployeeStatusHistory (
    StatusHistoryId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EmployeeStatusHistory PRIMARY KEY,
    EmployeeId      INT               NOT NULL,
    OldStatus       INT               NOT NULL,
    NewStatus       INT               NOT NULL,
    ChangeDate      DATETIME          NOT NULL CONSTRAINT DF_StatusHist_Date DEFAULT GETDATE(),
    ChangeReason    VARCHAR(500)      NULL,
    ChangedBy       VARCHAR(100)      NOT NULL CONSTRAINT DF_StatusHist_By DEFAULT SYSTEM_USER,
    CONSTRAINT FK_StatusHistory_Employees FOREIGN KEY (EmployeeId) REFERENCES Employees(EmployeeId)
);

CREATE TABLE EmployeeDeductions (
    EnrollmentId    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EmployeeDeductions PRIMARY KEY,
    EmployeeId      INT               NOT NULL,
    DeductionTypeId INT               NOT NULL,
    Amount          DECIMAL(12,2)     NOT NULL,
    IsPercentage    BIT               NOT NULL CONSTRAINT DF_EmpDed_Pct DEFAULT 0,
    EffectiveDate   DATE              NOT NULL,
    EndDate         DATE              NULL,
    IsActive        BIT               NOT NULL CONSTRAINT DF_EmpDed_Active DEFAULT 1,
    Notes           VARCHAR(500)      NULL,
    CreatedDate     DATETIME          NOT NULL CONSTRAINT DF_EmpDed_Created DEFAULT GETDATE(),
    CONSTRAINT FK_EmpDeductions_Employees     FOREIGN KEY (EmployeeId)      REFERENCES Employees(EmployeeId),
    CONSTRAINT FK_EmpDeductions_DeductionTypes FOREIGN KEY (DeductionTypeId) REFERENCES DeductionTypes(DeductionTypeId)
);

-- =============================================
-- PAYROLL TABLES
-- PayPeriod Status: 1=Open, 2=Processing, 3=Closed, 4=Reopened
-- PayrollRun Status: 1=Draft, 2=Processing, 3=Calculated, 4=Approved, 5=Posted, 6=Voided
-- PayrollRunDetail Status: 1=Calculated, 2=Approved, 3=Posted, 4=Voided
-- RunType: 1=Regular, 2=Supplemental, 3=Bonus, 4=Correction
-- =============================================

CREATE TABLE PayPeriods (
    PayPeriodId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PayPeriods PRIMARY KEY,
    PeriodName    VARCHAR(50)       NOT NULL,
    StartDate     DATE              NOT NULL,
    EndDate       DATE              NOT NULL,
    PayDate       DATE              NOT NULL,
    FiscalYear    INT               NOT NULL,
    PeriodNumber  INT               NOT NULL,
    -- Status: 1=Open, 2=Processing, 3=Closed, 4=Reopened
    Status        INT               NOT NULL CONSTRAINT DF_PayPeriods_Status DEFAULT 1,
    FrequencyType VARCHAR(20)       NOT NULL CONSTRAINT DF_PayPeriods_Freq   DEFAULT 'BiWeekly',
    CreatedDate   DATETIME          NOT NULL CONSTRAINT DF_PayPeriods_Created DEFAULT GETDATE(),
    CONSTRAINT UQ_PayPeriods UNIQUE (FiscalYear, PeriodNumber, FrequencyType)
);

CREATE TABLE PayrollRuns (
    RunId           INT IDENTITY(1,1)  NOT NULL CONSTRAINT PK_PayrollRuns PRIMARY KEY,
    PayPeriodId     INT                NOT NULL,
    RunNumber       INT                NOT NULL CONSTRAINT DF_Runs_Num DEFAULT 1,
    -- RunType: 1=Regular, 2=Supplemental, 3=Bonus, 4=Correction
    RunType         INT                NOT NULL CONSTRAINT DF_Runs_Type   DEFAULT 1,
    -- Status: 1=Draft, 2=Processing, 3=Calculated, 4=Approved, 5=Posted, 6=Voided
    Status          INT                NOT NULL CONSTRAINT DF_Runs_Status DEFAULT 1,
    TotalGross      DECIMAL(14,2)      NOT NULL CONSTRAINT DF_Runs_Gross  DEFAULT 0,
    TotalFederalTax DECIMAL(14,2)      NOT NULL CONSTRAINT DF_Runs_FedTax DEFAULT 0,
    TotalStateTax   DECIMAL(14,2)      NOT NULL CONSTRAINT DF_Runs_StTax  DEFAULT 0,
    TotalSSEmployee DECIMAL(14,2)      NOT NULL CONSTRAINT DF_Runs_SS     DEFAULT 0,
    TotalMedicare   DECIMAL(14,2)      NOT NULL CONSTRAINT DF_Runs_Med    DEFAULT 0,
    TotalDeductions DECIMAL(14,2)      NOT NULL CONSTRAINT DF_Runs_Ded    DEFAULT 0,
    TotalNetPay     DECIMAL(14,2)      NOT NULL CONSTRAINT DF_Runs_Net    DEFAULT 0,
    EmployeeCount   INT                NOT NULL CONSTRAINT DF_Runs_EmpCnt DEFAULT 0,
    ProcessedDate   DATETIME           NULL,
    ApprovedDate    DATETIME           NULL,
    ApprovedBy      VARCHAR(100)       NULL,
    PostedDate      DATETIME           NULL,
    PostedBy        VARCHAR(100)       NULL,
    VoidedDate      DATETIME           NULL,
    VoidReason      VARCHAR(500)       NULL,
    Notes           VARCHAR(1000)      NULL,
    CreatedDate     DATETIME           NOT NULL CONSTRAINT DF_Runs_Created  DEFAULT GETDATE(),
    CreatedBy       VARCHAR(100)       NOT NULL CONSTRAINT DF_Runs_CreatedBy DEFAULT SYSTEM_USER,
    CONSTRAINT FK_PayrollRuns_PayPeriods FOREIGN KEY (PayPeriodId) REFERENCES PayPeriods(PayPeriodId)
);

CREATE TABLE PayrollRunDetails (
    DetailId          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PayrollRunDetails PRIMARY KEY,
    RunId             INT               NOT NULL,
    EmployeeId        INT               NOT NULL,
    RegularHours      DECIMAL(8,2)      NOT NULL CONSTRAINT DF_Det_RegHrs  DEFAULT 0,
    OvertimeHours     DECIMAL(8,2)      NOT NULL CONSTRAINT DF_Det_OTHrs   DEFAULT 0,
    HolidayHours      DECIMAL(8,2)      NOT NULL CONSTRAINT DF_Det_HolHrs  DEFAULT 0,
    VacationHours     DECIMAL(8,2)      NOT NULL CONSTRAINT DF_Det_VacHrs  DEFAULT 0,
    SickHours         DECIMAL(8,2)      NOT NULL CONSTRAINT DF_Det_SickHrs DEFAULT 0,
    RegularPay        DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_RegPay  DEFAULT 0,
    OvertimePay       DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_OTPay   DEFAULT 0,
    HolidayPay        DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_HolPay  DEFAULT 0,
    VacationPay       DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_VacPay  DEFAULT 0,
    SickPay           DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_SickPay DEFAULT 0,
    BonusPay          DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_Bonus   DEFAULT 0,
    OtherEarnings     DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_Other   DEFAULT 0,
    GrossPay          DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_Gross   DEFAULT 0,
    PreTaxDeductions  DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_PreTax  DEFAULT 0,
    TaxableGross      DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_TaxGross DEFAULT 0,
    FederalTax        DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_FedTax  DEFAULT 0,
    StateTax          DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_StTax   DEFAULT 0,
    SocialSecurity    DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_SS      DEFAULT 0,
    Medicare          DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_Medicare DEFAULT 0,
    PostTaxDeductions DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_PostTax DEFAULT 0,
    NetPay            DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Det_Net     DEFAULT 0,
    CheckNumber       VARCHAR(20)       NULL,
    -- Status: 1=Calculated, 2=Approved, 3=Posted, 4=Voided
    Status            INT               NOT NULL CONSTRAINT DF_Det_Status  DEFAULT 1,
    ErrorMessage      VARCHAR(1000)     NULL,
    CalculatedDate    DATETIME          NULL,
    CONSTRAINT FK_PayrollDetails_Runs      FOREIGN KEY (RunId)       REFERENCES PayrollRuns(RunId),
    CONSTRAINT FK_PayrollDetails_Employees FOREIGN KEY (EmployeeId)  REFERENCES Employees(EmployeeId)
);

CREATE TABLE TimeEntries (
    TimeEntryId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TimeEntries PRIMARY KEY,
    EmployeeId    INT               NOT NULL,
    PayPeriodId   INT               NOT NULL,
    EntryDate     DATE              NOT NULL,
    RegularHours  DECIMAL(6,2)      NOT NULL CONSTRAINT DF_TE_Reg  DEFAULT 0,
    OvertimeHours DECIMAL(6,2)      NOT NULL CONSTRAINT DF_TE_OT   DEFAULT 0,
    HolidayHours  DECIMAL(6,2)      NOT NULL CONSTRAINT DF_TE_Hol  DEFAULT 0,
    VacationHours DECIMAL(6,2)      NOT NULL CONSTRAINT DF_TE_Vac  DEFAULT 0,
    SickHours     DECIMAL(6,2)      NOT NULL CONSTRAINT DF_TE_Sick DEFAULT 0,
    Notes         VARCHAR(500)      NULL,
    ApprovedBy    INT               NULL,
    ApprovedDate  DATETIME          NULL,
    -- Status: 1=Pending, 2=Approved, 3=Rejected
    Status        INT               NOT NULL CONSTRAINT DF_TE_Status DEFAULT 1,
    CreatedDate   DATETIME          NOT NULL CONSTRAINT DF_TE_Created DEFAULT GETDATE(),
    CONSTRAINT FK_TimeEntries_Employees  FOREIGN KEY (EmployeeId)  REFERENCES Employees(EmployeeId),
    CONSTRAINT FK_TimeEntries_PayPeriods FOREIGN KEY (PayPeriodId) REFERENCES PayPeriods(PayPeriodId)
);

CREATE TABLE VacationAccrualLedger (
    AccrualId       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VacationAccrualLedger PRIMARY KEY,
    EmployeeId      INT               NOT NULL,
    PayPeriodId     INT               NOT NULL,
    -- AccrualType: 'Vacation', 'Sick', 'PTO'
    AccrualType     VARCHAR(20)       NOT NULL,
    HoursAccrued    DECIMAL(8,2)      NOT NULL CONSTRAINT DF_Accr_Accrued  DEFAULT 0,
    HoursUsed       DECIMAL(8,2)      NOT NULL CONSTRAINT DF_Accr_Used     DEFAULT 0,
    HoursAdjusted   DECIMAL(8,2)      NOT NULL CONSTRAINT DF_Accr_Adj      DEFAULT 0,
    BalanceBefore   DECIMAL(8,2)      NOT NULL CONSTRAINT DF_Accr_Before   DEFAULT 0,
    BalanceAfter    DECIMAL(8,2)      NOT NULL CONSTRAINT DF_Accr_After    DEFAULT 0,
    TransactionDate DATETIME          NOT NULL CONSTRAINT DF_Accr_Date     DEFAULT GETDATE(),
    Notes           VARCHAR(500)      NULL,
    CONSTRAINT FK_VacAccrual_Employees  FOREIGN KEY (EmployeeId)  REFERENCES Employees(EmployeeId),
    CONSTRAINT FK_VacAccrual_PayPeriods FOREIGN KEY (PayPeriodId) REFERENCES PayPeriods(PayPeriodId)
);

CREATE TABLE W2Records (
    W2Id            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_W2Records PRIMARY KEY,
    EmployeeId      INT               NOT NULL,
    TaxYear         INT               NOT NULL,
    Box1_Wages      DECIMAL(12,2)     NOT NULL CONSTRAINT DF_W2_Box1  DEFAULT 0,
    Box2_FedTax     DECIMAL(12,2)     NOT NULL CONSTRAINT DF_W2_Box2  DEFAULT 0,
    Box3_SS_Wages   DECIMAL(12,2)     NOT NULL CONSTRAINT DF_W2_Box3  DEFAULT 0,
    Box4_SS_Tax     DECIMAL(12,2)     NOT NULL CONSTRAINT DF_W2_Box4  DEFAULT 0,
    Box5_Med_Wages  DECIMAL(12,2)     NOT NULL CONSTRAINT DF_W2_Box5  DEFAULT 0,
    Box6_Med_Tax    DECIMAL(12,2)     NOT NULL CONSTRAINT DF_W2_Box6  DEFAULT 0,
    Box12a_Code     VARCHAR(2)        NULL,
    Box12a_Amount   DECIMAL(12,2)     NULL,
    Box16_StateWages DECIMAL(12,2)    NOT NULL CONSTRAINT DF_W2_Box16 DEFAULT 0,
    Box17_StateTax  DECIMAL(12,2)     NOT NULL CONSTRAINT DF_W2_Box17 DEFAULT 0,
    GeneratedDate   DATETIME          NOT NULL CONSTRAINT DF_W2_GenDate DEFAULT GETDATE(),
    GeneratedBy     VARCHAR(100)      NOT NULL CONSTRAINT DF_W2_GenBy   DEFAULT SYSTEM_USER,
    CONSTRAINT UQ_W2Records UNIQUE (EmployeeId, TaxYear),
    CONSTRAINT FK_W2Records_Employees FOREIGN KEY (EmployeeId) REFERENCES Employees(EmployeeId)
);

CREATE TABLE AuditLog (
    AuditId     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AuditLog PRIMARY KEY,
    TableName   VARCHAR(100)      NOT NULL,
    RecordId    INT               NOT NULL,
    -- Action: 'INSERT', 'UPDATE', 'DELETE'
    Action      VARCHAR(20)       NOT NULL,
    ColumnName  VARCHAR(100)      NULL,
    OldValue    VARCHAR(MAX)      NULL,
    NewValue    VARCHAR(MAX)      NULL,
    ChangedBy   VARCHAR(100)      NOT NULL CONSTRAINT DF_Audit_By   DEFAULT SYSTEM_USER,
    ChangedDate DATETIME          NOT NULL CONSTRAINT DF_Audit_Date DEFAULT GETDATE(),
    IPAddress   VARCHAR(50)       NULL,
    SessionId   VARCHAR(100)      NULL
);

-- =============================================
-- INDEXES
-- =============================================

CREATE INDEX IX_Employees_DepartmentId  ON Employees(DepartmentId);
CREATE INDEX IX_Employees_PayGradeId    ON Employees(PayGradeId);
CREATE INDEX IX_Employees_Status        ON Employees(Status);
CREATE INDEX IX_Employees_LastName      ON Employees(LastName, FirstName);
CREATE INDEX IX_Employees_HireDate      ON Employees(HireDate);
CREATE INDEX IX_Employees_EmploymentType ON Employees(EmploymentType);

CREATE INDEX IX_PayrollRunDetails_RunId       ON PayrollRunDetails(RunId);
CREATE INDEX IX_PayrollRunDetails_EmployeeId  ON PayrollRunDetails(EmployeeId);
CREATE INDEX IX_PayrollRunDetails_Status      ON PayrollRunDetails(RunId, Status);

CREATE INDEX IX_TimeEntries_EmployeeId  ON TimeEntries(EmployeeId);
CREATE INDEX IX_TimeEntries_PayPeriodId ON TimeEntries(PayPeriodId);
CREATE INDEX IX_TimeEntries_EntryDate   ON TimeEntries(EntryDate);

CREATE INDEX IX_EmployeeDeductions_EmployeeId ON EmployeeDeductions(EmployeeId);
CREATE INDEX IX_EmployeeDeductions_Active     ON EmployeeDeductions(EmployeeId, IsActive);

CREATE INDEX IX_PayrollRuns_PayPeriodId ON PayrollRuns(PayPeriodId);
CREATE INDEX IX_PayrollRuns_Status      ON PayrollRuns(Status);

CREATE INDEX IX_AuditLog_Table_Record ON AuditLog(TableName, RecordId);
CREATE INDEX IX_AuditLog_ChangedDate  ON AuditLog(ChangedDate);

CREATE INDEX IX_W2Records_TaxYear ON W2Records(TaxYear);

-- Add FK from Departments to Employees (manager -- circular, added after Employees)
ALTER TABLE Departments ADD CONSTRAINT FK_Departments_Manager
    FOREIGN KEY (ManagerId) REFERENCES Employees(EmployeeId);

GO

-- =============================================
-- SEED DATA
-- =============================================

INSERT INTO Departments (DepartmentCode, DepartmentName, CostCenter) VALUES
('EXEC',  'Executive',              'CC-001'),
('HR',    'Human Resources',        'CC-010'),
('FIN',   'Finance & Accounting',   'CC-020'),
('IT',    'Information Technology', 'CC-030'),
('OPS',   'Operations',             'CC-040'),
('SALES', 'Sales & Marketing',      'CC-050'),
('ENG',   'Engineering',            'CC-060'),
('CS',    'Customer Service',       'CC-070');

INSERT INTO PayGrades (GradeCode, GradeTitle, MinSalary, MaxSalary, OvertimeEligible) VALUES
('G1', 'Entry Level',       30000.00,  50000.00, 1),
('G2', 'Associate',         45000.00,  70000.00, 1),
('G3', 'Mid-Level',         65000.00, 100000.00, 1),
('G4', 'Senior',            90000.00, 140000.00, 0),
('G5', 'Lead / Principal', 120000.00, 180000.00, 0),
('G6', 'Manager',          110000.00, 200000.00, 0),
('G7', 'Director',         150000.00, 280000.00, 0),
('G8', 'VP / Executive',   200000.00, 500000.00, 0);

INSERT INTO EarningsTypes (TypeCode, TypeName, IsTaxable, IsOvertimeEligible, MultiplierRate) VALUES
('REG',  'Regular Pay',            1, 1, 1.0000),
('OT15', 'Overtime 1.5x',          1, 0, 1.5000),
('OT20', 'Overtime 2.0x',          1, 0, 2.0000),
('HOL',  'Holiday Pay',             1, 0, 1.0000),
('VAC',  'Vacation Pay',            1, 0, 1.0000),
('SICK', 'Sick Pay',                1, 0, 1.0000),
('BONUS','Performance Bonus',       1, 0, 1.0000),
('SIGN', 'Sign-On Bonus',           1, 0, 1.0000),
('COMM', 'Commission',              1, 0, 1.0000),
('MISC', 'Miscellaneous Earnings',  1, 0, 1.0000);

INSERT INTO DeductionTypes (TypeCode, TypeName, IsPreTax, IsPercentage, DefaultAmount, MaxAnnualAmount, DisplayOrder) VALUES
('HEALTH_S', 'Health Insurance - Single',    1, 0,  250.00,     NULL, 10),
('HEALTH_F', 'Health Insurance - Family',    1, 0,  750.00,     NULL, 11),
('DENTAL_S', 'Dental Insurance - Single',    1, 0,   35.00,     NULL, 20),
('DENTAL_F', 'Dental Insurance - Family',    1, 0,   95.00,     NULL, 21),
('VISION',   'Vision Insurance',             1, 0,   15.00,     NULL, 30),
('401K',     '401(k) Contribution',          1, 1,    6.00, 23000.00, 40),
('HSA',      'Health Savings Account',       1, 0,  100.00,  4150.00, 50),
('LIFE_SUP', 'Supplemental Life Insurance',  0, 0,   25.00,     NULL, 60),
('GARNISH',  'Wage Garnishment',             0, 0,    0.00,     NULL, 70),
('CHARITY',  'Charitable Contribution',      0, 0,    0.00,     NULL, 80);

-- Federal Tax Brackets 2024 -- Single
INSERT INTO FederalTaxBrackets (TaxYear, FilingStatus, MinIncome, MaxIncome, TaxRate, BaseAmount) VALUES
(2024,'Single',         0.00,    11600.00, 0.1000,      0.00),
(2024,'Single',     11600.00,    47150.00, 0.1200,   1160.00),
(2024,'Single',     47150.00,   100525.00, 0.2200,   5426.00),
(2024,'Single',    100525.00,   191950.00, 0.2400,  17168.50),
(2024,'Single',    191950.00,   243725.00, 0.3200,  39110.50),
(2024,'Single',    243725.00,   609350.00, 0.3500,  55678.50),
(2024,'Single',    609350.00,         NULL,0.3700, 183647.25),
-- Married Filing Jointly
(2024,'Married',        0.00,    23200.00, 0.1000,      0.00),
(2024,'Married',    23200.00,    94300.00, 0.1200,   2320.00),
(2024,'Married',    94300.00,   201050.00, 0.2200,  10852.00),
(2024,'Married',   201050.00,   383900.00, 0.2400,  34337.00),
(2024,'Married',   383900.00,   487450.00, 0.3200,  78221.00),
(2024,'Married',   487450.00,   731200.00, 0.3500, 111357.00),
(2024,'Married',   731200.00,         NULL,0.3700, 196669.50);

-- State flat rates
INSERT INTO StateTaxRates (StateCode, TaxYear, FlatRate, StandardDeduction) VALUES
('CA', 2024, 0.0930, 5202.00),
('NY', 2024, 0.0685, 8000.00),
('TX', 2024, 0.0000,    0.00),
('FL', 2024, 0.0000,    0.00),
('WA', 2024, 0.0000,    0.00),
('IL', 2024, 0.0495, 2425.00),
('GA', 2024, 0.0549, 5400.00),
('OH', 2024, 0.0399, 2400.00);

-- Pay Periods -- BiWeekly 2024 (26 periods)
DECLARE @PP_Start DATE = '2024-01-01';
DECLARE @PP_Num   INT  = 1;
WHILE @PP_Start <= '2024-12-31'
BEGIN
    DECLARE @PP_End  DATE = DATEADD(DAY, 13, @PP_Start);
    DECLARE @PP_Pay  DATE = DATEADD(DAY,  5, @PP_End);
    IF @PP_End > '2024-12-31' SET @PP_End = '2024-12-31';
    INSERT INTO PayPeriods (PeriodName, StartDate, EndDate, PayDate, FiscalYear, PeriodNumber, Status, FrequencyType)
    VALUES (
        'PP' + RIGHT('0' + CAST(@PP_Num AS VARCHAR(2)), 2) + '-2024',
        @PP_Start, @PP_End, @PP_Pay, 2024, @PP_Num,
        CASE WHEN @PP_Start < '2024-04-01' THEN 3 ELSE 1 END,  -- first 6 periods closed
        'BiWeekly'
    );
    SET @PP_Start = DATEADD(DAY, 14, @PP_Start);
    SET @PP_Num   = @PP_Num + 1;
END;
GO

-- Employees (20 records)
INSERT INTO Employees (EmployeeNumber,FirstName,LastName,SSN,DateOfBirth,HireDate,
    DepartmentId,PayGradeId,PositionTitle,AnnualSalary,HourlyRate,
    FilingStatus,StateCode,WorkState,Status,EmploymentType,
    Email,Phone,Address1,City,StateAddr,Zip)
VALUES
('EMP001','Robert',   'Johnson',  '111-22-3333','1975-03-15','2010-06-01',1,8,'Chief Executive Officer',         480000.00,NULL,'Married','CA','CA',1,1,'rjohnson@company.com',  '555-0101','100 Executive Blvd','San Francisco','CA','94102'),
('EMP002','Patricia', 'Williams', '222-33-4444','1980-07-22','2012-03-15',2,7,'VP Human Resources',              195000.00,NULL,'Married','CA','CA',1,1,'pwilliams@company.com', '555-0102','200 Corporate Ave',  'San Francisco','CA','94103'),
('EMP003','Michael',  'Brown',    '333-44-5555','1978-11-30','2011-08-20',3,7,'Chief Financial Officer',         210000.00,NULL,'Married','CA','CA',1,1,'mbrown@company.com',    '555-0103','300 Finance St',     'Oakland',       'CA','94601'),
('EMP004','Jennifer', 'Davis',    '444-55-6666','1985-04-10','2015-01-12',4,7,'VP Information Technology',       185000.00,NULL,'Single', 'CA','CA',1,1,'jdavis@company.com',    '555-0104','400 Tech Drive',     'San Jose',      'CA','95101'),
('EMP005','James',    'Miller',   '555-66-7777','1982-09-05','2013-05-20',5,6,'Operations Manager',              130000.00,NULL,'Married','CA','CA',1,1,'jmiller@company.com',   '555-0105','500 Ops Way',        'Fremont',       'CA','94538'),
('EMP006','Linda',    'Wilson',   '666-77-8888','1990-02-14','2018-09-01',2,4,'Senior HR Business Partner',       95000.00,NULL,'Single', 'CA','CA',1,1,'lwilson@company.com',   '555-0106','600 People Ave',     'Berkeley',      'CA','94710'),
('EMP007','David',    'Moore',    '777-88-9999','1988-06-25','2017-02-28',3,4,'Senior Financial Analyst',         92000.00,NULL,'Married','NY','NY',1,1,'dmoore@company.com',    '555-0107','700 Wall Street',    'New York',      'NY','10005'),
('EMP008','Barbara',  'Taylor',   '888-99-0000','1992-12-08','2019-06-15',4,3,'Software Engineer II',             82000.00,NULL,'Single', 'CA','CA',1,1,'btaylor@company.com',   '555-0108','800 Code Lane',      'San Jose',      'CA','95112'),
('EMP009','Richard',  'Anderson', '999-00-1111','1987-08-17','2016-11-01',4,4,'Senior Software Engineer',        105000.00,NULL,'Married','TX','TX',1,1,'randerson@company.com', '555-0109','900 Dev Road',       'Austin',        'TX','78701'),
('EMP010','Susan',    'Thomas',   '101-20-3040','1993-03-29','2020-02-03',6,3,'Marketing Specialist',             72000.00,NULL,'Single', 'CA','CA',1,1,'sthomas@company.com',   '555-0110','1000 Market St',     'San Francisco', 'CA','94105'),
('EMP011','Joseph',   'Jackson',  '111-20-3041','1984-05-11','2014-07-14',6,5,'Sales Director',                  145000.00,NULL,'Married','CA','CA',1,1,'jjackson@company.com',  '555-0111','1100 Sales Blvd',    'Los Angeles',   'CA','90001'),
('EMP012','Margaret', 'White',    '121-20-3042','1991-10-03','2019-03-25',7,3,'Junior Engineer',                  68000.00,NULL,'Single', 'CA','CA',1,1,'mwhite@company.com',    '555-0112','1200 Build Ave',     'Palo Alto',     'CA','94301'),
('EMP013','Charles',  'Harris',   '131-20-3043','1979-07-16','2011-12-01',7,5,'Principal Engineer',              155000.00,NULL,'Married','CA','CA',1,1,'charris@company.com',   '555-0113','1300 Circuit Dr',    'Santa Clara',   'CA','95050'),
('EMP014','Dorothy',  'Martin',   '141-20-3044','1994-01-22','2021-08-16',8,2,'Customer Service Associate',       48000.00,23.0769,'Single','CA','CA',1,1,'dmartin@company.com',  '555-0114','1400 Service Way',   'Sacramento',    'CA','95814'),
('EMP015','Thomas',   'Garcia',   '151-20-3045','1986-04-07','2015-10-05',5,3,'Operations Analyst',               76000.00,NULL,'Single', 'CA','CA',1,1,'tgarcia@company.com',   '555-0115','1500 Ops Lane',      'Stockton',      'CA','95201'),
('EMP016','Nancy',    'Martinez', '161-20-3046','1996-09-18','2022-01-10',4,1,'Junior Developer',                 52000.00,25.0000,'Single','CA','CA',1,1,'nmartinez@company.com', '555-0116','1600 Startup Ave',   'San Jose',      'CA','95110'),
('EMP017','Mark',     'Robinson', '171-20-3047','1983-11-25','2013-09-30',3,4,'Finance Manager',                  98000.00,NULL,'Married','IL','IL',1,1,'mrobinson@company.com', '555-0117','1700 Finance Blvd',  'Chicago',       'IL','60601'),
('EMP018','Sandra',   'Clark',    '181-20-3048','1997-06-12','2022-05-23',8,1,'CS Representative',                44000.00,21.1538,'Single','CA','CA',1,1,'sclark@company.com',   '555-0118','1800 Help St',       'Modesto',       'CA','95350'),
('EMP019','Paul',     'Rodriguez','191-20-3049','1975-08-30','2009-04-15',1,6,'General Counsel',                 175000.00,NULL,'Married','CA','CA',1,1,'prodriguez@company.com','555-0119','1900 Legal Way',     'San Francisco', 'CA','94111'),
('EMP020','Betty',    'Lewis',    '201-20-3050','1989-02-06','2018-11-19',2,3,'HR Generalist',                    71000.00,NULL,'Married','GA','GA',3,1,'blewis@company.com',    '555-0120','2000 HR Drive',       'Atlanta',       'GA','30301');
GO

UPDATE Employees SET TerminationDate = '2024-02-29' WHERE EmployeeNumber = 'EMP020';
GO

-- Set department managers
UPDATE Departments SET ManagerId=(SELECT EmployeeId FROM Employees WHERE EmployeeNumber='EMP001') WHERE DepartmentCode='EXEC';
UPDATE Departments SET ManagerId=(SELECT EmployeeId FROM Employees WHERE EmployeeNumber='EMP002') WHERE DepartmentCode='HR';
UPDATE Departments SET ManagerId=(SELECT EmployeeId FROM Employees WHERE EmployeeNumber='EMP003') WHERE DepartmentCode='FIN';
UPDATE Departments SET ManagerId=(SELECT EmployeeId FROM Employees WHERE EmployeeNumber='EMP004') WHERE DepartmentCode='IT';
UPDATE Departments SET ManagerId=(SELECT EmployeeId FROM Employees WHERE EmployeeNumber='EMP005') WHERE DepartmentCode='OPS';
UPDATE Departments SET ManagerId=(SELECT EmployeeId FROM Employees WHERE EmployeeNumber='EMP011') WHERE DepartmentCode='SALES';
UPDATE Departments SET ManagerId=(SELECT EmployeeId FROM Employees WHERE EmployeeNumber='EMP013') WHERE DepartmentCode='ENG';
GO

-- Enroll all full-time active employees in basic benefits
INSERT INTO EmployeeDeductions (EmployeeId, DeductionTypeId, Amount, IsPercentage, EffectiveDate, IsActive)
SELECT e.EmployeeId, dt.DeductionTypeId, dt.DefaultAmount, 0, e.HireDate, 1
FROM   Employees e
CROSS JOIN DeductionTypes dt
WHERE  dt.TypeCode IN ('HEALTH_S','DENTAL_S','VISION')
AND    e.Status = 1 AND e.EmploymentType = 1;

-- Upgrade married employees to family health plan
UPDATE ed
SET    ed.DeductionTypeId = (SELECT DeductionTypeId FROM DeductionTypes WHERE TypeCode='HEALTH_F'),
       ed.Amount          = (SELECT DefaultAmount   FROM DeductionTypes WHERE TypeCode='HEALTH_F')
FROM   EmployeeDeductions ed
JOIN   Employees      e  ON e.EmployeeId      = ed.EmployeeId
JOIN   DeductionTypes dt ON dt.DeductionTypeId= ed.DeductionTypeId
WHERE  dt.TypeCode = 'HEALTH_S' AND e.FilingStatus = 'Married';

-- 401k for salary >= 70k
INSERT INTO EmployeeDeductions (EmployeeId, DeductionTypeId, Amount, IsPercentage, EffectiveDate, IsActive)
SELECT e.EmployeeId, dt.DeductionTypeId, 6.00, 1, e.HireDate, 1
FROM   Employees e
CROSS JOIN DeductionTypes dt
WHERE  dt.TypeCode = '401K'
AND    e.AnnualSalary >= 70000 AND e.Status = 1;

-- HSA for high earners
INSERT INTO EmployeeDeductions (EmployeeId, DeductionTypeId, Amount, IsPercentage, EffectiveDate, IsActive)
SELECT e.EmployeeId, dt.DeductionTypeId, dt.DefaultAmount, 0, e.HireDate, 1
FROM   Employees e
CROSS JOIN DeductionTypes dt
WHERE  dt.TypeCode = 'HSA'
AND    e.AnnualSalary >= 90000 AND e.Status = 1;
GO

-- YTD balances simulating 6 closed pay periods (Q1 2024)
UPDATE Employees SET
    YTDGross          = ROUND(AnnualSalary / 26.0 * 6, 2),
    YTDFederalTax     = ROUND(AnnualSalary / 26.0 * 6 * 0.22, 2),
    YTDStateTax       = ROUND(AnnualSalary / 26.0 * 6 * 0.0693, 2),
    YTDSocialSecurity = ROUND(CASE WHEN AnnualSalary > 168600 THEN 168600 ELSE AnnualSalary END / 26.0 * 6 * 0.062, 2),
    YTDMedicare       = ROUND(AnnualSalary / 26.0 * 6 * 0.0145, 2)
WHERE Status IN (1, 2);

-- Accrued leave balances
UPDATE Employees SET
    VacationBalance = CASE
        WHEN DATEDIFF(YEAR, HireDate, GETDATE()) >= 10 THEN 160.00
        WHEN DATEDIFF(YEAR, HireDate, GETDATE()) >= 5  THEN 120.00
        WHEN DATEDIFF(YEAR, HireDate, GETDATE()) >= 2  THEN 80.00
        ELSE 40.00
    END,
    SickBalance = 40.00
WHERE Status = 1;
GO

PRINT 'PayrollLegacy schema and seed data created successfully.';
GO
