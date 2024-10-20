-- Create the database
CREATE DATABASE KidsChurchManagementSystem;
GO

-- Use the new database
USE KidsChurchManagementSystem;
GO

-- User table (base table for all user types)
CREATE TABLE [User] (
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
    CONSTRAINT FK_Parent_Child_User FOREIGN KEY (User_ID) REFERENCES [User](User_ID),
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
    CONSTRAINT FK_Teacher_Class_User FOREIGN KEY (User_ID) REFERENCES [User](User_ID),
    CONSTRAINT FK_Teacher_Class_Class FOREIGN KEY (Class_ID) REFERENCES Class(Class_ID)
);

-- Administrator table
CREATE TABLE Administrator (
    Admin_ID INT IDENTITY(1,1) PRIMARY KEY,
    User_ID INT NOT NULL,
    Admin_Level NVARCHAR(20) NOT NULL,
    Date_Appointed DATE NOT NULL CONSTRAINT DF_Admin_Date_Appointed DEFAULT GETDATE(),
    CONSTRAINT FK_Administrator_User FOREIGN KEY (User_ID) REFERENCES [User](User_ID)
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
    CONSTRAINT FK_Check_Parent FOREIGN KEY (Parent_User_ID) REFERENCES [User](User_ID),
    CONSTRAINT FK_Check_Class FOREIGN KEY (Class_ID) REFERENCES Class(Class_ID),
    CONSTRAINT FK_Check_Security FOREIGN KEY (Security_User_ID) REFERENCES [User](User_ID)
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
