
USE MSDB
GO

if (@@SERVERNAME = 'HRK-MOTSQL01' or @@SERVERNAME = 'PWDCSQL11' )
begin
	print 'PLEASE DO NOT RUN JOB OWNER CHANGE SCRIPT ON ['+@@SERVERNAME+'] SERVER '
	return
end


DECLARE @JobName NVARCHAR(max)

DECLARE My_Cursor CURSOR FOR
	SELECT [name]  FROM msdb.dbo.sysjobs where suser_sname(owner_sid) <> 'sa' and suser_sname(owner_sid) not in ('##MS_SSISServerCleanupJobLogin##','LOANPACIFIC\sql_etl','LOANPACIFIC\sql_ssrs','LOANPACIFIC\svc_sqlbackups','LOANPACIFIC\SVC_vCenterSQL','LOANPACIFIC\svcctxsql','LOANPACIFIC\svcreportsrvs1','NT AUTHORITY\NETWORK SERVICE')  
		and @@SERVERNAME not in ('HRK-MOTSQL01','PWDCSQL11')
		and @@SERVERNAME in ('PWDCSQL04','PWDCSQL01','PWDCSQL08','PWDCSQL99','PWDCSQL03','PWDCRPT02','PWDCSQL07','PWDCQSD01')


OPEN My_Cursor
FETCH NEXT FROM My_Cursor INTO @JobName

WHILE (@@FETCH_STATUS = 0)
BEGIN
	exec msdb..sp_update_job @job_name = @jobname, @owner_login_name = 'SA'
	print @jobname + ' - Job Owner changed to SA' 
	FETCH NEXT FROM My_Cursor INTO @JobName
END 
CLOSE My_Cursor
DEALLOCATE My_Cursor