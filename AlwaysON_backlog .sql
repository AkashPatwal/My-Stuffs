
SELECT AGS.NAME AS AGGroupName
    ,AR.replica_server_name AS InstanceName
    ,HARS.role_desc
    ,Db_name(DRS.database_id) AS DBName
    ,DRS.database_id
    ,is_ag_replica_local = CASE 
        WHEN DRS.is_local = 1
            THEN N'LOCAL'
        ELSE 'REMOTE'
        END
    ,AR.availability_mode_desc AS SyncMode
    ,DRS.synchronization_state_desc AS SyncState
    ,DRS.last_hardened_lsn
    ,DRS.end_of_log_lsn
    ,DRS.last_redone_lsn
    ,DRS.last_hardened_time
    ,DRS.last_redone_time
    ,DRS.log_send_queue_size
    ,DRS.redo_queue_size AS 'Redo_Queue_Size(KB)'
    /*
    if the last_hardened_lsn from the primary server == last_hardened_lsn from secondary server
    then there is NO LATENCY
    */
    ,'seconds behind primary' = CASE 
            WHEN EXISTS (
                    SELECT DRS.last_hardened_lsn
                    FROM (
                        (
                            sys.availability_groups AS AGS INNER JOIN sys.availability_replicas AS AR ON AGS.group_id = AR.group_id
                            ) INNER JOIN sys.dm_hadr_availability_replica_states AS HARS ON AR.replica_id = HARS.replica_id
                        )
                    INNER JOIN sys.dm_hadr_database_replica_states DRS ON AGS.group_id = DRS.group_id
                        AND DRS.replica_id = HARS.replica_id
                    WHERE HARS.role_desc = 'PRIMARY'
                        AND DRS.last_hardened_lsn = DRS.last_hardened_lsn
                    )
                THEN 0
            ELSE datediff(s, last_hardened_time, getdate())
            end
FROM sys.dm_hadr_database_replica_states DRS
LEFT JOIN sys.availability_replicas AR ON DRS.replica_id = AR.replica_id
LEFT JOIN sys.availability_groups AGS ON AR.group_id = AGS.group_id
LEFT JOIN sys.dm_hadr_availability_replica_states HARS ON AR.group_id = HARS.group_id
    AND AR.replica_id = HARS.replica_id
ORDER BY Db_name(DRS.database_id)
    ,is_ag_replica_local