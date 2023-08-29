USE [ReportServer]
GO


SELECT
    Schedule.ScheduleID as SQLAgent_Job_Name, 
    Subscriptions.Description as sub_desc, 
    Subscriptions.DeliveryExtension as sub_delExt, 
    [Catalog].Name as reportname, [catalog].path as reportpath
    from reportschedule inner join Schedule 
        on ReportSchedule.ScheduleID = Schedule.ScheduleID 
    inner join Subscriptions 
        on ReportSchedule.SubscriptionID = Subscriptions.SubscriptionID 
    inner join [Catalog] 
        on ReportSchedule.ReportID = [Catalog].ItemID 
        and Subscriptions.Report_OID = [Catalog].ItemID;