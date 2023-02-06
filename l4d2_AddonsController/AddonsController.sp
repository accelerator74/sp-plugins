#pragma semicolon 1

#include <sourcemod>
#tryinclude <left4downtown>

#if !defined _l4do_included
#tryinclude <left4dhooks>
#if !defined _l4dh_included
#error "Required Left4Downtown2 or Left4Dhooks!"
#endif
#endif

#undef REQUIRE_PLUGIN
#include <adminmenu>

new String:datafilepath[PLATFORM_MAX_PATH];
new String:datalogpath[PLATFORM_MAX_PATH];

new Handle:g_hKV = INVALID_HANDLE;
new Handle:hTopMenu = INVALID_HANDLE;
new g_Target[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "Addons Controller",
	author = "Accelerator",
	description = "Enable/Disable addons Players",
	version = "2.3",
	url = "https://github.com/accelerator74/sp-plugins"
};

public OnPluginStart()
{
	LoadTranslations("common.phrases");

	BuildPath(Path_SM, datafilepath, sizeof(datafilepath), "data/AddonsController.txt");
	BuildPath(Path_SM, datalogpath, sizeof(datalogpath), "logs/AddonsController.log");
	
	RegAdminCmd("sm_banaddons", Command_BanAddons, ADMFLAG_BAN, "sm_banaddons <steamid>");
	RegAdminCmd("sm_unbanaddons", Command_UnbanAddons, ADMFLAG_UNBAN, "sm_unbanaddons <steamid>");
	
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
	
	g_hKV = CreateKeyValues("AddonsController");
	FileToKeyValues(g_hKV, datafilepath);
}

public OnLibraryRemoved(const String:name[]) {
    if (StrEqual(name, "adminmenu")) 
	{
		hTopMenu = INVALID_HANDLE;
    }
}

public OnAdminMenuReady(Handle:topmenu)
{
	/* Block us from being called twice */
	if (topmenu == hTopMenu)
	{
		return;
	}
	
	/* Save the Handle */
	hTopMenu = topmenu;
	
	/* Find the "Player Commands" category */
	new TopMenuObject:player_commands = FindTopMenuCategory(hTopMenu, ADMINMENU_PLAYERCOMMANDS);

	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(hTopMenu, "sm_banaddons", TopMenuObject_Item, AdminMenu_BanAddons, player_commands, "sm_banaddons", ADMFLAG_BAN);
	}
}

public AdminMenu_BanAddons(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength) 
{
    switch (action) 
	{
		case TopMenuAction_DisplayOption: 
		{
			Format(buffer, maxlength, "Addons Controller");
		}
		case TopMenuAction_SelectOption: 
		{
			DisplayPlayerMenu(param);
		}
    }
}

stock DisplayPlayerMenu(client) 
{
    new Handle:menu = CreateMenu(MenuHandler_Player);

    decl String:title[100];
    Format(title, sizeof(title), "Addons Controller:");
    SetMenuTitle(menu, title);
    SetMenuExitBackButton(menu, true);
    AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Player(Handle:menu, MenuAction:action, param1, param2) 
{
    switch (action) 
	{
		case MenuAction_End: 
		{
			CloseHandle(menu);
		}
		case MenuAction_Cancel: 
		{
			if (param2 == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE) 
			{
				DisplayTopMenu(hTopMenu, param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_Select:
		{
			decl String:info[32];

			GetMenuItem(menu, param2, info, sizeof(info));
			new userid = StringToInt(info);
			new target = GetClientOfUserId(userid);

			if (!target) 
			{
				PrintToChat(param1, "%t", "Player no longer available");
			}
			else if (!CanUserTarget(param1, target)) 
			{
				PrintToChat(param1, "%t", "Unable to target");
			}
			else 
			{
				g_Target[param1] = target;
				DisplayTypesMenu(param1, target);
			}
		}
    }
}

stock DisplayTypesMenu(client, target) 
{
    new Handle:menu = CreateMenu(MenuHandler_Types);

    decl String:title[100];
    Format(title, sizeof(title), "Addons Controller:");
    SetMenuTitle(menu, title);
    SetMenuExitBackButton(menu, true);

    if (GetFileData(target)) 
	{
		AddMenuItem(menu, "0", "Enable Addons");
    }
    else 
	{
		AddMenuItem(menu, "1", "Disable Addons");
    }
    
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Types(Handle:menu, MenuAction:action, param1, param2) 
{
    switch (action) 
	{
		case MenuAction_End: 
		{
			CloseHandle(menu);
		}
		case MenuAction_Cancel:
		{
			if (param1 == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE) 
			{
				DisplayTopMenu(hTopMenu, param1, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_Select:
		{
			decl String:info[32];
			GetMenuItem(menu, param2, info, sizeof(info));

			PerformAddons(param1, g_Target[param1], StringToInt(info));
		}
    }
}

stock PerformAddons(client, target, type)
{
    switch (type) 
	{
		case 0: 
		{
			SetFileData(target, client, "block", "0");
			if (client) 
			{
				ShowActivity2(client, "[SM] ", "Addons Enable for %N", target);
			}
		}
		case 1: 
		{
			SetFileData(target, client, "block", "1");
			if (client) 
			{
				ShowActivity2(client, "[SM] ", "Addons Disable for %N", target);
			}
		}
    }
}

public Action:L4D2_OnClientDisableAddons(const String:SteamID[])
{
	if (GetFileData(0, SteamID)) 
		return Plugin_Continue;
	
	return Plugin_Handled;
}

public Action:Command_BanAddons(client, args) 
{
	if (args < 1) 
	{
		ReplyToCommand(client, "[SM] Usage: sm_banaddons <steamid>");
		return Plugin_Handled;
	}

	decl String:arg[50];
	GetCmdArgString(arg, sizeof(arg));

	ReplaceString(arg, sizeof(arg), "\"", "");	

	bool idValid = false;
	if (!strncmp(arg, "STEAM_", 6) && arg[7] == ':')
		idValid = true;
	else if (!strncmp(arg, "[U:", 3))
		idValid = true;
	
	if (!idValid)
	{
		ReplyToCommand(client, "[SM] This is not SteamID!");
		return Plugin_Handled;
	}

	SetFileData(0, client, "block", "1", arg);
	ShowActivity2(client, "[SM] ", "Addons Disable for %s", arg);
	return Plugin_Handled;
}

public Action:Command_UnbanAddons(client, args) 
{
	if (args < 1) 
	{
		ReplyToCommand(client, "[SM] Usage: sm_unbanaddons <steamid>");
		return Plugin_Handled;
	}

	decl String:arg[50];
	GetCmdArgString(arg, sizeof(arg));

	ReplaceString(arg, sizeof(arg), "\"", "");	

	bool idValid = false;
	if (!strncmp(arg, "STEAM_", 6) && arg[7] == ':')
		idValid = true;
	else if (!strncmp(arg, "[U:", 3))
		idValid = true;
	
	if (!idValid)
	{
		ReplyToCommand(client, "[SM] This is not SteamID!");
		return Plugin_Handled;
	}

	SetFileData(0, client, "block", "0", arg);
	ShowActivity2(client, "[SM] ", "Addons Enable for %s", arg);
	return Plugin_Handled;
}

stock GetFileData(client, const String:data[] = "")
{
	decl String:SteamID[50];
	if (client && data[0] == '\0')
	{
		GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID));
	}
	else
	{
		strcopy(SteamID, sizeof(SteamID), data);
	}
	
	KvRewind(g_hKV);
	if (KvJumpToKey(g_hKV, SteamID))
		return true;
	
	return false;
}

stock SetFileData(client, admin, const String:key[], String:value[], String:SteamID[50] = "")
{
	if (SteamID[0] == '\0' && client)
	{
		GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID));
	}
	
	KvRewind(g_hKV);
	if (StrEqual(value, "1"))
	{
		KvJumpToKey(g_hKV, SteamID, true);
		KvSetString(g_hKV, key, value);
		KvRewind(g_hKV);
		LogToFileEx(datalogpath, "[%N]: Addons Disable for %s", admin, SteamID);
	}
	else
	{
		if (KvJumpToKey(g_hKV, SteamID))
		{
			KvDeleteThis(g_hKV);
			KvRewind(g_hKV);
			LogToFileEx(datalogpath, "[%N]: Addons Enable for %s", admin, SteamID);
		}
	}
	KeyValuesToFile(g_hKV, datafilepath);
	CloseHandle(g_hKV);
	
	g_hKV = CreateKeyValues("AddonsController");
	FileToKeyValues(g_hKV, datafilepath);
}