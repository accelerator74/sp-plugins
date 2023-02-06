#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

bool ClientSpeaked[MAXPLAYERS+1];
bool alltalk;
ConVar sv_alltalk;

// "L4D2 EMS HUD Functions" by "sorallll"

enum
{
	HUD_LEFT_TOP,
	HUD_LEFT_BOT,
	HUD_MID_TOP,
	HUD_MID_BOT,
	HUD_RIGHT_TOP,
	HUD_RIGHT_BOT,
	HUD_TICKER,
	HUD_FAR_LEFT,
	HUD_FAR_RIGHT,
	HUD_MID_BOX,
	HUD_SCORE_TITLE,
	HUD_SCORE_1,
	HUD_SCORE_2,
	HUD_SCORE_3,
	HUD_SCORE_4
};

// custom flags for background, time, alignment, which team, pre or postfix, etc
#define HUD_FLAG_PRESTR			(1<<0)	//	do you want a string/value pair to start(pre) or end(post) with the static string (default is PRE)
#define HUD_FLAG_POSTSTR		(1<<1)	//	ditto
#define HUD_FLAG_BEEP			(1<<2)	//	Makes a countdown timer blink
#define HUD_FLAG_BLINK			(1<<3)	//	do you want this field to be blinking
#define HUD_FLAG_AS_TIME		(1<<4)	//	to do..
#define HUD_FLAG_COUNTDOWN_WARN	(1<<5)	//	auto blink when the timer gets under 10 seconds
#define HUD_FLAG_NOBG			(1<<6)	//	dont draw the background box for this UI element
#define HUD_FLAG_ALLOWNEGTIMER	(1<<7)	//	by default Timers stop on 0:00 to avoid briefly going negative over network, this keeps that from happening
#define HUD_FLAG_ALIGN_LEFT		(1<<8)	//	Left justify this text
#define HUD_FLAG_ALIGN_CENTER	(1<<9)	//	Center justify this text
#define HUD_FLAG_ALIGN_RIGHT	(3<<8)	//	Right justify this text
#define HUD_FLAG_TEAM_SURVIVORS	(1<<10)	//	only show to the survivor team
#define HUD_FLAG_TEAM_INFECTED	(1<<11)	//	only show to the special infected team
#define HUD_FLAG_TEAM_MASK		(3<<10)	//	link HUD_FLAG_TEAM_SURVIVORS and HUD_FLAG_TEAM_INFECTED
#define HUD_FLAG_UNKNOWN1		(1<<12)	//	?
#define HUD_FLAG_TEXT			(1<<13)	//	?
#define HUD_FLAG_NOTVISIBLE		(1<<14)	//	if you want to keep the slot data but keep it from displaying

public Plugin myinfo = 
{
	name = "SpeakingList",
	author = "Accelerator",
	description = "Voice Announce. Print to Hud Message who Speaking.",
	version = "2.1",
	url = "https://github.com/accelerator74/sp-plugins"
}

public void OnPluginStart()
{
	sv_alltalk = FindConVar("sv_alltalk");
	alltalk = sv_alltalk.BoolValue;
	sv_alltalk.AddChangeHook(OnAllTalkChange);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
	GameRules_SetProp("m_bChallengeModeActive", true, _, _, true);
	HudSet();
	CreateTimer(0.3, ShowSpeaking, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientSpeaking(int client)
{
	ClientSpeaked[client] = true;
}

public void OnClientDisconnect(int client)
{
	ClientSpeaked[client] = false;
}

void OnAllTalkChange(Handle convar, const char[] oldValue, const char[] newValue)
{
	HudSet();
}

void Event_RoundStart(Event hEvent, const char[] strName, bool DontBroadcast)
{
	HudSet();
}

void HudSet()
{
	alltalk = sv_alltalk.BoolValue;
	
	RemoveHUD(HUD_RIGHT_TOP);
	RemoveHUD(HUD_RIGHT_BOT);
	
	if (!alltalk)
	{
		GameRules_SetProp("m_iScriptedHUDFlags", HUD_FLAG_TEXT|HUD_FLAG_NOBG|HUD_FLAG_ALIGN_LEFT|HUD_FLAG_TEAM_SURVIVORS, _, HUD_RIGHT_TOP, true);
		GameRules_SetProp("m_iScriptedHUDFlags", HUD_FLAG_TEXT|HUD_FLAG_NOBG|HUD_FLAG_ALIGN_LEFT|HUD_FLAG_TEAM_INFECTED, _, HUD_RIGHT_BOT, true);
		GameRules_SetPropFloat("m_fScriptedHUDPosX", 0.82, HUD_RIGHT_BOT, true);
		GameRules_SetPropFloat("m_fScriptedHUDPosY", 0.67, HUD_RIGHT_BOT, true);
		GameRules_SetPropFloat("m_fScriptedHUDWidth", 0.17, HUD_RIGHT_BOT, true);
		GameRules_SetPropFloat("m_fScriptedHUDHeight", 0.3, HUD_RIGHT_BOT, true);
	}
	else
		GameRules_SetProp("m_iScriptedHUDFlags", HUD_FLAG_TEXT|HUD_FLAG_NOBG|HUD_FLAG_ALIGN_LEFT, _, HUD_RIGHT_TOP, true);
	
	GameRules_SetPropFloat("m_fScriptedHUDPosX", 0.82, HUD_RIGHT_TOP, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosY", 0.67, HUD_RIGHT_TOP, true);
	GameRules_SetPropFloat("m_fScriptedHUDWidth", 0.17, HUD_RIGHT_TOP, true);
	GameRules_SetPropFloat("m_fScriptedHUDHeight", 0.3, HUD_RIGHT_TOP, true);
}

void RemoveHUD(int slot)
{
	GameRules_SetProp("m_iScriptedHUDInts", 0, _, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDFloats", 0.0, slot, true);
	GameRules_SetProp("m_iScriptedHUDFlags", HUD_FLAG_NOTVISIBLE, _, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosX", 0.0, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosY", 0.0, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDWidth", 0.0, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDHeight", 0.0, slot, true);
	GameRules_SetPropString("m_szScriptedHUDStringSet", "", true, slot);
}

Action ShowSpeaking(Handle timer)
{
	char str[2][255], name[32];
	int len, team;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (ClientSpeaked[i])
			{
				ClientSpeaked[i] = false;
				
				team = alltalk ? 0 : GetClientTeam(i)-2;
				if (team < 0 || team > 1)
					continue;
				
				if (GetClientListeningFlags(i) & VOICE_MUTED)
					continue;
				
				GetClientName(i, name, sizeof(name));
				if (strlen(name) > 25)
				{
					name[23] = '.';
					name[24] = '.';
					name[25] = '.';
					name[26] = 0;
				}
				
				len = strlen(str[team]);
				if (len) {
					Format(str[team][len], sizeof(str[])-len, "\n> %s", name);
				} else {
					FormatEx(str[team], sizeof(str[]), "> %s", name);
				}
			}
		}
	}
	GameRules_SetPropString("m_szScriptedHUDStringSet", str[0], true, HUD_RIGHT_TOP);
	GameRules_SetPropString("m_szScriptedHUDStringSet", str[1], true, HUD_RIGHT_BOT);
	return Plugin_Continue;
}