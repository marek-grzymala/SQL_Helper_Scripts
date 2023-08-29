SET NOCOUNT ON

DECLARE @ASCIITable TABLE (AsciiChar nvarchar(2), CharNum int)
DECLARE
  @counter INT
, @NonStandardChars NVARCHAR(20)
, @AllowedRangeOfChars1 NVARCHAR(256)
, @AllowedRangeOfChars2 NVARCHAR(256)
, @ReplacementChar CHAR(1) = '#'

SET @counter = 32

SET @NonStandardChars = N'[^ -~À-ÖØ-öø-ÿ]';
SET @AllowedRangeOfChars1 = CONCAT(N'[^', '0-9A-Za-z<->', ' -~', 'Ÿ', 'À-Ö', 'Ø-ö', 'ø-ÿ', CHAR(160), ']');
SET @AllowedRangeOfChars2 = CONCAT(N'[^', '-+', CHAR(39), CHAR(160), '0-9A-Za-z<->', ' -~', ']');

DECLARE @InvalidChars VARCHAR(256)
SET @InvalidChars = '€‚ƒ„…†‡ˆ‰Š‹ŒŽ‘’“”•–—˜™š›œžŸ¡¢£¤¥¦§¨©ª«¬­®¯°±²³´µ¶·¸¹º»¼½¾¿×÷';

SET @counter = 32
WHILE @counter <= 255 --125
BEGIN
       INSERT INTO @ASCIITable
       SELECT CHAR(@counter), @counter
       SET @counter = @counter + 1
END

/* Print out ASCII Table: */
; WITH cte AS (
SELECT 
            CharNum
           ,AsciiChar                                                                          AS [OriginalAscii]
           --,[dbo].[fnRegExpressionReplace](AsciiChar, @NonStandardChars,     @ReplacementChar) AS [fnReplaceValue]
           --,[dbo].[fnRegExpressionReplace](AsciiChar, @AllowedRangeOfChars1, @ReplacementChar) AS [fnReplaceValue1]
           --,[dbo].[ReplaceInvalidChars](AsciiChar,  @InvalidChars, @ReplacementChar)                   AS [fnReplaceValue2]
FROM        @ASCIITable
)
SELECT * FROM cte 
--WHERE (([fnReplaceValue] <> '#' AND [fnReplaceValue1] <> '#') AND [fnReplaceValue2] = '#')
--OR    (([fnReplaceValue] = '#' OR [fnReplaceValue1] = '#') AND [fnReplaceValue2] <> '#')


--DECLARE @InvalidChars VARCHAR(256)
--SET @InvalidChars = '€‚ƒ„…†‡ˆ‰Š‹ŒŽ‘’“”•–—˜™š›œžŸ¡¢£¤¥¦§¨©ª«¬­®¯°±²³´µ¶·¸¹º»¼½¾¿×÷';
--SELECT [dbo].[ReplaceInvalidChars]('¥¦This§²³is¹a€•–—test¶of™replacingŸinvalid†characters !%_Ž',  @InvalidChars, ' ')




