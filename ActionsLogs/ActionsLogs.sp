#pragma semicolon 1
#include <sourcemod>

char fileCmds[PLATFORM_MAX_PATH];
char fileChat[PLATFORM_MAX_PATH];
char adminCmds[PLATFORM_MAX_PATH];

StringMap hCommandsTrie;

public Plugin myinfo =
{
	name = "Actions Logs",
	author = "Accelerator",
	description = "Logs of chat, commands and actions of administrators",
	version = "2.0",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	BuildPath(Path_SM, fileCmds, sizeof(fileCmds), "logs/cmds.log");
	BuildPath(Path_SM, fileChat, sizeof(fileChat), "logs/chat.log");
	
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof(buffer), "logs/admins");
	if (!DirExists(buffer))
	{
		CreateDirectory(buffer, 511);
	}
	
	hCommandsTrie = new StringMap();
}

public void OnMapStart()
{
	hCommandsTrie.Clear();
	
	char name[128];
	CommandIterator it = new CommandIterator();
	
	while (it.Next())
	{
		it.GetName(name, sizeof(name));
		hCommandsTrie.SetValue(name, it.Flags);
	}
	
	delete it;
}

public Action OnClientCommand(int client, int args)
{
	char CommandName[128];
	GetCmdArg(0, CommandName, sizeof(CommandName));
	
	int flags;
	if (!hCommandsTrie.GetValue(CommandName, flags))
		return Plugin_Continue;

	AdminId admin_id = GetUserAdmin(client);
	
	if (args > 0)
	{
		char argstring[255];
		GetCmdArgString(argstring, sizeof(argstring));
		LogToFileEx(fileCmds, "%N - %s [%s]", client, CommandName, argstring);
		
		if (flags && admin_id != INVALID_ADMIN_ID)
		{
			char PlayerName[MAX_NAME_LENGTH];
			if (!GetAdminUsername(admin_id, PlayerName, sizeof(PlayerName)))
				strcopy(PlayerName, sizeof(PlayerName), "Unknown");
			
			BuildPath(Path_SM, adminCmds, sizeof(adminCmds), "logs/admins/%s.log", PlayerName);
			LogToFileEx(adminCmds, "%N - %s [%s]", client, CommandName, argstring);
		}
		
		return Plugin_Continue;
	}

	LogToFileEx(fileCmds, "%N - %s", client, CommandName);
	
	if (flags && admin_id != INVALID_ADMIN_ID)
	{
		char PlayerName[MAX_NAME_LENGTH];
		if (!GetAdminUsername(admin_id, PlayerName, sizeof(PlayerName)))
			strcopy(PlayerName, sizeof(PlayerName), "Unknown");
		
		BuildPath(Path_SM, adminCmds, sizeof(adminCmds), "logs/admins/%s.log", PlayerName);
		LogToFileEx(adminCmds, "%N - %s", client, CommandName);
	}
	
	return Plugin_Continue;
}

public Action OnLogAction(Handle source, Identity ident, int client, int target, const char[] message)
{
	if (client < 1)
		return Plugin_Continue;
	
	AdminId admin_id = GetUserAdmin(client);
	
	if (admin_id == INVALID_ADMIN_ID)
		return Plugin_Continue;
	
	char PlayerName[MAX_NAME_LENGTH];
	if (!GetAdminUsername(admin_id, PlayerName, sizeof(PlayerName)))
		strcopy(PlayerName, sizeof(PlayerName), "Unknown");
	
	BuildPath(Path_SM, adminCmds, sizeof(adminCmds), "logs/admins/%s.log", PlayerName);
	LogToFileEx(adminCmds, "%N - %s", client, message);
	
	return Plugin_Continue;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] szArgs)
{
	if (!client)
		return Plugin_Continue;

	if (!IsClientInGame(client))
		return Plugin_Continue;

	LogToFileEx(fileChat, "[%N]: %s", client, szArgs);

	return Plugin_Continue;
}