SET DATEFIRST 1 -- 1: Monday, 7: Sunday

declare 
    @DatFirst DATE = '20200101', 
    @DatLast DATE = GETDATE();

;WITH AllDays AS
(
    SELECT
        Dt = @DatFirst
    UNION ALL
    SELECT
        Dt = DATEADD(DAY, 1, D.Dt)
    FROM
        AllDays AS D
    WHERE
        D.Dt < @DatLast
),
BusinessLimitsByMonth AS
(
    SELECT
        Yr = YEAR(T.Dt),
        Mn = MONTH(T.Dt),
        FirstBusinessDay = MIN(T.Dt),
        LastBusinessDay = MAX(T.Dt)
    FROM
        AllDays AS T
    WHERE
        DATEPART(WEEKDAY, T.Dt) BETWEEN 1 AND 5 -- 1: Monday, 5: Friday
    GROUP BY
        YEAR(T.Dt),
        MONTH(T.Dt)
)
,CalendarLimitsByMonth AS
(
    SELECT
        Yr = YEAR(T.Dt),
        Mn = MONTH(T.Dt),
        FirstCalendarDay = MIN(T.Dt),
        LastCalendarDay = MAX(T.Dt)
    FROM
        AllDays AS T
    GROUP BY
        YEAR(T.Dt),
        MONTH(T.Dt)
)
SELECT
                B.Yr,
                B.Mn,
                C.FirstCalendarDay,
                B.FirstBusinessDay,
                B.LastBusinessDay,
                C.LastCalendarDay
FROM
                BusinessLimitsByMonth AS B
INNER JOIN      CalendarLimitsByMonth AS C
ON              B.Yr = C.Yr AND B.Mn = C.Mn
ORDER BY
    B.Yr,
    B.Mn
OPTION
    (MAXRECURSION 0) -- 0: Unlimited