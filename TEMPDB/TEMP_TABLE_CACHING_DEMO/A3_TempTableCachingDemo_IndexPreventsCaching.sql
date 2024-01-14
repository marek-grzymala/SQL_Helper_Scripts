/* https://www.sql.kiwi/2012/08/temporary-object-caching-explained.html 
   https://techcommunity.microsoft.com/t5/sql-server-blog/tempdb-files-and-trace-flags-and-updates-oh-my/ba-p/385937
*/
USE [tempdb];
GO

DBCC FREEPROCCACHE;
GO

DROP PROCEDURE IF EXISTS [dbo].[Demo];
GO

CREATE OR ALTER PROCEDURE [dbo].[Demo]
AS
BEGIN
SET NOCOUNT ON
    CREATE TABLE [#T1] ([dummy] INTEGER NULL);

	/* Prevents caching of #T1: */
    CREATE INDEX idxnc_t5 ON [#T1]([dummy]);

	/* Prevents caching of #T1: */
	--CREATE STATISTICS man_stat_t1 ON [#T1]([dummy]) WITH FULLSCAN

	/* this shows a value inside the sp but after the sp finishes it's gone: 
	SELECT so.* FROM sys.sysobjvalues AS sov
    JOIN sys.objects AS so ON so.object_id = sov.objid
	JOIN sys.sysschobjs AS sso ON sso.id = so.object_id
    WHERE so.is_ms_shipped = 0 AND so.type_desc = 'USER_TABLE'
	*/

	PRINT('Executing [dbo].[Demo]')
END;
GO

DBCC FREEPROCCACHE;
WAITFOR DELAY '00:00:01';
GO

CHECKPOINT;
EXECUTE [dbo].[Demo];
GO

SELECT [T].*
FROM [tempdb].[sys].[tables] AS [T]
WHERE [T].[name] LIKE N'#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]';

SELECT [FD].[Current LSN]
     , [FD].[Operation]
     , [FD].[AllocUnitName]
     , [FD].[Transaction Name]
     , [FD].[Transaction ID]
     , CONVERT(sysname, SUBSTRING([FD].[RowLog Contents 0], 3, 256)) AS [RowLog Contents 0]
     , CONVERT(sysname, SUBSTRING([FD].[RowLog Contents 1], 3, 256)) AS [RowLog Contents 1]
FROM [sys].fn_dblog(NULL, NULL) AS [FD]
--WHERE [FD].[AllocUnitName] LIKE 'sys.sysschobjs%'
ORDER BY [Current LSN] DESC
