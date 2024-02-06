DECLARE 
        @input NVARCHAR(MAX), 
        @LineSeparator CHAR(1) = ',',
        @i INT,
        @j INT

SET @input = 'Test 1,test 2, Test 3, test 123'
DECLARE @OutputTable TABLE ([Id] INT IDENTITY(1,1), [LineOfText] NVARCHAR(MAX) NOT NULL)

SET @i = 1
SET @j = 1
WHILE @i <= LEN(@input)
BEGIN 
     IF (SUBSTRING(@input, @i+1, 1) = @LineSeparator)
	 BEGIN
		PRINT(CONCAT('@LineSeparator found at: ', @i))
		SET @i = @i + 1
		PRINT(CONCAT('@i = ', @i, ' @j = ', @j, ' SUBSTRING: ', SUBSTRING(@input, @j, @i-@j)))
        INSERT INTO @OutputTable
        (
            LineOfText
        )
        VALUES
        (
           TRIM(SUBSTRING(@input, @j, @i-@j))
        )
		SET @j = @i + 1
	 END
     SET @i = @i + 1
	 /* append any leftover characters: */
	 IF (@i = LEN(@input))
	 BEGIN
        INSERT INTO @OutputTable
        (
            LineOfText
        )
        VALUES
        (
           TRIM(SUBSTRING(@input, @j, @i-@j+1))
        )     
	 END
END
SELECT * FROM @OutputTable AS [t]