-- http://www.sqlskills.com/blogs/paul/easy-monitoring-of-high-severity-errors-create-agent-alerts/
-- http://www.sqlskills.com/blogs/glenn/the-accidental-dba-day-17-of-30-configuring-alerts-for-high-severity-problems/

--1. Check that following files are in the Binn folder (they most likely are):DatabaseMail90.exe,DatabaseMailEngine.dll and DatabaseMailProtocols.dll.

--2. Activate DB Mail functionality by running the following script from Query Analyzer:
USE Master
GO
sp_configure 'show advanced options', 1
GO
reconfigure with override
GO
sp_configure 'Database Mail XPs', 1
GO
reconfigure
GO
sp_configure 'show advanced options', 0
GO

--3. Create a DB Mail profile:
EXECUTE msdb.dbo.sysmail_add_profile_sp
@profile_name = 'DBASupport', -- Change to desired profile name 
@description = 'Profile to send mails from SQL' -- Change to desired profile description
GO

--4. Make the new profile default
EXECUTE msdb.dbo.sysmail_add_principalprofile_sp
@profile_name = 'DBASupport', -- change to the profile just created
@principal_name = 'public',
@is_default = 1 ; -- Make this the default profile
GO

--5. Create a new DB Mail account:
EXECUTE msdb.dbo.sysmail_add_account_sp
@account_name = 'SQLHost' -- change to desired account name
,@description = 'SQL mail account' -- change to desired description
,@email_address = 'SQLHost@YourCompanyDomain.com' -- change to desired mail address
,@display_name = 'SQLHost@YourCompanyDomain.com' -- change to desired name
,@replyto_address = 'DoNotReply@YourCompanyDomain.com'
,@mailserver_name = 'smtprelay@YourCompanyDomain.com' -- change to valid smpt server

--6. Add the new account to the profile:
EXECUTE msdb.dbo.sysmail_add_profileaccount_sp
@profile_name = 'DBASupport', -- change to valid profile
@account_name = 'SQLHost', -- change to valid account
@sequence_number = 1
GO

--7. Test the setup by sending a mail
DECLARE @MailSubject VARCHAR(250)
SET @MailSubject = 'Test email sent from: '+ @@SERVERNAME
DECLARE @MailBody VARCHAR(250)
SET @MailBody = 'Test email sent from: '+ @@SERVERNAME +' - if you received this email by mistake please contact dba@YourCompanyDomain.com'

EXECUTE msdb.dbo.sp_send_dbmail
@profile_name = 'DBASupport',
@recipients='EndUser@YourCompanyDomain.com',
@subject = @MailSubject,
@body = @MailBody
--@replyto_address = 'DoNotReply@YourCompanyDomain.comM'
GO
