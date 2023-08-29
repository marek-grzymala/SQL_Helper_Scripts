USE [DbName]
GO

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

DECLARE 
        @ReferencedObjectOwnerOrSchema SYSNAME = 'dbo'
       ,@ReferencedObjectName SYSNAME = 'TableName'
       ,@ObjectID INT
       ,@ErrorMsg NVARCHAR(2047)
       ,@SqlEngineVersion INT

SELECT @SqlEngineVersion = CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20)), 1, 2) AS INT)

DROP TABLE IF EXISTS [dbo].[_ForeignKeyConstraintDefinitions]CREATE TABLE [dbo].[_ForeignKeyConstraintDefinitions]--DECLARE @ConstraintCommands TABLE(	 [LineId]                          INT PRIMARY KEY CLUSTERED IDENTITY(1,1)
    ,[Foreign_Key_Id]                  INT UNIQUE NOT NULL
	,[Drop_Constraint_Command]         NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Recreate_Constraint_Command]     NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)

IF  (@ObjectID IS NULL)
BEGIN
SET @ObjectID = OBJECT_ID('[' + @ReferencedObjectOwnerOrSchema + '].[' + @ReferencedObjectName + ']');
    IF  (@ObjectID IS NULL)
    BEGIN
    SET @ErrorMsg
        = N'Object [' + @ReferencedObjectOwnerOrSchema + N'].[' + @ReferencedObjectName + N'] does not exist in the database: [' + DB_NAME(DB_ID()) + N'].';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
    END
END

; WITH cte AS (
       SELECT          
                       fk.[object_id]                                        AS [Foreign_Key_Id]
                      ,fk.[name]                                             AS [Foreign_Key_Name]
                      ,sch_src.[SchemaName]                                  AS [Schema_Name_Src]
                      ,(SELECT (OBJECT_NAME(fkc.parent_object_id)))          AS [Table_Name_Src]
                      ,fkc.parent_column_id                                  AS [Column_Id_Src]
                      ,col_src.[name]                                        AS [Column_Name_Src]
                      ,sch_tgt.[SchemaName]                                  AS [Schema_Name_Trgt]                      
                      ,(SELECT (OBJECT_NAME(fkc.referenced_object_id)))      AS [Table_Name_Trgt]
                      ,fkc.referenced_column_id                              AS [Column_Id_Trgt]
                      ,col_tgt.[name]                                        AS [Column_Name_Trgt]
       FROM            sys.foreign_keys                                      AS fk
       CROSS APPLY     (
                           SELECT  
                                   fkc.parent_column_id,
                                   fkc.parent_object_id,
                                   fkc.referenced_object_id,
                                   fkc.referenced_column_id
                           FROM    sys.foreign_key_columns                            AS fkc 
                           WHERE   1 = 1
                           AND     fk.parent_object_id = fkc.parent_object_id 
                           AND     fk.referenced_object_id = fkc.referenced_object_id
                           AND     fk.[object_id] = fkc.constraint_object_id
                       )                                                              AS  fkc
       CROSS APPLY     (
                           SELECT     ss.[name]                                       AS [SchemaName]
                           FROM       sys.objects                                     AS so
                           INNER JOIN sys.schemas                                     AS ss ON ss.[schema_id] = so.[schema_id]
                           WHERE      so.[object_id] = fkc.parent_object_id
                       )                                                              AS sch_src
       CROSS APPLY     (
                           SELECT sc.[name]      
                           FROM   sys.columns                                         AS sc 
                           WHERE  sc.[object_id] = fk.[parent_object_id] 
                           AND    sc.[column_id] = fkc.[parent_column_id]
                       )                                                              AS col_src
       CROSS APPLY     (
                           SELECT     ss.[name]                                       AS [SchemaName]
                           FROM       sys.objects                                     AS so
                           INNER JOIN sys.schemas                                     AS ss ON ss.[schema_id] = so.[schema_id]
                           WHERE      so.[object_id] = fkc.referenced_object_id
                       )                                                              AS sch_tgt
       CROSS APPLY     (
                           SELECT sc.[name]      
                           FROM   sys.columns                                         AS sc 
                           WHERE  sc.[object_id] = fk.[referenced_object_id] 
                           AND    sc.[column_id] = fkc.[referenced_column_id]
                       )                                                              AS col_tgt
       --WHERE           OBJECT_NAME(fk.referenced_object_id) = ('[' + @ReferencedObjectOwnerOrSchema + '].[' + @ReferencedObjectName + ']')
       WHERE           fk.referenced_object_id = @ObjectID /* this predicate is more accurate as it requires schema-prefix for non-dbo tables */
       AND             fkc.parent_object_id <> @ObjectID /* we exclude self-referencing constraints */
)
INSERT INTO  [dbo].[_ForeignKeyConstraintDefinitions](
             [Foreign_Key_Id]              
            ,[Drop_Constraint_Command]     
            ,[Recreate_Constraint_Command]
)
SELECT         
             cte.[Foreign_Key_Id],
             [Drop_Constraint_Command]     = 'ALTER TABLE '+ QUOTENAME(cte.[Schema_Name_Src])+'.'+ QUOTENAME(cte.[Table_Name_Src])+' DROP CONSTRAINT '+ QUOTENAME(cte.[Foreign_Key_Name])+';',        
             
             [Recreate_Constraint_Command] = 
             CASE 
             WHEN @SqlEngineVersion < 14 
                  /* For SQL Versions older than 14 (2017) use FOR XML PATH for all multi-column constraints: */
             THEN 'ALTER TABLE ' + QUOTENAME(cte.[Schema_Name_Src])+'.'+ QUOTENAME(cte.[Table_Name_Src])+' WITH CHECK ADD CONSTRAINT '+ QUOTENAME(cte.[Foreign_Key_Name])+' '+
                  'FOREIGN KEY ('+ STUFF((SELECT   ', ' + QUOTENAME(t.[Column_Name_Src])
                                         FROM     cte t
                                         WHERE    t.Foreign_Key_Id = cte.Foreign_Key_Id
                                         ORDER BY t.Column_Id_Src --This is identical to the ORDER BY in WITHIN GROUP clause in STRING_AGG
                                         FOR XML PATH(''),TYPE).value('(./text())[1]', 'VARCHAR(MAX)'), 1, 1,'')+' ) '+
                  'REFERENCES ' + QUOTENAME(cte.[Schema_Name_Trgt])+'.'+ QUOTENAME(cte.[Table_Name_Trgt])+
                            ' ('+ STUFF((SELECT   ', ' + QUOTENAME(t.[Column_Name_Trgt])
                                        FROM     cte t
                                        WHERE    t.Foreign_Key_Id = cte.Foreign_Key_Id
                                        ORDER BY t.Column_Id_Trgt --This is identical to the ORDER BY in WITHIN GROUP clause in STRING_AGG
                                        FOR XML PATH(''),TYPE).value('(./text())[1]', 'VARCHAR(MAX)'), 1, 1,'')+' ); '
             ELSE 
                  /* For SQL Versions 2017+ use STRING_AGG for all multi-column constraints: */
                  'ALTER TABLE '  + QUOTENAME(cte.[Schema_Name_Src])+'.'+ QUOTENAME(cte.[Table_Name_Src])+' WITH CHECK ADD CONSTRAINT '+ QUOTENAME(cte.[Foreign_Key_Name])+' '+
                  'FOREIGN KEY ( '+ STRING_AGG(QUOTENAME(cte.[Column_Name_Src]), ', ') WITHIN GROUP (ORDER BY cte.[Column_Id_Src]) +' ) '+
                  'REFERENCES '   + QUOTENAME(cte.[Schema_Name_Trgt])+'.'+ QUOTENAME(cte.[Table_Name_Trgt])+' ( '+ STRING_AGG(QUOTENAME(cte.[Column_Name_Trgt]), ', ')+' );'
             END
FROM         cte
GROUP BY     
             cte.[Foreign_Key_Id]
            ,cte.[Schema_Name_Src]
            ,cte.[Table_Name_Src]
            ,cte.[Foreign_Key_Name]
            ,cte.[Schema_Name_Trgt]
            ,cte.[Table_Name_Trgt]
ORDER BY     cte.[Table_Name_Src]
GO

SELECT * FROM [dbo].[_ForeignKeyConstraintDefinitions] ORDER BY [Drop_Constraint_Command] 

/* ======================================================================================================================= */
/* !!! ATTENTION - from this line to the end: run this code-section IN A SEPARATE SESSION !!! 
   to avoid accidentally overwriting your [_ForeignKeyConstraintDefinitions] table with empty values 
   after dropping all constraints */
DECLARE
             @Foreign_Key_Id              INT
            ,@Drop_Constraint_Command     NVARCHAR(MAX)
            ,@Recreate_Constraint_Command NVARCHAR(MAX)
            ,@Command                     NVARCHAR(MAX)
            ,@Drop                        BIT
            ,@Recreate                    BIT
            ,@Execute                     BIT
            ,@RowCount                    INT
            ,@LineId                      INT = 1   

SET @Drop = 0
SET @Recreate = 0
/* CAUTION!!!! SETTING @Execute = 1 WILL EXECUTE ALL @Drop OR @Recreate COMMANDS: */
SET @Execute = 0 /* 0 = Print out the @Command only */
SET XACT_ABORT ON

SELECT @RowCount = COUNT(LineId) FROM [dbo].[_ForeignKeyConstraintDefinitions]
WHILE @LineId <= @RowCount
      BEGIN
            SELECT      
                         @Foreign_Key_Id                = [Foreign_Key_Id]              
                        ,@Drop_Constraint_Command       = [Drop_Constraint_Command]     
                        ,@Recreate_Constraint_Command   = [Recreate_Constraint_Command]
            FROM         [dbo].[_ForeignKeyConstraintDefinitions]
            WHERE        LineId = @LineId

            IF (@Execute = 0)
            BEGIN
                PRINT(@Command)
            END
            IF (@Execute = 1)
            BEGIN
                  IF (@Drop = 1 AND @Recreate = 0)
                  BEGIN
                      SET @Command = @Drop_Constraint_Command
                  END
                  ELSE IF (@Drop = 0 AND @Recreate = 1)
                  BEGIN
                      SET @Command = @Recreate_Constraint_Command
                  END
                  ELSE
                  BEGIN
                        RAISERROR('If you want to execute the command then set one (and only one) of the parameters: @Drop or @Recreate = 1 so that either one of the actions is selected', 16, 1);
                        RETURN;
                  END

                  EXECUTE (@Command)
                  IF (@@ERROR = 0)
                  BEGIN
                      PRINT(@Command+ ' - Executed Successfully')
                  END
            END
            SET @LineId = @LineId + 1;
      END

/* ======================================================================================================================= */
