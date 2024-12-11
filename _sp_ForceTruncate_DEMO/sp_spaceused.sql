USE [master];
SET NOCOUNT ON;
GO
IF DB_ID('test') IS NOT NULL
    ALTER DATABASE [test] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
    DROP DATABASE [test];
GO
CREATE DATABASE [test];
GO
ALTER DATABASE [test] SET RECOVERY FULL;
GO

USE [test];
GO
DROP TABLE IF EXISTS [TestTable]
CREATE TABLE [TestTable]
(
  [name] CHAR(8000) NOT NULL DEFAULT (REPLICATE('abcd', 2000))
);
GO
INSERT INTO [TestTable] DEFAULT VALUES;
GO 8000


SELECT CONVERT(INT, SUBSTRING([sa].[first_iam_page], 6, 1) + SUBSTRING([sa].[first_iam_page], 5, 1)) AS [first_iam_file]
     , CONVERT(INT, SUBSTRING([sa].[first_iam_page], 4, 1) + SUBSTRING([sa].[first_iam_page], 3, 1) + SUBSTRING([sa].[first_iam_page], 2, 1) + SUBSTRING([sa].[first_iam_page], 1, 1)) AS [first_iam_page]
     , CONVERT(INT, SUBSTRING([sa].[root_page], 6, 1) + SUBSTRING([sa].[root_page], 5, 1)) AS [root_page_file]
     , CONVERT(INT, SUBSTRING([sa].[root_page], 4, 1) + SUBSTRING([sa].[root_page], 3, 1) + SUBSTRING([sa].[root_page], 2, 1) + SUBSTRING([sa].[root_page], 1, 1)) AS [root_page]
     , CONVERT(INT, SUBSTRING([sa].[first_page], 6, 1) + SUBSTRING([sa].[first_page], 5, 1)) AS [first_page_file]
     , CONVERT(INT, SUBSTRING([sa].[first_page], 4, 1) + SUBSTRING([sa].[first_page], 3, 1) + SUBSTRING([sa].[first_page], 2, 1) + SUBSTRING([sa].[first_page], 1, 1)) AS [first_page]
     , [sa].[type_desc]
     , [sp].[partition_number]
     , [sp].[hobt_id]
     , [sp].[rows]
FROM sys.system_internals_allocation_units [sa]
INNER JOIN sys.partitions [sp]
    ON [sa].[container_id] = [sp].[partition_id]
WHERE OBJECT_NAME([sp].[object_id]) = 'TestTable';

EXEC sp_spaceused N'dbo.TestTable', N'TRUE';
--SELECT 64000/8 = 8000 PAGES and you can verify this by running this:

SELECT 
  [partition_number]
, [hobt_id]
, [index_type_desc]
, [page_count]
, [alloc_unit_type_desc]
, [index_depth]
, [index_level]
, [avg_fragmentation_in_percent]
, [fragment_count]
, [avg_fragment_size_in_pages]
, [avg_page_space_used_in_percent]
, [record_count]
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID(N'TestTable'), NULL, NULL, 'DETAILED')


SELECT OBJECT_NAME(pa.object_id) AS [TableName],
       pa.allocation_unit_id,
       pa.allocation_unit_type_desc,
       pa.extent_page_id,
       pa.page_free_space_percent,
       pa.page_type_desc,
       pa.allocated_page_page_id,
       pa.extent_file_id
FROM sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('dbo.TestTable'), NULL, NULL, 'DETAILED') AS [pa]
WHERE pa.page_type_desc <> 'DATA_PAGE'

DECLARE @maxlns VARCHAR(100);
SELECT @maxlns = MAX([Current LSN]) FROM [sys].[fn_dblog](NULL, NULL);

PRINT 'Before Truncating/Deleting.........................................';
SELECT CONVERT(INT, SUBSTRING([sa].[first_iam_page], 6, 1) + SUBSTRING([sa].[first_iam_page], 5, 1)) AS [first_iam_file]
     , CONVERT(INT, SUBSTRING([sa].[first_iam_page], 4, 1) + SUBSTRING([sa].[first_iam_page], 3, 1) + SUBSTRING([sa].[first_iam_page], 2, 1) + SUBSTRING([sa].[first_iam_page], 1, 1)) AS [first_iam_page]
     , CONVERT(INT, SUBSTRING([sa].[root_page], 6, 1) + SUBSTRING([sa].[root_page], 5, 1)) AS [root_page_file]
     , CONVERT(INT, SUBSTRING([sa].[root_page], 4, 1) + SUBSTRING([sa].[root_page], 3, 1) + SUBSTRING([sa].[root_page], 2, 1) + SUBSTRING([sa].[root_page], 1, 1)) AS [root_page]
     , CONVERT(INT, SUBSTRING([sa].[first_page], 6, 1) + SUBSTRING([sa].[first_page], 5, 1)) AS [first_page_file]
     , CONVERT(INT, SUBSTRING([sa].[first_page], 4, 1) + SUBSTRING([sa].[first_page], 3, 1) + SUBSTRING([sa].[first_page], 2, 1) + SUBSTRING([sa].[first_page], 1, 1)) AS [first_page]
     , [sa].[type_desc]
FROM sys.system_internals_allocation_units [sa]
INNER JOIN sys.partitions [sp]
    ON [sa].[container_id] = [sp].[partition_id]
WHERE OBJECT_NAME([sp].[object_id]) = 'TestTable';

PRINT 'Before Truncating/Deleting.........................................';
SELECT CONVERT(INT, SUBSTRING([sa].[first_iam_page], 6, 1) + SUBSTRING([sa].[first_iam_page], 5, 1)) AS [first_iam_file]
     , CONVERT(INT, SUBSTRING([sa].[first_iam_page], 4, 1) + SUBSTRING([sa].[first_iam_page], 3, 1) + SUBSTRING([sa].[first_iam_page], 2, 1) + SUBSTRING([sa].[first_iam_page], 1, 1)) AS [first_iam_page]
     , CONVERT(INT, SUBSTRING([sa].[root_page], 6, 1) + SUBSTRING([sa].[root_page], 5, 1)) AS [root_page_file]
     , CONVERT(INT, SUBSTRING([sa].[root_page], 4, 1) + SUBSTRING([sa].[root_page], 3, 1) + SUBSTRING([sa].[root_page], 2, 1) + SUBSTRING([sa].[root_page], 1, 1)) AS [root_page]
     , CONVERT(INT, SUBSTRING([sa].[first_page], 6, 1) + SUBSTRING([sa].[first_page], 5, 1)) AS [first_page_file]
     , CONVERT(INT, SUBSTRING([sa].[first_page], 4, 1) + SUBSTRING([sa].[first_page], 3, 1) + SUBSTRING([sa].[first_page], 2, 1) + SUBSTRING([sa].[first_page], 1, 1)) AS [first_page]
     , [sa].[type_desc]
FROM sys.system_internals_allocation_units [sa]
INNER JOIN sys.partitions [sp]
    ON [sa].[container_id] = [sp].[partition_id]
WHERE OBJECT_NAME([sp].[object_id]) = 'TestTable';


--delete TestTable
PRINT 'After Truncating/Deleting.........................................';
SELECT CONVERT(INT, SUBSTRING([sa].[first_iam_page], 6, 1) + SUBSTRING([sa].[first_iam_page], 5, 1)) AS [first_iam_file]
     , CONVERT(INT, SUBSTRING([sa].[first_iam_page], 4, 1) + SUBSTRING([sa].[first_iam_page], 3, 1) + SUBSTRING([sa].[first_iam_page], 2, 1) + SUBSTRING([sa].[first_iam_page], 1, 1)) AS [first_iam_page]
     , CONVERT(INT, SUBSTRING([sa].[root_page], 6, 1) + SUBSTRING([sa].[root_page], 5, 1)) AS [root_page_file]
     , CONVERT(INT, SUBSTRING([sa].[root_page], 4, 1) + SUBSTRING([sa].[root_page], 3, 1) + SUBSTRING([sa].[root_page], 2, 1) + SUBSTRING([sa].[root_page], 1, 1)) AS [root_page]
     , CONVERT(INT, SUBSTRING([sa].[first_page], 6, 1) + SUBSTRING([sa].[first_page], 5, 1)) AS [first_page_file]
     , CONVERT(INT, SUBSTRING([sa].[first_page], 4, 1) + SUBSTRING([sa].[first_page], 3, 1) + SUBSTRING([sa].[first_page], 2, 1) + SUBSTRING([sa].[first_page], 1, 1)) AS [first_page]
     , [sa].[type_desc] --,*
FROM sys.system_internals_allocation_units [sa]
INNER JOIN sys.partitions [sp]
    ON [sa].[container_id] = [sp].[partition_id]
WHERE OBJECT_NAME([sp].[object_id]) = 'TestTable';

PRINT 'right after truncate...................................';
SELECT [Current LSN]
     , LEFT([Operation], 16) AS [Operation]
     , LEFT([AllocUnitName], 30) AS [AllocUnitName]
     , [Page ID]
     , [Slot ID]
FROM sys.fn_dblog(NULL, NULL)
WHERE [Current LSN] > @maxlns;
--select [Current LSN], left(Operation, 16) as Operation, left(AllocUnitName, 30) as AllocUnitName, [Page ID],[Slot ID] from fn_dblog(null, null) where [Current LSN] > @maxlns and AllocUnitName like 'dbo.TestTable%'
SELECT @maxlns = MAX([Current LSN])FROM [sys].[fn_dblog](NULL, NULL);

WAITFOR DELAY '00:02:00';

PRINT '2 minutes after truncate...................................';


DECLARE @maxlns VARCHAR(100);
SELECT @maxlns = MAX([Current LSN]) FROM [sys].[fn_dblog](NULL, NULL);
SELECT @maxlns

SELECT CONVERT(INT, SUBSTRING([sa].[first_iam_page], 6, 1) + SUBSTRING([sa].[first_iam_page], 5, 1)) AS [first_iam_file]
     , CONVERT(INT, SUBSTRING([sa].[first_iam_page], 4, 1) + SUBSTRING([sa].[first_iam_page], 3, 1) + SUBSTRING([sa].[first_iam_page], 2, 1) + SUBSTRING([sa].[first_iam_page], 1, 1)) AS [first_iam_page]
     , CONVERT(INT, SUBSTRING([sa].[root_page], 6, 1) + SUBSTRING([sa].[root_page], 5, 1)) AS [root_page_file]
     , CONVERT(INT, SUBSTRING([sa].[root_page], 4, 1) + SUBSTRING([sa].[root_page], 3, 1) + SUBSTRING([sa].[root_page], 2, 1) + SUBSTRING([sa].[root_page], 1, 1)) AS [root_page]
     , CONVERT(INT, SUBSTRING([sa].[first_page], 6, 1) + SUBSTRING([sa].[first_page], 5, 1)) AS [first_page_file]
     , CONVERT(INT, SUBSTRING([sa].[first_page], 4, 1) + SUBSTRING([sa].[first_page], 3, 1) + SUBSTRING([sa].[first_page], 2, 1) + SUBSTRING([sa].[first_page], 1, 1)) AS [first_page]
     , [sa].[type_desc]
     , [sp].[partition_number]
     , [sp].[hobt_id]
     , [sp].[rows]
FROM sys.system_internals_allocation_units [sa] (NOLOCK)
INNER JOIN sys.partitions [sp] (NOLOCK)
    ON [sa].[container_id] = [sp].[partition_id]
WHERE OBJECT_NAME([sp].[object_id]) = 'TestTable';

SELECT [Current LSN]
     , LEFT([Operation], 16) AS [Operation]
     , [Begin Time]
     , [End Time]
     , [Transaction ID]
     , [Transaction Name]
     , [AllocUnitId]
     , LEFT([AllocUnitName], 30) AS [AllocUnitName]
     --, [Page ID]
     --, [Slot ID]
     --, [PartitionId]
     --, [Lock Information]
     , [Description]
FROM [sys].[fn_dblog](NULL, NULL)
WHERE [Current LSN] >= '00000030:00000548:0001' --@maxlns
AND [Transaction ID] = '0000:00003dfd'
--OR  [Transaction Name] = 'DeferredAllocUnitDrop::Process'
--AND [Slot ID] IS NOT NULL
ORDER BY [Current LSN] --DESC

SELECT COUNT(1) FROM [TestTable] (NOLOCK)

--'0000002a:00007c78:0015'