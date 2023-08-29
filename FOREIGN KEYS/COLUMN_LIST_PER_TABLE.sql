SELECT
                    schema_name(o.schema_id)                                   AS [object_schema]                   
                   ,object_name(c.object_id)                                   AS [object_name]
                   -- columns / data types
                   ,c.name                                                     AS [column_name]
                   ,c.column_id
                   ,schema_name(t.schema_id)                                   AS [type_schema]
                   ,c.is_nullable                                              AS [is_nullable]
                   ,t.name                                                     AS [type_name]
                   ,c.max_length
                   ,c.precision
                   ,c.scale
                   -- primary key / indexes
                   ,i.name                                                     AS [index_name]
                   ,is_identity
                   ,i.is_unique                                                AS [is_unique]
                   ,i.is_primary_key
                   ,CAST(CASE i.index_id WHEN 1 THEN 1 ELSE 0 END AS bit)      AS [is_clustered]
                   -- foreign key
                   ,f.name                                                     AS [foreign_key_name]
                   ,sch_tgt.SchemaName                                         AS [referenced_object_schema]
                   ,object_name (f.referenced_object_id)                       AS [referenced_object_name]
                   ,col_name(fc.referenced_object_id, fc.referenced_column_id) AS [referenced_column_name]
FROM                sys.columns             AS c
INNER JOIN          sys.objects             AS o    ON o.object_id = c.object_id
INNER JOIN          sys.types               AS t    ON c.user_type_id=t.user_type_id
LEFT OUTER JOIN     sys.index_columns       AS ic   ON ic.object_id = c.object_id and c.column_id = ic.column_id
LEFT OUTER JOIN     sys.indexes             AS i    ON i.object_id = ic.object_id and i.index_id = ic.index_id
LEFT OUTER JOIN     sys.foreign_key_columns AS fc   ON fc.parent_object_id = c.object_id and col_name(fc.parent_object_id, fc.parent_column_id) = c.name
LEFT OUTER JOIN     sys.foreign_keys        AS f    ON f.parent_object_id = c.object_id and fc.constraint_object_id = f.object_id
OUTER APPLY     (
                    SELECT     ss.[schema_id]                                  AS [SchemaId]
                              ,ss.[name]                                       AS [SchemaName]
                    FROM       sys.objects                                     AS so
                    INNER JOIN sys.schemas                                     AS ss ON ss.[schema_id] = so.[schema_id]
                    WHERE      so.[object_id] = fc.referenced_object_id
                )                                                              AS sch_tgt
WHERE               c.object_id = object_id('[dbo].[FactResellerSalesXL_PageCompressed]')
ORDER BY            [object_name], c.column_id;