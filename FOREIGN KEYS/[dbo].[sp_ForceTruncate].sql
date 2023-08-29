/*============================================================================
  File:     sp_ForceTruncate

  Summary:  This procedure drops all foreign keys referencing the table
			specified as parameter, truncates the table and recreates 
			all previously dropped foreign keys
			
  Date:     June 2023

  Runs on SQL Versions:	SQL Server 2005/2008/2008R2/2012/2014/2016/2019

  ------------------------------------------------------------------------------
  Example use:

  USE [AdventureWorks2019]
  GO

  EXEC sp_ForceTruncate 
	 @SchemaNames = 'Sales;Production;HumanResources;Person;'
	,@TableNames  = 'SpecialOfferProduct;Product;Employee;BusinessEntity;'
	,@Delimiter = ';'

select count(*) from Sales.SpecialOfferProduct
select count(*) from Production.Product
select count(*) from HumanResources.Employee
select count(*) from Person.BusinessEntity


  USE [SIRIUS1_DEV_MG]
  GO

  EXEC sp_ForceTruncate 
	 @SchemaNames = 'dbo;'
	,@TableNames = 'Client;'
	,@Delimiter = ';'
------------------------------------------------------------------------------
  Written by CleanSql.com © 

  For more scripts and sample code, check out http://www.CleanSql.com
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

USE [master]
GO

IF OBJECTPROPERTY(OBJECT_ID('sp_ForceTruncate'), 'IsProcedure') = 1
    DROP PROCEDURE [sp_ForceTruncate]
GO

CREATE PROCEDURE [sp_ForceTruncate]
(
    @SchemaNames NVARCHAR(MAX)
  , @TableNames  NVARCHAR(MAX)
  , @Delimiter         CHAR(1)   /* character used to delimit and terminate the item(s) in the lists above */
  , @DropAllFKsPerDB   BIT = 0   /* Set @DropAllFKsPerDB to = 1 ONLY if you want to ignore the @SchemaNames/@TableNames 
									specified above and  drop/re-create commands for ALL FK constraints within the ENTIRE DB */
)
AS
BEGIN

DECLARE @ObjectId                 INT
      , @SchemaId                 INT
      , @ErrorMsg                 NVARCHAR(2047)
      , @StartSearchSch           INT
      , @DelimiterPosSch          INT
      , @SchemaName               SYSNAME
      , @TableName                SYSNAME
      , @StartSearchTbl           INT
      , @DelimiterPosTbl          INT
      , @SqlSchemaIdEngineVersion INT
      , @LineId                   INT
      , @LineIdMax                INT
      
	  , @SqlCte                   NVARCHAR(MAX)
      , @SqlSelect                NVARCHAR(MAX)
      , @SqlInsert                NVARCHAR(MAX)
      , @SqlSchemaId              NVARCHAR(MAX)
      , @SqlDropConstraint        NVARCHAR(MAX)
      , @SqlTruncateTable         NVARCHAR(MAX)
      , @SqlRecreateConstraint    NVARCHAR(MAX)
      
	  , @ParamDefinition          NVARCHAR(500)
	  , @ErrorMessage			  NVARCHAR(4000)
	  , @ErrorSeverity			  INT
	  , @ErrorState				  INT;
	  
DROP TABLE IF EXISTS [#SelectedObjectList]
CREATE TABLE [#SelectedObjectList]
(
    [Id]         INT     PRIMARY KEY CLUSTERED IDENTITY(1, 1)
  , [SchemaID]   INT     NOT NULL
  , [SchemaName] SYSNAME NOT NULL
  , [ObjectID]   INT     NOT NULL
  , [TableName]  SYSNAME NOT NULL
)

DROP TABLE IF EXISTS [#ForeignKeyConstraintDefinitions]
CREATE TABLE [#ForeignKeyConstraintDefinitions]
(
	 [LineId]                      INT PRIMARY KEY CLUSTERED IDENTITY(1,1)
    ,[ForeignKeyId]                INT UNIQUE NOT NULL
	,[DropConstraintCommand]       NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[RecreateConstraintCommand]   NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)

/* ----------------------------------- Search through @SchemaNames: ----------------------------------- */
SET @StartSearchSch = 0
SET @DelimiterPosSch = 0
IF (@DropAllFKsPerDB <> 1)
BEGIN
    WHILE CHARINDEX(@Delimiter, @SchemaNames, @StartSearchSch + 1) > 0
    BEGIN
        SET @DelimiterPosSch = CHARINDEX(@Delimiter, @SchemaNames, @StartSearchSch + 1) - @StartSearchSch
        SET @SchemaName = SUBSTRING(@SchemaNames, @StartSearchSch, @DelimiterPosSch)
        SET @SchemaId = NULL;

        SET @SqlSchemaId = CONCAT('SELECT @_SchemaId = schema_id FROM [', DB_NAME(), '].sys.schemas WHERE name = @_SchemaName');			  
  SET @ParamDefinition = N'@_SchemaName SYSNAME, @_SchemaId INT OUTPUT';			  
  EXEC sp_executesql @SqlSchemaId, @ParamDefinition, @_SchemaName = @SchemaName, @_SchemaId = @SchemaId OUTPUT;

        IF (@SchemaId IS NOT NULL)
           /* ----------------------------------- Search through @TableNames: ----------------------------------- */
           BEGIN
               SET @StartSearchTbl = 0
               SET @DelimiterPosTbl = 0
               
               WHILE CHARINDEX(@Delimiter, @TableNames, @StartSearchTbl + 1) > 0
               BEGIN
                   SET @DelimiterPosTbl = CHARINDEX(@Delimiter, @TableNames, @StartSearchTbl + 1) - @StartSearchTbl
                   SET @TableName = SUBSTRING(@TableNames, @StartSearchTbl, @DelimiterPosTbl)
                   
                   SET @ObjectId = NULL;
                   SET @ObjectId = OBJECT_ID('[' + @SchemaName + '].[' + @TableName + ']');
 
				   IF (@ObjectId IS NOT NULL)
                   BEGIN
                       INSERT INTO [#SelectedObjectList] ( 
                                   [SchemaID]
                                  ,[SchemaName]             
                                  ,[ObjectID] 
                                  ,[TableName]             
                       )
                       VALUES (
                                   @SchemaId
                                  ,@SchemaName
                                  ,@ObjectId
                                  ,@TableName
                       )
                   END
                   SET @StartSearchTbl = CHARINDEX(@Delimiter, @TableNames, @StartSearchTbl + @DelimiterPosTbl) + 1
               END
           END
           /* ----------------------------------- End of Seaching through @TableNames -------------------------------- */
        SET @StartSearchSch = CHARINDEX(@Delimiter, @SchemaNames, @StartSearchSch + @DelimiterPosSch) + 1
    END
END
ELSE
BEGIN
        INSERT INTO [#SelectedObjectList] ( 
                    [SchemaID]
                   ,[SchemaName]             
                   ,[ObjectID] 
                   ,[TableName]             
        )
        SELECT  SCHEMA_ID(TABLE_SCHEMA), TABLE_SCHEMA, OBJECT_ID(QUOTENAME(TABLE_SCHEMA)+'.'+QUOTENAME(TABLE_NAME)), TABLE_NAME
        FROM    INFORMATION_SCHEMA.TABLES
        WHERE   TABLE_TYPE = 'BASE TABLE'
END
/* ----------------------------------- End of Seaching through @SchemaNames -------------------------------- */

IF  (@DropAllFKsPerDB <> 1) AND (SELECT COUNT(*) FROM [#SelectedObjectList]) < 1
BEGIN
    BEGIN
    SET @ErrorMsg
        = N'Could not find any objects specified in the list of schemas: [' + @SchemaNames + N'] and tables: [' + @TableNames + N'] in the database: [' + DB_NAME(DB_ID()) + N'].';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
    END
END

SET @SqlSchemaIdEngineVersion = CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20)), 1, 2) AS INT)

SELECT @SqlCte = 
N'; WITH [cte] AS (
SELECT
		   [ForeignKeyId]			 = [fk].[object_id]                                  
		 , [ForeignKeyName]			 = [fk].[name]                                       
		 , [SchemaNameSrc]			 = [SchSrc].[SchemaName]                             
		 , [TableNameSrc]			 = (SELECT (OBJECT_NAME([fkc].parent_object_id)))    
		 , [ColumnIdSrc]			 = [fkc].[parent_column_id]                          
		 , [ColumnNameSrc]			 = [ColSrc].[name]                                   
		 , [SchemaNameTrgt] 		 = [SchTgt].[SchemaName]                             
		 , [TableNameTrgt]			 = (SELECT (OBJECT_NAME([fkc].referenced_object_id)))
		 , [ColumnIdTrgt]			 = [fkc].[referenced_column_id]                      
		 , [ColumnNameTrgt]			 = [ColTgt].[name]                                   
		 , [SchemaIdTrgt]			 = [SchTgt].[SchemaId]                               
		 , [DeleteReferentialAction] = [fk].[delete_referential_action]					
		 , [UpdateReferentialAction] = [fk].[update_referential_action]					 
FROM	   ['+ DB_NAME() + '].sys.[foreign_keys]				   AS [fk] 
CROSS APPLY(
		   SELECT  
		          [fkc].[parent_column_id]
		         ,[fkc].[parent_object_id]
		         ,[fkc].[referenced_object_id]
		         ,[fkc].[referenced_column_id]
		   FROM   [' + DB_NAME() + '].sys.[foreign_key_columns]  AS [fkc] 
		   WHERE  1 = 1
		   AND    [fk].[parent_object_id] = [fkc].[parent_object_id]
		   AND    [fk].[referenced_object_id] = [fkc].[referenced_object_id]
		   AND    [fk].[object_id] = [fkc].constraint_object_id
	       )														AS [fkc] 
CROSS APPLY(
		   SELECT [ss].name											AS [SchemaName]
		   FROM   [' + DB_NAME() + '].sys.[objects]				AS [so]
		   JOIN   [' + DB_NAME() + '].sys.[schemas]				AS [ss] ON [ss].[schema_id] = [so].[schema_id]
		   WHERE  [so].[object_id] = [fkc].[parent_object_id]
           )														AS [SchSrc] 
CROSS APPLY(
		   SELECT [sc].name      
		   FROM   [' + DB_NAME() + '].sys.columns					AS [sc]
		   WHERE  [sc].[object_id] = [fk].[parent_object_id] 
		   AND    [sc].[column_id] = [fkc].[parent_column_id]
           )														AS [ColSrc] 
CROSS APPLY(
		   SELECT [ss].[schema_id]									AS [SchemaId]
		         ,[ss].[name]										AS [SchemaName]
		   FROM   [' + DB_NAME() + '].sys.objects					AS [so]
		   JOIN   [' + DB_NAME() + '].sys.schemas					AS [ss] ON [ss].[schema_id] = [so].[schema_id]
		   WHERE  [so].[object_id] = [fkc].[referenced_object_id]
           )														AS [SchTgt] 
CROSS APPLY(
		   SELECT [sc].[name]    
		   FROM   [' + DB_NAME() + '].sys.columns					AS [sc] 
		   WHERE  [sc].[object_id] = [fk].[referenced_object_id] 
		   AND    [sc].[column_id] = [fkc].[referenced_column_id]
		   )														AS [ColTgt]
JOIN	   [#SelectedObjectList]									AS [sol] 
ON         [sol].[SchemaID] = [SchTgt].[SchemaId]
AND        [sol].[ObjectID] = OBJECT_ID(QUOTENAME([SchTgt].[SchemaName]) + ''.'' + QUOTENAME(OBJECT_NAME([fkc].[referenced_object_id])))
)'

SET @SqlInsert =  'INSERT INTO [#ForeignKeyConstraintDefinitions]
(
	  [ForeignKeyId]              
	, [DropConstraintCommand]     
	, [RecreateConstraintCommand]
)'

SET @SqlSelect = CONCAT(
'SELECT 
	   [cte].[ForeignKeyId]
	  ,[DropConstraintCommand] = ''ALTER TABLE '' + QUOTENAME([cte].[SchemaNameSrc]) + ''.'' + QUOTENAME([cte].[TableNameSrc]) + 
								'' DROP CONSTRAINT '' + QUOTENAME([cte].[ForeignKeyName]) + '';''
	  ,[RecreateConstraintCommand] = 
	   CONCAT(''ALTER TABLE '', QUOTENAME([cte].[SchemaNameSrc]), ''.'', QUOTENAME([cte].[TableNameSrc]), 
			 '' WITH NOCHECK ADD CONSTRAINT '', QUOTENAME([cte].[ForeignKeyName]),
	   CASE 
	   WHEN ',  @SqlSchemaIdEngineVersion, ' < 14 
	   THEN  '' FOREIGN KEY (''+ STUFF((SELECT   '', '' + QUOTENAME([t].[ColumnNameSrc])
	                                    FROM      [cte] AS [t]
	                                    WHERE     [t].[ForeignKeyId] = [cte].[ForeignKeyId]
	                                    ORDER BY  [t].[ColumnIdTrgt]
	                                    FOR XML PATH(''''), TYPE).value(''(./text())[1]'', ''VARCHAR(MAX)''), 1, 2,'''') + '' ) '' +
	  		 '' REFERENCES ''  + QUOTENAME([cte].[SchemaNameTrgt]) + ''.'' + QUOTENAME([cte].[TableNameTrgt])+
	                    '' ('' + STUFF((SELECT   '', '' + QUOTENAME([t].[ColumnNameTrgt])
	                                    FROM      [cte] AS [t]
	                                    WHERE     [t].[ForeignKeyId] = [cte].[ForeignKeyId]
	                                    ORDER BY  [t].[ColumnIdTrgt]
	                                    FOR XML PATH(''''), TYPE).value(''(./text())[1]'', ''VARCHAR(MAX)''), 1, 2,'''') + '' )''
	   ELSE                    
	          ''FOREIGN KEY (''+ STRING_AGG(QUOTENAME([cte].[ColumnNameSrc]), '', '') WITHIN GROUP (ORDER BY [cte].[ColumnIdTrgt]) +'') ''+
	          ''REFERENCES ''  + QUOTENAME([cte].[SchemaNameTrgt])+''.''+ QUOTENAME([cte].[TableNameTrgt])+'' (''+ STRING_AGG(QUOTENAME([cte].[ColumnNameTrgt]), '', '') + '')''             
	   END,
	   CASE
	       WHEN [cte].[DeleteReferentialAction] = 1 THEN '' ON DELETE CASCADE ''
	       WHEN [cte].[DeleteReferentialAction] = 2 THEN '' ON DELETE SET NULL ''
	       WHEN [cte].[DeleteReferentialAction] = 3 THEN '' ON DELETE SET DEFAULT ''
	       ELSE ''''
	   END,
	   CASE
	       WHEN [cte].[UpdateReferentialAction] = 1 THEN '' ON UPDATE CASCADE ''
	       WHEN [cte].[UpdateReferentialAction] = 2 THEN '' ON UPDATE SET NULL ''
	       WHEN [cte].[UpdateReferentialAction] = 3 THEN '' ON UPDATE SET DEFAULT ''
	       ELSE ''''
	   END, CHAR(13),
	   ''ALTER TABLE '' + QUOTENAME([cte].[SchemaNameSrc]) + ''.'' + QUOTENAME([cte].[TableNameSrc]) + '' CHECK CONSTRAINT '' + QUOTENAME([cte].[ForeignKeyName]),
	   '';'')
 FROM [cte]
 GROUP BY     
           [cte].[ForeignKeyId]
         , [cte].[SchemaNameSrc]
         , [cte].[TableNameSrc]
         , [cte].[ForeignKeyName]
         , [cte].[SchemaNameTrgt]
         , [cte].[TableNameTrgt]
         , [cte].[DeleteReferentialAction]
         , [cte].[UpdateReferentialAction]
 ORDER BY  [cte].[TableNameSrc]')

EXEC(@SqlCte + @SqlInsert + @SqlSelect);

IF  (SELECT COUNT(*) FROM [#ForeignKeyConstraintDefinitions]) < 1
BEGIN
    BEGIN
    SET @ErrorMsg
        = N'Could not find any foreign keys referencing the tables specified in the list of schemas: [' + @SchemaNames + N'] and tables: [' + @TableNames + N'] in the database: [' + DB_NAME() + N'].';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
    END
END
ELSE
BEGIN
	BEGIN TRANSACTION
    
	PRINT('---------------------------------------------------- DROP CONSTRAINTS: --------------------------------------------------------------------')

	SELECT @LineId = MIN([LineId]), @LineIdMax = MAX([LineId]) FROM [#ForeignKeyConstraintDefinitions];
	WHILE (@LineId <= @LineIdMax) 
	BEGIN
		SELECT @SqlDropConstraint = [DropConstraintCommand]
		FROM   [#ForeignKeyConstraintDefinitions]
		WHERE  [LineId] = @LineId

		EXEC sys.sp_executesql @SqlDropConstraint;
		IF (@@ERROR = 0) PRINT (CONCAT('Successfully executed:', @SqlDropConstraint))
		ELSE 
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Error when executing: ', @SqlDropConstraint);
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			BREAK;
		END
		SELECT @LineId = @LineId + 1;
	END

	PRINT('---------------------------------------------------- TRUNCATE TABLES: --------------------------------------------------------------------')

	SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedObjectList];
	WHILE (@LineId <= @LineIdMax) 
	BEGIN
		SELECT @SqlTruncateTable = CONCAT('TRUNCATE TABLE [', [SchemaName], '].[', [TableName], '];')
		FROM   [#SelectedObjectList]
		WHERE  [Id] = @LineId

		EXEC sys.sp_executesql @SqlTruncateTable;
		IF (@@ERROR = 0) PRINT (CONCAT('Successfully executed:', @SqlTruncateTable))
		ELSE 
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Error when executing: ', @SqlTruncateTable);
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			BREAK;
		END
		SELECT @LineId = @LineId + 1;
	END

	PRINT('---------------------------------------------------- RECREATE CONSTRAINTS: --------------------------------------------------------------------')

	SELECT @LineId = MIN([LineId]), @LineIdMax = MAX([LineId]) FROM [#ForeignKeyConstraintDefinitions];
	
	/*
	Simulate error:
	UPDATE @ForeignKeyConstraintDefinitions
	SET [RecreateConstraintCommand] = CONCAT([RecreateConstraintCommand], '_BadCommand')
	WHERE  [LineId] = @LineIdMax;
	*/

	WHILE (@LineId <= @LineIdMax) 
	BEGIN
		SELECT @SqlRecreateConstraint = [RecreateConstraintCommand]
		FROM   [#ForeignKeyConstraintDefinitions]
		WHERE  [LineId] = @LineId

		EXEC sys.sp_executesql @SqlRecreateConstraint;
		IF (@@ERROR = 0) PRINT (CONCAT('Successfully executed: ', @SqlRecreateConstraint))
		ELSE 
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Error when executing: ', @SqlRecreateConstraint);
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			BREAK;
		END
		SELECT @LineId = @LineId + 1;
	END
	IF (@@ERROR = 0) COMMIT TRANSACTION    
END
END