#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define MAX_BUY_COUNT 2

int g_iBuyLeft;

int WeaponBuyCount[MAXPLAYERS+1][20];

public Plugin myinfo =
{
	name = "Opposite buy menu",
	author = "Accelerator",
	description = "",
	version = "2.0",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	RegConsoleCmd("obuy", Command_OBuy);
	HookEvent("round_start", Event_OnRoundStart);
	HookEvent("round_freeze_end", Event_OnRoundStart);
}

public Action Event_OnRoundStart(Event hEvent, const char[] name, bool dontBroadcast)
{
	if (StrEqual(name, "round_freeze_end"))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			for (int k = 0; k < sizeof(WeaponBuyCount[]); k++)
				WeaponBuyCount[i][k] = 0;
		}
	}
	g_iBuyLeft = GetTime() + FindConVar("mp_buytime").IntValue;
	
	return Plugin_Continue;
}

public Action Command_OBuy(int client, int args)
{
	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;
	
	if (!AllowBuy(client))
		return Plugin_Handled;
	
	if (GetClientTeam(client) == CS_TEAM_T)
	{
		Panel bPanel = new Panel();
		SetPanelTitle(bPanel, "Counter-Terrorists Buy Menu");
		
		char Value[64];
		
		Format(Value, sizeof(Value), "USP-S/P2000 [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_HKP2000));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "Five-SeveN [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_FIVESEVEN));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "MAG-7 [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_MAG7));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "MP9 [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_MP9));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "Famas [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_FAMAS));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "M4A1/M4A1S [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_M4A1));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "AUG [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_AUG));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "SCAR-20 [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_SCAR20));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "IncGrenade [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_INCGRENADE));
		bPanel.DrawItem(Value);
		
		bPanel.Send(client, PanelHandlerCT, 10);
		delete bPanel;
		return Plugin_Continue;
	}
	if (GetClientTeam(client) == CS_TEAM_CT)
	{
		Panel bPanel = new Panel();
		SetPanelTitle(bPanel, "Terrorists Buy Menu");
		
		char Value[64];
		
		Format(Value, sizeof(Value), "Glock-18 [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_GLOCK));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "TEC-9 [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_TEC9));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "Sawed-Off [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_SAWEDOFF));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "MAC-10 [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_MAC10));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "Galil AR [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_GALILAR));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "AK47 [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_AK47));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "SG553 [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_SG556));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "G3SG1 [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_G3SG1));
		bPanel.DrawItem(Value);
		Format(Value, sizeof(Value), "Molotov [ %i $ ]", CS_GetWeaponPrice(client, CSWeapon_MOLOTOV));
		bPanel.DrawItem(Value);
		
		bPanel.Send(client, PanelHandlerT, 10);
		delete bPanel;
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

public int PanelHandlerCT(Menu panel, MenuAction action, int client, int option)
{
	if (action != MenuAction_Select)
		return;

	if (!AllowBuy(client))
		return;
	
	bool CallMenu = true;
	switch (option)
	{
		case 1:
		{
			Panel bPanel = new Panel();
			SetPanelTitle(bPanel, "Select Weapon");
			
			bPanel.DrawItem("USP-S");
			bPanel.DrawItem("P2000");
			
			bPanel.Send(client, PanelHandlerUSP, 10);
			delete bPanel;
			CallMenu = false;
		}
		case 2:
		{
			if (WeaponBuyCount[client][0]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_FIVESEVEN);
			if (BuyWeapon(client, "weapon_fiveseven", Price, 1) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03Five-SeveN\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 3:
		{
			if (WeaponBuyCount[client][1]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_MAG7);
			if (BuyWeapon(client, "weapon_mag7", Price, 0) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03MAG-7\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 4:
		{
			if (WeaponBuyCount[client][2]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_MP9);
			if (BuyWeapon(client, "weapon_mp9", Price, 0) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03MP-9\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 5:
		{
			if (WeaponBuyCount[client][3]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_FAMAS);
			if (BuyWeapon(client, "weapon_famas", Price, 0) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03Famas\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 6:
		{
			Panel bPanel = new Panel();
			SetPanelTitle(bPanel, "Select Weapon");
			
			bPanel.DrawItem("M4A1");
			bPanel.DrawItem("M4A1-S");
			
			bPanel.Send(client, PanelHandlerM4A1, 10);
			delete bPanel;
			CallMenu = false;
		}
		case 7:
		{
			if (WeaponBuyCount[client][4]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_AUG);
			if (BuyWeapon(client, "weapon_aug", Price, 0) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03AUG\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 8:
		{
			if (WeaponBuyCount[client][5]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_SCAR20);
			if (BuyWeapon(client, "weapon_scar20", Price, 0) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03SCAR-20\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 9:
		{
			if (WeaponBuyCount[client][6]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_INCGRENADE);
			if (BuyWeapon(client, "weapon_incgrenade", Price) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03IncGrenade\x01! The price is \x03$%i\x01!", Price);
			}
		}
	}
	if (CallMenu) Command_OBuy(client, 0);
}

public int PanelHandlerUSP(Menu panel, MenuAction action, int client, int option)
{
	if (action != MenuAction_Select)
		return;
	
	if (!AllowBuy(client))
		return;
	
	switch (option)
	{
		case 1:
		{
			if (WeaponBuyCount[client][7]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_HKP2000);
			if (BuyWeapon(client, "weapon_usp_silencer", Price, 1) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03USP-S\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 2:
		{
			if (WeaponBuyCount[client][8]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_HKP2000);
			if (BuyWeapon(client, "weapon_hkp2000", Price, 1) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03P2000\x01! The price is \x03$%i\x01!", Price);
			}
		}
	}
	Command_OBuy(client, 0);
}

public int PanelHandlerM4A1(Menu panel, MenuAction action, int client, int option)
{
	if (action != MenuAction_Select)
		return;
	
	if (!AllowBuy(client))
		return;
	
	switch (option)
	{
		case 1:
		{
			if (WeaponBuyCount[client][9]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_M4A1);
			if (BuyWeapon(client, "weapon_m4a1", Price, 0) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03M4A1\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 2:
		{
			if (WeaponBuyCount[client][10]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_M4A1);
			if (BuyWeapon(client, "weapon_m4a1_silencer", Price, 0) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03M4A1-Sx01! The price is \x03$%i\x01!", Price);
			}
		}
	}
	Command_OBuy(client, 0);
}

public int PanelHandlerT(Menu panel, MenuAction action, int client, int option)
{
	if (action != MenuAction_Select)
		return;
	
	if (!AllowBuy(client))
		return;
	
	switch (option)
	{
		case 1:
		{
			if (WeaponBuyCount[client][11]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_GLOCK);
			if (BuyWeapon(client, "weapon_glock", Price, 1) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03Glock-18\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 2:
		{
			if (WeaponBuyCount[client][12]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_TEC9);
			if (BuyWeapon(client, "weapon_tec9", Price, 1) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03TEC-9\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 3:
		{
			if (WeaponBuyCount[client][13]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_SAWEDOFF);
			if (BuyWeapon(client, "weapon_sawedoff", Price, 0) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03Sawed-Off\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 4:
		{
			if (WeaponBuyCount[client][14]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_MAC10);
			if (BuyWeapon(client, "weapon_mac10", Price, 0) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03MAC-10\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 5:
		{
			if (WeaponBuyCount[client][15]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_GALILAR);
			if (BuyWeapon(client, "weapon_galilar", Price, 0) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03Galil AR\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 6:
		{
			if (WeaponBuyCount[client][16]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_AK47);
			if (BuyWeapon(client, "weapon_ak47", Price, 0) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03AK-47\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 7:
		{
			if (WeaponBuyCount[client][17]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_SG556);
			if (BuyWeapon(client, "weapon_sg556", Price, 0) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03SG553\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 8:
		{
			if (WeaponBuyCount[client][18]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_G3SG1);
			if (BuyWeapon(client, "weapon_g3sg1", Price, 0) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03G3SG1\x01! The price is \x03$%i\x01!", Price);
			}
		}
		case 9:
		{
			if (WeaponBuyCount[client][19]++ >= MAX_BUY_COUNT)
			{
				PrintToChat(client, "You have already bought this weapon in this round!");
				Command_OBuy(client, 0);
				return;
			}
			int Price = CS_GetWeaponPrice(client, CSWeapon_MOLOTOV);
			if (BuyWeapon(client, "weapon_molotov", Price) == 0)
			{
				PrintToChat(client, "You doesn't have enough cash to buy an \x03Molotov\x01! The price is \x03$%i\x01!", Price);
			}
		}
	}
	Command_OBuy(client, 0);
}

stock int BuyWeapon(int client, const char[] weapon_name, int Price, int slotid = -1)
{
	int Cash = GetEntProp(client, Prop_Send, "m_iAccount");
	if (Cash >= Price)
	{
		if (slotid > -1)
		{
			int slot = GetPlayerWeaponSlot(client, slotid);
			if (slot > 0)
			{
				CS_DropWeapon(client, slot, false);
			}
		}
		int item = GivePlayerItem(client, weapon_name);
		if (item > 0)
		{
			Cash -= Price;
			SetEntProp(client, Prop_Send, "m_iAccount", Cash);
			
			return 1;
		}
		return -1;
	}
	return 0;
}

bool AllowBuy(int client)
{
	if (FindConVar("mp_buy_anywhere").IntValue == 0)
	{
		if (!GetEntProp(client, Prop_Send, "m_bInBuyZone"))
		{
			PrintToChat(client, "You left the buy zone");
			return false;
		}
	}
	
	if (GetTime() > g_iBuyLeft)
	{
		PrintToChat(client, "Buying time expired");
		return false;
	}
	
	return true;
}