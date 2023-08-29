CREATE OR ALTER FUNCTION [dbo].[ufnRemoveAllNonAlphaNum](@Input NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS 
BEGIN
DECLARE 
        @Output             NVARCHAR(MAX)
      , @LeftTrim           NVARCHAR(MAX)
      , @RightTrim          NVARCHAR(MAX)
      , @i                  BIGINT

SET @i = 1
WHILE @i <= LEN(@Input)
BEGIN
    IF  (SUBSTRING(@Input, @i, 1)COLLATE Latin1_General_CI_AI LIKE '%[a-z0-9]%')
    BEGIN
		/* PRINT(CONCAT('Printable char found: ', SUBSTRING(@Input, @i, 1), ' - appending it to: ', @Output)) */
		SET @Output = CONCAT(@Output, SUBSTRING(@Input, @i, 1))
	END    
    SET @i = @i + 1
END
RETURN  @Output
END;
GO


