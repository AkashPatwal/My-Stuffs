/*
1)	Exclude timestamp part in backup file name and now file will generate with the same name (“<SourceDBName>_CopyOnly.bak”) and overwrite each time instead of creating a new backup file.
2)	The Process should take latest restored database backup on target server immediately after restore.  For target database backup, it will use the same stored procedure which used in a Full backup job, 

You need to call stored procedure with below four parameters. It will perform all the steps automatically which mentioned in the document. You can change a parameter value as per your requirement.

                For e.g. 
EXECUTE [sp_RestoreDB] @SourceDB = 'Aries_Work', @TargetDB = 'SQL_Q3XX', @SourceDB_Bkp_Location = '\\data\full$\OnDemand', @TargetDB_Bkp_Location = '\\den-backup\full$\pariesdb02'

@SourceDB_Bkp_Location is an optional parameter and it use the default location (\\data\full$\OnDemand) if not specify. Also, @TargetDB_Bkp_Location is an optional parameter and it should skip the target DB backup if location not specify.


You can find the progress real time and history backup/restore details from tblRestoreLog table as well.  You can find the error in Msg column if process failed. 


*/





USE [master]
GO
/****** Object:  StoredProcedure [dbo].[sp_RestoreDB]    Script Date: 11/28/2017 5:56:29 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****
Created by : Jayvant, Datavail Corporation,		Dt : 2017-11-14
Purpose : Backup copy only database and restore with diffrent name on same sql instance.After restore applied predefined user, role and permissions
Supported Edition : SQL 2008 and later
Script version :  Ver 1.0.0

*****/

Create procedure [dbo].[sp_RestoreDB]
	 @SourceDB sysname
	,@TargetDB sysname
	,@SourceDB_Bkp_Location varchar(4000) = null
	,@TargetDB_Bkp_Location  varchar(4000) = null
 
as

begin
		set nocount on

	-- variable declaration 
		declare @server varchar(255)

		declare @physical_device_name varchar(4000)	
		declare @PhysicalLocation varchar(4000)
		declare @PhysicalFileExt varchar(50)
		declare @PhysicalName nvarchar(260)
		declare @LogicalName nvarchar(128)
		declare @newLogicalName nvarchar(128)
		declare @cmd varchar(max)
		declare @subcmd varchar(max)
		declare @subcmd1 varchar(max)
		declare @Type char(10)
		declare @movetocmd varchar(max)
		declare @datafilectr int
		declare @logfilectr int

		declare @ProcessStartTime datetime 
		declare @ProcessEndTime datetime

		declare @StartTime datetime 
		declare @EndTime datetime

		declare @Duration varchar(20)
		declare @Duration_In_Sec int
		declare @Msg  varchar(max)
		declare @status varchar(20)
	-- Parameter validation
		if isnull(@SourceDB,'') = ''
			begin
				RAISERROR (  'Source database is missing' ,16,1)
				return
			end
		if isnull(@TargetDB,'') = ''
			begin
				RAISERROR (  'Target database is missing' ,16,1)
				return
			end

	if not exists( select name from sys.tables where name = 'tblRestoreLog')
	begin
		CREATE TABLE [dbo].[tblRestoreLog](	[LogId] [int] IDENTITY(1,1) NOT NULL Primary key,	[ProcessDate] [varchar](20) NULL,	[Operation] [varchar](8000) NULL,	[StartTime] [datetime] NULL,	[EndTime] [datetime] NULL,	[Duration] [varchar](20) NULL,	[Duration_In_Sec] [int] NULL,	[Status] [varchar](50) NULL,	[Msg] [varchar](max) NULL)
	end 



	insert into tblRestoreLog( ProcessDate,  Operation, StartTime, EndTime, Duration, Duration_In_Sec, Status, Msg)
	values('------------','-------------------------------------------------------------------------------------', '1900-01-01','1900-01-01','',0,'','')
	
	declare @processDt as varchar(20)

	set @processDt = left( replace(replace(replace(convert(varchar(20),getdate(),120) ,'-',''),':',''),' ',''),12)
	set @server = @@SERVERNAME

	set @ProcessStartTime = GETDATE() 
	insert into tblRestoreLog( ProcessDate,  Operation, StartTime, EndTime, Duration, Duration_In_Sec, Status, Msg)
	values(@processDt,'Process started', @ProcessStartTime,'1900-01-01',null,null,'Started','')

	begin Try

		-- set backup file location		
			if isnull(@SourceDB_Bkp_Location,'') = ''
				 set @SourceDB_Bkp_Location = '\\data\full$\OnDemand\'

			set @SourceDB_Bkp_Location = ltrim(rtrim(@SourceDB_Bkp_Location))
	
			if right(@SourceDB_Bkp_Location,1) <> '\'
				set @SourceDB_Bkp_Location = @SourceDB_Bkp_Location + '\' 	     

			declare @BkpTS varchar(10)
			--set @BkpTS = replace(convert(varchar(10), getdate(),101),'/','') 		
			set @BkpTS = 'CopyOnly'

			set @physical_device_name = @SourceDB_Bkp_Location + @SourceDB + '_'+@BkpTS+'.bak'

			
		-- Taking source database backup
			set @StartTime = getdate()

			insert into tblRestoreLog( ProcessDate,  Operation, StartTime, EndTime, Duration, Duration_In_Sec, Status, Msg)
			values(@processDt,'Taking ' + @SourceDB +' database full copy only backup on '+@server, @StartTime,null,null,null,'InProgress','')
			
			set @cmd = 'Backup database '+QUOTENAME(@SourceDB)+' to disk = ''' + @physical_device_name + ''' with stats=5,compression,copy_only,INIT'
			exec(@cmd)
		
			set @EndTime = getdate()
			set @Duration_In_Sec = datediff(SS,@StartTime,@EndTime)
			set @Duration	 = CONVERT(varchar, DATEADD(ss, (@Duration_In_Sec), 0), 108)

			update tblRestoreLog set EndTime = @EndTime, Duration = @Duration, Duration_In_Sec =@Duration_In_Sec,[status] = 'Completed'
			where isnull(Operation,'') <> '' and EndTime is null


		-- Temporary table declaration
			IF OBJECT_ID('tempdb..#fileListTable') IS NOT NULL
				DROP TABLE #fileListTable

			create table #fileListTable  (    [LogicalName]   NVARCHAR(128),[PhysicalName]          NVARCHAR(260),    [Type]  CHAR(1),    [FileGroupName]   NVARCHAR(128),[Size] NUMERIC(20,0),    [MaxSize]   NUMERIC(20,0),     [FileID]  BIGINT,
				[CreateLSN]             NUMERIC(25,0),    [DropLSN] NUMERIC(25,0),    [UniqueID] UNIQUEIDENTIFIER,    [ReadOnlyLSN] NUMERIC(25,0),[ReadWriteLSN]          NUMERIC(25,0),    [BackupSizeInBytes]     BIGINT,
				[SourceBlockSize]       INT,    [FileGroupID]           INT,    [LogGroupGUID]   UNIQUEIDENTIFIER,    [DifferentialBaseLSN]   NUMERIC(25,0),    [DifferentialBaseGUID]  UNIQUEIDENTIFIER,[IsReadOnly]            BIT,    [IsPresent]             BIT
				,[TDEThumbprint]         VARBINARY(32) -- remove this column if using SQL 2005
				--,[nvarchar(360)]		  nvarchar(360)  -- remove this column if SQL version not 2016 
			)

		set @datafilectr = 0
		set @logfilectr = 0

		-- Praparing move clause for restore
			if not exists(select name from sys.databases where name = @TargetDB)
			begin
				truncate table #fileListTable
				INSERT INTO #fileListTable 
				EXEC('RESTORE FILELISTONLY FROM DISK = '''+@physical_device_name+'''')

				declare curDF cursor for
					select ltrim(rtrim( reverse( substring(reverse(PhysicalName), charindex('\',reverse(PhysicalName),0),len(reverse(PhysicalName)))))) as PhysicalLocation
						,ltrim(rtrim(substring(PhysicalName,	CHARINDEX('.',PhysicalName,0) , len(PhysicalName)))) as PhysicalFileExt
						,LogicalName ,type
					from #fileListTable order by FileID

				open curDF
				fetch next from curDF into @PhysicalLocation,@PhysicalFileExt, @LogicalName,@Type
				while @@FETCH_STATUS = 0
					begin
						if @Type = 'D'
							begin
						
								if @datafilectr = 0
									set @PhysicalName = @TargetDB+ @PhysicalFileExt
								else
									set @PhysicalName = @TargetDB +'_' + cast(@datafilectr as varchar(2)) + @PhysicalFileExt

								if isnull(@movetocmd,'') = ''
									set @movetocmd = ',move ''' + @LogicalName + ''' to ''' + @PhysicalLocation +  @PhysicalName  +''''
								else
									set @movetocmd = @movetocmd + char(10) + ',move ''' + @LogicalName + ''' to ''' + @PhysicalLocation +  @PhysicalName  +''''	
							
								set @datafilectr = @datafilectr +1			
							end
						else
							begin

								if @logfilectr = 0
									set @PhysicalName = @TargetDB+'_Log'+ @PhysicalFileExt
								else
									set @PhysicalName = @TargetDB +'_Log_' + cast(@logfilectr as varchar(2)) + @PhysicalFileExt

						
								if isnull(@movetocmd,'') = ''
									set @movetocmd = ',move ''' + @LogicalName + ''' to ''' + @PhysicalLocation +  @PhysicalName  +''''		
								else
									set @movetocmd = @movetocmd + char(10) +  ',move ''' + @LogicalName + ''' to ''' + @PhysicalLocation +  @PhysicalName  +''''	
						
								set @logfilectr = @logfilectr +1		
							end

						fetch next from curDF into @PhysicalLocation,@PhysicalFileExt, @LogicalName,@Type
					end
				close curDF
				deallocate curDF
			end

		-- Preapring backup command
			if exists(select name from sys.databases where database_id > 4 and name =  @TargetDB)
				set @subcmd = 'ALTER DATABASE '+ QUOTENAME(@TargetDB)+'  SET SINGLE_USER WITH ROLLBACK IMMEDIATE;'
			else
				set @subcmd = ''

			set @subcmd1 =   'ALTER DATABASE '+ QUOTENAME(@TargetDB)+' SET MULTI_USER;'

			--FROM DISK = '''+@physical_device_name+''''

			set @cmd =  @subcmd + char(10) +  'RESTORE DATABASE '+ QUOTENAME(@TargetDB)+' FROM DISK = '''+ @physical_device_name + ''' WITH   stats=5  '

			if isnull(@movetocmd,'') <> ''
				set @cmd = @cmd + char(10) +  @movetocmd 

			set @cmd += char(10) + ' ,REPLACE,RECOVERY;'
	
			set @cmd = @cmd + char(10) + @subcmd1
		-- run target db restore command

			set @StartTime = getdate()
			insert into tblRestoreLog( ProcessDate,  Operation, StartTime, EndTime, Duration, Duration_In_Sec, Status, Msg)
			values(@processDt,'Restoring Full backup as ' + @TargetDB + ' on ' +@server ,@StartTime,null,null,null,'InProgress','')

			print @cmd		
			exec(@cmd)

			set @EndTime = getdate()
			set @Duration_In_Sec = datediff(SS,@StartTime,@EndTime)
			set @Duration	 = CONVERT(varchar, DATEADD(ss, (@Duration_In_Sec), 0), 108)

			update tblRestoreLog set EndTime = @EndTime, Duration = @Duration, Duration_In_Sec =@Duration_In_Sec,[status] = 'Completed'
			where isnull(Operation,'') <> '' and EndTime is null


		-- rename targetdb logical files name
			set @StartTime = getdate()
			insert into tblRestoreLog( ProcessDate,  Operation, StartTime, EndTime, Duration, Duration_In_Sec, Status, Msg)
			values(@processDt,'Rename Logical filenames of ' + @TargetDB +' database',@StartTime,null,null,null,'InProgress','')

			set @datafilectr = 0
			set @logfilectr = 0
			set @cmd = 'USE Master'
			declare curLN cursor for 
				select name as LogicalName,type_desc from sys.master_files where db_name(database_id) = 'DB2' order by file_id

			open curLN
			fetch next from curLN into @LogicalName,@Type
			while @@FETCH_STATUS = 0
				begin
					
						if @Type = 'ROWS'
							begin
								if @datafilectr = 0
									set @newLogicalName = @TargetDB
								else
									set @newLogicalName = @TargetDB +'_' + cast(@datafilectr as varchar(2)) 
							
								set @cmd = @cmd + char(10) +  'ALTER DATABASE ' + QUOTENAME(@TargetDB) + ' MODIFY FILE (NAME=N'''+@LogicalName+''', NEWNAME=N'''+@newLogicalName+''');'

								set @datafilectr = @datafilectr +1
							end
						else
							begin
								if @logfilectr = 0
									set @newLogicalName = @TargetDB +'_Log'
								else
									set @newLogicalName = @TargetDB +'_Log_' + cast(@logfilectr as varchar(2)) 
							
								set @cmd = @cmd + char(10) +  'ALTER DATABASE ' + QUOTENAME(@TargetDB) + ' MODIFY FILE (NAME=N'''+@LogicalName+''', NEWNAME=N'''+@newLogicalName+''');'

								set @logfilectr = @logfilectr +1
							end
					fetch next from curLN into @LogicalName,@Type
				end

			close curLN
			deallocate curLN

			
			if isnull(@cmd,'') <> ''
				exec(@cmd)

			set @EndTime = getdate()
			set @Duration_In_Sec = datediff(SS,@StartTime,@EndTime)
			set @Duration	 = CONVERT(varchar, DATEADD(ss, (@Duration_In_Sec), 0), 108)

			update tblRestoreLog set EndTime = @EndTime, Duration = @Duration, Duration_In_Sec =@Duration_In_Sec,[status] = 'Completed'
			where isnull(Operation,'') <> '' and EndTime is null


		--Post restore process
			set @StartTime = getdate()
			insert into tblRestoreLog( ProcessDate,  Operation, StartTime, EndTime, Duration, Duration_In_Sec, Status, Msg)
			values(@processDt,'Post restore process - View and permission configuration on ' + @TargetDB ,@StartTime,null,null,null,'InProgress','')

		-- 1 Create Views
			-- Create view AC_MONTHLY  
				set @cmd = 'USE '+QUOTENAME(@TargetDB)+';
				exec(''
				CREATE VIEW [dbo].[AC_MONTHLY]
				AS
				SELECT     ariesadmin.AC_MONTHLY.*
				FROM         ariesadmin.AC_MONTHLY
				'')
				'
				exec(@cmd)

			-- Create view AC_MONTHLY  
				set @cmd = 'USE '+QUOTENAME(@TargetDB)+';
				exec(''
				CREATE VIEW [dbo].[AC_PROPERTY]
				AS
					SELECT     ariesadmin.AC_PROPERTY.*
					FROM         ariesadmin.AC_PROPERTY
				'')
				'
				exec(@cmd)

			-- Create view AC_MONTHLY  
				set @cmd = 'USE '+QUOTENAME(@TargetDB)+';
				exec(''
				CREATE VIEW [dbo].[AC_SCENARIO]
				AS
					SELECT     ariesadmin.AC_SCENARIO.*
					FROM         ariesadmin.AC_SCENARIO
				'')
				'
				exec(@cmd)

		-- 2 Update ARSYSTABLE table
			set @cmd = 'USE '+QUOTENAME(@TargetDB)+'
				UPDATE [ariesadmin].[ARSYSTBL]
				SET TABLENAME = ''Aries_Work.ariesadmin.AC_DAILY''
				WHERE TABLENAME = ''ariesadmin.AC_DAILY''
				AND TABLESET = ''ARIES'''
			exec(@cmd)

			set @cmd = 'USE '+QUOTENAME(@TargetDB)+'
				UPDATE [ariesadmin].[ARSYSTBL]
				SET TABLENAME = ''Aries_Work.ariesadmin.AC_PRODUCT''
				WHERE TABLENAME = ''ariesadmin.AC_PRODUCT''
				AND TABLESET = ''ARIES'''

			exec(@cmd)


		-- 3 Create database roles in the new database
			set @cmd = 'USE '+QUOTENAME(@TargetDB)+'
				if not exists(select dp.name			
					from sys.database_principals as dp 
						left join sys.database_role_members as drm on drm.role_principal_id = dp.principal_id
						left join sys.database_principals as mp on drm.member_principal_id = mp.principal_id
					where dp.sid NOT IN (0x01) and dp.principal_id > 5 and dp.is_fixed_role <> 1 
					and dp.type = ''R'' and mp.name is null AND dp.name NOT LIKE ''##%'' and dp.name = ''SQL_Admin_Role'')
				begin
					CREATE ROLE [SQL_Admin_Role];
				end
				if not exists(select dp.name			
					from sys.database_principals as dp 
						left join sys.database_role_members as drm on drm.role_principal_id = dp.principal_id
						left join sys.database_principals as mp on drm.member_principal_id = mp.principal_id
					where dp.sid NOT IN (0x01) and dp.principal_id > 5 and dp.is_fixed_role <> 1 
					and dp.type = ''R'' and mp.name is null AND dp.name NOT LIKE ''##%'' and dp.name = ''SQL_Read_Role'')
				begin
					CREATE ROLE [SQL_Read_Role];
				end'

			exec(@cmd)
	
		-- 4 Grant SELECT, UPDATE, INSERT & DELETE permissions on ariesadmin schema for SQL_Admin_Role
			set @cmd = 'USE '+QUOTENAME(@TargetDB)+'
			GRANT DELETE ON SCHEMA::[ariesadmin] TO [SQL_Admin_Role];
			GRANT INSERT ON SCHEMA::[ariesadmin] TO [SQL_Admin_Role];
			GRANT SELECT ON SCHEMA::[ariesadmin] TO [SQL_Admin_Role];
			GRANT UPDATE ON SCHEMA::[ariesadmin] TO [SQL_Admin_Role]'

			exec(@cmd)
		--	5 Grant SELECT, UPDATE, INSERT & DELETE permissions on ariesadmin.ARLOCK table for SQL_Read_Role 
			-- Grant SELECT permissions on ariesadmin schema for SQL_SQL_Read_RoleAdmin_Role  

			set @cmd = 'USE '+QUOTENAME(@TargetDB)+'
			GRANT SELECT ON SCHEMA::[ariesadmin] TO [SQL_Read_Role];
			GRANT DELETE ON [ariesadmin].[ARLOCK] TO [SQL_Read_Role];
			GRANT INSERT ON [ariesadmin].[ARLOCK] TO [SQL_Read_Role];
			GRANT SELECT ON [ariesadmin].[ARLOCK] TO [SQL_Read_Role];
			GRANT UPDATE ON [ariesadmin].[ARLOCK] TO [SQL_Read_Role];'
			exec(@cmd)
	
		-- 6 create BILLBARRETTCORP\SQL_Archive_Admin user and assign role
			set @cmd = 'USE '+QUOTENAME(@TargetDB)+'' + char(10) +'
				if not exists(SELECT name FROM sys.database_principals WHERE name = ''BILLBARRETTCORP\SQL_Archive_Admin'')
				begin
					CREATE USER [BILLBARRETTCORP\SQL_Archive_Admin] FOR LOGIN [BILLBARRETTCORP\SQL_Archive_Admin];
				end'
			exec(@cmd)

			-- assign role
			set @cmd = 'USE '+QUOTENAME(@TargetDB)+'
				ALTER ROLE [SQL_Admin_Role] ADD MEMBER [BILLBARRETTCORP\SQL_Archive_Admin];'
			exec(@cmd)

		-- 7 create BILLBARRETTCORP\SQL_Archive_Admin user and assign role
			set @cmd = 'USE '+QUOTENAME(@TargetDB)+'' + char(10) +'
				if not exists(SELECT name FROM sys.database_principals WHERE name = ''BILLBARRETTCORP\SQL_Archive_Read'')
				begin
					CREATE USER [BILLBARRETTCORP\SQL_Archive_Read] FOR LOGIN [BILLBARRETTCORP\SQL_Archive_Read];
				end'
			exec(@cmd)

			-- assign role
			set @cmd = 'USE '+QUOTENAME(@TargetDB)+'
			ALTER ROLE [SQL_Read_Role] ADD MEMBER [BILLBARRETTCORP\SQL_Archive_Read];'

			exec(@cmd)

			set @EndTime = getdate()
			set @Duration_In_Sec = datediff(SS,@StartTime,@EndTime)
			set @Duration	 = CONVERT(varchar, DATEADD(ss, (@Duration_In_Sec), 0), 108)

			update tblRestoreLog set EndTime = @EndTime, Duration = @Duration, Duration_In_Sec =@Duration_In_Sec,[status] = 'Completed'
			where isnull(Operation,'') <> '' and EndTime is null
	
		-- 8 Taking backup of new database on target server.
			if isnull(@TargetDB_Bkp_Location,'') <> ''
			begin
				set @StartTime = getdate()
				insert into tblRestoreLog( ProcessDate,  Operation, StartTime, EndTime, Duration, Duration_In_Sec, Status, Msg)
				values(@processDt,'Taking ' + @TargetDB +' database full backup on '+@server, @StartTime,null,null,null,'InProgress','')
	
				DECLARE	@RETURNVALUE	VARCHAR(1000)	
			
				EXEC dv_BkupAlldbs_sp	@TargetDB_Bkp_Location,'FULL',1,7,'Yes',@RETURNVALUE OUTPUT,@TargetDB

				--SELECT	@RETURNVALUE
				set @EndTime = getdate()
				set @Duration_In_Sec = datediff(SS,@StartTime,@EndTime)
				set @Duration	 = CONVERT(varchar, DATEADD(ss, (@Duration_In_Sec), 0), 108)

				update tblRestoreLog set EndTime = @EndTime, Duration = @Duration, Duration_In_Sec =@Duration_In_Sec,[status] = 'Completed'
				where isnull(Operation,'') <> '' and EndTime is null
			end

		set @EndTime = GETDATE() 
		set @Duration_In_Sec = datediff(SS,@ProcessStartTime,@EndTime)
		set @Duration	 = CONVERT(varchar, DATEADD(ss, (@Duration_In_Sec), 0), 108)

						
		insert into tblRestoreLog( ProcessDate,  Operation, StartTime, EndTime, Duration, Duration_In_Sec, Status, Msg)
		values(@processDt,'Process ended successfully', @ProcessStartTime,@EndTime,@Duration,@Duration_In_Sec,'Ended','')

		
	end try
	begin catch

		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT

		SELECT @ErrorMessage = ERROR_MESSAGE(),@ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE() ;	

		set @EndTime = getdate()

		set @Duration_In_Sec = datediff(SS,@StartTime,@EndTime)
		set @Duration	 = CONVERT(varchar, DATEADD(ss, (@Duration_In_Sec), 0), 108)

		update tblRestoreLog set EndTime = @EndTime, Duration = @Duration, Duration_In_Sec =@Duration_In_Sec,[status] = 'Failed' 	,Msg = @ErrorMessage
		where isnull(Operation,'') <> '' and EndTime is null

		set @EndTime = GETDATE() 
		set @Duration_In_Sec = datediff(SS,@ProcessStartTime,@EndTime)
		set @Duration	 = CONVERT(varchar, DATEADD(ss, (@Duration_In_Sec), 0), 108)

		insert into tblRestoreLog( ProcessDate,  Operation, StartTime, EndTime, Duration, Duration_In_Sec, Status, Msg)
		values(@processDt,'Process ended with error', @ProcessStartTime,@EndTime,@Duration,@Duration_In_Sec,'Ended with error','')
    
		RAISERROR (@ErrorMessage, @ErrorSeverity,@ErrorState)

	end catch
end
