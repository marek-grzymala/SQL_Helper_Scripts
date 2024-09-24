DECLARE @input         NVARCHAR(MAX)
      , @LineSeparator CHAR(1) = ':';

SET @input = N'PAGE: 7:1:688256 ';
SELECT [value] AS [SubstringsSeparatedIntoRows] FROM STRING_SPLIT(@input, @LineSeparator)

-- Split the string into rows and assign row numbers
;
WITH [SplitInput]
AS (
    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [RowNum]
         , [value] AS [SubstringValue]
    FROM STRING_SPLIT(@input, @LineSeparator)
   )
-- Pivot each line into its respective column
SELECT MAX(CASE WHEN [SplitInput].[RowNum] = 2 THEN TRY_CONVERT(INT, [SplitInput].[SubstringValue]) END) AS [DbId]
     , MAX(CASE WHEN [SplitInput].[RowNum] = 3 THEN TRY_CONVERT(INT, [SplitInput].[SubstringValue]) END) AS [FileId]
     , MAX(CASE WHEN [SplitInput].[RowNum] = 4 THEN TRY_CONVERT(INT, [SplitInput].[SubstringValue]) END) AS [PageId]
FROM [SplitInput];
