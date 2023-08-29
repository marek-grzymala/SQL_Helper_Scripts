USE [AdventureWorks2019]
GO

SET NOCOUNT ON;

DECLARE 
	@SchemaNames NVARCHAR(MAX) = 'Sales;Production;HumanResources;Person;'
  , @TableNames  NVARCHAR(MAX) = 'SpecialOfferProduct;Product;Employee;BusinessEntity;Person;'
  , @Delimiter         CHAR(1) = ';'
  
  /* character used to delimit and terminate the item(s) in the lists above */
  , @DropAllFKsPerDB   BIT = 0   /* Set @DropAllFKsPerDB to = 1 ONLY if you want to ignore the @SchemaNames/@TableNames 
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

      , @level0type				  VARCHAR(128)
      , @level0name				  SYSNAME
      , @level1type				  VARCHAR(128)
      , @level1name				  SYSNAME
	  , @crlf					  CHAR(32) = CHAR(13)+CHAR(10)
	  , @linesep				  VARCHAR(32)

SET @linesep = CONCAT(CHAR(10), 'UNION ALL', CHAR(10))
	  
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
	 [Id]						 INT PRIMARY KEY CLUSTERED IDENTITY(1,1)
    ,[ForeignKeyId]              INT UNIQUE NOT NULL
	,[DropConstraintCommand]     NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[RecreateConstraintCommand] NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
)

DROP TABLE IF EXISTS [#SchemaBoundViews]
CREATE TABLE [#SchemaBoundViews]
(
    [Id]                      INT           PRIMARY KEY CLUSTERED IDENTITY(1, 1)
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

/* --------------------------------------------------------- Search through @SchemaNames: --------------------------------------------------------------------- */
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
/* --------------------------------------------------------- Search through @TableNames: ---------------------------------------------------------------------- */
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
/* --------------------------------------------------------- End of Search through @TableNames: --------------------------------------------------------------- */
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
/* --------------------------------------------------------- End of Seaching through @SchemaNames ------------------------------------------------------------- */
IF  (@DropAllFKsPerDB <> 1) AND (SELECT COUNT(*) FROM [#SelectedObjectList]) < 1
BEGIN
    BEGIN
    SET @ErrorMsg
        = N'Could not find any objects specified in the list of schemas: [' + @SchemaNames + N'] and tables: [' + @TableNames + N'] in the database: [' + DB_NAME(DB_ID()) + N'].';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
    END
END

/* --------------------------------------------------------- Insert into [#ForeignKeyConstraintDefinitions]: -------------------------------------------------- */
SELECT @SqlEngineVersion = CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20)), 1, 2) AS INT)
; WITH [cte] AS (
SELECT          
				[ForeignKeyId]				= fk.object_id                                                                                  
               ,[ForeignKeyName]			= fk.name                                                                                       
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
INNER JOIN      [#SelectedObjectList]                                          AS [sol] 
ON              [sol].[SchemaID] = [SchTgt].[SchemaId] 
/* if you want to search by source schema+table names (rather than target) uncomment line below and comment the next one: */
/* AND             [sol].[ObjectID] = OBJECT_ID(QUOTENAME([SchSrc].[SchemaName]) + '.' + QUOTENAME(OBJECT_NAME([fkc].[parent_object_id]))) */
AND             [sol].[ObjectID] = OBJECT_ID(QUOTENAME([SchTgt].[SchemaName]) + '.' + QUOTENAME(OBJECT_NAME([fkc].[referenced_object_id])))
)
INSERT INTO  [#ForeignKeyConstraintDefinitions](
             [ForeignKeyId]              
            ,[DropConstraintCommand]     
            ,[RecreateConstraintCommand]
)
SELECT         
             [cte].[ForeignKeyId],
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
            ,[cte].[SchemaNameTrgt]
            ,[cte].[TableNameTrgt]
            ,[cte].[DeleteReferentialAction]
            ,[cte].[UpdateReferentialAction]
ORDER BY     [cte].[TableNameSrc]

IF  (SELECT COUNT(*) FROM [#ForeignKeyConstraintDefinitions]) < 1
BEGIN
    BEGIN
    SET @ErrorMsg
        = N'Could not find any foreign keys referencing the tables specified in the list of schemas: [' + @SchemaNames + N'] and tables: [' + @TableNames + N'] in the database: [' + DB_NAME(DB_ID()) + N'].';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
    END
END
ELSE
BEGIN
	SELECT * FROM [#ForeignKeyConstraintDefinitions]
END
/* --------------------------------------------------------- End of Insert into [#ForeignKeyConstraintDefinitions]: ------------------------------------------  */

/* --------------------------------------------------------- Merge into [#SchemaBoundViews]: -----------------------------------------------------------------  */
SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedObjectList];
WHILE (@LineId <= @LineIdMax) 
BEGIN
	SELECT 
			@ObjectId	= [ObjectID]
		  , @SchemaName = [SchemaName]
		  , @TableName  = [TableName]
	FROM	[#SelectedObjectList] 
	WHERE	[Id]		= @LineId

MERGE INTO [#SchemaBoundViews] AS TARGET
USING (
          SELECT DISTINCT
                 [ob1].[object_id] AS [ReferencingObjectId]
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
                                           [ReferencingObjectId]
                                         , [ReferencingObjectSchema]
                                         , [ReferencingObjectName]
                                         , [DropViewCommand]
										 , [RecreateViewCommand]
                                         , [@level0type]
                                         , [@level0name]
                                         , [@level1type]
                                         , [@level1name]
                                       )
VALUES (SOURCE.[ReferencingObjectId]
	 ,  SOURCE.[ReferencingObjectSchema]
	 ,  SOURCE.[ReferencingObjectName]
	 ,  SOURCE.[DropViewCommand]
	 ,  SOURCE.[RecreateViewCommand]
	 ,  SOURCE.[@level0type]
	 ,  SOURCE.[@level0name]
	 ,  SOURCE.[@level1type]
	 ,  SOURCE.[@level1name]);
    
	SELECT @LineId = @LineId + 1;
END

/* --------------------------------------------------------- End of Merge into [#SchemaBoundViews]: ----------------------------------------------------------  */
IF  (SELECT COUNT(*) FROM [#SchemaBoundViews]) < 1
BEGIN
    BEGIN
    SET @ErrorMsg
        = N'Could not find any [#SchemaBoundViews] referencing the tables specified in the list of schemas: [' + @SchemaNames + N'] and tables: [' + @TableNames + N'] in the database: [' + DB_NAME(DB_ID()) + N'].';
    PRINT(@ErrorMsg);
    RETURN;
    END
END
ELSE 
BEGIN
/* --------------------------------------------------------- Update [XtdProperties] of [#SchemaBoundViews]: --------------------------------------------------  */
	SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id])FROM [#SchemaBoundViews];
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
	END
SELECT * FROM [#SchemaBoundViews]
/* --------------------------------------------------------- End of Update [XtdProperties] of [#SchemaBoundViews]: -------------------------------------------  */
END

BEGIN

	BEGIN TRANSACTION
	
	SELECT @SqlTableCounts = STRING_AGG(CONCAT('SELECT ''', QUOTENAME([SchemaName]), '.', QUOTENAME([TableName]), ''' AS [TableName], COUNT_BIG(*) AS [Rc] FROM ', QUOTENAME([SchemaName]), '.', QUOTENAME([TableName])), @linesep)
	FROM   [#SelectedObjectList]

	EXEC sys.sp_executesql @SqlTableCounts;
	IF (@@ERROR <> 0)
	BEGIN
		ROLLBACK TRANSACTION
		SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlTableCounts);
		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
		--BREAK;
	END
    
	PRINT('---------------------------------------------------- DROP CONSTRAINTS: --------------------------------------------------------------------')

	SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#ForeignKeyConstraintDefinitions];
	WHILE (@LineId <= @LineIdMax) 
	BEGIN
		SELECT @SqlDropConstraint = [DropConstraintCommand]
		FROM   [#ForeignKeyConstraintDefinitions]
		WHERE  [Id] = @LineId

		EXEC sys.sp_executesql @SqlDropConstraint;
		IF (@@ERROR <> 0)
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlDropConstraint);
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			BREAK;
		END
		SELECT @LineId = @LineId + 1;
	END
	PRINT(CONCAT('Successfully dropped: ', @LineIdMax, ' FK Constraints'))

	PRINT('---------------------------------------------------- DROP SCHMA-BOUND VIEWS: ---------------------------------------------------------------')

	SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SchemaBoundViews];
	WHILE (@LineId <= @LineIdMax) 
	BEGIN
		SELECT @SqlDropView = [DropViewCommand]
		FROM   [#SchemaBoundViews]
		WHERE  [Id] = @LineId

		EXEC sys.sp_executesql @SqlDropView;
		IF (@@ERROR <> 0)
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlDropView);
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			BREAK;
		END
		SELECT @LineId = @LineId + 1;
	END
	PRINT(CONCAT('Successfully dropped: ', @LineIdMax, ' Schema-Bound Views'))

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
			SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlTruncateTable);
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			BREAK;
		END
		SELECT @LineId = @LineId + 1;
	END
	PRINT(CONCAT('Successfully truncated: ', @LineIdMax, ' Tables'))

	PRINT('---------------------------------------------------- RECREATE CONSTRAINTS: --------------------------------------------------------------------')

	SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#ForeignKeyConstraintDefinitions];
	
	/*
	Simulate error:
	UPDATE [#ForeignKeyConstraintDefinitions]
	SET [RecreateConstraintCommand] = CONCAT([RecreateConstraintCommand], '_BadCommand')
	WHERE  [LineId] = @LineIdMax;
	*/

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
	END
	PRINT(CONCAT('Successfully re-created: ', @LineIdMax, ' FK Constraints'))
	
	PRINT('---------------------------------------------------- RECREATE SCHEMA-BOUND VIEWS: -------------------------------------------------------------')

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
	PRINT(CONCAT('Successfully re-created: ', @LineIdMax, ' Schema-Bound Views'))

	EXEC sys.sp_executesql @SqlTableCounts;
	IF (@@ERROR <> 0)
	BEGIN
		ROLLBACK TRANSACTION
		SET @ErrorMessage = CONCAT('Rolling back transaction - Error while executing: ', @SqlTableCounts);
		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
		--BREAK;
	END
	COMMIT TRANSACTION
END
