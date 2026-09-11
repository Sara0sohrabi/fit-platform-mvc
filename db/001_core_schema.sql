/*
 Gymmap / Soura Home Gym - Core database schema
 SQL Server / SQL Server Express compatible

 Flow:
 User -> Role (Student / Gym / Coach)
 Gym -> Class -> Schedule -> Sessions
 Student -> Enrollment -> Package -> Payment -> Admin approval
 Enrollment -> Attendance
 Notifications are generated for class/session/payment events.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------- Security / users ---------- */
IF OBJECT_ID(N'dbo.Roles', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.Roles (
   Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Roles PRIMARY KEY,
   Code NVARCHAR(30) NOT NULL CONSTRAINT UQ_Roles_Code UNIQUE,
   NameFa NVARCHAR(50) NOT NULL,
   IsActive BIT NOT NULL CONSTRAINT DF_Roles_IsActive DEFAULT 1
 );
END;
GO

IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.Users (
   Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
   Mobile NVARCHAR(20) NOT NULL CONSTRAINT UQ_Users_Mobile UNIQUE,
   Email NVARCHAR(254) NULL,
   PasswordHash NVARCHAR(500) NULL,
   FullName NVARCHAR(150) NOT NULL,
   IsMobileVerified BIT NOT NULL CONSTRAINT DF_Users_IsMobileVerified DEFAULT 0,
   IsActive BIT NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT 1,
   CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME(),
   LastLoginAt DATETIME2 NULL
 );
END;
GO

IF OBJECT_ID(N'dbo.UserRoles', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.UserRoles (
   UserId BIGINT NOT NULL,
   RoleId INT NOT NULL,
   CONSTRAINT PK_UserRoles PRIMARY KEY(UserId, RoleId),
   CONSTRAINT FK_UserRoles_User FOREIGN KEY(UserId) REFERENCES dbo.Users(Id),
   CONSTRAINT FK_UserRoles_Role FOREIGN KEY(RoleId) REFERENCES dbo.Roles(Id)
 );
END;
GO

INSERT INTO dbo.Roles(Code,NameFa) VALUES
(N'STUDENT',N'شاگرد'),
(N'GYM',N'باشگاه ورزشی'),
(N'COACH',N'مربی'),
(N'ADMIN',N'مدیر سیستم');
GO

/* ---------- Gym / location ---------- */
IF OBJECT_ID(N'dbo.Gyms', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.Gyms (
   Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Gyms PRIMARY KEY,
   OwnerUserId BIGINT NOT NULL,
   Name NVARCHAR(150) NOT NULL,
   Description NVARCHAR(1000) NULL,
   Address NVARCHAR(500) NULL,
   City NVARCHAR(100) NULL,
   Latitude DECIMAL(10,7) NULL,
   Longitude DECIMAL(10,7) NULL,
   Phone NVARCHAR(30) NULL,
   IsApproved BIT NOT NULL CONSTRAINT DF_Gyms_IsApproved DEFAULT 0,
   IsActive BIT NOT NULL CONSTRAINT DF_Gyms_IsActive DEFAULT 1,
   CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Gyms_CreatedAt DEFAULT SYSUTCDATETIME(),
   CONSTRAINT FK_Gyms_Owner FOREIGN KEY(OwnerUserId) REFERENCES dbo.Users(Id)
 );
END;
GO

/* ---------- Student / coach profiles ---------- */
IF OBJECT_ID(N'dbo.StudentProfiles', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.StudentProfiles (
   UserId BIGINT NOT NULL CONSTRAINT PK_StudentProfiles PRIMARY KEY,
   BirthDate DATE NULL,
   Gender NVARCHAR(20) NULL,
   EmergencyContact NVARCHAR(150) NULL,
   EmergencyMobile NVARCHAR(20) NULL,
   CONSTRAINT FK_StudentProfiles_User FOREIGN KEY(UserId) REFERENCES dbo.Users(Id)
 );
END;
GO

IF OBJECT_ID(N'dbo.CoachProfiles', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.CoachProfiles (
   UserId BIGINT NOT NULL CONSTRAINT PK_CoachProfiles PRIMARY KEY,
   Bio NVARCHAR(1000) NULL,
   Specialties NVARCHAR(500) NULL,
   PhotoUrl NVARCHAR(500) NULL,
   IsApproved BIT NOT NULL CONSTRAINT DF_CoachProfiles_IsApproved DEFAULT 0,
   CONSTRAINT FK_CoachProfiles_User FOREIGN KEY(UserId) REFERENCES dbo.Users(Id)
 );
END;
GO

IF OBJECT_ID(N'dbo.GymCoaches', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.GymCoaches (
   GymId BIGINT NOT NULL,
   CoachUserId BIGINT NOT NULL,
   IsActive BIT NOT NULL CONSTRAINT DF_GymCoaches_IsActive DEFAULT 1,
   CONSTRAINT PK_GymCoaches PRIMARY KEY(GymId,CoachUserId),
   CONSTRAINT FK_GymCoaches_Gym FOREIGN KEY(GymId) REFERENCES dbo.Gyms(Id),
   CONSTRAINT FK_GymCoaches_Coach FOREIGN KEY(CoachUserId) REFERENCES dbo.Users(Id)
 );
END;
GO

/* ---------- Sports master: db/sports.sql is the seed/source of truth ---------- */
/* Sports(Id, NameFa, NameEn, CategoryFa, IsActive, SortOrder, CreatedAt) */

/* ---------- Classes ---------- */
IF OBJECT_ID(N'dbo.Classes', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.Classes (
   Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Classes PRIMARY KEY,
   GymId BIGINT NOT NULL,
   SportId INT NOT NULL,
   CoachUserId BIGINT NULL,
   Title NVARCHAR(150) NOT NULL,
   Description NVARCHAR(1000) NULL,
   Capacity INT NOT NULL,
   StartDate DATE NOT NULL,
   EndDate DATE NOT NULL,
   Status NVARCHAR(30) NOT NULL CONSTRAINT DF_Classes_Status DEFAULT N'DRAFT',
   CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Classes_CreatedAt DEFAULT SYSUTCDATETIME(),
   CONSTRAINT CK_Classes_Capacity CHECK(Capacity > 0),
   CONSTRAINT CK_Classes_Dates CHECK(EndDate >= StartDate),
   CONSTRAINT FK_Classes_Gym FOREIGN KEY(GymId) REFERENCES dbo.Gyms(Id),
   CONSTRAINT FK_Classes_Sport FOREIGN KEY(SportId) REFERENCES dbo.Sports(Id),
   CONSTRAINT FK_Classes_Coach FOREIGN KEY(CoachUserId) REFERENCES dbo.Users(Id)
 );
END;
GO

/* Schedule supports فرد / زوج as well as explicit weekdays. Weekday: 0=Saturday ... 6=Friday */
IF OBJECT_ID(N'dbo.ClassSchedules', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.ClassSchedules (
   Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ClassSchedules PRIMARY KEY,
   ClassId BIGINT NOT NULL,
   DayType NVARCHAR(10) NOT NULL, /* ODD, EVEN, WEEKDAY */
   WeekdayNo TINYINT NULL,
   StartTime TIME(0) NOT NULL,
   EndTime TIME(0) NOT NULL,
   CONSTRAINT CK_ClassSchedules_DayType CHECK(DayType IN(N'ODD',N'EVEN',N'WEEKDAY')),
   CONSTRAINT CK_ClassSchedules_Weekday CHECK((DayType=N'WEEKDAY' AND WeekdayNo BETWEEN 0 AND 6) OR DayType IN(N'ODD',N'EVEN')),
   CONSTRAINT CK_ClassSchedules_Time CHECK(EndTime > StartTime),
   CONSTRAINT FK_ClassSchedules_Class FOREIGN KEY(ClassId) REFERENCES dbo.Classes(Id)
 );
END;
GO

/* Actual occurrences shown on calendars and used for attendance */
IF OBJECT_ID(N'dbo.ClassSessions', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.ClassSessions (
   Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ClassSessions PRIMARY KEY,
   ClassId BIGINT NOT NULL,
   ScheduleId BIGINT NULL,
   SessionDate DATE NOT NULL,
   StartTime TIME(0) NOT NULL,
   EndTime TIME(0) NOT NULL,
   SessionNumber INT NULL,
   Status NVARCHAR(20) NOT NULL CONSTRAINT DF_ClassSessions_Status DEFAULT N'SCHEDULED',
   CONSTRAINT UQ_ClassSessions UNIQUE(ClassId,SessionDate,StartTime),
   CONSTRAINT FK_ClassSessions_Class FOREIGN KEY(ClassId) REFERENCES dbo.Classes(Id),
   CONSTRAINT FK_ClassSessions_Schedule FOREIGN KEY(ScheduleId) REFERENCES dbo.ClassSchedules(Id)
 );
END;
GO

/* ---------- Packages / fees ---------- */
IF OBJECT_ID(N'dbo.Packages', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.Packages (
   Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Packages PRIMARY KEY,
   ClassId BIGINT NOT NULL,
   Title NVARCHAR(100) NOT NULL,
   SessionCount INT NOT NULL,
   Price DECIMAL(18,2) NOT NULL,
   ValidityDays INT NULL,
   IsActive BIT NOT NULL CONSTRAINT DF_Packages_IsActive DEFAULT 1,
   CONSTRAINT CK_Packages_SessionCount CHECK(SessionCount IN(4,8,12) OR SessionCount > 0),
   CONSTRAINT CK_Packages_Price CHECK(Price >= 0),
   CONSTRAINT FK_Packages_Class FOREIGN KEY(ClassId) REFERENCES dbo.Classes(Id)
 );
END;
GO

/* ---------- Student registration ---------- */
IF OBJECT_ID(N'dbo.Enrollments', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.Enrollments (
   Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Enrollments PRIMARY KEY,
   StudentUserId BIGINT NOT NULL,
   ClassId BIGINT NOT NULL,
   PackageId BIGINT NOT NULL,
   RequestedAt DATETIME2 NOT NULL CONSTRAINT DF_Enrollments_RequestedAt DEFAULT SYSUTCDATETIME(),
   ApprovedAt DATETIME2 NULL,
   StartDate DATE NULL,
   EndDate DATE NULL,
   Status NVARCHAR(30) NOT NULL CONSTRAINT DF_Enrollments_Status DEFAULT N'PAYMENT_PENDING',
   SessionsPurchased INT NOT NULL,
   SessionsUsed INT NOT NULL CONSTRAINT DF_Enrollments_SessionsUsed DEFAULT 0,
   SessionsRemaining AS (SessionsPurchased-SessionsUsed) PERSISTED,
   CONSTRAINT CK_Enrollments_Status CHECK(Status IN(N'PAYMENT_PENDING',N'REVIEW',N'ACTIVE',N'REJECTED',N'EXPIRED',N'CANCELLED')),
   CONSTRAINT FK_Enrollments_Student FOREIGN KEY(StudentUserId) REFERENCES dbo.Users(Id),
   CONSTRAINT FK_Enrollments_Class FOREIGN KEY(ClassId) REFERENCES dbo.Classes(Id),
   CONSTRAINT FK_Enrollments_Package FOREIGN KEY(PackageId) REFERENCES dbo.Packages(Id)
 );
END;
GO

/* ---------- Card transfer / manual payment approval ---------- */
IF OBJECT_ID(N'dbo.Payments', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.Payments (
   Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Payments PRIMARY KEY,
   EnrollmentId BIGINT NOT NULL,
   Amount DECIMAL(18,2) NOT NULL,
   Method NVARCHAR(30) NOT NULL CONSTRAINT DF_Payments_Method DEFAULT N'CARD_TRANSFER',
   PaidAt DATETIME2 NULL,
   TrackingCode NVARCHAR(100) NULL,
   ReceiptUrl NVARCHAR(500) NULL,
   Status NVARCHAR(30) NOT NULL CONSTRAINT DF_Payments_Status DEFAULT N'PENDING',
   ReviewedByUserId BIGINT NULL,
   ReviewedAt DATETIME2 NULL,
   ReviewNote NVARCHAR(500) NULL,
   CONSTRAINT CK_Payments_Status CHECK(Status IN(N'PENDING',N'APPROVED',N'REJECTED')),
   CONSTRAINT CK_Payments_Amount CHECK(Amount >= 0),
   CONSTRAINT FK_Payments_Enrollment FOREIGN KEY(EnrollmentId) REFERENCES dbo.Enrollments(Id),
   CONSTRAINT FK_Payments_Reviewer FOREIGN KEY(ReviewedByUserId) REFERENCES dbo.Users(Id)
 );
END;
GO

/* ---------- Attendance: visible to student, coach and gym ---------- */
IF OBJECT_ID(N'dbo.Attendance', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.Attendance (
   Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Attendance PRIMARY KEY,
   SessionId BIGINT NOT NULL,
   EnrollmentId BIGINT NOT NULL,
   StudentUserId BIGINT NOT NULL,
   Status NVARCHAR(20) NOT NULL CONSTRAINT DF_Attendance_Status DEFAULT N'PRESENT',
   MarkedByUserId BIGINT NULL,
   MarkedAt DATETIME2 NULL,
   Note NVARCHAR(300) NULL,
   CONSTRAINT UQ_Attendance UNIQUE(SessionId,EnrollmentId),
   CONSTRAINT CK_Attendance_Status CHECK(Status IN(N'PRESENT',N'ABSENT',N'LATE',N'EXCUSED')),
   CONSTRAINT FK_Attendance_Session FOREIGN KEY(SessionId) REFERENCES dbo.ClassSessions(Id),
   CONSTRAINT FK_Attendance_Enrollment FOREIGN KEY(EnrollmentId) REFERENCES dbo.Enrollments(Id),
   CONSTRAINT FK_Attendance_Student FOREIGN KEY(StudentUserId) REFERENCES dbo.Users(Id),
   CONSTRAINT FK_Attendance_Marker FOREIGN KEY(MarkedByUserId) REFERENCES dbo.Users(Id)
 );
END;
GO

/* ---------- Notifications ---------- */
IF OBJECT_ID(N'dbo.Notifications', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.Notifications (
   Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Notifications PRIMARY KEY,
   UserId BIGINT NOT NULL,
   Type NVARCHAR(50) NOT NULL,
   Title NVARCHAR(200) NOT NULL,
   Message NVARCHAR(1000) NOT NULL,
   RelatedEntity NVARCHAR(50) NULL,
   RelatedId BIGINT NULL,
   ScheduledAt DATETIME2 NULL,
   SentAt DATETIME2 NULL,
   ReadAt DATETIME2 NULL,
   CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Notifications_CreatedAt DEFAULT SYSUTCDATETIME(),
   CONSTRAINT FK_Notifications_User FOREIGN KEY(UserId) REFERENCES dbo.Users(Id)
 );
END;
GO

/* ---------- Mobile push tokens ---------- */
IF OBJECT_ID(N'dbo.DeviceTokens', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.DeviceTokens (
   Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DeviceTokens PRIMARY KEY,
   UserId BIGINT NOT NULL,
   Platform NVARCHAR(20) NOT NULL,
   Token NVARCHAR(500) NOT NULL,
   IsActive BIT NOT NULL CONSTRAINT DF_DeviceTokens_IsActive DEFAULT 1,
   CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_DeviceTokens_CreatedAt DEFAULT SYSUTCDATETIME(),
   CONSTRAINT UQ_DeviceTokens_Token UNIQUE(Token),
   CONSTRAINT FK_DeviceTokens_User FOREIGN KEY(UserId) REFERENCES dbo.Users(Id)
 );
END;
GO

/* ---------- Useful indexes ---------- */
CREATE INDEX IX_Gyms_Location ON dbo.Gyms(Latitude,Longitude);
CREATE INDEX IX_Classes_Gym_Status ON dbo.Classes(GymId,Status);
CREATE INDEX IX_ClassSessions_Date ON dbo.ClassSessions(SessionDate,ClassId);
CREATE INDEX IX_Enrollments_Student_Status ON dbo.Enrollments(StudentUserId,Status);
CREATE INDEX IX_Enrollments_Class_Status ON dbo.Enrollments(ClassId,Status);
CREATE INDEX IX_Payments_Status ON dbo.Payments(Status);
CREATE INDEX IX_Attendance_Student ON dbo.Attendance(StudentUserId,SessionId);
CREATE INDEX IX_Notifications_User_Read ON dbo.Notifications(UserId,ReadAt,CreatedAt);
GO

/* Basic API/dashboard views */
CREATE OR ALTER VIEW dbo.v_ActiveEnrollments AS
SELECT e.Id EnrollmentId,e.StudentUserId,e.ClassId,e.PackageId,e.StartDate,e.EndDate,
       e.SessionsPurchased,e.SessionsUsed,e.SessionsRemaining,e.Status,
       c.Title ClassTitle,g.Id GymId,g.Name GymName,s.NameFa SportNameFa,
       p.Title PackageTitle,p.Price
FROM dbo.Enrollments e
JOIN dbo.Classes c ON c.Id=e.ClassId
JOIN dbo.Gyms g ON g.Id=c.GymId
JOIN dbo.Sports s ON s.Id=c.SportId
JOIN dbo.Packages p ON p.Id=e.PackageId
WHERE e.Status=N'ACTIVE';
GO
