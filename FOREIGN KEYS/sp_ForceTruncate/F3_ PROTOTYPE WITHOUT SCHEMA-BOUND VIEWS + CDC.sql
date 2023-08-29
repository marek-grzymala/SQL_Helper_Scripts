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

  SELECT COUNT(*) from Sales.SpecialOfferProduct
  SELECT COUNT(*) from Production.Product
  SELECT COUNT(*) from HumanResources.Employee
  SELECT COUNT(*) from Person.BusinessEntity


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

/*
USE	[AdventureWorks2019]
GO

USE [SIRIUS1_DEV_1]
GO
*/

USE [RegisterTakeOn1_DEV_1]
GO

SET NOCOUNT ON;

DECLARE

	@SchemaNames                         NVARCHAR(MAX) = N'' --'Sales;Production;HumanResources;Person;'
  , @TableNames                          NVARCHAR(MAX) = N'' --'SpecialOfferProduct;Product;Employee;BusinessEntity;Person;'
  , @Delimiter                           CHAR(1)       = ';'
  , @DropFKReferencingNonEmptyTablesOnly BIT           = 1 /* 1 = drop and re-create only FKs referencing non-empty [#SelectedTables], 
															  0 = drop and re-create all FKs referencing [#SelectedTables] - may impact performance! */

  /* character used to delimit and terminate the item(s) in the lists above */
  , @DropAllFKsPerDB   BIT = 1   /* Set @DropAllFKsPerDB to = 1 ONLY if you want to ignore the @SchemaNames/@TableNames 
									specified above and  drop/re-create commands for ALL FK constraints within the ENTIRE DB */

  , @ObjectId                 INT
  , @SchemaId                 INT
  , @ErrorMsg                 NVARCHAR(2047)
  , @StartSearchSch           INT
  , @DelimiterPosSch          INT
  , @SchemaName               SYSNAME
  , @TableName                SYSNAME
  , @StartSearchTbl           INT
  , @DelimiterPosTbl          INT
  , @SqlEngineVersion		  INT
  , @LineId                   INT
  , @LineIdMax                INT
  , @BatchSize				  INT = 10
  , @PercentCompleted		  INT = 0
  
  , @SqlCte                   NVARCHAR(MAX)
  , @SqlSelect                NVARCHAR(MAX)
  , @SqlInsert                NVARCHAR(MAX)
  , @SqlSchemaId              NVARCHAR(MAX)
  , @SqlDropConstraint        NVARCHAR(MAX)
  , @SqlDropView			  NVARCHAR(MAX)
  , @SqlTruncateTable         NVARCHAR(MAX)
  , @SqlRecreateConstraint    NVARCHAR(MAX)
  , @SqlRecreateView		  NVARCHAR(MAX)
  , @SqlXtndProperties		  NVARCHAR(MAX)
  , @SqlTableCounts			  NVARCHAR(MAX)
  
  , @ParamDefinition          NVARCHAR(500)
  , @ErrorMessage			  NVARCHAR(4000)
  , @ErrorSeverity			  INT
  , @ErrorState				  INT

  , @CountSelectedTables	  INT = 0
  , @CountFKFound			  INT = 0
  , @CountFKDropped			  INT = 0
  , @CountFKRecreated		  INT = 0
  , @CountSchBvFound		  INT = 0  
  , @CountSchBvDropped		  INT = 0
  , @CountSchBvRecreated	  INT = 0
  , @CountIsReferencedByFk	  INT = 0
  , @CountIsReferencedBySchBv INT = 0
  , @CountFKObjectIdTrgt		  INT = 0

  , @level0type				  VARCHAR(128)
  , @level0name				  SYSNAME
  , @level1type				  VARCHAR(128)
  , @level1name				  SYSNAME
  , @crlf					  CHAR(32)	  = CONCAT(CHAR(13), CHAR(10))
  , @UnionAll				  VARCHAR(32) = CONCAT(CHAR(10), 'UNION ALL', CHAR(10))
	  
DROP TABLE IF EXISTS [#SelectedTables]
CREATE TABLE [#SelectedTables]
(
    [Id]					INT     PRIMARY KEY CLUSTERED IDENTITY(1, 1)
  , [SchemaID]				INT     NOT NULL
  , [ObjectID]				INT     NOT NULL
  , [SchemaName]			sysname NOT NULL
  , [TableName]				sysname NOT NULL
  , [IsReferencedByFk]		BIT     NULL
  , [IsReferencedBySchBv]	BIT     NULL
  , [IsCDCEnabled]			BIT     NULL
  , [CDC_capture_instance]	SYSNAME NULL	   
  , [CDC_role_name]			SYSNAME NULL
  , [CDC_filegroup_name]	SYSNAME NULL
  , [RowCountBefore]		BIGINT  NULL
  , [RowCountAfter]			BIGINT  NULL
  , [IsTruncated]			BIT     NULL
)

DROP TABLE IF EXISTS [#ForeignKeyConstraintDefinitions]
CREATE TABLE [#ForeignKeyConstraintDefinitions]
(
    [Id]                        INT           PRIMARY KEY CLUSTERED IDENTITY(1, 1)
  , [ForeignKeyId]              INT           UNIQUE NOT NULL
  , [ForeignKeyName]            SYSNAME       NOT NULL
  , [ObjectIdTrgt]				INT			  NOT NULL
  , [SchemaNameTrgt]			SYSNAME		  NOT NULL
  , [TableNameTrgt]				SYSNAME		  NOT NULL
  , [DropConstraintCommand]     NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
  , [RecreateConstraintCommand] NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
)

DROP TABLE IF EXISTS [#TableRowCounts]
CREATE TABLE [#TableRowCounts]
(
    [Id]        INT          PRIMARY KEY CLUSTERED IDENTITY(1, 1)
  , [ObjectID]  INT          UNIQUE NOT NULL
  , [TableName] VARCHAR(256) NOT NULL
  , [RowCount]  BIGINT       NOT NULL
  /*, INDEX [#IX_TableRowCounts_GtZ]([RowCount]) WHERE [RowCount] > 0  -- does not help, select does a full scan anyway */
)

DROP TABLE IF EXISTS [#SchemaBoundViews]
CREATE TABLE [#SchemaBoundViews]
(
    [Id]                      INT           PRIMARY KEY CLUSTERED IDENTITY(1, 1)
  , [ReferencedObjectId]	  INT           NOT NULL
  , [ReferencingObjectId]     INT           UNIQUE NOT NULL
  , [ReferencingObjectSchema] NVARCHAR(128) NOT NULL
  , [ReferencingObjectName]   NVARCHAR(128) NOT NULL
  , [DropViewCommand]		  NVARCHAR(MAX) NOT NULL
  , [RecreateViewCommand]     NVARCHAR(MAX) NOT NULL
  , [@level0type]             VARCHAR(128)  NULL
  , [@level0name]             SYSNAME       NULL
  , [@level1type]             VARCHAR(128)  NULL
  , [@level1name]             SYSNAME       NULL
  , [XtdProperties]			  NVARCHAR(MAX) NULL
)


DROP TABLE IF EXISTS [#ExtendedProperties];
CREATE TABLE [#ExtendedProperties] 
(
  [objtype] VARCHAR(128)  NOT NULL
, [objname] NVARCHAR(128) NOT NULL
, [name]	NVARCHAR(128) NOT NULL
, [value]	SQL_VARIANT	  NOT NULL
)


PRINT('---------------------------------------------------- COLLECTING [#SelectedTables]: -----------------------------------------------')
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
                       INSERT INTO [#SelectedTables] ( 
                                   [SchemaID]
                                  ,[ObjectID] 
                                  ,[SchemaName]             
                                  ,[TableName]
								  ,[IsTruncated]
                       )
                       VALUES (
                                   @SchemaId
                                  ,@ObjectId
                                  ,@SchemaName
                                  ,@TableName
								  ,0
                       )
                   END
                   SET @StartSearchTbl = CHARINDEX(@Delimiter, @TableNames, @StartSearchTbl + @DelimiterPosTbl) + 1
               END
           END
        SET @StartSearchSch = CHARINDEX(@Delimiter, @SchemaNames, @StartSearchSch + @DelimiterPosSch) + 1
    END
END
ELSE
BEGIN
        INSERT INTO [#SelectedTables] ( 
                    [SchemaID]
                   ,[ObjectID] 
                   ,[SchemaName]             
                   ,[TableName]
				   ,[IsTruncated]
        )
        SELECT  SCHEMA_ID(TABLE_SCHEMA), OBJECT_ID(QUOTENAME(TABLE_SCHEMA)+'.'+QUOTENAME(TABLE_NAME)), TABLE_SCHEMA, TABLE_NAME, 0
        FROM    INFORMATION_SCHEMA.TABLES
        WHERE   TABLE_TYPE = 'BASE TABLE'
END
PRINT('---------------------------------------------------- END OF COLLECTING [#SelectedTables] -----------------------------------------------')

IF NOT EXISTS (SELECT 1 FROM [#SelectedTables])
BEGIN
    BEGIN
    SET @ErrorMsg
        = N'Could not find any objects specified in the list of schemas: [' + @SchemaNames + N'] and tables: [' + @TableNames + N'] in the database: [' + DB_NAME(DB_ID()) + N'].';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
    END
END
ELSE
BEGIN
	BEGIN TRANSACTION

	SELECT @CountSelectedTables = COUNT(1) FROM [#SelectedTables]
	PRINT(CONCAT('Populated [#SelectedTables] with: ', @CountSelectedTables, ' Records'))
	SELECT @SqlEngineVersion = CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20)), 1, 2) AS INT)

	PRINT('---------------------------------------------------- GETTING TABLE ROWCOUNTS BEFORE TRUNCATE INTO [#SelectedTables]: -----------------------------------------------')
	TRUNCATE TABLE [#TableRowCounts];
	SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedTables];
	WHILE (@LineId <= @LineIdMax) 
	BEGIN
		SELECT		
			  @SqlTableCounts = 
			  CASE WHEN @SqlEngineVersion < 14 
			  /* For SQL Versions older than 14 (2017) use FOR XML PATH instead of STRING_AGG(): */
			  THEN
					STUFF((
					SELECT @UnionAll + ' SELECT '
					    + CAST([ObjectID] AS NVARCHAR(MAX)) + ' AS [ObjectID], '
					    + '''' + CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)) + '.' + CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))
					    + ''' AS [TableName], COUNT_BIG(1) AS [RowCount] FROM '
					    + CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)) + '.' + CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))
					FROM [#SelectedTables]
					WHERE [Id] BETWEEN @LineId AND (@LineId + @BatchSize)
					FOR XML PATH(''), TYPE
					).value('.', 'NVARCHAR(MAX)'), 1, LEN(@UnionAll), '')
			  ELSE
			  /* For SQL Versions 14+ (2017+) use STRING_AGG(): */
					STRING_AGG(CONCAT('SELECT '
					, CAST([ObjectID] AS NVARCHAR(MAX)), ' AS [ObjectID], '
					, '''', CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)), '.' , CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))
					, ''' AS [TableName], COUNT_BIG(1) AS [RowCount] FROM '
					, CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)), '.' , CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))), @UnionAll)
			  END
			  
		FROM  [#SelectedTables]
		WHERE [Id] BETWEEN @LineId AND (@LineId + @BatchSize)

		SET @SqlTableCounts = CONCAT(N'INSERT INTO [#TableRowCounts] ([ObjectID], [TableName], [RowCount])', @SqlTableCounts)

		EXEC sys.sp_executesql @SqlTableCounts;
		IF (@@ERROR <> 0)
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlTableCounts);
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			BREAK;
		END
		SELECT @LineId = @LineId + 1 + @BatchSize;
		IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentCompleted
		BEGIN
			SET @PercentCompleted = (@LineId * 100)/@LineIdMax;
			PRINT(CONCAT('% completed: ', @PercentCompleted))
		END
	END

	UPDATE [st]
	SET    [st].[RowCountBefore] = [trc].[RowCount]
	FROM   [#SelectedTables] AS [st]
	JOIN   [#TableRowCounts] AS [trc] ON [trc].[ObjectID] = [st].[ObjectID]
		
	PRINT('---------------------------------------------------- POPULATING [#ForeignKeyConstraintDefinitions]: ----------------------------------------------------')

	; WITH [cte] AS (
	SELECT          
					[ForeignKeyId]				= [fk].object_id                                                                                  
	               ,[ForeignKeyName]			= [fk].name                                                                                       
	               ,[SchemaNameSrc]				= [SchSrc].[SchemaName]                                                                         
	               ,[TableNameSrc]				= (SELECT (OBJECT_NAME([fkc].parent_object_id)))                                                
	               ,[ColumnIdSrc]				= [fkc].parent_column_id                                                                        
	               ,[ColumnNameSrc]				= [ColSrc].name                                                                                 
	               ,[SchemaNameTrgt]         	= [SchTgt].[SchemaName]                                                                         
	               ,[TableNameTrgt]				= (SELECT (OBJECT_NAME([fkc].referenced_object_id)))                                            
	               ,[ColumnIdTrgt]				= [fkc].referenced_column_id                                                                    
	               ,[ColumnNameTrgt]			= [ColTgt].name                                                                                 
	               ,[SchemaIdTrgt]				= [SchTgt].[SchemaId]                                                                           
	               ,[DeleteReferentialAction]	= [fk].[delete_referential_action]															    
	               ,[UpdateReferentialAction]	= [fk].[update_referential_action]															    
	               ,[ObjectIdTrgt]				= OBJECT_ID('[' + [SchTgt].[SchemaName] + '].[' + OBJECT_NAME([fkc].referenced_object_id) + ']')
	FROM            sys.foreign_keys                                               AS [fk]
	CROSS APPLY     (
	                    SELECT  
	                            [fkc].parent_column_id,
	                            [fkc].parent_object_id,
	                            [fkc].referenced_object_id,
	                            [fkc].referenced_column_id
	                    FROM    sys.foreign_key_columns                            AS [fkc] 
	                    WHERE   1 = 1
	                    AND     fk.parent_object_id = [fkc].parent_object_id 
	                    AND     fk.referenced_object_id = [fkc].referenced_object_id
	                    AND     fk.object_id = [fkc].constraint_object_id
	                )                                                              AS [fkc]
	CROSS APPLY     (
	                    SELECT     [ss].name                                       AS [SchemaName]
	                    FROM       sys.objects                                     AS [so]
	                    INNER JOIN sys.schemas                                     AS [ss] ON [ss].schema_id = [so].schema_id
	                    WHERE      [so].object_id = [fkc].parent_object_id
	                )                                                              AS [SchSrc]
	CROSS APPLY     (
	                    SELECT [sc].name      
	                    FROM   sys.columns                                         AS [sc] 
	                    WHERE  [sc].object_id = [fk].[parent_object_id] 
	                    AND    [sc].column_id = [fkc].[parent_column_id]
	                )                                                              AS [ColSrc]
	CROSS APPLY     (
	                    SELECT     [ss].schema_id                                  AS [SchemaId]
	                              ,[ss].name                                       AS [SchemaName]
	                    FROM       sys.objects                                     AS [so]
	                    INNER JOIN sys.schemas                                     AS [ss] ON [ss].schema_id = [so].schema_id
	                    WHERE      [so].object_id = [fkc].[referenced_object_id]
	                )                                                              AS [SchTgt]
	CROSS APPLY     (
	                    SELECT [sc].name      
	                    FROM   sys.columns                                         AS [sc] 
	                    WHERE  [sc].object_id = [fk].[referenced_object_id] 
	                    AND    [sc].column_id = [fkc].[referenced_column_id]
	                )                                                              AS [ColTgt]
	INNER JOIN      [#SelectedTables]											   AS [st] 
	ON              [st].[SchemaID] = [SchTgt].[SchemaId] 
	/* if you want to search by source schema+table names (rather than target) uncomment line below and comment the next one: */
	/* AND             [st].[ObjectID] = OBJECT_ID(QUOTENAME([SchSrc].[SchemaName]) + '.' + QUOTENAME(OBJECT_NAME([fkc].[parent_object_id]))) */
	AND             [st].[ObjectID] = OBJECT_ID(QUOTENAME([SchTgt].[SchemaName]) + '.' + QUOTENAME(OBJECT_NAME([fkc].[referenced_object_id])))		
	WHERE			[st].[RowCountBefore] > CASE WHEN @DropFKReferencingNonEmptyTablesOnly = 1 THEN 0 ELSE -1 END
	)
	INSERT INTO   [#ForeignKeyConstraintDefinitions](
	              [ForeignKeyId]
				, [ForeignKeyName]
				, [ObjectIdTrgt]
				, [SchemaNameTrgt]
				, [TableNameTrgt]	
	            , [DropConstraintCommand]     
	            , [RecreateConstraintCommand])
	SELECT         
	             [cte].[ForeignKeyId],
				 [cte].[ForeignKeyName],
				 [cte].[ObjectIdTrgt],
				 [cte].[SchemaNameTrgt],
				 [cte].[TableNameTrgt],	
	             [DropConstraintCommand] = 
	                    'ALTER TABLE ' + QUOTENAME([cte].[SchemaNameSrc]) + '.' + QUOTENAME([cte].[TableNameSrc])+' DROP CONSTRAINT ' + QUOTENAME([cte].[ForeignKeyName]) + ';',        
	             
	             [RecreateConstraintCommand] = 
	             CONCAT('ALTER TABLE ' + QUOTENAME([cte].[SchemaNameSrc]) + '.'+ QUOTENAME([cte].[TableNameSrc])+' WITH NOCHECK ADD CONSTRAINT ' + QUOTENAME([cte].[ForeignKeyName]) + ' ',
	             CASE 
	             WHEN @SqlEngineVersion < 14 
	             /* For SQL Versions older than 14 (2017) use FOR XML PATH for all multi-column constraints: */
	             THEN   'FOREIGN KEY ('+ STUFF((SELECT   ', ' + QUOTENAME([t].[ColumnNameSrc])
	                                            FROM      [cte] AS [t]
	                                            WHERE     [t].[ForeignKeyId] = [cte].[ForeignKeyId]
	                                            ORDER BY  [t].[ColumnIdTrgt] --This is identical to the ORDER BY in WITHIN GROUP clause in STRING_AGG
	                                            FOR XML PATH(''),TYPE).value('(./text())[1]', 'VARCHAR(MAX)'), 1, 2,'') + ' ) ' +
	                    'REFERENCES '  + QUOTENAME([cte].[SchemaNameTrgt])+'.'+ QUOTENAME([cte].[TableNameTrgt])+
	                              ' (' + STUFF((SELECT   ', ' + QUOTENAME([t].[ColumnNameTrgt])
	                                            FROM      [cte] AS [t]
	                                            WHERE     [t].[ForeignKeyId] = [cte].[ForeignKeyId]
	                                            ORDER BY  [t].[ColumnIdTrgt] --This is identical to the ORDER BY in WITHIN GROUP clause in STRING_AGG
	                                            FOR XML PATH(''),TYPE).value('(./text())[1]', 'VARCHAR(MAX)'), 1, 2,'') + ' )'                 
	             ELSE   
	                    /* For SQL Versions 2017+ use STRING_AGG for all multi-column constraints: */                  
	                    'FOREIGN KEY ('+ STRING_AGG(QUOTENAME([cte].[ColumnNameSrc]), ', ') WITHIN GROUP (ORDER BY [cte].[ColumnIdTrgt]) +') '+
	                    'REFERENCES '  + QUOTENAME([cte].[SchemaNameTrgt])+'.'+ QUOTENAME([cte].[TableNameTrgt])+' ('+ STRING_AGG(QUOTENAME([cte].[ColumnNameTrgt]), ', ') + ')'             
	             END,   
	             CASE
	                 WHEN [cte].[DeleteReferentialAction] = 1 THEN ' ON DELETE CASCADE '
	                 WHEN [cte].[DeleteReferentialAction] = 2 THEN ' ON DELETE SET NULL '
	                 WHEN [cte].[DeleteReferentialAction] = 3 THEN ' ON DELETE SET DEFAULT '
	                 ELSE ''
	             END,
	             CASE
	                 WHEN [cte].[UpdateReferentialAction] = 1 THEN ' ON UPDATE CASCADE '
	                 WHEN [cte].[UpdateReferentialAction] = 2 THEN ' ON UPDATE SET NULL '
	                 WHEN [cte].[UpdateReferentialAction] = 3 THEN ' ON UPDATE SET DEFAULT '
	                 ELSE ''
	             END,
	             CHAR(13)+ 'ALTER TABLE ' + QUOTENAME([cte].[SchemaNameSrc])+'.'+ QUOTENAME([cte].[TableNameSrc])+' CHECK CONSTRAINT '+ QUOTENAME([cte].[ForeignKeyName])+';')
	FROM         [cte]
	GROUP BY     
	             [cte].[ForeignKeyId]
	            ,[cte].[SchemaNameSrc]
	            ,[cte].[TableNameSrc]
	            ,[cte].[ForeignKeyName]
				,[cte].[ObjectIdTrgt]
	            ,[cte].[SchemaNameTrgt]
	            ,[cte].[TableNameTrgt]
	            ,[cte].[DeleteReferentialAction]
	            ,[cte].[UpdateReferentialAction]
	ORDER BY     [cte].[TableNameSrc]
	
	IF NOT EXISTS (SELECT 1 FROM [#ForeignKeyConstraintDefinitions])
	BEGIN
	    PRINT(CONCAT(N'Could not find any foreign keys referencing the tables specified in the list of schemas: [', @SchemaNames, N'] and tables: [', @TableNames, N'] in the database: [', DB_NAME(DB_ID()), N'].'));
		
		UPDATE [st]
		SET    [st].[IsReferencedByFk] = 0
		FROM   [#SelectedTables] AS [st]
	END
	ELSE
	BEGIN
		/* ********************************************** TROUBLESHOOTING: ********************************************** */
		--SELECT * FROM [#ForeignKeyConstraintDefinitions] WHERE [ForeignKeyName] = 'FK_LoadAddress_EventClientIDFileImportID'  /* 'FK_LoadAlternateReference_EventClientIDFileImportID' 'FK_LoadAddress_EventClientIDFileImportID' */
		/* ********************************************** TROUBLESHOOTING: ********************************************** */

		SELECT @CountFKFound = COUNT(*) FROM [#ForeignKeyConstraintDefinitions]
		PRINT(CONCAT('Populated [#ForeignKeyConstraintDefinitions] with: ', @CountFKFound, ' Records'))

		UPDATE		[st]
		SET			[st].[IsReferencedByFk] = CASE WHEN [fkc].[ObjectIdTrgt] IS NOT NULL THEN 1 ELSE 0 END
		FROM		[#SelectedTables] AS [st]
		LEFT JOIN   [#ForeignKeyConstraintDefinitions] AS [fkc] ON [st].[ObjectID] = [fkc].[ObjectIdTrgt]

		SELECT @CountFKObjectIdTrgt = COUNT(DISTINCT [ObjectIdTrgt]) FROM [#ForeignKeyConstraintDefinitions]
		SELECT @CountIsReferencedByFk = COUNT(1) FROM [#SelectedTables] WHERE [IsReferencedByFk] = 1;
		IF (@CountFKObjectIdTrgt <> @CountIsReferencedByFk)
		BEGIN
			--ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Distinct Count of [#ForeignKeyConstraintDefinitions].[ObjectIdTrgt]: ', @CountFKObjectIdTrgt, ' does not match the Number of Updated [#SelectedTables].[IsReferencedByFk] flag: ', @CountIsReferencedByFk);
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
		END
		ELSE
		BEGIN
			PRINT(CONCAT('Distinct Count of [#ForeignKeyConstraintDefinitions].[ObjectIdTrgt]: ', @CountFKObjectIdTrgt, ' matches the Number of Updated [#SelectedTables].[IsReferencedByFk] flag: ', @CountIsReferencedByFk));
		END


		
		PRINT('---------------------------------------------------- POPULATING [#SchemaBoundViews]: ----------------------------------------------------')

		SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedTables] WHERE [RowCountBefore] > 0;
		WHILE (@LineId <= @LineIdMax) 
		BEGIN
			SELECT 
					@ObjectId	= [ObjectID]
				  , @SchemaName = [SchemaName]
				  , @TableName  = [TableName]
			FROM	[#SelectedTables] 
			WHERE	[Id]		= @LineId
		
			MERGE INTO [#SchemaBoundViews] AS TARGET
			USING (
			          SELECT DISTINCT
							 @ObjectId AS [ReferencedObjectId]
						   , [ob1].[object_id] AS [ReferencingObjectId]
			               , [sc1].[name] AS [ReferencingObjectSchema]
			               , [ob1].[name] AS [ReferencingObjectName]
						   , CONCAT('DROP VIEW ', QUOTENAME([sc1].[name]), '.', QUOTENAME([ob1].[name])) AS [DropViewCommand]
			               , [definition] AS [RecreateViewCommand]
			               , [@level0type]
			               , [@level0name]
			               , [@level1type]
			               , [@level1name]
			          FROM [sys].[sql_expression_dependencies] AS [sed]
			          JOIN [sys].[objects] AS [ob1]
			              ON [referencing_id] = [ob1].[object_id]
			          JOIN [sys].[schemas] AS [sc1]
			              ON [sc1].[schema_id] = [ob1].[schema_id]
			          JOIN [sys].[objects] AS [ob2]
			              ON [referenced_id] = [ob2].[object_id]
			          JOIN [sys].[schemas] AS [sc2]
			              ON [sc2].[schema_id] = [ob2].[schema_id]
			          JOIN [sys].[sql_modules] AS [sqm]
			              ON [sqm].[object_id] = [ob1].[object_id]
			          OUTER APPLY (
			                          SELECT DISTINCT
			                                 [sch].[schema_id]
			                               , [obj].[object_id]
			                               , 'SCHEMA' AS [@level0type]
			                               , [sch].[name] AS [@level0name]
			                               , [type_desc] AS [@level1type]
			                               , [obj].[name] AS [@level1name]
			                          FROM [sys].[objects] [obj]
			                          INNER JOIN [sys].[schemas] AS [sch]
			                              ON [obj].[schema_id] = [sch].[schema_id]
			                          INNER JOIN [sys].[columns] AS [col]
			                              ON [obj].[object_id] = [col].[object_id]
			                          WHERE [obj].[object_id] = [ob1].[object_id]
			                      ) AS [Xtp]
			          WHERE 1 = 1
			          AND   [ob2].[object_id] = @ObjectId
			          AND   [ob1].[type_desc] = 'VIEW'
			          AND   [is_schema_bound] = 1
			      ) AS SOURCE
			ON  SOURCE.[ReferencingObjectId]	 = TARGET.[ReferencingObjectId]
			WHEN NOT MATCHED BY TARGET THEN INSERT (
			                                           [ReferencedObjectId]
													 , [ReferencingObjectId]
			                                         , [ReferencingObjectSchema]
			                                         , [ReferencingObjectName]
			                                         , [DropViewCommand]
													 , [RecreateViewCommand]
			                                         , [@level0type]
			                                         , [@level0name]
			                                         , [@level1type]
			                                         , [@level1name]
			                                       )
			VALUES (
					SOURCE.[ReferencedObjectId]
				 ,  SOURCE.[ReferencingObjectId]
				 ,  SOURCE.[ReferencingObjectSchema]
				 ,  SOURCE.[ReferencingObjectName]
				 ,  SOURCE.[DropViewCommand]
				 ,  SOURCE.[RecreateViewCommand]
				 ,  SOURCE.[@level0type]
				 ,  SOURCE.[@level0name]
				 ,  SOURCE.[@level1type]
				 ,  SOURCE.[@level1name]);
		    
			/* SELECT @LineId = @LineId + 1; */
			SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedTables] WHERE [RowCountBefore] > 0 AND [Id] > @LineId

			IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentCompleted
			BEGIN
				SET @PercentCompleted = (@LineId * 100)/@LineIdMax;
				PRINT(CONCAT('% completed: ', @PercentCompleted))
			END        
		END
		
		PRINT('---------------------------------------------------- END OF POPULATING [#SchemaBoundViews]: ----------------------------------------------------')

		IF  (SELECT COUNT(*) FROM [#SchemaBoundViews]) < 1
		BEGIN
		    PRINT(CONCAT(N'Could not find any [#SchemaBoundViews] referencing the tables specified in the list of schemas: [', @SchemaNames, N'] and tables: [', @TableNames + N'] in the database: [', DB_NAME(DB_ID()), N'].'));
			UPDATE [st]
			SET    [st].[IsReferencedBySchBv] = 0
			FROM   [#SelectedTables] AS [st]
		END
		ELSE 
		BEGIN
			SELECT @CountSchBvFound = COUNT(*) FROM [#SchemaBoundViews]
			PRINT(CONCAT('Populated [#SchemaBoundViews] with: ', @CountSchBvFound, ' Records'))

			UPDATE	  [st]
			SET		  [st].[IsReferencedBySchBv] = CASE WHEN [sbv].[ReferencedObjectId] IS NOT NULL THEN 1 ELSE 0 END
			FROM	  [#SelectedTables] AS [st]
			LEFT JOIN [#SchemaBoundViews] AS [sbv] ON [st].[ObjectID] = [sbv].[ReferencedObjectId]

			SELECT @CountIsReferencedBySchBv = COUNT(1) FROM [#SelectedTables] WHERE [IsReferencedBySchBv] = 1;
			IF (@CountIsReferencedBySchBv <> @CountSchBvFound)
			BEGIN
				--ROLLBACK TRANSACTION
				SET @ErrorMessage = CONCAT('Number of Schema-Bound Views found: ', @CountSchBvFound, ' does not match the Number of Updated [#SelectedTables].[IsReferencedBySchBv] flag: ', @CountIsReferencedBySchBv);
				RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			END
			ELSE
			BEGIN
				PRINT(CONCAT('Number of Schema-Bound Views found: ', @CountSchBvFound, ' matches the Number of Updated [#SelectedTables].[IsReferencedBySchBv] flag: ', @CountIsReferencedBySchBv));
			END

			PRINT('---------------------------------------------------- UPDATING [XtdProperties] of [#SchemaBoundViews]: ----------------------------------------------------')

				SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SchemaBoundViews];
				WHILE (@LineId <= @LineIdMax)
				BEGIN
				    SELECT @level0type = [@level0type]
				         , @level0name = [@level0name]
				         , @level1type = [@level1type]
				         , @level1name = [@level1name]
				    FROM [#SchemaBoundViews]
				    WHERE [Id] = @LineId
				
					SELECT @SqlXtndProperties = STRING_AGG((CONCAT(
						  'EXEC [sys].[sp_addextendedproperty] @name = '''
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
						 )), @crlf)
					FROM [sys].fn_listextendedproperty(NULL, @level0type, @level0name, @level1type, @level1name, NULL, NULL)
					
					IF (@SqlXtndProperties IS NOT NULL)
					BEGIN
						UPDATE [#SchemaBoundViews]
						SET [XtdProperties] = @SqlXtndProperties
						WHERE [Id] = @LineId    
					END
				
					SET @SqlXtndProperties = NULL;
					SELECT @LineId = @LineId + 1;
					IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentCompleted
					BEGIN
						SET @PercentCompleted = (@LineId * 100)/@LineIdMax;
						PRINT(CONCAT('% completed: ', @PercentCompleted))
					END 
				END	
			PRINT('---------------------------------------------------- END of UPDATING [XtdProperties] of [#SchemaBoundViews]: ----------------------------------------------------')		
		END
	END

	IF EXISTS (SELECT 1 FROM [INFORMATION_SCHEMA].[TABLES] WHERE [TABLE_SCHEMA] = 'cdc' AND [TABLE_NAME] = 'change_tables')
	BEGIN
			PRINT('---------------------------------------------------- UPDATING [IsCDCEnabled] flag of [#SelectedTables]: ----------------------------------------------------')
			
			UPDATE [st]
			SET		
					   [st].[IsCDCEnabled]			= CASE WHEN [cdc].[source_object_id] IS NOT NULL THEN 1 ELSE 0 END
					 , [st].[CDC_capture_instance]	= [capture_instance]	   
					 , [st].[CDC_role_name]			= [role_name]
					 , [st].[CDC_filegroup_name]	= [filegroup_name]
			FROM	   [#SelectedTables]			AS [st]
			LEFT JOIN  [cdc].[change_tables]		AS [cdc] ON [st].[ObjectID] = [cdc].[source_object_id]

			PRINT('---------------------------------------------------- END OF UPDATING [IsCDCEnabled] flag of [#SelectedTables]: ----------------------------------------------------')		
	END
	ELSE 
	BEGIN
    		UPDATE  [st]
			SET	    [st].[IsCDCEnabled]	= 0
			FROM	[#SelectedTables] AS [st]
	END    

	IF (@CountFKFound > 0)
	BEGIN
		PRINT('---------------------------------------------------- DROPPING FK CONSTRAINTS: --------------------------------------------------------------------')

		SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#ForeignKeyConstraintDefinitions];
		WHILE (@LineId <= @LineIdMax) 
		BEGIN
			SELECT @SqlDropConstraint = [DropConstraintCommand]
			FROM   [#ForeignKeyConstraintDefinitions]
			WHERE  [Id] = @LineId

			EXEC sys.sp_executesql @SqlDropConstraint;
			IF (@@ERROR <> 0)
			BEGIN
				--ROLLBACK TRANSACTION
				SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlDropConstraint);
				RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
				BREAK;
			END
			ELSE 
			BEGIN
				SELECT @LineId = @LineId + 1;
				IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentCompleted
				BEGIN
					SET @PercentCompleted = (@LineId * 100)/@LineIdMax;
					PRINT(CONCAT('% completed: ', @PercentCompleted))
				END        
			END
		END
		IF (@LineIdMax > 0)	
		BEGIN
			PRINT(CONCAT('Successfully dropped: ', COALESCE(@LineIdMax, 0), ' FK Constraints'))
			SELECT @CountFKDropped = @LineIdMax;
		END    
	END

	IF (@CountSchBvFound > 0)
	BEGIN
		PRINT('---------------------------------------------------- DROPPING SCHEMA-BOUND VIEWS: ---------------------------------------------------------------')

		SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SchemaBoundViews];
		WHILE (@LineId <= @LineIdMax) 
		BEGIN
			SELECT @SqlDropView = [DropViewCommand]
			FROM   [#SchemaBoundViews]
			WHERE  [Id] = @LineId

			EXEC sys.sp_executesql @SqlDropView;
			IF (@@ERROR <> 0)
			BEGIN
				--ROLLBACK TRANSACTION
				SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlDropView);
				RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
				BREAK;
			END
			SELECT @LineId = @LineId + 1;
		END
		IF (@LineIdMax > 0)
		BEGIN
			PRINT(CONCAT('Successfully dropped: ', COALESCE(@LineIdMax, 0), ' Schema-Bound Views'))
			SELECT @CountSchBvDropped = @LineIdMax;
		END    
	END

	/*
	PRINT('---------------------------------------------------- TRUNCATING TABLES: --------------------------------------------------------------------')

	SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedTables] 
	WHERE [RowCountBefore] > 0 /* drop only constraints referring to non-empty target tables */
	AND [IsReferencedByFk] = 1
	
	WHILE (@LineId <= @LineIdMax) 
	BEGIN
		SELECT @SqlTruncateTable = CONCAT('TRUNCATE TABLE [', [SchemaName], '].[', [TableName], '];')
		FROM   [#SelectedTables]
		WHERE  [Id] = @LineId

		EXEC sys.sp_executesql @SqlTruncateTable;
		IF (@@ERROR = 0) PRINT (CONCAT('Successfully executed:', @SqlTruncateTable))
		ELSE 
		BEGIN
			SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlTruncateTable);
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			ROLLBACK TRANSACTION
			BREAK;
		END

		UPDATE [#SelectedTables] SET [IsTruncated] = 1 WHERE [Id] = @LineId
		SELECT @LineId = MIN([Id]) FROM [#SelectedTables]
		WHERE [RowCountBefore] > 0 /* drop only constraints referring to non-empty target tables */
		AND [IsReferencedByFk] = 1
		AND [IsTruncated] = 0
		IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentCompleted
		BEGIN
			SET @PercentCompleted = (@LineId * 100)/@LineIdMax;
			PRINT(CONCAT('% completed: ', @PercentCompleted))
		END        

	END
	IF (@LineIdMax > 0)	PRINT(CONCAT('Successfully truncated: ', COALESCE(@LineIdMax, 0), ' Tables'))
	*/
	
	IF (@CountSchBvFound > 0)
	BEGIN
		PRINT('---------------------------------------------------- RECREATING SCHEMA-BOUND VIEWS: -------------------------------------------------------------')

		SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SchemaBoundViews];

		WHILE (@LineId <= @LineIdMax) 
		BEGIN
			SELECT @SqlRecreateView = [RecreateViewCommand]
			FROM   [#SchemaBoundViews]
			WHERE  [Id] = @LineId

			EXEC sys.sp_executesql @SqlRecreateView;
			IF (@@ERROR <> 0)
			BEGIN
				ROLLBACK TRANSACTION
				SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlRecreateView);
				RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
				BREAK;
			END

			SELECT @SqlXtndProperties = [XtdProperties]
			FROM   [#SchemaBoundViews]
			WHERE  [Id] = @LineId

			IF (@SqlXtndProperties IS NOT NULL)
			EXEC sys.sp_executesql @SqlXtndProperties;
			IF (@@ERROR <> 0)
			BEGIN
				ROLLBACK TRANSACTION
				SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlXtndProperties);
				RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
				BREAK;
			END
			SET @SqlXtndProperties = NULL;

			SELECT @LineId = @LineId + 1;
		END
		IF (@LineIdMax > 0)	
		BEGIN
			PRINT(CONCAT('Successfully re-created: ', COALESCE(@LineIdMax, 0), ' Schema-Bound Views'))
			SELECT @CountSchBvRecreated = @LineIdMax;
		END
		IF (@CountSchBvDropped > 0)
		BEGIN
			IF (@CountSchBvDropped <> @CountSchBvRecreated)
			BEGIN
				--ROLLBACK TRANSACTION
				SET @ErrorMessage = CONCAT('Number of Schema-Bound Views re-created: ', @CountSchBvRecreated, ' does not match Number of Schema-Bound Views dropped: ', @CountSchBvDropped);
				RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
				--BREAK;
			END
			ELSE
			BEGIN
				PRINT(CONCAT('Number of Schema-Bound Views re-created: ', @CountSchBvRecreated, ' matches the Number of Schema-Bound Views dropped: ', @CountSchBvDropped));
			END
		END
	END

	IF (@CountFKFound > 0)
	BEGIN
		PRINT('---------------------------------------------------- RECREATING FK CONSTRAINTS: --------------------------------------------------------------------')

		SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#ForeignKeyConstraintDefinitions];
		WHILE (@LineId <= @LineIdMax) 
		BEGIN
			SELECT @SqlRecreateConstraint = [RecreateConstraintCommand]
			FROM   [#ForeignKeyConstraintDefinitions]
			WHERE  [Id] = @LineId

			EXEC sys.sp_executesql @SqlRecreateConstraint;
			IF (@@ERROR <> 0)
			BEGIN
				ROLLBACK TRANSACTION
				SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlRecreateConstraint);
				RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
				BREAK;
			END
			SELECT @LineId = @LineId + 1;
			IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentCompleted
			BEGIN
				SET @PercentCompleted = (@LineId * 100)/@LineIdMax;
				PRINT(CONCAT('% completed: ', @PercentCompleted))
			END
		END
		IF (@LineIdMax > 0)	
		BEGIN
			PRINT(CONCAT('Successfully re-created: ', COALESCE(@LineIdMax, 0), ' FK Constraints'))
			SELECT @CountFKRecreated = @LineIdMax;
		END
		IF (@CountFKDropped > 0)
		BEGIN
			IF (@CountFKDropped <> @CountFKRecreated)
			BEGIN
				--ROLLBACK TRANSACTION
				SET @ErrorMessage = CONCAT('Number of FK Constraints re-created : ', @CountFKRecreated, ' does not match Number of FK Constraints dropped: ', @CountFKDropped);
				RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
				--BREAK;
			END
			ELSE
			BEGIN
				PRINT(CONCAT('Number of FK Constraints re-created: ', @CountFKRecreated, ' matches the Number of FK Constraints dropped: ', @CountFKDropped));
			END
		END    
	END	

	COMMIT TRANSACTION
    
	PRINT('---------------------------------------------------- GETTING TABLE ROWCOUNTS AFTER TRUNCATE INTO [#SelectedTables]: -----------------------------------------------')
	TRUNCATE TABLE [#TableRowCounts];
	SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedTables];
	WHILE (@LineId <= @LineIdMax) 
	BEGIN
		SELECT		
			  @SqlTableCounts = 
			  CASE WHEN @SqlEngineVersion < 14 
			  /* For SQL Versions older than 14 (2017) use FOR XML PATH instead of STRING_AGG(): */
			  THEN
					STUFF((
					SELECT @UnionAll + ' SELECT '
					    + CAST([ObjectID] AS NVARCHAR(MAX)) + ' AS [ObjectID], '
					    + '''' + CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)) + '.' + CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))
					    + ''' AS [TableName], COUNT_BIG(1) AS [RowCount] FROM '
					    + CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)) + '.' + CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))
					FROM [#SelectedTables]
					WHERE [Id] BETWEEN @LineId AND (@LineId + @BatchSize) AND [RowCountBefore] > 0
					FOR XML PATH(''), TYPE
					).value('.', 'NVARCHAR(MAX)'), 1, LEN(@UnionAll), '')
			  ELSE
			  /* For SQL Versions 14+ (2017+) use STRING_AGG(): */
					STRING_AGG(CONCAT('SELECT '
					, CAST([ObjectID] AS NVARCHAR(MAX)), ' AS [ObjectID], '
					, '''', CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)), '.' , CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))
					, ''' AS [TableName], COUNT_BIG(1) AS [RowCount] FROM '
					, CAST(QUOTENAME([SchemaName]) AS NVARCHAR(MAX)), '.' , CAST(QUOTENAME([TableName]) AS NVARCHAR(MAX))), @UnionAll)
			  END
			  
		FROM  [#SelectedTables]
		WHERE [Id] BETWEEN @LineId AND (@LineId + @BatchSize)

		SET @SqlTableCounts = CONCAT(N'INSERT INTO [#TableRowCounts] ([ObjectID], [TableName], [RowCount])', @SqlTableCounts)

		EXEC sys.sp_executesql @SqlTableCounts;
		IF (@@ERROR <> 0)
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlTableCounts);
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			BREAK;
		END
		SELECT @LineId = @LineId + 1 + @BatchSize;
		IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentCompleted
		BEGIN
			SET @PercentCompleted = (@LineId * 100)/@LineIdMax;
			PRINT(CONCAT('% completed: ', @PercentCompleted))
		END
	END

	UPDATE [st]
	SET    [st].[RowCountAfter] = [trc].[RowCount]
	FROM   [#SelectedTables] AS [st]
	JOIN   [#TableRowCounts] AS [trc] ON [trc].[ObjectID] = [st].[ObjectID]

	
	SELECT * FROM [#SelectedTables] 
	WHERE --[IsReferencedBySchBv] = 1
	--[IsReferencedByFk] IS NULL OR [IsReferencedBySchBv] IS NULL
	[RowCountAfter] > 0 --AND 
	ORDER BY [RowCountAfter] DESC, [SchemaName], [TableName] --[RowCountBefore] DESC
END