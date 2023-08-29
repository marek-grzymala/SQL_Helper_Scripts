USE [master]
GO


DECLARE @CurrentUser NVARCHAR(256)

EXECUTE AS LOGIN = 'DOMAIN\username'
PRINT 'Currently running as login: '+@CurrentUser

SELECT @CurrentUser = CONVERT(NVARCHAR(256), CURRENT_USER)

IF IS_SRVROLEMEMBER ('sysadmin') = 1  
   PRINT 'Current user''s login: ['+@CurrentUser+'] is a member of the sysadmin role'  
ELSE IF IS_SRVROLEMEMBER ('sysadmin') = 0  
   PRINT 'Current user''s login: ['+@CurrentUser+'] is NOT a member of the sysadmin role'  
REVERT
SELECT @CurrentUser = CONVERT(NVARCHAR(256), CURRENT_USER)
PRINT 'Currently running as login: '+@CurrentUser
