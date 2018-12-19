--- Change non sa database owner to sa

USE [master]
go
DECLARE @DBName varchar(255)
DECLARE @OwnerName varchar(255)
declare @cmd varchar(max)

DECLARE My_Cursor CURSOR FOR
	select  [name] as dbname,suser_sname(owner_sid) as dbowner from sys.databases where suser_sname(owner_sid) <> 'sa'

OPEN My_Cursor
FETCH NEXT FROM My_Cursor INTO @DBName,@OwnerName

WHILE (@@FETCH_STATUS = 0)
BEGIN
	set @cmd = ''
	set @cmd =  char(10) + 'USE ['+@DBName+']'   
	set @cmd =  @cmd + char(10) + 'EXEC dbo.sp_changedbowner @loginame = N''SA'''   
	
	set @cmd =  @cmd + char(10) + 'USE ['+@DBName+']' 

	set @cmd =  @cmd + char(10) + 'IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = '''+@OwnerName+''')'
	set @cmd =  @cmd + char(10) + '	CREATE USER ['+@OwnerName+'] FOR LOGIN ['+@OwnerName+']' 
	set @cmd =  @cmd + char(10) + 'ALTER ROLE [db_owner] ADD MEMBER ['+@OwnerName+']'

	--print @cmd
	exec(@cmd)

	print @DBName + ' - Database Owner changed to SA' 

	print ''
	FETCH NEXT FROM My_Cursor INTO @DBName,@OwnerName
END 
CLOSE My_Cursor
DEALLOCATE My_Cursor

