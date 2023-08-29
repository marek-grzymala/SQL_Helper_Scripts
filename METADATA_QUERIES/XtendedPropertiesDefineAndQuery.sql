USE [AdventureWorks2019]
GO

IF OBJECT_ID('MyTest', 'U') IS NOT NULL
    DROP TABLE [MyTest];
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [MyTest] ([sno] INT, [myName] CHAR(20))
GO

EXEC sys.sp_addextendedproperty @name = N'SNO'
                              , @value = N'Testing entry for Extended Property'
                              , @level0type = N'Schema'
                              , @level0name = 'dbo'
                              , @level1type = N'Table'
                              , @level1name = 'mytest'
                              , @level2type = N'Column'
                              , @level2name = 'sno'
GO

SELECT 
       [xtp].[name]							AS [@name]
     , CAST([value] AS SQL_VARIANT)			AS [@value]
	 , 'SCHEMA'								AS [@level0type]
	 , SCHEMA_NAME([tbl].[schema_id])		AS [@level0name]
	 , 'TABE'								AS [@level1type]
     , [tbl].[name]							AS [@level1name]
	 , 'COLUMN'								AS [@level2type]
     , [col].[name]							AS [@level2name]
FROM sys.tables								AS [tbl]
INNER JOIN sys.all_columns					AS [col]
    ON [col].object_id = [tbl].object_id
INNER JOIN sys.extended_properties			AS [xtp]
    ON  [xtp].[major_id] = [tbl].[object_id]
    AND [xtp].[minor_id] = [col].[column_id]
    AND [xtp].[class] = 1
WHERE SCHEMA_NAME([tbl].[schema_id]) = 'dbo'
AND   [tbl].[name] = 'MyTest'
GO


SELECT 
		[sch].[schema_id]
		, [obj].[object_id]
		, 'SCHEMA'			 AS [@level0type]     
		, [sch].[name]		 AS [@level0name]
		, [obj].[type_desc] AS [@level1type]
		, [obj].[name]		 AS [@level1name]				
FROM sys.objects [obj]
INNER JOIN sys.schemas AS [sch]
	ON [obj].[schema_id] = [sch].[schema_id]
INNER JOIN sys.columns AS [col]
	ON [obj].[object_id] = [col].[object_id]
INNER JOIN sys.extended_properties AS [xtp]
	ON  [col].[object_id] = [xtp].[major_id]
	AND [col].[column_id] = [xtp].[minor_id]
--WHERE   [obj].[object_id] = [RefVw].[ReferencingObjectId]
WHERE OBJECT_NAME([obj].[object_id]) = N'vProductAndDescription'