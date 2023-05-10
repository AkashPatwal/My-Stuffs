--- Prepared by : Jayvant		Dt : 2016-06-17
--- Purpose : Capture the deadlock and send alert through database mail.
--- Supported Edition : SQL 2012 nd later
--- Script version :  Ver 1.0.0

alter Procedure [dbo].[sp_Deadlock_Events]
As
begin
	set nocount on

	DECLARE @LastDeadLock DATETIME2, @XE_EVENT_FILE_TARGET XML, @XE_FILE_PATH NVARCHAR(260), @sql varchar(max)

	DECLARE @vbody NVARCHAR(MAX),@vbody_db NVARCHAR(MAX), @vbody_h NVARCHAR(MAX),@vXML_String AS NVARCHAR (MAX),@vXML_String_db AS NVARCHAR (MAX)

	SET @vbody = ''  
	SET @vbody_db = ''  
	set @vbody_h = ''
	SET @vXML_String=''
	set @vXML_String_db = ''
	

	SELECT @XE_EVENT_FILE_TARGET = CONVERT(XML, xst.target_data)
	FROM sys.dm_xe_sessions xs
	JOIN sys.dm_xe_session_targets xst
	ON xs.address = xst.event_session_address
	WHERE xs.name = 'system_health'
	AND xst.target_name = 'event_file'
 
	SELECT @XE_FILE_PATH = t.c.value('File[1]/@name', 'varchar(260)') FROM @XE_EVENT_FILE_TARGET.nodes('/EventFileTarget') AS t(c)

	IF OBJECT_ID('tempdb..#tmp_EE_DATA') IS NOT NULL
		DROP TABLE #tmp_EE_DATA

	IF OBJECT_ID('tempdb..#tbl_DEADLOCKS_DTL') IS NOT NULL
		DROP TABLE #tbl_DEADLOCKS_DTL


	create table #tmp_EE_DATA(ID int identity(1,1) primary key, event_data xml null, Process_count int null)

	CREATE TABLE #tbl_DEADLOCKS_DTL(Id int identity(1,1) primary key,Instance varchar(250) null ,DeadlockTimestamp DATETIME2  NULL,DeadlockEvent NVARCHAR(250) NULL,
				Victim int null,VictimSPID NVARCHAR(250) NULL,SPID NVARCHAR(250) NULL,WaitResource NVARCHAR(250) NULL,WaitTime INT NULL,OwnerId BIGINT NULL,DBName varchar(250) NULL,LastTranStarted DATETIME2 NULL,LastBatchStarted DATETIME2 NULL,Statement NVARCHAR(MAX) NULL,
				sqlhandle nvarchar(500) null,Client NVARCHAR(250) NULL,Hostname NVARCHAR(250) NULL,Loginname NVARCHAR(250) NULL,DeadlockGraph xml null)

	IF (SELECT OBJECT_ID('tbl_Deadock_History')) IS NULL 
	BEGIN
		CREATE TABLE tbl_Deadock_History(Id int identity(1,1) primary key,Instance varchar(250) null ,DeadlockTimestamp DATETIME2  NULL,DeadlockEvent NVARCHAR(250) NULL,
				Victim int null,VictimSPID NVARCHAR(250) NULL,SPID NVARCHAR(250) NULL,WaitResource NVARCHAR(250) NULL,WaitTime INT NULL,OwnerId BIGINT NULL,DBName varchar(250) NULL,LastTranStarted DATETIME2 NULL,LastBatchStarted DATETIME2 NULL,Statement NVARCHAR(MAX) NULL,
				sqlhandle nvarchar(500) null,Client NVARCHAR(250) NULL,Hostname NVARCHAR(250) NULL,Loginname NVARCHAR(250) NULL,DeadlockGraph xml null)
	END
 
	SELECT @LastDeadLock = ISNULL(MAX(DeadlockTimestamp), '1900-01-01') FROM tbl_Deadock_History where DeadlockTimestamp is not null

	insert into #tmp_EE_DATA(event_data,Process_count)
	SELECT CAST(event_data AS XML) AS event_data
		,(len(cast(event_data as varchar(max))) - len(replace(cast(event_data as varchar(max)), '<process id="', ''))) /13
		as process_count
	FROM sys.fn_xe_file_target_read_file(@XE_FILE_PATH, null, null, null)
	WHERE object_name = 'xml_deadlock_report'


	declare @id int, @Process_count int,@ctr int

	declare curD cursor for 
		select ID,Process_count from #tmp_EE_DATA order by ID 

	open curD
	fetch next from curD into @id,@Process_count
	while @@FETCH_STATUS = 0
		begin
			set @ctr = 1
			while @ctr <= @Process_count
				begin
					if @ctr = 1
						set @sql = 'insert into #tbl_DEADLOCKS_DTL(Instance,DeadlockTimestamp ,DeadlockEvent ,Victim ,VictimSPID ,SPID ,WaitResource ,WaitTime ,OwnerId ,DBName ,LastTranStarted ,LastBatchStarted ,Statement  ,sqlhandle  ,Client ,Hostname ,Loginname ,DeadlockGraph )
									SELECT @@SERVERNAME, DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), GETDATE()), c.value(''@timestamp'', ''DATETIME2'')) AS DeadlockTimestamp,
									c.value(''(@name)[1]'', ''nvarchar(250)'') AS DeadlockEvent,
									1 AS victim,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@spid'', ''nvarchar(250)'') AS VictimSPID,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@spid'', ''nvarchar(250)'') AS SPID,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@waitresource'', ''nvarchar(250)'') AS WaitResource,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@waittime'', ''int'') AS WaitTime,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@ownerId'', ''bigint'') AS OwnerId,
									DB_NAME(c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@currentdb'', ''int'')) AS CurrentDb,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@lasttranstarted'', ''datetime2'') AS LastTranStarted,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@lastbatchstarted'', ''datetime2'') AS LastBatchStarted,
									c.value(''(data/value/deadlock/process-list/process/inputbuf)['+cast(@ctr as varchar(10))+']'', ''nvarchar(max)'') AS Statement_1,
									c.value(''(data/value/deadlock/process-list/process/executionStack/frame)['+cast(@ctr as varchar(10))+']/@sqlhandle'', ''nvarchar(250)'') AS sqlhandle,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@clientapp'', ''nvarchar(250)'') AS Client,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@hostname'', ''nvarchar(250)'') AS Hostname,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@loginname'', ''nvarchar(250)'') AS Loginname
									,#tmp_EE_DATA.event_data
								FROM #tmp_EE_DATA
								CROSS APPLY event_data.nodes(''//event'') AS t (c) 
								where  id = ' + cast(@id as varchar(10))	
							
										
					else				
						set @sql = 'insert into #tbl_DEADLOCKS_DTL(Instance,DeadlockTimestamp ,DeadlockEvent ,Victim ,VictimSPID ,SPID ,WaitResource ,WaitTime ,OwnerId ,DBName ,LastTranStarted ,LastBatchStarted ,Statement  ,sqlhandle  ,Client ,Hostname ,Loginname ,DeadlockGraph )
									SELECT '''' as Instance
									, DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), GETDATE()), c.value(''@timestamp'', ''DATETIME2'')) AS DeadlockTimestamp
									,'''' as DeadlockEvent, 0 AS victim, '''' as VictimSPID,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@spid'', ''nvarchar(250)'') AS SPID,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@waitresource'', ''nvarchar(250)'') AS WaitResource,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@waittime'', ''int'') AS WaitTime,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@ownerId'', ''bigint'') AS OwnerId,
									DB_NAME(c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@currentdb'', ''int'')) AS CurrentDb,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@lasttranstarted'', ''datetime2'') AS LastTranStarted,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@lastbatchstarted'', ''datetime2'') AS LastBatchStarted,
									c.value(''(data/value/deadlock/process-list/process/inputbuf)['+cast(@ctr as varchar(10))+']'', ''nvarchar(max)'') AS Statement_1,
									c.value(''(data/value/deadlock/process-list/process/executionStack/frame)['+cast(@ctr as varchar(10))+']/@sqlhandle'', ''nvarchar(250)'') AS sqlhandle,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@clientapp'', ''nvarchar(250)'') AS Client,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@hostname'', ''nvarchar(250)'') AS Hostname,
									c.value(''(data/value/deadlock/process-list/process)['+cast(@ctr as varchar(10))+']/@loginname'', ''nvarchar(250)'') AS Loginname
									,'''' as deadlockgraph
								FROM #tmp_EE_DATA
								CROSS APPLY event_data.nodes(''//event'') AS t (c) 
								where  id = ' + cast(@id as varchar(10))
					--print @sql
					exec(@sql)
					set @ctr +=1
				end
				fetch next from curD into @id,@Process_count
		end
	close curD
	deallocate curD

	INSERT tbl_Deadock_History(Instance,DeadlockTimestamp ,DeadlockEvent,Victim,VictimSPID,SPID,WaitResource,WaitTime,OwnerId,DBName,LastTranStarted,LastBatchStarted,[Statement], sqlhandle,Client,Hostname,Loginname,DeadlockGraph)
	SELECT Instance,DeadlockTimestamp ,DeadlockEvent,Victim,VictimSPID,SPID,WaitResource,WaitTime,OwnerId,DBName,LastTranStarted,LastBatchStarted,[Statement], sqlhandle,Client,Hostname,Loginname,DeadlockGraph
	FROM #tbl_DEADLOCKS_DTL
	WHERE DeadlockTimestamp > @LastDeadLock

	if exists(select id FROM #tbl_DEADLOCKS_DTL where  DeadlockTimestamp > @LastDeadLock )
	begin
			SET @vBody_h ='
							<html>
							<head></head>
							<title>'+@@Servername+' Instance Deadlock Report</title>
							<body>
							<h2><center>Deadlock Report from : ' + @@Servername +' </center></h2>
							<h3>Hello Team,</h3>
							<h4>Deadlock occurred on ' + @@Servername +'  </h4>'

			SET @vBody_db =  '<left>
								<table border=1 cellpadding=2>
								<style>table {border-collapse: collapse}  TH{font-size: 10pt;font-style: Bold} TD{font-size: 10pt;font-style: normal}</style>
								<style>tr {border-collapse: collapse} </style>
								<tr border=0 bgcolor="#D8D8D8">
								<td colspan="2" > <font size="2.75">  <center> <b>Deadlock Deshboard </b></center>  </font></td>
								<tr bgcolor="#D8D8D8">
								<th>Deadlock Count</th>
								<th>Processes Involved</th>
								</tr>'

			SET @vXML_String_db = CONVERT (VARCHAR (MAX),
							(
								SELECT 					 
										'',isnull(sum(victim),'') AS 'td'
									,'',isnull(count(victim),'') AS 'td'
								
								FROM #tbl_DEADLOCKS_DTL --where DeadlockTimestamp > @LastDeadLock  
								FOR
									XML PATH ('tr')
								)
							)	

			SET @vBody = '
								<center>
								<table border=1 cellpadding=2>
									<style>table {border-collapse: collapse}</style>
									<tr border=0 bgcolor="#D8D8D8">
										<style>tr {border-collapse: collapse} </style>
										<th>Instance</th>
										<th>Deadlock Timestamp</th>
										<th>Victim</th>
										<th>Victim SPID</th>
										<th>SPID</th>
										<th>Database</th>
										<th>WaitTime</th>
										<th>Loginname</th>
										<th>Hostname</th>
										<th>Transaction Time</th>
										<th>Client App</th>
										<th>Query</th>
									</tr>'

					SET @vXML_String = CONVERT (VARCHAR (MAX),
							(
								SELECT 					 
										'',isnull(Instance,'') AS 'td'
									,'',case when victim =1 then isnull(Convert(varchar,DeadlockTimestamp),'') else '' end  AS 'td'
									,'',isnull(Victim,'') AS 'td'
									,'',isnull(VictimSPID,'') AS 'td'
									,'',isnull(SPID,'') AS 'td'
									,'',isnull(DBName,'') AS 'td'
									,'',isnull(Convert(varchar,WaitTime),'') AS 'td'
									,'',isnull(Convert(varchar,Loginname),'') AS 'td'
									,'',isnull(Convert(varchar,Hostname),'') AS 'td'
									,'',isnull(Convert(varchar,LastTranStarted),'') AS 'td'
									,'',isnull(Convert(varchar,Client),'') AS 'td'
									,'',isnull(Convert(varchar(max),Statement),'') AS 'td'
								
								FROM #tbl_DEADLOCKS_DTL --where DeadlockTimestamp > @LastDeadLock  
								FOR
									XML PATH ('tr')
								)
							)

			set @vBody_db = @vBody_db +@vXML_String_db + 
												'</table>
													</left> 
													</BR>'

			SET @vBody = @vBody_h + @vBody_db  + @vBody +@vXML_String+'
								</table>
							</center>
							</BR>
							<B> Thanks 
							</BR>
							</BR> Datavail Corporation </B>
		
						</body>
					</html>	'
	

			--print @vBody

			declare @email_subject varchar(250)
			set @email_subject = 'Deadlock Capture on ' + @@Servername

			Exec msdb.dbo.sp_send_dbmail @profile_name = 'dv_jay'  
				, @recipients ='jayvant.patel@datavail.com' 
				, @subject =   @email_subject    
				, @body =   @vbody    
				, @body_format = 'HTML' 

	END					  

END