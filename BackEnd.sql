-- Create the database
CREATE DATABASE KidsChurchManagementSystem;
GO

-- Use the new database
USE KidsChurchManagementSystem;
GO

-- User table (base table for all user types)
CREATE TABLE [Users] (
    User_ID INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(50) NOT NULL UNIQUE,
    Password_Hash NVARCHAR(128) NOT NULL,
    First_Name NVARCHAR(50) NOT NULL,
    Last_Name NVARCHAR(50) NOT NULL,
    Contact_Number NVARCHAR(20),
    Email_Address NVARCHAR(100),
    User_Role NVARCHAR(20) NOT NULL,
    CONSTRAINT CK_User_Role CHECK (User_Role IN ('Administrator', 'Teacher', 'Parent'))
);

-- Child table
CREATE TABLE Child (
    Child_ID INT IDENTITY(1,1) PRIMARY KEY,
    First_Name NVARCHAR(50) NOT NULL,
    Last_Name NVARCHAR(50) NOT NULL,
    Date_of_Birth DATE NOT NULL,
    Allergies NVARCHAR(MAX),
    Medical_Conditions NVARCHAR(MAX)
);

-- Parent_Child relationship table
CREATE TABLE Parent_Child (
    User_ID INT,
    Child_ID INT,
    Relationship NVARCHAR(50),
    CONSTRAINT PK_Parent_Child PRIMARY KEY (User_ID, Child_ID),
    CONSTRAINT FK_Parent_Child_User FOREIGN KEY (User_ID) REFERENCES [Users](User_ID),
    CONSTRAINT FK_Parent_Child_Child FOREIGN KEY (Child_ID) REFERENCES Child(Child_ID)
);

-- Class table
CREATE TABLE Class (
    Class_ID INT IDENTITY(1,1) PRIMARY KEY,
    Class_Name NVARCHAR(50) NOT NULL,
    Age_Group NVARCHAR(20) NOT NULL,
    Capacity INT NOT NULL
);

-- Teacher_Class assignment table
CREATE TABLE Teacher_Class (
    User_ID INT,
    Class_ID INT,
    Assignment_Date DATE NOT NULL,
    CONSTRAINT PK_Teacher_Class PRIMARY KEY (User_ID, Class_ID),
    CONSTRAINT FK_Teacher_Class_User FOREIGN KEY (User_ID) REFERENCES [Users](User_ID),
    CONSTRAINT FK_Teacher_Class_Class FOREIGN KEY (Class_ID) REFERENCES Class(Class_ID)
);

-- Administrator table
CREATE TABLE Administrator (
    Admin_ID INT IDENTITY(1,1) PRIMARY KEY,
    User_ID INT NOT NULL,
    Admin_Level NVARCHAR(20) NOT NULL,
    Date_Appointed DATE NOT NULL CONSTRAINT DF_Admin_Date_Appointed DEFAULT GETDATE(),
    CONSTRAINT FK_Administrator_User FOREIGN KEY (User_ID) REFERENCES [Users](User_ID)
);

-- Check_In_Out table
CREATE TABLE Check_In_Out (
    Check_ID INT IDENTITY(1,1) PRIMARY KEY,
    Child_ID INT,
    Parent_User_ID INT,
    Class_ID INT,
    Security_User_ID INT,
    Check_Type NVARCHAR(10) NOT NULL,
    Date_Time DATETIME NOT NULL CONSTRAINT DF_Check_Date_Time DEFAULT GETDATE(),
    Scanned_QR_Code NVARCHAR(100),
    CONSTRAINT CK_Check_Type CHECK (Check_Type IN ('IN', 'OUT')),
    CONSTRAINT FK_Check_Child FOREIGN KEY (Child_ID) REFERENCES Child(Child_ID),
    CONSTRAINT FK_Check_Parent FOREIGN KEY (Parent_User_ID) REFERENCES [Users](User_ID),
    CONSTRAINT FK_Check_Class FOREIGN KEY (Class_ID) REFERENCES Class(Class_ID),
    CONSTRAINT FK_Check_Security FOREIGN KEY (Security_User_ID) REFERENCES [Users](User_ID)
);

-- QR_Code table
CREATE TABLE QR_Code (
    QR_Code_ID INT IDENTITY(1,1) PRIMARY KEY,
    Child_ID INT NOT NULL,
    Check_In_ID INT,
    QR_Code_Value NVARCHAR(100) NOT NULL,
    Generated_Date DATETIME NOT NULL CONSTRAINT DF_QR_Generated_Date DEFAULT GETDATE(),
    Expiry_Date DATETIME,
    Is_Active BIT NOT NULL CONSTRAINT DF_QR_Is_Active DEFAULT 1,
    CONSTRAINT FK_QR_Child FOREIGN KEY (Child_ID) REFERENCES Child(Child_ID),
    CONSTRAINT FK_QR_Check_In FOREIGN KEY (Check_In_ID) REFERENCES Check_In_Out(Check_ID)
);

USE KidsChurchManagementSystem;
GO

-- Stored Procedure: Register a new child
CREATE PROCEDURE sp_RegisterChild
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @DateOfBirth DATE,
    @Allergies NVARCHAR(MAX) = NULL,
    @MedicalConditions NVARCHAR(MAX) = NULL,
    @ParentUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Insert the new child
        INSERT INTO Child (First_Name, Last_Name, Date_of_Birth, Allergies, Medical_Conditions)
        VALUES (@FirstName, @LastName, @DateOfBirth, @Allergies, @MedicalConditions);
        
        DECLARE @ChildID INT = SCOPE_IDENTITY();
        
        -- Link child to parent
        INSERT INTO Parent_Child (User_ID, Child_ID, Relationship)
        VALUES (@ParentUserID, @ChildID, 'Parent');
        
        COMMIT TRANSACTION;
        SELECT @ChildID AS NewChildID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Error handling
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO

-- Trigger: Ensure class capacity is not exceeded
CREATE TRIGGER trg_CheckClassCapacity
ON Check_In_Out
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ClassID INT, @CurrentCapacity INT, @MaxCapacity INT;
    
    SELECT @ClassID = i.Class_ID
    FROM inserted i
    WHERE i.Check_Type = 'IN';
    
    IF @ClassID IS NOT NULL
    BEGIN
        -- Get current capacity
        SELECT @CurrentCapacity = COUNT(*)
        FROM Check_In_Out
        WHERE Class_ID = @ClassID AND Check_Type = 'IN' AND Check_ID IN (
            SELECT MAX(Check_ID)
            FROM Check_In_Out
            GROUP BY Child_ID
        );
        
        -- Get max capacity
        SELECT @MaxCapacity = Capacity
        FROM Class
        WHERE Class_ID = @ClassID;
        
        IF @CurrentCapacity > @MaxCapacity
        BEGIN
            RAISERROR('Class capacity exceeded. Cannot check in more children.', 16, 1);
            ROLLBACK TRANSACTION;
        END
    END
END;
GO

-- Function: Calculate Age
CREATE FUNCTION fn_CalculateAge
(
    @DateOfBirth DATE,
    @CurrentDate DATE
)
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(YEAR, @DateOfBirth, @CurrentDate) - 
        CASE 
            WHEN (MONTH(@DateOfBirth) > MONTH(@CurrentDate)) OR 
                 (MONTH(@DateOfBirth) = MONTH(@CurrentDate) AND DAY(@DateOfBirth) > DAY(@CurrentDate))
            THEN 1
            ELSE 0
        END
END;
GO

-- Stored Procedure: Check In Child
CREATE PROCEDURE sp_CheckInChild
    @ChildID INT,
    @ParentUserID INT,
    @ClassID INT,
    @SecurityUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Generate QR Code
        DECLARE @QRCodeValue NVARCHAR(100) = CONCAT('QR', @ChildID, '-', CONVERT(NVARCHAR(20), GETDATE(), 112));
        
        -- Insert Check-In record
        INSERT INTO Check_In_Out (Child_ID, Parent_User_ID, Class_ID, Security_User_ID, Check_Type, Scanned_QR_Code)
        VALUES (@ChildID, @ParentUserID, @ClassID, @SecurityUserID, 'IN', @QRCodeValue);
        
        DECLARE @CheckInID INT = SCOPE_IDENTITY();
        
        -- Insert QR Code record
        INSERT INTO QR_Code (Child_ID, Check_In_ID, QR_Code_Value)
        VALUES (@ChildID, @CheckInID, @QRCodeValue);
        
        COMMIT TRANSACTION;
        SELECT @QRCodeValue AS GeneratedQRCode;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Error handling
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO

-- User Sign-up Procedure
CREATE PROCEDURE sp_SignUpUser
    @Username NVARCHAR(50),
    @Password NVARCHAR(50),
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @ContactNumber NVARCHAR(20),
    @EmailAddress NVARCHAR(100),
    @UserRole NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Hash the password (replace this with a proper hashing function)
    DECLARE @PasswordHash NVARCHAR(128) = CONVERT(NVARCHAR(128), HASHBYTES('SHA2_256', @Password), 2)
    
    INSERT INTO [Users] (Username, Password_Hash, First_Name, Last_Name, Contact_Number, Email_Address, User_Role)
    VALUES (@Username, @PasswordHash, @FirstName, @LastName, @ContactNumber, @EmailAddress, @UserRole)
END
GO

-- User Login Procedure
CREATE PROCEDURE sp_LoginUser
    @Username NVARCHAR(50),
    @Password NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Hash the provided password (replace this with the same hashing function used in sign-up)
    DECLARE @PasswordHash NVARCHAR(128) = CONVERT(NVARCHAR(128), HASHBYTES('SHA2_256', @Password), 2)
    
    IF EXISTS (SELECT 1 FROM [Users] WHERE Username = @Username AND Password_Hash = @PasswordHash)
    BEGIN
        SELECT 'Login Successful' AS Result, User_ID, User_Role
        FROM [Users]
        WHERE Username = @Username
    END
    ELSE
    BEGIN
        SELECT 'Login Failed' AS Result
    END
END
GO

USE KidsChurchManagementSystem;
GO

-- 1. Add unique constraints and indexes

-- Ensure unique combination of first name, last name, and date of birth for children
ALTER TABLE Child
ADD CONSTRAINT UQ_Child_Name_DOB UNIQUE (First_Name, Last_Name, Date_of_Birth);

-- Ensure unique email addresses for users
ALTER TABLE [User]
ADD CONSTRAINT UQ_User_Email UNIQUE (Email_Address);

-- 2. Create a procedure to check for duplicate children
USE KidsChurchManagementSystem;
GO


CREATE PROCEDURE sp_CheckDuplicateChild
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @DateOfBirth DATE,
    @IsDuplicate BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 
        FROM Child 
        WHERE First_Name = @FirstName 
          AND Last_Name = @LastName 
          AND Date_of_Birth = @DateOfBirth
    )
    BEGIN
        SET @IsDuplicate = 1;
    END
    ELSE
    BEGIN
        SET @IsDuplicate = 0;
    END
END;
GO

-- 3. Implement a trigger to prevent duplicate check-ins

CREATE TRIGGER trg_PreventDuplicateCheckIn
ON Check_In_Out
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ChildID INT, @CheckType NVARCHAR(10), @LastCheckType NVARCHAR(10);

    SELECT @ChildID = Child_ID, @CheckType = Check_Type
    FROM inserted;

    -- Get the last check type for this child
    SELECT TOP 1 @LastCheckType = Check_Type
    FROM Check_In_Out
    WHERE Child_ID = @ChildID
    ORDER BY Date_Time DESC;

    -- Prevent duplicate check-in or check-out
    IF (@CheckType = 'IN' AND @LastCheckType = 'IN') OR (@CheckType = 'OUT' AND @LastCheckType = 'OUT' OR @LastCheckType IS NULL)
    BEGIN
        RAISERROR('Invalid check-in/out sequence. Child is already checked in or out.', 16, 1);
        RETURN;
    END

    -- If all checks pass, insert the new record
    INSERT INTO Check_In_Out (Child_ID, Parent_User_ID, Class_ID, Security_User_ID, Check_Type, Date_Time, Scanned_QR_Code)
    SELECT Child_ID, Parent_User_ID, Class_ID, Security_User_ID, Check_Type, Date_Time, Scanned_QR_Code
    FROM inserted;
END;
GO

-- 4. Update the sp_RegisterChild procedure to use the duplicate check

ALTER PROCEDURE sp_RegisterChild
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @DateOfBirth DATE,
    @Allergies NVARCHAR(MAX) = NULL,
    @MedicalConditions NVARCHAR(MAX) = NULL,
    @ParentUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @IsDuplicate BIT;

        EXEC sp_CheckDuplicateChild @FirstName, @LastName, @DateOfBirth, @IsDuplicate OUTPUT;

        IF @IsDuplicate = 1
        BEGIN
            RAISERROR('A child with the same name and date of birth already exists.', 16, 1);
            RETURN;
        END

        BEGIN TRANSACTION;
        
        -- Insert the new child
        INSERT INTO Child (First_Name, Last_Name, Date_of_Birth, Allergies, Medical_Conditions)
        VALUES (@FirstName, @LastName, @DateOfBirth, @Allergies, @MedicalConditions);
        
        DECLARE @ChildID INT = SCOPE_IDENTITY();
        
        -- Link child to parent
        INSERT INTO Parent_Child (User_ID, Child_ID, Relationship)
        VALUES (@ParentUserID, @ChildID, 'Parent');
        
        COMMIT TRANSACTION;
        SELECT @ChildID AS NewChildID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Error handling
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO
