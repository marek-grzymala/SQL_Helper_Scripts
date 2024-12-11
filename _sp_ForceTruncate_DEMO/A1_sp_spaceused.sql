USE [TestDB]
GO

/*--- Summary Partition/AllocationUnit/TotalPages: ---*/

SELECT [o].[name] AS [Table Name]
     , [p].[partition_id] AS [Partition ID]
     , [p].[hobt_id] AS [HOBT ID]
     , [i].[name] AS [Index Name]
     , [i].[type_desc] AS [Index Type]
     , [au].[allocation_unit_id] AS [Allocation Unit ID]
     , [au].[type_desc] AS [Allocation Type]
     , [au].[data_pages]
     , [au].[used_pages]
     , [au].[total_pages]
     , [p].[data_compression_desc] AS [Data Compression]
FROM sys.allocation_units AS [au]
JOIN sys.partitions AS [p]
    ON [p].[hobt_id] = [au].[container_id]
JOIN sys.objects AS [o]
    ON [p].[object_id] = [o].[object_id]
JOIN sys.indexes AS [i]
    ON  [p].[index_id] = [i].[index_id]
    AND [i].[object_id] = [p].[object_id]
WHERE [o].[name] = N'TestTable'
GO

EXEC sp_spaceused @objname = N'dbo.TestTable';

/*
reserved	=	Total amount of space allocated by objects in the database.
data	    =	Total amount of space used by data.
index_size	=	Total amount of space used by indexes.
unused	    =	Total amount of space reserved for objects in the database, but not yet used.
*/

/*---  ExtentIDs/PageIDs per Table Name: ---*/
SELECT 
       [prt].[partition_number]       AS [PartNbr]
     , [alu].[allocation_unit_id]     AS [AlUntId]
     , [alu].[type_desc]              AS [AlUntType]
     , [dpa].[extent_page_id]         AS [ExtentId]
     , [dpa].[page_type_desc]
     , [dpa].[allocated_page_page_id] AS [PageId]
     , [dpa].[is_allocated]
     , [dpa].[page_free_space_percent] AS [Free%]
FROM sys.tables AS [tbl] 
JOIN sys.partitions AS [prt] 
    ON [prt].[object_id] = [tbl].[object_id]
LEFT JOIN sys.dm_db_database_page_allocations(DB_ID(), OBJECT_ID('dbo.TestTable'), NULL, NULL, 'DETAILED') AS [dpa] /* NULLs = return information for all indexes and all partitions */
    ON [prt].object_id = [tbl].[object_id]
LEFT JOIN sys.allocation_units AS [alu]
    ON [alu].[container_id] = [prt].[hobt_id]
WHERE [tbl].[name] = 'TestTable';


DBCC IND('TestDB',TestTable,-1)

SELECT sys.fn_PhysLocFormatter(%%physloc%%) AS [FileID-PageID], * FROM dbo.TestTable;

SELECT 
          [au].[data_space_id]
        , [au].[container_id]      
        , [au].[type_desc]
        , [au].[allocation_unit_id]
        , [au].[total_pages]
        , [au].[used_pages]
        , [au].[data_pages]
FROM sys.allocation_units AS [au]
WHERE [au].[container_id] = (SELECT [hobt_id] FROM sys.partitions WHERE [object_id] = OBJECT_ID('TestTable'));

BEGIN TRANSACTION
DELETE FROM [dbo].[TestTable] WHERE 1 = 1
COMMIT TRANSACTION

TRUNCATE TABLE [dbo].[TestTable]
SELECT * FROM [dbo].[TestTable]
--DROP TABLE IF EXISTS [dbo].[TestTable]

CHECKPOINT;
GO

DBCC DROPCLEANBUFFERS;
GO

DBCC FREEPROCCACHE;
GO

DBCC FREESYSTEMCACHE ('ALL');
GO

DBCC FREESESSIONCACHE
GO
