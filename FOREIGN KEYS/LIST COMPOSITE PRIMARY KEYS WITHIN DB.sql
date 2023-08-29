SELECT 
	   QUOTENAME([ss].[name]) AS [SchemaName]
	 , QUOTENAME([so].[name]) AS [TableName]
     , STRING_AGG(QUOTENAME([sc].[name]), ', ') AS [ColumnList]
     , COUNT([sc].[name]) AS [ColumnCount]
FROM sys.key_constraints AS [kc]
LEFT JOIN sys.[indexes] AS [si]
    ON  [si].[object_id] = [kc].[parent_object_id]
    AND [si].[index_id] = [unique_index_id]
LEFT JOIN sys.index_columns AS [ic]
    ON  [ic].[object_id] = [kc].[parent_object_id]
    AND [ic].[index_id] = [unique_index_id]
LEFT JOIN sys.columns AS [sc]
    ON  [sc].[object_id] = [ic].[object_id]
    AND [sc].[column_id] = [ic].[column_id]
JOIN sys.objects AS [so]
    ON  [so].[object_id] = [kc].[parent_object_id]
    AND [kc].[type] = 'PK'
JOIN sys.schemas AS [ss]
	ON [ss].[schema_id] = [so].[schema_id]
GROUP BY [ss].[name], [so].[name]
HAVING COUNT([sc].[name]) > 1
ORDER BY COUNT([sc].[name]) DESC
GO
