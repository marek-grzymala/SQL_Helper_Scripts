;WITH event_data AS 
(
  SELECT data = CONVERT(XML, event_data)
    FROM sys.fn_xe_file_target_read_file(
   'T:\XTENDED_EVENT_LOGS\FailedLogins*.xel', 
   'T:\XTENDED_EVENT_LOGS\FailedLogins*.xem', 
   NULL, NULL
 )
),
tabular AS
(
  SELECT 
    [host] = data.value('(event/action[@name="client_hostname"]/value)[1]','nvarchar(4000)'),
    [app] = data.value('(event/action[@name="client_app_name"]/value)[1]','nvarchar(4000)'),
    [date/time] = data.value('(event/@timestamp)[1]','datetime2'),
    [error] = data.value('(event/data[@name="error_number"]/value)[1]','int'),
    [state] = data.value('(event/data[@name="state"]/value)[1]','tinyint'),
    [message] = data.value('(event/data[@name="message"]/value)[1]','nvarchar(250)')
  FROM event_data
)
SELECT [host],[app],[state],[message],[date/time]
  FROM tabular
  WHERE error = 18456 
  ORDER BY [date/time] DESC;