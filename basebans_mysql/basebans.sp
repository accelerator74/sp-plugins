#pragma semicolon 1

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#pragma newdecls required

#define BAN_DETAILS_URL "http://site"
#define TABLE_NAME "mb_bans"

Database db;

public Plugin myinfo =
{
	name = "Basic Ban Commands (MySQL)",
	author = "AlliedModders LLC (MySQL by Accelerator)",
	description = "Basic Banning Commands",
	version = SOURCEMOD_VERSION,
	url = "https://github.com/accelerator74/sp-plugins"
};

TopMenu hTopMenu;

int g_BanTarget[MAXPLAYERS+1];
int g_BanTargetUserId[MAXPLAYERS+1];
int g_BanTime[MAXPLAYERS+1];

int g_IsWaitingForChatReason[MAXPLAYERS+1];
KeyValues g_hKvBanReasons;
char g_BanReasonsPath[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
	BuildPath(Path_SM, g_BanReasonsPath, sizeof(g_BanReasonsPath), "configs/banreasons.txt");

	LoadBanReasons();

	LoadTranslations("common.phrases");
	LoadTranslations("basebans.phrases");
	LoadTranslations("core.phrases");

	ConnectDB();
	RegAdminCmd("sm_ban", Command_Ban, ADMFLAG_BAN, "sm_ban <steamid|name> <minutes|0> [reason]");
	RegAdminCmd("sm_unban", Command_Unban, ADMFLAG_UNBAN, "sm_unban <steamid>");
	RegAdminCmd("sm_addban", Command_AddBan, ADMFLAG_BAN, "sm_addban <time> <steamid> [reason]");
	
	//This to manage custom ban reason messages
	RegConsoleCmd("sm_abortban", Command_AbortBan, "sm_abortban");
	
	/* Account for late loading */
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}
}

public void OnMapStart()
{
	//(Re-)Load BanReasons
	LoadBanReasons();
	
	if (db == null)
		ConnectDB();
}

public void OnClientDisconnect(int client)
{
	g_IsWaitingForChatReason[client] = false;
}

void LoadBanReasons()
{
	delete g_hKvBanReasons;

	g_hKvBanReasons = new KeyValues("banreasons");

	if (g_hKvBanReasons.ImportFromFile(g_BanReasonsPath))
	{
		char sectionName[255];
		if (!g_hKvBanReasons.GetSectionName(sectionName, sizeof(sectionName)))
		{
			SetFailState("Error in %s: File corrupt or in the wrong format", g_BanReasonsPath);
			return;
		}

		if (strcmp(sectionName, "banreasons") != 0)
		{
			SetFailState("Error in %s: Couldn't find 'banreasons'", g_BanReasonsPath);
			return;
		}
		
		//Reset kvHandle
		g_hKvBanReasons.Rewind();
	} else {
		SetFailState("Error in %s: File not found, corrupt or in the wrong format", g_BanReasonsPath);
		return;
	}
}

void ConnectDB()
{
	if (SQL_CheckConfig("default"))
	{
		char Error[256];
		db = SQL_DefConnect(Error, sizeof(Error), true);

		if (db == null)
			LogError("Failed to connect to database: %s", Error);
		else
		{
			if (!db.SetCharset("utf8"))
			{
				SQL_GetError(db, Error, sizeof(Error));
				LogError("SQL Error: %s", Error);
			}
		}
	}
	else
		LogError("Database.cfg missing 'default' entry!");
}

void SQLErrorCheckCallback(Database hDB, DBResultSet hResults, const char[] sError, any data)
{
	if (db == null)
		return;

	if(sError[0] != '\0')
		LogError("SQL Error: %s", sError);
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	/* Block us from being called twice */
	if (topmenu == hTopMenu)
	{
		return;
	}
	
	/* Save the Handle */
	hTopMenu = topmenu;
	
	/* Find the "Player Commands" category */
	TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		hTopMenu.AddItem("sm_ban", AdminMenu_Ban, player_commands, "sm_ban", ADMFLAG_BAN);
	}
}

Action Command_AddBan(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addban <time> <steamid> [reason]");
		return Plugin_Handled;
	}

	char arg_string[256];
	char time[50];
	char authid[32];

	GetCmdArgString(arg_string, sizeof(arg_string));

	int len, total_len;

	/* Get time */
	if ((len = BreakString(arg_string, time, sizeof(time))) == -1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addban <time> <steamid> [reason]");
		return Plugin_Handled;
	}	
	total_len += len;

	/* Get steamid */
	if ((len = BreakString(arg_string[total_len], authid, sizeof(authid))) != -1)
	{
		total_len += len;
	}
	else
	{
		total_len = 0;
		arg_string[0] = '\0';
	}

	/* Verify steamid */
	bool idValid = false;
	if (!strncmp(authid, "STEAM_", 6) && authid[7] == ':')
		idValid = true;
	else if (!strncmp(authid, "[U:", 3))
		idValid = true;
	
	if (!idValid)
	{
		ReplyToCommand(client, "[SM] %t", "Invalid SteamID specified");
		return Plugin_Handled;
	}

	int minutes = StringToInt(time);

	LogAction(client, 
			  -1, 
			  "\"%L\" added ban (minutes \"%d\") (id \"%s\") (reason \"%s\")", 
			  client, 
			  minutes, 
			  authid, 
			  arg_string[total_len]);
	
	AddBan(client, authid, minutes, arg_string[total_len]);

	ReplyToCommand(client, "[SM] %t", "Ban added");

	return Plugin_Handled;
}

Action Command_Unban(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_unban <steamid>");
		return Plugin_Handled;
	}

	char arg[50];
	GetCmdArgString(arg, sizeof(arg));

	ReplaceString(arg, sizeof(arg), "\"", "");	

	/* Verify steamid */
	bool idValid = false;
	if (!strncmp(arg, "STEAM_", 6) && arg[7] == ':')
		idValid = true;
	else if (!strncmp(arg, "[U:", 3))
		idValid = true;
	
	if (!idValid)
	{
		ReplyToCommand(client, "[SM] %t", "Invalid SteamID specified");
		return Plugin_Handled;
	}

	char query[128];
	FormatEx(query, sizeof(query), "SELECT steamid,immunity FROM `%s` WHERE steamid = '%s' LIMIT 1", TABLE_NAME, arg);
 	db.Query(PrepareUnban, query, client);

	return Plugin_Handled;
}

void AddBan(int client, const char[] authid, int time, const char[] reason)
{
	char AdminName[MAX_NAME_LENGTH];
	int immunity;
	if (client)
	{
		AdminId admin_id = GetUserAdmin(client);
		if (admin_id != INVALID_ADMIN_ID)
		{
			if (!admin_id.GetUsername(AdminName, sizeof(AdminName)))
				strcopy(AdminName, sizeof(AdminName), "Unknown");
			
			immunity = admin_id.ImmunityLevel;
		}
		else
		{
			strcopy(AdminName, sizeof(AdminName), "Unknown");
			immunity = 0;
		}
	}
	else
	{
		strcopy(AdminName, sizeof(AdminName), "Banned by server");
		immunity = 0;
	}
	int BanTime = 0;
	
	if (time <= 0)
	{
		BanTime = 0;
	}
	else
	{
		BanTime = GetTime() + (time * 60);
	}
	
	char dbReason[192];
	db.Escape(reason, dbReason, sizeof(dbReason));
	
	char query[512];
	FormatEx(query, sizeof(query), "INSERT IGNORE INTO `%s` (`name`, `ip`, `steamid`, `date`, `time`, `reason`, `admin`, `immunity`) VALUES ('%s', '%s', '%s', '%d', '%d', '%s', '%s', '%i')", TABLE_NAME, "", "", authid, GetTime(), BanTime, dbReason, AdminName, immunity);
	db.Query(SQLErrorCheckCallback, query);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if(IsFakeClient(client))
		return;

	if (GetClientTime(client) > 10.0)
		return;

	char ip[32];
	GetClientIP(client, ip, sizeof(ip));

	char query[192];
	FormatEx(query, sizeof(query), "SELECT steamid,time FROM `%s` WHERE steamid = '%s' OR ip = '%s' LIMIT 1", TABLE_NAME, auth, ip);
 	db.Query(CheckClient, query, GetClientUserId(client));
}

void CheckClient(Database owner, DBResultSet hQuery, const char[] error, any client)
{
	if (((client = GetClientOfUserId(client)) == 0) || hQuery == null)
		return;
		
	if (!IsClientConnected(client))
		return;
		
	while (hQuery.FetchRow())
	{
		int ban_time = hQuery.FetchInt(1);
		if (ban_time == 0)
		{
			KickClient(client,"You have been Banned.\nSee details: %s", BAN_DETAILS_URL);
		}
		else if (ban_time > GetTime())
		{
			KickClient(client,"You have been Temporary Banned.\nSee details: %s", BAN_DETAILS_URL);
		}
		else
		{
			char query[128], SteamID[54];
			hQuery.FetchString(0, SteamID, sizeof(SteamID));
			FormatEx(query, sizeof(query), "DELETE FROM `%s` WHERE steamid = '%s'", TABLE_NAME, SteamID);
			db.Query(SQLErrorCheckCallback, query);
		}
	}
}

void PrepareUnban(Database owner, DBResultSet hQuery, const char[] error, any client)
{
	if (hQuery == null)
		return;
		
	while (hQuery.FetchRow())
	{
		if (client)
		{
			int immunity;
			AdminId admin_id = GetUserAdmin(client);
			
			if (admin_id != INVALID_ADMIN_ID)
				immunity = admin_id.ImmunityLevel;
			else
				immunity = 0;
			
			int immunity_sql = hQuery.FetchInt(1);
		
			if (immunity_sql > immunity)
			{
				PrintToChat(client, "[SM] You have an administrator (%i) level lower than the administrator (%i) who banned this steamid!", immunity, immunity_sql);
				return;
			}
		}
		
		char query[128], SteamID[54];
		hQuery.FetchString(0, SteamID, sizeof(SteamID));
		FormatEx(query, sizeof(query), "DELETE FROM `%s` WHERE steamid = '%s'", TABLE_NAME, SteamID);
		db.Query(SQLErrorCheckCallback, query);
		
		LogAction(client, -1, "\"%L\" removed ban (filter \"%s\")", client, SteamID);
		
		if (client == 0)
		{
			PrintToServer("[SM] %t", "Removed bans matching", SteamID);
		}
		else
		{
			PrintToChat(client, "[SM] %t", "Removed bans matching", SteamID);
		}
	}
}

void PrepareBan(int client, int target, int time, const char[] reason)
{
	int originalTarget = GetClientOfUserId(g_BanTargetUserId[client]);

	if (originalTarget != target)
	{
		if (client == 0)
		{
			PrintToServer("[SM] %t", "Player no longer available");
		}
		else
		{
			PrintToChat(client, "[SM] %t", "Player no longer available");
		}

		return;
	}

	char authid[32], name[MAX_NAME_LENGTH], ip[24];
	int BanTime = 0;
	GetClientAuthId(target, AuthId_Steam2, authid, sizeof(authid));
	GetClientName(target, name, sizeof(name));
	GetClientIP(target, ip, sizeof(ip));

	if (time <= 0)
	{
		BanTime = 0;
		if (reason[0] == '\0')
		{
			ShowActivity(client, "%t", "Permabanned player", name);
		} else {
			ShowActivity(client, "%t", "Permabanned player reason", name, reason);
		}
	} else {
		BanTime = GetTime() + (time * 60);
		if (reason[0] == '\0')
		{
			ShowActivity(client, "%t", "Banned player", name, time);
		} else {
			ShowActivity(client, "%t", "Banned player reason", name, time, reason);
		}
	}

	LogAction(client, target, "\"%L\" banned \"%L\" (minutes \"%d\") (reason \"%s\")", client, target, time, reason);
	
	char FixedName[128];
	db.Escape(name, FixedName, sizeof(FixedName));
	
	char AdminName[MAX_NAME_LENGTH];
	int immunity;
	if (client)
	{
		AdminId admin_id = GetUserAdmin(client);
		if (admin_id != INVALID_ADMIN_ID)
		{
			if (!admin_id.GetUsername(AdminName, sizeof(AdminName)))
				strcopy(AdminName, sizeof(AdminName), "Unknown");
			
			immunity = admin_id.ImmunityLevel;
		}
		else
		{
			strcopy(AdminName, sizeof(AdminName), "Unknown");
			immunity = 0;
		}
	}
	else
	{
		strcopy(AdminName, sizeof(AdminName), "Banned by server");
		immunity = 0;
	}
	
	char dbReason[192];
	db.Escape(reason, dbReason, sizeof(dbReason));
	
	char query[512];
	FormatEx(query, sizeof(query), "INSERT IGNORE INTO `%s` (`name`, `ip`, `steamid`, `date`, `time`, `reason`, `admin`, `immunity`) VALUES ('%s', '%s', '%s', '%d', '%d', '%s', '%s', '%i')", TABLE_NAME, FixedName, ip, authid, GetTime(), BanTime, dbReason, AdminName, immunity);
	db.Query(SQLErrorCheckCallback, query);
	
	if (reason[0] == '\0')
	{
		ServerCommand("kickid %d \"You have been Banned\"", GetClientUserId(target));
	}
	else
	{
		ServerCommand("kickid %d \"You have been Banned because %s\"", GetClientUserId(target), reason);
	}
}

void DisplayBanTargetMenu(int client)
{
	Menu menu = new Menu(MenuHandler_BanPlayerList);

	char title[100];
	Format(title, sizeof(title), "%T:", "Ban player", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;

	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayBanTimeMenu(int client)
{
	Menu menu = new Menu(MenuHandler_BanTimeList);

	char title[100];
	Format(title, sizeof(title), "%T: %N", "Ban player", client, g_BanTarget[client]);
	menu.SetTitle(title);
	menu.ExitBackButton = true;

	menu.AddItem("30", "30 Minutes");
	menu.AddItem("60", "1 Hour");
	menu.AddItem("240", "4 Hours");
	menu.AddItem("1440", "1 Day");
	menu.AddItem("10080", "1 Week");
	menu.AddItem("43200", "1 Month");
	menu.AddItem("0", "Permanent");

	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayBanReasonMenu(int client)
{
	Menu menu = new Menu(MenuHandler_BanReasonList);

	char title[100];
	Format(title, sizeof(title), "%T: %N", "Ban reason", client, g_BanTarget[client]);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	//Add custom chat reason entry first
	menu.AddItem("", "Custom reason (type in chat)");
	
	//Loading configurable entries from the kv-file
	char reasonName[100];
	char reasonFull[255];
	
	//Iterate through the kv-file
	g_hKvBanReasons.GotoFirstSubKey(false);
	do
	{
		g_hKvBanReasons.GetSectionName(reasonName, sizeof(reasonName));
		g_hKvBanReasons.GetString(NULL_STRING, reasonFull, sizeof(reasonFull));
		
		//Add entry
		menu.AddItem(reasonFull, reasonName);
		
	} while (g_hKvBanReasons.GotoNextKey(false));
	
	//Reset kvHandle
	g_hKvBanReasons.Rewind();

	menu.Display(client, MENU_TIME_FOREVER);
}

void AdminMenu_Ban(TopMenu topmenu,
							  TopMenuAction action,
							  TopMenuObject object_id,
							  int param,
							  char[] buffer,
							  int maxlength)
{
	//Reset chat reason first
	g_IsWaitingForChatReason[param] = false;
	
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Ban player", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayBanTargetMenu(param);
	}
}

int MenuHandler_BanReasonList(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		if(param2 == 0)
		{
			//Chat reason
			g_IsWaitingForChatReason[param1] = true;
			PrintToChat(param1, "[SM] %t", "Custom ban reason explanation", "sm_abortban");
		}
		else
		{
			char info[64];
			
			menu.GetItem(param2, info, sizeof(info));
			
			PrepareBan(param1, g_BanTarget[param1], g_BanTime[param1], info);
		}
	}
	
	return 0;
}

int MenuHandler_BanPlayerList(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32], name[32];
		int userid, target;

		menu.GetItem(param2, info, sizeof(info), _, name, sizeof(name));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			g_BanTarget[param1] = target;
			g_BanTargetUserId[param1] = userid;
			DisplayBanTimeMenu(param1);
		}
	}

	return 0;
}

int MenuHandler_BanTimeList(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];

		menu.GetItem(param2, info, sizeof(info));
		g_BanTime[param1] = StringToInt(info);

		DisplayBanReasonMenu(param1);
	}

	return 0;
}

Action Command_Ban(int client, int args)
{
	if (args < 2)
	{
		if ((GetCmdReplySource() == SM_REPLY_TO_CHAT) && (client != 0) && (args == 0))
		{
			DisplayBanTargetMenu(client);
		}
		else
		{
			ReplyToCommand(client, "[SM] Usage: sm_ban <#userid|name> <minutes|0> [reason]");
		}
		
		return Plugin_Handled;
	}

	int len, next_len;
	char Arguments[256];
	GetCmdArgString(Arguments, sizeof(Arguments));

	char arg[65];
	len = BreakString(Arguments, arg, sizeof(arg));

	int target = FindTarget(client, arg, true);
	if (target == -1)
	{
		return Plugin_Handled;
	}

	char s_time[12];
	if ((next_len = BreakString(Arguments[len], s_time, sizeof(s_time))) != -1)
	{
		len += next_len;
	}
	else
	{
		len = 0;
		Arguments[0] = '\0';
	}

	int time = StringToInt(s_time);

	g_BanTargetUserId[client] = GetClientUserId(target);

	PrepareBan(client, target, time, Arguments[len]);

	return Plugin_Handled;
}

Action Command_AbortBan(int client, int args)
{
	if(!CheckCommandAccess(client, "sm_ban", ADMFLAG_BAN))
	{
		ReplyToCommand(client, "[SM] %t", "No Access");
		return Plugin_Handled;
	}
	if(g_IsWaitingForChatReason[client])
	{
		g_IsWaitingForChatReason[client] = false;
		ReplyToCommand(client, "[SM] %t", "AbortBan applied successfully");
	}
	else
	{
		ReplyToCommand(client, "[SM] %t", "AbortBan not waiting for custom reason");
	}
	
	return Plugin_Handled;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(g_IsWaitingForChatReason[client])
	{
		g_IsWaitingForChatReason[client] = false;
		PrepareBan(client, g_BanTarget[client], g_BanTime[client], sArgs);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}
