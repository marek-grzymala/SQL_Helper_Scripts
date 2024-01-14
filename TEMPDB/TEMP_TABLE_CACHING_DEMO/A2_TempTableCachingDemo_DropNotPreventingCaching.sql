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
	PRINT('Executing [dbo].[Demo]')
	DROP TABLE [#T1]
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

--SELECT CONVERT(INT, 0xA6EA6019); /* = -1494589415 */

/*
SELECT * FROM sys.dm_exec_cached_plans
SELECT * FROM sys.dm_exec_sql_text(0x050002005F91E032D0C2193FC601000001000000000000000000000000000000000000000000000000000000)
SELECT * FROM sys.dm_exec_query_plan(0x050002005F91E032D0C2193FC601000001000000000000000000000000000000000000000000000000000000)

SELECT [cp].[objtype] AS [PlanType]
     , OBJECT_NAME([st].[objectid], [st].[dbid]) AS [ObjectName]
     , [cp].[refcounts] AS [ReferenceCounts]
     , [cp].[usecounts] AS [UseCounts]
     , [st].[text] AS [SQLBatch]
     , [qp].[query_plan] AS [QueryPlan]
FROM [sys].[dm_exec_cached_plans] AS [cp]
CROSS APPLY [sys].dm_exec_query_plan([cp].[plan_handle]) AS [qp]
CROSS APPLY [sys].dm_exec_sql_text([cp].[plan_handle]) AS [st];

SELECT [domcc].[name]
     , [domcc].[type]
     , [domcc].[pages_kb]
     , [domcc].[pages_in_use_kb]
     , [domcc].[entries_count]
     , [domcc].[entries_in_use_count]
FROM [sys].[dm_os_memory_cache_counters] AS [domcc]
WHERE [domcc].[type] IN (   N'CACHESTORE_OBJCP'      -- Object Plans
                          , N'CACHESTORE_SQLCP'      -- SQL Plans
                          , N'CACHESTORE_PHDR'       -- Bound Trees
                          , N'CACHESTORE_XPROC'      -- Extended Stored Procedures
                          , N'CACHESTORE_TEMPTABLES' -- Temporary Tables & Table Variables

                        );

SELECT CASE WHEN [value] <> [value_in_use] THEN 'restart required' END AS [restart_required?]
     , *
FROM [sys].[configurations]
WHERE [name] = N'tempdb metadata memory-optimized';

SELECT [t].[object_id]
     , [t].[name]
FROM [tempdb].[sys].[all_objects] AS [t]
INNER JOIN [tempdb].[sys].[memory_optimized_tables_internal_attributes] AS [i]
    ON [t].[object_id] = [i].[object_id];
*/