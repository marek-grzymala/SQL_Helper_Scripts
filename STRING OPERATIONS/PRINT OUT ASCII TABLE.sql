SET NOCOUNT ON

DECLARE @ASCIITable TABLE 
       (AsciiChar nvarchar(2), CharNum int)
DECLARE @CNT INT
DECLARE @NonStandardChars NVARCHAR(20);
DECLARE @AllowedRangeOfChars NVARCHAR(256);
DECLARE @AllowedRangeOfChars2 NVARCHAR(256);
SET @CNT = 32

SET @NonStandardChars = N'[^ -~�-��-��-�]';
SET @AllowedRangeOfChars = CONCAT(N'[^', ' -~', '�-�', '�-�', '�-�', ']');
SET @AllowedRangeOfChars2 = CONCAT(N'%[^', 'a-zA-Z0-9<->', ' -~�-��-��-�', CHAR(39), CHAR(43), CHAR(45), ']%');


WHILE @CNT <= 255 --125
BEGIN
       INSERT INTO @ASCIITable
       SELECT CHAR(@CNT), @CNT
       SET @CNT = @CNT + 1
END

/* Print out ASCII Table: */
; WITH cte AS (
SELECT 
            CharNum
           ,AsciiChar
           --,[dbo].[fnRegExpressionReplace](AsciiChar, @NonStandardChars, '#')    AS [fnReplaceValue]
           --,[dbo].[fnRegExpressionReplace](AsciiChar, @AllowedRangeOfChars, '#') AS [fnReplaceValue2]
           --,[dbo].[fnReplaceInvalidChars](AsciiChar, @AllowedRangeOfChars2)      AS [fnReplaceValue3]

FROM        @ASCIITable
--WHERE       PATINDEX('[^ -~�-��-��-�]', [AsciiChar] COLLATE Latin1_General_CI_AS) = 0
)
SELECT * FROM cte 
--WHERE ([fnReplaceValue] <> '#' AND [fnReplaceValue2] <> '#') --AND [fnReplaceValue3] = '#'

/* Print out random characters: */
/*
DECLARE  
       @Upper INT = 256,
       @Lower INT = 32,
       @RndInt INT

SELECT CHAR(ROUND(((@Upper - @Lower - 1) * RAND() + @Lower), 0)) AS [RandomCharacter]
*/