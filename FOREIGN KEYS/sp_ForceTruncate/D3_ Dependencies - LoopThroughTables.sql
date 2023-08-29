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
      , @SqlTruncateTable         NVARCHAR(MAX)
      , @SqlRecreateConstraint    NVARCHAR(MAX)
      
	  , @ParamDefinition          NVARCHAR(500)
	  , @ErrorMessage			  NVARCHAR(4000)
	  , @ErrorSeverity			  INT
	  , @ErrorState				  INT

	  , @SqlRecreateView		  NVARCHAR(MAX)
      , @level0type				  VARCHAR(128)
      , @level0name				  SYSNAME
      , @level1type				  VARCHAR(128)
      , @level1name				  SYSNAME
	  , @crlf					  CHAR(2) = CHAR(13)+CHAR(10)
	  
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

DROP TABLE IF EXISTS [#ExtendedProperties];
CREATE TABLE [#ExtendedProperties] 
(
  [objtype] VARCHAR(128)  NOT NULL
, [objname] NVARCHAR(128) NOT NULL
, [name]	NVARCHAR(128) NOT NULL
, [value]	SQL_VARIANT	  NOT NULL
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

SET @SqlEngineVersion = CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20)), 1, 2) AS INT)

SELECT @LineId = MIN([Id]), @LineIdMax = MAX([Id]) FROM [#SelectedObjectList];
WHILE (@LineId <= @LineIdMax) 
BEGIN
	SELECT 
			@ObjectId = [ObjectID]
		  , @SchemaName = [SchemaName]
		  , @TableName  = [TableName]
	FROM	[#SelectedObjectList] 
	WHERE	[Id] = @LineId
	PRINT(CONCAT('Processing LineId: ', @LineId, ' of: ', @LineIdMax, ' for ObjectId: ', @ObjectId, ': ', @SchemaName, '.', @TableName))

	/* -------------------------------------------------------------------------------------------------------------------------- */
	SELECT		DISTINCT
				[ob1].[object_id]	AS [ReferencingObjectId]
			  , [sc1].[name]		AS [ReferencingObjectSchema]
			  , [ob1].[name]		AS [ReferencingObjectName]
			  , [ob2].[object_id]	AS [ReferencedObjectId]
			  , [sc2].[name]		AS [ReferencedObjectSchema]
			  , [ob2].[name]		AS [ReferencedObjectName]
			  , [dbo].[ufnTrimNonAlphaNum]([sqm].[definition]) AS [ViewDefinition]
	FROM	  sys.sql_expression_dependencies AS [sed]
	JOIN	  sys.objects			AS [ob1] ON [sed].[referencing_id]	= [ob1].[object_id]
	JOIN	  sys.schemas			AS [sc1] ON [sc1].[schema_id]		= [ob1].[schema_id]
	JOIN	  sys.objects			AS [ob2] ON [sed].[referenced_id]	= [ob2].[object_id]
	JOIN	  sys.schemas			AS [sc2] ON [sc2].[schema_id]		= [ob2].[schema_id]
	JOIN      sys.sql_modules		AS [sqm] ON [sqm].[object_id]		= [ob1].[object_id]
	WHERE 1 = 1
	AND [ob2].[object_id] = @ObjectId
	AND [ob1].[type_desc] = 'VIEW'
	AND [sqm].[is_schema_bound] = 1
	/* -------------------------------------------------------------------------------------------------------------------------- */

	IF (@@ERROR = 0) PRINT (CONCAT('', @SqlTruncateTable))
	ELSE 
	BEGIN
		ROLLBACK TRANSACTION
		SET @ErrorMessage = CONCAT('Rolling back transaction - Error when executing: ', @SqlTruncateTable);
		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
		BREAK;
	END

	SET @SqlRecreateView = NULL;
	SET @level0type	     = NULL;
	SET @level0name	     = NULL;
	SET @level1type	     = NULL;
	SET @level1name	     = NULL;

	SELECT @LineId = @LineId + 1;
END
