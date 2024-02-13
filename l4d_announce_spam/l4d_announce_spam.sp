#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

public Plugin myinfo =
{
	name = "[L4D] Announce Spam",
	author = "Accelerator",
	description = "Reduce the spam of informational gaming messages",
	version = "1.0",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	HookEvent("player_incapacitated", Event_DontBroadcast, EventHookMode_Pre);
	HookEvent("player_death", Event_DontBroadcast, EventHookMode_Pre);

	GameData hGameData = new GameData("l4d_announce");
	if (hGameData == null) {
		SetFailState("Failed to load \"l4d_announce.txt\" gamedata.");
	}

	DynamicDetour detour;

	if (hGameData.GetOffset("os") == 1) // windows
	{
		Address addr = hGameData.GetAddress("HitAnnouncement");
		if (addr == Address_Null) {
			SetFailState("Could not load the HitAnnouncement address");
		}

		Address pRelativeOffset = LoadFromAddress(addr + view_as<Address>(1), NumberType_Int32);
		Address pFunc = addr + view_as<Address>(5) + pRelativeOffset;

		detour = new DynamicDetour(pFunc, CallConv_CDECL, ReturnType_Bool, ThisPointer_Ignore);
		detour.AddParam(HookParamType_ObjectPtr);
	}
	else
	{
		detour = DynamicDetour.FromConf(hGameData, "HitAnnouncement");
	}

	if (!detour.Enable(Hook_Pre, HitAnnouncement)) {
		SetFailState("Failed to detour: HitAnnouncement");
	}

	delete detour;
	delete hGameData;
}

MRESReturn HitAnnouncement(DHookReturn hReturn, DHookParam hParams)
{
	int iMsgType = hParams.GetObjectVar(1, 0, ObjectValueType_Int);

	switch (iMsgType)
	{
		case 7, 9: { // AssistedAgainst, Hit
			int victim = hParams.GetObjectVar(1, 4, ObjectValueType_CBaseEntityPtr);
			int attacker = hParams.GetObjectVar(1, 8, ObjectValueType_CBaseEntityPtr);

			if (victim < 1 || attacker < 1)
			{
				return MRES_Ignored;
			}

			if (GetClientTeam(attacker) == 3)
			{
				float gmtime = GetEngineTime();
				static float fMsgTime[33][33];

				if (gmtime - fMsgTime[attacker][victim] >= 1.0)
				{
					fMsgTime[attacker][victim] = gmtime;
					return MRES_Ignored;
				}
			}
			else
			{
				if (iMsgType != 7)
				{
					return MRES_Ignored;
				}
			}
		}
		case 15, 18, 19: {} // Saved, Protected, Rescued
		default: return MRES_Ignored;
	}

	hReturn.Value = 0;
	return MRES_Supercede;
}

void Event_DontBroadcast(Event event, const char[] name, bool dontBroadcast)
{
	int enemy = GetClientOfUserId(event.GetInt("attacker"));
	int target = GetClientOfUserId(event.GetInt("userid"));

	if (!target || !enemy)
		return;

	if (!IsFakeClient(enemy))
		return;

	event.BroadcastDisabled = true;
}