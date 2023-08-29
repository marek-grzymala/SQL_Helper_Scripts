/* more reliable version: */
CREATE OR ALTER FUNCTION [dbo].[fnReplaceInvalidChars] (
     @InputString     VARCHAR(MAX)
    ,@CharsToRemove   VARCHAR(500)
    ,@ReplacementChar CHAR(1)
    )
RETURNS VARCHAR(MAX)
AS
BEGIN
    DECLARE  @len     INT
            ,@i       INT
            ,@OneChar CHAR(1)

    SET @i = 1
    SET @len = LEN(@InputString);
    WHILE (@i <= @len)
    BEGIN
        SET @OneChar = SUBSTRING(@InputString, @i, 1)        
        IF CHARINDEX(@OneChar COLLATE Latin1_General_CS_AS, @CharsToRemove COLLATE Latin1_General_CS_AS) > 0
        BEGIN
            SET @InputString = REPLACE(@InputString COLLATE Latin1_General_CS_AS, @OneChar COLLATE Latin1_General_CS_AS, @ReplacementChar)
        END
        SET @i = @i + 1
    END
    RETURN @InputString
END

/* unreliable version: */
/*
CREATE OR ALTER FUNCTION [dbo].[fnReplaceInvalidChars] 
(
      @input NVARCHAR(MAX)
    , @AllowedChars NVARCHAR(256)
    , @ReplacementChar CHAR(1)
)
/*
Replaces anything that is not '^' on the @AllowedChars:
Example of Parameter definition:
SET @AllowedChars = CONCAT(N'[^', 'a-zA-Z0-9<->', ' -~', CHAR(39), CHAR(43), CHAR(45), ']');
*/
RETURNS NVARCHAR(MAX)
BEGIN
    DECLARE @output VARCHAR(MAX) = @input;       
    WHILE PATINDEX(@AllowedChars, @output) > 0
    BEGIN
        SELECT @output = STUFF(@output, PATINDEX(@AllowedChars, @output), 1, @ReplacementChar); 
    END  
    RETURN @output
END
*/