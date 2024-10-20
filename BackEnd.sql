-- Create the schema
CREATE SCHEMA KidsChurch;
GO

-- User table (base table for all user types)
CREATE TABLE KidsChurch.[User] (
    User_ID INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(50) NOT NULL UNIQUE,
    Password_Hash NVARCHAR(128) NOT NULL,
    First_Name NVARCHAR(50) NOT NULL,
    Last_Name NVARCHAR(50) NOT NULL,
    Contact_Number NVARCHAR(20),
    Email_Address NVARCHAR(100),
    User_Role NVARCHAR(20) NOT NULL CHECK (User_Role IN ('Administrator', 'Teacher', 'Parent', 'Security'))
);

-- Child table
CREATE TABLE KidsChurch.Child (
    Child_ID INT IDENTITY(1,1) PRIMARY KEY,
    First_Name NVARCHAR(50) NOT NULL,
    Last_Name NVARCHAR(50) NOT NULL,
    Date_of_Birth DATE NOT NULL,
    Allergies NVARCHAR(MAX),
    Medical_Conditions NVARCHAR(MAX),
    CurrentQRCode NVARCHAR(100) NULL
);

-- Parent_Child relationship table
CREATE TABLE KidsChurch.Parent_Child (
    User_ID INT,
    Child_ID INT,
    Relationship NVARCHAR(50),
    PRIMARY KEY (User_ID, Child_ID),
    FOREIGN KEY (User_ID) REFERENCES KidsChurch.[User](User_ID),
    FOREIGN KEY (Child_ID) REFERENCES KidsChurch.Child(Child_ID)
);

-- Class table
CREATE TABLE KidsChurch.Class (
    Class_ID INT IDENTITY(1,1) PRIMARY KEY,
    Class_Name NVARCHAR(50) NOT NULL,
    Age_Group NVARCHAR(20) NOT NULL,
    Capacity INT NOT NULL
);

-- Teacher_Class assignment table
CREATE TABLE KidsChurch.Teacher_Class (
    User_ID INT,
    Class_ID INT,
    Assignment_Date DATE NOT NULL,
    PRIMARY KEY (User_ID, Class_ID),
    FOREIGN KEY (User_ID) REFERENCES KidsChurch.[User](User_ID),
    FOREIGN KEY (Class_ID) REFERENCES KidsChurch.Class(Class_ID)
);

-- Check_In_Out table
CREATE TABLE KidsChurch.Check_In_Out (
    Check_ID INT IDENTITY(1,1) PRIMARY KEY,
    Child_ID INT,
    Parent_User_ID INT,
    Class_ID INT,
    Security_User_ID INT,
    Check_Type NVARCHAR(10) NOT NULL CHECK (Check_Type IN ('IN', 'OUT')),
    Date_Time DATETIME NOT NULL DEFAULT GETDATE(),
    QRCode NVARCHAR(100) NOT NULL,
    FOREIGN KEY (Child_ID) REFERENCES KidsChurch.Child(Child_ID),
    FOREIGN KEY (Parent_User_ID) REFERENCES KidsChurch.[User](User_ID),
    FOREIGN KEY (Class_ID) REFERENCES KidsChurch.Class(Class_ID),
    FOREIGN KEY (Security_User_ID) REFERENCES KidsChurch.[User](User_ID)
);
