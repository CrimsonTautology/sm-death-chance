#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0.1"
#define PLUGIN_NAME  "[FoF] Death Chance"

#define CLASS_NAME_SIZE 32

public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "CrimsonTautology",
    description = "Adds chance to spawn entity on player death",
    version = PLUGIN_VERSION,
    url = "http://github.com/CrimsonTautology/sm_death_chance"
};

new Handle:g_Cvar_Enabled     = INVALID_HANDLE;
new Handle:g_Cvar_TargetClass = INVALID_HANDLE;
new Handle:g_Cvar_Percentage  = INVALID_HANDLE;
new Handle:g_Cvar_Ammount     = INVALID_HANDLE;

public OnPluginStart()
{
    CreateConVar("sm_death_chance_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
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
    g_Cvar_Ammount = CreateConVar(
            "sm_death_chance_ammount",
            "1",
            "The Upper limmit for the ammount of this item that should spawn.",
            FCVAR_REPLICATED | FCVAR_NOTIFY,
            true,
            1.0,
            true,
            10.0);

    RegAdminCmd("sm_deathchance", Command_Deathchance, ADMFLAG_SLAY, "[ADMIN] Set entity to spawn on death.");

    HookEvent("player_death", Event_PlayerDeath);

    AutoExecConfig();
}

bool:IsDeathChanceEnabled()
{
    return GetConVarBool(g_Cvar_Enabled);
}

bool:DeathChanceRoll()
{
    return GetURandomFloat() < GetConVarFloat(g_Cvar_Percentage);
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    if(!IsDeathChanceEnabled()) return;
    if(!DeathChanceRoll()) return;

    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    new String:class[CLASS_NAME_SIZE];
    GetConVarString(g_Cvar_TargetClass, class, sizeof(class));

    // Remove ragdoll during the next frame
    CreateTimer(0.0, Timer_RemoveRagdoll, client, TIMER_FLAG_NO_MAPCHANGE);

    new ent = SpawnEntity(client, class);
    CreateTimer(60.0, Timer_RemoveEntity, EntIndexToEntRef(ent), TIMER_FLAG_NO_MAPCHANGE);
}

SpawnEntity(client, String:class[])
{
    new Float:pos[3], Float:ang[3];

    GetClientEyePosition(client, pos);
    GetClientAbsAngles(client, ang);

    new ent = CreateEntityByName(class);
    if(IsValidEntity(ent))
    {
        DispatchSpawn(ent);
        AddEntityProperties(ent, class);
        TeleportEntity(ent, pos, ang, NULL_VECTOR);
        ActivateEntity(ent);
    }

    return ent;
}

//Add custom default properties to some entities
AddEntityProperties(ent, String:class[])
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
        //Randomize the horse
        new saddle = GetRandomInt(0, 1);
        new skin   = GetRandomInt(0, 2);

        SetEntProp(ent, Prop_Data, "m_bSaddle", saddle);
        SetEntProp(ent, Prop_Data, "m_nSkin", skin);
    }
}

public Action:Timer_RemoveRagdoll(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if (!client) return;
    new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
    if (ragdoll <= MaxClients) return;
    AcceptEntityInput(ragdoll, "Kill");
}

public Action:Timer_RemoveEntity(Handle:timer, any:ref)
{
    new ent = EntRefToEntIndex(ref);
    if (ent <= MaxClients) return;
    AcceptEntityInput(ent, "Kill");
}


public Action:Command_Deathchance(client, args)
{
    if(client <= 0) return Plugin_Handled;
    if(!IsClientInGame(client)) return Plugin_Handled;

    new Handle:menu = CreateMenu(DeathchanceMenuHandler);

    SetMenuTitle(menu, "Choose Entity");

    AddMenuItem(menu, "none", "Disable");

    AddMenuItem(menu, "fof_ghost", "Ghosts");
    AddMenuItem(menu, "npc_horse", "Horses");
    AddMenuItem(menu, "npc_gman", "Gman");
    AddMenuItem(menu, "npc_citizen", "Citizen");
    AddMenuItem(menu, "item_golden_skull", "Skull");
    AddMenuItem(menu, "item_whiskey", "Whiskey");
    AddMenuItem(menu, "item_potion_small", "Potion (Small)");
    AddMenuItem(menu, "item_potion", "Potion");

    AddMenuItem(menu, "npc_grenade_bugbait", "Bugbait");
    AddMenuItem(menu, "npc_handgrenade", "Hand Grenade");
    AddMenuItem(menu, "bounce_bomb", "Bounce Bomb");
    AddMenuItem(menu, "combine_bouncemine", "Bounce Mine");
    AddMenuItem(menu, "combine_mine", "Mine");
    AddMenuItem(menu, "grenade_ar2", "Grenade AR2");
    AddMenuItem(menu, "grenade_helicopter", "Grenade Helicopter");

    AddMenuItem(menu, "weapon_walker", "Colt Walker");
    AddMenuItem(menu, "weapon_sawedoff_shotgun", "Sawed-Off Shotgun");
    AddMenuItem(menu, "weapon_sharps", "Sharps Rifle");

    DisplayMenu(menu, client, 20);

    return Plugin_Handled;
}

public DeathchanceMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
            {
                new client = param1;
                new String:class[32];
                GetMenuItem(menu, param2, class, sizeof(class));

                if(StrEqual(class, "none"))
                {
                    SetConVarBool(g_Cvar_Enabled, false);
                }else{
                    SetConVarString(g_Cvar_TargetClass, class);
                    SetConVarBool(g_Cvar_Enabled, true);
                }
            }
        case MenuAction_End: CloseHandle(menu);
    }
}
