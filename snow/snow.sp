#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

ConVar cvar_preciptype;
ConVar cvar_density;
ConVar cvar_color;
ConVar cvar_render;

char sMap[96];

public Plugin myinfo =
{
	name = "Snow precipitation",
	author = "Accelerator",
	description = "Add precipitations to the maps",
	version = "1.0",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	
	cvar_preciptype = CreateConVar("snow_type", "3", "Type of the precipitation (https://developer.valvesoftware.com/wiki/Func_precipitation)");
	cvar_density = CreateConVar("snow_density", "75", "Density of the precipitation");
	cvar_color = CreateConVar("snow_color", "255 255 255", "Color of the precipitation");
	cvar_render = CreateConVar("snow_renderamt", "5", "Render of the precipitation");
}

public void OnMapStart()
{
	GetCurrentMap(sMap, 64);
	Format(sMap, sizeof(sMap), "maps/%s.bsp", sMap);
	PrecacheModel(sMap, true);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.3, CreateSnowFall);
}

public Action CreateSnowFall(Handle timer)
{
	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "func_precipitation")) != -1)
		AcceptEntityInput(iEnt, "Kill");

	iEnt = CreateEntityByName("func_precipitation");

	if (iEnt != -1)
	{
		char preciptype[5], density[5], color[16], render[5];
		float vMins[3], vMax[3], vBuff[3];
		
		cvar_preciptype.GetString(preciptype, sizeof(preciptype));
		cvar_density.GetString(density, sizeof(density));
		cvar_color.GetString(color, sizeof(color));
		cvar_render.GetString(render, sizeof(render));

		DispatchKeyValue(iEnt, "model", sMap);
		DispatchKeyValue(iEnt, "preciptype", preciptype);
		DispatchKeyValue(iEnt, "renderamt", render);
		DispatchKeyValue(iEnt, "density", density);
		DispatchKeyValue(iEnt, "rendercolor", color);

		GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMax);
		GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);

		SetEntPropVector(iEnt, Prop_Send, "m_vecMins", vMins);
		SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", vMax);

		vBuff[0] = vMins[0] + vMax[0];
		vBuff[1] = vMins[1] + vMax[1];
		vBuff[2] = vMins[2] + vMax[2];

		TeleportEntity(iEnt, vBuff, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(iEnt);
		ActivateEntity(iEnt);
	}
}