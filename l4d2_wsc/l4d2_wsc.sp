#include <sourcemod>

enum WeaponId
{
	WEPID_NONE = -1, WEPID_PISTOL, WEPID_SMG, WEPID_PUMPSHOTGUN, WEPID_AUTOSHOTGUN, WEPID_RIFLE, 
	WEPID_HUNTING_RIFLE, WEPID_SMG_SILENCED, WEPID_SHOTGUN_CHROME, WEPID_RIFLE_DESERT, WEPID_SNIPER_MILITARY, 
	WEPID_SHOTGUN_SPAS, WEPID_FIRST_AID_KIT, WEPID_MOLOTOV, WEPID_PIPE_BOMB, WEPID_PAIN_PILLS, 
	WEPID_MELEE, WEPID_CHAINSAW, WEPID_GRENADE_LAUNCHER, WEPID_ADRENALINE, WEPID_DEFIBRILLATOR, 
	WEPID_VOMITJAR, WEPID_RIFLE_AK47, WEPID_INCENDIARY_AMMO, WEPID_FRAG_AMMO, WEPID_PISTOL_MAGNUM, 
	WEPID_SMG_MP5, WEPID_RIFLE_SG552, WEPID_SNIPER_AWP, WEPID_SNIPER_SCOUT, WEPID_RIFLE_M60
};

enum Cvars
{
	ConVar:PISTOL, ConVar:SMG, ConVar:PUMPSHOTGUN, ConVar:AUTOSHOTGUN, ConVar:RIFLE, 
	ConVar:HUNTING_RIFLE, ConVar:SMG_SILENCED, ConVar:SHOTGUN_CHROME, ConVar:RIFLE_DESERT, ConVar:SNIPER_MILITARY, 
	ConVar:SHOTGUN_SPAS, ConVar:FIRST_AID_KIT, ConVar:MOLOTOV, ConVar:PIPE_BOMB, ConVar:PAIN_PILLS, 
	ConVar:MELEE, ConVar:CHAINSAW, ConVar:GRENADE_LAUNCHER, ConVar:ADRENALINE, ConVar:DEFIBRILLATOR, 
	ConVar:VOMITJAR, ConVar:RIFLE_AK47, ConVar:INCENDIARY_AMMO, ConVar:FRAG_AMMO, ConVar:PISTOL_MAGNUM, 
	ConVar:SMG_MP5, ConVar:RIFLE_SG552, ConVar:SNIPER_AWP, ConVar:SNIPER_SCOUT, ConVar:RIFLE_M60
};

char WeaponNames[WeaponId][] =
{
	"weapon_pistol", "weapon_smg", "weapon_pumpshotgun", "weapon_autoshotgun", "weapon_rifle", 
	"weapon_hunting_rifle", "weapon_smg_silenced", "weapon_shotgun_chrome", "weapon_rifle_desert", "weapon_sniper_military", 
	"weapon_shotgun_spas", "weapon_first_aid_kit", "weapon_molotov", "weapon_pipe_bomb", "weapon_pain_pills", 
	"weapon_melee", "weapon_chainsaw", "weapon_grenade_launcher", "weapon_adrenaline", "weapon_defibrillator", 
	"weapon_vomitjar", "weapon_rifle_ak47", "weapon_upgradepack_incendiary", "weapon_upgradepack_explosive", "weapon_pistol_magnum", 
	"weapon_smg_mp5", "weapon_rifle_sg552", "weapon_sniper_awp", "weapon_sniper_scout", "weapon_rifle_m60"
};

ConVar l4d2_wsc[Cvars];
StringMap hWeaponNamesTrie = null;
int ent_table[128];
int ent_counter;

public Plugin myinfo = 
{
	name = "[L4D2] Weapon Spawns Control",
	author = "Accelerator",
	description = "Count items from weapons spawns",
	version = "1.0",
	url = "https://github.com/accelerator74/sp-plugins"
}

stock WeaponId WeaponNameToId(const char[] weaponName)
{
	WeaponId id;
	if(hWeaponNamesTrie.GetValue(weaponName, id))
	{
		return view_as<WeaponId>(id);
	}
	return WEPID_NONE;
}

public void OnPluginStart()
{
	HookEvent("spawner_give_item", Event_SpawnerGiveItem);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	
	l4d2_wsc[FIRST_AID_KIT] = CreateConVar("l4d2_wsc_first_aid_kit", "0");
	l4d2_wsc[DEFIBRILLATOR] = CreateConVar("l4d2_wsc_defibrillator", "0");
	l4d2_wsc[PAIN_PILLS] = CreateConVar("l4d2_wsc_pain_pills", "0");
	l4d2_wsc[ADRENALINE] = CreateConVar("l4d2_wsc_adrenaline", "0");
	l4d2_wsc[MELEE] = CreateConVar("l4d2_wsc_melee", "0");
	l4d2_wsc[CHAINSAW] = CreateConVar("l4d2_wsc_chainsaw", "0");
	l4d2_wsc[PISTOL] = CreateConVar("l4d2_wsc_pistol", "0");
	l4d2_wsc[PISTOL_MAGNUM] = CreateConVar("l4d2_wsc_pistol_magnum", "0");
	l4d2_wsc[SMG] = CreateConVar("l4d2_wsc_smg", "0");
	l4d2_wsc[SMG_SILENCED] = CreateConVar("l4d2_wsc_smg_silenced", "0");
	l4d2_wsc[PUMPSHOTGUN] = CreateConVar("l4d2_wsc_pumpshotgun", "0");
	l4d2_wsc[SHOTGUN_CHROME] = CreateConVar("l4d2_wsc_shotgun_chrome", "0");
	l4d2_wsc[SHOTGUN_SPAS] = CreateConVar("l4d2_wsc_shotgun_spas", "0");
	l4d2_wsc[AUTOSHOTGUN] = CreateConVar("l4d2_wsc_autoshotgun", "0");
	l4d2_wsc[SNIPER_MILITARY] = CreateConVar("l4d2_wsc_sniper_military", "0");
	l4d2_wsc[HUNTING_RIFLE] = CreateConVar("l4d2_wsc_hunting_rifle", "0");
	l4d2_wsc[RIFLE] = CreateConVar("l4d2_wsc_rifle", "0");
	l4d2_wsc[RIFLE_DESERT] = CreateConVar("l4d2_wsc_rifle_desert", "0");
	l4d2_wsc[RIFLE_AK47] = CreateConVar("l4d2_wsc_rifle_ak47", "0");
	l4d2_wsc[RIFLE_M60] = CreateConVar("l4d2_wsc_rifle_m60", "0");
	l4d2_wsc[SMG_MP5] = CreateConVar("l4d2_wsc_smg_mp5", "0");
	l4d2_wsc[SNIPER_SCOUT] = CreateConVar("l4d2_wsc_sniper_scout", "0");
	l4d2_wsc[SNIPER_AWP] = CreateConVar("l4d2_wsc_sniper_awp", "0");
	l4d2_wsc[RIFLE_SG552] = CreateConVar("l4d2_wsc_rifle_sg552", "0");
	l4d2_wsc[GRENADE_LAUNCHER] = CreateConVar("l4d2_wsc_grenade_launcher", "0");
	l4d2_wsc[PIPE_BOMB] = CreateConVar("l4d2_wsc_pipe_bomb", "0");
	l4d2_wsc[MOLOTOV] = CreateConVar("l4d2_wsc_molotov", "0");
	l4d2_wsc[VOMITJAR] = CreateConVar("l4d2_wsc_vomitjar", "0");
	l4d2_wsc[INCENDIARY_AMMO] = CreateConVar("l4d2_wsc_upgradepack_exp", "0");
	l4d2_wsc[FRAG_AMMO] = CreateConVar("l4d2_wsc_upgradepack_inc", "0");
	
	hWeaponNamesTrie = new StringMap();
	for(int i = 0; i < view_as<int>(WeaponId); i++)
	{
		hWeaponNamesTrie.SetValue(WeaponNames[view_as<WeaponId>(i)], i);
	}
	
	AutoExecConfig(true, "l4d2_wsc");
}

public Action Event_SpawnerGiveItem(Event event, const char[] name, bool dontBroadcast)
{
	char item_name[32];
	event.GetString("item", item_name, sizeof(item_name));
	
	WeaponId wepid = WeaponNameToId(item_name);
	if (wepid != WEPID_NONE)
	{
		int value = l4d2_wsc[wepid].IntValue;
		if (value > 0)
		{
			int spawner = GetEventInt(event, "spawner");
			
			if (value == 1)
			{
				if (IsValidEdict(spawner))
					RemoveEdict(spawner);
			}
			else
			{
				if (IsUseFirst(spawner))
				{
					SetEntProp(spawner, Prop_Data, "m_itemCount", value);
					ent_table[ent_counter] = spawner;
					ent_counter++;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Event_RoundStart(Event hEvent, const char[] strName, bool DontBroadcast)
{
	for (int i = 0; i < sizeof(ent_table); i++)
		ent_table[i] = 0;
	
	ent_counter = 0;
	
	return Plugin_Continue;
}

bool IsUseFirst(spawner)
{
	for (int i = 0; i < sizeof(ent_table); i++)
	{
		if(ent_table[i] == spawner)
			return false;
	}
	return true;
}