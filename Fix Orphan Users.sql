
-- ==========================================================================================
-- Update Orphaned users
-- ==========================================================================================
USE tempdb

GO

SET NOCOUNT ON

IF object_id('tempdb..#d') IS NOT NULL
BEGIN
   DROP TABLE #d
END

IF object_id('tempdb..#o') IS NOT NULL
BEGIN
   DROP TABLE #o
END


--DB(s)
CREATE TABLE #d(
	ID INT IDENTITY(1,1) PRIMARY KEY NOT NULL
	,DB		VARCHAR(100) NOT NULL
)	

--Orphans
CREATE TABLE #o(
	ID INT IDENTITY(1,1) PRIMARY KEY NOT NULL
	,UserName	VARCHAR(100) NOT NULL
	,UserSID	VARBINARY(85)NOT NULL 
)


DECLARE @dbID	INT
DECLARE @dbIDs	INT
DECLARE @dbName	VARCHAR(100)
DECLARE @opID	INT
DECLARE @opIDs	INT
DECLARE @opName VARCHAR(100)
DECLARE @SQLStr	VARCHAR(500)

INSERT INTO #d(DB)
SELECT name 
FROM sys.databases 
--WHERE name IN('V1OTASynxis','V1Shared','MammothAcct','Mammoth')

SELECT @dbIDs = MAX(ID) FROM #d
SELECT @dbID  = MIN(ID) FROM #d

WHILE @dbID <= @dbIDs
BEGIN	--DB
	SELECT @dbName = DB FROM #d WHERE ID = @dbID
	SET @SQLStr	= 'USE ' + QUOTENAME(@dbName) + ' ' + 
				  'INSERT INTO #o ' +
				  'EXEC sp_change_users_login ''REPORT'''
				  
	EXEC (@SQLStr)
	
	IF @@ROWCOUNT > 0
	BEGIN	-- RowCount
		SELECT @opIDs = MAX(ID) FROM #o
		SELECT @opID  = MIN(ID) FROM #o
		
		WHILE @opID <= @opIDs
		BEGIN	-- Orphan
			
			SELECT @opName = UserName FROM #o WHERE ID = @opID
				
			SET @SQLStr = 'USE ' + QUOTENAME(@dbName) + CHAR(13) + CHAR(13) + 
			'IF EXISTS(SELECT 1 FROM sys.server_principals WHERE name = ''' + @opName + ''')' + CHAR(10) +
			'BEGIN' + CHAR(13) + 
			'	IF EXISTS(SELECT 1 FROM sys.database_principals WHERE name =''' + @opName + ''')' + CHAR(13) + 
			'	BEGIN' + CHAR(10) +
			'		EXEC sp_change_users_login ''Update_One'', ''' + @opName + ''',''' + @opName + '''' + CHAR(10) + 
			'	END' + CHAR(13) + 
			'END' + CHAR(13) 

			--EXEC (@SQLStr)
			PRINT @SQLStr
			
			
			SET @opID = @opID + 1
						  
		END		-- Orphan	
		
	END		-- RowCount
	
	TRUNCATE TABLE #o
	
	SET @dbID = @dbID + 1		  
END		--DB	

GO
