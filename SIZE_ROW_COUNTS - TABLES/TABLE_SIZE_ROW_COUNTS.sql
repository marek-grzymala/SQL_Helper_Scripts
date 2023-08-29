USE YourDbName
GO

-- Get Table names, row counts, and compression status for clustered index or heap  (Query 56) (Table Sizes)
SELECT 
    s.[name]                            AS [SchemaName],
    t.[name]                            AS [TableName],
    p.[rows]                            AS [RowCounts],
    p.[data_compression_desc]           AS [CompressionType],
    (SUM(a.total_pages) * 8)/1024       AS [TotalSpaceMB], 
    (SUM(a.used_pages) * 8)/1024        AS [UsedSpaceMB], 
    ((SUM(a.total_pages) - SUM(a.used_pages)) * 8)/1024 AS UnusedSpaceMB
FROM 
    sys.tables t (NOLOCK)
INNER JOIN      
    sys.indexes i (NOLOCK) ON t.OBJECT_ID = i.object_id
INNER JOIN 
    sys.partitions p (NOLOCK) ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN 
    sys.allocation_units a (NOLOCK) ON p.partition_id = a.container_id
LEFT OUTER JOIN 
    sys.schemas s (NOLOCK) ON t.schema_id = s.schema_id
WHERE 1 = 1
    --t.NAME = 'TableName'
    AND t.is_ms_shipped = 0
    AND i.OBJECT_ID > 255 
GROUP BY
            s.[name]
           ,t.[name]
           ,p.[rows]
           ,p.[data_compression_desc]
ORDER BY 
    TotalSpaceMB DESC, 
	UsedSpaceMB DESC, 
	t.[name]