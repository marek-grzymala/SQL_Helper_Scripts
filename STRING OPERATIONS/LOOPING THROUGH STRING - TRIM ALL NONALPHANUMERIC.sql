DECLARE @Input              NVARCHAR(MAX)
      , @Output             NVARCHAR(MAX)
      , @LeftTrim           NVARCHAR(MAX)
      , @RightTrim          NVARCHAR(MAX)
      , @i                  BIGINT
      , @FirstAlphaNumFound BIT = 0

SET @Input = N'

§

Test 1 
test 2
test 3
test 4

§

'
SET @i = 1
SET @FirstAlphaNumFound = 0
WHILE @i <= LEN(@Input)
BEGIN

    IF  (SUBSTRING(@Input, @i, 1)COLLATE Latin1_General_CI_AI NOT LIKE '%[a-z0-9]%')
    AND @FirstAlphaNumFound = 0
    BEGIN
        SET @FirstAlphaNumFound = 0 /* do nothing, no printable chrachters so far */
    END
    ELSE
    BEGIN
        SET @FirstAlphaNumFound = 1
        SET @LeftTrim = CONCAT(@LeftTrim, SUBSTRING(@Input, @i, 1))
    END
    SET @i = @i + 1
END

SET @i = LEN(@LeftTrim)
SET @RightTrim = @LeftTrim
SET @FirstAlphaNumFound = 0
WHILE @i > 0
BEGIN
    IF  (SUBSTRING(@LeftTrim, @i, 1)COLLATE Latin1_General_CI_AI NOT LIKE '%[a-z0-9]%')
    AND @FirstAlphaNumFound = 0
    BEGIN
        SET @RightTrim = STUFF(@RightTrim, @i, 1, '')
    END
    ELSE
    BEGIN
        SET @FirstAlphaNumFound = 1
    END
    SET @i = @i - 1
END
SELECT @Output = @RightTrim
SELECT @Output
