SELECT distinct ServerName, LoginName, databasename, ApplicationName
FROM fn_trace_gettable('f:\dv\LoginInfo.trc', default);  