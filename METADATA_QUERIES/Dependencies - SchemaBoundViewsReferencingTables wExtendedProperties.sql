USE [AdventureWorks2019]
GO

/*
SELECT OBJECT_DEFINITION (OBJECT_ID(N'Production.vProductAndDescription')) AS ObjectDefinition; 
SELECT OBJECT_DEFINITION (OBJECT_ID(N'Person.vStateProvinceCountryRegion')) AS ObjectDefinition; 
GO
*/

DECLARE @SqlCreateView      NVARCHAR(MAX)
      , @ReferencedTableName SYSNAME      = 'Production.Product'
      , @level0type          VARCHAR(128)
      , @level0name          SYSNAME
      , @level1type          VARCHAR(128)
      , @level1name          SYSNAME
	  , @crlf				 CHAR(2) = CHAR(13)+CHAR(10)

DROP TABLE IF EXISTS [#ExtendedProperties];
CREATE TABLE [#ExtendedProperties] 
(
  [objtype] VARCHAR(128)  NOT NULL
, [objname] NVARCHAR(128) NOT NULL
, [name]	NVARCHAR(128) NOT NULL
, [value]	SQL_VARIANT	  NOT NULL
)

SELECT 

	   @SqlCreateView = [Sqm].[definition]
	 , @level0type	   = [Xtp].[@level0type]
	 , @level0name	   = [Xtp].[@level0name]
	 , @level1type	   = [Xtp].[@level1type]
	 , @level1name	   = [Xtp].[@level1name]

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
	AND [ob1].[object_id] = [sqm].[object_id]
	AND ob1.[type_desc] = 'VIEW'
	AND [sqm].[is_schema_bound] = 1
	AND ob2.[object_id] = OBJECT_ID(@ReferencedTableName)
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

TRUNCATE TABLE [#ExtendedProperties]
INSERT INTO [#ExtendedProperties] ([objtype], [objname], [name], [value])
SELECT [objtype]
     , [objname]
     , [name]
     , [value]
FROM [sys].fn_listextendedproperty(NULL, @level0type, @level0name, @level1type, @level1name, NULL, NULL)

IF (SELECT COUNT(1) FROM [#ExtendedProperties]) > 0 
BEGIN
	SELECT @SqlCreateView = CONCAT(@SqlCreateView, 
	CONCAT(
		   @crlf /* no idea whay but this has to be there otherwise syntax check fails */		 
		 , 'GO'
		 , @crlf
		 , 'EXEC [sys].[sp_addextendedproperty] @name = '''
		 , [name]
		 , ''', @value = '''
		 , CONVERT(NVARCHAR(MAX), [value])
		 , ''', @level0type = '''
		 , @level0type
		 , ''', @level0name = '''
		 , @level0name
		 , ''', @level1type = '''
		 , @level1type
		 , ''', @level1name = '''
		 , @level1name
		 , ''';'
		 )
	)
FROM [#ExtendedProperties]
END
SELECT @SqlCreateView