#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#define PLUGIN_VERSION "1.3"

#pragma semicolon 1
#pragma newdecls required

#define FB_MODEL "models/props/cs_office/snowman_head.mdl"
//#define MODEL_WIDGET "models/tools/rotate_widget.mdl"
#define MODEL_WIDGET "models/props/cs_office/vending_machine.mdl"

#define CSGO_HEGRENADE_AMMO 14
#define CSGO_FLASH_AMMO 15
#define CSGO_SMOKE_AMMO 16
#define INCENDERY_AND_MOLOTOV_AMMO 17
#define	DECOY_AMMO 18

int g_iKillPoint[MAXPLAYERS + 1] =  { 0, ... };
int g_iTeslaEntity[MAXPLAYERS + 1] =  { -1, ... };
int g_iButtonFlags[MAXPLAYERS + 1] =  { 0, ... };

bool g_bUseStraightBall[MAXPLAYERS + 1] =  { false, ... };
bool g_bUseBounceBall[MAXPLAYERS + 1] =  { false, ... };
bool g_bUseDoubleFire[MAXPLAYERS + 1] =  { false, ... };

bool g_bAutoSwitchFb[MAXPLAYERS + 1] =  { false, ... };
bool g_bIsStuned[MAXPLAYERS + 1] =  { false, ... };
float g_flStunEndTime[MAXPLAYERS + 1];

int g_iLastFbIndex[MAXPLAYERS + 1] =  { -1, ... };

bool g_bRoundEnded;

int g_iBeamSprite;
int g_iGlowSprite;
int g_iElecticSprite;

#include "dodgeball/warmup.sp"
#include "dodgeball/basic.sp"
#include "dodgeball/events.sp"
#include "dodgeball/client.sp"
#include "dodgeball/menu.sp"

public Plugin myinfo =
{
	name = "Dodge Ball for CS:GO",
	author = "Trostal",
	description = "Throw balls, get frags!",
	version = PLUGIN_VERSION,
	url = "https://github.com/Hatser/Dodge-Ball"
};

public void OnPluginStart()
{
	SetConVars(0);
	// events.inc
	SetEvents();
	SetCommands();
	//RegConsoleCmd("say_team", SayTeamHook);
}

public void SetConVars(int data)
{
	SetConVarInt(FindConVar("sv_infinite_ammo"), 0);
	SetConVarInt(FindConVar("mp_death_drop_grenade"), 0);
	SetConVarInt(FindConVar("mp_friendlyfire"), 0);
	SetConVarInt(FindConVar("ammo_grenade_limit_default"), 10);
	SetConVarInt(FindConVar("ammo_grenade_limit_flashbang"), 2);
	SetConVarInt(FindConVar("ammo_grenade_limit_total"), 99);
	SetConVarInt(FindConVar("mp_free_armor"), 0);
}

void SetEvents()
{
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("round_start", OnRoundStart);
	HookEvent("round_freeze_end", OnRoundFreezeTimeEnd);
	HookEvent("round_end", OnRoundEnd);
	
	HookEvent("hegrenade_detonate", OnDetonate);
	
	HookUserMessage(GetUserMessageId("TextMsg"), BlockWarmupNoticeTextMsg, true);
	
	AddNormalSoundHook(OnNormalSoundEmit);
	
	/*
	HookEntityOutput("trigger_multiple", "OnTrigger",        trigger_multiple);
	HookEntityOutput("trigger_multiple", "OnStartTouch",    trigger_multiple);
	HookEntityOutput("trigger_multiple", "OnTouching",    trigger_multiple);
	*/
}

void SetCommands()
{
	AddCommandListener(SayHook, "say");
	AddCommandListener(SayHook, "say_team");
	AddCommandListener(BuyMenuEvent, "buymenu");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(entity <= 0)
		return;
		
//	if(StrContains(classname, "_projectile") != -1)
	
	if(StrEqual(classname, "flashbang_projectile", false))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnFlashbangSpawned);
	}
	if(StrEqual(classname, "hegrenade_projectile", false))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnGrenadeSpawned);
	}
	if(StrEqual(classname, "decoy_projectile", false))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnDecoySpawned);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
//	int fb = EntRefToEntIndex(g_iLastFbIndex[client]);
	
	if(IsValidClient(client))
	{
		if(IsPlayerAlive(client))
		{
			if(g_bIsStuned[client])
			{
				if(g_flStunEndTime[client] <= GetGameTime())
				{
					UnstunClient(client);
					SetEntityRenderMode(client, RENDER_TRANSCOLOR);
					SetEntityRenderColor(client, 255, 255, 255, 255);
				}
				else
				{
					float flDuration = g_flStunEndTime[client] - GetGameTime();
					int coloroffset = 255 - RoundToFloor(flDuration * 85);
					//지속시간 값이 적을수록 coloroffset값은 높아진다...
					SetEntityRenderMode(client, RENDER_TRANSCOLOR);
					SetEntityRenderColor(client, coloroffset, 127+(coloroffset/2), 255, 255);
				}
			}
			
			if(buttons & IN_RELOAD && !(g_iButtonFlags[client] & IN_RELOAD))
			{
				g_iButtonFlags[client] |= IN_RELOAD;
				ShopMenu(client, 20);
			}
			else
			{
				g_iButtonFlags[client] &= ~IN_RELOAD;
			}
		}
	}
}

// 플뱅 가만히 서서 던질 때, 675.0, 202.500015
// 플래시뱅이 던져졌을 때
public void OnFlashbangSpawned(int entity)
{
	// 플래시뱅을 기본적으로 터지지 않도록 한다.
	SetEntProp(entity, Prop_Data, "m_nNextThinkTick", -1);
	
	// 더블파이어로 인해 생성된 녀석인지를 m_bIsLive를 이용해서 파악하자 (더블 파이어인 놈은 m_bIsLive에 true값을 주도록 했다.)
	bool bIsSecondProjectile = view_as<bool>(GetEntProp(entity, Prop_Send, "m_bIsLive"));
	
	// 프로젝타일의 주인을 알아낸다.
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	if(!bIsSecondProjectile)
		// 자동 무기 스왑을 허용한다.
		g_bAutoSwitchFb[client] = true;
	
	// 갯수 조정, (갯수를 1로 두도록 하면 날아가고있는 프로젝타일이 증발한다)
	SetFlashbangCount(client, 2);
	
	// 모델 설정
//	SetEntityModel(entity, FB_MODEL);
	SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 1.5);
	
	SetEntProp(entity, Prop_Data, "m_iHealth", 20);
	
	if(IsValidClient(client))
	{
		g_iLastFbIndex[client] = EntIndexToEntRef(entity);
		
		// 직구를 사용할 때
		if(g_bUseStraightBall[client])
		{
			SetEntityMoveType(entity, MOVETYPE_FLY);
			if(!bIsSecondProjectile)
				RequestFrame(PushProjectile, entity);
		}
		
		// 바운스 볼을 사용할 때
		if(g_bUseBounceBall[client])
		{
			SetEntPropFloat(entity, Prop_Send, "m_flElasticity", 1.5);
			SetEntPropFloat(entity, Prop_Data, "m_flFriction", 0.0);
			
			SDKHook(entity, SDKHook_StartTouch, OnFlashbangTouch);
		}
		else
		{
			SDKHook(entity, SDKHook_StartTouchPost, OnFlashbangTouchPost);
		}
		
		// 더블 파이어를 사용할 때
		if(g_bUseDoubleFire[client])
		{
			if(!bIsSecondProjectile)
			{
				RequestFrame(SetSecondFire, entity);
			}
		}
	}
	
	// 트레일
	int color[4];
	color[0] = 255;
	color[1] = 255;
	color[2] = 255;
	color[3] = 255;
	TE_SetupBeamFollow(entity, g_iBeamSprite, 0, 0.75, 1.0, 1.0, 1, color);
	TE_SendToClient(client);
	
	
	/*
	float AbsOrigin[3], Origin[3], EyePosition[3];
	
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", AbsOrigin);
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", Origin);
	GetClientEyePosition(client, EyePosition);
	
	RequestFrame(PrintProps, entity);
	
	PrintToChat(client, "m_vecOrigin: %f %f %f", AbsOrigin[0], AbsOrigin[1], AbsOrigin[2]);
	PrintToChat(client, "m_vecAbsOrigin: %f %f %f", AbsOrigin[0], AbsOrigin[1], AbsOrigin[2]);
	PrintToChat(client, "EyePosision: %f %f %f", EyePosition[0], EyePosition[1], EyePosition[2]);
	PrintToChat(client, "m_flFriction: %f", GetEntPropFloat(entity, Prop_Data, "m_flFriction")); // 0.2
	PrintToChat(client, "m_flElasticity: %f", GetEntPropFloat(entity, Prop_Send, "m_flElasticity")); // 0.45
	PrintToChat(client, "m_flGravity: %f", GetEntPropFloat(entity, Prop_Data, "m_flGravity"));
	
	PrintToChat(client, "Diff: %f %f %f", AbsOrigin[0]-EyePosition[0], AbsOrigin[1]-EyePosition[1], AbsOrigin[2]-EyePosition[2]);
	*/
}
/*
public void PrintProps(any entity)
{
	float BaseVelocity[3], InitialVelocity[3], Velocity[3];
	
	GetEntPropVector(entity, Prop_Data, "m_vecBaseVelocity", BaseVelocity);
	GetEntPropVector(entity, Prop_Send, "m_vInitialVelocity", InitialVelocity);
	GetEntPropVector(entity, Prop_Send, "m_vecVelocity", Velocity);
	
	PrintToChatAll("m_vecBaseVelocity: %f %f %f", BaseVelocity[0], BaseVelocity[1], BaseVelocity[2]);
	PrintToChatAll("m_vInitialVelocity: %f %f %f", InitialVelocity[0], InitialVelocity[1], InitialVelocity[2]);
	PrintToChatAll("m_vecVelocity: %f %f %f", Velocity[0], Velocity[1], Velocity[2]);
}
*/

// 더블 파이어를 던지기 위해 기존 프로젝타일의 위치, 속도, 각도회전속도를 얻어낸다.
public void SetSecondFire(any entity)
{
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	float vecOrigin[3], vecVelocity[3], vecAngVelocity[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecOrigin);
	GetEntPropVector(entity, Prop_Send, "m_vecVelocity", vecVelocity);
	GetEntPropVector(entity, Prop_Data, "m_vecAngVelocity", vecAngVelocity);
	
	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteFloat(vecOrigin[0]);
	pack.WriteFloat(vecOrigin[1]);
	pack.WriteFloat(vecOrigin[2]);
	pack.WriteFloat(vecVelocity[0]);
	pack.WriteFloat(vecVelocity[1]);
	pack.WriteFloat(vecVelocity[2]);
	pack.WriteFloat(vecAngVelocity[0]);
	pack.WriteFloat(vecAngVelocity[1]);
	pack.WriteFloat(vecAngVelocity[2]);
	
	TE_SetupGlowSprite(vecOrigin, g_iGlowSprite, 1.0, 0.35, 75);
	TE_SendToClient(client);
	
	// 1초 후 재발사
	CreateTimer(1.0, FireSecondProjectile, pack);
}

// 더블 파이어의 두번째 프로젝타일을 던진다.
public Action FireSecondProjectile(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	float vecOrigin[3], vecVelocity[3], vecAngVelocity[3];
	vecOrigin[0] = pack.ReadFloat();
	vecOrigin[1] = pack.ReadFloat();
	vecOrigin[2] = pack.ReadFloat();
	vecVelocity[0] = pack.ReadFloat();
	vecVelocity[1] = pack.ReadFloat();
	vecVelocity[2] = pack.ReadFloat();
	vecAngVelocity[0] = pack.ReadFloat();
	vecAngVelocity[1] = pack.ReadFloat();
	vecAngVelocity[2] = pack.ReadFloat();
	delete pack;
	
	int entity = CreateEntityByName("flashbang_projectile", 0);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	SetEntPropEnt(entity, Prop_Send, "m_hThrower", client);
	SetEntProp(entity, Prop_Send, "m_bIsLive", 1);
	SetEntPropVector(entity, Prop_Data, "m_vecAngVelocity", vecAngVelocity);
	TeleportEntity(entity, vecOrigin, NULL_VECTOR, vecVelocity);
	DispatchSpawn(entity);
	ActivateEntity(entity);
}

// 바운스볼을 사용할 때만 발동
public void OnFlashbangTouch(int entity, int other)
{
	// 프로젝타일의 주인을 알아낸다.
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	// 18 번 튕기면 터지므로 그 이전에 삭제하도록 해주자.
	// 최대 15번만 튕기도록!
	SetEntProp(entity, Prop_Send, "m_nBounces", 1);
	
	int health = GetEntProp(entity, Prop_Data, "m_iHealth") - 1;
	SetEntProp(entity, Prop_Data, "m_iHealth", health);
	
	// 처음에 체력을 20으로 설정해줬다.
	if(health <= 5)
		RemoveProjectile(entity);
		
	if(!g_bUseStraightBall[client])
		// 기본 바운스 볼은 최초로 벽에 닿은 뒤 1.5초, 바운스 볼과 직구를 함께 사용할 땐 2.5초 후에 사라진다.
		CreateTimer(1.5, RemoveFlashbang, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
	else
		CreateTimer(2.5, RemoveFlashbang, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
				
}
// 바운스볼을 사용하지 않을 때만 발동
public void OnFlashbangTouchPost(int entity, int other)
{
	RemoveProjectile(EntIndexToEntRef(entity), true);
}

public Action RemoveFlashbang(Handle timer, any entity)
{
	RemoveProjectile(entity, true);
}

// 직구 사용시 프로젝타일을 밀어준다
public void PushProjectile(int entity)
{
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	float vecInitialVelocity[3], flInitialSpeed;
	GetEntPropVector(entity, Prop_Send, "m_vInitialVelocity", vecInitialVelocity);
	flInitialSpeed = GetVectorLength(vecInitialVelocity);
	
	float vecEyePosition[3], angEyeAngles[3], vecSpawnOrigin[3], vecAngleVector[3], vecPushVector[3];
	GetClientEyePosition(client, vecEyePosition);
	GetClientEyeAngles(client, angEyeAngles);
	
	float flSpawnDistanceFront;
	flSpawnDistanceFront = 4.0;
	GetAngleVectors(angEyeAngles, vecAngleVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vecAngleVector, vecAngleVector);
	AddVectors(vecPushVector, vecAngleVector, vecPushVector);
	ScaleVector(vecAngleVector, flSpawnDistanceFront);
	AddVectors(vecEyePosition, vecAngleVector, vecSpawnOrigin);
	
	float flFinalSpeed = flInitialSpeed * 2;
	if(flFinalSpeed > 1350)
		flFinalSpeed = 1350.0;
	else if(flFinalSpeed < 250)
		flFinalSpeed = 250.0;
	
	ScaleVector(vecPushVector, flFinalSpeed);
	SetEntPropVector(entity, Prop_Send, "m_vInitialVelocity", NULL_VECTOR);
	SetEntPropVector(entity, Prop_Send, "m_vecVelocity", NULL_VECTOR);
	
	TeleportEntity(entity, vecSpawnOrigin, NULL_VECTOR, vecPushVector);	
}

// 고폭이 던져졌을 때
public void OnGrenadeSpawned(int entity)
{
	int color[4];
	color[0] = 255;
	color[1] = 255;
	color[2] = 255;
	color[3] = 255;
	TE_SetupBeamFollow(entity, g_iElecticSprite, 0, 1.0 , 3.0, 3.0, 1, color);
	TE_SendToAll();
	
//	PrintToServer("HE Grenade: m_DmgRadius %f", GetEntPropFloat(entity, Prop_Data, "m_DmgRadius"));
//	PrintToServer("HE Grenade: m_flDetonateTime %f", GetEntPropFloat(entity, Prop_Data, "m_flDetonateTime"));
//	PrintToServer("HE Grenade: m_flDamage %f", GetEntPropFloat(entity, Prop_Data, "m_flDamage"));
	
	SetEntPropFloat(entity, Prop_Data, "m_DmgRadius", 500.0);
}

// 유인수류탄이 던져졌을 때
public void OnDecoySpawned(int entity)
{
	SetEntProp(entity, Prop_Data, "m_nNextThinkTick", -1);
	
	// 유인 수류탄이 아직 활성화되지 않았다.
	// 활성화시 m_bIsLive 값을 1로 주기로 했다.
	SetEntProp(entity, Prop_Send, "m_bIsLive", 0);
	
	SDKHook(entity, SDKHook_StartTouchPost, OnDecoyTouchPost);
	
	int color[4];
	color[0] = 255;
	color[1] = 255;
	color[2] = 255;
	color[3] = 255;
	TE_SetupBeamFollow(entity, g_iElecticSprite, 0, 1.0 , 3.0, 3.0, 1, color);
	TE_SendToAll();
	
	SetEntPropFloat(entity, Prop_Data, "m_flDamage", 0.0);
}

// 디코이가 벽 또는 물체에 닿았을 때
public void OnDecoyTouchPost(int entity, int other)
{
	// 플레이어에게 닿았을 때
	if(other > 0 && other <= MaxClients)
	{
//		SDKUnhook(entity, SDKHook_StartTouch, OnDecoyTouch);
//		StickGrenade(other, entity);
	}
	// 다른 오브젝트에 닿았을 때
	else if(GetEntityMoveType(entity) != MOVETYPE_NONE)
	{
		SDKUnhook(entity, SDKHook_StartTouchPost, OnDecoyTouchPost);
		SetEntityMoveType(entity, MOVETYPE_NONE);
		ActivateRepulse(entity);
	}
}

void ActivateRepulse(int entity)
{
	// 여기서 프레임을 요구하는 이유는 이 함수에서 즉시 m_bIsLive 값을 1로 바꿀 시에 디코이가 물체에 부착되는 소리조차 나지않기 때문이다.
	RequestFrame(SetProjectileState, entity);
	
	int ent = CreateEntityByName("trigger_multiple");
	if ( ent != -1 )
	{
		SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", entity);
		// 8
		// 64 1024
		DispatchKeyValue(ent, "spawnflags", "8");
		DispatchKeyValue(ent, "StartDisabled", "0");
//		DispatchKeyValue(ent, "OnTrigger", "!activator,IgnitePlayer,,0,-1");

		DispatchSpawn(ent);
		ActivateEntity(ent);

		SetEntityModel(ent, MODEL_WIDGET);

		float minbounds[3] = {-100.0, -100.0, 0.0};
		float maxbounds[3] = {100.0, 100.0, 200.0};
		SetEntPropVector(ent, Prop_Send, "m_vecMins", minbounds);
		SetEntPropVector(ent, Prop_Send, "m_vecMaxs", maxbounds);
		
		/*
		SOLID_NONE            = 0,    // no solid model
	    SOLID_BSP            = 1,    // a BSP tree
	    SOLID_BBOX            = 2,    // an AABB, Bounding Box
	    SOLID_OBB            = 3,    // an OBB (not implemented yet)
	    SOLID_OBB_YAW        = 4,    // an OBB, constrained so that it can only yaw
	    SOLID_CUSTOM        = 5,    // Always call into the entity for tests
	    SOLID_VPHYSICS        = 6,    // solid vphysics object, get vcollide from the model and collide with that
	    SOLID_LAST,
   		*/
		SetEntProp(ent, Prop_Send, "m_nSolidType", 2);
		
		/*
		FSOLID_CUSTOMRAYTEST        = (1 << 0),    // Ignore solid type + always call into the entity for ray tests
	    FSOLID_CUSTOMBOXTEST        = (1 << 1),    // Ignore solid type + always call into the entity for swept box tests
	    FSOLID_NOT_SOLID            = (1 << 2),    // Are we currently not solid?
	    FSOLID_TRIGGER                = (1 << 3),    // This is something may be collideable but fires touch functions
	                                            // even when it's not collideable (when the FSOLID_NOT_SOLID flag is set)
	    FSOLID_NOT_STANDABLE        = (1 << 4),    // You can't stand on this
	    FSOLID_VOLUME_CONTENTS        = (1 << 5),    // Contains volumetric contents (like water)
	    FSOLID_FORCE_WORLD_ALIGNED    = (1 << 6),    // Forces the collision rep to be world-aligned even if it's SOLID_BSP or SOLID_VPHYSICS
	    FSOLID_USE_TRIGGER_BOUNDS    = (1 << 7),    // Uses a special trigger bounds separate from the normal OBB
	    FSOLID_ROOT_PARENT_ALIGNED    = (1 << 8),    // Collisions are defined in root parent's local coordinate space
	    FSOLID_TRIGGER_TOUCH_DEBRIS    = (1 << 9),    // This trigger will touch debris objects
	
	    FSOLID_MAX_BITS    = 10
    	*/
    	// 기본 8 + 4
		SetEntProp(ent, Prop_Send, "m_usSolidFlags", (1 << 2) + (1 << 3));
		
		int enteffects = GetEntProp(ent, Prop_Send, "m_fEffects");
		enteffects |= 32;
		SetEntProp(ent, Prop_Send, "m_fEffects", enteffects);  

		float vecBallOrigin[3], vecOriginOffsets[3];
		vecOriginOffsets[2] += -maxbounds[2]/2;
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vecBallOrigin);
		AddVectors(vecBallOrigin, vecOriginOffsets, vecBallOrigin);
		TeleportEntity(ent, vecBallOrigin, NULL_VECTOR, NULL_VECTOR);

//		SetVariantString(Buffer);
//		AcceptEntityInput(ent, "SetParent");
		SetVariantString("!activator");
		AcceptEntityInput(ent, "SetParent", entity, ent, 0);
		
		SDKHook(ent, SDKHook_StartTouch, OnTrigger);
//		SDKHook(ent, SDKHook_Touch, OnTrigger);
		
		LaserBOX2(ent, vecOriginOffsets);
	}
	// 10초 후 디코이 삭제
	CreateTimer(10.0, RemoveFlashbang, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

public void SetProjectileState(any entity)
{
	// 유인 수류탄이 활성화되었다.
	// 활성화시 m_bIsLive 값을 1로 주기로 했다.
	SetEntProp(entity, Prop_Send, "m_bIsLive", 1);
}

// 섬광탄 프로젝타일이 척력장에 닿을 경우
public void OnTrigger(int entity, int activator)
{
	if(!IsValidEdict(activator))	return;
	
	// 척력 수류탄 인덱스
	int iBallEntity = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	// 척력 수류탄을 던진 사람의 인덱스
	int client = GetEntPropEnt(iBallEntity, Prop_Data, "m_hOwnerEntity");
	
	char classname[64];
	GetEdictClassname(activator, classname, sizeof(classname));
	
	if(StrContains(classname, "_projectile") != -1)
	{
		// 프로젝타일이 날아오므로, 척력장의 중심과 프로젝타일의 위치를 기반으로 척력벡터를 만들어낸다.
		float vecBallOrigin[3], vecActivatorOrigin[3], vecRepulseVector[3];
		GetEntPropVector(iBallEntity, Prop_Data, "m_vecAbsOrigin", vecBallOrigin);
		GetEntPropVector(activator, Prop_Data, "m_vecAbsOrigin", vecActivatorOrigin);
		MakeVectorFromPoints(vecBallOrigin, vecActivatorOrigin, vecRepulseVector);
		NormalizeVector(vecRepulseVector, vecRepulseVector);
		
		// 이전 프로젝타일의 속도를 구해, 같은 속도로 척력을 행사한다.
		float vecVelocity[3], flRepulsePushScale;
		GetEntPropVector(activator, Prop_Send, "m_vecVelocity", vecVelocity);
		flRepulsePushScale = GetVectorLength(vecVelocity);
		ScaleVector(vecRepulseVector, flRepulsePushScale);
		
		TeleportEntity(activator, NULL_VECTOR, NULL_VECTOR, vecRepulseVector);
		
		// 섬광탄일 경우엔 프로젝타일의 소유권을 빼앗는다.
		if(StrContains(classname, "flashbang_projectile"))
		{
			SetEntPropEnt(activator, Prop_Send, "m_hThrower", client);
			SetEntPropEnt(activator, Prop_Send, "m_hOwnerEntity", client);
			SetEntPropEnt(activator, Prop_Send, "m_iTeamNum", GetClientTeam(client));
		}
	}
}

#define RED    0
#define GRE    1
#define BLU    2
#define WHI    3

#define X    0
#define Y    1
#define Z    2

int colort[4][4] = { {255, 0, 0, 255}, {0, 255, 0, 255}, {0, 0, 255, 255}, {255, 255, 255, 255} };

stock void LaserP(const float start[3], const float end[3], const int color[4])
{
    TE_SetupBeamPoints(start, end, g_iBeamSprite, 0, 0, 0, 10.0, 3.0, 3.0, 7, 0.0, color, 0);
    TE_SendToAll();
}
stock void LaserBOX2(const int Ent, const float Offsets[3])
{
    float posMin[4][3], posMax[4][3], orig[3];
    
    GetEntPropVector(Ent, Prop_Send, "m_vecMins", posMin[0]);
    GetEntPropVector(Ent, Prop_Send, "m_vecMaxs", posMax[0]);
    GetEntPropVector(GetEntPropEnt(Ent, Prop_Data, "m_hOwnerEntity"), Prop_Send, "m_vecOrigin", orig);
    
    AddVectors(orig, Offsets, orig);
    
    // Incase the entity is a player i want to make the box fit..
    char edictname[32];
    GetEdictClassname(Ent, edictname, 32);
    if (StrEqual(edictname, "player"))
    {
        posMax[0][2] += 16.0;
    }
    //
    /*
        0    =    X
        1    =    Y
        2    =    Z
    */
    posMin[1][X] = posMax[0][X];
    posMin[1][Y] = posMin[0][Y];
    posMin[1][Z] = posMin[0][Z];
    posMax[1][X] = posMin[0][X];
    posMax[1][Y] = posMax[0][Y];
    posMax[1][Z] = posMax[0][Z];
    posMin[2][X] = posMin[0][X];
    posMin[2][Y] = posMax[0][Y];
    posMin[2][Z] = posMin[0][Z];
    posMax[2][X] = posMax[0][X];
    posMax[2][Y] = posMin[0][Y];
    posMax[2][Z] = posMax[0][Z];
    posMin[3][X] = posMax[0][X];
    posMin[3][Y] = posMax[0][Y];
    posMin[3][Z] = posMin[0][Z];
    posMax[3][X] = posMin[0][X];
    posMax[3][Y] = posMin[0][Y];
    posMax[3][Z] = posMax[0][Z];
    
    AddVectors(posMin[0], orig, posMin[0]);
    AddVectors(posMax[0], orig, posMax[0]);
    AddVectors(posMin[1], orig, posMin[1]);
    AddVectors(posMax[1], orig, posMax[1]);
    AddVectors(posMin[2], orig, posMin[2]);
    AddVectors(posMax[2], orig, posMax[2]);
    AddVectors(posMin[3], orig, posMin[3]);
    AddVectors(posMax[3], orig, posMax[3]);
    
    /*
    RED        =    RED
    BLUE    =    BLU
    GREEN    =    GRE
    WHITE    =    WHI
    */
    
    //LaserP(posMin[0], posMax[0], colort[RED]);
    //LaserP(posMin[1], posMax[1], colort[BLU]);
    //LaserP(posMin[2], posMax[2], colort[GRE]);
    //LaserP(posMin[3], posMax[3], colort[WHI]);
    
    //UP & DOWN
    
    //BORDER
    LaserP(posMin[0], posMax[3], colort[WHI]);
    LaserP(posMin[1], posMax[2], colort[WHI]);
    LaserP(posMin[3], posMax[0], colort[WHI]);
    LaserP(posMin[2], posMax[1], colort[WHI]);
    //CROSS
    LaserP(posMin[3], posMax[2], colort[WHI]);
    LaserP(posMin[1], posMax[0], colort[WHI]);
    LaserP(posMin[2], posMax[3], colort[WHI]);
    LaserP(posMin[3], posMax[1], colort[WHI]);
    LaserP(posMin[2], posMax[0], colort[WHI]);
    LaserP(posMin[0], posMax[1], colort[WHI]);
    LaserP(posMin[0], posMax[2], colort[WHI]);
    LaserP(posMin[1], posMax[3], colort[WHI]);
    
    
    //TOP
    
    //BORDER
    LaserP(posMax[0], posMax[1], colort[WHI]);
    LaserP(posMax[1], posMax[3], colort[WHI]);
    LaserP(posMax[3], posMax[2], colort[WHI]);
    LaserP(posMax[2], posMax[0], colort[WHI]);
    //CROSS
    LaserP(posMax[0], posMax[3], colort[WHI]);
    LaserP(posMax[2], posMax[1], colort[WHI]);
    
    //BOTTOM
    
    //BORDER
    LaserP(posMin[0], posMin[1], colort[WHI]);
    LaserP(posMin[1], posMin[3], colort[WHI]);
    LaserP(posMin[3], posMin[2], colort[WHI]);
    LaserP(posMin[2], posMin[0], colort[WHI]);
    //CROSS
    LaserP(posMin[0], posMin[3], colort[WHI]);
    LaserP(posMin[2], posMin[1], colort[WHI]);    
}
/* // 사람에게 붙일 때...
StickGrenade(iClient, iGrenade)
{	
	//Remove Collision
	SetEntProp(iGrenade, Prop_Send, "m_CollisionGroup", 2);
	
	//stop movement
	SetEntityMoveType(iGrenade, MOVETYPE_NONE);
	
	// Stick grenade to victim
	SetVariantString("!activator");
	AcceptEntityInput(iGrenade, "SetParent", iClient);
	SetVariantString("idle");
	AcceptEntityInput(iGrenade, "SetAnimation");
	
	//set properties
	SetEntDataFloat(iGrenade, OFFSET_DAMAGE, v_HEGrenadeStuckPower);
	SetEntDataFloat(iGrenade, OFFSET_RADIUS, v_HEGrenadeStuckRadius);
		
	// If shake is enabled, shake victim
	if(v_Shake)
	{
		Shake(iClient, AMP_SHAKE, DUR_SHAKE);
	}
	
	new iThrower = GetEntDataEnt2(iGrenade, OFFSET_THROWER);
	
	//Rare case where owner of grenade is gone when it sticks.
	if(iThrower > 0 && iThrower <= MaxClients)
	{	
		if(v_EmitSounds)
		{
			ClientCommand(iClient, "play *%s", SND_SCREAM[6]);
			ClientCommand(iThrower, "play *%s", SND_LAUGH[6]);
		}
		
		//Print stuck message
		PrintToChatAll("\x01\x0B\x04[StickyNades] \x05%N \x01stuck \x05%N \x01with a \x04Frag Grenade\x01!",iThrower,iClient);
	}
}*/
