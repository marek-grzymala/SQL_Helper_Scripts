--USE [YourDbName]
--GO

DROP TABLE IF EXISTS [#MismatchDeatils]
CREATE TABLE [#MismatchDeatils]
(
    [ColNum]         BIGINT
  , [SchemaName]     NVARCHAR(128)
  , [TableName]      NVARCHAR(128)
  , [ColumnName]     NVARCHAR(128)
  , [ColumnId]       INT
  , [DataType]       NVARCHAR(142)
  , [DtMaxLength]    INT
  , [NumOfDataTypes] BIGINT
)


DECLARE @ColNameExceptions TABLE ([ColumnName] SYSNAME NOT NULL PRIMARY KEY CLUSTERED);
INSERT @ColNameExceptions ([ColumnName]) VALUES 
  (N'Name')
, (N'LastName')
, (N'Prefix')
, (N'Code')
, (N'Suffix')
, (N'Value')
, (N'Status')
, (N'StringValue')
, (N'Description')
, (N'Data')

; WITH [DuplicateColNames]
AS (SELECT 
			   [c].[name]			AS [ColumnName]
			 , COUNT([c].[name])	AS [ColumnIdCnt]
    FROM	   [sys].[columns]		AS [c]
    GROUP BY   [name]
    HAVING	   COUNT([column_id]) > 1
)
, [ColDetails]
AS (SELECT
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
    JOIN [DuplicateColNames]	AS [d] ON [d].[ColumnName]	 = [c].[name]
    OUTER APPLY (
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
    LEFT JOIN @ColNameExceptions AS [ex] ON [ex].[ColumnName] = [d].[ColumnName]
    WHERE [s].[name] <> 'sys' AND [ex].[ColumnName] IS NULL
)
, [DataTypeRanks]
AS (SELECT [cld].[ColumnName]
         , DENSE_RANK() OVER (PARTITION BY [cld].[ColumnName] ORDER BY [cld].[DataType]) AS [DataTypeRank]
    FROM [ColDetails] AS [cld]
)
, [FlaggedColumns]
AS (SELECT [dtr].[ColumnName]
         , MAX([dtr].[DataTypeRank]) AS [NumOfDataTypes]
    FROM [DataTypeRanks] AS [dtr]
    GROUP BY [ColumnName]
    HAVING MAX([DataTypeRank]) > 1
)
INSERT INTO [#MismatchDeatils]
    (
        [ColNum]
      , [SchemaName]
      , [TableName]
      , [ColumnName]
      , [ColumnId]
      , [DataType]
      , [DtMaxLength]
      , [NumOfDataTypes]
    )
SELECT 
       ROW_NUMBER() OVER (PARTITION BY [cd].[ColumnName] ORDER BY [cd].[DtMaxLength], [cd].[TableName]) AS [ColNum]
	 , [cd].[SchemaName]
     , [cd].[TableName]
     , [cd].[ColumnName]
     , [cd].[ColumnId]
     , [cd].[DataType]
	 , [cd].[DtMaxLength]
     , [fc].[NumOfDataTypes]
FROM [ColDetails] AS [cd]
INNER JOIN [FlaggedColumns] AS [fc] ON [fc].[ColumnName] = [cd].[ColumnName]
ORDER BY [NumOfDataTypes] DESC, [cd].[ColumnName], [cd].[DtMaxLength], [cd].[TableName]
;

SELECT [ColNum]
     , [SchemaName]
     , [TableName]
     , [ColumnName]
     , [ColumnId]
     , [DataType]
     , [DtMaxLength]
     , [NumOfDataTypes]
FROM [#MismatchDeatils]
ORDER BY [NumOfDataTypes] DESC
       , [ColumnName]
       , [DtMaxLength]
       , [TableName];

/* Summary Aggregations: */
SELECT
    [ColumnName]
  , MAX([ColNum]) AS [NumTablesUsedIn]
  , [NumOfDataTypes]
FROM [#MismatchDeatils]
GROUP BY [ColumnName]
       , [NumOfDataTypes]
ORDER BY [NumOfDataTypes] DESC
       , [ColumnName]

