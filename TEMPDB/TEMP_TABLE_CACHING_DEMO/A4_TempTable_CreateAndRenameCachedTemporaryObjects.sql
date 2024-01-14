USE [tempdb];
GO

DBCC FREEPROCCACHE;
GO

DROP PROCEDURE IF EXISTS [dbo].[Demo];
GO

CREATE OR ALTER PROCEDURE [dbo].[Demo]
AS
BEGIN
    CREATE TABLE [#T1] ([i] INT);

    SELECT [T].[name]
         , [T].[object_id]
         , [T].[type_desc]
         , [T].[create_date]
    FROM [sys].[tables] AS [T]
    WHERE [T].[name] LIKE N'#T1%';

    DROP TABLE [#T1];

    SELECT [T].[name]
         , [T].[object_id]
         , [T].[type_desc]
         , [T].[create_date]
    FROM [sys].[tables] AS [T]
    WHERE [T].[name] LIKE N'#%';
END;
GO

DBCC FREEPROCCACHE;
WAITFOR DELAY '00:00:01';
GO

CHECKPOINT;
EXECUTE [dbo].[Demo];
GO

SELECT [FD].[Current LSN]
     , [FD].[Operation]
     , [FD].[AllocUnitName]
     , [FD].[Transaction Name]
     , [FD].[Transaction ID]
     , CONVERT(sysname, SUBSTRING([FD].[RowLog Contents 0], 3, 256)) AS [RowLog Contents 0]
     , CONVERT(sysname, SUBSTRING([FD].[RowLog Contents 1], 3, 256)) AS [RowLog Contents 1]
FROM [sys].fn_dblog(NULL, NULL) AS [FD]
WHERE [RowLog Contents 0] IS NOT NULL 
OR [RowLog Contents 1] IS NOT NULL 
OR [Transaction Name] IS NOT NULL
ORDER BY [Current LSN] DESC

--SELECT CONVERT(INT, 0xA6EA6019); /* = -1494589415 */