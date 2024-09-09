
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
SET NOCOUNT ON
GO

DECLARE 
		@ListOfSchemaNames         NVARCHAR(4000)
      , @ListOfTableNames          NVARCHAR(4000)
      , @Delimiter                 CHAR(1)
      , @RunTruncate               BIT
      , @DropAllFKsPerDB           BIT
      , @ObjectId                  INT
      , @SchemaId                  INT
      , @ErrorMsg                  NVARCHAR(2047)
      , @StartSearchSch            INT
      , @DelimiterPosSch           INT
      , @SchemaName                sysname
      , @TableName                 sysname
      , @StartSearchTbl            INT
      , @DelimiterPosTbl           INT
      , @SqlEngineVersion          INT
	  , @LineId					   INT
	  , @LineIdMax				   INT
      , @DropConstraintCommand     NVARCHAR(MAX)
	  , @TruncateTableCommand	   NVARCHAR(MAX)
      , @RecreateConstraintCommand NVARCHAR(MAX)
	  , @ErrorMessage			   NVARCHAR(4000)
	  , @ErrorSeverity			   INT
	  , @ErrorState				   INT

/* Set the list of Schemas and Tables you want to truncate; use a list of schemas and tables separated and terminated by the @Delimiter charachter */
/* Below a sample list of tables and schemas from AdventureWorks2019 - fill in your values as you please */

SET @ListOfSchemaNames = 'dbo;'
SET @ListOfTableNames  = 'TableName;'
SET @Delimiter = ';' /* character used to delimit and terminate the items in the lists above */
SET @DropAllFKsPerDB = 0 /* Set @DropAllFKsPerDB to = 1 ONLY if you want to ignore the @ListOfSchemaNames/@ListOfTableNames above 
                            and generate drop/re-create commands for ALL FK constraints within the ENTIRE DB */
SET @RunTruncate = 0
SET @ErrorSeverity = 16;
SET @ErrorState = 1;

DECLARE @SelectedObjectList TABLE
(
    [Id]         INT     PRIMARY KEY CLUSTERED IDENTITY(1, 1)
  , [SchemaID]   INT     NOT NULL
  , [SchemaName] SYSNAME NOT NULL
  , [ObjectID]   INT     NOT NULL
  , [TableName]  SYSNAME NOT NULL
)

DECLARE @ForeignKeyConstraintDefinitions TABLE
(
	 [LineId]                      INT PRIMARY KEY CLUSTERED IDENTITY(1,1)
    ,[ForeignKeyId]                INT UNIQUE NOT NULL
	,[DropConstraintCommand]       NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[RecreateConstraintCommand]   NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)

DECLARE @SchemBoundViews TABLE
(
    [object_id]              INT			NOT NULL PRIMARY KEY CLUSTERED
  , [ViewName]			     SYSNAME		NOT NULL
  , [ViewDefinition]         NVARCHAR(MAX)  NOT NULL
  , [uses_ansi_nulls]        BIT			NOT NULL
  , [uses_quoted_identifier] BIT			NOT NULL
  , [is_schema_bound]        BIT			NOT NULL
  , [XtdPropName]            NVARCHAR(128)  NULL
  , [XtdPropValue]           SQL_VARIANT	NULL
)


IF (@DropAllFKsPerDB <> 1) AND ((RIGHT(@ListOfSchemaNames, 1) <> @Delimiter) OR (RIGHT(@ListOfTableNames, 1) <> @Delimiter))
BEGIN
SET @ErrorMsg
    = N'Strings: @ListOfSchemaNames and @ListOfTableNames have to end with the delimiter scpecified in @Delimiter variable: [' + @Delimiter + ']';
RAISERROR(@ErrorMsg, 16, 1);
RETURN;
END

/* ----------------------------------- Search through @ListOfSchemaNames: ----------------------------------- */
SET @StartSearchSch = 0
SET @DelimiterPosSch = 0
IF (@DropAllFKsPerDB <> 1)
BEGIN
    WHILE CHARINDEX(@Delimiter, @ListOfSchemaNames, @StartSearchSch + 1) > 0
    BEGIN
        SET @DelimiterPosSch = CHARINDEX(@Delimiter, @ListOfSchemaNames, @StartSearchSch + 1) - @StartSearchSch
        SET @SchemaName = SUBSTRING(@ListOfSchemaNames, @StartSearchSch, @DelimiterPosSch)
        SET @SchemaId = NULL;
        SELECT @SchemaId = schema_id FROM sys.schemas WHERE name = @SchemaName        
        IF (@SchemaId IS NOT NULL)
           /* ----------------------------------- Search through @ListOfTableNames: ----------------------------------- */
           BEGIN
               SET @StartSearchTbl = 0
               SET @DelimiterPosTbl = 0
               
               WHILE CHARINDEX(@Delimiter, @ListOfTableNames, @StartSearchTbl + 1) > 0
               BEGIN
                   SET @DelimiterPosTbl = CHARINDEX(@Delimiter, @ListOfTableNames, @StartSearchTbl + 1) - @StartSearchTbl
                   SET @TableName = SUBSTRING(@ListOfTableNames, @StartSearchTbl, @DelimiterPosTbl)
                   
                   SET @ObjectId = NULL;
                   SET @ObjectId = OBJECT_ID('[' + @SchemaName + '].[' + @TableName + ']');
 
				   IF (@ObjectId IS NOT NULL)
                   BEGIN
                       INSERT INTO @SelectedObjectList ( 
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
                   SET @StartSearchTbl = CHARINDEX(@Delimiter, @ListOfTableNames, @StartSearchTbl + @DelimiterPosTbl) + 1
               END
           END
           /* ----------------------------------- End of Seaching through @ListOfTableNames -------------------------------- */
        SET @StartSearchSch = CHARINDEX(@Delimiter, @ListOfSchemaNames, @StartSearchSch + @DelimiterPosSch) + 1
    END
END
ELSE
BEGIN
        INSERT INTO @SelectedObjectList ( 
                    [SchemaID]
                   ,[SchemaName]             
                   ,[ObjectID] 
                   ,[TableName]             
        )
        SELECT  SCHEMA_ID(TABLE_SCHEMA), TABLE_SCHEMA, OBJECT_ID(QUOTENAME(TABLE_SCHEMA)+'.'+QUOTENAME(TABLE_NAME)), TABLE_NAME
        FROM    INFORMATION_SCHEMA.TABLES
        WHERE   TABLE_TYPE = 'BASE TABLE'
END
/* ----------------------------------- End of Seaching through @ListOfSchemaNames -------------------------------- */

IF  (@DropAllFKsPerDB <> 1) AND (SELECT COUNT(*) FROM @SelectedObjectList) < 1
BEGIN
    BEGIN
    SET @ErrorMsg
        = N'Could not find any objects specified in the list of schemas: [' + @ListOfSchemaNames + N'] and tables: [' + @ListOfTableNames + N'] in the database: [' + DB_NAME(DB_ID()) + N'].';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
    END
END

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
INNER JOIN      @SelectedObjectList                                            AS [sol] 
ON              [sol].[SchemaID] = [SchTgt].[SchemaId] 
/* if you want to search by source schema+table names (rather than target) uncomment line below and comment the next one */
--AND             [sol].[ObjectID] = OBJECT_ID(QUOTENAME([SchTgt].[SchemaName]) + '.' + QUOTENAME(OBJECT_NAME([fkc].[parent_object_id])))
AND             [sol].[ObjectID] = OBJECT_ID(QUOTENAME([SchTgt].[SchemaName]) + '.' + QUOTENAME(OBJECT_NAME([fkc].[referenced_object_id])))
     
/* ORDER BY        fk.object_id, Schema_Name_Trgt, Table_Name_Trgt */
)
INSERT INTO  @ForeignKeyConstraintDefinitions(
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

IF  (SELECT COUNT(*) FROM @ForeignKeyConstraintDefinitions) < 1
BEGIN
    BEGIN
    SET @ErrorMsg
        = N'Could not find any foreign keys referencing the tables specified in the list of schemas: [' + @ListOfSchemaNames + N'] and tables: [' + @ListOfTableNames + N'] in the database: [' + DB_NAME(DB_ID()) + N'].';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
    END
END
ELSE
BEGIN
	SELECT * FROM @ForeignKeyConstraintDefinitions

	BEGIN TRANSACTION
    
	PRINT('---------------------------------------------------- DROP CONSTRAINTS: --------------------------------------------------------------------')

	SELECT @LineId = MIN([LineId]), @LineIdMax = MAX([LineId]) FROM @ForeignKeyConstraintDefinitions;
	WHILE (@LineId <= @LineIdMax) 
	BEGIN
		SELECT @DropConstraintCommand = [DropConstraintCommand]
		FROM   @ForeignKeyConstraintDefinitions
		WHERE  [LineId] = @LineId

		EXEC sys.sp_executesql @DropConstraintCommand;
		IF (@@ERROR = 0) PRINT (CONCAT('Successfully executed:', @DropConstraintCommand))
		ELSE 
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Error when executing: ', @DropConstraintCommand);
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			BREAK;
		END
		SELECT @LineId = @LineId + 1;
	END

	PRINT('---------------------------------------------------- TRUNCATE TABLES: --------------------------------------------------------------------')
    IF (@RunTruncate = 1) 
    BEGIN
	    SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM @SelectedObjectList;
	    WHILE (@LineId <= @LineIdMax) 
	    BEGIN
		    SELECT @TruncateTableCommand = CONCAT('TRUNCATE TABLE [', [SchemaName], '].[', [TableName], '];')
		    FROM   @SelectedObjectList
		    WHERE  [Id] = @LineId

		    EXEC sys.sp_executesql @TruncateTableCommand;
		    IF (@@ERROR = 0) PRINT (CONCAT('Successfully executed:', @TruncateTableCommand))
		    ELSE 
		    BEGIN
			    ROLLBACK TRANSACTION
			    SET @ErrorMessage = CONCAT('Rolling back transaction - Error when executing: ', @TruncateTableCommand);
			    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			    BREAK;
		    END
		    SELECT @LineId = @LineId + 1;
	    END    
    END


	PRINT('---------------------------------------------------- RECREATE CONSTRAINTS: --------------------------------------------------------------------')

	SELECT @LineId = MIN([LineId]), @LineIdMax = MAX([LineId]) FROM @ForeignKeyConstraintDefinitions;
	
	/*
	Simulate error:
	UPDATE @ForeignKeyConstraintDefinitions
	SET [RecreateConstraintCommand] = CONCAT([RecreateConstraintCommand], '_BadCommand')
	WHERE  [LineId] = @LineIdMax;
	*/

	WHILE (@LineId <= @LineIdMax) 
	BEGIN
		SELECT @RecreateConstraintCommand = [RecreateConstraintCommand]
		FROM   @ForeignKeyConstraintDefinitions
		WHERE  [LineId] = @LineId

		EXEC sys.sp_executesql @RecreateConstraintCommand;
		IF (@@ERROR = 0) PRINT (CONCAT('Successfully executed: ', @RecreateConstraintCommand))
		ELSE 
		BEGIN
			ROLLBACK TRANSACTION
			SET @ErrorMessage = CONCAT('Rolling back transaction - Error when executing: ', @RecreateConstraintCommand);
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			BREAK;
		END
		SELECT @LineId = @LineId + 1;
	END
	IF (@@ERROR = 0) COMMIT TRANSACTION    
END


--SELECT 
--            [LineId]
--		   ,[ForeignKeyId]              
--           ,[DropConstraintCommand]     
--           ,[RecreateConstraintCommand] 
--FROM        @ForeignKeyConstraintDefinitions 
--ORDER BY    [LineId]

--SELECT 
--[Id], [SchemaID], [SchemaName], [ObjectID], [TableName] 
--FROM @SelectedObjectList
