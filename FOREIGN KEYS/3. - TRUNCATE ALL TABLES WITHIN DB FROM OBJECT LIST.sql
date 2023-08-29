--USE [YourDbName]
--GO

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
SET NOCOUNT ON
GO
DECLARE 
      @ListOfSchemaNames NVARCHAR(4000)
    , @ListOfTableNames NVARCHAR(4000)
    , @TruncateAllTablesPerDB BIT
	, @delim CHAR(1)

    , @ObjectID INT
    , @ErrorMsg NVARCHAR(2047)
    
    , @schema_id NVARCHAR(4000)
    , @object_id NVARCHAR(4000)    
	
    , @start_search_sch INT
	, @delim_pos_sch INT
	, @schema_name SYSNAME

    , @start_search_tbl INT
	, @delim_pos_tbl INT
	, @name_tbl SYSNAME

    , @Command  NVARCHAR(MAX)
    , @Execute  BIT
    , @RowCount INT
    , @LineId   INT = 1   

/* Set the list of schemas and Tables you want to truncate; use a list of schemas and tables separated and terminated by the @delim charachter */
/* Below a sample list of tables and schemas from AdventureWorks2019 - fill in your values as you please */

SET @ListOfSchemaNames = 'Production;HumanResources;Person;'
SET @ListOfTableNames  = 'Product;Employee;BusinessEntity;'
SET @delim = ';' /* character used to delimit and terminate the items in the lists above */
SET @TruncateAllTablesPerDB = 0 /* Set @TruncateAllTablesPerDB to = 1 ONLY if you want to ignore the @ListOfSchemaNames/@ListOfTableNames above 
                                   and generate TRUNCATE commands for all tables within the entire DB */
/* CAUTION!!!! SETTING @Execute = 1 WILL EXECUTE ALL @Drop OR @Recreate COMMANDS: */
SET @Execute = 0 /* 0 = Print out the @Command only */


DROP TABLE IF EXISTS [#SelectedObjectList];CREATE TABLE [#SelectedObjectList](	 [Id]                 INT PRIMARY KEY CLUSTERED IDENTITY(1,1)
	,[SchemaID]           INT NOT NULL
	,[SchemaName]         SYSNAME NOT NULL
	,[ObjectID]           INT NOT NULL
	,[TableName]          SYSNAME NOT NULL
)

IF (@TruncateAllTablesPerDB <> 1) AND ((RIGHT(@ListOfSchemaNames, 1) <> @delim) OR (RIGHT(@ListOfTableNames, 1) <> @delim))
BEGIN
SET @ErrorMsg
    = N'Strings: @ListOfSchemaNames and @ListOfTableNames have to end with the delimiter scpecified in @delim variable: [' + @delim + ']';
RAISERROR(@ErrorMsg, 16, 1);
RETURN;
END

/* ----------------------------------- Search through @ListOfSchemaNames: ----------------------------------- */
SET @start_search_sch = 0
SET @delim_pos_sch = 0
IF (@TruncateAllTablesPerDB <> 1)
BEGIN
    IF CHARINDEX(@ListOfTableNames, '_ForeignKeyConstraintDefinitions', 0) > 0
    BEGIN /* Remove the table _ForeignKeyConstraintDefinitions from the list just in case it got there (we do not want to truncate it: */
        SET @ListOfTableNames = REPLACE(@ListOfTableNames, '_ForeignKeyConstraintDefinitions', '')
    END
    WHILE CHARINDEX(@delim, @ListOfSchemaNames, @start_search_sch + 1) > 0
    BEGIN
        SET @delim_pos_sch = CHARINDEX(@delim, @ListOfSchemaNames, @start_search_sch + 1) - @start_search_sch
        SET @schema_name = SUBSTRING(@ListOfSchemaNames, @start_search_sch, @delim_pos_sch)
        SET @schema_id = NULL;
        SELECT @schema_id = [schema_id] FROM sys.schemas WHERE [name] = @schema_name        
        IF (@schema_id IS NOT NULL)
           /* ----------------------------------- Search through @ListOfTableNames: ----------------------------------- */
           BEGIN
               SET @start_search_tbl = 0
               SET @delim_pos_tbl = 0
               
               WHILE CHARINDEX(@delim, @ListOfTableNames, @start_search_tbl + 1) > 0
               BEGIN
                   SET @delim_pos_tbl = CHARINDEX(@delim, @ListOfTableNames, @start_search_tbl + 1) - @start_search_tbl
                   SET @name_tbl = SUBSTRING(@ListOfTableNames, @start_search_tbl, @delim_pos_tbl)
                   SET @object_id = NULL;
                   SELECT @object_id = object_id FROM sys.objects WHERE schema_id = @schema_id AND [name] = @name_tbl
                   
                   SET @ObjectID = NULL;
                   SET @ObjectID = OBJECT_ID('[' + @schema_name + '].[' + @name_tbl + ']');
                   IF  (@object_id IS NOT NULL) AND (@ObjectID IS NOT NULL)
                   BEGIN
                       INSERT INTO [#SelectedObjectList] ( 
                                   [SchemaID]
                                  ,[SchemaName]             
                                  ,[ObjectID] 
                                  ,[TableName]             
                       )
                       VALUES (
                                   @schema_id
                                  ,QUOTENAME(@schema_name)
                                  ,@object_id
                                  ,QUOTENAME(@name_tbl)
                       )
                   END
                   SET @start_search_tbl = CHARINDEX(@delim, @ListOfTableNames, @start_search_tbl + @delim_pos_tbl) + 1
               END
           END
           /* ----------------------------------- End of Seaching through @ListOfTableNames -------------------------------- */
        SET @start_search_sch = CHARINDEX(@delim, @ListOfSchemaNames, @start_search_sch + @delim_pos_sch) + 1
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
        SELECT  SCHEMA_ID(TABLE_SCHEMA), QUOTENAME(TABLE_SCHEMA), OBJECT_ID(QUOTENAME(TABLE_SCHEMA)+'.'+QUOTENAME(TABLE_NAME)), QUOTENAME(TABLE_NAME)
        FROM    INFORMATION_SCHEMA.TABLES
        WHERE   TABLE_TYPE = 'BASE TABLE'
        AND     TABLE_NAME <> '_ForeignKeyConstraintDefinitions';
END
/* ----------------------------------- End of Seaching through @ListOfSchemaNames -------------------------------- */

IF  (@TruncateAllTablesPerDB <> 1) AND (SELECT COUNT(*) FROM [#SelectedObjectList]) < 1
BEGIN
    BEGIN
    SET @ErrorMsg
        = N'Could not find any objects specified in the list of schemas: [' + @ListOfSchemaNames + N'] and tables: [' + @ListOfTableNames + N'] in the database: [' + DB_NAME(DB_ID()) + N'].';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
    END
END

SET XACT_ABORT ON
IF (@Execute = 0)
BEGIN
     PRINT('-----------------------------------------------------------------------------------------');
     PRINT('Below is the PRINTOUT ONLY of the commands to be executed once the @Execute is set to = 1');
     PRINT('-----------------------------------------------------------------------------------------');
END

SELECT @RowCount = COUNT(Id) FROM [#SelectedObjectList]
WHILE @LineId <= @RowCount
      BEGIN
            SELECT      
                         @Command = 'TRUNCATE TABLE '+[SchemaName]+'.'+[TableName]
            FROM         [#SelectedObjectList]
            WHERE        Id = @LineId

                  IF (@Execute = 0)
                  BEGIN                       
                       PRINT(@Command)
                  END
                  IF (@Execute = 1)
                  BEGIN
                      EXECUTE(@Command);
                      PRINT(CONCAT(@Command, ' - Executed Successfully'));
                  END

            SET @LineId = @LineId + 1;
      END;
GO
