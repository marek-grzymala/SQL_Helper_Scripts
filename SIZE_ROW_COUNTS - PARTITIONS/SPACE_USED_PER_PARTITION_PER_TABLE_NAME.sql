SELECT 
	ISNULL(quotename(ix.name),'Heap') as IndexName 
	, ix.type_desc as type
	, prt.partition_number
	, prt.data_compression_desc
	, ps.name as PartitionScheme
	, pf.name as PartitionFunction
	, fg.name as FilegroupName
	, case when ix.index_id < 2 then prt.rows else 0 END as Rows
	, au.TotalMB
	, au.UsedMB
	, st.name AS [TableName]
	, c.name AS [ColumnName]
	, CASE WHEN pf.boundary_value_on_right = 1 THEN 'less than' WHEN pf.boundary_value_on_right IS NULL THEN '' ELSE 'less than or equal to' END AS Comparison
	, rv.value
FROM 
	sys.partitions prt
	INNER JOIN  sys.indexes ix                      ON ix.object_id = prt.object_id and ix.index_id = prt.index_id
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
						        str(sum(total_pages)*8./1024,10,2) as [TotalMB],str(sum(used_pages)*8./1024,10,2) as [UsedMB]
						        ,container_id
					FROM        sys.allocation_units
					GROUP BY    container_id
				)   au
				ON  au.container_id = prt.partition_id

WHERE st.name IN ('YourTableName')
ORDER BY ix.type_desc;