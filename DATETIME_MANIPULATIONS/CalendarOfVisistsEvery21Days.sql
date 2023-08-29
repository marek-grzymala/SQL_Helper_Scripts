DECLARE @start DATETIME = GETDATE()
DECLARE @end DATETIME = DATEADD(MONTH, 12, @start)
DECLARE @day_interval INT = 21;

; WITH [VisitCalendar] ([day])
AS (SELECT @start AS [day] UNION ALL SELECT [day] + @day_interval FROM [VisitCalendar] WHERE [day] < @end)
SELECT ROW_NUMBER() OVER (ORDER BY [day]) AS [Rn]
     , CAST([day] AS DATE) AS [VisitDate]
     , DATENAME(DW, [day]) AS [WeekDay]
FROM [VisitCalendar]
GROUP BY [day]