/* 
DO NOT REPLACE STRING PATTERN WITH A VARIABLE: !!!

THE FOLLOWING WON'T WORK OR WILL WORK INCORRECTLY FOR SOME CHARCTERS (LIKE '�' WILL REPLACE 'th' in 'Smith'):

UPDATE      t
SET         t.[name] = REPLACE(t.[ColumnName], @StringPatternToBeRemoved, '')

FROM        [DBName].[dbo].[TableName] t
WHERE       PATINDEX('%'+@StringPatternToBeRemoved+'%', t.[ColumnName]) <> 0 

*/


SELECT      --DISTINCT
            t.[ColumnName],
            REPLACE(t.[ColumnName], '�', '') AS [ColumnAfterReplacement]

--UPDATE      t
--SET         t.[ColumnName] = REPLACE(t.[ColumnName], '�', '')
FROM        [DBName].[dbo].[TableName] t
WHERE       PATINDEX('%�%', t.[ColumnName]) <> 0 