USE [TestDb]
GO


SELECT     
            DB_NAME()               AS [DB_NAME]
           ,l.name                  AS [master_UserName]
           ,u.name                  AS [CurrentDB_UserName]
           ,l.sid                   AS [master_SID]
           ,u.sid                   AS [CurrentDB_SID]
FROM       master.dbo.syslogins     l
RIGHT JOIN dbo.sysusers u           ON l.name = u.name COLLATE SQL_Latin1_General_CP1_CI_AS
--RIGHT JOIN  dbo.sysusers u        ON l.sid = u.sid 
WHERE      1 = 1
           AND l.sid <> u.sid
           --AND l.sid IS NULL
           AND u.issqlrole <> 1
           AND u.isapprole <> 1
           AND
           (
               u.name <> 'INFORMATION_SCHEMA'
               AND u.name <> 'guest'
               AND u.name <> 'dbo'
               AND u.name <> 'sys'
               AND u.name <> 'system_function_schema'
           );