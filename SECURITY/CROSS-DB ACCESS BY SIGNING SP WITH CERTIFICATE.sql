/* how to sign a stored procedure so it can access other Databases on same server
adapted from this very helpful article 
http://rusanu.com/2006/03/01/signing-an-activated-procedure/ */


USE [SourceDb]
GO
/* 1). create a user for SourceDB: */ 

DROP USER IF EXISTS [CrossDb_Access_User]
CREATE USER [CrossDb_Access_User] WITHOUT LOGIN
GO

/* 2). create an [usp_RunningInSourceDb] in [SourceDb] that will access securables on [TargetDb]
       by using a statement like for example: SELECT SomeColumn FROM [TargetDb].[dbo].[TargetDbTable]
*/ 

/* 3). grant exec permissions to the user on SourceDB to that sp: */ 
GRANT EXECUTE ON dbo.[usp_RunningInSourceDb] TO [CrossDb_Access_User]
GO

/* 4). create a self-signed certificate on SourceDB and back it up: */ 
IF EXISTS (SELECT * FROM sys.crypt_properties WHERE (crypt_type = 'SPVC') AND (major_id = OBJECT_ID(N'[dbo].[usp_RunningInSourceDb]'))) 
DROP SIGNATURE FROM [usp_RunningInSourceDb] BY CERTIFICATE [CrossDbAccess_Cert];
IF(CERT_ID('CrossDbAccess_Cert') IS NOT NULL) DROP CERTIFICATE [CrossDbAccess_Cert];

CREATE CERTIFICATE [CrossDbAccess_Cert] ENCRYPTION BY PASSWORD = 'Password1234$' WITH SUBJECT = 'Signing for cross-DB access';
/* Sign the procedure with the certificate’s private key */
ADD SIGNATURE TO OBJECT::[usp_RunningInSourceDb] BY CERTIFICATE [CrossDbAccess_Cert] WITH PASSWORD = 'Password1234$'

/* Drop the private key. This way it cannot be used again to sign other procedures. */
ALTER CERTIFICATE [CrossDbAccess_Cert] REMOVE PRIVATE KEY
/* Copy the public key part of the cert to [master] DATABASE; BACKUP to a file and create cert from file in [master] */
BACKUP CERTIFICATE [CrossDbAccess_Cert] TO FILE = 'C:\Users\Public\CrossDbAccess_Cert.cer'
GO


/* 5). re-create that self-signed certificate on TargetDB(s): */ 
USE [TargetDb] /* or use [master] = all DBs on server accessible */
GO
DROP USER IF EXISTS [CrossDb_Access_User] 
IF(CERT_ID('CrossDbAccess_Cert') IS NOT NULL) DROP CERTIFICATE [CrossDbAccess_Cert];
CREATE CERTIFICATE [CrossDbAccess_Cert] FROM FILE = 'C:\Users\Public\CrossDbAccess_Cert.cer';
/* the 'certificate user' carries the permissions that are automatically granted when the signed SP accesses other Databases */
CREATE USER [CrossDb_Access_User] FROM CERTIFICATE [CrossDbAccess_Cert]
--ALTER AUTHORIZATION ON DATABASE::[StagingOpenbet] TO [CrossDb_Access_User];
GRANT SELECT ON [dbo].[TargetDbTable] TO [CrossDb_Access_User]
--exec sp_addrolemember 'db_owner', 'CrossDb_Access_User';
GO



/* 6). run the sp on SourceDB: */ 
USE [SourceDb]
GO

EXECUTE dbo.[usp_RunningInSourceDb]
GO
