#include <sourcemod>
#include <geoip>
#include <tz>

public void OnPluginStart()
{
	RegConsoleCmd("sm_tztime", cmd_tztime);
}

Action cmd_tztime(int client, int args)
{
	char sTemp[128], timezone[64];
	GetCmdArg(1, sTemp, sizeof(sTemp));

	if (GeoipTimezone(sTemp, timezone, sizeof(timezone))) // Get timezone and rewrite sTemp variable
	{
		int dst, offset;
		int iTime = TZ_GetTime(timezone, dst, offset);
		if (iTime != -1)
		{
			FormatTime(sTemp, sizeof(sTemp), "%m/%d/%Y - %H:%M:%S", dst ? iTime - 3600 : iTime);
			PrintToServer("%s: %s", timezone, sTemp);
			PrintToServer("DST: %d", dst);
			PrintToServer("Offset: %d", offset);
		}
		else
			PrintToServer("Failed to determine the time.");
	}
	else
		PrintToServer("Failed to determine time zone.");

	return Plugin_Handled;
}