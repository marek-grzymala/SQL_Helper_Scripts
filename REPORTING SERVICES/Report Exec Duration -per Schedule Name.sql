DECLARE @ScheduleName VARCHAR(150)
SET @ScheduleName = 'YourShceduleName'

SELECT      DISTINCT 
            b.name AS Reportname,
            b.schedulename,
            a.Status,
            a.TimeStart,
            a.TimeEnd,
            a.TimeDataRetrieval,
            a.TimeProcessing,
            a.TimeRendering,
            (DATEDIFF(ss,a.TimeStart, a.TimeEnd)/60) AS DurationInMin
--INTO        #temp
FROM        dbo.ExecutionLog AS a
INNER JOIN (
            SELECT  rs.ReportID,
                    c.Name,
                    s.Name AS schedulename
            FROM    ReportSchedule rs
            JOIN    Schedule s
            ON      rs.ScheduleID     = s.ScheduleID
            JOIN    Subscriptions sub
            ON      rs.SubscriptionID = sub.SubscriptionID
            JOIN    Catalog c
            ON      rs.ReportID       = c.ItemID
            --- WHERE rs.ScheduleID = '24229820-CF65-40D1-8DC5-7E54A903581D'
           ) AS b
ON         a.ReportID       = b.ReportID
WHERE      a.UserName       = 'DOMAIN\RSAccountName' 
AND        a.Format         = 'PDF' 
AND        a.TimeStart      >= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0) 
AND        b.schedulename   = @ScheduleName 
AND        a.Status         = 'rsSuccess'
ORDER BY   Reportname,  a.TimeStart DESC