#pragma semicolon 1

#include <sourcemod>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Anti-Flood",
	author = "AlliedModders LLC, Accelerator",
	description = "Protects against chat and console flooding",
	version = SOURCEMOD_VERSION,
	url = "http://www.sourcemod.net/"
};

float g_LastTime[MAXPLAYERS + 1] = {0.0, ...};
int g_FloodTokens[MAXPLAYERS + 1] = {0, ...};

float g_LastTimeCmd[MAXPLAYERS + 1] = {0.0, ...};
int g_FloodTokensCmd[MAXPLAYERS + 1] = {0, ...};

ArrayList g_hIgnoredCmds;

ConVar sm_flood_time;

public void OnPluginStart()
{
	sm_flood_time = CreateConVar("sm_flood_time", "0.75", "Amount of time allowed between chat messages and console commands");
	
	g_hIgnoredCmds = new ArrayList(ByteCountToCells(128));
	
	// SMAC
	g_hIgnoredCmds.PushString("choose_closedoor");
	g_hIgnoredCmds.PushString("choose_opendoor");
	g_hIgnoredCmds.PushString("buy");
	g_hIgnoredCmds.PushString("buyammo1");
	g_hIgnoredCmds.PushString("buyammo2");
	g_hIgnoredCmds.PushString("use");
	g_hIgnoredCmds.PushString("vmodenable");
	g_hIgnoredCmds.PushString("vban");
	g_hIgnoredCmds.PushString("bitcmd");
	g_hIgnoredCmds.PushString("sg");
	g_hIgnoredCmds.PushString("spec_next");
	g_hIgnoredCmds.PushString("spec_mode");
	g_hIgnoredCmds.PushString("spec_prev");
	g_hIgnoredCmds.PushString("spec_player");
	g_hIgnoredCmds.PushString("spec_scoreboard");
	g_hIgnoredCmds.PushString("menuselect");	
	g_hIgnoredCmds.PushString("+lookatweapon");
	g_hIgnoredCmds.PushString("-lookatweapon");
	g_hIgnoredCmds.PushString("close_buymenu");
	g_hIgnoredCmds.PushString("open_buymenu");
	g_hIgnoredCmds.PushString("autobuy");
	g_hIgnoredCmds.PushString("rebuy");
	g_hIgnoredCmds.PushString("drop");
	g_hIgnoredCmds.PushString("joingame");
	g_hIgnoredCmds.PushString("jointeam");
	
	RegAdminCmd("sm_addignorecmd",    Commands_AddIgnoreCmd,     ADMFLAG_ROOT,  "Adds a command to ignore on command spam.");
	RegAdminCmd("sm_removeignorecmd", Commands_RemoveIgnoreCmd,  ADMFLAG_ROOT,  "Remove a command to ignore.");
}

public void OnClientPutInServer(int client)
{
	g_LastTime[client] = 0.0;
	g_FloodTokens[client] = 0;
	g_LastTimeCmd[client] = 0.0;
	g_FloodTokensCmd[client] = 0;
}

float max_chat;

public bool OnClientFloodCheck(int client)
{
	max_chat = sm_flood_time.FloatValue;
	
	if (max_chat <= 0.0 
 		|| CheckCommandAccess(client, "sm_flood_access", ADMFLAG_ROOT, true))
	{
		return false;
	}
	
	if (g_LastTime[client] >= GetGameTime())
	{
		if (g_FloodTokens[client] >= 3)
		{
			return true;
		}
	}
	
	return false;
}

public void OnClientFloodResult(int client, bool blocked)
{
	if (max_chat <= 0.0 
 		|| CheckCommandAccess(client, "sm_flood_access", ADMFLAG_ROOT, true))
	{
		return;
	}
	
	float curTime = GetGameTime();
	float newTime = curTime + max_chat;
	
	if (g_LastTime[client] >= curTime)
	{
		if (blocked)
		{
			newTime += 3.0;
		}
		else if (g_FloodTokens[client] < 3)
		{
			g_FloodTokens[client]++;
		}
	}
	else if (g_FloodTokens[client] > 0)
	{
		g_FloodTokens[client]--;
	}
	
	g_LastTime[client] = newTime;
}

public Action OnClientCommand(int client, int args)
{
	if (client == 0)
	{
		return Plugin_Continue;
	}
	
	max_chat = sm_flood_time.FloatValue;
	
	if (max_chat <= 0.0 
 		|| CheckCommandAccess(client, "sm_flood_access", ADMFLAG_ROOT, true))
	{
		return Plugin_Continue;
	}
	
	char command[64];
	GetCmdArg(0, command, sizeof(command));
	StringToLower(command);
	
	if ( g_hIgnoredCmds.FindString(command) != -1 )
		return Plugin_Continue;
	
	if (g_LastTimeCmd[client] >= GetGameTime())
	{
		if (g_FloodTokensCmd[client] >= 30)
		{
			if (!IsClientInKickQueue(client))
			{
				KickClient(client, "kicked for command spamming: %s", command);
				LogAction(-1, client, "%N was kicked for command spamming: %s", client, command);
			}
			return Plugin_Stop;
		}
	}
	
	float curTime = GetGameTime();
	float newTime = curTime + max_chat;
	
	if (g_LastTimeCmd[client] >= curTime)
	{
		if (g_FloodTokensCmd[client] < 30)
		{
			g_FloodTokensCmd[client]++;
		}
	}
	else if (g_FloodTokensCmd[client] > 0)
	{
		g_FloodTokensCmd[client]--;
	}
	
	g_LastTimeCmd[client] = newTime;
	
	return Plugin_Continue;
}

// SMAC
Action Commands_AddIgnoreCmd(int client, int args)
{
	if ( args != 1 )
	{
		ReplyToCommand(client, "Usage: sm_addignorecmd <command name>");
		return Plugin_Handled;
	}

	char f_sCmdName[64];

	GetCmdArg(1, f_sCmdName, sizeof(f_sCmdName));

	int index = g_hIgnoredCmds.FindString(f_sCmdName);

	if ( index == -1 )
	{
		g_hIgnoredCmds.PushString(f_sCmdName);
		ReplyToCommand(client, "You have successfully added %s to the command ignore list.", f_sCmdName);
	}
	else
		ReplyToCommand(client, "%s already exists in the command ignore list.", f_sCmdName);
	return Plugin_Handled;
}

Action Commands_RemoveIgnoreCmd(int client, int args)
{
	if ( args != 1 )
	{
		ReplyToCommand(client, "Usage: sm_removeignorecmd <command name>");
		return Plugin_Handled;
	}

	char f_sCmdName[64];
	GetCmdArg(1, f_sCmdName, sizeof(f_sCmdName));

	int index = g_hIgnoredCmds.FindString(f_sCmdName);

	if ( index != -1 )
	{
		g_hIgnoredCmds.Erase(index);
		ReplyToCommand(client, "You have successfully removed %s from the command ignore list.", f_sCmdName);
	}
	else
		ReplyToCommand(client, "%s is not in the command ignore list.", f_sCmdName);
	return Plugin_Handled;
}

void StringToLower(char[] f_sInput)
{
	int f_iSize = strlen(f_sInput);
	for(int i=0;i<f_iSize;i++)
		f_sInput[i] = CharToLower(f_sInput[i]);
}