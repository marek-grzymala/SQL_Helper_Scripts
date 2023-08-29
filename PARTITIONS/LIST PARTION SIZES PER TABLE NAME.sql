-- extended info added to https://www.cathrinewilhelmsen.net/2015/04/12/table-partitioning-in-sql-server/


SELECT
	     OBJECT_SCHEMA_NAME(pst.object_id)          AS [SchemaName]
	  ,  OBJECT_NAME(pst.object_id)                 AS [TableName]
      ,  fg.name                                    AS [Filegroup]
--	  ,  ds.name                                    AS [PartitionFilegroupName]
	  ,  ps.name                                    AS [PartitionSchemeName]
	  ,  pf.name                                    AS [PartitionFunctionName]
	  ,  CASE pf.boundary_value_on_right WHEN 0 THEN 'Range Left' ELSE 'Range Right' END        AS [PartitionFunctionRange]
	  ,  CASE pf.boundary_value_on_right WHEN 0 THEN 'Upper Boundary' ELSE 'Lower Boundary' END AS [PartitionBoundary]
	  ,  prv.value                                  AS [PartitionBoundaryValue]
	  ,  col.name                                   AS [PartitionKey]
	  ,  CASE 
	  	   WHEN pf.boundary_value_on_right = 0 
	  	   THEN col.name + ' > ' + CAST(ISNULL(LAG(prv.value) OVER(PARTITION BY pst.object_id ORDER BY pst.object_id, pst.partition_number), 'Infinity') AS VARCHAR(100)) + ' and ' + col.name + ' <= ' + CAST(ISNULL(prv.value, 'Infinity') AS VARCHAR(100)) 
	  	   ELSE col.name + ' >= ' + CAST(ISNULL(prv.value, 'Infinity') AS VARCHAR(100))  + ' and ' + col.name + ' < ' + CAST(ISNULL(LEAD(prv.value) OVER(PARTITION BY pst.object_id ORDER BY pst.object_id, pst.partition_number), 'Infinity') AS VARCHAR(100))
	     END AS PartitionRange
	  ,  pst.partition_number                       AS [Part.Number]
	  ,  pst.row_count                              AS [PartitionRowCount]
      ,  au.total_pages                             AS [AU Total Pages]
      ,  STR((au.total_pages)*8./1024,10,2)         AS [UsedMB]
	  ,  p.data_compression_desc                    AS [DataCompression]
FROM 
            sys.dm_db_partition_stats               AS pst
INNER JOIN  sys.partitions                          AS p    ON pst.partition_id = p.partition_id
INNER JOIN  sys.destination_data_spaces             AS dds  ON pst.partition_number = dds.destination_id
INNER JOIN  sys.data_spaces                         AS ds   ON dds.data_space_id = ds.data_space_id
INNER JOIN  sys.partition_schemes                   AS ps   ON dds.partition_scheme_id = ps.data_space_id
INNER JOIN  sys.partition_functions                 AS pf   ON ps.function_id = pf.function_id
INNER JOIN  sys.indexes                             AS ix   ON pst.object_id = ix.object_id AND pst.index_id = ix.index_id AND dds.partition_scheme_id = ix.data_space_id AND ix.type <= 6 /* Heap or Clustered Index or Columnstore */
---------------------
INNER JOIN  sys.objects                             AS o    ON p.object_id       = o.object_id
INNER JOIN  sys.system_internals_allocation_units   AS au   ON p.partition_id    = au.container_id
INNER JOIN  sys.filegroups                          AS fg   ON dds.data_space_id = fg.data_space_id
---------------------
INNER JOIN  sys.index_columns                       AS ic   ON ix.index_id = ic.index_id AND ix.object_id = ic.object_id AND ic.partition_ordinal > 0
INNER JOIN  sys.columns                             AS col  ON pst.object_id = col.object_id AND ic.column_id = col.column_id
LEFT JOIN   sys.partition_range_values              AS prv  ON pf.function_id = prv.function_id AND pst.partition_number = (CASE pf.boundary_value_on_right WHEN 0 THEN prv.boundary_id ELSE (prv.boundary_id+1) END)
WHERE 1 = 1
--AND     pst.object_id = OBJECT_ID('TableName')
--AND     pst.row_count > 0
ORDER BY [TableName], [Part.Number];