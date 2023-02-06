#pragma semicolon 1
#include <sourcemod>

char current_map[53];
char NextCampaignVote[32];
char NextCampaign[53];

public Plugin myinfo = 
{
	name = "L4D2 Map Finale Next Versus",
	author = "Accelerator",
	description = "Map rotating",
	version = "4.8",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_next", Command_Next);
	HookEvent("versus_match_finished", Event_FinalWin, EventHookMode_PostNoCopy);
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

public void OnMapStart()
{
	GetCurrentMap(current_map, sizeof(current_map));
}

public void Event_FinalWin(Event event, const char[] name, bool dontBroadcast)
{
	PrintNextCampaign();
	CreateTimer(10.0, ChangeCampaign, TIMER_FLAG_NO_MAPCHANGE);
}

public Action ChangeCampaign(Handle timer, int client)
{
	ChangeCampaignEx();
	return Plugin_Stop;
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
	}
	else
	{
		PrintToChatAll("\x05Next campaign: \x04%s", NextCampaign);
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