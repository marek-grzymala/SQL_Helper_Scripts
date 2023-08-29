USE [YourDbName]
GO

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO
 
IF OBJECT_ID('tempdb..#HeapList') IS NOT NULL
    DROP TABLE #HeapList
 
CREATE TABLE #HeapList
    (
    object_name sysname
    ,page_count int
    ,avg_page_space_used_in_percent float
    ,record_count int
    ,forwarded_record_count int
    )
 
DECLARE HEAP_CURS CURSOR FOR
    SELECT object_id
    FROM sys.indexes i
    WHERE index_id = 0
 
DECLARE @IndexID int
 
OPEN HEAP_CURS
FETCH NEXT FROM HEAP_CURS INTO @IndexID
 
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO #HeapList
    SELECT 
		object_name(object_id) as ObjectName
        ,page_count
        ,avg_page_space_used_in_percent
        ,record_count
        ,forwarded_record_count
    FROM sys.dm_db_index_physical_stats (db_id(), @IndexID,  0, null,  'DETAILED'); 
 
    FETCH NEXT FROM HEAP_CURS INTO @IndexID
END
 
CLOSE HEAP_CURS
DEALLOCATE HEAP_CURS
 
SELECT 
		[object_name]
        ,page_count
        ,avg_page_space_used_in_percent
        ,record_count
        ,forwarded_record_count
		, page_count + forwarded_record_count AS [Logical Reads Needed]
FROM #HeapList
WHERE forwarded_record_count > 1000
ORDER BY 1
 
-- DBCC CLEANTABLE ('DB Name','Table Name');
/*
http://sqlblog.com/blogs/kalen_delaney/archive/2008/05/25/whats-worse-than-a-table-scan.aspx:
DBCC CLEANTABLE will not cleanup forwarded records if that is the only thing 'wrong' with the record. 
It will reclaim space from records that have dropped variable-length, SLOB, or LOB columns.
If you have a heap where some records are forwarded *and* have one of the situations above, 
it may seem like DBCC CLEANTABLE is removing forwarded records too, but it's really just an artifact 
of the way DBCC CLEANTABLE removes the dropped column space.
*/