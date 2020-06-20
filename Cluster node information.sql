USE tempdb

DECLARE @AFTERRESTART VARCHAR(50)
DECLARE @BEFORERESTART VARCHAR(50)
DECLARE @TIME VARCHAR(100)

CREATE TABLE #TBL_FAILOVER_INFO (C1 VARCHAR(100),C2 VARCHAR(15),C3 VARCHAR (200), C4 SMALLINT IDENTITY (0,1))
INSERT INTO #TBL_FAILOVER_INFO
EXEC master.dbo.xp_readerrorlog 0, 1, 'The NETBIOS name of the local node that is running the server is', NULL, NULL, NULL

INSERT INTO #TBL_FAILOVER_INFO
EXEC master.dbo.xp_readerrorlog 1, 1, 'The NETBIOS name of the local node that is running the server is', NULL, NULL, NULL

SET  @AFTERRESTART = (SELECT REVERSE(SUBSTRING(REVERSE(SUBSTRING(C3 ,67,100)),70,100)) AS TEXT FROM #TBL_FAILOVER_INFO WHERE C4 =0)
SET  @BEFORERESTART =  (SELECT REVERSE(SUBSTRING(REVERSE(SUBSTRING(C3 ,67,100)),70,100)) AS TEXT FROM #TBL_FAILOVER_INFO WHERE C4 =1)
SET @TIME = (SELECT C1 FROM #TBL_FAILOVER_INFO WHERE C4 = 0)

SELECT @AFTERRESTART AS 'CURRENT NODE' , @BEFORERESTART AS 'PREVIOUS NODE' , 'FAIL OVER STATUS' =

CASE
WHEN @AFTERRESTART = @BEFORERESTART
THEN 'RESTARTED ON THE NODE:'+ @BEFORERESTART + ' APPROXIMATELY AROUND ' + @TIME
ELSE 'FAILED OVER TO THE NODE:' + @AFTERRESTART + ' APPROXIMATELY AROUND ' + @TIME
END


drop table #TBL_FAILOVER_INFO


============================================================================

SELECT NodeName, status, status_description, is_current_owner   
FROM sys.dm_os_cluster_nodes;  