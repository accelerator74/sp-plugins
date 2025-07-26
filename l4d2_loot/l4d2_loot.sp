#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name = "[L4D2] Loot of Zombies",
	author = "Accelerator & Jonny",
	description = "Plugin drops some items from killed special-infected",
	version = "2.3",
	url = "http://forums.alliedmods.net/showthread.php?t=115763"
}

ConVar DropItemsFromPlayers;
ConVar NoFarm;

ConVar l4d2_loot_g_chance_nodrop;

ConVar l4d2_loot_h_drop_items;
ConVar l4d2_loot_b_drop_items;
ConVar l4d2_loot_s_drop_items;
ConVar l4d2_loot_c_drop_items;
ConVar l4d2_loot_sp_drop_items;
ConVar l4d2_loot_j_drop_items;
ConVar l4d2_loot_t_drop_items;

ArrayList MeleeDefault;
ArrayList MeleeExtra;

enum {
	loot_first_aid_kit,
	loot_defibrillator,
	loot_pain_pills,
	loot_adrenaline,
	loot_cricket_bat,
	loot_crowbar,
	loot_electric_guitar,
	loot_chainsaw,
	loot_katana,
	loot_machete,
	loot_tonfa,
	loot_frying_pan,
	loot_fireaxe,
	loot_golfclub,
	loot_riotshield,
	loot_melee_extra,
	loot_baseball_bat,
	loot_knife,
	loot_pistol,
	loot_pistol_magnum,
	loot_smg,
	loot_smg_silenced,
	loot_pumpshotgun,
	loot_shotgun_chrome,
	loot_shotgun_spas,
	loot_autoshotgun,
	loot_sniper_military,
	loot_hunting_rifle,
	loot_rifle,
	loot_rifle_desert,
	loot_rifle_ak47,
	loot_rifle_m60,
	loot_smg_mp5,
	loot_sniper_scout,
	loot_sniper_awp,
	loot_rifle_sg552,
	loot_grenade_launcher,
	loot_pipe_bomb,
	loot_molotov,
	loot_vomitjar,
	loot_upgradepack_exp,
	loot_upgradepack_inc,
	loot_fireworkcrate,
	loot_gascan,
	loot_oxygentank,
	loot_propanetank,
	loot_gnome,
	loot_cola_bottles,
	loot_shovel,
	loot_pitchfork,
	WeaponsLoot
};

enum {
	loot_h_chance_health,
	loot_h_chance_melee,
	loot_h_chance_bullet,
	loot_h_chance_explosive,
	loot_h_chance_throw,
	loot_h_chance_upgrades,
	loot_h_chance_misc,
	loot_h_chance_misc2,
	loot_h_chance_nodrop,
	loot_b_chance_health,
	loot_b_chance_melee,
	loot_b_chance_bullet,
	loot_b_chance_explosive,
	loot_b_chance_throw,
	loot_b_chance_upgrades,
	loot_b_chance_misc,
	loot_b_chance_misc2,
	loot_b_chance_nodrop,
	loot_s_chance_health,
	loot_s_chance_melee,
	loot_s_chance_bullet,
	loot_s_chance_explosive,
	loot_s_chance_throw,
	loot_s_chance_upgrades,
	loot_s_chance_misc,
	loot_s_chance_misc2,
	loot_s_chance_nodrop,
	loot_c_chance_health,
	loot_c_chance_melee,
	loot_c_chance_bullet,
	loot_c_chance_explosive,
	loot_c_chance_throw,
	loot_c_chance_upgrades,
	loot_c_chance_misc,
	loot_c_chance_misc2,
	loot_c_chance_nodrop,
	loot_sp_chance_health,
	loot_sp_chance_melee,
	loot_sp_chance_bullet,
	loot_sp_chance_explosive,
	loot_sp_chance_throw,
	loot_sp_chance_upgrades,
	loot_sp_chance_misc,
	loot_sp_chance_misc2,
	loot_sp_chance_nodrop,
	loot_j_chance_health,
	loot_j_chance_melee,
	loot_j_chance_bullet,
	loot_j_chance_explosive,
	loot_j_chance_throw,
	loot_j_chance_upgrades,
	loot_j_chance_misc,
	loot_j_chance_misc2,
	loot_j_chance_nodrop,
	loot_t_chance_health,
	loot_t_chance_melee,
	loot_t_chance_bullet,
	loot_t_chance_explosive,
	loot_t_chance_throw,
	loot_t_chance_upgrades,
	loot_t_chance_misc,
	loot_t_chance_misc2,
	loot_t_chance_nodrop,
	DropChances
};

ConVar l4d2_loot_items[WeaponsLoot];
ConVar l4d2_loot_chances[DropChances];

int cvar_value_loot[WeaponsLoot];
int cvar_value_chance[DropChances];

public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath);

	DropItemsFromPlayers = CreateConVar("l4d2_loot_from_players", "0");
	NoFarm = CreateConVar("l4d2_loot_nofarm", "0", "No farm");

	l4d2_loot_g_chance_nodrop = CreateConVar("l4d2_loot_g_chance_nodrop", "5");

	l4d2_loot_h_drop_items = CreateConVar("l4d2_loot_h_drop_items", "1");
	l4d2_loot_b_drop_items = CreateConVar("l4d2_loot_b_drop_items", "1");
	l4d2_loot_s_drop_items = CreateConVar("l4d2_loot_s_drop_items", "1");
	l4d2_loot_c_drop_items = CreateConVar("l4d2_loot_c_drop_items", "1");
	l4d2_loot_sp_drop_items = CreateConVar("l4d2_loot_sp_drop_items", "1");
	l4d2_loot_j_drop_items = CreateConVar("l4d2_loot_j_drop_items", "1");
	l4d2_loot_t_drop_items = CreateConVar("l4d2_loot_t_drop_items", "1");

	l4d2_loot_chances[loot_h_chance_health] = CreateConVar("l4d2_loot_h_chance_health", "35");
	l4d2_loot_chances[loot_h_chance_melee] = CreateConVar("l4d2_loot_h_chance_melee", "30");
	l4d2_loot_chances[loot_h_chance_bullet] = CreateConVar("l4d2_loot_h_chance_bullet", "44");
	l4d2_loot_chances[loot_h_chance_explosive] = CreateConVar("l4d2_loot_h_chance_explosive", "1");
	l4d2_loot_chances[loot_h_chance_throw] = CreateConVar("l4d2_loot_h_chance_throw", "50");
	l4d2_loot_chances[loot_h_chance_upgrades] = CreateConVar("l4d2_loot_h_chance_upgrades", "30");
	l4d2_loot_chances[loot_h_chance_misc] = CreateConVar("l4d2_loot_h_chance_misc", "0");
	l4d2_loot_chances[loot_h_chance_misc2] = CreateConVar("l4d2_loot_h_chance_misc2", "10");
	l4d2_loot_chances[loot_h_chance_nodrop] = CreateConVar("l4d2_loot_h_chance_nodrop", "30");

	l4d2_loot_chances[loot_b_chance_health] = CreateConVar("l4d2_loot_b_chance_health", "35");
	l4d2_loot_chances[loot_b_chance_melee] = CreateConVar("l4d2_loot_b_chance_melee", "30");
	l4d2_loot_chances[loot_b_chance_bullet] = CreateConVar("l4d2_loot_b_chance_bullet", "7");
	l4d2_loot_chances[loot_b_chance_explosive] = CreateConVar("l4d2_loot_b_chance_explosive", "1");
	l4d2_loot_chances[loot_b_chance_throw] = CreateConVar("l4d2_loot_b_chance_throw", "50");
	l4d2_loot_chances[loot_b_chance_upgrades] = CreateConVar("l4d2_loot_b_chance_upgrades", "10");
	l4d2_loot_chances[loot_b_chance_misc] = CreateConVar("l4d2_loot_b_chance_misc", "0");
	l4d2_loot_chances[loot_b_chance_misc2] = CreateConVar("l4d2_loot_b_chance_misc2", "10");
	l4d2_loot_chances[loot_b_chance_nodrop] = CreateConVar("l4d2_loot_b_chance_nodrop", "20");

	l4d2_loot_chances[loot_s_chance_health] = CreateConVar("l4d2_loot_s_chance_health", "25");
	l4d2_loot_chances[loot_s_chance_melee] = CreateConVar("l4d2_loot_s_chance_melee", "40");
	l4d2_loot_chances[loot_s_chance_bullet] = CreateConVar("l4d2_loot_s_chance_bullet", "44");
	l4d2_loot_chances[loot_s_chance_explosive] = CreateConVar("l4d2_loot_s_chance_explosive", "1");
	l4d2_loot_chances[loot_s_chance_throw] = CreateConVar("l4d2_loot_s_chance_throw", "50");
	l4d2_loot_chances[loot_s_chance_upgrades] = CreateConVar("l4d2_loot_s_chance_upgrades", "10");
	l4d2_loot_chances[loot_s_chance_misc] = CreateConVar("l4d2_loot_s_chance_misc", "10");
	l4d2_loot_chances[loot_s_chance_misc2] = CreateConVar("l4d2_loot_s_chance_misc2", "10");
	l4d2_loot_chances[loot_s_chance_nodrop] = CreateConVar("l4d2_loot_s_chance_nodrop", "20");

	l4d2_loot_chances[loot_c_chance_health] = CreateConVar("l4d2_loot_c_chance_health", "35");
	l4d2_loot_chances[loot_c_chance_melee] = CreateConVar("l4d2_loot_c_chance_melee", "0");
	l4d2_loot_chances[loot_c_chance_bullet] = CreateConVar("l4d2_loot_c_chance_bullet", "10");
	l4d2_loot_chances[loot_c_chance_explosive] = CreateConVar("l4d2_loot_c_chance_explosive", "1");
	l4d2_loot_chances[loot_c_chance_throw] = CreateConVar("l4d2_loot_c_chance_throw", "0");
	l4d2_loot_chances[loot_c_chance_upgrades] = CreateConVar("l4d2_loot_c_chance_upgrades", "20");
	l4d2_loot_chances[loot_c_chance_misc] = CreateConVar("l4d2_loot_c_chance_misc", "0");
	l4d2_loot_chances[loot_c_chance_misc2] = CreateConVar("l4d2_loot_c_chance_misc2", "10");
	l4d2_loot_chances[loot_c_chance_nodrop] = CreateConVar("l4d2_loot_c_chance_nodrop", "20");

	l4d2_loot_chances[loot_sp_chance_health] = CreateConVar("l4d2_loot_sp_chance_health", "35");
	l4d2_loot_chances[loot_sp_chance_melee] = CreateConVar("l4d2_loot_sp_chance_melee", "0");
	l4d2_loot_chances[loot_sp_chance_bullet] = CreateConVar("l4d2_loot_sp_chance_bullet", "0");
	l4d2_loot_chances[loot_sp_chance_explosive] = CreateConVar("l4d2_loot_sp_chance_explosive", "1");
	l4d2_loot_chances[loot_sp_chance_throw] = CreateConVar("l4d2_loot_sp_chance_throw", "0");
	l4d2_loot_chances[loot_sp_chance_upgrades] = CreateConVar("l4d2_loot_sp_chance_upgrades", "20");
	l4d2_loot_chances[loot_sp_chance_misc] = CreateConVar("l4d2_loot_sp_chance_misc", "50");
	l4d2_loot_chances[loot_sp_chance_misc2] = CreateConVar("l4d2_loot_sp_chance_misc2", "10");
	l4d2_loot_chances[loot_sp_chance_nodrop] = CreateConVar("l4d2_loot_sp_chance_nodrop", "20");

	l4d2_loot_chances[loot_j_chance_health] = CreateConVar("l4d2_loot_j_chance_health", "35");
	l4d2_loot_chances[loot_j_chance_melee] = CreateConVar("l4d2_loot_j_chance_melee", "10");
	l4d2_loot_chances[loot_j_chance_bullet] = CreateConVar("l4d2_loot_j_chance_bullet", "50");
	l4d2_loot_chances[loot_j_chance_explosive] = CreateConVar("l4d2_loot_j_chance_explosive", "1");
	l4d2_loot_chances[loot_j_chance_throw] = CreateConVar("l4d2_loot_j_chance_throw", "0");
	l4d2_loot_chances[loot_j_chance_upgrades] = CreateConVar("l4d2_loot_j_chance_upgrades", "0");
	l4d2_loot_chances[loot_j_chance_misc] = CreateConVar("l4d2_loot_j_chance_misc", "0");
	l4d2_loot_chances[loot_j_chance_misc2] = CreateConVar("l4d2_loot_j_chance_misc2", "10");
	l4d2_loot_chances[loot_j_chance_nodrop] = CreateConVar("l4d2_loot_j_chance_nodrop", "20");

	l4d2_loot_chances[loot_t_chance_health] = CreateConVar("l4d2_loot_t_chance_health", "45");
	l4d2_loot_chances[loot_t_chance_melee] = CreateConVar("l4d2_loot_t_chance_melee", "20");
	l4d2_loot_chances[loot_t_chance_bullet] = CreateConVar("l4d2_loot_t_chance_bullet", "75");
	l4d2_loot_chances[loot_t_chance_explosive] = CreateConVar("l4d2_loot_t_chance_explosive", "3");
	l4d2_loot_chances[loot_t_chance_throw] = CreateConVar("l4d2_loot_t_chance_throw", "50");
	l4d2_loot_chances[loot_t_chance_upgrades] = CreateConVar("l4d2_loot_t_chance_upgrades", "10");
	l4d2_loot_chances[loot_t_chance_misc] = CreateConVar("l4d2_loot_t_chance_misc", "10");
	l4d2_loot_chances[loot_t_chance_misc2] = CreateConVar("l4d2_loot_t_chance_misc2", "1");
	l4d2_loot_chances[loot_t_chance_nodrop] = CreateConVar("l4d2_loot_t_chance_nodrop", "0");

	l4d2_loot_items[loot_first_aid_kit] = CreateConVar("l4d2_loot_first_aid_kit", "6");
	l4d2_loot_items[loot_defibrillator] = CreateConVar("l4d2_loot_defibrillator", "1");
	l4d2_loot_items[loot_pain_pills] = CreateConVar("l4d2_loot_pain_pills", "15");
	l4d2_loot_items[loot_adrenaline] = CreateConVar("l4d2_loot_adrenaline", "15");

	l4d2_loot_items[loot_cricket_bat] = CreateConVar("l4d2_loot_cricket_bat", "10");
	l4d2_loot_items[loot_crowbar] = CreateConVar("l4d2_loot_crowbar", "10");
	l4d2_loot_items[loot_electric_guitar] = CreateConVar("l4d2_loot_electric_guitar", "10");
	l4d2_loot_items[loot_chainsaw] = CreateConVar("l4d2_loot_chainsaw", "1");
	l4d2_loot_items[loot_katana] = CreateConVar("l4d2_loot_katana", "6");
	l4d2_loot_items[loot_machete] = CreateConVar("l4d2_loot_machete", "8");
	l4d2_loot_items[loot_tonfa] = CreateConVar("l4d2_loot_tonfa", "10");
	l4d2_loot_items[loot_frying_pan] = CreateConVar("l4d2_loot_frying_pan", "10");
	l4d2_loot_items[loot_fireaxe] = CreateConVar("l4d2_loot_fireaxe", "5");
	l4d2_loot_items[loot_golfclub] = CreateConVar("l4d2_loot_golfclub", "7");
	l4d2_loot_items[loot_riotshield] = CreateConVar("l4d2_loot_riotshield", "10");
	l4d2_loot_items[loot_shovel] = CreateConVar("l4d2_loot_shovel", "10");
	l4d2_loot_items[loot_pitchfork] = CreateConVar("l4d2_loot_pitchfork", "10");
	l4d2_loot_items[loot_melee_extra] = CreateConVar("l4d2_loot_melee_extra", "10");
	l4d2_loot_items[loot_baseball_bat] = CreateConVar("l4d2_loot_baseball_bat", "10");
	l4d2_loot_items[loot_knife] = CreateConVar("l4d2_loot_knife", "2");
	l4d2_loot_items[loot_pistol] = CreateConVar("l4d2_loot_pistol", "0");
	l4d2_loot_items[loot_pistol_magnum] = CreateConVar("l4d2_loot_pistol_magnum", "10");
	l4d2_loot_items[loot_smg] = CreateConVar("l4d2_loot_smg", "10");
	l4d2_loot_items[loot_smg_silenced] = CreateConVar("l4d2_loot_smg_silenced", "10");
	l4d2_loot_items[loot_pumpshotgun] = CreateConVar("l4d2_loot_pumpshotgun", "10");
	l4d2_loot_items[loot_shotgun_chrome] = CreateConVar("l4d2_loot_shotgun_chrome", "10");
	l4d2_loot_items[loot_shotgun_spas] = CreateConVar("l4d2_loot_shotgun_spas", "2");
	l4d2_loot_items[loot_autoshotgun] = CreateConVar("l4d2_loot_autoshotgun", "10");
	l4d2_loot_items[loot_sniper_military] = CreateConVar("l4d2_loot_sniper_military", "9");
	l4d2_loot_items[loot_hunting_rifle] = CreateConVar("l4d2_loot_hunting_rifle", "10");
	l4d2_loot_items[loot_rifle] = CreateConVar("l4d2_loot_rifle", "10");
	l4d2_loot_items[loot_rifle_desert] = CreateConVar("l4d2_loot_rifle_desert", "10");
	l4d2_loot_items[loot_rifle_ak47] = CreateConVar("l4d2_loot_rifle_ak47", "1");
	l4d2_loot_items[loot_rifle_m60] = CreateConVar("l4d2_loot_rifle_m60", "4");
	l4d2_loot_items[loot_smg_mp5] = CreateConVar("l4d2_loot_smg_mp5", "10");
	l4d2_loot_items[loot_sniper_scout] = CreateConVar("l4d2_loot_sniper_scout", "1");
	l4d2_loot_items[loot_sniper_awp] = CreateConVar("l4d2_loot_sniper_awp", "1");
	l4d2_loot_items[loot_rifle_sg552] = CreateConVar("l4d2_loot_rifle_sg552", "10");
	l4d2_loot_items[loot_grenade_launcher] = CreateConVar("l4d2_loot_grenade_launcher", "1");

	l4d2_loot_items[loot_pipe_bomb] = CreateConVar("l4d2_loot_pipe_bomb", "3");
	l4d2_loot_items[loot_molotov] = CreateConVar("l4d2_loot_molotov", "4");
	l4d2_loot_items[loot_vomitjar] = CreateConVar("l4d2_loot_vomitjar", "5");

	l4d2_loot_items[loot_upgradepack_exp] = CreateConVar("l4d2_loot_upgradepack_exp", "1");
	l4d2_loot_items[loot_upgradepack_inc] = CreateConVar("l4d2_loot_upgradepack_inc", "1");

	l4d2_loot_items[loot_fireworkcrate] = CreateConVar("l4d2_loot_fireworkcrate", "1");
	l4d2_loot_items[loot_gascan] = CreateConVar("l4d2_loot_gascan", "0");
	l4d2_loot_items[loot_oxygentank] = CreateConVar("l4d2_loot_oxygentank", "0");
	l4d2_loot_items[loot_propanetank] = CreateConVar("l4d2_loot_propanetank", "0");

	l4d2_loot_items[loot_gnome] = CreateConVar("l4d2_loot_gnome", "100");
	l4d2_loot_items[loot_cola_bottles] = CreateConVar("l4d2_loot_cola_bottles", "0");

	int i;
	for (i = 0; i < DropChances; i++)
	{
		l4d2_loot_chances[i].AddChangeHook(OnConVarChanceChange);
		cvar_value_chance[i] = l4d2_loot_chances[i].IntValue;
	}
	for (i = 0; i < WeaponsLoot; i++)
	{
		l4d2_loot_items[i].AddChangeHook(OnConVarLootChange);
		cvar_value_loot[i] = l4d2_loot_items[i].IntValue;
	}

	MeleeExtra = new ArrayList(ByteCountToCells(32));
	MeleeDefault = new ArrayList(ByteCountToCells(32));
	MeleeDefault.PushString("baseball_bat");
	MeleeDefault.PushString("cricket_bat");
	MeleeDefault.PushString("crowbar");
	MeleeDefault.PushString("electric_guitar");
	MeleeDefault.PushString("fireaxe");
	MeleeDefault.PushString("frying_pan");
	MeleeDefault.PushString("golfclub");
	MeleeDefault.PushString("katana");
	MeleeDefault.PushString("knife");
	MeleeDefault.PushString("machete");
	MeleeDefault.PushString("tonfa");
	MeleeDefault.PushString("pitchfork");
	MeleeDefault.PushString("shovel");
	MeleeDefault.PushString("riot_shield");
}

public void OnMapStart()
{
	MeleeExtra.Clear();

	int table = FindStringTable("MeleeWeapons");
	int total = GetStringTableNumStrings(table);

	char sMelee[32];
	for (int i = 0; i < total; i++)
	{
		ReadStringTable(table, i, sMelee, sizeof(sMelee));
		if (MeleeDefault.FindString(sMelee) == -1)
		{
			MeleeExtra.PushString(sMelee);
		}
	}
}

void OnConVarChanceChange(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	if (StringToInt(newVal) == StringToInt(oldVal))
		return;

	for (int i = 0; i < DropChances; i++)
	{
		if (l4d2_loot_chances[i] == cvar)
		{
			cvar_value_chance[i] = cvar.IntValue;
		}
	}
}

void OnConVarLootChange(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	if (StringToInt(newVal) == StringToInt(oldVal))
		return;

	for (int i = 0; i < WeaponsLoot; i++)
	{
		if (l4d2_loot_items[i] == cvar)
		{
			cvar_value_loot[i] = cvar.IntValue;
		}
	}
}

void Event_PlayerDeath(Event hEvent, const char[] strName, bool DontBroadcast)
{
	if (NoFarm.BoolValue)
		return;

	int Attacker = GetClientOfUserId(hEvent.GetInt("attacker"));

	if (!Attacker)
		return;

	if (IsFakeClient(Attacker))
		return;
	
	if (GetClientTeam(Attacker) != 2)
		return;

	int Target = GetClientOfUserId(hEvent.GetInt("userid"));

	if (!Target) 
		return;

	if (Attacker == Target)
		return;
	
	if (GetClientTeam(Target) != 3)
		return;

	if (!IsFakeClient(Target) && !DropItemsFromPlayers.BoolValue)
		return;

	int iClass = GetEntProp(Target, Prop_Send, "m_zombieClass");
	int count;

	switch (iClass)
	{
		case 1: count = l4d2_loot_s_drop_items.IntValue;
		case 2: count = l4d2_loot_b_drop_items.IntValue;
		case 3: count = l4d2_loot_h_drop_items.IntValue;
		case 4: count = l4d2_loot_sp_drop_items.IntValue;
		case 5: count = l4d2_loot_j_drop_items.IntValue;
		case 6: count = l4d2_loot_c_drop_items.IntValue;
		case 8: count = l4d2_loot_t_drop_items.IntValue;
		default: return;
	}

	for (int i = 0; i < count; i++)
	{
		LootDropItem(Target, GetRandomItem(GetRandomGroup(iClass)));
	}
}

int GetRandomGroup(const int iClass)
{
	int nodrop = l4d2_loot_g_chance_nodrop.IntValue;
	if (nodrop > 0)
	{
		if (nodrop >= 1 + GetURandomInt() % 100)
		{
			return 0;
		}
	}

	int Sum = 0;
	switch (iClass)
	{
		case 1:
		{
			Sum = cvar_value_chance[loot_s_chance_health];
			Sum += cvar_value_chance[loot_s_chance_melee];
			Sum += cvar_value_chance[loot_s_chance_bullet];
			Sum += cvar_value_chance[loot_s_chance_explosive];
			Sum += cvar_value_chance[loot_s_chance_throw];
			Sum += cvar_value_chance[loot_s_chance_upgrades];
			Sum += cvar_value_chance[loot_s_chance_misc];
			Sum += cvar_value_chance[loot_s_chance_misc2];
			Sum += cvar_value_chance[loot_s_chance_nodrop];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_chance[loot_s_chance_health] * X;
				if (Y >= A && Y < A + B)
				{
					return 1;
				}
				A = A + B;
				B = cvar_value_chance[loot_s_chance_melee] * X;
				if (Y >= A && Y < A + B)
				{
					return 2;
				}
				A = A + B;
				B = cvar_value_chance[loot_s_chance_bullet] * X;
				if (Y >= A && Y < A + B)
				{
					return 3;
				}
				A = A + B;
				B = cvar_value_chance[loot_s_chance_explosive] * X;
				if (Y >= A && Y < A + B)
				{
					return 4;
				}
				A = A + B;
				B = cvar_value_chance[loot_s_chance_throw] * X;
				if (Y >= A && Y < A + B)
				{
					return 5;
				}
				A = A + B;
				B = cvar_value_chance[loot_s_chance_upgrades] * X;
				if (Y >= A && Y < A + B)
				{
					return 6;
				}
				A = A + B;
				B = cvar_value_chance[loot_s_chance_misc] * X;
				if (Y >= A && Y < A + B)
				{
					return 7;
				}
				A = A + B;
				B = cvar_value_chance[loot_s_chance_misc2] * X;
				if (Y >= A && Y < A + B)
				{
					return 8;
				}
				A = A + B;
				B = cvar_value_chance[loot_s_chance_nodrop] * X;
				if (Y >= A && Y < A + B)
				{
					return 0;
				}
			}
			else
			{
				return 0;
			}
		}
		case 2:
		{
			Sum = cvar_value_chance[loot_b_chance_health];
			Sum += cvar_value_chance[loot_b_chance_melee];
			Sum += cvar_value_chance[loot_b_chance_bullet];
			Sum += cvar_value_chance[loot_b_chance_explosive];
			Sum += cvar_value_chance[loot_b_chance_throw];
			Sum += cvar_value_chance[loot_b_chance_upgrades];
			Sum += cvar_value_chance[loot_b_chance_misc];
			Sum += cvar_value_chance[loot_b_chance_misc2];
			Sum += cvar_value_chance[loot_b_chance_nodrop];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_chance[loot_b_chance_health] * X;
				if (Y >= A && Y < A + B)
				{
					return 1;
				}
				A = A + B;
				B = cvar_value_chance[loot_b_chance_melee] * X;
				if (Y >= A && Y < A + B)
				{
					return 2;
				}
				A = A + B;
				B = cvar_value_chance[loot_b_chance_bullet] * X;
				if (Y >= A && Y < A + B)
				{
					return 3;
				}
				A = A + B;
				B = cvar_value_chance[loot_b_chance_explosive] * X;
				if (Y >= A && Y < A + B)
				{
					return 4;
				}
				A = A + B;
				B = cvar_value_chance[loot_b_chance_throw] * X;
				if (Y >= A && Y < A + B)
				{
					return 5;
				}
				A = A + B;
				B = cvar_value_chance[loot_b_chance_upgrades] * X;
				if (Y >= A && Y < A + B)
				{
					return 6;
				}
				A = A + B;
				B = cvar_value_chance[loot_b_chance_misc] * X;
				if (Y >= A && Y < A + B)
				{
					return 7;
				}
				A = A + B;
				B = cvar_value_chance[loot_b_chance_misc2] * X;
				if (Y >= A && Y < A + B)
				{
					return 8;
				}
				A = A + B;
				B = cvar_value_chance[loot_b_chance_nodrop] * X;
				if (Y >= A && Y < A + B)
				{
					return 0;
				}
			}
			else
			{
				return 0;
			}
		}
		case 3:
		{
			Sum = cvar_value_chance[loot_h_chance_health];
			Sum += cvar_value_chance[loot_h_chance_melee];
			Sum += cvar_value_chance[loot_h_chance_bullet];
			Sum += cvar_value_chance[loot_h_chance_explosive];
			Sum += cvar_value_chance[loot_h_chance_throw];
			Sum += cvar_value_chance[loot_h_chance_upgrades];
			Sum += cvar_value_chance[loot_h_chance_misc];
			Sum += cvar_value_chance[loot_h_chance_misc2];
			Sum += cvar_value_chance[loot_h_chance_nodrop];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_chance[loot_h_chance_health] * X;
				if (Y >= A && Y < A + B)
				{
					return 1;
				}
				A = A + B;
				B = cvar_value_chance[loot_h_chance_melee] * X;
				if (Y >= A && Y < A + B)
				{
					return 2;
				}
				A = A + B;
				B = cvar_value_chance[loot_h_chance_bullet] * X;
				if (Y >= A && Y < A + B)
				{
					return 3;
				}
				A = A + B;
				B = cvar_value_chance[loot_h_chance_explosive] * X;
				if (Y >= A && Y < A + B)
				{
					return 4;
				}
				A = A + B;
				B = cvar_value_chance[loot_h_chance_throw] * X;
				if (Y >= A && Y < A + B)
				{
					return 5;
				}
				A = A + B;
				B = cvar_value_chance[loot_h_chance_upgrades] * X;
				if (Y >= A && Y < A + B)
				{
					return 6;
				}
				A = A + B;
				B = cvar_value_chance[loot_h_chance_misc] * X;
				if (Y >= A && Y < A + B)
				{
					return 7;
				}
				A = A + B;
				B = cvar_value_chance[loot_h_chance_misc2] * X;
				if (Y >= A && Y < A + B)
				{
					return 8;
				}
				A = A + B;
				B = cvar_value_chance[loot_h_chance_nodrop] * X;
				if (Y >= A && Y < A + B)
				{
					return 0;
				}
			}
			else
			{
				return 0;
			}
		}
		case 4:
		{
			Sum = cvar_value_chance[loot_sp_chance_health];
			Sum += cvar_value_chance[loot_sp_chance_melee];
			Sum += cvar_value_chance[loot_sp_chance_bullet];
			Sum += cvar_value_chance[loot_sp_chance_explosive];
			Sum += cvar_value_chance[loot_sp_chance_throw];
			Sum += cvar_value_chance[loot_sp_chance_upgrades];
			Sum += cvar_value_chance[loot_sp_chance_misc];
			Sum += cvar_value_chance[loot_sp_chance_misc2];
			Sum += cvar_value_chance[loot_sp_chance_nodrop];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_chance[loot_sp_chance_health] * X;
				if (Y >= A && Y < A + B)
				{
					return 1;
				}
				A = A + B;
				B = cvar_value_chance[loot_sp_chance_melee] * X;
				if (Y >= A && Y < A + B)
				{
					return 2;
				}
				A = A + B;
				B = cvar_value_chance[loot_sp_chance_bullet] * X;
				if (Y >= A && Y < A + B)
				{
					return 3;
				}
				A = A + B;
				B = cvar_value_chance[loot_sp_chance_explosive] * X;
				if (Y >= A && Y < A + B)
				{
					return 4;
				}
				A = A + B;
				B = cvar_value_chance[loot_sp_chance_throw] * X;
				if (Y >= A && Y < A + B)
				{
					return 5;
				}
				A = A + B;
				B = cvar_value_chance[loot_sp_chance_upgrades] * X;
				if (Y >= A && Y < A + B)
				{
					return 6;
				}
				A = A + B;
				B = cvar_value_chance[loot_sp_chance_misc] * X;
				if (Y >= A && Y < A + B)
				{
					return 7;
				}
				A = A + B;
				B = cvar_value_chance[loot_sp_chance_misc2] * X;
				if (Y >= A && Y < A + B)
				{
					return 8;
				}
				A = A + B;
				B = cvar_value_chance[loot_sp_chance_nodrop] * X;
				if (Y >= A && Y < A + B)
				{
					return 0;
				}
			}
			else
			{
				return 0;
			}
		}
		case 5:
		{
			Sum = cvar_value_chance[loot_j_chance_health];
			Sum += cvar_value_chance[loot_j_chance_melee];
			Sum += cvar_value_chance[loot_j_chance_bullet];
			Sum += cvar_value_chance[loot_j_chance_explosive];
			Sum += cvar_value_chance[loot_j_chance_throw];
			Sum += cvar_value_chance[loot_j_chance_upgrades];
			Sum += cvar_value_chance[loot_j_chance_misc];
			Sum += cvar_value_chance[loot_j_chance_misc2];
			Sum += cvar_value_chance[loot_j_chance_nodrop];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_chance[loot_j_chance_health] * X;
				if (Y >= A && Y < A + B)
				{
					return 1;
				}
				A = A + B;
				B = cvar_value_chance[loot_j_chance_melee] * X;
				if (Y >= A && Y < A + B)
				{
					return 2;
				}
				A = A + B;
				B = cvar_value_chance[loot_j_chance_bullet] * X;
				if (Y >= A && Y < A + B)
				{
					return 3;
				}
				A = A + B;
				B = cvar_value_chance[loot_j_chance_explosive] * X;
				if (Y >= A && Y < A + B)
				{
					return 4;
				}
				A = A + B;
				B = cvar_value_chance[loot_j_chance_throw] * X;
				if (Y >= A && Y < A + B)
				{
					return 5;
				}
				A = A + B;
				B = cvar_value_chance[loot_j_chance_upgrades] * X;
				if (Y >= A && Y < A + B)
				{
					return 6;
				}
				A = A + B;
				B = cvar_value_chance[loot_j_chance_misc] * X;
				if (Y >= A && Y < A + B)
				{
					return 7;
				}
				A = A + B;
				B = cvar_value_chance[loot_j_chance_misc2] * X;
				if (Y >= A && Y < A + B)
				{
					return 8;
				}
				A = A + B;
				B = cvar_value_chance[loot_j_chance_nodrop] * X;
				if (Y >= A && Y < A + B)
				{
					return 0;
				}
			}
			else
			{
				return 0;
			}
		}
		case 6:
		{
			Sum = cvar_value_chance[loot_c_chance_health];
			Sum += cvar_value_chance[loot_c_chance_melee];
			Sum += cvar_value_chance[loot_c_chance_bullet];
			Sum += cvar_value_chance[loot_c_chance_explosive];
			Sum += cvar_value_chance[loot_c_chance_throw];
			Sum += cvar_value_chance[loot_c_chance_upgrades];
			Sum += cvar_value_chance[loot_c_chance_misc];
			Sum += cvar_value_chance[loot_c_chance_misc2];
			Sum += cvar_value_chance[loot_c_chance_nodrop];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_chance[loot_c_chance_health] * X;
				if (Y >= A && Y < A + B)
				{
					return 1;
				}
				A = A + B;
				B = cvar_value_chance[loot_c_chance_melee] * X;
				if (Y >= A && Y < A + B)
				{
					return 2;
				}
				A = A + B;
				B = cvar_value_chance[loot_c_chance_bullet] * X;
				if (Y >= A && Y < A + B)
				{
					return 3;
				}
				A = A + B;
				B = cvar_value_chance[loot_c_chance_explosive] * X;
				if (Y >= A && Y < A + B)
				{
					return 4;
				}
				A = A + B;
				B = cvar_value_chance[loot_c_chance_throw] * X;
				if (Y >= A && Y < A + B)
				{
					return 5;
				}
				A = A + B;
				B = cvar_value_chance[loot_c_chance_upgrades] * X;
				if (Y >= A && Y < A + B)
				{
					return 6;
				}
				A = A + B;
				B = cvar_value_chance[loot_c_chance_misc] * X;
				if (Y >= A && Y < A + B)
				{
					return 7;
				}
				A = A + B;
				B = cvar_value_chance[loot_c_chance_misc2] * X;
				if (Y >= A && Y < A + B)
				{
					return 8;
				}
				A = A + B;
				B = cvar_value_chance[loot_c_chance_nodrop] * X;
				if (Y >= A && Y < A + B)
				{
					return 0;
				}
			}
			else
			{
				return 0;
			}
		}
		case 8:
		{
			Sum = cvar_value_chance[loot_t_chance_health];
			Sum += cvar_value_chance[loot_t_chance_melee];
			Sum += cvar_value_chance[loot_t_chance_bullet];
			Sum += cvar_value_chance[loot_t_chance_explosive];
			Sum += cvar_value_chance[loot_t_chance_throw];
			Sum += cvar_value_chance[loot_t_chance_upgrades];
			Sum += cvar_value_chance[loot_t_chance_misc];
			Sum += cvar_value_chance[loot_t_chance_misc2];
			Sum += cvar_value_chance[loot_t_chance_nodrop];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_chance[loot_t_chance_health] * X;
				if (Y >= A && Y < A + B)
				{
					return 1;
				}
				A = A + B;
				B = cvar_value_chance[loot_t_chance_melee] * X;
				if (Y >= A && Y < A + B)
				{
					return 2;
				}
				A = A + B;
				B = cvar_value_chance[loot_t_chance_bullet] * X;
				if (Y >= A && Y < A + B)
				{
					return 3;
				}
				A = A + B;
				B = cvar_value_chance[loot_t_chance_explosive] * X;
				if (Y >= A && Y < A + B)
				{
					return 4;
				}
				A = A + B;
				B = cvar_value_chance[loot_t_chance_throw] * X;
				if (Y >= A && Y < A + B)
				{
					return 5;
				}
				A = A + B;
				B = cvar_value_chance[loot_t_chance_upgrades] * X;
				if (Y >= A && Y < A + B)
				{
					return 6;
				}
				A = A + B;
				B = cvar_value_chance[loot_t_chance_misc] * X;
				if (Y >= A && Y < A + B)
				{
					return 7;
				}
				A = A + B;
				B = cvar_value_chance[loot_t_chance_misc2] * X;
				if (Y >= A && Y < A + B)
				{
					return 8;
				}
				A = A + B;
				B = cvar_value_chance[loot_t_chance_nodrop] * X;
				if (Y >= A && Y < A + B)
				{
					return 0;
				}
			}
			else
			{
				return 0;
			}
		}
	}
	return 0;
}

int GetRandomItem(const int Group)
{
	if (Group == 0)
	{
		return 0;
	}

	int Sum = 0;
	switch (Group)
	{
		case 1:
		{
			Sum = cvar_value_loot[loot_first_aid_kit];
			Sum += cvar_value_loot[loot_defibrillator];
			Sum += cvar_value_loot[loot_pain_pills];
			Sum += cvar_value_loot[loot_adrenaline];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_loot[loot_first_aid_kit] * X;
				if (Y >= A && Y < A + B)
				{
					return 1;
				}
				A = A + B;
				B = cvar_value_loot[loot_defibrillator] * X;
				if (Y >= A && Y < A + B)
				{
					return 2;
				}
				A = A + B;
				B = cvar_value_loot[loot_pain_pills] * X;
				if (Y >= A && Y < A + B)
				{
					return 3;
				}
				A = A + B;
				B = cvar_value_loot[loot_adrenaline] * X;
				if (Y >= A && Y < A + B)
				{
					return 4;
				}
			}
			else
			{
				return 0;
			}
		}
		case 2:
		{
			Sum = cvar_value_loot[loot_cricket_bat];
			Sum += cvar_value_loot[loot_crowbar];
			Sum += cvar_value_loot[loot_electric_guitar];
			Sum += cvar_value_loot[loot_chainsaw];
			Sum += cvar_value_loot[loot_katana];
			Sum += cvar_value_loot[loot_machete];
			Sum += cvar_value_loot[loot_tonfa];
			Sum += cvar_value_loot[loot_frying_pan];
			Sum += cvar_value_loot[loot_fireaxe];
			Sum += cvar_value_loot[loot_baseball_bat];
			Sum += cvar_value_loot[loot_knife];
			Sum += cvar_value_loot[loot_riotshield];
			Sum += cvar_value_loot[loot_shovel];
			Sum += cvar_value_loot[loot_pitchfork];
			Sum += cvar_value_loot[loot_golfclub];
			Sum += MeleeExtra.Length ? cvar_value_loot[loot_melee_extra] : 0;
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_loot[loot_cricket_bat] * X;
				if (Y >= A && Y < A + B)
				{
					return 5;
				}
				A = A + B;
				B = cvar_value_loot[loot_crowbar] * X;
				if (Y >= A && Y < A + B)
				{
					return 6;
				}
				A = A + B;
				B = cvar_value_loot[loot_electric_guitar] * X;
				if (Y >= A && Y < A + B)
				{
					return 7;
				}
				A = A + B;
				B = cvar_value_loot[loot_chainsaw] * X;
				if (Y >= A && Y < A + B)
				{
					return 8;
				}
				A = A + B;
				B = cvar_value_loot[loot_katana] * X;
				if (Y >= A && Y < A + B)
				{
					return 9;
				}
				A = A + B;
				B = cvar_value_loot[loot_machete] * X;
				if (Y >= A && Y < A + B)
				{
					return 10;
				}
				A = A + B;
				B = cvar_value_loot[loot_tonfa] * X;
				if (Y >= A && Y < A + B)
				{
					return 11;
				}
				A = A + B;
				B = cvar_value_loot[loot_frying_pan] * X;
				if (Y >= A && Y < A + B)
				{
					return 13;
				}
				A = A + B;
				B = cvar_value_loot[loot_fireaxe] * X;
				if (Y >= A && Y < A + B)
				{
					return 14;
				}
				A = A + B;
				B = cvar_value_loot[loot_baseball_bat] * X;
				if (Y >= A && Y < A + B)
				{
					return 12;
				}
				A = A + B;
				B = cvar_value_loot[loot_knife] * X;
				if (Y >= A && Y < A + B)
				{
					return 40;
				}
				A = A + B;
				B = cvar_value_loot[loot_golfclub] * X;
				if (Y >= A && Y < A + B)
				{
					return 43;
				}
				A = A + B;
				B = cvar_value_loot[loot_riotshield] * X;
				if (Y >= A && Y < A + B)
				{
					return 45;
				}
				A = A + B;
				B = cvar_value_loot[loot_shovel] * X;
				if (Y >= A && Y < A + B)
				{
					return 48;
				}
				A = A + B;
				B = cvar_value_loot[loot_pitchfork] * X;
				if (Y >= A && Y < A + B)
				{
					return 49;
				}
				if (MeleeExtra.Length)
				{
					A = A + B;
					B = cvar_value_loot[loot_melee_extra] * X;
					if (Y >= A && Y < A + B)
					{
						return 50;
					}
				}
			}
			else
			{
				return 0;
			}
		}
		case 3:
		{
			Sum = cvar_value_loot[loot_pistol];
			Sum += cvar_value_loot[loot_pistol_magnum];
			Sum += cvar_value_loot[loot_smg];
			Sum += cvar_value_loot[loot_smg_silenced];
			Sum += cvar_value_loot[loot_pumpshotgun];
			Sum += cvar_value_loot[loot_shotgun_chrome];
			Sum += cvar_value_loot[loot_shotgun_spas];
			Sum += cvar_value_loot[loot_autoshotgun];
			Sum += cvar_value_loot[loot_sniper_military];
			Sum += cvar_value_loot[loot_hunting_rifle];
			Sum += cvar_value_loot[loot_rifle];
			Sum += cvar_value_loot[loot_rifle_desert];
			Sum += cvar_value_loot[loot_rifle_ak47];
			Sum += cvar_value_loot[loot_rifle_m60];
			Sum += cvar_value_loot[loot_smg_mp5];
			Sum += cvar_value_loot[loot_sniper_scout];
			Sum += cvar_value_loot[loot_sniper_awp];
			Sum += cvar_value_loot[loot_rifle_sg552];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_loot[loot_pistol] * X;
				if (Y >= A && Y < A + B)
				{
					return 15;
				}
				A = A + B;
				B = cvar_value_loot[loot_pistol_magnum] * X;
				if (Y >= A && Y < A + B)
				{
					return 16;
				}
				A = A + B;
				B = cvar_value_loot[loot_smg] * X;
				if (Y >= A && Y < A + B)
				{
					return 17;
				}
				A = A + B;
				B = cvar_value_loot[loot_smg_silenced] * X;
				if (Y >= A && Y < A + B)
				{
					return 19;
				}
				A = A + B;
				B = cvar_value_loot[loot_pumpshotgun] * X;
				if (Y >= A && Y < A + B)
				{
					return 20;
				}
				A = A + B;
				B = cvar_value_loot[loot_shotgun_chrome] * X;
				if (Y >= A && Y < A + B)
				{
					return 21;
				}
				A = A + B;
				B = cvar_value_loot[loot_shotgun_spas] * X;
				if (Y >= A && Y < A + B)
				{
					return 22;
				}
				A = A + B;
				B = cvar_value_loot[loot_autoshotgun] * X;
				if (Y >= A && Y < A + B)
				{
					return 39;
				}
				A = A + B;
				B = cvar_value_loot[loot_sniper_military] * X;
				if (Y >= A && Y < A + B)
				{
					return 24;
				}
				A = A + B;
				B = cvar_value_loot[loot_hunting_rifle] * X;
				if (Y >= A && Y < A + B)
				{
					return 26;
				}
				A = A + B;
				B = cvar_value_loot[loot_rifle] * X;
				if (Y >= A && Y < A + B)
				{
					return 27;
				}
				A = A + B;
				B = cvar_value_loot[loot_rifle_desert] * X;
				if (Y >= A && Y < A + B)
				{
					return 28;
				}
				A = A + B;
				B = cvar_value_loot[loot_rifle_ak47] * X;
				if (Y >= A && Y < A + B)
				{
					return 29;
				}
				A = A + B;
				B = cvar_value_loot[loot_rifle_m60] * X;
				if (Y >= A && Y < A + B)
				{
					return 44;
				}
				A = A + B;
				B = cvar_value_loot[loot_smg_mp5] * X;
				if (Y >= A && Y < A + B)
				{
					return 18;
				}
				A = A + B;
				B = cvar_value_loot[loot_sniper_scout] * X;
				if (Y >= A && Y < A + B)
				{
					return 23;
				}
				A = A + B;
				B = cvar_value_loot[loot_sniper_awp] * X;
				if (Y >= A && Y < A + B)
				{
					return 25;
				}
				A = A + B;
				B = cvar_value_loot[loot_rifle_sg552] * X;
				if (Y >= A && Y < A + B)
				{
					return 30;
				}
			}
			else
			{
				return 0;
			}
		}
		case 4:
		{
			Sum = cvar_value_loot[loot_grenade_launcher];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_loot[loot_grenade_launcher] * X;
				if (Y >= A && Y < A + B)
				{
					return 31;
				}
			}
			else
			{
				return 0;
			}
		}
		case 5:
		{
			Sum = cvar_value_loot[loot_pipe_bomb];
			Sum += cvar_value_loot[loot_molotov];
			Sum += cvar_value_loot[loot_vomitjar];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_loot[loot_pipe_bomb] * X;
				if (Y >= A && Y < A + B)
				{
					return 32;
				}
				A = A + B;
				B = cvar_value_loot[loot_molotov] * X;
				if (Y >= A && Y < A + B)
				{
					return 33;
				}
				A = A + B;
				B = cvar_value_loot[loot_vomitjar] * X;
				if (Y >= A && Y < A + B)
				{
					return 34;
				}
			}
			else
			{
				return 0;
			}
		}
		case 6:
		{
			Sum = cvar_value_loot[loot_upgradepack_exp];
			Sum += cvar_value_loot[loot_upgradepack_inc];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_loot[loot_upgradepack_exp] * X;
				if (Y >= A && Y < A + B)
				{
					return 35;
				}
				A = A + B;
				B = cvar_value_loot[loot_upgradepack_inc] * X;
				if (Y >= A && Y < A + B)
				{
					return 36;
				}
			}
			else
			{
				return 0;
			}
		}
		case 7:
		{
			Sum = cvar_value_loot[loot_fireworkcrate];
			Sum += cvar_value_loot[loot_gascan];
			Sum += cvar_value_loot[loot_oxygentank];
			Sum += cvar_value_loot[loot_propanetank];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_loot[loot_fireworkcrate] * X;
				if (Y >= A && Y < A + B)
				{
					return 37;
				}
				A = A + B;
				B = cvar_value_loot[loot_gascan] * X;
				if (Y >= A && Y < A + B)
				{
					return 38;
				}
				A = A + B;
				B = cvar_value_loot[loot_oxygentank] * X;
				if (Y >= A && Y < A + B)
				{
					return 41;
				}
				A = A + B;
				B = cvar_value_loot[loot_propanetank] * X;
				if (Y >= A && Y < A + B)
				{
					return 42;
				}
			}
			else
			{
				return 0;
			}
		}
		case 8:
		{
			Sum = cvar_value_loot[loot_gnome];
			Sum += cvar_value_loot[loot_cola_bottles];
			if (Sum > 0)
			{
				float X = 100.0 / Sum;
				float Y = 100.0 * GetURandomFloat();
				float A = 0.0;
				float B = cvar_value_loot[loot_gnome] * X;
				if (Y >= A && Y < A + B)
				{
					return 46;
				}
				A = A + B;
				B = cvar_value_loot[loot_cola_bottles] * X;
				if (Y >= A && Y < A + B)
				{
					return 47;
				}
			}
			else
			{
				return 0;
			}
		}
	}
	return 0;
}

void LootDropItem(int client, int ItemNumber)
{
	if (ItemNumber > 0)
	{
		char ItemName[32];
		int iRandSkin = 0;
		switch (ItemNumber)
		{
			case 1: ItemName = "first_aid_kit";
			case 2: ItemName = "defibrillator";
			case 3: ItemName = "pain_pills";
			case 4: ItemName = "adrenaline";
			case 5: ItemName = "cricket_bat"; // iRandSkin = 1;
			case 6: ItemName = "crowbar"; // iRandSkin = 1;
			case 7: ItemName = "electric_guitar";
			case 8: ItemName = "chainsaw";
			case 9: ItemName = "katana";
			case 10: ItemName = "machete";
			case 11: ItemName = "tonfa";
			case 12: ItemName = "baseball_bat";
			case 13: ItemName = "frying_pan";
			case 14: ItemName = "fireaxe";
			case 15: ItemName = "pistol";
			case 16: { ItemName = "pistol_magnum"; iRandSkin = 2; }
			case 17: { ItemName = "smg"; iRandSkin = 1; }
			case 18: ItemName = "smg_mp5"; // need precache
			case 19: { ItemName = "smg_silenced"; iRandSkin = 1; }
			case 20: { ItemName = "pumpshotgun"; iRandSkin = 1; }
			case 21: { ItemName = "shotgun_chrome"; iRandSkin = 1; }
			case 22: ItemName = "shotgun_spas";
			case 23: ItemName = "sniper_scout"; // need precache
			case 24: ItemName = "sniper_military";
			case 25: ItemName = "sniper_awp"; // need precache
			case 26: { ItemName = "hunting_rifle"; iRandSkin = 1; }
			case 27: { ItemName = "rifle"; iRandSkin = 2; }
			case 28: ItemName = "rifle_desert";
			case 29: { ItemName = "rifle_ak47"; iRandSkin = 2; }
			case 30: ItemName = "rifle_sg552"; // need precache
			case 31: ItemName = "grenade_launcher";
			case 32: ItemName = "pipe_bomb";
			case 33: ItemName = "molotov";
			case 34: ItemName = "vomitjar";
			case 35: ItemName = "upgradepack_explosive";
			case 36: ItemName = "upgradepack_incendiary";
			case 37: ItemName = "fireworkcrate";
			case 38: ItemName = "gascan";
			case 39: { ItemName = "autoshotgun"; iRandSkin = 1; }
			case 40: ItemName = "knife"; // protected
			case 41: ItemName = "oxygentank";
			case 42: ItemName = "propanetank";
			case 43: ItemName = "golfclub";
			case 44: ItemName = "rifle_m60"; // need precache on some maps
			case 45: ItemName = "riotshield"; // need precache on some maps
			case 46: ItemName = "gnome"; // need precache on some maps
			case 47: ItemName = "cola_bottles"; // need precache on some maps
			case 48: ItemName = "shovel"; // need precache on some maps
			case 49: ItemName = "pitchfork"; // need precache on some maps
			case 50: MeleeExtra.GetString(GetRandomInt(0, MeleeExtra.Length - 1), ItemName, sizeof(ItemName));
		}

		int weapon = GivePlayerItem(client, ItemName);
		if (iRandSkin && weapon != -1)
		{
			SetEntProp(weapon, Prop_Send, "m_nSkin", GetRandomInt(0, iRandSkin));
		}
	}
}