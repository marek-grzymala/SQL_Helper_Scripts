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
    , @DropAllFKsPerDB BIT
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
    , @SqlEngineVersion INT

/* Set the list of Schemas and Tables you want to truncate; use a list of schemas and tables separated and terminated by the @delim charachter */
/* Below a sample list of tables and schemas from AdventureWorks2019 - fill in your values as you please */

SET @ListOfSchemaNames = 'Sales;Production;HumanResources;Person;'
SET @ListOfTableNames  = 'SpecialOfferProduct;Product;Employee;BusinessEntity;Person;'
SET @delim = ';' /* character used to delimit and terminate the items in the lists above */
SET @DropAllFKsPerDB = 0 /* Set @DropAllFKsPerDB to = 1 ONLY if you want to ignore the @ListOfSchemaNames/@ListOfTableNames above 
                            and generate drop/re-create commands for ALL FK constraints within the ENTIRE DB */

/* After the script executes CLOSE OR DISCONNECT THIS SESSION!!! - your commands are prepared in the table [_ForeignKeyConstraintDefinitions]
   and you do not want to overwrite this table by re-running this script accidentally 
   Do not delete the [_ForeignKeyConstraintDefinitions] table untill you are 100% sure that you no longer need it */

DROP TABLE IF EXISTS [#SelectedObjectList];
CREATE TABLE [#SelectedObjectList]
(
	 [Id]                 INT PRIMARY KEY CLUSTERED IDENTITY(1,1)
	,[SchemaID]           INT NOT NULL
	,[SchemaName]         SYSNAME NOT NULL
	,[ObjectID]           INT NOT NULL
	,[TableName]          SYSNAME NOT NULL
)

DROP TABLE IF EXISTS [dbo].[_ForeignKeyConstraintDefinitions]
CREATE TABLE [dbo].[_ForeignKeyConstraintDefinitions]

(
	 [LineId]                          INT PRIMARY KEY CLUSTERED IDENTITY(1,1)
    ,[Foreign_Key_Id]                  INT UNIQUE NOT NULL
	,[Drop_Constraint_Command]         NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Recreate_Constraint_Command]     NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)


IF (@DropAllFKsPerDB <> 1) AND ((RIGHT(@ListOfSchemaNames, 1) <> @delim) OR (RIGHT(@ListOfTableNames, 1) <> @delim))
BEGIN
SET @ErrorMsg
    = N'Strings: @ListOfSchemaNames and @ListOfTableNames have to end with the delimiter scpecified in @delim variable: [' + @delim + ']';
RAISERROR(@ErrorMsg, 16, 1);
RETURN;
END

/* ----------------------------------- Search through @ListOfSchemaNames: ----------------------------------- */
SET @start_search_sch = 0
SET @delim_pos_sch = 0
IF (@DropAllFKsPerDB <> 1)
BEGIN
    WHILE CHARINDEX(@delim, @ListOfSchemaNames, @start_search_sch + 1) > 0
    BEGIN
        SET @delim_pos_sch = CHARINDEX(@delim, @ListOfSchemaNames, @start_search_sch + 1) - @start_search_sch
        SET @schema_name = SUBSTRING(@ListOfSchemaNames, @start_search_sch, @delim_pos_sch)
        SET @schema_id = NULL;
        SELECT @schema_id = schema_id FROM sys.schemas WHERE name = @schema_name        
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
                   SELECT @object_id = object_id FROM sys.objects WHERE schema_id = @schema_id AND name = @name_tbl
                   
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
                                  ,@schema_name
                                  ,@object_id
                                  ,@name_tbl
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
        SELECT  SCHEMA_ID(TABLE_SCHEMA), TABLE_SCHEMA, OBJECT_ID(QUOTENAME(TABLE_SCHEMA)+'.'+QUOTENAME(TABLE_NAME)), TABLE_NAME
        FROM    INFORMATION_SCHEMA.TABLES
        WHERE   TABLE_TYPE = 'BASE TABLE'
END
/* ----------------------------------- End of Seaching through @ListOfSchemaNames -------------------------------- */
--SELECT * FROM [#SelectedObjectList]

IF  (@DropAllFKsPerDB <> 1) AND (SELECT COUNT(*) FROM [#SelectedObjectList]) < 1
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
                fk.object_id                                                                                    AS [Foreign_Key_Id]
               ,fk.name                                                                                         AS [Foreign_Key_Name]
               ,[sch_src].[SchemaName]                                                                          AS [Schema_Name_Src]
               ,(SELECT (OBJECT_NAME([fkc].parent_object_id)))                                                  AS [Table_Name_Src]
               ,[fkc].parent_column_id                                                                          AS [Column_Id_Src]
               ,[col_src].name                                                                                  AS [Column_Name_Src]
               ,[sch_tgt].[SchemaName]                                                                          AS [Schema_Name_Trgt]                      
               ,(SELECT (OBJECT_NAME([fkc].referenced_object_id)))                                              AS [Table_Name_Trgt]
               ,[fkc].referenced_column_id                                                                      AS [Column_Id_Trgt]
               ,[col_tgt].name                                                                                  AS [Column_Name_Trgt]
               ,[sch_tgt].[SchemaId]                                                                            AS [Schema_Id_Trgt]
               ,[fk].delete_referential_action
               ,[fk].update_referential_action
               ,OBJECT_ID('[' + [sch_tgt].[SchemaName] + '].[' + OBJECT_NAME([fkc].referenced_object_id) + ']') AS [Object_Id_Trgt]
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
                )                                                              AS [sch_src]
CROSS APPLY     (
                    SELECT [sc].name      
                    FROM   sys.columns                                         AS [sc] 
                    WHERE  [sc].object_id = fk.[parent_object_id] 
                    AND    [sc].column_id = [fkc].[parent_column_id]
                )                                                              AS [col_src]
CROSS APPLY     (
                    SELECT     [ss].schema_id                                  AS [SchemaId]
                              ,[ss].name                                       AS [SchemaName]
                    FROM       sys.objects                                     AS [so]
                    INNER JOIN sys.schemas                                     AS [ss] ON [ss].schema_id = [so].schema_id
                    WHERE      [so].object_id = [fkc].referenced_object_id
                )                                                              AS [sch_tgt]
CROSS APPLY     (
                    SELECT [sc].name      
                    FROM   sys.columns                                         AS [sc] 
                    WHERE  [sc].object_id = fk.[referenced_object_id] 
                    AND    [sc].column_id = [fkc].[referenced_column_id]
                )                                                              AS [col_tgt]
INNER JOIN      [#SelectedObjectList]                                          AS [sol] 
ON              [sol].SchemaID = [sch_tgt].[SchemaId] 
/* if you want to search by source schema+table names (rather than target) uncomment line below and comment the next one */
--AND             [sol].[ObjectID] = OBJECT_ID(QUOTENAME([sch_src].[SchemaName]) + '.' + QUOTENAME(OBJECT_NAME([fkc].[parent_object_id])))
AND             [sol].[ObjectID] = OBJECT_ID(QUOTENAME([sch_tgt].[SchemaName]) + '.' + QUOTENAME(OBJECT_NAME([fkc].[referenced_object_id])))
      
/* ORDER BY        fk.object_id, Schema_Name_Trgt, Table_Name_Trgt */
)
INSERT INTO  [dbo].[_ForeignKeyConstraintDefinitions](
             [Foreign_Key_Id]              
            ,[Drop_Constraint_Command]     
            ,[Recreate_Constraint_Command]
)
SELECT         
             [cte].[Foreign_Key_Id],
             [Drop_Constraint_Command] = 
                    'ALTER TABLE ' + QUOTENAME([cte].[Schema_Name_Src]) + '.' + QUOTENAME([cte].[Table_Name_Src])+' DROP CONSTRAINT ' + QUOTENAME([cte].[Foreign_Key_Name]) + ';',        
             
             [Recreate_Constraint_Command] = 
             CONCAT('ALTER TABLE ' + QUOTENAME([cte].[Schema_Name_Src]) + '.'+ QUOTENAME([cte].[Table_Name_Src])+' WITH NOCHECK ADD CONSTRAINT ' + QUOTENAME([cte].[Foreign_Key_Name]) + ' ',
             CASE 
             WHEN @SqlEngineVersion < 14 
                    /* For SQL Versions older than 14 (2017) use FOR XML PATH for all multi-column constraints: */
             THEN   'FOREIGN KEY ('+ STUFF((SELECT   ', ' + QUOTENAME([t].[Column_Name_Src])
                                            FROM      [cte] AS [t]
                                            WHERE     [t].Foreign_Key_Id = [cte].[Foreign_Key_Id]
                                            ORDER BY  [t].Column_Id_Trgt --This is identical to the ORDER BY in WITHIN GROUP clause in STRING_AGG
                                            FOR XML PATH(''),TYPE).value('(./text())[1]', 'VARCHAR(MAX)'), 1, 2,'') + ' ) ' +
                    'REFERENCES '  + QUOTENAME([cte].[Schema_Name_Trgt])+'.'+ QUOTENAME([cte].[Table_Name_Trgt])+
                              ' (' + STUFF((SELECT   ', ' + QUOTENAME([t].[Column_Name_Trgt])
                                            FROM      [cte] AS [t]
                                            WHERE     [t].[Foreign_Key_Id] = [cte].[Foreign_Key_Id]
                                            ORDER BY  [t].[Column_Id_Trgt] --This is identical to the ORDER BY in WITHIN GROUP clause in STRING_AGG
                                            FOR XML PATH(''),TYPE).value('(./text())[1]', 'VARCHAR(MAX)'), 1, 2,'') + ' )'                 
             ELSE   
                    /* For SQL Versions 2017+ use STRING_AGG for all multi-column constraints: */                  
                    'FOREIGN KEY ('+ STRING_AGG(QUOTENAME([cte].[Column_Name_Src]), ', ') WITHIN GROUP (ORDER BY [cte].[Column_Id_Trgt]) +') '+
                    'REFERENCES '  + QUOTENAME([cte].[Schema_Name_Trgt])+'.'+ QUOTENAME([cte].[Table_Name_Trgt])+' ('+ STRING_AGG(QUOTENAME([cte].[Column_Name_Trgt]), ', ') + ')'             
             END,   
             CASE
                 WHEN [cte].delete_referential_action = 1 THEN ' ON DELETE CASCADE '
                 WHEN [cte].delete_referential_action = 2 THEN ' ON DELETE SET NULL '
                 WHEN [cte].delete_referential_action = 3 THEN ' ON DELETE SET DEFAULT '
                 ELSE ''
             END, 
             CASE
                 WHEN [cte].update_referential_action = 1 THEN ' ON UPDATE CASCADE '
                 WHEN [cte].update_referential_action = 2 THEN ' ON UPDATE SET NULL '
                 WHEN [cte].update_referential_action = 3 THEN ' ON UPDATE SET DEFAULT '
                 ELSE ''
             END,
             CHAR(13)+ 'ALTER TABLE ' + QUOTENAME([cte].[Schema_Name_Src])+'.'+ QUOTENAME([cte].[Table_Name_Src])+' CHECK CONSTRAINT '+ QUOTENAME([cte].[Foreign_Key_Name])+';')
FROM         [cte]
GROUP BY     
             [cte].[Foreign_Key_Id]
            ,[cte].[Schema_Name_Src]
            ,[cte].[Table_Name_Src]
            ,[cte].[Foreign_Key_Name]
            ,[cte].[Schema_Name_Trgt]
            ,[cte].[Table_Name_Trgt]
            ,[cte].delete_referential_action
            ,[cte].update_referential_action
ORDER BY     [cte].[Table_Name_Src]

IF  (SELECT COUNT(*) FROM [dbo].[_ForeignKeyConstraintDefinitions]) < 1
BEGIN
    BEGIN
    SET @ErrorMsg
        = N'Could not find any foreign keys referencing the tables specified in the list of schemas: [' + @ListOfSchemaNames + N'] and tables: [' + @ListOfTableNames + N'] in the database: [' + DB_NAME(DB_ID()) + N'].';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
    END
END

SELECT 
            [Foreign_Key_Id]              
           ,[Drop_Constraint_Command]     
           ,[Recreate_Constraint_Command] 
FROM        [dbo].[_ForeignKeyConstraintDefinitions] 
ORDER BY    [Recreate_Constraint_Command], [Foreign_Key_Id]
