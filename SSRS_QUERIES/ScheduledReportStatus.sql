USE [ReportServer]
GO

DECLARE @date DATE = GETDATE()

	;WITH cte_ReportsExecutionPrediction (
		ReportID
		, LastWeek80PercentileStartTimeAsSecondsOfTheDayUK
		, LastWeek80PercentileDuration
	) AS (
		SELECT DISTINCT 
				els.ReportID
				, PERCENTILE_DISC(0.8) WITHIN GROUP ( ORDER BY DATEDIFF(s, DATEADD(DAY, DATEDIFF(DAY, 0, els.TimeStart), 0), els.TimeStart) ASC ) OVER (PARTITION BY els.ReportID) AS LastWeek80PercentileStartTimeAsSecondsOfTheDayUK
				, PERCENTILE_DISC(0.8) WITHIN GROUP ( ORDER BY DATEDIFF(s, els.TimeStart, els.TimeEnd) ASC ) OVER (PARTITION BY els.ReportID) AS LastWeek80PercentileDuration
		FROM	ReportServer.dbo.ExecutionLogStorage AS els
		WHERE	1 = 1
				--AND els.TimeStart >= DATEADD(DAY, DATEDIFF(DAY, 7, GETDATE()), 0)
				--AND els.TimeStart < DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
				AND CONVERT(DATE, els.TimeStart) >= DATEADD(DAY, -7, @date)
				AND CONVERT(DATE, els.TimeStart) <= DATEADD(DAY, -1, @date)
				AND DATEDIFF(SS, DATEADD(DAY, DATEDIFF(DAY, 0, els.TimeStart), 0), els.TimeStart) < 43200
				AND els.Status = 'rsSuccess'
	)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	Identifing reports for particular schedules + logical structure of fields
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	, cte_ReportsScheduled (
		ReportID
		, ReportName
		--, ScheduleType
		, ScheduleName
		, StartTime
		, StartTimeUK
		, CompletionTime
		, CompletionTimeUK
		, LastWeek80PercentileStartTimeAsSecondsOfTheDayUK
		, LastWeek80PercentileDuration
		, Status
		, StatusCode
		, LastStatus
		, LastStatusCode
		, SubscriptionLastStatus
		, SubscriptionLastRunTime
		, ExecutionsCount
		, SucceededExecutionsCount
		, FailedExecutionsCount
		, RowNumber
	) AS (
		SELECT DISTINCT
				rs.ReportID
				, c.Name AS ReportName
				--, CASE 
				--	WHEN s.Name LIKE 'Regulatory%' THEN 'Regulatory'
				--	WHEN s.Name LIKE 'Operational%' THEN 'Operational'
				--	WHEN s.Name LIKE 'General%' THEN 'General'
				--	WHEN s.Name LIKE 'CubeReportingSchedule%' THEN 'CubeReports'
				--	WHEN s.Name LIKE 'HighPriorityReporting%' THEN 'HPR'
				--	ELSE 'Unkown'
				--END AS ScheduleType
				, s.Name AS ScheduleName
				, NULL AS StartTime 
				, NULL AS StartTimeUK
				, NULL AS CompletionTime
				, NULL AS CompletionTimeUK
				, cte_rep.LastWeek80PercentileStartTimeAsSecondsOfTheDayUK
				, cte_rep.LastWeek80PercentileDuration	
				, 'Pending' AS Status
				, 0 AS StatusCode
				, 'Pending' AS LastStatus
				, 0 AS LastStatusCode
				, sub.LastStatus AS SubscriptionLastStatus
				, sub.LastRunTime AS SubscriptionLastRunTime
				, 0 AS ExecutionsCount
				, 0 AS SucceededExecutionsCount
				, 0 AS FailedExecutionsCount
				, 1 AS RowNumber
		FROM	ReportServer.dbo.ReportSchedule (NOLOCK) AS rs 
		INNER JOIN ReportServer.dbo.Schedule (NOLOCK) AS s 
				ON rs.ScheduleID = s.ScheduleID
		INNER JOIN ReportServer.dbo.Subscriptions (NOLOCK) AS sub 
				ON rs.SubscriptionID = sub.SubscriptionID
		INNER JOIN ReportServer.dbo.Catalog (NOLOCK) AS c 
				ON rs.ReportID = c.ItemID
		LEFT JOIN  cte_ReportsExecutionPrediction cte_rep
				ON rs.ReportID = cte_rep.ReportID
		WHERE	1 = 1
				AND sub.InactiveFlags = 0
				/*
                AND (
					s.Name LIKE 'Regulatory%'
					OR s.Name LIKE 'Operational%'
					OR s.Name LIKE 'General%'
					OR s.Name LIKE 'CubeReportingSchedule%'
					OR s.Name LIKE 'HighPriorityReporting%'
				)
				AND (
					s.Name LIKE '%Daily%'
					OR s.Name = 'HighPriorityReporting'
					OR (s.Name = 'HighPriorityReporting_weekly' AND DATENAME(WEEKDAY, @date) = 'Monday')
					OR (s.Name LIKE '%Weekly - Monday%' AND DATENAME(WEEKDAY, @date) = 'Monday')
					OR (s.Name LIKE '%Weekly - Thursday%' AND DATENAME(WEEKDAY, @date) = 'Thursday')
					OR (s.Name LIKE '%Weekly - Wednesday%' AND DATENAME(WEEKDAY,@date) = 'Wednesday')
					OR (s.Name LIKE '%Weekly - Saturday%' AND DATENAME(WEEKDAY, @date) = 'Saturday')
					OR (s.Name LIKE '%Monthly - 01%' AND DAY(@date) = 1 )
					OR (s.Name LIKE '%Monthly - 15%' AND DAY(@date) = 15 )
					OR (s.Name LIKE '%Quarterly%' AND DAY(@date) = 1 AND (MONTH(@date) = 1 OR MONTH(@date) = 4 OR MONTH(@date) = 7 OR MONTH(@date) = 10) )
					OR (s.Name LIKE '%Yearly%' AND MONTH(@date) = 1 AND DAY(@date) = 1  )
				)
                */
	)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	Selecting reports executed today and existing in schedule + logical structure of fields
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	, cte_ReportsExecutedToday (
		ReportID
		, ReportName
		--, ScheduleType
		, ScheduleName
		, StartTime
		, StartTimeUK
		, CompletionTime
		, CompletionTimeUK
		, LastWeek80PercentileStartTimeAsSecondsOfTheDayUK
		, LastWeek80PercentileDuration
		, Status
		, StatusCode
		, LastStatus
		, LastStatusCode
		, SubscriptionLastStatus
		, SubscriptionLastRunTime
		, ExecutionsCount
		, SucceededExecutionsCount
		, FailedExecutionsCount
		, RowNumber
	) AS (
		SELECT
				els.ReportID
				, cte_rs.ReportName
				--, cte_rs.ScheduleType
				, cte_rs.ScheduleName
				, els.TimeStart AS StartTime
				, els.TimeStart AT TIME ZONE 'GMT Standard Time' AS StartTimeUK
				, els.TimeEnd AS CompletionTime
				, els.TimeEnd AT TIME ZONE 'GMT Standard Time' AS CompletionTimeUK
				, cte_rs.LastWeek80PercentileStartTimeAsSecondsOfTheDayUK
				, cte_rs.LastWeek80PercentileDuration
				, CASE 
					WHEN els.Status = 'rsSuccess' THEN 'Delivered'
					ELSE 'Failed'
				  END AS Status
				, CASE 
					WHEN els.Status = 'rsSuccess' THEN 1
					ELSE -1
				  END AS StatusCode
				, LAST_VALUE(CASE 
					WHEN els.Status = 'rsSuccess' THEN 'Delivered'
					ELSE 'Failed'
				  END) OVER (PARTITION BY els.ReportID ORDER BY els.TimeEnd ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS LastStatus
				, LAST_VALUE(CASE 
					WHEN els.Status = 'rsSuccess' THEN 1
					ELSE -1
				  END) OVER (PARTITION BY els.ReportID ORDER BY els.TimeEnd ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS LastStatus
				, cte_rs.SubscriptionLastStatus
				, cte_rs.SubscriptionLastRunTime
				, COUNT(*) OVER (PARTITION BY els.ReportID) AS ExecutionsCount
				, SUM (CASE WHEN els.Status = 'rsSuccess' THEN 1 ELSE 0 END) OVER (PARTITION BY els.ReportID) AS SucceededExecutionsCount
				, SUM (CASE WHEN els.Status <> 'rsSuccess' THEN 1 ELSE 0 END) OVER (PARTITION BY els.ReportID) AS FailedExecutionsCount
				, ROW_NUMBER() OVER (PARTITION BY els.ReportID ORDER BY (CASE WHEN els.Status = 'rsSuccess' THEN 1 ELSE 0 END) DESC, els.TimeEnd DESC) AS RowNumber
		FROM	ReportServer.dbo.ExecutionLogStorage AS els (NOLOCK)
		INNER JOIN cte_ReportsScheduled AS cte_rs
				ON els.ReportID = cte_rs.ReportID
		WHERE	1 = 1
				AND els.ReportID IN (SELECT ReportID FROM cte_ReportsScheduled)
				--AND els.TimeStart >= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
				AND CONVERT(DATE, els.TimeStart) = @date
	)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--	Combining today's reports with scheduled (but not yet executed)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	SELECT 
			*
	FROM	cte_ReportsExecutedToday
	WHERE	1 = 1
			AND RowNumber = 1
	UNION ALL (
	SELECT 
			* 
	FROM	cte_ReportsScheduled
	WHERE	1 = 1
			--Selecting reports existing in schedule but not exectued today
			AND cte_ReportsScheduled.ReportID NOT IN (SELECT ReportID FROM cte_ReportsExecutedToday)
	)