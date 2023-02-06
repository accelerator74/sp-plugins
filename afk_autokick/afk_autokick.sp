#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <vip>

StringMap hUserIdTrie;

public Plugin myinfo = 
{
	name = "AFK Autokick",
	author = "Accelerator",
	description = "AutoKick AFK Players",
	version = "5.1",
	url = "https://github.com/accelerator74/sp-plugins"
}

public void OnPluginStart()
{
	hUserIdTrie = new StringMap();
	
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	
	char userid[11];
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) <= 1)
		{
			IntToString(GetClientUserId(i), userid, sizeof(userid));
			hUserIdTrie.SetValue(userid, i);
		}
	}
}

public void OnMapStart()
{
	CreateTimer(60.0, TimerCheck, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action TimerCheck(Handle timer)
{
	int CurTime = GetTime();
	
	int time;
	char userid[11];
	
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (GetClientTeam(i) == 1)
			{
				if (GetUserAdmin(i) == INVALID_ADMIN_ID)
				{
					IntToString(GetClientUserId(i), userid, sizeof(userid));
					if (hUserIdTrie.GetValue(userid, time))
					{
						int specTime = CurTime - time;
						if (specTime >= (IsPlayerVip(i) ? 720 : 360))
						{
							KickClient(i, "You were AFK for too long (%i sec)", specTime);
						}
						else
						{
							PrintToChat(i, "\x05AFK Time: \x03%i sec", specTime);
						}
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	
	if (!client)
		return;
		
	if (!IsClientInGame(client))
		return;
		
	if (IsFakeClient(client))
		return;
	
	char sUserID[11];
	IntToString(userid, sUserID, sizeof(sUserID));
	
	if (event.GetInt("team") <= 1)
	{
		int time;
		if (!hUserIdTrie.GetValue(sUserID, time))
		{
			hUserIdTrie.SetValue(sUserID, GetTime());
		}
	}
	else
	{
		hUserIdTrie.Remove(sUserID);
	}
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	char userid[11];
	IntToString(event.GetInt("userid"), userid, sizeof(userid));
	hUserIdTrie.Remove(userid);
}