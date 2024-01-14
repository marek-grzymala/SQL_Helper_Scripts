USE [tempdb];
GO

DROP PROCEDURE IF EXISTS [dbo].[Demo];
GO

CREATE OR ALTER PROCEDURE [dbo].[Demo]
AS
BEGIN
    CREATE TABLE [#T1] ([dummy] INT NULL);
    INSERT [#T1] ([dummy]) VALUES (1);

    DECLARE @dummy INT;

    /* Trigger auto-stats creation */
    SELECT @dummy = [dummy] FROM [#T1] WHERE [dummy] > 0;

    WAITFOR DELAY '00:00:01';
END;
GO

DBCC FREEPROCCACHE;
GO

WAITFOR DELAY '00:00:01';
GO

EXECUTE [dbo].[Demo];
GO

SELECT [T].[name]
     , [T].[object_id]
     , [S].[name]
     , [S].[auto_created]
FROM [tempdb].[sys].[tables] AS [T]
JOIN [tempdb].[sys].[stats] AS [S]
    ON [S].[object_id] = [T].[object_id];