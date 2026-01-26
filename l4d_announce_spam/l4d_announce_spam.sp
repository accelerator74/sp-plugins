#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

public Plugin myinfo =
{
	name = "[L4D] Announce Spam",
	author = "Accelerator",
	description = "Reduce the spam of informational gaming messages",
	version = "1.4",
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

	if (iMsgType > 6 && iMsgType < 15)
	{
		int victim = hParams.GetObjectVar(1, 4, ObjectValueType_CBaseEntityPtr);
		int attacker = hParams.GetObjectVar(1, 8, ObjectValueType_CBaseEntityPtr);

		if (victim < 1 || attacker < 1)
		{
			return MRES_Ignored;
		}

		if (GetClientTeam(attacker) == 3)
		{
			if (GetClientTeam(victim) != 2)
			{
				return MRES_Ignored;
			}

			int iMsgSlot = -1;
			float gmtime = GetEngineTime();

			static int iMsgSlots[4];
			static float fMsgTime[4];

			for (int i = 0; i < sizeof(iMsgSlots); i++)
			{
				if (iMsgSlots[i] == GetClientUserId(victim))
				{
					iMsgSlot = i;
					break;
				}
			}

			if (iMsgSlot != -1)
			{
				if (gmtime - fMsgTime[iMsgSlot] >= 1.0)
				{
					fMsgTime[iMsgSlot] = gmtime;
					return MRES_Ignored;
				}
			}

			if (iMsgSlot == -1)
			{
				for (int i = 0; i < sizeof(iMsgSlots); i++)
				{
					if (
						!iMsgSlots[i] ||
						(GetClientOfUserId(iMsgSlots[i]) == 0) ||
						(gmtime - fMsgTime[i] >= 2.5)
					)
					{
						iMsgSlots[i] = GetClientUserId(victim);
						fMsgTime[i] = gmtime;
						return MRES_Ignored;
					}
				}
			}

			hReturn.Value = 1;
			return MRES_Supercede;
		}
	}

	if (iMsgType == 15 || iMsgType == 18 || iMsgType == 19)
	{
		hReturn.Value = 1;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

void Event_DontBroadcast(Event event, const char[] name, bool dontBroadcast)
{
	int enemy = GetClientOfUserId(event.GetInt("attacker"));
	int target = GetClientOfUserId(event.GetInt("userid"));

	if (!target || !enemy)
		return;

	if (!IsFakeClient(target))
		return;

	if (GetClientTeam(target) != 3)
		return;

	event.BroadcastDisabled = true;
}