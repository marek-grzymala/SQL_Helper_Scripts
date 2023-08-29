; WITH cte AS (
SELECT          
                fk.[object_id]                                                                               AS [Foreign_Key_Id]
               ,fk.[name]                                                                                    AS [Foreign_Key_Name]
               ,sch_src.[SchemaName]                                                                         AS [Schema_Name_Src]
               ,(SELECT (OBJECT_NAME(fkc.parent_object_id)))                                                 AS [Table_Name_Src]
               ,fkc.parent_column_id                                                                         AS [Column_Id_Src]
               ,col_src.[name]                                                                               AS [Column_Name_Src]
               ,sch_tgt.[SchemaName]                                                                         AS [Schema_Name_Trgt]                      
               ,(SELECT (OBJECT_NAME(fkc.referenced_object_id)))                                             AS [Table_Name_Trgt]
               ,fkc.referenced_column_id                                                                     AS [Column_Id_Trgt]
               ,col_tgt.[name]                                                                               AS [Column_Name_Trgt]
               ,sch_tgt.[SchemaId]                                                                           AS [Schema_Id_Trgt]
               ,OBJECT_ID('[' + sch_tgt.[SchemaName] + '].[' + OBJECT_NAME(fkc.referenced_object_id) + ']')  AS [Object_Id_Trgt]
FROM            sys.foreign_keys                                             AS fk
CROSS APPLY     (
                    SELECT  
                            fkc.parent_column_id,
                            fkc.parent_object_id,
                            fkc.referenced_object_id,
                            fkc.referenced_column_id
                    FROM    sys.foreign_key_columns                            AS fkc 
                    WHERE   1 = 1
                    AND     fk.parent_object_id = fkc.parent_object_id 
                    AND     fk.referenced_object_id = fkc.referenced_object_id
                    AND     fk.[object_id] = fkc.constraint_object_id
                )                                                              AS  fkc
CROSS APPLY     (
                    SELECT     ss.[name]                                       AS [SchemaName]
                    FROM       sys.objects                                     AS so
                    INNER JOIN sys.schemas                                     AS ss ON ss.[schema_id] = so.[schema_id]
                    WHERE      so.[object_id] = fkc.parent_object_id
                )                                                              AS sch_src
CROSS APPLY     (
                    SELECT sc.[name]      
                    FROM   sys.columns                                         AS sc 
                    WHERE  sc.[object_id] = fk.[parent_object_id] 
                    AND    sc.[column_id] = fkc.[parent_column_id]
                )                                                              AS col_src
CROSS APPLY     (
                    SELECT     ss.[schema_id]                                  AS [SchemaId]
                              ,ss.[name]                                       AS [SchemaName]
                    FROM       sys.objects                                     AS so
                    INNER JOIN sys.schemas                                     AS ss ON ss.[schema_id] = so.[schema_id]
                    WHERE      so.[object_id] = fkc.referenced_object_id
                )                                                              AS sch_tgt
CROSS APPLY     (
                    SELECT sc.[name]      
                    FROM   sys.columns                                         AS sc 
                    WHERE  sc.[object_id] = fk.[referenced_object_id] 
                    AND    sc.[column_id] = fkc.[referenced_column_id]
                )                                                              AS col_tgt
--WHERE (OBJECT_NAME(fkc.parent_object_id)) = 'SalesOrderDetail' /* Filter by Source Table name*/
--WHERE (OBJECT_NAME(fkc.referenced_object_id)) = 'SpecialOfferProduct' /* Filter by Target Table name*/
)
, counts AS (
SELECT
             cte.[Foreign_Key_Id],
             COUNT(cte.[Foreign_Key_Id]) AS [Count]
FROM         cte
GROUP BY     
             cte.[Foreign_Key_Id]
            ,cte.[Schema_Name_Src]
            ,cte.[Table_Name_Src]
            ,cte.[Foreign_Key_Name]
            ,cte.[Schema_Name_Trgt]
            ,cte.[Table_Name_Trgt]
)
SELECT      DISTINCT 
             cte.[Schema_Name_Trgt]      
            ,cte.[Table_Name_Trgt]
FROM        cte         
INNER JOIN  counts ON cte.Foreign_Key_Id = counts.[Foreign_Key_Id]
WHERE       counts.[Count] > 1   
ORDER BY    cte.[Table_Name_Trgt] --counts.[Count] DESC, cte.[Table_Name_Src]
