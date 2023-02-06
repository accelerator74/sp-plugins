#pragma semicolon 1
#include <sourcemod>

char current_map[53];
int round_end_repeats;
bool IsRoundStarted = false;
char NextCampaignVote[32];
int seconds;
char NextCampaign[53];
float RoundStartTime;

public Plugin myinfo = 
{
	name = "L4D2 Map Finale Next",
	author = "Accelerator",
	description = "Map rotating and vote manager",
	version = "4.10",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_next", Command_Next);
	
	AddCommandListener(Callvote_Handler, "callvote");
	
	HookEvent("finale_win", Event_FinalWin, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

void NextMission()
{
	if (StrContains(current_map, "c1m", false) != -1)
	{
		NextCampaign = "The Passing";
		NextCampaignVote = "L4D2C6";
	}
	else if (StrContains(current_map, "c2m", false) != -1)
	{
		NextCampaign = "Swamp Fever";
		NextCampaignVote = "L4D2C3";
	}
	else if (StrContains(current_map, "c3m", false) != -1)
	{
		NextCampaign = "Hard Rain";
		NextCampaignVote = "L4D2C4";
	}
	else if (StrContains(current_map, "c4m", false) != -1)
	{
		NextCampaign = "The Parish";
		NextCampaignVote = "L4D2C5";
	}
	else if (StrContains(current_map, "c5m", false) != -1)
	{
		NextCampaign = "The Sacrifice";
		NextCampaignVote = "L4D2C7";
	}
	else if (StrContains(current_map, "c6m", false) != -1)
	{
		NextCampaign = "Dark Carnival";
		NextCampaignVote = "L4D2C2";
	}
	else if (StrContains(current_map, "c7m", false) != -1)
	{
		NextCampaign = "No Mercy";
		NextCampaignVote = "L4D2C8";
	}
	else if (StrContains(current_map, "c8m", false) != -1)
	{
		NextCampaign = "Crash Course";
		NextCampaignVote = "L4D2C9";
	}
	else if (StrContains(current_map, "c9m", false) != -1)
	{
		NextCampaign = "Death Toll";
		NextCampaignVote = "L4D2C10";
	}
	else if (StrContains(current_map, "c10m", false) != -1)
	{
		NextCampaign = "The Last Stand";
		NextCampaignVote = "L4D2C14";
	}
	else if (StrContains(current_map, "c11m", false) != -1)
	{
		NextCampaign = "Blood Harvest";
		NextCampaignVote = "L4D2C12";
	}
	else if (StrContains(current_map, "c12m", false) != -1)
	{
		NextCampaign = "Cold Stream";
		NextCampaignVote = "L4D2C13";
	}
	else if (StrContains(current_map, "c13m", false) != -1)
	{
		NextCampaign = "Dead Center";
		NextCampaignVote = "L4D2C1";
	}
	else if (StrContains(current_map, "c14m", false) != -1)
	{
		NextCampaign = "Dead Air";
		NextCampaignVote = "L4D2C11";
	}
	else
	{
		NextCampaign = "Dead Center";
		NextCampaignVote = "L4D2C1";
	}
}

public Action Callvote_Handler(int client, const char[] command, int arg)
{
	char voteName[32];
	char voteValue[128];
	GetCmdArg(1, voteName, sizeof(voteName));
	GetCmdArg(2, voteValue, sizeof(voteValue));
	
	if (StrEqual(voteName, "ChangeMission", false) || StrEqual(voteName, "ChangeChapter", false))
	{
		int flags = GetUserFlagBits(client);
		if (flags & ADMFLAG_VOTE || flags & ADMFLAG_CHANGEMAP || flags & ADMFLAG_ROOT || flags & ADMFLAG_GENERIC)
			return Plugin_Continue;
		else if (round_end_repeats > 5)
			return Plugin_Handled;
		else if (round_end_repeats > 3)
		{
			if (GetEngineTime() - RoundStartTime > 180.0)
			{
				PrintToChat(client, "\x05The game has already started. Vote cancelled.", NextCampaign);
				return Plugin_Handled;
			}
			
			NextMission();
			
			if (StrEqual(voteValue, NextCampaignVote, false))
			{
				RoundStartTime -= 180.0;
				return Plugin_Continue;
			}
			else
			{
				PrintToChat(client, "\x05Next campaign to vote: \x04%s", NextCampaign);
				return Plugin_Handled;
			}
		}
		else
		{
			PrintToChat(client, "\x05Mission failed \x01%d\x05 of \x01%d\x05 times. Vote cancelled.", round_end_repeats, 4);
			return Plugin_Handled;
		}
	}
	if (StrEqual(voteName, "RestartGame", false))
	{
		int flags = GetUserFlagBits(client);
		if (flags & ADMFLAG_VOTE || flags & ADMFLAG_CHANGEMAP || flags & ADMFLAG_ROOT || flags & ADMFLAG_GENERIC)
			return Plugin_Continue;
		else
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void OnMapStart()
{
	GetCurrentMap(current_map, sizeof(current_map));
	round_end_repeats = 0;
	seconds = 15;
}

public void Event_FinalWin(Event event, const char[] name, bool dontBroadcast)
{
	PrintNextCampaign();
	CreateTimer(10.0, ChangeCampaign, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	IsRoundStarted = true;
	RoundStartTime = GetEngineTime();
	
	if (round_end_repeats > 5)
	{
		Veto();
		CreateTimer(1.0, TimerInfo, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		PrintNextCampaign();
	}
	else if (round_end_repeats > 0)
		PrintToChatAll("\x05Mission failed \x01%d\x05 of \x01%d\x05 times", round_end_repeats, 6);
}

public Action TimerInfo(Handle timer)
{
	PrintHintTextToAll("Change campaign through %i seconds!", seconds);
	
	if (seconds <= 0)
	{
		PrintHintTextToAll("Change campaign on %s", NextCampaign);
		CreateTimer(5.0, ChangeCampaign, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Stop;
	}
	
	seconds--;
	
	return Plugin_Continue;
}

public Action ChangeCampaign(Handle timer, int client)
{
	ChangeCampaignEx();
	round_end_repeats = 0;
	return Plugin_Stop;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsRoundStarted)
		return;

	round_end_repeats++;
	
	if (round_end_repeats > 5)
		Veto();
}

public void ChangeCampaignEx()
{
	NextMission();
	
	if (StrEqual(NextCampaignVote, "L4D2C1"))
		ServerCommand("changelevel c1m1_hotel");
	else if (StrEqual(NextCampaignVote, "L4D2C2"))
		ServerCommand("changelevel c2m1_highway");
	else if (StrEqual(NextCampaignVote, "L4D2C3"))
		ServerCommand("changelevel c3m1_plankcountry");
	else if (StrEqual(NextCampaignVote, "L4D2C4"))
		ServerCommand("changelevel c4m1_milltown_a");
	else if (StrEqual(NextCampaignVote, "L4D2C5"))
		ServerCommand("changelevel c5m1_waterfront");
	else if (StrEqual(NextCampaignVote, "L4D2C6"))
		ServerCommand("changelevel c6m1_riverbank");
	else if (StrEqual(NextCampaignVote, "L4D2C7"))
		ServerCommand("changelevel c7m1_docks");
	else if (StrEqual(NextCampaignVote, "L4D2C8"))
		ServerCommand("changelevel c8m1_apartment");
	else if (StrEqual(NextCampaignVote, "L4D2C9"))
		ServerCommand("changelevel c9m1_alleys");
	else if (StrEqual(NextCampaignVote, "L4D2C10"))
		ServerCommand("changelevel c10m1_caves");
	else if (StrEqual(NextCampaignVote, "L4D2C11"))
		ServerCommand("changelevel c11m1_greenhouse");
	else if (StrEqual(NextCampaignVote, "L4D2C12"))
		ServerCommand("changelevel c12m1_hilltop");
	else if (StrEqual(NextCampaignVote, "L4D2C13"))
		ServerCommand("changelevel c13m1_alpinecreek");
	else if (StrEqual(NextCampaignVote, "L4D2C14"))
		ServerCommand("changelevel c14m1_junkyard");
	else
		ServerCommand("changelevel c1m1_hotel");
}

void PrintNextCampaign(int client = 0)
{
	NextMission();

	if (client)
	{
		PrintToChat(client, "\x05Next campaign: \x04%s", NextCampaign);
		PrintToChat(client, "\x05Mission failed \x01%d\x05 of \x01%d\x05 times", round_end_repeats, 6);
	}
	else
	{
		PrintToChatAll("\x05Next campaign: \x04%s", NextCampaign);
	}
}

void Veto()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidEntity(i))
		{
			FakeClientCommand(i, "Vote No");
		}
	}
}

public Action Command_Next(int client, int args)
{
	if (client)
	{
		PrintNextCampaign(client);
	}
	return Plugin_Handled;
}