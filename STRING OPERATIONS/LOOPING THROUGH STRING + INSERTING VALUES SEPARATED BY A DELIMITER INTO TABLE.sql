SET NOCOUNT ON;
DECLARE 
      @StringList VARCHAR(8000)
	, @delim CHAR(1)
	, @pos INT
	, @len INT
    , @arg_descr NVARCHAR(4000)    
	, @value VARCHAR(8000)
    , @count INT

DROP TABLE IF EXISTS [#TableFromStringList]CREATE TABLE [#TableFromStringList](	 [Id]           INT PRIMARY KEY CLUSTERED IDENTITY(1,1)
    ,[LineNo]       INT NOT NULL
	,[Description]  NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AI NOT NULL
	,[Value]        NVARCHAR(MAX) COLLATE SQL_Latin1_General_CP1_CI_AI NOT NULL
)

SET @StringList = 'Product;Employee;BusinessEntity;'
SET @delim = ';'
SET @pos = 0
SET @len = 0

SELECT @count = 1
SELECT @arg_descr = 'Arg' + CAST(@count AS NVARCHAR(3));

WHILE CHARINDEX(@delim, @StringList, @pos + 1) > 0
BEGIN
    SET @len = CHARINDEX(@delim, @StringList, @pos + 1) - @pos
    SET @value = SUBSTRING(@StringList, @pos, @len)
    --SELECT @pos, @len, @value /* this is for debugging */
        
	PRINT 'Adding argument: ' + @arg_descr + ' with Value: ' + @value
    INSERT INTO [#TableFromStringList] (
         [LineNo]     
        ,[Description]
        ,[Value]      
    )
    VALUES (
         @count
        ,@arg_descr
        ,@value
    )

    SET @pos = CHARINDEX(@delim, @StringList, @pos + @len) + 1
	SET @count = @count + 1
	SELECT @arg_descr = 'Arg' + CAST(@count AS NVARCHAR(3));
END

SELECT * FROM #TableFromStringList