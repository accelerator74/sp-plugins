#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =
{
    name = "[L4D2] Weapon Drop !drop",
    author = "Accelerator",
    description = "",
    version = "1.0",
    url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_drop", Command_Drop);
}

public Action Command_Drop(int client, int args)
{
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return Plugin_Handled;

	int PlayerWeaponSlot1 = GetPlayerWeaponSlot(client, 0);
	
	if (PlayerWeaponSlot1 > 0)
	{
		char weapon[32];
		GetEdictClassname(PlayerWeaponSlot1, weapon, sizeof(weapon));
		
		int ammo;
		int ammoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
		if (StrEqual(weapon, "weapon_rifle") || StrEqual(weapon, "weapon_rifle_sg552") || StrEqual(weapon, "weapon_rifle_desert") || StrEqual(weapon, "weapon_rifle_ak47"))
		{
			ammo = GetEntData(client, ammoOffset+(12));
			SetEntData(client, ammoOffset+(12), 0);
		}
		else if (StrEqual(weapon, "weapon_smg") || StrEqual(weapon, "weapon_smg_silenced") || StrEqual(weapon, "weapon_smg_mp5"))
		{
			ammo = GetEntData(client, ammoOffset+(20));
			SetEntData(client, ammoOffset+(20), 0);
		}
		else if (StrEqual(weapon, "weapon_pumpshotgun") || StrEqual(weapon, "weapon_shotgun_chrome"))
		{
			ammo = GetEntData(client, ammoOffset+(28));
			SetEntData(client, ammoOffset+(28), 0);
		}
		else if (StrEqual(weapon, "weapon_autoshotgun") || StrEqual(weapon, "weapon_shotgun_spas"))
		{
			ammo = GetEntData(client, ammoOffset+(32));
			SetEntData(client, ammoOffset+(32), 0);
		}
		else if (StrEqual(weapon, "weapon_hunting_rifle"))
		{
			ammo = GetEntData(client, ammoOffset+(36));
			SetEntData(client, ammoOffset+(36), 0);
		}
		else if (StrEqual(weapon, "weapon_sniper_scout") || StrEqual(weapon, "weapon_sniper_military") || StrEqual(weapon, "weapon_sniper_awp"))
		{
			ammo = GetEntData(client, ammoOffset+(40));
			SetEntData(client, ammoOffset+(40), 0);
		}
		else if (StrEqual(weapon, "weapon_grenade_launcher"))
		{
			ammo = GetEntData(client, ammoOffset+(68));
			SetEntData(client, ammoOffset+(68), 0);
		}
		
		SDKHooks_DropWeapon(client, PlayerWeaponSlot1);
		SetEntProp(PlayerWeaponSlot1, Prop_Send, "m_iExtraPrimaryAmmo", ammo);
	}

	return Plugin_Continue;
}