USE [AdventureWorks2019]
GO


DECLARE @SchemaNames                         NVARCHAR(MAX) = N'Sales,Production,HumanResources,Person'						-- N'dbo,uk,us'
      , @TableNames                          NVARCHAR(MAX) = N'SpecialOfferProduct,Product,Employee,BusinessEntity,Person'	-- N'LoadControlClient,ControlClient' 
      , @Delimiter                           CHAR(1)       = ',' /* character used to delimit the item(s) in the lists above */

SELECT	DISTINCT 
	    SCHEMA_ID([sn].[value])												AS [SchemaID]
	  , OBJECT_ID(QUOTENAME([sn].[value]) + '.' + QUOTENAME([tn].[value]))	AS [ObjectID]
	  , [sn].[value]														AS [SchemaName]
	  , [tn].[value]														AS [TableName]
FROM 
STRING_SPLIT(@SchemaNames, @Delimiter)										AS [sn]
LEFT JOIN INFORMATION_SCHEMA.SCHEMATA										AS [sch]
    ON  [sch].[SCHEMA_NAME] = LTRIM(RTRIM([sn].[value])),
STRING_SPLIT(@TableNames, @Delimiter)										AS [tn]
LEFT JOIN INFORMATION_SCHEMA.TABLES											AS [tbl]
    ON  [tbl].[TABLE_NAME] = LTRIM(RTRIM([tn].[value]))
WHERE OBJECT_ID(QUOTENAME([sn].[value]) + '.' + QUOTENAME([tn].[value])) IS NOT NULL 

