/* auto-gen the xml for the columns for your XE sessions */
DECLARE @EventName VARCHAR(64) = NULL --'query_post_execution_showplan'
	,@ReadFlag VARCHAR(64) = 'readonly' --NULL if all columntypes are desired
	,@SessionName	VARCHAR(128) = NULL --'system_health' --NULL if all Sessions are desired

SELECT oc.OBJECT_NAME AS EventName
		,oc.name AS column_name, oc.type_name
		,',event_data.value(''(event/data[@name="' + oc.name + '"]/value)[1]'',''' + 
			CASE 
				WHEN ISNULL(xmv.name,'') = ''
					AND oc.type_name = 'guid'
				THEN 'uniqueidentifier'
				WHEN ISNULL(xmv.name,'') = ''
					AND oc.type_name = 'boolean'
				THEN 'bit'
				WHEN ISNULL(xmv.name,'') = ''
					AND oc.type_name <> 'unicode_string'
					AND oc.type_name <> 'ansi_string'
					AND oc.type_name <> 'ptr'
					AND oc.type_name NOT LIKE '%int%'
				THEN oc.type_name
				WHEN ISNULL(xmv.name,'') = ''
					AND oc.type_name LIKE '%int%'
				THEN 'int'
				ELSE 'varchar(max)' END + ''') AS ' + oc.name + '' AS ColumnXML
		,oc.column_type AS column_type
		,oc.column_value AS column_value
		,oc.description AS column_description
		,ca.map_value AS SearchKeyword
	FROM sys.dm_xe_object_columns oc
	-- do we have any custom data types
		OUTER APPLY (SELECT DISTINCT mv.name FROM sys.dm_xe_map_values mv
			WHERE mv.name = oc.type_name
			AND mv.object_package_guid = oc.object_package_guid) xmv
	--just get the unique events that are tied to a session on the server (stopped or started state)
		CROSS APPLY (SELECT DISTINCT sese.name,ses.name AS SessionName
						FROM sys.server_event_session_events sese
							INNER JOIN sys.server_event_sessions ses
								ON sese.event_session_id = ses.event_session_id) sesea
	--keyword search phrase tied to the event
		CROSS APPLY (SELECT TOP 1 mv.map_value
						FROM sys.dm_xe_object_columns occ
						INNER JOIN sys.dm_xe_map_values mv
							ON occ.type_name = mv.name
							AND occ.column_value = mv.map_key
						WHERE occ.name = 'KEYWORD'
							AND occ.object_name = oc.object_name) ca
	WHERE oc.column_type <> @ReadFlag
		AND sesea.name = oc.object_name
		AND oc.object_name = ISNULL(@EventName,oc.object_name)
		AND sesea.SessionName = ISNULL(@SessionName,sesea.SessionName)
	ORDER BY sesea.SessionName,oc.object_name
	;
GO