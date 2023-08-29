/*
improved and extended version of: 
https://en.dirceuresende.com/blog/sql-server-como-recuperar-o-codigo-fonte-de-um-objeto-criptografado-with-encryption/
https://stackoverflow.com/questions/7670636/how-to-decrypt-stored-procedure-in-sql-server-2008/7671944#7671944
*/
--USE [YourDbName]
--GO

SET NOCOUNT ON;

DECLARE @EncryptedObjectOwnerOrSchema SYSNAME = N'dbo',
        @EncryptedObjectName SYSNAME = N'p_TestEncryption', /* 'P' 'V' 'TR' 'FN' 'TF' 'IF' */
        @ErrorMsg NVARCHAR(2047),
        @ObjectID INT, -- = 97591586,           /* if value supplied, it has to match Schema and Object Name above */
        @ObjectType NVARCHAR(128), -- = 'FN';    /* if value supplied, it has to match Schema and Object Name above */
        @CreateDecryptedVersion BIT = 0,
        @PrintOutObjectDefinition BIT = 1;

DECLARE 
        @SessionId INT,
        @TriggerOnSchema SYSNAME,
        @TriggerOnTable SYSNAME, 
        @TriggerForType NVARCHAR(32), /* Maximum possible length is 22 => LEN('INSERT, UPDATE, DELETE') */
        @RealEncryptedObject NVARCHAR(MAX),
        @ObjectDataLength INT,
        @DefinitionOfFakeEncryptedObject NVARCHAR(MAX),
        @TempFakeEncryptedObject NVARCHAR(MAX),
        @DefinitionOfDecryptedObject NVARCHAR(MAX),
        @Pointer_DecryptedString INT,
        @Pointer_BeginOfNewLine INT,
        @LineSeparator CHAR(2) = CHAR(13) + CHAR(10),
        @DecryptedLineOfCode NVARCHAR(MAX);
/* ------------------------------------------- Check Input: -------------------------------------------  */

SELECT      @SessionId = ses.session_id
FROM        sys.endpoints AS en
INNER JOIN  sys.dm_exec_sessions ses ON en.endpoint_id = ses.endpoint_id
WHERE       en.name = 'Dedicated Admin Connection';

IF (@@SPID <> (COALESCE(@SessionId, 0)))
BEGIN
    SET @ErrorMsg
        = N'In order to run this script you need to connect using Dedicated Admin Connection (DAC).';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
END

IF  (@ObjectID IS NULL)
BEGIN
SET @ObjectID = OBJECT_ID('[' + @EncryptedObjectOwnerOrSchema + '].[' + @EncryptedObjectName + ']');
    IF  @ObjectID IS NULL
    BEGIN
    SET @ErrorMsg
        = N'Object [' + @EncryptedObjectOwnerOrSchema + N'].[' + @EncryptedObjectName
          + N'] does not exist in the database: [' + DB_NAME(DB_ID()) + N'].';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
    END
END

IF NOT EXISTS
(
    SELECT      TOP 1 *
    FROM        sys.objects  so
    INNER JOIN  sys.syscomments sc ON so.[object_id] = sc.[id]
    WHERE       [id] = @ObjectID
)
BEGIN
    SET @ErrorMsg
        = N'Object [' + @EncryptedObjectOwnerOrSchema + N'].[' + @EncryptedObjectName + N'] with ID: ['+CONVERT(VARCHAR(32), @ObjectID)+'] exists in the database: ['
          + DB_NAME(DB_ID()) + N'] but it does not have an entry in sys.objects and/or sys.syscomments.';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
END;

IF EXISTS
(
    SELECT  TOP 1 *
    FROM    sys.syscomments
    WHERE   [id] = @ObjectID
    AND     [encrypted] = 0
)
BEGIN
    SET @ErrorMsg
        = N'Object [' + @EncryptedObjectOwnerOrSchema + N'].[' + @EncryptedObjectName + N'] exists in the database: ['
          + DB_NAME(DB_ID()) + N'] but it is not encrypted.';
    RAISERROR(@ErrorMsg, 16, 1);
    RETURN;
END;

IF (@ObjectType IS NULL)
BEGIN
    SELECT      @ObjectType =   so.[type]
    FROM        sys.objects     so
    INNER JOIN  sys.syscomments sc ON so.[object_id] = sc.[id]
    WHERE       so.[object_id] = @ObjectID
    AND         sc.[encrypted] = 1
    IF  (@ObjectType IS NULL)
        BEGIN
                SET @ErrorMsg
                    = N'Could not find Object Type in sys.objects for [' + @EncryptedObjectOwnerOrSchema + N'].[' + @EncryptedObjectName
                      + N'] in the database: [' + DB_NAME(DB_ID()) + N'].';
                RAISERROR(@ErrorMsg, 16, 1);
                RETURN;
        END
END

/* ------------------------------------------- Print Out Object Type: -------------------------------------------  */
SELECT 
        @ObjectType AS [Object Type],
        CASE   @ObjectType
               WHEN (N'P' ) THEN N'Stored procedure'
               WHEN (N'V' ) THEN N'View'
               WHEN (N'TR') THEN N'Trigger'
               WHEN (N'FN') THEN N'Scalar function'
               WHEN (N'TF') THEN N'Table-function'
               WHEN (N'IF') THEN N'In-lined table-function'
        END AS [ObjectType Name]

IF (@ObjectType NOT IN ('P', 'V', 'TR', 'FN', 'TF', 'IF'))
    BEGIN
        SET @ErrorMsg
            = N'Object [' + @EncryptedObjectOwnerOrSchema + N'].[' + @EncryptedObjectName + N'] exists in the database: ['
              + DB_NAME(DB_ID()) + N'] but the object type: ['+ @ObjectType +'] is not handled by this script. '
              +CHAR(10)+'Currently supported object-types are: '
              +CHAR(10)+'[P]-PROCEDURE,'
              +CHAR(10)+'[V]-VIEW,'
              +CHAR(10)+'[TR]-TRIGGER,'
              +CHAR(10)+'[FN]-FUNCTION,'
              +CHAR(10)+'[TF]-TABLE-VALUED FUNCTION,'
              +CHAR(10)+'[IF]-IN-LINED TABLE-VALUED FUNCTION';
        RAISERROR(@ErrorMsg, 16, 1);
        RETURN;
    END;
/* ------------------------------------------- End of Check Input -------------------------------------------  */

/* ------------------------------------------- Classify Trigger Type: ----------------------------------------  */
IF (@ObjectType = 'TR')
BEGIN
     SELECT     @TriggerOnSchema = sch.[name],
                @TriggerOnTable = OBJECT_NAME(tr.parent_id),
                @TriggerForType = REPLACE(LTRIM(RTRIM(
                                  CASE WHEN OBJECTPROPERTY(so.[object_id], 'ExecIsInsertTrigger') = 1 THEN 'INSERT ' ELSE '' END + 
                                  CASE WHEN OBJECTPROPERTY(so.[object_id], 'ExecIsUpdateTrigger') = 1 THEN 'UPDATE ' ELSE '' END + 
                                  CASE WHEN OBJECTPROPERTY(so.[object_id], 'ExecIsDeleteTrigger') = 1 THEN 'DELETE ' ELSE '' END)), ' ', ', ')
     FROM       sys.objects  so
     INNER JOIN sys.triggers tr  ON tr.object_id = so.object_id
     INNER JOIN sys.tables   st  ON tr.parent_id = st.object_id
     INNER JOIN sys.schemas  sch ON so.schema_id = sch.schema_id
     WHERE      so.[type] = 'TR'
     AND        so.[object_id] = @ObjectID;
END
/* ------------------------------------------- End of Classify Trigger Type -------------------------------------------  */

/* ------------------------------------------- Prepopulate Fake Object Header: ---------------------------------------  */
SELECT  TOP 1
        @RealEncryptedObject = imageval
FROM    sys.sysobjvalues
WHERE   [objid] = @ObjectID
AND     valclass = 1

SET     @ObjectDataLength = DATALENGTH(@RealEncryptedObject) / 2;

SELECT @DefinitionOfFakeEncryptedObject =
CASE   @ObjectType
       WHEN (N'P')  THEN N'ALTER PROCEDURE [' + @EncryptedObjectOwnerOrSchema + N'].[' + @EncryptedObjectName + N'] WITH ENCRYPTION AS'
       WHEN (N'V')  THEN N'ALTER VIEW ['      + @EncryptedObjectOwnerOrSchema + N'].[' + @EncryptedObjectName + N'] WITH ENCRYPTION AS SELECT 1 AS [1]'
       WHEN (N'TR') THEN N'ALTER TRIGGER ['   + @EncryptedObjectOwnerOrSchema + N'].[' + @EncryptedObjectName + N'] ON ['
                                              + @TriggerOnSchema + N'].['              + @TriggerOnTable + N'] WITH ENCRYPTION FOR ' + @TriggerForType + N' AS BEGIN SELECT 1 END'
       WHEN (N'FN') THEN N'ALTER FUNCTION ['  + @EncryptedObjectOwnerOrSchema + N'].[' + @EncryptedObjectName + N']() RETURNS INT WITH ENCRYPTION AS BEGIN RETURN 1 END'
       WHEN (N'TF') THEN N'ALTER FUNCTION ['  + @EncryptedObjectOwnerOrSchema + N'].[' + @EncryptedObjectName + N']() RETURNS @t TABLE (p1 INT) WITH ENCRYPTION AS BEGIN INSERT @t SELECT 1 RETURN END'
       WHEN (N'IF') THEN N'ALTER FUNCTION ['  + @EncryptedObjectOwnerOrSchema + N'].[' + @EncryptedObjectName + N']() RETURNS TABLE WITH ENCRYPTION AS RETURN (SELECT 1 AS [1])'
END
/* ------------------------------------------- End of Prepopulate Fake Object Header --------------------------------------  */

/* ------------------------------------------- Pad the fake object with dashes: -------------------------------------------  */
WHILE DATALENGTH(@DefinitionOfFakeEncryptedObject) / 2 < @ObjectDataLength
BEGIN
    IF DATALENGTH(@DefinitionOfFakeEncryptedObject) / 2 + 4000 < @ObjectDataLength
        SET @DefinitionOfFakeEncryptedObject = @DefinitionOfFakeEncryptedObject + REPLICATE(N'-', 4000);
    ELSE
        SET @DefinitionOfFakeEncryptedObject
            = @DefinitionOfFakeEncryptedObject + REPLICATE(N'-', @ObjectDataLength - (DATALENGTH(@DefinitionOfFakeEncryptedObject) / 2));
END;

/* ------------------------------------------- Create the fake object: -------------------------------------------------  */
SET XACT_ABORT OFF;
BEGIN TRAN;
    --PRINT(@DefinitionOfFakeEncryptedObject);
    EXEC (@DefinitionOfFakeEncryptedObject);
    
    SELECT  TOP 1
            @TempFakeEncryptedObject = imageval
    FROM    sys.sysobjvalues
    WHERE   [objid] = @ObjectID
    AND     valclass = 1

IF @@TRANCOUNT > 0
BEGIN
    /* Now that the fake object is stored in the @TempFakeEncryptedObject we can rollback the creation to keep the real object as it was */
    ROLLBACK TRAN;
END
/* -------------------------------------------  End of Create the fake object -------------------------------------------  */

SET @DefinitionOfFakeEncryptedObject = REPLACE(@DefinitionOfFakeEncryptedObject, 'ALTER PROCEDURE', 'CREATE PROCEDURE');
SET @DefinitionOfFakeEncryptedObject = REPLACE(@DefinitionOfFakeEncryptedObject, 'ALTER VIEW', 'CREATE VIEW');
SET @DefinitionOfFakeEncryptedObject = REPLACE(@DefinitionOfFakeEncryptedObject, 'ALTER FUNCTION', 'CREATE FUNCTION');
SET @DefinitionOfFakeEncryptedObject = REPLACE(@DefinitionOfFakeEncryptedObject, 'ALTER TRIGGER', 'CREATE TRIGGER');

/* ------------------------------------------- Pad the Object to be decrypted with placeholder characters: ---------------  */
SET @DefinitionOfDecryptedObject = N'';
WHILE DATALENGTH(@DefinitionOfDecryptedObject) / 2 < @ObjectDataLength
BEGIN
    IF DATALENGTH(@DefinitionOfDecryptedObject) / 2 + 4000 < @ObjectDataLength
        SET @DefinitionOfDecryptedObject = @DefinitionOfDecryptedObject + REPLICATE(N'A', 4000);
    ELSE
        SET @DefinitionOfDecryptedObject
            = @DefinitionOfDecryptedObject
              + REPLICATE(N'A', @ObjectDataLength - (DATALENGTH(@DefinitionOfDecryptedObject) / 2));
END;

/* -------------------------------------------  Do the actual Decrypting: --------------------------------------------------  */
SET @Pointer_DecryptedString = 1;
WHILE (@Pointer_DecryptedString <= @ObjectDataLength)
BEGIN
    /*  
        Replace 1 character at a time in the @DefinitionOfDecryptedObject at the @Pointer_DecryptedString position
        with the result of XOR operation (^) between Real and Fake Encrypted Objects:
    */
    SET @DefinitionOfDecryptedObject
        = STUFF(
                   @DefinitionOfDecryptedObject,
                   @Pointer_DecryptedString,
                   1,
                   NCHAR(UNICODE(SUBSTRING(@RealEncryptedObject, @Pointer_DecryptedString, 1))
                         ^ (UNICODE(SUBSTRING(@DefinitionOfFakeEncryptedObject, @Pointer_DecryptedString, 1))
                            ^ UNICODE(SUBSTRING(@TempFakeEncryptedObject, @Pointer_DecryptedString, 1))
                           )
                        )
               );
    SET @Pointer_DecryptedString = @Pointer_DecryptedString + 1;
END;


/* ------------------------------------------------- Comment out the 'WITH ENCRYPTION' clause: --------------------------------*/
IF (CHARINDEX('WITH ENCRYPTION', @DefinitionOfDecryptedObject COLLATE Latin1_General_CI_AI)) > 0
BEGIN
    /* COLLATE Latin1_General_CI_AI makes below Case-Insensitive (valid for both: 'WITH ENCRYPTION' and 'with encryption'): */
    SET @DefinitionOfDecryptedObject = REPLACE(@DefinitionOfDecryptedObject COLLATE Latin1_General_CI_AI, 'WITH ENCRYPTION', '/* WITH ENCRYPTION */')
END

IF (@CreateDecryptedVersion = 1)
BEGIN
    DECLARE @EncryptedObjectNewName SYSNAME = @EncryptedObjectName + '_ENCRYPTED';
    DECLARE @rename_return INT, @exec_return INT;
    EXEC @rename_return = sp_rename @objname = @EncryptedObjectName, @newname = @EncryptedObjectNewName;
    IF @rename_return <> 0
    BEGIN
        RAISERROR('sp_rename returned return code %d', 16, 1);
    END
    ELSE
    BEGIN
        PRINT(CONCAT('Successfully renamed: ', QUOTENAME(@EncryptedObjectName), ' to: ', QUOTENAME(@EncryptedObjectNewName)));
    BEGIN TRY
        BEGIN TRY
            EXECUTE sp_executesql @stmt = @DefinitionOfDecryptedObject;
            PRINT(CONCAT('Successfully created decrypted version of: ', QUOTENAME(@EncryptedObjectName)));
        END TRY
        BEGIN CATCH  
    
            DECLARE
                 @ErrorNumber int
                ,@ErrorMessage nvarchar(2048)
                ,@ErrorSeverity int
                ,@ErrorState int
                ,@ErrorLine int;
    
            SELECT
                 @ErrorNumber =ERROR_NUMBER()
                ,@ErrorMessage =ERROR_MESSAGE()
                ,@ErrorSeverity = ERROR_SEVERITY()
                ,@ErrorState =ERROR_STATE()
                ,@ErrorLine =ERROR_LINE();
    
            RAISERROR('Error %d caught in @DefinitionOfDecryptedObject at line %d: %s'
                ,@ErrorSeverity
                ,@ErrorState
                ,@ErrorNumber
                ,@ErrorLine
                ,@ErrorMessage);
    
        END CATCH; 
    END TRY
    BEGIN CATCH  
        THROW;
    END CATCH; 
    END
END

/* ------------------------------------------------- Print out section: --------------------------------------------------------*/
IF (@PrintOutObjectDefinition = 1)
BEGIN
    DROP TABLE IF EXISTS #ObjectDefinition
    CREATE TABLE #ObjectDefinition
    (
        [LineId] INT PRIMARY KEY CLUSTERED IDENTITY(1,1),
        [DecryptedLineOfCode] NVARCHAR(MAX)
    );
    SET @Pointer_DecryptedString = 0;
    SET @Pointer_BeginOfNewLine = -2; /* (-2) because at first iteration we want to catch the first 2 characters of the first line */
    
    WHILE @Pointer_DecryptedString <= LEN(@DefinitionOfDecryptedObject)
    BEGIN
        IF ((SUBSTRING(@DefinitionOfDecryptedObject, @Pointer_DecryptedString + 1, 2) = @LineSeparator) OR (@Pointer_DecryptedString = LEN(@DefinitionOfDecryptedObject)))
        BEGIN
            SELECT @DecryptedLineOfCode
                /* = TRIM(@LineSeparator FROM SUBSTRING(@DefinitionOfDecryptedObject, @Pointer_BeginOfNewLine + LEN(@LineSeparator), (@Pointer_DecryptedString - @Pointer_BeginOfNewLine))); */
                /* If you are on SQL that does not understand TRIM: */
                = REPLACE(REPLACE(
                  SUBSTRING(@DefinitionOfDecryptedObject, @Pointer_BeginOfNewLine + LEN(@LineSeparator), (@Pointer_DecryptedString - @Pointer_BeginOfNewLine))
                  , CHAR(13), ''), CHAR(10), '')
            
            --IF (CHARINDEX('WITH ENCRYPTION', @DecryptedLineOfCode)) > 0
            --BEGIN
            --    SET @DecryptedLineOfCode = REPLACE(@DecryptedLineOfCode, 'WITH ENCRYPTION', '/* WITH ENCRYPTION */')
            --END
            PRINT (@DecryptedLineOfCode);
            INSERT INTO #ObjectDefinition
            (
                DecryptedLineOfCode
            )
            VALUES
            (@DecryptedLineOfCode);
            SET @Pointer_BeginOfNewLine = @Pointer_DecryptedString;
        END
        SET @Pointer_DecryptedString = @Pointer_DecryptedString + 1;
    END;
    /* ------------------------------------------------ End of Print out section --------------------------------------------------------*/
    
    SELECT 
             [LineId],
             [DecryptedLineOfCode]
    FROM     #ObjectDefinition 
    ORDER BY [LineId]
END

/*
--Check length of each object:
SELECT LEN(@RealEncryptedObject) AS [Length_Real_Object],
       LEN(@DefinitionOfFakeEncryptedObject) AS [Length_Fake_Object],
       LEN(@TempFakeEncryptedObject) AS [Length_Temp_Fake_Object],
       LEN(@DefinitionOfDecryptedObject) AS [Length_Decrypted_Object]
*/
