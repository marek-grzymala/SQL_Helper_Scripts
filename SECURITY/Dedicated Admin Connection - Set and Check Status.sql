USE [master];
GO

sp_configure 'remote admin connections', 1;

SELECT *
FROM sys.configurations
WHERE value <> value_in_use;
--RECONFIGURE

SELECT CASE
           WHEN ses.session_id = @@SPID THEN
               'It''s me! '
           ELSE
               ''
       END + COALESCE(ses.login_name, '???') AS WhosGotTheDAC,
       ses.session_id,
       ses.login_time,
       ses.status,
       ses.original_login_name
FROM sys.endpoints AS en
    JOIN sys.dm_exec_sessions ses
        ON en.endpoint_id = ses.endpoint_id
WHERE en.name = 'Dedicated Admin Connection';