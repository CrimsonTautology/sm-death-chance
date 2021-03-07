/**
 * vim: set ts=4 :
 * =============================================================================
 * Death Chance
 * Adds chance to spawn entity on player death
 *
 * Copyright 2021 CrimsonTautology
 * =============================================================================
 *
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.10.0"
#define PLUGIN_NAME  "[FoF] Death Chance"

#define CLASS_NAME_SIZE 32

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = "CrimsonTautology",
    description = "Adds chance to spawn entity on player death",
    version = PLUGIN_VERSION,
    url = "http://github.com/CrimsonTautology/sm-death-chance"
};

ConVar g_Cvar_Enabled;
ConVar g_Cvar_TargetClass;
ConVar g_Cvar_Percentage;

public void OnPluginStart()
{
    CreateConVar("sm_death_chance_version", PLUGIN_VERSION, PLUGIN_NAME,
            FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
    g_Cvar_Enabled = CreateConVar(
            "sm_death_chance",
            "1",
            "Set to 1 to enable the death chance plugin",
            FCVAR_REPLICATED | FCVAR_NOTIFY,
            true,
            0.0,
            true,
            1.0);
    g_Cvar_TargetClass = CreateConVar(
            "sm_death_chance_class",
            "none",
            "The class name of the entity to spawn",
            FCVAR_REPLICATED | FCVAR_NOTIFY
            );
    g_Cvar_Percentage = CreateConVar(
            "sm_death_chance_percentage",
            "0.25",
            "Percentage of times that this entity should spawn (0.0 = 0%, 1.0 = 100%)",
            FCVAR_REPLICATED | FCVAR_NOTIFY,
            true,
            0.0,
            true,
            1.0);

    RegAdminCmd("sm_deathchance", Command_Deathchance, ADMFLAG_SLAY,
            "[ADMIN] Set entity to spawn on death.");

    HookEvent("player_death", Event_PlayerDeath);

    AutoExecConfig();
}

bool IsDeathChanceEnabled()
{
    return g_Cvar_Enabled.BoolValue;
}

bool DeathChanceRoll()
{
    return GetURandomFloat() < g_Cvar_Percentage.FloatValue;
}

int Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if(!IsDeathChanceEnabled()) return;
    if(!DeathChanceRoll()) return;

    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    char class[CLASS_NAME_SIZE];
    g_Cvar_TargetClass.GetString(class, sizeof(class));

    // remove ragdoll during the next frame
    RequestFrame(RemoveRagdollDelay, userid);

    int ent = SpawnEntity(client, class);
    CreateTimer(60.0, Timer_RemoveEntity, EntIndexToEntRef(ent),
            TIMER_FLAG_NO_MAPCHANGE);
}

void RemoveRagdollDelay(int userid)
{
    int client = GetClientOfUserId(userid);
    if(!(0 < client < MaxClients)) return;

    int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
    if (ragdoll <= MaxClients) return;

    AcceptEntityInput(ragdoll, "Kill");
}

int SpawnEntity(int client, char[] class)
{
    float pos[3], ang[3];

    GetClientEyePosition(client, pos);
    GetClientAbsAngles(client, ang);

    int ent = CreateEntityByName(class);
    if(IsValidEntity(ent))
    {
        DispatchSpawn(ent);
        AddEntityProperties(ent, class);
        TeleportEntity(ent, pos, ang, NULL_VECTOR);
        ActivateEntity(ent);
    }

    return ent;
}

// add custom default properties to some entities
void AddEntityProperties(int ent, char[] class)
{
    if(StrEqual(class, "item_whiskey"))
    {
        SetEntProp(ent, Prop_Data, "m_nHealth", 25);
    }
    else if(StrEqual(class, "item_potion"))
    {
        SetEntProp(ent, Prop_Data, "m_nPotion", 100);
    }
    else if(StrEqual(class, "item_potion_small"))
    {
        SetEntProp(ent, Prop_Data, "m_nPotion", 25);
    }
    else if(StrEqual(class, "npc_horse"))
    {
        // randomize the horse
        int saddle = GetRandomInt(0, 1);
        int skin = GetRandomInt(0, 2);

        SetEntProp(ent, Prop_Data, "m_bSaddle", saddle);
        SetEntProp(ent, Prop_Data, "m_nSkin", skin);
    }
}

Action Timer_RemoveEntity(Handle timer, any ref)
{
    int ent = EntRefToEntIndex(ref);
    if (ent <= MaxClients) return;
    AcceptEntityInput(ent, "Kill");
}

Action Command_Deathchance(int client, int args)
{
    if(client <= 0) return Plugin_Handled;
    if(!IsClientInGame(client)) return Plugin_Handled;

    Menu menu = new Menu(DeathchanceMenuHandler);

    menu.SetTitle("Choose Entity");

    menu.AddItem("none", "Disable");

    menu.AddItem("fof_ghost", "Ghosts");
    menu.AddItem("npc_horse", "Horses");
    menu.AddItem("npc_gman", "Gman");
    menu.AddItem("npc_citizen", "Citizen");
    menu.AddItem("item_golden_skull", "Skull");
    menu.AddItem("item_whiskey", "Whiskey");
    menu.AddItem("item_potion_small", "Potion (Small)");
    menu.AddItem("item_potion", "Potion");

    menu.AddItem("npc_grenade_bugbait", "Bugbait");
    menu.AddItem("npc_handgrenade", "Hand Grenade");
    menu.AddItem("bounce_bomb", "Bounce Bomb");
    menu.AddItem("combine_bouncemine", "Bounce Mine");
    menu.AddItem("combine_mine", "Mine");
    menu.AddItem("grenade_ar2", "Grenade AR2");
    menu.AddItem("grenade_helicopter", "Grenade Helicopter");

    menu.AddItem("weapon_walker", "Colt Walker");
    menu.AddItem("weapon_sawedoff_shotgun", "Sawed-Off Shotgun");
    menu.AddItem("weapon_sharps", "Sharps Rifle");

    menu.Display(client, 20);

    return Plugin_Handled;
}

int DeathchanceMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
            {
                char class[32];
                menu.GetItem(param2, class, sizeof(class));

                if(StrEqual(class, "none"))
                {
                    g_Cvar_Enabled.SetBool(false);
                }else{
                    g_Cvar_TargetClass.SetString(class);
                    g_Cvar_Enabled.BoolValue = true;
                }
            }
        case MenuAction_End: delete menu;
    }
}
