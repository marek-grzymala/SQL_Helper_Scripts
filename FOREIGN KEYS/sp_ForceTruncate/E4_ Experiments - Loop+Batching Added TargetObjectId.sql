USE [SIRIUS1_DEV_1]
GO


SET NOCOUNT ON;

DECLARE 
	@SchemaNames NVARCHAR(MAX) = '' --'Sales;Production;HumanResources;Person;'
  , @TableNames  NVARCHAR(MAX) = '' --'SpecialOfferProduct;Product;Employee;BusinessEntity;Person;'
  , @Delimiter         CHAR(1) = ';'
  
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

  , @level0type				  VARCHAR(128)
  , @level0name				  SYSNAME
  , @level1type				  VARCHAR(128)
  , @level1name				  SYSNAME
  , @crlf					  CHAR(32) = CHAR(13)+CHAR(10)
  , @UnionAll				  VARCHAR(32)

SET @UnionAll = CONCAT(CHAR(10), 'UNION ALL', CHAR(10))
	  
DROP TABLE IF EXISTS [#SelectedObjectList]
CREATE TABLE [#SelectedObjectList]
(
    [Id]               INT     PRIMARY KEY CLUSTERED IDENTITY(1, 1)
  , [SchemaID]         INT     NOT NULL
  , [SchemaName]       SYSNAME NOT NULL
  , [ObjectID]         INT     NOT NULL
  , [TableName]        SYSNAME NOT NULL
  , [IsReferencedByFk] BIT     NULL
  , [RowCountBefore]   BIGINT  NULL
  , [RowCountAfter]    BIGINT  NULL
)

DROP TABLE IF EXISTS [#ForeignKeyConstraintDefinitions]
CREATE TABLE [#ForeignKeyConstraintDefinitions]
(
    [Id]                        INT           PRIMARY KEY CLUSTERED IDENTITY(1, 1)
  , [ForeignKeyId]              INT           UNIQUE NOT NULL
  , [ForeignKeyName]            SYSNAME       UNIQUE NOT NULL
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

BEGIN
	BEGIN TRANSACTION
	SELECT @SqlEngineVersion = CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20)), 1, 2) AS INT)

	PRINT('---------------------------------------------------- GETTING TABLE ROWCOUNTS INTO [#SelectedObjectList]: -----------------------------------------------')
	TRUNCATE TABLE [#TableRowCounts];
	SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedObjectList];
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
					FROM [#SelectedObjectList]
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
			  
		FROM  [#SelectedObjectList]
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

	UPDATE [sol]
	SET    [sol].[RowCountBefore] = [trc].[RowCount]
	FROM   [#SelectedObjectList] AS [sol]
	JOIN   [#TableRowCounts] AS [trc] ON [trc].[ObjectID] = [sol].[ObjectID]
		
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
	INNER JOIN      [#SelectedObjectList]                                          AS [sol] 
	ON              [sol].[SchemaID] = [SchTgt].[SchemaId] 
	/* if you want to search by source schema+table names (rather than target) uncomment line below and comment the next one: */
	/* AND             [sol].[ObjectID] = OBJECT_ID(QUOTENAME([SchSrc].[SchemaName]) + '.' + QUOTENAME(OBJECT_NAME([fkc].[parent_object_id]))) */
	AND             [sol].[ObjectID] = OBJECT_ID(QUOTENAME([SchTgt].[SchemaName]) + '.' + QUOTENAME(OBJECT_NAME([fkc].[referenced_object_id])))
	WHERE			[sol].[RowCountBefore] > 0 /* drop only constraints referring to non-empty target tables */
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
	    BEGIN
	    SET @ErrorMsg
	        = N'Could not find any foreign keys referencing the tables specified in the list of schemas: [' + @SchemaNames + N'] and tables: [' + @TableNames + N'] in the database: [' + DB_NAME(DB_ID()) + N'].';
	    RAISERROR(@ErrorMsg, 16, 1);
	    RETURN;
	    END
	END
	ELSE
	BEGIN

		UPDATE [sol]
		SET    [sol].[IsReferencedByFk] = 1
		FROM   [#SelectedObjectList] AS [sol]
		JOIN   [#ForeignKeyConstraintDefinitions] AS [fkc] ON [sol].[ObjectID] = [fkc].[ObjectIdTrgt]

		SELECT * FROM [#SelectedObjectList] 
		WHERE [RowCountBefore] > 0 AND [IsReferencedByFk] = 1
		ORDER BY [SchemaName], [TableName] --[RowCountBefore] DESC

		SELECT * FROM [#ForeignKeyConstraintDefinitions] ORDER BY [SchemaNameTrgt], [TableNameTrgt], [Id]
	END

    
	PRINT('---------------------------------------------------- DROPPING CONSTRAINTS: --------------------------------------------------------------------')

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
		IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentCompleted
		BEGIN
			SET @PercentCompleted = (@LineId * 100)/@LineIdMax;
			PRINT(CONCAT('% completed: ', @PercentCompleted))
		END
	END
	PRINT(CONCAT('Successfully dropped: ', @LineIdMax, ' FK Constraints'))

	/*
	PRINT('---------------------------------------------------- TRUNCATING TABLES: --------------------------------------------------------------------')

	SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedObjectList] WHERE [RowCount] > 0 /* drop only constraints referring to non-empty target tables */;
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
		SELECT @LineId = MIN([Id]) FROM [#SelectedObjectList] WHERE [RowCount] > 0
		IF (@LineId < @LineIdMax) AND (@LineId * 100)/@LineIdMax <> @PercentCompleted
		BEGIN
			SET @PercentCompleted = (@LineId * 100)/@LineIdMax;
			PRINT(CONCAT('% completed: ', @PercentCompleted))
		END
	END
	PRINT(CONCAT('Successfully truncated: ', @LineIdMax, ' Tables'))
	*/
	
	PRINT('---------------------------------------------------- RECREATING CONSTRAINTS: --------------------------------------------------------------------')

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
	PRINT(CONCAT('Successfully recreated: ', @LineIdMax, ' FK Constraints'))
	

	PRINT('---------------------------------------------------- GETTING TABLE ROWCOUNTS AFTER TRUNCATE: -----------------------------------------------')
	TRUNCATE TABLE [#TableRowCounts];
	SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedObjectList];
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
					FROM [#SelectedObjectList]
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
			  
		FROM  [#SelectedObjectList]
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

	UPDATE [sol]
	SET    [sol].[RowCountAfter] = [trc].[RowCount]
	FROM   [#SelectedObjectList] AS [sol]
	JOIN   [#TableRowCounts] AS [trc] ON [trc].[ObjectID] = [sol].[ObjectID]
	
	SELECT * FROM [#SelectedObjectList] 
	WHERE [RowCountAfter] > 0 AND [IsReferencedByFk] = 1
	ORDER BY [SchemaName], [TableName] --[RowCountBefore] DESC


	
	COMMIT TRANSACTION
END