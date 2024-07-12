#pragma semicolon 1

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#pragma newdecls required

#define TABLE_NAME	"mb_bans"
#define BANS_CACHE

Database db;
#if defined BANS_CACHE
StringMap hBansCache;
#endif

public Plugin myinfo =
{
	name = "Basic Ban Commands (MySQL)",
	author = "AlliedModders LLC (MySQL by Accelerator)",
	description = "Basic Banning Commands",
	version = SOURCEMOD_VERSION,
	url = "https://github.com/accelerator74/sp-plugins"
};

TopMenu hTopMenu;

enum struct PlayerInfo {
	int banTarget;
	int banTargetUserId;
	int banTime;
	int isWaitingForChatReason;
}

PlayerInfo playerinfo[MAXPLAYERS+1];

KeyValues g_hKvBanReasons;
char g_BanReasonsPath[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
	BuildPath(Path_SM, g_BanReasonsPath, sizeof(g_BanReasonsPath), "configs/banreasons.txt");

	ConnectDB();
	LoadBanReasons();

	LoadTranslations("common.phrases");
	LoadTranslations("basebans.phrases");
	LoadTranslations("core.phrases");

	RegAdminCmd("sm_ban", Command_Ban, ADMFLAG_BAN, "sm_ban <#userid|name> <minutes|0> [reason]");
	RegAdminCmd("sm_unban", Command_Unban, ADMFLAG_UNBAN, "sm_unban <steamid>");
	RegAdminCmd("sm_addban", Command_AddBan, ADMFLAG_BAN, "sm_addban <minutes|0> <steamid> [reason]");

	//This to manage custom ban reason messages
	RegConsoleCmd("sm_abortban", Command_AbortBan, "sm_abortban");

	/* Account for late loading */
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}

#if defined BANS_CACHE
	hBansCache = new StringMap();
#endif
}

public void OnMapStart()
{
	if (db == null)
		ConnectDB();

#if defined BANS_CACHE
	char query[128];
	FormatEx(query, sizeof(query), "SELECT steamid,time FROM `%s` WHERE time = 0 OR time > %d", TABLE_NAME, GetTime());
	db.Query(GetValidBans, query);
#endif
}

public void OnConfigsExecuted()
{
	//(Re-)Load BanReasons
	LoadBanReasons();
}

public void OnClientDisconnect(int client)
{
	playerinfo[client].isWaitingForChatReason = false;
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

void SQLErrorCheckCallback(Database owner, DBResultSet hQuery, const char[] error, any data)
{
	if (hQuery == null)
		return;

	if (error[0] != '\0')
		LogError("SQL Error: %s", error);
}

#if defined BANS_CACHE
void GetValidBans(Database owner, DBResultSet hQuery, const char[] error, any data)
{
	if (hQuery == null)
		return;

	hBansCache.Clear();

	char authid[32];

	while (hQuery.FetchRow())
	{
		hQuery.FetchString(0, authid, sizeof(authid));
		hBansCache.SetValue(authid, hQuery.FetchInt(1));
	}
}
#endif

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
		ReplyToCommand(client, "[SM] Usage: sm_addban <minutes|0> <steamid> [reason]");
		return Plugin_Handled;
	}

	char arg_string[256];
	char s_time[12];
	char authid[32];

	GetCmdArgString(arg_string, sizeof(arg_string));

	int len, total_len;

	/* Get time */
	if ((len = BreakString(arg_string, s_time, sizeof(s_time))) == -1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addban <minutes|0> <steamid> [reason]");
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

	AdminId tid = FindAdminByIdentity("steam", authid);
	if (client && !CanAdminTarget(GetUserAdmin(client), tid))
	{
		ReplyToCommand(client, "[SM] %t", "No Access");
		return Plugin_Handled;
	}

	int time = StringToInt(s_time);

	LogAction(client, 
			  -1, 
			  "\"%L\" added ban (minutes \"%d\") (id \"%s\") (reason \"%s\")", 
			  client, 
			  time, 
			  authid, 
			  arg_string[total_len]);
	AddBan(client, authid, time, arg_string[total_len]);

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

	char authid[32];
	GetCmdArgString(authid, sizeof(authid));

	ReplaceString(authid, sizeof(authid), "\"", "");

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

	char query[128];
	FormatEx(query, sizeof(query), "SELECT steamid,immunity FROM `%s` WHERE steamid = '%s' LIMIT 1", TABLE_NAME, authid);
 	db.Query(PrepareUnban, query, client);

	return Plugin_Handled;
}

void AddBan(int client, const char[] authid, int time, const char[] reason)
{
	char AdminName[128];
	int immunity = GetAdmin(client, AdminName, sizeof(AdminName));

	if (time <= 0)
	{
		time = 0;
	}
	else
	{
		time = GetTime() + (time * 60);
	}

	char dbReason[255];
	db.Escape(reason, dbReason, sizeof(dbReason));

	char query[512];
	FormatEx(query, sizeof(query), "INSERT IGNORE INTO `%s` (`steamid`,`date`,`time`,`reason`,`admin`,`immunity`) VALUES ('%s','%d','%d','%s','%s','%i')", TABLE_NAME, authid, GetTime(), time, dbReason, AdminName, immunity);
	db.Query(SQLErrorCheckCallback, query);

#if defined BANS_CACHE
	hBansCache.SetValue(authid, time);
#endif
}

#if defined BANS_CACHE
public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	if (!IsFakeClient(client))
	{
		char authid[32];

		if (GetClientAuthId(client, AuthId_Steam2, authid, sizeof(authid)))
		{
			int time;

			if (hBansCache.GetValue(authid, time))
			{
				if (!time)
				{
					Format(rejectmsg, maxlen, "%T", "Permabanned player", client, authid);
					return false;
				}

				time -= GetTime();

				if (time > 0)
				{
					Format(rejectmsg, maxlen, "%T", "Banned player", client, authid, GetTimeInMinutes(time));
					return false;
				}

				hBansCache.Remove(authid);
			}
		}
	}

	return true;
}
#endif

public void OnClientAuthorized(int client, const char[] auth)
{
	if (IsFakeClient(client))
		return;

	if (GetClientTime(client) > 10.0)
		return;

	char ip[24];
	GetClientIP(client, ip, sizeof(ip));

	char query[192];
	FormatEx(query, sizeof(query), "SELECT steamid,time,reason,date FROM `%s` WHERE steamid = '%s' OR ip = '%s' LIMIT 1", TABLE_NAME, auth, ip);
 	db.Query(CheckClient, query, GetClientUserId(client));
}

void CheckClient(Database owner, DBResultSet hQuery, const char[] error, int client)
{
	if (((client = GetClientOfUserId(client)) == 0) || hQuery == null)
		return;

	if (!IsClientConnected(client))
		return;

	int time;
	char authid[32], reason[255];

	if (hQuery.FetchRow())
	{
		hQuery.FetchString(0, authid, sizeof(authid));
		time = hQuery.FetchInt(1);

		if (!time)
		{
			if (hQuery.FetchString(2, reason, sizeof(reason)))
			{
				KickClient(client, "%t", "Permabanned player reason", authid, reason);
			}
			else
			{
				KickClient(client, "%t", "Permabanned player", authid);
			}
		}
		else if (time > GetTime())
		{
			if (hQuery.FetchString(2, reason, sizeof(reason)))
			{
				KickClient(client, "%t", "Banned player reason", authid, GetTimeInMinutes(time - hQuery.FetchInt(3)), reason);
			}
			else
			{
				KickClient(client, "%t", "Banned player", authid, GetTimeInMinutes(time - hQuery.FetchInt(3)));
			}
		}
		else
		{
			char query[128];
			FormatEx(query, sizeof(query), "DELETE FROM `%s` WHERE steamid = '%s'", TABLE_NAME, authid);
			db.Query(SQLErrorCheckCallback, query);
		}
	}
}

void PrepareUnban(Database owner, DBResultSet hQuery, const char[] error, int client)
{
	if (hQuery == null)
		return;

	if (hQuery.FetchRow())
	{
		if (client)
		{
			int immunity;
			AdminId admin_id = GetUserAdmin(client);

			if (admin_id != INVALID_ADMIN_ID)
				immunity = admin_id.ImmunityLevel;
			else
				immunity = 0;

			if (hQuery.FetchInt(1) > immunity)
			{
				PrintToChat(client, "[SM] %t", "Unable to target");
				return;
			}
		}

		char query[128], authid[32];
		hQuery.FetchString(0, authid, sizeof(authid));
		FormatEx(query, sizeof(query), "DELETE FROM `%s` WHERE steamid = '%s'", TABLE_NAME, authid);
		db.Query(SQLErrorCheckCallback, query);

#if defined BANS_CACHE
		hBansCache.Remove(authid);
#endif

		LogAction(client, -1, "\"%L\" removed ban (filter \"%s\")", client, authid);

		if (!client)
		{
			PrintToServer("[SM] %t", "Removed bans matching", authid);
		}
		else
		{
			PrintToChat(client, "[SM] %t", "Removed bans matching", authid);
		}
	}
}

void PrepareBan(int client, int target, int time, const char[] reason)
{
	int originalTarget = GetClientOfUserId(playerinfo[client].banTargetUserId);

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
	GetClientAuthId(target, AuthId_Steam2, authid, sizeof(authid));
	GetClientName(target, name, sizeof(name));
	GetClientIP(target, ip, sizeof(ip));

	LogAction(client, target, "\"%L\" banned \"%L\" (minutes \"%d\") (reason \"%s\")", client, target, time, reason);

	if (time <= 0)
	{
		time = 0;
		if (reason[0] == '\0') {
			ShowActivity(client, "%t", "Permabanned player", name);
		} else {
			ShowActivity(client, "%t", "Permabanned player reason", name, reason);
		}
	} else {
		if (reason[0] == '\0') {
			ShowActivity(client, "%t", "Banned player", name, time);
		} else {
			ShowActivity(client, "%t", "Banned player reason", name, time, reason);
		}
		time = GetTime() + (time * 60);
	}

	db.Escape(name, name, sizeof(name));

	char AdminName[128];
	int immunity = GetAdmin(client, AdminName, sizeof(AdminName));

	char dbReason[255];
	db.Escape(reason, dbReason, sizeof(dbReason));

	char query[512];
	FormatEx(query, sizeof(query), "INSERT IGNORE INTO `%s` (`name`,`ip`,`steamid`,`date`,`time`,`reason`,`admin`,`immunity`) VALUES ('%s','%s','%s','%d','%d','%s','%s','%i')", TABLE_NAME, name, ip, authid, GetTime(), time, dbReason, AdminName, immunity);
	db.Query(SQLErrorCheckCallback, query);

#if defined BANS_CACHE
	hBansCache.SetValue(authid, time);
#endif

	if (!time)
	{
		if (reason[0] != '\0')
		{
			KickClient(target, "%t", "Permabanned player reason", authid, reason);
		}
		else
		{
			KickClient(target, "%t", "Permabanned player", authid);
		}
	}
	else
	{
		if (reason[0] != '\0')
		{
			KickClient(target, "%t", "Banned player reason", authid, GetTimeInMinutes(time - GetTime()), reason);
		}
		else
		{
			KickClient(target, "%t", "Banned player", authid, GetTimeInMinutes(time - GetTime()));
		}
	}
}

int GetAdmin(int client, char[] buffer, int maxlen)
{
	int immunity = 0;

	if (client)
	{
		AdminId admin_id = GetUserAdmin(client);
		if (admin_id != INVALID_ADMIN_ID)
		{
			if (!admin_id.GetUsername(buffer, maxlen))
				strcopy(buffer, maxlen, "Unknown");

			immunity = admin_id.ImmunityLevel;
		}
		else
		{
			strcopy(buffer, maxlen, "Unknown");
		}
	}
	else
	{
		strcopy(buffer, maxlen, "Banned by server");
	}

	return immunity;
}

int GetTimeInMinutes(int time)
{
	return RoundToCeil(time / 60.0);
}

void DisplayBanTargetMenu(int client)
{
	Menu menu = new Menu(MenuHandler_BanPlayerList);

	char title[100];
	Format(title, sizeof(title), "%T:", "Ban player", client);
	menu.SetTitle(title);
	menu.ExitBackButton = CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false);

	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayBanTimeMenu(int client)
{
	Menu menu = new Menu(MenuHandler_BanTimeList);

	char title[100];
	Format(title, sizeof(title), "%T: %N", "Ban player", client, playerinfo[client].banTarget);
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
	Format(title, sizeof(title), "%T: %N", "Ban reason", client, playerinfo[client].banTarget);
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
	playerinfo[param].isWaitingForChatReason = false;

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
			playerinfo[param1].isWaitingForChatReason = true;
			PrintToChat(param1, "[SM] %t", "Custom ban reason explanation", "sm_abortban");
		}
		else
		{
			char info[64];

			menu.GetItem(param2, info, sizeof(info));

			PrepareBan(param1, playerinfo[param1].banTarget, playerinfo[param1].banTime, info);
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
			playerinfo[param1].banTarget = target;
			playerinfo[param1].banTargetUserId = userid;
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
		playerinfo[param1].banTime = StringToInt(info);

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

	playerinfo[client].banTargetUserId = GetClientUserId(target);

	int time = StringToInt(s_time);
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
	if(playerinfo[client].isWaitingForChatReason)
	{
		playerinfo[client].isWaitingForChatReason = false;
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
	if(playerinfo[client].isWaitingForChatReason && !IsChatTrigger())
	{
		playerinfo[client].isWaitingForChatReason = false;
		PrepareBan(client, playerinfo[client].banTarget, playerinfo[client].banTime, sArgs);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}
