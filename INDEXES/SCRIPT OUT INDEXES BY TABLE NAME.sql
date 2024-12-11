USE [AdventureWorks2019];
GO

DECLARE @ObjectId INT = OBJECT_ID('[Person].[Person]')

SELECT 
       [si].[index_id] AS [IndexId]
     , [si].[type] AS [IndexType]
     , 'CREATE '
     , CASE WHEN [si].[is_unique] = 1 THEN ' UNIQUE ' ELSE '' END AS [IsUnique]
     , CASE WHEN [xm].[xml_index_type] = 0 THEN ' PRIMARY ' 
            WHEN [xm].[xml_index_type] = 1 THEN ' ' 
            ELSE '' END                                                             AS [XmlType]
     , IIF([xm].[xml_index_type] = 1, CONCAT(' USING XML INDEX ', QUOTENAME([use].[name]), ' FOR ', [xm].[secondary_type_desc] COLLATE SQL_Latin1_General_CP1_CI_AS), '') AS [UsingXmlIndex]    
     , [si].[type_desc] AS [IndexTypeDescr]
     , ' INDEX '
     , QUOTENAME([si].[name]) AS [IndexName], ' ON '
     , CONCAT(QUOTENAME([ss].[name]), '.', QUOTENAME([so].[name]), ' ') [OnTable]
     , [colidx].[ColumnListIndexed]
     , IIF([colincl].[ColumnListIncl] IS NOT NULL, [colincl].[ColumnListIncl], '') AS [ColumnListIncluded]
     , IIF([si].[type] <> 3, CONCAT(' ON ', [ds].[name]), '' ) AS [OnFgPsName]
     , CASE [si].[has_filter]
           WHEN 1 THEN CONCAT('WHERE ', [si].[filter_definition])
           ELSE ''
       END AS [FilteredDefinition]
FROM sys.indexes AS [si]
JOIN sys.objects AS [so]
    ON [so].[object_id] = [si].[object_id]
JOIN sys.schemas AS [ss]
    ON [ss].[schema_id] = [so].[schema_id]
JOIN sys.data_spaces AS [ds]
    ON [si].[data_space_id] = [ds].[data_space_id]
LEFT JOIN sys.xml_indexes AS [xm]
    ON [xm].[index_id] = [si].[index_id]
    AND [xm].[object_id] = [so].[object_id]
LEFT JOIN sys.xml_indexes AS [use]
    ON  [use].[index_id] = [xm].[using_xml_index_id]
    AND [use].[object_id] = [xm].[object_id]
CROSS APPLY 
(
    SELECT DISTINCT
       CONCAT('(', STRING_AGG(   QUOTENAME([_sc].[name]) 
                                        + CASE
                                               WHEN [_si].[type] < 3
                                               AND  [_ic].[is_descending_key] = 1 THEN ' DESC'
                                               WHEN [_si].[type] < 3
                                               AND  [_ic].[is_descending_key] = 0 THEN ' ASC'
                                               ELSE ''
                                           END
                   , ', '
                 )WITHIN GROUP(ORDER BY [_ic].[key_ordinal]), ')') AS [ColumnListIndexed]
    FROM sys.indexes AS [_si]
    JOIN sys.data_spaces AS [_ds]
        ON [_si].[data_space_id] = [_ds].[data_space_id]
    JOIN sys.objects AS [_so]
        ON [_si].[index_id] = [si].[index_id]
        AND [_si].[object_id] = [so].[object_id]
    JOIN sys.schemas AS [_ss]
        ON [_ss].[schema_id] = [_so].[schema_id]
    JOIN sys.index_columns AS [_ic]
        ON  [_ic].[object_id]   = [_so].[object_id]
        AND [_si].[object_id] = [_so].[object_id]
    JOIN sys.columns AS [_sc]
        ON  [_sc].[object_id] = [_ic].[object_id]
        AND [_sc].[column_id] = [_ic].[column_id]
        AND [_ic].[index_id] = [_si].[index_id]
    WHERE [_so].[is_ms_shipped] <> 1
    AND   [_si].[is_hypothetical] = 0
    AND   [_si].[type] > 1 /* excluding heap and clustered objects */
    AND   [_si].[index_id] <> 0
    AND   [_si].[is_primary_key] = 0
    AND   [_ic].[is_included_column] = 0
    GROUP BY [_si].[index_id]
)   AS [colidx]
OUTER APPLY 
(
    SELECT [_si].[index_id], 
         CONCAT('INCLUDE (', STRING_AGG(QUOTENAME([_sc].[name]), ', ') WITHIN GROUP(ORDER BY [_ic].[key_ordinal]) , ')') AS [ColumnListIncl]
    FROM sys.indexes AS [_si]
    JOIN sys.data_spaces AS [_ds]
        ON [_si].[data_space_id] = [_ds].[data_space_id]
    JOIN sys.objects AS [_so]
        ON [_si].[index_id] = [si].[index_id]
        AND [_si].[object_id] = [so].[object_id]
    JOIN sys.schemas AS [_ss]
        ON [_ss].[schema_id] = [_so].[schema_id]
    JOIN sys.index_columns AS [_ic]
        ON  [_ic].[object_id]   = [_so].[object_id]
        AND [_si].[object_id] = [_so].[object_id]
    JOIN sys.columns AS [_sc]
        ON  [_sc].[object_id] = [_ic].[object_id]
        AND [_sc].[column_id] = [_ic].[column_id]
        AND [_ic].[index_id] = [_si].[index_id]
    WHERE [_so].[is_ms_shipped] <> 1
    AND   [_si].[is_hypothetical] = 0
    AND   [_si].[type] > 1 /* excluding heap and clustered objects */
    AND   [_si].[index_id] <> 0
    AND   [_si].[is_primary_key] = 0
    AND   [_ic].[is_included_column] = 1
    GROUP BY [_si].[index_id]
)   AS [colincl]
WHERE [si].[object_id] = @ObjectId
