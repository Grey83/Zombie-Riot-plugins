#pragma semicolon 1

#include <sdktools>
#include <zriot>

#define PLUGIN_NAME		"ZRiot Health Bar"
#define PLUGIN_VERSION	"1.0.0"

new iHealthBar[MAXPLAYERS+1],
	iHPmax[MAXPLAYERS+1],
	Handle:hTimer[MAXPLAYERS+1];


public Plugin:myinfo =
{
	name		= PLUGIN_NAME,
	author		= "Grey83",
	description = "Shows healthbar above the head of zombies",
	version		= PLUGIN_VERSION,
	url			= "https://steamcommunity.com/groups/grey83ds"
};

public OnPluginStart()
{
	CreateConVar("zr_healthbar_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_Death, EventHookMode_Pre);

	for(new i = 1; i <= MaxClients; i++) if(IsClientInGame(i)) OnClientPutInServer(i);
}

public OnMapStart()
{
	for(new i = 1, String:buffer[64]; i < 40; i++)
	{
		FormatEx(buffer, sizeof(buffer), "materials/overlays/healthbar/bar%02d.vtf", i);
		AddFileToDownloadsTable(buffer);

		FormatEx(buffer, sizeof(buffer), "materials/overlays/healthbar/bar%02d.vmt", i);
		AddFileToDownloadsTable(buffer);
		PrecacheModel(buffer);
	}
}

public OnClientPutInServer(client)
{
	iHPmax[client] = iHealthBar[client] = 0;
}

public OnClientDisconnect(client)
{
	ClearHealthBar(client);
}

public OnPluginEnd()
{
	for(new i = 1; i <= MaxClients; i++) if(IsClientInGame(i)) ClearHealthBar(i);
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	static client;
	if((client = GetClientOfUserId(GetEventInt(event, "userid"))) && ZRiot_IsClientZombie(client))
	{
		iHPmax[client] = GetClientHealth(client);
		if(!IconValid(client)) iHealthBar[client] = CreateHealthBar(client, 100);
	}
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	static client, total;
	if((client = GetClientOfUserId(GetEventInt(event, "userid"))) && ZRiot_IsClientZombie(client))
	{
		total = RoundToNearest((GetEventFloat(event, "health") / iHPmax[client])*100.0);
		if(IconValid(client)) UpdateHealthBar(client, total);
		else iHealthBar[client] = CreateHealthBar(client, total);
		ClearTimer(hTimer[client]);
		hTimer[client] = CreateTimer(4.0, Timer_HideHealthBar, client);
	}
}

public Action:Event_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	ClearHealthBar(GetClientOfUserId(GetEventInt(event, "userid")));
}

public Action:Timer_HideHealthBar(Handle:timer, any:client)
{
	hTimer[client] = INVALID_HANDLE;
	ClearHealthBar(client);
}

stock CreateHealthBar(client, hp)
{
	if(hp < 1) return 0;

	decl String:iTarget[16];
	Format(iTarget, 16, "client%d", client);
	DispatchKeyValue(client, "targetname", iTarget);

	decl Float:origin[3];
	GetClientEyePosition(client, origin);
	origin[2] += 10.0;

	new Ent = CreateEntityByName("env_sprite");
	if(!Ent) return 0;

	new num = RoundToCeil(hp/2.5);
	if(num < 1) num = 1;
	else if(num > 40) num = 40;
	decl String:buffer[64];
	FormatEx(buffer, sizeof(buffer), "materials/overlays/healthbar/bar%02d.vmt", num);
	DispatchKeyValue(Ent, "model", buffer);
	DispatchKeyValue(Ent, "classname", "healthbar");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.08");
/*
	https://developer.valvesoftware.com/wiki/Render_Modes
	Normal (0), Color (1), Texture (2), Glow (3), Solid (4), Additive (5), Additive Fractional Frame (7), Alpha Add (8), World Space Glow (9), Don't Render (10)
*/
	DispatchKeyValue(Ent, "rendermode", "9");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, origin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(iTarget);
	AcceptEntityInput(Ent, "SetParent", Ent, Ent, 0);

	return EntIndexToEntRef(Ent);
}

stock ClearHealthBar(client)
{
	if(iHealthBar[client])
	{
		static entity;
		if((entity = EntRefToEntIndex(iHealthBar[client])) != INVALID_ENT_REFERENCE) AcceptEntityInput(entity, "Kill");
		iHealthBar[client] = 0;
	}
	ClearTimer(hTimer[client]);
}

stock ClearTimer(&Handle:timer)
{
	if(timer != INVALID_HANDLE)
	{
		KillTimer(timer);
		timer = INVALID_HANDLE;
	}
}

stock UpdateHealthBar(client, hp)
{
	static ent, num, String:buffer[64];

	num = RoundToCeil(hp/2.5);
	if(num < 1) num = 1;
	else if(num > 40) num = 40;
	FormatEx(buffer, sizeof(buffer), "materials/overlays/healthbar/bar%02d.vmt", num);
	ent = EntRefToEntIndex(iHealthBar[client]);
	SetEntityModel(ent, buffer);
}

stock bool:IconValid(client)
{
	return iHealthBar[client] && EntRefToEntIndex(iHealthBar[client]) != INVALID_ENT_REFERENCE;
}