USE [AdventureWorks2019]
GO

SELECT 
	   [ss].[name] AS [sch_name]
	 , [st].[name] AS [tbl_name]
     , [st].[schema_id]
	 , [st].[object_id]
     , [st].[is_published]
     , [st].[is_merge_published]
     , [st].[is_schema_published]
FROM sys.[tables] AS [st]
JOIN sys.[schemas] AS [ss] ON [ss].[schema_id] = [st].[schema_id]
WHERE [st].[is_published] = 1
OR    [st].[is_merge_published] = 1
OR    [st].[is_schema_published] = 1;