

IF DB_ID(N'RaceDay') IS NULL
BEGIN
    CREATE DATABASE RaceDay;
END;
GO

USE RaceDay;
GO

CREATE TABLE dbo.AppUsers
(
    UserId          int IDENTITY(1,1) NOT NULL,
    Email           nvarchar(254) NOT NULL,
    PasswordHash    nvarchar(255) NOT NULL,
    FirstName       nvarchar(80) NOT NULL,
    LastName        nvarchar(80) NOT NULL,
    Phone           nvarchar(30) NULL,
    Role            nvarchar(20) NOT NULL,
    CreatedAt       datetime2(0) NOT NULL CONSTRAINT DF_AppUsers_CreatedAt DEFAULT SYSUTCDATETIME(),
    IsActive        bit NOT NULL CONSTRAINT DF_AppUsers_IsActive DEFAULT (1),
    CONSTRAINT PK_AppUsers PRIMARY KEY (UserId),
    CONSTRAINT UQ_AppUsers_Email UNIQUE (Email),
    CONSTRAINT CK_AppUsers_Role CHECK (Role IN (N'Organiser', N'Participant'))
);
GO

CREATE TABLE dbo.Events
(
    EventId                 int IDENTITY(1,1) NOT NULL,
    OrganiserId             int NOT NULL,
    Name                    nvarchar(150) NOT NULL,
    EventType               nvarchar(20) NOT NULL,
    Description             nvarchar(1000) NULL,
    EventDate               datetime2(0) NOT NULL,
    RegistrationOpenAt      datetime2(0) NOT NULL,
    RegistrationCloseAt     datetime2(0) NOT NULL,
    Venue                   nvarchar(200) NOT NULL,
    City                    nvarchar(100) NOT NULL,
    Province                nvarchar(50) NOT NULL,
    Status                  nvarchar(20) NOT NULL CONSTRAINT DF_Events_Status DEFAULT (N'Draft'),
    RouteUrl                nvarchar(500) NULL,
    RouteDistanceKm         decimal(7,2) NULL,
    CreatedAt               datetime2(0) NOT NULL CONSTRAINT DF_Events_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Events PRIMARY KEY (EventId),
    CONSTRAINT FK_Events_AppUsers_Organiser FOREIGN KEY (OrganiserId) REFERENCES dbo.AppUsers(UserId),
    CONSTRAINT CK_Events_EventType CHECK (EventType IN (N'Run', N'Walk', N'Cycle')),
    CONSTRAINT CK_Events_Status CHECK (Status IN (N'Draft', N'Published', N'Cancelled', N'Completed')),
    CONSTRAINT CK_Events_RegistrationWindow CHECK (RegistrationOpenAt < RegistrationCloseAt AND RegistrationCloseAt <= EventDate),
    CONSTRAINT CK_Events_RouteDistance CHECK (RouteDistanceKm IS NULL OR RouteDistanceKm > 0)
);
GO

CREATE TABLE dbo.Categories
(
    CategoryId      int IDENTITY(1,1) NOT NULL,
    EventId         int NOT NULL,
    Name            nvarchar(100) NOT NULL,
    DistanceKm      decimal(7,2) NOT NULL,
    MinimumAge      tinyint NULL,
    MaximumAge      tinyint NULL,
    Capacity        int NOT NULL,
    EntryFee        decimal(10,2) NOT NULL CONSTRAINT DF_Categories_EntryFee DEFAULT (0),
    CONSTRAINT PK_Categories PRIMARY KEY (CategoryId),
    CONSTRAINT FK_Categories_Events FOREIGN KEY (EventId) REFERENCES dbo.Events(EventId),
    CONSTRAINT UQ_Categories_Event_Name UNIQUE (EventId, Name),
    CONSTRAINT CK_Categories_Distance CHECK (DistanceKm > 0),
    CONSTRAINT CK_Categories_AgeRange CHECK (MinimumAge IS NULL OR MaximumAge IS NULL OR MinimumAge <= MaximumAge),
    CONSTRAINT CK_Categories_Capacity CHECK (Capacity > 0),
    CONSTRAINT CK_Categories_EntryFee CHECK (EntryFee >= 0)
);
GO

CREATE TABLE dbo.Enrolments
(
    EnrolmentId         int IDENTITY(1,1) NOT NULL,
    ParticipantUserId   int NOT NULL,
    CategoryId          int NOT NULL,
    EnrolledAt          datetime2(0) NOT NULL CONSTRAINT DF_Enrolments_EnrolledAt DEFAULT SYSUTCDATETIME(),
    Status              nvarchar(20) NOT NULL CONSTRAINT DF_Enrolments_Status DEFAULT (N'Confirmed'),
    BibNumber           nvarchar(20) NULL,
    CONSTRAINT PK_Enrolments PRIMARY KEY (EnrolmentId),
    CONSTRAINT FK_Enrolments_AppUsers_Participant FOREIGN KEY (ParticipantUserId) REFERENCES dbo.AppUsers(UserId),
    CONSTRAINT FK_Enrolments_Categories FOREIGN KEY (CategoryId) REFERENCES dbo.Categories(CategoryId),
    CONSTRAINT UQ_Enrolments_Participant_Category UNIQUE (ParticipantUserId, CategoryId),
    CONSTRAINT CK_Enrolments_Status CHECK (Status IN (N'Confirmed', N'Waitlisted', N'Cancelled'))
);
GO
CREATE UNIQUE INDEX UX_Enrolments_Category_BibNumber
    ON dbo.Enrolments(CategoryId, BibNumber)
    WHERE BibNumber IS NOT NULL;
GO

CREATE TABLE dbo.Results
(
    ResultId            int IDENTITY(1,1) NOT NULL,
    EnrolmentId         int NOT NULL,
    Position            int NULL,
    FinishTime          time(0) NULL,
    ResultStatus        nvarchar(10) NOT NULL,
    RecordedByUserId    int NOT NULL,
    RecordedAt          datetime2(0) NOT NULL CONSTRAINT DF_Results_RecordedAt DEFAULT SYSUTCDATETIME(),
    Notes               nvarchar(500) NULL,
    CONSTRAINT PK_Results PRIMARY KEY (ResultId),
    CONSTRAINT UQ_Results_Enrolment UNIQUE (EnrolmentId),
    CONSTRAINT FK_Results_Enrolments FOREIGN KEY (EnrolmentId) REFERENCES dbo.Enrolments(EnrolmentId),
    CONSTRAINT FK_Results_AppUsers_Recorder FOREIGN KEY (RecordedByUserId) REFERENCES dbo.AppUsers(UserId),
    CONSTRAINT CK_Results_Status CHECK (ResultStatus IN (N'Finished', N'DNF', N'DNS', N'DSQ')),
    CONSTRAINT CK_Results_Position CHECK (Position IS NULL OR Position > 0)
);
GO

CREATE TABLE dbo.WeatherSnapshots
(
    WeatherSnapshotId    int IDENTITY(1,1) NOT NULL,
    EventId              int NOT NULL,
    ObservedAt           datetime2(0) NOT NULL,
    TemperatureC         decimal(5,2) NULL,
    Conditions           nvarchar(100) NOT NULL,
    WindSpeedKph         decimal(6,2) NULL,
    PrecipitationMm      decimal(6,2) NULL,
    Provider             nvarchar(100) NOT NULL,
    CONSTRAINT PK_WeatherSnapshots PRIMARY KEY (WeatherSnapshotId),
    CONSTRAINT FK_WeatherSnapshots_Events FOREIGN KEY (EventId) REFERENCES dbo.Events(EventId),
    CONSTRAINT CK_WeatherSnapshots_Wind CHECK (WindSpeedKph IS NULL OR WindSpeedKph >= 0),
    CONSTRAINT CK_WeatherSnapshots_Precipitation CHECK (PrecipitationMm IS NULL OR PrecipitationMm >= 0)
);
GO

/* Seed records: 2 organisers, 2 participants, 3 events, 6 categories,
   representative enrolments, a result, and cached weather observations. */
SET IDENTITY_INSERT dbo.AppUsers ON;
INSERT INTO dbo.AppUsers (UserId, Email, PasswordHash, FirstName, LastName, Phone, Role, CreatedAt, IsActive)
VALUES
 (1, N'sipho.dlamini@raceday.example', N'DEMO-REPLACE-WITH-IDENTITY-HASH-ORGANISER-1', N'Sipho', N'Dlamini', N'+27 82 555 0101', N'Organiser', '2026-10-01T08:00:00', 1),
 (2, N'amanda.jacobs@raceday.example', N'DEMO-REPLACE-WITH-IDENTITY-HASH-ORGANISER-2', N'Amanda', N'Jacobs', N'+27 83 555 0102', N'Organiser', '2026-10-02T08:00:00', 1),
 (3, N'lerato.mokoena@raceday.example', N'DEMO-REPLACE-WITH-IDENTITY-HASH-PARTICIPANT-1', N'Lerato', N'Mokoena', N'+27 72 555 0103', N'Participant', '2026-10-03T09:00:00', 1),
 (4, N'james.naidoo@raceday.example', N'DEMO-REPLACE-WITH-IDENTITY-HASH-PARTICIPANT-2', N'James', N'Naidoo', N'+27 73 555 0104', N'Participant', '2026-10-04T09:00:00', 1);
SET IDENTITY_INSERT dbo.AppUsers OFF;
GO

SET IDENTITY_INSERT dbo.Events ON;
INSERT INTO dbo.Events (EventId, OrganiserId, Name, EventType, Description, EventDate, RegistrationOpenAt, RegistrationCloseAt, Venue, City, Province, Status, RouteUrl, RouteDistanceKm, CreatedAt)
VALUES
 (1, 1, N'Harbour Lights 10K', N'Run', N'An evening road race along the Durban beachfront.', '2026-10-18T18:00:00', '2026-07-01T00:00:00', '2026-10-10T23:59:59', N'uShaka Marine World', N'Durban', N'KwaZulu-Natal', N'Published', N'https://routes.example/harbour-lights-10k', 10.00, '2026-07-01T08:00:00'),
 (2, 2, N'Joburg Spring Walk', N'Walk', N'A family-friendly walk through central Johannesburg.', '2026-11-15T07:00:00', '2026-08-15T00:00:00', '2026-11-08T23:59:59', N'Zoo Lake', N'Johannesburg', N'Gauteng', N'Published', N'https://routes.example/joburg-spring-walk', 5.00, '2026-08-15T08:00:00'),
 (3, 1, N'Winelands Cycle Challenge', N'Cycle', N'A supported road-cycling event through the Stellenbosch Winelands.', '2026-12-06T06:30:00', '2026-09-01T00:00:00', '2026-11-29T23:59:59', N'Dorp Street', N'Stellenbosch', N'Western Cape', N'Published', N'https://routes.example/winelands-cycle', 70.00, '2026-09-01T08:00:00');
SET IDENTITY_INSERT dbo.Events OFF;
GO

SET IDENTITY_INSERT dbo.Categories ON;
INSERT INTO dbo.Categories (CategoryId, EventId, Name, DistanceKm, MinimumAge, MaximumAge, Capacity, EntryFee)
VALUES
 (1, 1, N'10 km Open', 10.00, 16, NULL, 1200, 180.00),
 (2, 1, N'5 km Fun Run', 5.00, 8, NULL, 800, 90.00),
 (3, 2, N'5 km Family Walk', 5.00, NULL, NULL, 1000, 60.00),
 (4, 2, N'10 km Challenge Walk', 10.00, 12, NULL, 600, 100.00),
 (5, 3, N'70 km Road Cycle', 70.00, 18, NULL, 500, 650.00),
 (6, 3, N'35 km Social Cycle', 35.00, 16, NULL, 500, 350.00);
SET IDENTITY_INSERT dbo.Categories OFF;
GO

SET IDENTITY_INSERT dbo.Enrolments ON;
INSERT INTO dbo.Enrolments (EnrolmentId, ParticipantUserId, CategoryId, EnrolledAt, Status, BibNumber)
VALUES
 (1, 3, 1, '2026-09-10T10:15:00', N'Confirmed', N'DB001'),
 (2, 4, 2, '2026-09-11T11:20:00', N'Confirmed', N'DB002'),
 (3, 3, 3, '2026-10-12T12:10:00', N'Confirmed', N'JW101'),
 (4, 4, 5, '2026-10-13T13:45:00', N'Confirmed', N'WC204');
SET IDENTITY_INSERT dbo.Enrolments OFF;
GO

SET IDENTITY_INSERT dbo.Results ON;
INSERT INTO dbo.Results (ResultId, EnrolmentId, Position, FinishTime, ResultStatus, RecordedByUserId, RecordedAt, Notes)
VALUES
 (1, 1, 18, '00:52:34', N'Finished', 1, '2026-10-18T19:05:00', N'Sample result for schema demonstration.');
SET IDENTITY_INSERT dbo.Results OFF;
GO

SET IDENTITY_INSERT dbo.WeatherSnapshots ON;
INSERT INTO dbo.WeatherSnapshots (WeatherSnapshotId, EventId, ObservedAt, TemperatureC, Conditions, WindSpeedKph, PrecipitationMm, Provider)
VALUES
 (1, 1, '2026-10-18T17:00:00', 23.50, N'Partly cloudy (sample)', 14.00, 0.00, N'Sample seed data - replace with live provider'),
 (2, 2, '2026-10-22T12:00:00', 20.00, N'Clear (sample)', 9.50, 0.00, N'Sample seed data - replace with live provider');
SET IDENTITY_INSERT dbo.WeatherSnapshots OFF;
GO

/* Basic verification queries for SSMS demonstration. */
SELECT Role, COUNT(*) AS UserCount FROM dbo.AppUsers GROUP BY Role;
SELECT e.Name AS EventName, COUNT(c.CategoryId) AS CategoryCount
FROM dbo.Events AS e LEFT JOIN dbo.Categories AS c ON c.EventId = e.EventId
GROUP BY e.EventId, e.Name ORDER BY e.EventId;
SELECT COUNT(*) AS EnrolmentCount FROM dbo.Enrolments;
GO
