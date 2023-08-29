DECLARE @MachineName NVARCHAR(256)

SELECT @MachineName = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(256))
--SELECT @MachineName

SELECT
	c.session_id
	, s.login_name
	, c.client_net_address
	, s.host_name
	, c.local_tcp_port
	, c.auth_scheme
    , c.net_transport

FROM sys.dm_exec_connections AS c
INNER JOIN sys.dm_exec_sessions s ON s.session_id = c.session_id
WHERE       1 = 1 
--AND         c.auth_scheme IN ('KERBEROS', 'NTLM') 
AND         s.host_name <> @MachineName --  we do not care about the locally logged in sessions
--AND         s.login_name NOT IN ( 'DOMAIN\user' )

SELECT 
	        c.auth_scheme AS [AuthenticationScheme]
	        ,COUNT(c.auth_scheme) AS [SessionCount]
FROM        sys.dm_exec_connections AS c
INNER JOIN  sys.dm_exec_sessions s ON s.session_id = c.session_id
WHERE       1 = 1 
--AND         c.auth_scheme IN ('KERBEROS', 'NTLM') 
AND         s.host_name <> @MachineName --  we do not care about the locally logged in sessions
--AND         s.login_name NOT IN ( 'DOMAIN\user' )
GROUP BY    c.auth_scheme