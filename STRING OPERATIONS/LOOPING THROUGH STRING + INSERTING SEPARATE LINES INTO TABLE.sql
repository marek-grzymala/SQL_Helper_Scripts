SET NOCOUNT ON

DECLARE 
        @input NVARCHAR(MAX), 
        @output NVARCHAR(MAX),
        @TempOutput NVARCHAR(MAX) = '',
        @FillerChar NCHAR(1) = '¶',
        @LineSeparator CHAR(1) = CHAR(13),
        @i BIGINT,
        @j BIGINT

DECLARE @Table TABLE 
                (
                 --[Id] BIGINT IDENTITY(1,1), 
                 [LineOfText] NVARCHAR(MAX)
                )

SET @input = 'Test 1A
              Test 2B
              Test3
              blah blah 4D
              srutu ''tuttu
              ''''        dupa z drutu
              E
             '

SET @i = 1
SET @j = 0

WHILE @i <= LEN(@input)
BEGIN
     
     SET @output = CONCAT(@output, @FillerChar)
     SET @i = @i + 1
END

SET @i = 1
WHILE @i <= LEN(@input)
BEGIN
     --SET @output = STUFF(@output, @i, 1, SUBSTRING(@input, @i, 1))
     
     IF (SUBSTRING(@input, @i+1, 1) = @LineSeparator)
     BEGIN
        PRINT(SUBSTRING(@input, @j+LEN(@LineSeparator), (@i-@j)))
        INSERT INTO @Table
        (
            LineOfText
        )
        VALUES
        (
           SUBSTRING(@input, @j+LEN(@LineSeparator), (@i-@j))
        )
        SET @j = @i
     END

     SET @i = @i + 1
END


SELECT * FROM @Table

