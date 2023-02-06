#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

#define MAX_LINE_WIDTH	32

#define CLEAR_SPAWNS 0

#if CLEAR_SPAWNS
#include <sdktools>

static const char sWeaponSpawns[][] = {
	"weapon_smg_silenced_spawn",
	"weapon_rifle_m60_spawn",
	"weapon_rifle_ak47_spawn",
	"weapon_rifle_spawn",
	"weapon_rifle_desert_spawn",
	"weapon_autoshotgun_spawn",
	"weapon_shotgun_spas_spawn",
	"weapon_hunting_rifle_spawn",
	"weapon_sniper_military_spawn",
	"weapon_shotgun_chrome_spawn",
	"weapon_smg_spawn",
	"weapon_grenade_launcher_spawn",
	"weapon_pumpshotgun_spawn",
	"weapon_chainsaw_spawn",
	"weapon_upgradepack_explosive_spawn",
	"weapon_upgradepack_incendiary_spawn",
	"weapon_pain_pills_spawn",
	"weapon_adrenaline_spawn",
	"weapon_defibrillator_spawn",
	"weapon_vomitjar_spawn",
	"weapon_pipe_bomb_spawn",
	"weapon_molotov_spawn",
	"weapon_spawn",
	"weapon_melee_spawn",
	"weapon_first_aid_kit_spawn"
};
#endif
static const char sWeaponTmp[][] = {
	"weapon_pain_pills",
	"weapon_adrenaline",
	"weapon_pistol",
	"weapon_pistol_magnum",
	"weapon_smg",
	"weapon_smg_mp5",
	"weapon_smg_silenced",
	"weapon_pumpshotgun",
	"weapon_shotgun_chrome",
	"weapon_sniper_military",
	"weapon_hunting_rifle",
	"weapon_rifle",
	"weapon_rifle_desert",
	"weapon_rifle_sg552",
	"weapon_pipe_bomb",
	"weapon_molotov",
	"weapon_vomitjar",
	"weapon_upgradepack_explosive",
	"weapon_upgradepack_incendiary",
	"weapon_autoshotgun"
};

static const int iWeaponTmpTime[] = {
	300, // pain_pills
	300, // adrenaline
	120, // pistol
	300, // pistol_magnum
	120, // smg
	120, // smg_mp5
	120, // smg_silenced
	120, // pumpshotgun
	120, // shotgun_chrome
	180, // sniper_military
	150, // hunting_rifle
	120, // rifle
	180, // rifle_desert
	300, // rifle_sg552
	240, // pipe_bomb
	240, // molotov
	240, // vomitjar
	180, // upgradepack_explosive
	180, // upgradepack_incendiary
	180  // autoshotgun
};

ArrayList hWeaponClassList;

public Plugin myinfo =
{
	name = "[L4D] Remove Weapons",
	author = "Accelerator",
	description = "Remove weapon spawn and clean unused weapons",
	version = "1.3",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	#if CLEAR_SPAWNS
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	#endif
	HookEvent("weapon_drop", Event_WeaponDrop);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}
	
	hWeaponClassList = new ArrayList(ByteCountToCells(64));
	
	for (int i = 0; i < sizeof(sWeaponTmp); i++)
	{
		hWeaponClassList.PushString(sWeaponTmp[i]);
	}
}

public void OnMapStart()
{
	CreateTimer(20.0, Cleaner, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, OnClientWeaponEquip);
}

public void OnEntityCreated(int entity, const char[] classname)
{	
	if (classname[0] == 'w' && StrContains(classname, "weapon_") != -1)
	{
		if (!IsServerProcessing()) return;
		if (hWeaponClassList.FindString(classname) != -1)
		{
			SetEntPropFloat(entity, Prop_Send, "m_flCreateTime", (GetGameTime()+10.0));
		}
	}
}

void OnClientWeaponEquip(int client, int weapon)
{
	if (weapon > 0)
	{
		if (GetClientTeam(client) == 2)
		{
			char classname[MAX_LINE_WIDTH+1];
			GetEdictClassname(weapon, classname, MAX_LINE_WIDTH);
			
			if (hWeaponClassList.FindString(classname) != -1)
			{
				SetEntPropFloat(weapon, Prop_Send, "m_flCreateTime", 0.0);
			}
		}
	}
}

Action Cleaner(Handle timer)
{
	if (!IsServerProcessing())
		return Plugin_Continue;
	
	float GameTime = GetGameTime();
	char classname[MAX_LINE_WIDTH+1];
	int index;
	float CreateTime;
	
	for (int i = MaxClients + 1; i <= 2048; i++)
	{
		if (IsValidEntity(i) && IsValidEdict(i))
		{
			GetEdictClassname(i, classname, MAX_LINE_WIDTH);
			
			if (StrContains(classname, "weapon_") != -1)
			{
				index = hWeaponClassList.FindString(classname);
				
				if (index != -1)
				{
					CreateTime = GetEntPropFloat(i, Prop_Send, "m_flCreateTime");
					
					if (CreateTime > 0.0)
					{
						if ((GameTime - CreateTime) >= (iWeaponTmpTime[index] - 1.0))
							RemoveEntity(i);
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

void Event_WeaponDrop(Event hEvent, const char[] strName, bool DontBroadcast)
{
	int weapon = hEvent.GetInt("propid");
	
	if (weapon > 0)
	{
		char classname[MAX_LINE_WIDTH+1];
		GetEdictClassname(weapon, classname, MAX_LINE_WIDTH);
		
		if (hWeaponClassList.FindString(classname) != -1)
		{
			SetEntPropFloat(weapon, Prop_Send, "m_flCreateTime", GetGameTime());
		}
	}
}
#if CLEAR_SPAWNS
void Event_RoundStart(Event hEvent, const char[] strName, bool DontBroadcast)
{
	CreateTimer(0.2, ClearSpawns, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(10.0, ClearSpawns, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action ClearSpawns(Handle timer)
{
	int Entity = -1;
	int iCount = 0;
	for (int i = 0; i < sizeof(sWeaponSpawns); i++)
	{
		Entity = -1;
		while((Entity = FindEntityByClassname(Entity, sWeaponSpawns[i])) != -1)
		{
			RemoveEntity(Entity);
			iCount++;
		}
	}
	if (iCount) PrintToServer("Clear %i weapon spawns", iCount);
	return Plugin_Stop;
}
#endif
