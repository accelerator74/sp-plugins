#include <sourcemod>

#pragma newdecls required
#pragma semicolon 1

Address g_pFuncAddress;
int g_iMinRangeOffset;
int g_iMaxRangeOffset;
int g_iScaleOffset;
int g_iNegativeMinRangeOffset;

Address g_pMinRangeData;
Address g_pMaxRangeData;
Address g_pRangeScaleData;
Address g_pNegativeMinRangeData;

float g_flMinRange = 300.0;
float g_flMaxRange = 1000.0;
float g_fRangeScaleFactor;
float g_flNegativeMinRange = -300.0;

ConVar g_hMinRange;
ConVar g_hMaxRange;

public Plugin myinfo =
{
	name = "Pounce Damage Uncap",
	author = "Accelerator & ProdigySim & DeepSeek AI",
	description = "Patch L4D2 to allow uncapping the pounce range limits",
	version = "1.0",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	g_fRangeScaleFactor = 1.0 / 700.0;

	g_hMinRange = CreateConVar("z_pounce_damage_range_min", "300.0", "Minimum range for a pounce to be worth bonus damage.", FCVAR_GAMEDLL|FCVAR_CHEAT, true, 0.0);
	g_hMaxRange = CreateConVar("z_pounce_damage_range_max", "1000.0", "Range at which a pounce is worth the maximum bonus damage.", FCVAR_GAMEDLL|FCVAR_CHEAT, true, 0.0);

	GameData hGameConf = new GameData("pduncap");
	if (hGameConf == null)
		SetFailState("Failed to load gamedata/pduncap.txt");

	g_pFuncAddress = hGameConf.GetAddress("CTerrorPlayer::OnPouncedOnSurvivor");
	if (g_pFuncAddress == Address_Null)
		SetFailState("Failed to find CTerrorPlayer::OnPouncedOnSurvivor address");

	g_iMinRangeOffset = hGameConf.GetOffset("MinRange");
	g_iMaxRangeOffset = hGameConf.GetOffset("MaxRange");
	g_iScaleOffset = hGameConf.GetOffset("RangeScaleFactor");
	g_iNegativeMinRangeOffset = hGameConf.GetOffset("NegativeMinRange");

	delete hGameConf;

	if (g_iMinRangeOffset == -1 || g_iMaxRangeOffset == -1 || g_iScaleOffset == -1)
		SetFailState("Invalid offsets in gamedata");

	GetAddresses();

	g_hMinRange.AddChangeHook(OnRangeChanged_Min);
	g_hMaxRange.AddChangeHook(OnRangeChanged_Max);

	g_flMinRange = g_hMinRange.FloatValue;
	g_flMaxRange = g_hMaxRange.FloatValue;
	RecalculateScaleFactor();
}

public void OnPluginEnd()
{
	g_flMinRange = 300.0;
	g_flMaxRange = 1000.0;
	RecalculateScaleFactor();
}

void GetAddresses()
{
	Address pMinPtrAddr = g_pFuncAddress + g_iMinRangeOffset;
	Address pMaxPtrAddr = g_pFuncAddress + g_iMaxRangeOffset;
	Address pScalePtrAddr = g_pFuncAddress + g_iScaleOffset;
	Address pNegPtrAddr = Address_Null;

	g_pMinRangeData = LoadFromAddress(pMinPtrAddr, NumberType_Int32);
	g_pMaxRangeData = LoadFromAddress(pMaxPtrAddr, NumberType_Int32);
	g_pRangeScaleData = LoadFromAddress(pScalePtrAddr, NumberType_Int32);

	if (g_pMinRangeData == Address_Null || g_pMaxRangeData == Address_Null || g_pRangeScaleData == Address_Null)
	{
		SetFailState("Failed to read original pointers!");
	}

	if (g_iNegativeMinRangeOffset != -1)
	{
		pNegPtrAddr = g_pFuncAddress + g_iNegativeMinRangeOffset;
		g_pNegativeMinRangeData = LoadFromAddress(pNegPtrAddr, NumberType_Int32);

		if (g_pNegativeMinRangeData == Address_Null)
		{
			SetFailState("Failed to read NegativeMinRange pointer!");
		}
	}

	ReadOriginalValues(pMinPtrAddr, pMaxPtrAddr, pScalePtrAddr, pNegPtrAddr);
}

void ReadOriginalValues(Address pMinAddr, Address pMaxAddr, Address pScaleAddr, Address pNegAddr)
{
	int ptr = LoadFromAddress(pMinAddr, NumberType_Int32);
	Address pAddr = view_as<Address>(ptr);

	float val = view_as<float>(LoadFromAddress(pAddr, NumberType_Int32));
	if (val != g_flMinRange)
	{
		SetFailState("Invalid 'MinRange' offset");
	}

	ptr = LoadFromAddress(pMaxAddr, NumberType_Int32);
	pAddr = view_as<Address>(ptr);

	val = view_as<float>(LoadFromAddress(pAddr, NumberType_Int32));
	if (val != g_flMaxRange)
	{
		SetFailState("Invalid 'MaxRange' offset");
	}

	ptr = LoadFromAddress(pScaleAddr, NumberType_Int32);
	pAddr = view_as<Address>(ptr);

	val = view_as<float>(LoadFromAddress(pAddr, NumberType_Int32));
	if (val != g_fRangeScaleFactor)
	{
		SetFailState("Invalid 'RangeScaleFactor' offset");
	}

	if (g_iNegativeMinRangeOffset != -1)
	{
		ptr = LoadFromAddress(pNegAddr, NumberType_Int32);
		pAddr = view_as<Address>(ptr);

		val = view_as<float>(LoadFromAddress(pAddr, NumberType_Int32));
		if (val != g_flNegativeMinRange)
		{
			SetFailState("Invalid 'NegativeMinRange' offset");
		}
	}
}

void RecalculateScaleFactor()
{
	float diff = g_flMaxRange - g_flMinRange;
	if (diff == 0.0)
		g_fRangeScaleFactor = view_as<float>(0x7F7FFFFF); // FLT_MAX
	else
		g_fRangeScaleFactor = 1.0 / diff;

	if (g_iNegativeMinRangeOffset != -1)
		g_flNegativeMinRange = -g_flMinRange;

	if (g_pMinRangeData != Address_Null)
		StoreToAddress(g_pMinRangeData, view_as<int>(g_flMinRange), NumberType_Int32);

	if (g_pMaxRangeData != Address_Null)
		StoreToAddress(g_pMaxRangeData, view_as<int>(g_flMaxRange), NumberType_Int32);

	if (g_pRangeScaleData != Address_Null)
		StoreToAddress(g_pRangeScaleData, view_as<int>(g_fRangeScaleFactor), NumberType_Int32);

	if (g_pNegativeMinRangeData != Address_Null)
		StoreToAddress(g_pNegativeMinRangeData, view_as<int>(g_flNegativeMinRange), NumberType_Int32);
}

void OnRangeChanged_Min(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flMinRange = g_hMinRange.FloatValue;
	RecalculateScaleFactor();
}

void OnRangeChanged_Max(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_flMaxRange = g_hMaxRange.FloatValue;
	RecalculateScaleFactor();
}