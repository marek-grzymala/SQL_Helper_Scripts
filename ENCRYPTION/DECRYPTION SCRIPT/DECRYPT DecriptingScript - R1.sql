/*
improved and extended version of: 
https://en.dirceuresende.com/blog/sql-server-como-recuperar-o-codigo-fonte-de-um-objeto-criptografado-with-encryption/
*/
USE [TestDb]
GO

SET NOCOUNT ON;

DECLARE @EncryptedObjectOwnerOrSchema SYSNAME = N'dbo',
        @EncryptedObjectName SYSNAME = N'if_TestEncryption', /* 'P' 'V' 'TR' 'FN' 'TF' 'IF' */
        @ErrorMsg NVARCHAR(2047),
        @ObjectID INT, -- = 97591586,           /* if value supplied, it has to match Schema and Object Name above */
        @ObjectType NVARCHAR(128) -- = 'FN';    /* if value supplied, it has to match Schema and Object Name above */

DECLARE 
        @SessionId INT,
        @TriggerOnSchema SYSNAME,
        @TriggerOnTable SYSNAME, 
        @TriggerForType NVARCHAR(32), /* Maximum possible length is 22 => LEN('INSERT, UPDATE, DELETE') */
        @DefinitionOfRealEncryptedObject NVARCHAR(MAX),
        @ObjectDataLength INT,
        @DefinitionOfFakeObject NVARCHAR(MAX),
        @DefinitionOfFakeEncryptedObject NVARCHAR(MAX),
        @DefinitionOfDecryptedObject NVARCHAR(MAX),
        @Pointer_DecryptedString INT,
        @Pointer_BeginOfNewLine INT,
        @LineSeparator CHAR(2) = CHAR(13) + CHAR(10),
        @LineOfText NVARCHAR(MAX);
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

IF  @ObjectID IS NULL
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
ELSE IF EXISTS
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
    SELECT      @ObjectType = so.[type]
    FROM        sys.objects  so
    INNER JOIN  sys.syscomments sc ON so.[object_id] = sc.[id]
    WHERE       so.[object_id] = @ObjectID
    AND         sc.[encrypted] = 1
    IF  @ObjectType IS NULL
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
     FROM       sys.objects so
     INNER JOIN sys.triggers tr ON tr.object_id = so.object_id
     INNER JOIN sys.tables st ON tr.parent_id = st.object_id
     INNER JOIN sys.schemas sch ON so.schema_id = sch.schema_id
     WHERE      so.[type] = 'TR'
     AND        so.[object_id] = @ObjectID;
END
/* ------------------------------------------- End of Classify Trigger Type -------------------------------------------  */

/* ------------------------------------------- Prepopulate Fake Object Header: ---------------------------------------  */
SELECT  TOP 1
        @DefinitionOfRealEncryptedObject = imageval
FROM    sys.sysobjvalues
WHERE   [objid] = @ObjectID
AND     valclass = 1

SET     @ObjectDataLength = DATALENGTH(@DefinitionOfRealEncryptedObject) / 2;

SELECT @DefinitionOfFakeObject =
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
WHILE DATALENGTH(@DefinitionOfFakeObject) / 2 < @ObjectDataLength
BEGIN
    IF DATALENGTH(@DefinitionOfFakeObject) / 2 + 4000 < @ObjectDataLength
        SET @DefinitionOfFakeObject = @DefinitionOfFakeObject + REPLICATE(N'-', 4000);
    ELSE
        SET @DefinitionOfFakeObject
            = @DefinitionOfFakeObject + REPLICATE(N'-', @ObjectDataLength - (DATALENGTH(@DefinitionOfFakeObject) / 2));
END;

/* ------------------------------------------- Create the fake object: -------------------------------------------------  */
SET XACT_ABORT OFF;
BEGIN TRAN;
    --PRINT(@DefinitionOfFakeObject);
    EXEC (@DefinitionOfFakeObject);
    
    SELECT  TOP 1
            @DefinitionOfFakeEncryptedObject = imageval
    FROM    sys.sysobjvalues
    WHERE   [objid] = @ObjectID
    AND     valclass = 1

IF @@TRANCOUNT > 0
BEGIN
    /* Now that the fake object is stored in the @DefinitionOfFakeEncryptedObject we can rollback the creation to keep the real object as it was */
    ROLLBACK TRAN;
END
/* -------------------------------------------  End of Create the fake object -------------------------------------------  */

SET @DefinitionOfFakeObject = REPLACE(@DefinitionOfFakeObject, 'ALTER PROCEDURE', 'CREATE PROCEDURE');
SET @DefinitionOfFakeObject = REPLACE(@DefinitionOfFakeObject, 'ALTER VIEW', 'CREATE VIEW');
SET @DefinitionOfFakeObject = REPLACE(@DefinitionOfFakeObject, 'ALTER FUNCTION', 'CREATE FUNCTION');
SET @DefinitionOfFakeObject = REPLACE(@DefinitionOfFakeObject, 'ALTER TRIGGER', 'CREATE TRIGGER');

/* -------------------------------------------  Do the actual Decrypting: --------------------------------------------------  */
SET @Pointer_DecryptedString = 1;
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

WHILE (@Pointer_DecryptedString <= @ObjectDataLength)
BEGIN
    SET @DefinitionOfDecryptedObject
        = STUFF(
                   @DefinitionOfDecryptedObject,
                   @Pointer_DecryptedString,
                   1,
                   NCHAR(UNICODE(SUBSTRING(@DefinitionOfRealEncryptedObject, @Pointer_DecryptedString, 1))
                         ^ (UNICODE(SUBSTRING(@DefinitionOfFakeObject, @Pointer_DecryptedString, 1))
                            ^ UNICODE(SUBSTRING(@DefinitionOfFakeEncryptedObject, @Pointer_DecryptedString, 1))
                           )
                        )
               );
    SET @Pointer_DecryptedString = @Pointer_DecryptedString + 1;
END;

/* ------------------------------------------------- Print out section: --------------------------------------------------------*/
DECLARE @Table TABLE
(
    [LineOfText] NVARCHAR(MAX)
);
SET @Pointer_DecryptedString = 0;
SET @Pointer_BeginOfNewLine = -2; /* (-2) because at first iteration we want to catch the first 2 charachters of the first line */
WHILE @Pointer_DecryptedString <= LEN(@DefinitionOfDecryptedObject)
BEGIN
    IF ((SUBSTRING(@DefinitionOfDecryptedObject, @Pointer_DecryptedString + 1, 2) = @LineSeparator) OR (@Pointer_DecryptedString = LEN(@DefinitionOfDecryptedObject)))
    BEGIN
        SELECT @LineOfText
            /* = TRIM(@LineSeparator FROM SUBSTRING(@DefinitionOfDecryptedObject, @Pointer_BeginOfNewLine + LEN(@LineSeparator), (@Pointer_DecryptedString - @Pointer_BeginOfNewLine))); */
            /* If you are on SQL that does not understand TRIM: */
            = REPLACE(REPLACE(
              SUBSTRING(@DefinitionOfDecryptedObject, @Pointer_BeginOfNewLine + LEN(@LineSeparator), (@Pointer_DecryptedString - @Pointer_BeginOfNewLine))
              , CHAR(13), ''), CHAR(10), '')
        
        IF (CHARINDEX('WITH ENCRYPTION', @LineOfText)) > 0
        BEGIN
            SET @LineOFText = REPLACE(@LineOFText, 'WITH ENCRYPTION', '/* WITH ENCRYPTION */')
        END
        PRINT (@LineOfText);
        INSERT INTO @Table
        (
            LineOfText
        )
        VALUES
        (@LineOfText);
        SET @Pointer_BeginOfNewLine = @Pointer_DecryptedString;
    END
    SET @Pointer_DecryptedString = @Pointer_DecryptedString + 1;
END;

SELECT *
FROM @Table;
/* ------------------------------------------------ End of Print out section --------------------------------------------------------*/