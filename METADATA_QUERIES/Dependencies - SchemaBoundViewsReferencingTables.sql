USE [AdventureWorks2019]
GO

/*
SELECT OBJECT_DEFINITION (OBJECT_ID(N'Production.vProductAndDescription')) AS ObjectDefinition; 
SELECT OBJECT_DEFINITION (OBJECT_ID(N'Person.vStateProvinceCountryRegion')) AS ObjectDefinition; 
GO
*/


SELECT 
	   [RefVw].[ReferencingObjectId]
	 , [RefVw].[ReferencingObjectSchema]
	 , [RefVw].[ReferencingObjectName]
	 , [RefVw].[ReferencedObjectId]
	 , [RefVw].[ReferencedObjectSchema]
	 , [RefVw].[ReferencedObjectName]
	 , [sqm].[definition]
	 , [Xtp].[@level0type]
	 , [Xtp].[@level0name]
	 , [Xtp].[@level1type]
	 , [Xtp].[@level1name]
     , [sqm].[uses_ansi_nulls]
     , [sqm].[uses_quoted_identifier]
	 , [sqm].[is_schema_bound]

FROM sys.sql_modules				AS [sqm]
CROSS APPLY
(
	SELECT		DISTINCT
				[ob1].[object_id]	AS [ReferencingObjectId]
			  , [sc1].[name]		AS [ReferencingObjectSchema]
			  , [ob1].[name]		AS [ReferencingObjectName]
			  , [ob2].[object_id]	AS [ReferencedObjectId]
			  , [sc2].[name]		AS [ReferencedObjectSchema]
			  , [ob2].[name]		AS [ReferencedObjectName]
	FROM		sys.sql_expression_dependencies AS [sed]
	INNER JOIN	sys.objects AS [ob1] ON [sed].[referencing_id] = [ob1].[object_id]
	INNER JOIN	sys.schemas AS [sc1] ON [sc1].[schema_id] = [ob1].[schema_id]
	INNER JOIN	sys.objects AS [ob2] ON [sed].[referenced_id]  = [ob2].[object_id]
	INNER JOIN	sys.schemas AS [sc2] ON [sc2].[schema_id] = [ob2].[schema_id]
	WHERE 1 = 1
	AND ob1.[type_desc] = 'VIEW'
	--AND ob2.[object_id] = OBJECT_ID('Production.Product')
) AS [RefVw]

OUTER APPLY (
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
				WHERE   [obj].[object_id] = [RefVw].[ReferencingObjectId]
) AS [Xtp]
WHERE 
	[sqm].[object_id] = [RefVw].[ReferencingObjectId]
AND [sqm].[is_schema_bound] = 1
ORDER BY [ReferencedObjectName]
GO

