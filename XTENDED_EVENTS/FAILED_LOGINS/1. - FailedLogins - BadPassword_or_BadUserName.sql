IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='FailedLoginsDemo')
    DROP EVENT SESSION [FailedLoginsDemo] ON SERVER;
CREATE EVENT SESSION [FailedLoginsDemo]
ON SERVER
ADD EVENT sqlserver.error_reported
 (
   ACTION 
   (
     sqlserver.client_app_name,
     sqlserver.client_hostname,
     sqlserver.sql_text,
	 sqlserver.username
    )
    WHERE severity = 14
      AND ( 
			state = 5 --Could not find a login matching the name provided
			OR state = 8 --Password did not match that for the login provided
	)	
)
ADD TARGET package0.asynchronous_file_target(
     SET filename='T:\XTENDED_EVENT_LOGS\FailedLoginsDemo.etl', metadatafile='T:\XTENDED_EVENT_LOGS\FailedLoginsDemo.mta')

ALTER EVENT SESSION [FailedLoginsDemo]
ON SERVER
STATE = START

;WITH event_data AS 
(
  SELECT 
		data = CONVERT(XML, event_data)  
  FROM sys.fn_xe_file_target_read_file('T:\XTENDED_EVENT_LOGS\FailedLoginsDemo*etl', 'T:\XTENDED_EVENT_LOGS\FailedLoginsDemo*mta', null, null)
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
  WHERE state IN (5, 8) 
  -- state 8: Login failed for user 'rfsmart'. Reason: Password did not match that for the login provided. [CLIENT: 10.191.13.207]
  -- state 5: Login failed for user 'dupa'. Reason: Could not find a login matching the name provided. [CLIENT: 10.191.13.207]
  ORDER BY [date/time] DESC;

ALTER EVENT SESSION [FailedLoginsDemo]
ON SERVER
STATE = STOP