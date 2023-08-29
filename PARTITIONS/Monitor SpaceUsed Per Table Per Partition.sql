; WITH cte AS (
SELECT 
 	  st.name AS [TableName]  
	, prt.partition_number
	, ps.name as PartitionScheme
	, pf.name as PartitionFunction
	, fg.name as FilegroupName
	, CASE WHEN ix.index_id < 2 THEN prt.rows ELSE 0 END AS [NumOfRows]
	, au.TotalMB
	, au.UsedMB
	, c.name AS [ColumnName]
	, CASE WHEN pf.boundary_value_on_right = 1 THEN 'less than' WHEN pf.boundary_value_on_right IS NULL THEN '' ELSE 'less than or equal to' END AS Comparison
	, rv.value
    , prt.data_compression_desc                    AS [DataCompression]
    , ISNULL(QUOTENAME(ix.name),'Heap') as IndexName 
	, ix.type_desc as [type]
    , prt.data_compression_desc
FROM 
	sys.partitions prt
	INNER JOIN  sys.indexes ix                      ON ix.object_id = prt.object_id AND ix.index_id = prt.index_id                                          
	INNER JOIN  sys.tables st                       ON prt.object_id = st.object_id                                                                         
	INNER JOIN  sys.index_columns ic                ON (ic.partition_ordinal > 0 AND ic.index_id = ix.index_id AND ic.object_id = st.object_id)             
	INNER JOIN  sys.columns c                       ON (c.object_id = ic.object_id AND c.column_id = ic.column_id)                                          
	INNER JOIN  sys.data_spaces ds                  ON ds.data_space_id = ix.data_space_id                                                                  
	LEFT JOIN   sys.partition_schemes ps            ON ps.data_space_id = ix.data_space_id                                                                  
	LEFT JOIN   sys.partition_functions pf          ON pf.function_id = ps.function_id                                                                      
	LEFT JOIN   sys.partition_range_values rv       ON rv.function_id = pf.function_id AND rv.boundary_id = prt.partition_number                            
	LEFT JOIN   sys.destination_data_spaces dds     ON dds.partition_scheme_id = ps.data_space_id AND dds.destination_id = prt.partition_number             
	LEFT JOIN   sys.filegroups fg                   ON fg.data_space_id = ISNULL(dds.data_space_id,ix.data_space_id)                                        
	INNER JOIN (
					SELECT 
						         --STR(sum(total_pages)*8./1024, 10,2) as [TotalMB]
                                 --,STR(sum(used_pages)*8./1024, 10,2) as [UsedMB]
                                 SUM(total_pages)*8./1024 as [TotalMB]
                                ,SUM(used_pages)*8./1024 as [UsedMB]
						        ,container_id
					FROM        sys.allocation_units
					GROUP BY    container_id
				)   au
				ON  au.container_id = prt.partition_id
                                                                                                                                   

--WHERE au.UsedMB > 0
)
SELECT 
        *
        -- cte.TableName
        --,SUM(cte.rows)                   AS [NumberOfRecords]
        --,cte.[PartitionScheme]           AS [PartitionScheme]
        --,COUNT(cte.[partition_number])   AS [NumOfPartitions]
        --,cte.MinVaue                     AS [MinTransactionDate]
        --,cte.MaxVaue                     AS [MaxTransactionDate]
        --,cte.[DataCompression]           AS [DataCompression]
        --,STR(SUM(cte.TotalMB), 10,2)     AS [TotalMB]
        --,STR(SUM(cte.UsedMB), 10,2)      AS [UsedMB]

FROM cte 
WHERE   1 = 1
--AND     cte.TableName IN ('YourTableName')
--AND     cte.UsedMB > 0
--AND     cte.Rows > 0

--GROUP BY cte.TableName
--        , cte.[DataCompression]
--        , cte.[PartitionScheme]
--        , cte.[MinVaue]
--        , cte.[MaxVaue]
--        , cte.[partition_number]
ORDER BY cte.TableName DESC, cte.partition_number;


