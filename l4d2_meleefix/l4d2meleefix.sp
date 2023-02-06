#include <sourcemod>
#include <sdkhooks>

#define SMOKER	1
#define BOOMER	2
#define HUNTER	3
#define SPITTER	4
#define JOCKEY	5
#define CHARGER	6
#define TANK	8
#define WITCH	0

new Handle:MeleeDmg[10];
new Handle:MeleeHeadshotDmg[9];

new Float:Damage[10];
new Float:DamageHeadshot[9];

public Plugin:myinfo =
{
	name = "L4D2 Melee Fix",
	description = "Fix melee damage",
	author = "Accelerator",
	version = "1.0",
	url = "https://github.com/accelerator74/sp-plugins"
};

public OnPluginStart()
{
	HookEvent("witch_spawn", OnWitchSpawn_Event);
	HookEvent("witch_killed", OnWitchKilled_Event);
	
	MeleeDmg[SMOKER] = CreateConVar("l4d2_meleefix_smoker", "400.0", "Melee damage Smoker", FCVAR_PLUGIN);
	MeleeDmg[BOOMER] = CreateConVar("l4d2_meleefix_boomer", "400.0", "Melee damage Boomer", FCVAR_PLUGIN);
	MeleeDmg[HUNTER] = CreateConVar("l4d2_meleefix_hunter", "400.0", "Melee damage Hunter", FCVAR_PLUGIN);
	MeleeDmg[JOCKEY] = CreateConVar("l4d2_meleefix_jockey", "400.0", "Melee damage Jockey", FCVAR_PLUGIN);
	MeleeDmg[SPITTER] = CreateConVar("l4d2_meleefix_spitter", "400.0", "Melee damage Spitter", FCVAR_PLUGIN);
	MeleeDmg[CHARGER] = CreateConVar("l4d2_meleefix_charger", "400.0", "Melee damage Charger", FCVAR_PLUGIN);
	MeleeDmg[WITCH] = CreateConVar("l4d2_meleefix_witch", "400.0", "Melee damage Witch", FCVAR_PLUGIN);
	MeleeDmg[TANK] = CreateConVar("l4d2_meleefix_tank", "400.0", "Melee damage Tank", FCVAR_PLUGIN);
	
	MeleeHeadshotDmg[SMOKER] = CreateConVar("l4d2_meleefix_smoker_headshot", "800.0", "Headshot Melee damage Smoker", FCVAR_PLUGIN);
	MeleeHeadshotDmg[BOOMER] = CreateConVar("l4d2_meleefix_boomer_headshot", "800.0", "Headshot Melee damage Boomer", FCVAR_PLUGIN);
	MeleeHeadshotDmg[HUNTER] = CreateConVar("l4d2_meleefix_hunter_headshot", "800.0", "Headshot Melee damage Hunter", FCVAR_PLUGIN);
	MeleeHeadshotDmg[JOCKEY] = CreateConVar("l4d2_meleefix_jockey_headshot", "800.0", "Headshot Melee damage Jockey", FCVAR_PLUGIN);
	MeleeHeadshotDmg[SPITTER] = CreateConVar("l4d2_meleefix_spitter_headshot", "800.0", "Headshot Melee damage Spitter", FCVAR_PLUGIN);
	MeleeHeadshotDmg[CHARGER] = CreateConVar("l4d2_meleefix_charger_headshot", "800.0", "Headshot Melee damage Charger", FCVAR_PLUGIN);
	MeleeHeadshotDmg[TANK] = CreateConVar("l4d2_meleefix_tank_headshot", "1000.0", "Headshot Melee damage Tank", FCVAR_PLUGIN);
	
	HookConVarChange(MeleeDmg[SMOKER], ConVarChanged);
	HookConVarChange(MeleeDmg[BOOMER], ConVarChanged);
	HookConVarChange(MeleeDmg[HUNTER], ConVarChanged);
	HookConVarChange(MeleeDmg[JOCKEY], ConVarChanged);
	HookConVarChange(MeleeDmg[SPITTER], ConVarChanged);
	HookConVarChange(MeleeDmg[CHARGER], ConVarChanged);
	HookConVarChange(MeleeDmg[WITCH], ConVarChanged);
	HookConVarChange(MeleeDmg[TANK], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[SMOKER], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[BOOMER], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[HUNTER], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[JOCKEY], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[SPITTER], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[CHARGER], ConVarChanged);
	HookConVarChange(MeleeHeadshotDmg[TANK], ConVarChanged);
	
	AutoExecConfig(true, "l4d2_meleefix");
	
	ConVarsInit();
}

public ConVarChanged(Handle:hVariable, const String:strOldValue[], const String:strNewValue[])
{
	ConVarsInit();
}

public ConVarsInit()
{
	Damage[SMOKER] = GetConVarFloat(MeleeDmg[SMOKER]);
	Damage[BOOMER] = GetConVarFloat(MeleeDmg[BOOMER]);
	Damage[HUNTER] = GetConVarFloat(MeleeDmg[HUNTER]);
	Damage[JOCKEY] = GetConVarFloat(MeleeDmg[JOCKEY]);
	Damage[SPITTER] = GetConVarFloat(MeleeDmg[SPITTER]);
	Damage[CHARGER] = GetConVarFloat(MeleeDmg[CHARGER]);
	Damage[WITCH] = GetConVarFloat(MeleeDmg[WITCH]);
	Damage[TANK] = GetConVarFloat(MeleeDmg[TANK]);
	
	DamageHeadshot[SMOKER] = GetConVarFloat(MeleeHeadshotDmg[SMOKER]);
	DamageHeadshot[BOOMER] = GetConVarFloat(MeleeHeadshotDmg[BOOMER]);
	DamageHeadshot[HUNTER] = GetConVarFloat(MeleeHeadshotDmg[HUNTER]);
	DamageHeadshot[JOCKEY] = GetConVarFloat(MeleeHeadshotDmg[JOCKEY]);
	DamageHeadshot[SPITTER] = GetConVarFloat(MeleeHeadshotDmg[SPITTER]);
	DamageHeadshot[CHARGER] = GetConVarFloat(MeleeHeadshotDmg[CHARGER]);
	DamageHeadshot[TANK] = GetConVarFloat(MeleeHeadshotDmg[TANK]);
}

public OnClientPutInServer(client)
{
	if (client)
	{
		SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
	}
}

public OnClientDisconnect(client)
{
	if (client)
	{
		SDKUnhook(client, SDKHook_TraceAttack, OnTraceAttack);
	}
}

public OnWitchSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (Damage[WITCH] == 0.0)
		return;

	new witch = GetEventInt(event, "witchid");
	
	if (witch < 1 || !IsValidEntity(witch))
		return;

	SDKHook(witch, SDKHook_OnTakeDamage, OnWitchTakeDamage);
}

public OnWitchKilled_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (Damage[WITCH] == 0.0)
		return;

	new witch = GetEventInt(event, "witchid");
	if (witch < 1 || !IsValidEntity(witch))
		return;

	SDKUnhook(witch, SDKHook_OnTakeDamage, OnWitchTakeDamage);
}

public Action:OnWitchTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (!(damage > 0.0) || attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2) 
		return Plugin_Continue;

	decl String:clsname[64];
	GetEdictClassname(inflictor, clsname, 64);
	
	if (!StrEqual(clsname, "weapon_melee"))
		return Plugin_Continue;

	damage = Damage[WITCH];
	
	return Plugin_Changed;
}

public Action:OnTraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
	if (damage == 0.0 || victim < 1 || victim > MaxClients || !IsClientInGame(victim) || GetClientTeam(victim) != 3 || attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return Plugin_Continue;

	decl String:clsname[64];
	GetEdictClassname(inflictor, clsname, 64);
	
	if (!StrEqual(clsname, "weapon_melee"))
		return Plugin_Continue;

	new zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
	
	if (((zClass > 0) && (zClass < 7)) || (zClass == 8))
	{
		if (Damage[zClass] == 0.0)
			return Plugin_Continue;
		
		if (hitgroup == 1)
		{
			if (DamageHeadshot[zClass] == 0.0)
				return Plugin_Continue;
			
			damage = DamageHeadshot[zClass];
			return Plugin_Changed;
		}
		damage = Damage[zClass];
		
		return Plugin_Changed;
	}

	return Plugin_Continue;
}