USE [PartitionTesting]
GO

SELECT DISTINCT
    object_name(i.object_id) AS [Object Name],
    c.name AS [Partition Column],
    s.name AS [Partition Scheme],
    pf.name AS [Partition Function],
    prv.tot AS [Partition Count],
    prv.miVal AS [Min Boundary Value],
    prv.maVal AS [Max Boundary Value]
FROM sys.objects o 
INNER JOIN sys.indexes i ON i.object_id = o.object_id
INNER JOIN sys.columns c ON c.object_id = o.object_id
INNER JOIN sys.index_columns ic ON ic.object_id = o.object_id
    AND ic.column_id = c.column_id
    AND ic.partition_ordinal = 1
RIGHT OUTER JOIN sys.partition_schemes s ON i.data_space_id = s.data_space_id
RIGHT OUTER JOIN sys.partition_functions pf ON pf.function_id = s.function_id
OUTER APPLY(SELECT 
                COUNT(*) tot, MIN(value) miVal, MAX(value) maVal 
            FROM sys.partition_range_values prv 
            WHERE prv.function_id = pf.function_id) prv
--WHERE object_name(i.object_id) = 'table_name'
ORDER BY OBJECT_NAME(i.object_id)