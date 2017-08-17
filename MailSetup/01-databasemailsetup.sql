-- DATABASE MAIL SETUP --
-- Send your constructive comments to Dimitri

-- DJ - 20141117 - 1.1 - handles named instances 

-- 0. Some variables  to be changed if needed
DECLARE @servername varchar(255)
SET  @servername = CAST(SERVERPROPERTY('ServerName') AS varchar(255))

DECLARE @smtpserver varchar(255)
SET @smtpserver = <%= $PLASTER_PARAM_SMTPSERVER %>
DECLARE @smtpport int
SET @smtpport  = <%= $PLASTER_PARAM_SMTPPORT %>

DECLARE @testmailrecipients varchar(255)
SET  @testmailrecipients = <%= $PLASTER_PARAM_TESTEMAILADDRESS %>


PRINT '--- About to set up database mail --'
PRINT 'Using SMTP Server ' + @smtpserver + ':' + CAST(@smtpport AS VARCHAR(5))


-- 1. Enable the db mail feature at server level 
-- Enabling Database Mail
exec sp_configure 'show advanced options',1
reconfigure


exec sp_configure 'Database Mail XPs',1
reconfigure

-- 2.Enable service broker in the MSDB database 
-- normally you don't need it
-- USE [master]
-- GO
-- ALTER DATABASE [MSDB] SET  ENABLE_BROKER WITH NO_WAIT


--3. Creating a Profile

PRINT '-- Setting profile '
DECLARE @serverdescription nvarchar(max)
SET @serverdescription = 'Mail Service for instance ' + @servername

IF EXISTS(SELECT 1 FROM msdb.dbo.sysmail_profile WHERE  name = 'sql_alert_profile' )
exec msdb.dbo.sysmail_delete_profile_sp @profile_name= 'sql_alert_profile'

EXECUTE msdb.dbo.sysmail_add_profile_sp
@profile_name = 'sql_alert_profile',
@description =  @serverdescription

-- 4. Create a Mail account  We have to use our company mail messaging system.
PRINT '-- Setting Account'
DECLARE @fromaddress nvarchar(128)
SET @fromaddress = 'sqlserver.'+REPLACE(@servername,'\','.')+'@<%= $PLASTER_PARAM_MAILDOMAIN %>'

IF EXISTS(SELECT 1 FROM msdb.dbo.sysmail_account  WHERE  name = 'account_smtp_public' )
exec msdb.dbo.sysmail_delete_account_sp @account_name='account_smtp_public'

EXECUTE msdb.dbo.sysmail_add_account_sp
@account_name = 'account_smtp_public',
@email_address = @fromaddress,
@description = 'default SMTP Server',
@mailserver_name = @smtpserver,
@port=@smtpport,
@enable_ssl=0

-- 5. Adding the account to the profile
EXECUTE msdb.dbo.sysmail_add_profileaccount_sp
@profile_name = 'sql_alert_profile',
@account_name = 'account_smtp_public',
@sequence_number =1 ;

-- 6. Granting access to the profile to the DatabaseMailUserRole of MSDB
EXECUTE msdb.dbo.sysmail_add_principalprofile_sp
@profile_name = 'sql_alert_profile',
@principal_id = 0,
@is_default = 1 ;


-- 7. Sending Test Mail
PRINT ' Sending test mail to ' + @testmailrecipients
DECLARE @testsubject varchar(255)
SET @testsubject = 'A Test mail from SQL Server ' + @servername
EXECUTE msdb.dbo.sp_send_dbmail
@profile_name = 'sql_alert_profile',
@recipients = @testmailrecipients,
@body = 'Database Mail Testing... Note that it just tests the reachability of the SMTP server from the SQL Server machine, not that the SQL Agent Job can send mails',
@subject = @testsubject;
go


-- 8. allow agent to use it
exec sp_configure 'Agent XPs',1
reconfigure

USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1
GO
EXEC master.dbo.xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent', N'UseDatabaseMail', N'REG_DWORD', 1
GO
EXEC master.dbo.xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent', N'DatabaseMailProfile', N'REG_SZ', N'sql_alert_profile'
GO


-- 9. reset advanced options to default
sp_configure 'show advanced options',0
reconfigure
go

