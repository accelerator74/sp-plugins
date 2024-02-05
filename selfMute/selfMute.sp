#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <adminmenu>

#define PLUGIN_VERSION "2.1"

int g_MuteList[MAXPLAYERS+1][MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "Self-Mute",
	author = "Accelerator, Otokiru ,edit 93x",
	description = "Self Mute Player Voice",
	version = PLUGIN_VERSION,
	url = "www.xose.net"
}

//====================================================================================================
//==== CREDITS: Otokiru (Idea+Source) // TF2MOTDBackpack (PlayerList Menu)
//====================================================================================================

public void OnPluginStart() 
{	
	LoadTranslations("common.phrases");
	CreateConVar("sm_selfmute_version", PLUGIN_VERSION, "Version of Self-Mute", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	RegConsoleCmd("sm_sm", selfMute, "Mute player by typing !selfmute [playername]");
	RegConsoleCmd("sm_selfmute", selfMute, "Mute player by typing !sm [playername]");
	RegConsoleCmd("sm_su", selfUnmute, "Unmute player by typing !su [playername]");
	RegConsoleCmd("sm_selfunmute", selfUnmute, "Unmute player by typing !selfunmute [playername]");
	RegConsoleCmd("sm_cm", checkmute, "Check who you have self-muted");
	RegConsoleCmd("sm_checkmute", checkmute, "Check who you have self-muted");
}

//====================================================================================================

public void OnClientAuthorized(int client, const char[] auth)
{
	if (!StrEqual(auth, "BOT"))
	{
		if (GetClientTime(client) > 10.0)
			return;
	}
	
	for (int i = 1; i <= MaxClients; i++)
		g_MuteList[client][i] = 0;
}

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
	{
		for (int id = 1; id <= MaxClients; id++)
		{
			if (id == client) continue;
			
			if (g_MuteList[client][id] && IsClientConnected(id))
			{
				if (g_MuteList[client][id] == GetClientUserId(id))
					SetListenOverride(client, id, Listen_No);
				else
					g_MuteList[client][id] = 0;
			}
		}
	}
}

//====================================================================================================

Action selfMute(int client, int args)
{
	if(client == 0)
	{
		PrintToChat(client, "[SM] Cannot use command from RCON");
		return Plugin_Handled;
	}
	
	if(args < 1) 
	{
		ReplyToCommand(client, "[SM] Use: !sm [playername]");
		DisplayMuteMenu(client);
		return Plugin_Handled;
	}
	
	char strTarget[32];
	GetCmdArg(1, strTarget, sizeof(strTarget)); 
	
	char strTargetName[MAX_TARGET_LENGTH]; 
	int TargetList[MAXPLAYERS], TargetCount; 
	bool TargetTranslate; 
	
	if ((TargetCount = ProcessTargetString(strTarget, client, TargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS, 
	strTargetName, sizeof(strTargetName), TargetTranslate)) <= 0) 
	{
		ReplyToTargetError(client, TargetCount); 
		return Plugin_Handled; 
	}
	
	for (int i = 0; i < TargetCount; i++) 
	{ 
		if (TargetList[i] > 0 && TargetList[i] != client && IsClientInGame(TargetList[i])) 
		{
			muteTargetedPlayer(client, TargetList[i]);
		}
	}
	return Plugin_Handled;
}

void DisplayMuteMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_MuteMenu);
	SetMenuTitle(menu, "Choose a player to mute");
	SetMenuExitBackButton(menu, true);
	
	AddTargetsToMenu2(menu, 0, COMMAND_FILTER_NO_BOTS);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

int MenuHandler_MuteMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char info[32];
			int target;
			
			GetMenuItem(menu, param2, info, sizeof(info));
			int userid = StringToInt(info);
			
			if ((target = GetClientOfUserId(userid)) == 0)
			{
				PrintToChat(param1, "[SM] Player no longer available");
			}
			else
			{
				muteTargetedPlayer(param1, target);
			}
		}
	}
	
	return 0;
}

void muteTargetedPlayer(int client, int target)
{
	SetListenOverride(client, target, Listen_No);
	PrintToChat(client, "\x04[Self-Mute]\x01 You have self-muted:\x04 %N", target);
	g_MuteList[client][target] = GetClientUserId(target);
}

//====================================================================================================

Action selfUnmute(int client, int args)
{
	if(client == 0)
	{
		PrintToChat(client, "[SM] Cannot use command from RCON");
		return Plugin_Handled;
	}
	
	if(args < 1) 
	{
		ReplyToCommand(client, "[SM] Use: !su [playername]");
		DisplayUnMuteMenu(client);
		return Plugin_Handled;
	}
	
	char strTarget[32];
	GetCmdArg(1, strTarget, sizeof(strTarget)); 
	
	char strTargetName[MAX_TARGET_LENGTH]; 
	int TargetList[MAXPLAYERS], TargetCount; 
	bool TargetTranslate; 
	
	if ((TargetCount = ProcessTargetString(strTarget, client, TargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS, 
	strTargetName, sizeof(strTargetName), TargetTranslate)) <= 0) 
	{
		ReplyToTargetError(client, TargetCount); 
		return Plugin_Handled; 
	}
	
	for (int i = 0; i < TargetCount; i++) 
	{ 
		if(TargetList[i] > 0 && TargetList[i] != client && IsClientInGame(TargetList[i]))
		{
			unMuteTargetedPlayer(client, TargetList[i]);
		}
	}
	return Plugin_Handled;
}

void DisplayUnMuteMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_UnMuteMenu);
	SetMenuTitle(menu, "Choose a player to unmute");
	SetMenuExitBackButton(menu, true);
	
	AddTargetsToMenu2(menu, 0, COMMAND_FILTER_NO_BOTS);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

int MenuHandler_UnMuteMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char info[32];
			int target;
			
			GetMenuItem(menu, param2, info, sizeof(info));
			int userid = StringToInt(info);
			
			if ((target = GetClientOfUserId(userid)) == 0)
			{
				PrintToChat(param1, "[SM] Player no longer available");
			}
			else
			{
				unMuteTargetedPlayer(param1, target);
			}
		}
	}
	
	return 0;
}

void unMuteTargetedPlayer(int client, int target)
{
	SetListenOverride(client, target, Listen_Default);
	PrintToChat(client, "\x04[Self-Mute]\x01 You have self-unmuted:\x04 %N", target);
	g_MuteList[client][target] = 0;
}

//====================================================================================================

Action checkmute(int client, int args)
{
	if (client == 0)
	{
		PrintToChat(client, "[SM] Cannot use command from RCON");
		return Plugin_Handled;
	}
	
	char nickNames[256];
	strcopy(nickNames, sizeof(nickNames), "No players found.");
	bool firstNick = true;
	
	for (int id = 1; id <= MaxClients; id++)
	{
		if (IsClientInGame(id))
		{
			if(GetListenOverride(client, id) == Listen_No)
			{
				if(firstNick)
				{
					firstNick = false;
					FormatEx(nickNames, sizeof(nickNames), "%N", id);
				}
				else
					Format(nickNames, sizeof(nickNames), "%s, %N", nickNames, id);
			}
		}
	}
	
	PrintToChat(client, "\x04[Self-Mute]\x01 List of self-muted:\x04 %s", nickNames);
	
	return Plugin_Handled;
}
