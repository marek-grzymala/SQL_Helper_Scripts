--USE [TestDecryption];
--GO

/*
based on: https://sqljunkieshare.com/2012/03/07/decrypting-encrypted-stored-procedures-views-functions-in-sql-server-20052008-r2/
*/

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

CREATE PROCEDURE [dbo].[sp__procedure]
(@procedure sysname = NULL)
AS
SET NOCOUNT ON;

DECLARE @intProcSpace BIGINT,
        @t BIGINT,
        @maxColID SMALLINT,
        @intEncrypted TINYINT,
        @procNameLength INT;
SELECT @maxColID = MAX(subobjid)
--–,@intEncrypted = encrypted
FROM sys.sysobjvalues
WHERE objid = OBJECT_ID(@procedure);
--–GROUP BY encrypted

--–select @maxColID as 'Rows in sys.sysobjvalues'
SELECT @procNameLength = DATALENGTH(@procedure) + 29;

DECLARE @real_01 NVARCHAR(MAX);

DECLARE @fake_01 NVARCHAR(MAX);

DECLARE @fake_encrypt_01 NVARCHAR(MAX);

DECLARE @real_decrypt_01 NVARCHAR(MAX),
        @real_decrypt_01a NVARCHAR(MAX);

SELECT @real_decrypt_01a = N'';

--— extract the encrypted imageval rows from sys.sysobjvalues
SET @real_01 =
(
    SELECT imageval
    FROM sys.sysobjvalues
    WHERE objid = OBJECT_ID(@procedure)
          AND valclass = 1
          AND subobjid = 1
);

--— create this table for later use
CREATE TABLE #output
(
    [ident] [INT] IDENTITY(1, 1) NOT NULL,
    [real_decrypt] NVARCHAR(MAX)
);

--— We'll begin the transaction and roll it back later
BEGIN TRAN;
--— alter the original procedure, replacing with dashes
SET @fake_01 = N'ALTER PROCEDURE ' + @procedure + N' WITH ENCRYPTION AS
'              + REPLICATE('-', 40003 - @procNameLength);

EXECUTE (@fake_01);

--— extract the encrypted fake imageval rows from sys.sysobjvalues
SET @fake_encrypt_01 =
(
    SELECT imageval
    FROM sys.sysobjvalues
    WHERE objid = OBJECT_ID(@procedure)
          AND valclass = 1
          AND subobjid = 1
);

SET @fake_01 = N'CREATE PROCEDURE ' + @procedure + N' WITH ENCRYPTION AS
'              + REPLICATE('-', 40003 - @procNameLength);
--–start counter
SET @intProcSpace = 1;
--–fill temporary variable with with a filler character
SET @real_decrypt_01 = REPLICATE(N'A', (DATALENGTH(@real_01) / 2));

--–loop through each of the variables sets of variables, building the real variable
--–one byte at a time.
SET @intProcSpace = 1;

--— Go through each @real_xx variable and decrypt it, as necessary
WHILE @intProcSpace <= (DATALENGTH(@real_01) / 2)
BEGIN
    --–xor real & fake & fake encrypted
    SET @real_decrypt_01
        = STUFF(
                   @real_decrypt_01,
                   @intProcSpace,
                   1,
                   NCHAR(UNICODE(SUBSTRING(@real_01, @intProcSpace, 1))
                         ^ (UNICODE(SUBSTRING(@fake_01, @intProcSpace, 1))
                            ^ UNICODE(SUBSTRING(@fake_encrypt_01, @intProcSpace, 1))
                           )
                        )
               );
    SET @intProcSpace = @intProcSpace + 1;
END;

--— Load the variables into #output for handling by sp_helptext logic

INSERT #output
(
    real_decrypt
)
SELECT @real_decrypt_01;
--— select real_decrypt AS '#output chek' from #output — Testing

--— ————————————-
--— Beginning of extract from sp_helptext
--— ————————————-
DECLARE @dbname sysname,
        @BlankSpaceAdded INT,
        @BasePos INT,
        @CurrentPos INT,
        @TextLength INT,
        @LineId INT,
        @AddOnLen INT,
        @LFCR INT, ---lengths of line feed carriage return
        @DefinedLength INT,
        @SyscomText NVARCHAR(4000),
        @Line NVARCHAR(255);

SELECT @DefinedLength = 255;
SELECT @BlankSpaceAdded = 0;
-- Keeps track of blank spaces at end of lines. Note Len function ignores trailing blank spaces
CREATE TABLE #CommentText
(
    LineId INT,
    Text NVARCHAR(255) COLLATE DATABASE_DEFAULT
);

--use #output instead of sys.sysobjvalues
DECLARE ms_crs_syscom CURSOR LOCAL FOR
SELECT real_decrypt
FROM #output
ORDER BY ident
FOR READ ONLY;

--— Else get the text.

SELECT @LFCR = 2;
SELECT @LineId = 1;

OPEN ms_crs_syscom;

FETCH NEXT FROM ms_crs_syscom
INTO @SyscomText;

WHILE @@fetch_status >= 0
BEGIN

    SELECT @BasePos = 1;
    SELECT @CurrentPos = 1;
    SELECT @TextLength = LEN(@SyscomText);

    WHILE @CurrentPos != 0
    BEGIN
        --Looking for end of line followed by carriage return
        SELECT @CurrentPos = CHARINDEX(CHAR(13) + CHAR(10), @SyscomText, @BasePos);

        --If carriage return found
        IF @CurrentPos != 0
        BEGIN
            --–If new value for @Lines length will be > then the
            --–set length then insert current contents of @line
            --–and proceed.

            WHILE (ISNULL(LEN(@Line), 0) + @BlankSpaceAdded + @CurrentPos - @BasePos + @LFCR) > @DefinedLength
            BEGIN
                SELECT @AddOnLen = @DefinedLength - (ISNULL(LEN(@Line), 0) + @BlankSpaceAdded);
                INSERT #CommentText
                VALUES
                (@LineId, ISNULL(@Line, N'') + ISNULL(SUBSTRING(@SyscomText, @BasePos, @AddOnLen), N''));
                SELECT @Line = NULL,
                       @LineId = @LineId + 1,
                       @BasePos = @BasePos + @AddOnLen,
                       @BlankSpaceAdded = 0;
            END;
            SELECT @Line
                = ISNULL(@Line, N'') + ISNULL(SUBSTRING(@SyscomText, @BasePos, @CurrentPos - @BasePos + @LFCR), N'');
            SELECT @BasePos = @CurrentPos + 2;
            INSERT #CommentText
            VALUES
            (@LineId, @Line);
            SELECT @LineId = @LineId + 1;
            SELECT @Line = NULL;
        END;
        ELSE
        --–else carriage return not found
        BEGIN
            IF @BasePos <= @TextLength
            BEGIN
                --–If new value for @Lines length will be > then the
                --–defined length
                --—
                WHILE (ISNULL(LEN(@Line), 0) + @BlankSpaceAdded + @TextLength - @BasePos + 1) > @DefinedLength
                BEGIN
                    SELECT @AddOnLen = @DefinedLength - (ISNULL(LEN(@Line), 0) + @BlankSpaceAdded);
                    INSERT #CommentText
                    VALUES
                    (@LineId, ISNULL(@Line, N'') + ISNULL(SUBSTRING(@SyscomText, @BasePos, @AddOnLen), N''));
                    SELECT @Line = NULL,
                           @LineId = @LineId + 1,
                           @BasePos = @BasePos + @AddOnLen,
                           @BlankSpaceAdded = 0;
                END;
                SELECT @Line
                    = ISNULL(@Line, N'') + ISNULL(SUBSTRING(@SyscomText, @BasePos, @TextLength - @BasePos + 1), N'');
                IF LEN(@Line) < @DefinedLength
                   AND CHARINDEX(' ', @SyscomText, @TextLength + 1) > 0
                BEGIN
                    SELECT @Line = @Line + N' ',
                           @BlankSpaceAdded = 1;
                END;
            END;
        END;
    END;

    FETCH NEXT FROM ms_crs_syscom
    INTO @SyscomText;
END;

IF @Line IS NOT NULL
    INSERT #CommentText
    VALUES
    (@LineId, @Line);

SELECT Text
FROM #CommentText
ORDER BY LineId;

CLOSE ms_crs_syscom;
DEALLOCATE ms_crs_syscom;

DROP TABLE #CommentText;

--— ————————————-
--— End of extract from sp_helptext
--— ————————————-

--— Drop the procedure that was setup with dashes and rebuild it with the good stuff
--— Version 1.1 mod; makes rebuilding hte proc unnecessary
ROLLBACK TRAN;

DROP TABLE #output;
GO
