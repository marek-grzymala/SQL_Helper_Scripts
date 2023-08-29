SELECT 
           [o].[object_id]	AS [ObjectId]
         , [s].[name]		AS [SchemaName]
         , [o].[name]		AS [TableName]
         , [c].[column_id]	AS [ColumnId]
         , [c].[name]		AS [ColumnName]
         , IIF( [is_user_defined] = 0,
						  CASE [t].[name]
                               WHEN 'nvarchar'	THEN IIF([c].[max_length] <= 0, CONCAT([t].[name], '(MAX)'), CONCAT([t].[name], '(', [c].[max_length]/2, ')'))
                               WHEN 'varchar'	THEN IIF([c].[max_length] <= 0, CONCAT([t].[name], '(MAX)'), CONCAT([t].[name], '(', [c].[max_length], ')'))
							   WHEN 'nchar'		THEN CONCAT([t].[name], '(', [c].[max_length]/2, ')')
							   WHEN 'char'		THEN CONCAT([t].[name], '(', [c].[max_length], ')')
                               ELSE [t].[name]
                          END,						  
						  CASE [udt].[SystemTypeName]
                               WHEN 'nvarchar'	THEN IIF([udt].[max_length] <= 0, CONCAT([t].[name], '(MAX)'), CONCAT([t].[name], '(', [udt].[max_length]/2, ')'))
                               WHEN 'varchar'	THEN IIF([udt].[max_length] <= 0, CONCAT([t].[name], '(MAX)'), CONCAT([t].[name], '(', [udt].[max_length], ')'))
							   WHEN 'nchar'		THEN CONCAT([t].[name], '(', [udt].[max_length]/2, ')')
							   WHEN 'char'		THEN CONCAT([t].[name], '(', [udt].[max_length], ')')
                               ELSE [udt].[SystemTypeName]
                          END
              )				   AS [DataType]
         , IIF( [is_user_defined] = 0,
						  CASE [t].[name]
                               WHEN 'nvarchar'	THEN IIF([c].[max_length] <= 0, 1073741822, [c].[max_length]/2)
                               WHEN 'varchar'	THEN IIF([c].[max_length] <= 0, 2147483645, [c].[max_length])
							   WHEN 'nchar'		THEN [c].[max_length]/2
							   WHEN 'char'		THEN [c].[max_length]
							   WHEN 'xml'		THEN 2147483645
                               ELSE [c].[max_length]
                          END,
						  CASE [udt].[SystemTypeName]
                               WHEN 'nvarchar'	THEN IIF([udt].[max_length] <= 0, 1073741822, [udt].[max_length]/2)
                               WHEN 'varchar'	THEN IIF([udt].[max_length] <= 0, 2147483645, [udt].[max_length])
							   WHEN 'nchar'		THEN [udt].[max_length]/2
							   WHEN 'char'		THEN [udt].[max_length]
							   WHEN 'xml'		THEN 2147483645
                               ELSE [udt].[max_length]
                          END
              )				   AS [DtMaxLength]
    FROM [sys].[objects]		AS [o]
    JOIN [sys].[schemas]		AS [s] ON [s].[schema_id]	 = [o].[schema_id]
    JOIN [sys].[columns]		AS [c] ON [o].[object_id]	 = [c].[object_id]
    JOIN [sys].[types]			AS [t] ON [c].[user_type_id] = [t].[user_type_id]
    CROSS APPLY (
                    SELECT TYPE_NAME([system_type_id]) AS [SystemTypeName]
                         , [max_length]
                         , [precision]
                         , [scale]
                         , [collation_name]
                         , [is_nullable]
                    FROM   [sys].[types] AS [st]
                    WHERE  [is_user_defined] = 1
                    AND    [user_type_id] = [c].[user_type_id]
                    AND    [system_type_id] = [t].[system_type_id]
                )   AS [udt]
ORDER BY
 [SchemaName]
,[TableName]
,[ColumnName]