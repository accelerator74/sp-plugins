#pragma semicolon 1
#include <sourcemod>

#pragma newdecls required

Database db;

public Plugin myinfo =
{
	name = "Timezone DB API",
	author = "Accelerator",
	description = "Time DB API in specific timezone",
	version = "2.0",
	url = "https://forums.alliedmods.net/showthread.php?p=2620743"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("TZ_GetTime", Native_TZGetTime);
	RegPluginLibrary("TZ_API");

	return APLRes_Success;
}

public void OnPluginStart()
{
	char Error[256];
	db = SQLite_UseDatabase("time_zone", Error, sizeof(Error));

	if (Error[0] != '\0')
		LogError("Failed to read database: %s", Error);
}

int Native_TZGetTime(Handle hPlugin, int numParams)
{
	char sTimezone[64];
	GetNativeString(1, sTimezone, sizeof(sTimezone));

	char query[320];
	db.Format(query, sizeof(query), "SELECT (strftime('%%s',DATETIME('now', 'utc')) + `gmt_offset`), `dst`, `gmt_offset` \
		FROM `time_zone` \
		WHERE `time_start` <= strftime('%%s',DATETIME('now', 'utc')) AND `zone_name` = '%s' \
		ORDER BY `time_start` DESC LIMIT 1;", sTimezone);

	SQL_LockDatabase(db);
	DBResultSet rs = SQL_Query(db, query);
	SQL_UnlockDatabase(db);

	if (rs == null)
		return -1;
	
	int ret = -1;
	while (rs.FetchRow())
	{
		ret = rs.FetchInt(0);
		SetNativeCellRef(2, rs.FetchInt(1));
		SetNativeCellRef(3, rs.FetchInt(2));
	}

	delete rs;
	return ret;
}