; WITH cte  AS (
SELECT      DISTINCT
            so.[id],
            so.[type]
FROM        sys.sysobjects  so
INNER JOIN  sys.syscomments sc ON so.id = sc.id
WHERE       sc.[encrypted] = 1
)
SELECT  
         CASE cte.[type]
            WHEN 'P'       THEN 'PROCEDURE'
            WHEN 'V'       THEN 'VIEW'
            WHEN 'FN'      THEN 'FUNCTION'
            WHEN 'IF'      THEN 'TABLE-VALUED FUNCTION'
            WHEN 'TR'      THEN 'TRIGGER'
            ELSE cte.[type]
         END               AS [ObjectType], 
         COUNT(cte.[type]) AS [CountPerType]
FROM     cte
GROUP BY cte.[type]
ORDER BY [CountPerType] DESC
