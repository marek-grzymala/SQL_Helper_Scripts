SELECT class_desc,*
FROM sys.server_permissions
WHERE grantor_principal_id = (
SELECT principal_id
FROM sys.server_principals
WHERE NAME = N'DomainName\DBA_Account_name') --[DomainName\DBA_Account_name]
GO

select * from sys.endpoints

drop endpoint [Hadr_endpoint]

select * from sys.server_principals

REVOKE ALTER, CONNECT, CONTROL, TAKE OWNERSHIP, VIEW DEFINITION
ON ENDPOINT :: Hadr_endpoint  
FROM [DomainName\DBA_Account_name]


USE [master]
GO

ALTER AVAILABILITY GROUP [Test-AG]
REMOVE LISTENER N'LISTENER_NAME';

GO
