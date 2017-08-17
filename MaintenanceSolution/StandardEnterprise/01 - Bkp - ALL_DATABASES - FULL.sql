-- Set here the <%= $PLASTER_PARAM_SQLBackupPath %> (not trailing backslash!)
-- Set here the <%= $PLASTER_PARAM_DBMaintenance %> - where the Maintenance Solution is installed, normally cs_helper.
-- Set here the <%= $PLASTER_PARAM_SQLLogPath %> - Path to where you want to save the logs (Instance Log path by default).
-- Set here the <%= $PLASTER_PARAM_Operator %> - Not the email address, but the defined operator in Database MailConfig.
-- Set here the <%= $PLASTER_PARAM_FriendlyName %> - Customer name or application.
-- Set here the <%= $PLASTER_PARAM_InstanceName %> - Hostname\Instance

USE [msdb]
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Backup Solution' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Backup Solution'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Bkp - ALL_DATABASES - FULL - <%= $PLASTER_PARAM_SQLBackupPath %>', 
                @enabled=1, 
                @notify_level_eventlog=2, 
                @notify_level_email=0, 
                @notify_level_netsend=0, 
                @notify_level_page=0, 
                @delete_level=0, 
                @description=N'Do a full backup of all database using Ola''s solution', 
                @category_name=N'Backup Solution', 
                @owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Launch backup solution', 
                @step_id=1, 
                @cmdexec_success_code=0, 
                @on_success_action=4, 
                @on_success_step_id=2, 
                @on_fail_action=4, 
                @on_fail_step_id=3, 
                @retry_attempts=0, 
                @retry_interval=0, 
                @os_run_priority=0, @subsystem=N'CmdExec', 
                @command=N'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d <%= $PLASTER_PARAM_DBMaintenance %> -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''ALL_DATABASES'', @Directory = N''<%= $PLASTER_PARAM_SQLBackupPath %>'', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = 72, @CheckSum = ''Y'', @LogToTable = ''Y''" -b', 
                @output_file_name=N'<%= $PLASTER_PARAM_SQLLogPath %>\DatabaseBackup_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt', 
                @flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Notify operator OK', 
                @step_id=2, 
                @cmdexec_success_code=0, 
                @on_success_action=1, 
                @on_success_step_id=0, 
                @on_fail_action=2, 
                @on_fail_step_id=0, 
                @retry_attempts=0, 
                @retry_interval=0, 
                @os_run_priority=0, @subsystem=N'TSQL', 
                @command=N'EXECUTE msdb.dbo.sp_notify_operator @name=N''<%= $PLASTER_PARAM_Operator %>'',@subject=N''[<%= $PLASTER_PARAM_FriendlyName %>] [<%= $PLASTER_PARAM_InstanceName %>] [OK] ALL DATABASES - FULL - <%= $PLASTER_PARAM_SQLBackupPath %>'',@body=N''All Databases backups from <%= $PLASTER_PARAM_InstanceName %> on <%= $PLASTER_PARAM_SQLBackupPath %> have been done successfully. Congratulations !''
', 
                @database_name=N'<%= $PLASTER_PARAM_DBMaintenance %>', 
                @flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Notify Operator Error', 
                @step_id=3, 
                @cmdexec_success_code=0, 
                @on_success_action=1, 
                @on_success_step_id=0, 
                @on_fail_action=2, 
                @on_fail_step_id=0, 
                @retry_attempts=0, 
                @retry_interval=0, 
                @os_run_priority=0, @subsystem=N'TSQL', 
                @command=N'EXECUTE msdb.dbo.sp_notify_operator @name=N''<%= $PLASTER_PARAM_Operator %>'',@subject=N''[<%= $PLASTER_PARAM_FriendlyName %>] [<%= $PLASTER_PARAM_InstanceName %>] [KO] ALL DATABASES - FULL - <%= $PLASTER_PARAM_SQLBackupPath %>'',@body=N''All Databases backups from <%= $PLASTER_PARAM_InstanceName %> on <%= $PLASTER_PARAM_SQLBackupPath %> failed. Please check the CommandLog table in <%= $PLASTER_PARAM_DBMaintenance %> to know more about the error''
', 
                @database_name=N'<%= $PLASTER_PARAM_DBMaintenance %>', 
                @flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Schedule for Bkp - ALL_DATABASES - FULL - <%= $PLASTER_PARAM_SQLBackupPath %>', 
                @enabled=1, 
-- weekly, Mo-Fr at 7:01pm
                @freq_type=8, 
                @freq_interval=62, 
                @freq_subday_type=1, 
                @freq_subday_interval=0, 
                @freq_relative_interval=0, 
                @freq_recurrence_factor=1, 
                @active_start_date=20131216, 
                @active_end_date=99991231, 
                @active_start_time=190100, 
                @active_end_time=235959
-- schedule id to be generated by the s

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO
