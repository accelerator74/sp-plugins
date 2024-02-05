#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

bool incap_magnum[33];

public Plugin myinfo = {
	name = "L4D2 Incapped Magnum",
	author = "Accelerator",
	description = "Gives incapped players a magnum.",
	version = "2.0",
	url = "https://github.com/accelerator74/sp-plugins"
}

public void OnPluginStart()
{
	HookEvent("player_incapacitated", event_PlayerIncap);
	HookEvent("player_incapacitated_start", Event_MeleeCheck);
	HookEvent("revive_success", EventReviveSuccess);
}

void Event_MeleeCheck(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	incap_magnum[client] = false;

	if (IsFakeClient(client))
		return;

	if (GetClientTeam(client) != 2)
		return;

	int slot = GetPlayerWeaponSlot(client, 1);
	if (slot != -1) 
	{
		char weapon[32];
		GetEdictClassname(slot, weapon, sizeof(weapon));
		if (StrEqual(weapon, "weapon_melee") || StrEqual(weapon, "weapon_chainsaw"))
			incap_magnum[client] = true;
	}
}

void event_PlayerIncap(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IsFakeClient(client))
		return;

	if (GetClientTeam(client) != 2)
		return;
	
	if (incap_magnum[client])
	{
		int slot = GetPlayerWeaponSlot(client, 1);
		if (slot != -1) 
		{
			char weapon[32];
			GetEdictClassname(slot, weapon, sizeof(weapon));
			
			if (StrContains(weapon, "pistol", false) != -1)
			{
				RemovePlayerItem(client, slot);
				RemoveEntity(slot);
				
				GivePlayerItem(client, "pistol_magnum");
			}
		}
	}
}

void EventReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	
	if (IsFakeClient(client))
		return;

	if (GetClientTeam(client) != 2)
		return;

	incap_magnum[client] = false;
}