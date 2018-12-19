SELECT
	[database_name] AS "Database Name",
	DATENAME(month,[backup_start_date]) AS "Backup Month",
	cast(AVG([backup_size]/1024/1024) as numeric(10,2)) AS "Backup Size(MB)",
	cast(AVG([compressed_backup_size]/1024/1024) as numeric(10,2)) AS "Compressed Backup Size(MB)",
	cast(AVG([backup_size]/[compressed_backup_size]) as numeric(10,2)) AS "Compression Ratio"
FROM msdb.dbo.backupset
WHERE [type] = 'D'
AND [database_name] = 'learn'
GROUP BY [database_name], DATENAME(month,[backup_start_date]), DATEPART(mm,[backup_start_date])
order by [database_name], DATEPART(mm,backup_start_date) desc;


SELECT
CAST([database_name] as Varchar(20)) AS 'Database',
convert(varchar(7),[backup_start_date],120) AS 'Month',
STR(AVG([backup_size]/1024/1024/1024),5,2) AS 'Backup Size GB',
STR(AVG([compressed_backup_size]/1024/1024/1024),5,2) AS 'Compressed Backup Size GB',
STR(AVG([backup_size]/[compressed_backup_size]),5,2) AS 'Compression Ratio'
FROM msdb.dbo.backupset
WHERE [type] = 'D'
--AND [database_name] = N'alsSecure'
and backup_finish_date > '2015-11-30'
GROUP BY [database_name],convert(varchar(7),[backup_start_date],120)
order BY [database_name],convert(varchar(7),[backup_start_date],120);