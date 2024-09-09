DECLARE @DateTimeUTC DATETIME = GETUTCDATE();
WITH [tz]
AS (SELECT [UTC]    = @DateTimeUTC
         , [EUST]   = CONVERT(SMALLDATETIME, (@DateTimeUTC AT TIME ZONE 'UTC') AT TIME ZONE 'Central Europe Standard Time')
         , [GMT]    = CONVERT(SMALLDATETIME, (@DateTimeUTC AT TIME ZONE 'UTC') AT TIME ZONE 'GMT Standard Time'           )
         , [US_Est] = CONVERT(SMALLDATETIME, (@DateTimeUTC AT TIME ZONE 'UTC') AT TIME ZONE 'Eastern Standard Time'       )
         , [US_Cst] = CONVERT(SMALLDATETIME, (@DateTimeUTC AT TIME ZONE 'UTC') AT TIME ZONE 'Central Standard Time'       )
         , [US_Mst] = CONVERT(SMALLDATETIME, (@DateTimeUTC AT TIME ZONE 'UTC') AT TIME ZONE 'Mountain Standard Time'      )
         , [US_Pst] = CONVERT(SMALLDATETIME, (@DateTimeUTC AT TIME ZONE 'UTC') AT TIME ZONE 'Pacific Standard Time')      )
SELECT [tz].[UTC]
     , [tz].[EUST]
     , DATEDIFF(HOUR, [tz].[UTC], [tz].[EUST]) AS [Diff]
     , [tz].[GMT]
     , DATEDIFF(HOUR, [tz].[UTC], [tz].[GMT]) AS [Diff]
     , [tz].[US_Est]
     , DATEDIFF(HOUR, [tz].[UTC], [tz].[US_Est]) AS [Diff]
     , [tz].[US_Cst]
     , DATEDIFF(HOUR, [tz].[UTC], [tz].[US_Cst]) AS [Diff]
     , [tz].[US_Mst]
     , DATEDIFF(HOUR, [tz].[UTC], [tz].[US_Mst]) AS [Diff]
     , [tz].[US_Pst]
     , DATEDIFF(HOUR, [tz].[UTC], [tz].[US_Pst]) AS [Diff]
FROM [tz];

DECLARE 
  @DateTimeUTC2 DATETIME = '2024-08-13 15:22:46' --> 2024-08-13 08:22:52 (#25)
, @DateTimeUTC3 DATETIME = '2024-08-14 02:57:17' --> 2024-08-13 19:57:05 (#7) victim @spid = 212 (winner: 262) 

WITH [tz]
AS (SELECT [UTC]    = @DateTimeUTC2
         , [EUST]   = CONVERT(SMALLDATETIME, (@DateTimeUTC2 AT TIME ZONE 'UTC') AT TIME ZONE 'Central Europe Standard Time')
         , [GMT]    = CONVERT(SMALLDATETIME, (@DateTimeUTC2 AT TIME ZONE 'UTC') AT TIME ZONE 'GMT Standard Time'           )
         , [US_Est] = CONVERT(SMALLDATETIME, (@DateTimeUTC2 AT TIME ZONE 'UTC') AT TIME ZONE 'Eastern Standard Time'       )
         , [US_Cst] = CONVERT(SMALLDATETIME, (@DateTimeUTC2 AT TIME ZONE 'UTC') AT TIME ZONE 'Central Standard Time'       )
         , [US_Mst] = CONVERT(SMALLDATETIME, (@DateTimeUTC2 AT TIME ZONE 'UTC') AT TIME ZONE 'Mountain Standard Time'      )
         , [US_Pst] = CONVERT(SMALLDATETIME, (@DateTimeUTC2 AT TIME ZONE 'UTC') AT TIME ZONE 'Pacific Standard Time'       )

    UNION ALL 

    SELECT [UTC]    = @DateTimeUTC3
         , [EUST]   = CONVERT(SMALLDATETIME, (@DateTimeUTC3 AT TIME ZONE 'UTC') AT TIME ZONE 'Central Europe Standard Time')
         , [GMT]    = CONVERT(SMALLDATETIME, (@DateTimeUTC3 AT TIME ZONE 'UTC') AT TIME ZONE 'GMT Standard Time'           )
         , [US_Est] = CONVERT(SMALLDATETIME, (@DateTimeUTC3 AT TIME ZONE 'UTC') AT TIME ZONE 'Eastern Standard Time'       )
         , [US_Cst] = CONVERT(SMALLDATETIME, (@DateTimeUTC3 AT TIME ZONE 'UTC') AT TIME ZONE 'Central Standard Time'       )
         , [US_Mst] = CONVERT(SMALLDATETIME, (@DateTimeUTC3 AT TIME ZONE 'UTC') AT TIME ZONE 'Mountain Standard Time'      )
         , [US_Pst] = CONVERT(SMALLDATETIME, (@DateTimeUTC3 AT TIME ZONE 'UTC') AT TIME ZONE 'Pacific Standard Time'       )
         
         )
SELECT [tz].[UTC]
     , [tz].[EUST]
     , DATEDIFF(HOUR, [tz].[UTC], [tz].[EUST]) AS [Diff]
     , [tz].[GMT]
     , DATEDIFF(HOUR, [tz].[UTC], [tz].[GMT]) AS [Diff]
     , [tz].[US_Est]
     , DATEDIFF(HOUR, [tz].[UTC], [tz].[US_Est]) AS [Diff]
     , [tz].[US_Cst]
     , DATEDIFF(HOUR, [tz].[UTC], [tz].[US_Cst]) AS [Diff]
     , [tz].[US_Mst]
     , DATEDIFF(HOUR, [tz].[UTC], [tz].[US_Mst]) AS [Diff]
     , [tz].[US_Pst]
     , DATEDIFF(HOUR, [tz].[UTC], [tz].[US_Pst]) AS [Diff]
FROM [tz];


