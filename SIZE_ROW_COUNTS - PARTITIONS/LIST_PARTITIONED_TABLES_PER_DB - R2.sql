USE YourDbName
GO


/*
select distinct t.name
from sys.partitions p
inner join sys.tables t on p.object_id = t.object_id
where p.partition_number <> 1

select 
    object_schema_name(i.object_id) as [schema],
    object_name(i.object_id) as [object_name],
    t.name as [table_name],
    i.name as [index_name],
    s.name as [partition_scheme]
	
from sys.indexes i
    join sys.partition_schemes s on i.data_space_id = s.data_space_id
    join sys.tables t on i.object_id = t.object_id
	--inner join sys.partitions p on p.partition_id = s.
	--INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
*/
; WITH cte AS (
SELECT 
	 SCHEMA_NAME(o.schema_id) + '.' + OBJECT_NAME(i.object_id)                  AS [object]
     , p.partition_number                                                       AS [partition_nr]
     , fg.name                                                                  AS [filegroup]
     , p.rows                                                                   AS [num_rows_per_partition]
     , au.allocation_unit_id                                                    AS [aloc_unit_id]
	 , au.total_pages                                                           AS [AU Total Pages]
	 , str((au.total_pages)*8./1024,10,2)                                       AS [UsedMB]
     , CASE f.boundary_value_on_right
                WHEN 1 THEN 'less than'
                ELSE 'less than or equal to' 
       END                                                                      AS [comparison]
     , rv.value                                                                 AS [range_value]
     , CONVERT (VARCHAR(6), CONVERT (INT, SUBSTRING (au.first_page, 6, 1) +
       SUBSTRING (au.first_page, 5, 1))) + ':' + CONVERT (VARCHAR(20),
       CONVERT (INT, SUBSTRING (au.first_page, 4, 1) +
       SUBSTRING (au.first_page, 3, 1) + SUBSTRING (au.first_page, 2, 1) +
       SUBSTRING (au.first_page, 1, 1)))                                        AS [first_page]
FROM 
	            sys.partitions                          p 
INNER JOIN      sys.indexes                             i   ON p.object_id              = i.object_id AND p.index_id = i.index_id
INNER JOIN      sys.objects                             o   ON p.object_id              = o.object_id
INNER JOIN      sys.system_internals_allocation_units   au  ON p.partition_id           = au.container_id
INNER JOIN      sys.partition_schemes                   ps  ON ps.data_space_id         = i.data_space_id
INNER JOIN      sys.partition_functions                 f   ON f.function_id            = ps.function_id
INNER JOIN      sys.destination_data_spaces             dds ON dds.partition_scheme_id  = ps.data_space_id AND dds.destination_id = p.partition_number
INNER JOIN      sys.filegroups                          fg  ON dds.data_space_id        = fg.data_space_id
LEFT OUTER JOIN sys.partition_range_values              rv  ON f.function_id            = rv.function_id AND p.partition_number = rv.boundary_id

--WHERE OBJECT_NAME(i.object_id) LIKE 'your_table_name'
)
SELECT * FROM cte ORDER BY 
--cte.[object], cte.[partition_nr]
cte.[UsedMB] DESC, cte.num_rows_per_partition DESC