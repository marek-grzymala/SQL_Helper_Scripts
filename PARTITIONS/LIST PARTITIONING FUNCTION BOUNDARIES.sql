USE [ColumnstoreMigrationDemo]
GO

SELECT 
             t.name                                      AS [TableName] 
            ,ix.name                                     AS [Index] 
            ,pa.partition_id                             AS [PartitionId]
            ,pr.boundary_id 
            ,CONCAT(pa.partition_number, '/', pf.fanout) AS [PartitionNumber]
            ,pf.name                                     AS [PartFunctionName]
            ,fg.FileGroupName
            ,LEFT(CONVERT(VARCHAR, pr.value, 112),6)     AS [BoundaryValue]
            ,pf.boundary_value_on_right                  AS [BoundaryOnRight]
            ,st.name                                     AS [DataType]
            ,ps.name                                     AS [PartitionScheme]

FROM        sys.tables                 AS t  
INNER JOIN  sys.indexes                AS ix ON t.object_id       = ix.object_id  
INNER JOIN  sys.partitions             AS pa ON ix.object_id      = pa.object_id AND ix.index_id = pa.index_id   
INNER JOIN  sys.partition_schemes      AS ps ON ix.data_space_id  = ps.data_space_id  
INNER JOIN  sys.partition_functions    AS pf ON ps.function_id    = pf.function_id  
LEFT JOIN   sys.partition_range_values AS pr ON pf.function_id    = pr.function_id AND pr.boundary_id = pa.partition_number /* this has to be LEFT JOIN to show "border regions" */
INNER JOIN  sys.partition_parameters   AS pp ON pp.function_id    = pf.function_id
INNER JOIN  sys.types                  AS st ON st.system_type_id = pp.system_type_id
INNER JOIN  sys.system_internals_allocation_units au ON pa.partition_id = au.container_id
OUTER APPLY (
                SELECT
                           sfg.name AS [FileGroupName]            
                FROM
                           sys.destination_data_spaces  AS dds
                INNER JOIN sys.filegroups               AS sfg ON sfg.data_space_id = dds.data_space_id
                WHERE     (ps.name = ps.name AND dds.destination_id = pr.boundary_id)
            )   AS fg
 
ORDER BY pa.partition_number ASC;

/*
SELECT
    CASE c.maxinrowlen
        WHEN 0 THEN p.length  
        ELSE c.maxinrowlen
    END AS max_inrow_length,
    p.xtype AS system_type_id,  
    p.length AS max_length,  
    p.prec AS PRECISION,  
    p.scale AS scale
FROM
    sys.sysrscols c --- sys.system_internals_partition_columns
OUTER APPLY
    OPENROWSET(TABLE RSCPROP, c.ti) p
*/
