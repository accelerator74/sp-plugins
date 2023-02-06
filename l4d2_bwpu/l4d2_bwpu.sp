#include <sourcemod>
#include <sdkhooks>

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

ConVar l4d2_bwpu_global;
ConVar l4d2_bwpu[Cvars];
StringMap hWeaponNamesTrie = null;

public Plugin myinfo = 
{
	name = "[L4D2] Bots Weapons Pick Up Control",
	author = "Accelerator",
	description = "Control Bots Weapons Pick Up",
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
	l4d2_bwpu_global = CreateConVar("l4d2_bwpu_global", "0", "Restrict all weapons from bots");
	l4d2_bwpu[FIRST_AID_KIT] = CreateConVar("l4d2_bwpu_first_aid_kit", "0");
	l4d2_bwpu[DEFIBRILLATOR] = CreateConVar("l4d2_bwpu_defibrillator", "0");
	l4d2_bwpu[PAIN_PILLS] = CreateConVar("l4d2_bwpu_pain_pills", "0");
	l4d2_bwpu[ADRENALINE] = CreateConVar("l4d2_bwpu_adrenaline", "0");
	l4d2_bwpu[MELEE] = CreateConVar("l4d2_bwpu_melee", "0");
	l4d2_bwpu[CHAINSAW] = CreateConVar("l4d2_bwpu_chainsaw", "0");
	l4d2_bwpu[PISTOL] = CreateConVar("l4d2_bwpu_pistol", "0");
	l4d2_bwpu[PISTOL_MAGNUM] = CreateConVar("l4d2_bwpu_pistol_magnum", "0");
	l4d2_bwpu[SMG] = CreateConVar("l4d2_bwpu_smg", "0");
	l4d2_bwpu[SMG_SILENCED] = CreateConVar("l4d2_bwpu_smg_silenced", "0");
	l4d2_bwpu[PUMPSHOTGUN] = CreateConVar("l4d2_bwpu_pumpshotgun", "0");
	l4d2_bwpu[SHOTGUN_CHROME] = CreateConVar("l4d2_bwpu_shotgun_chrome", "0");
	l4d2_bwpu[SHOTGUN_SPAS] = CreateConVar("l4d2_bwpu_shotgun_spas", "0");
	l4d2_bwpu[AUTOSHOTGUN] = CreateConVar("l4d2_bwpu_autoshotgun", "0");
	l4d2_bwpu[SNIPER_MILITARY] = CreateConVar("l4d2_bwpu_sniper_military", "0");
	l4d2_bwpu[HUNTING_RIFLE] = CreateConVar("l4d2_bwpu_hunting_rifle", "0");
	l4d2_bwpu[RIFLE] = CreateConVar("l4d2_bwpu_rifle", "0");
	l4d2_bwpu[RIFLE_DESERT] = CreateConVar("l4d2_bwpu_rifle_desert", "0");
	l4d2_bwpu[RIFLE_AK47] = CreateConVar("l4d2_bwpu_rifle_ak47", "0");
	l4d2_bwpu[RIFLE_M60] = CreateConVar("l4d2_bwpu_rifle_m60", "0");
	l4d2_bwpu[SMG_MP5] = CreateConVar("l4d2_bwpu_smg_mp5", "0");
	l4d2_bwpu[SNIPER_SCOUT] = CreateConVar("l4d2_bwpu_sniper_scout", "0");
	l4d2_bwpu[SNIPER_AWP] = CreateConVar("l4d2_bwpu_sniper_awp", "0");
	l4d2_bwpu[RIFLE_SG552] = CreateConVar("l4d2_bwpu_rifle_sg552", "0");
	l4d2_bwpu[GRENADE_LAUNCHER] = CreateConVar("l4d2_bwpu_grenade_launcher", "0");
	l4d2_bwpu[PIPE_BOMB] = CreateConVar("l4d2_bwpu_pipe_bomb", "0");
	l4d2_bwpu[MOLOTOV] = CreateConVar("l4d2_bwpu_molotov", "0");
	l4d2_bwpu[VOMITJAR] = CreateConVar("l4d2_bwpu_vomitjar", "0");
	l4d2_bwpu[INCENDIARY_AMMO] = CreateConVar("l4d2_bwpu_upgradepack_exp", "0");
	l4d2_bwpu[FRAG_AMMO] = CreateConVar("l4d2_bwpu_upgradepack_inc", "0");
	
	hWeaponNamesTrie = new StringMap();
	int i;
	for(i = 0; i < view_as<int>(WeaponId); i++)
	{
		hWeaponNamesTrie.SetValue(WeaponNames[view_as<WeaponId>(i)], i);
	}
	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}
	
	AutoExecConfig(true, "l4d2_bwpu");
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public Action OnWeaponCanUse(int client, int weapon)
{
	if (GetClientTeam(client) == 2)
	{
		if (IsFakeClient(client))
		{	
			char wname[32];
			GetEdictClassname(weapon, wname, sizeof(wname));
			
			if (l4d2_bwpu_global.BoolValue)
			{
				if (!StrEqual(wname, "weapon_pistol"))
					return Plugin_Handled;
			}
			
			WeaponId wepid = WeaponNameToId(wname);
			if (wepid != WEPID_NONE)
			{
				return l4d2_bwpu[wepid].BoolValue ? Plugin_Handled : Plugin_Continue;
			}
		}
	}
	return Plugin_Continue;
}