#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>

#define PLUGIN_VERSION      "1.2.2"
#define MAX_LINE_WIDTH      64
#define L4D_MAXPLAYERS      32
#define MAX_TOP_PLAYERS     5

#define TEAM_SPECTATORS     1
#define TEAM_SURVIVORS      2
#define TEAM_INFECTED       3

int g_iTankClass = 5;   // L4D1 default

// ConVars
ConVar g_cvShowFrags;
ConVar g_cvShowTankDamage;
ConVar g_cvShowWitchDamage;
ConVar g_cvShowTankHP;

// Per-player counters (index 0 not used)
int g_iKills      [L4D_MAXPLAYERS + 1];
int g_iTankDamage [L4D_MAXPLAYERS + 1];
int g_iWitchDamage[L4D_MAXPLAYERS + 1];

bool g_bAllowPrints;

public Plugin myinfo =
{
    name        = "L4D1/2 Damage & Frags Counters",
    author      = "Jonny, Accelerator, Grok",
    description = "Shows frags, tank/witch damage statistics",
    version     = PLUGIN_VERSION,
    url         = ""
};

public void OnPluginStart()
{
    g_cvShowFrags       = CreateConVar("counters_show_frags",       "1", "0 = off, 1 = end of round, 2 = after each kill", _, true, 0.0, true, 2.0);
    g_cvShowTankDamage  = CreateConVar("counters_show_tank_damage", "1", "Show tank damage statistics", _);
    g_cvShowWitchDamage = CreateConVar("counters_show_witch_damage","0", "Show witch damage statistics", _);
    g_cvShowTankHP      = CreateConVar("counters_show_tank_hp",     "1", "Show remaining tank HP when round ends", _);

    HookEvent("round_start",        Event_RoundStart);
    HookEvent("round_end",          Event_RoundEnd);
    HookEvent("finale_win",         Event_RoundEnd);
    HookEvent("map_transition",     Event_RoundEnd);
    HookEvent("player_death",       Event_PlayerDeath);
    HookEvent("player_incapacitated", Event_PlayerIncap);
    HookEvent("player_hurt",        Event_PlayerHurt);
    HookEvent("infected_hurt",      Event_InfectedHurt, EventHookMode_Post);
    HookEvent("witch_killed",       Event_WitchKilled,  EventHookMode_Post);

    RegConsoleCmd("sm_frags", Cmd_ShowFrags, "Show current frags");

    // L4D2 tank class = 8
    char gameFolder[24];
    GetGameFolderName(gameFolder, sizeof(gameFolder));
    if (StrEqual(gameFolder, "left4dead2", false))
    {
        g_iTankClass = 8;
    }
}

public void OnMapStart()
{
    ResetAllCounters();
}

public void OnClientDisconnect(int client)
{
    g_iKills[client]       = 0;
    g_iTankDamage[client]  = 0;
    g_iWitchDamage[client] = 0;
}

void ResetAllCounters()
{
    for (int i = 0; i <= MaxClients; i++)
    {
        g_iKills[i]       = 0;
        g_iTankDamage[i]  = 0;
        g_iWitchDamage[i] = 0;
    }
    g_bAllowPrints = true;
}

Action Cmd_ShowFrags(int client, int args)
{
    if (client == 0)
        return Plugin_Handled;

    PrintTopFrags(client);
    return Plugin_Handled;
}

// ────────────────────────────────────────────────
//  Events
// ────────────────────────────────────────────────

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ResetAllCounters();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bAllowPrints)
        return;

    if (AreAnySurvivorsAliveAndNotIncap())
        return;

    if (g_cvShowTankHP.BoolValue)
        PrintRemainingTankHP();

    if (g_cvShowFrags.IntValue > 0)
        PrintTopFrags();

    g_bAllowPrints = false;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim   = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (!victim)
        return;

    // Tank killed
    if (IsTank(victim))
    {
        RequestFrame(OnTankKilled, attacker);
        return;
    }

    if (IsSurvivor(attacker))
    {
        if (GetClientTeam(victim) != TEAM_INFECTED)
            return;

        // Special infected kill
        g_iKills[attacker]++;

        if (g_cvShowFrags.IntValue == 2)
        {
            PrintCenterText(attacker, "%d", g_iKills[attacker]);
        }

        return;
    }

    if (GetClientTeam(victim) != TEAM_SURVIVORS)
        return;

    // Last survivor died → show stats
    Event_RoundEnd(event, name, dontBroadcast);
}

void Event_PlayerIncap(Event event, const char[] name, bool dontBroadcast)
{
    Event_RoundEnd(event, name, dontBroadcast);
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int victim   = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (!victim || !IsTank(victim) || IsIncapacitated(victim) || !IsSurvivor(attacker))
        return;

    int dmg = event.GetInt("dmg_health");
    if (dmg <= 0)
        return;

    g_iTankDamage[attacker] += dmg;
    g_iTankDamage[0] = event.GetInt("health");
}

void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
    int witch    = event.GetInt("entityid");
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (!IsSurvivor(attacker))
        return;

    char classname[16];
    GetEdictClassname(witch, classname, sizeof(classname));

    if (StrEqual(classname, "witch", false))
    {
        g_iWitchDamage[attacker] += event.GetInt("amount");
        g_iWitchDamage[0] = GetEntProp(witch, Prop_Data, "m_iHealth");
    }
}

void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvShowWitchDamage.BoolValue)
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));

    if (IsSurvivor(client))
    {
        g_iWitchDamage[client] += g_iWitchDamage[0];
    }

    PrintTopWitchDamage();
    ResetWitchDamage();
}

// ────────────────────────────────────────────────
//  Tank killed delayed check
// ────────────────────────────────────────────────

void OnTankKilled(int attacker)
{
    if (!g_cvShowTankDamage.BoolValue)
        return;

    if (IsAnyTankAlive())
        return;

    if (IsSurvivor(attacker))
    {
        g_iTankDamage[attacker] += g_iTankDamage[0];
    }

    PrintTopTankDamage(true);   // killed
    ResetTankDamage();
}

// ────────────────────────────────────────────────
//  Display functions
// ────────────────────────────────────────────────

void PrintTopFrags(int client = 0)
{
    if (!g_bAllowPrints)
        return;

    int[][] data = new int[MaxClients + 1][2];
    int count = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsSurvivor(i))
            continue;

        if (g_iKills[i] <= 0)
            continue;

        data[count][0] = i;
        data[count][1] = g_iKills[i];
        count++;
    }

    if (count == 0)
        return;

    SortCustom2D(data, count, SortByDamageDesc);

    char msg[256];
    FormatEx(msg, sizeof(msg), "Frags: ");

    int id, frags, printed = 0;
    bool first = true;

    for (int i = 0; i < count && printed < MAX_TOP_PLAYERS; i++)
    {
        id   = data[i][0];
        frags = data[i][1];
        if (!first) Format(msg, sizeof(msg), "%s, ", msg);
        Format(msg, sizeof(msg), "%s{blue}%N{default} %d", msg, id, frags);
        first = false;
        printed++;
    }

    if (client > 0 && IsClientInGame(client))
        CPrintToChat(client, msg);
    else
    {
        CPrintToChatAll(msg);
        ResetKills();
    }
}

void PrintTopTankDamage(bool killed)
{
    if (!g_bAllowPrints)
        return;

    int[][] data = new int[MaxClients + 1][2];
    int count = CollectTopDamage(g_iTankDamage, data);

    if (count == 0)
        return;

    char msg[256];
    FormatEx(msg, sizeof(msg), "{green}Tank(s){default} %s by ",
        killed ? "was killed" : "was damaged");

    int id, dmg, printed = 0;
    bool first = true;

    for (int i = 0; i < count && printed < MAX_TOP_PLAYERS; i++)
    {
        id = data[i][0];
        dmg = data[i][1];
        if (!first) Format(msg, sizeof(msg), "%s, ", msg);
        Format(msg, sizeof(msg), "%s{blue}%N{default}: %d", msg, id, dmg);
        first = false;
        printed++;
    }

    CPrintToChatAll(msg);
}

void PrintTopWitchDamage()
{
    if (!g_bAllowPrints)
        return;

    int[][] data = new int[MaxClients + 1][2];
    int count = CollectTopDamage(g_iWitchDamage, data);

    if (count == 0)
        return;

    char msg[256];
    FormatEx(msg, sizeof(msg), "{green}Witch{default} was killed by ");

    int id, dmg, printed = 0;
    bool first = true;

    for (int i = 0; i < count && printed < MAX_TOP_PLAYERS; i++)
    {
        id = data[i][0];
        dmg = data[i][1];
        if (!first) Format(msg, sizeof(msg), "%s, ", msg);
        Format(msg, sizeof(msg), "%s{blue}%N{default}: %d", msg, id, dmg);
        first = false;
        printed++;
    }

    CPrintToChatAll(msg);
}

void PrintRemainingTankHP()
{
    char buffer[128];
    int tanks = GetAllTankHP(buffer, sizeof(buffer));

    if (tanks > 0)
    {
        CPrintToChatAll("{red}Tank(s){default} had {olive}%s{default} health remaining!", buffer);
        PrintTopTankDamage(false);
        ResetTankDamage();
    }
}

// ────────────────────────────────────────────────
//  Helpers
// ────────────────────────────────────────────────

int CollectTopDamage(const int[] damageArray, int[][] data)
{
    int count = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsSurvivor(i))
            continue;
        if (damageArray[i] <= 0)
            continue;

        data[count][0] = i;
        data[count][1] = damageArray[i];
        count++;
    }

    if (count > 0)
        SortCustom2D(data, count, SortByDamageDesc);

    return count;
}

int GetAllTankHP(char[] buffer, int maxlen)
{
    int hp, count = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsTank(i) || !IsPlayerAlive(i) || IsIncapacitated(i))
            continue;

        hp = GetClientHealth(i);
        if (hp <= 0)
            continue;

        if (count > 0)
            Format(buffer, maxlen, "%s, ", buffer);

        Format(buffer, maxlen, "%s{olive}%d{default}", buffer, hp);
        count++;
    }

    return count;
}

bool AreAnySurvivorsAliveAndNotIncap()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsSurvivor(i) && IsPlayerAlive(i) && !IsIncapacitated(i))
            return true;
    }
    return false;
}

bool IsAnyTankAlive()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsTank(i) && IsPlayerAlive(i) && !IsIncapacitated(i))
            return true;
    }
    return false;
}

bool IsSurvivor(int client)
{
    if (!client)
        return false;
    if (!IsClientInGame(client))
        return false;
    if (IsFakeClient(client))
        return false;
    if (GetClientTeam(client) != TEAM_SURVIVORS)
        return false;
    return true;
}

bool IsTank(int client)
{
    if (!IsClientInGame(client))
        return false;
    if (GetClientTeam(client) != TEAM_INFECTED)
        return false;
    return GetEntProp(client, Prop_Send, "m_zombieClass") == g_iTankClass;
}

bool IsIncapacitated(int client)
{
    return GetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
}

void ResetKills()
{
    for (int i = 1; i <= MaxClients; i++)
        g_iKills[i] = 0;
}

void ResetTankDamage()
{
    for (int i = 0; i <= MaxClients; i++)
        g_iTankDamage[i] = 0;
}

void ResetWitchDamage()
{
    for (int i = 0; i <= MaxClients; i++)
        g_iWitchDamage[i] = 0;
}

public int SortByDamageDesc(int[] a, int[] b, const int[][] array, Handle hndl)
{
    if (a[1] > b[1]) return -1;
    if (a[1] < b[1]) return 1;
    return 0;
}