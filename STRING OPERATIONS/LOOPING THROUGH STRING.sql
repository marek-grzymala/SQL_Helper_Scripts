DECLARE 
        @input NVARCHAR(MAX), 
        @output NVARCHAR(MAX),
        @TempOutput NVARCHAR(MAX) = ' ',
        @FillerChar NCHAR(1) = '§',
        @LineSeparator CHAR(2) = CHAR(13),
        @i BIGINT,
        @j BIGINT

DECLARE @Table TABLE ([Id] INT IDENTITY(1,1), [LineOfText] NVARCHAR(MAX))

SET @input = '
Test 1 
test 2
test 3
test 4
'

SET @i = 1
SET @j = 1

WHILE @i <= LEN(@input)
BEGIN
     
     SET @output = CONCAT(@output, @FillerChar)
     SET @i = @i + 1
END

SET @i = 1
WHILE @i <= LEN(@input)
BEGIN
     
     SET @output = STUFF(@output, @i, 1, SUBSTRING(@input, @i, 1))
     
     IF (SUBSTRING(@input, @i+1, 1) = @LineSeparator)
     BEGIN
        PRINT(SUBSTRING(@output, 1, @i))
        INSERT INTO @Table
        (
            LineOfText
        )
        VALUES
        (
           SUBSTRING(@output, 1, @i)
        )
     END

     SET @i = @i + 1
END

SELECT * FROM @Table

