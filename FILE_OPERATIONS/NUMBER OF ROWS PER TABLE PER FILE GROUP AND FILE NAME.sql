SELECT 
 	  ss.[name]				AS [SchemaName]
	, st.[name]				AS [TableName]  
	, fg.[name]				AS [FilegroupName]
	, ix.[name]				AS [IndexName]
	, df.[physical_name]	AS [FileName]
	, CASE WHEN ix.index_id < 2 THEN prt.rows ELSE 0 END AS [NumOfRows]
	, CAST(au.TotalMB AS DECIMAL(10,2)) AS [TotalMB]
	, CAST(au.UsedMB  AS DECIMAL(10,2)) AS [UsedMB]
FROM 
	sys.partitions							AS prt
	INNER JOIN  sys.indexes					AS ix  ON ix.object_id				= prt.object_id AND ix.index_id = prt.index_id                                          
	INNER JOIN  sys.tables					AS st  ON prt.object_id				= st.object_id
	INNER JOIN  sys.schemas					AS ss  ON ss.[schema_id]			= st.[schema_id]                                          
	INNER JOIN  sys.data_spaces				AS ds  ON ds.data_space_id			= ix.data_space_id                                                                  
	LEFT JOIN   sys.partition_schemes		AS ps  ON ps.data_space_id			= ix.data_space_id                                                                  
	LEFT JOIN   sys.partition_functions		AS pf  ON pf.function_id			= ps.function_id                                                                      
	LEFT JOIN   sys.partition_range_values	AS rv  ON rv.function_id			= pf.function_id AND rv.boundary_id = prt.partition_number                            
	LEFT JOIN   sys.destination_data_spaces	AS dds ON dds.partition_scheme_id	= ps.data_space_id AND dds.destination_id = prt.partition_number             
	LEFT JOIN   sys.filegroups				AS fg  ON fg.data_space_id			= ISNULL(dds.data_space_id,ix.data_space_id)
	LEFT JOIN	sys.database_files			AS df  ON df.data_space_id			= fg.data_space_id
	INNER JOIN (
					SELECT 
                                 SUM((total_pages)*8./1024) AS [TotalMB]
                                ,SUM((used_pages)*8./1024)  AS [UsedMB]
						        ,container_id
					FROM        sys.allocation_units
					GROUP BY    container_id
				)   au
				ON  au.container_id = prt.partition_id                                                                                                                                  
--WHERE au.UsedMB > 0
ORDER BY [au].[UsedMB] DESC 