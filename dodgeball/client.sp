// 무기 다 없애기
void RemoveGuns(int client)
{
	if (!(IsClientInGame(client) && IsPlayerAlive(client)))	return;
	int weaponID;
	int MyWeaponsOffset = FindSendPropInfo("CBaseCombatCharacter", "m_hMyWeapons");
	
	for(int x = 0; x < 20; x += 4)
	{
		weaponID = GetEntDataEnt2(client, MyWeaponsOffset + x);
		
		if(weaponID <= 0) {
			continue;
		}
		/*
		char weaponClassName[128];
		GetEntityClassname(weaponID, weaponClassName, sizeof(weaponClassName));
		
		if(StrContains(weaponClassName, immunities, false) != -1) {
			continue;
		}*/
		if(weaponID != -1)
		{
			RemovePlayerItem(client, weaponID);
			RemoveEdict(weaponID);
		}
	}
}

void ResetClientVariables(int client)
{
	g_bUseStraightBall[client] = false;
	g_bUseBounceBall[client] = false;
	g_bUseDoubleFire[client] = false;
	g_bAutoSwitchFb[client] = false;
	g_bIsStuned[client] = false;
	g_flStunEndTime[client] = 0.0;
	g_iButtonFlags[client] = 0;
}

void RemoveProjectile(int entity, bool byRef=false)
{
	if (byRef)	entity = EntRefToEntIndex(entity);
	if(IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "KillHierarchy");
	}
}

int CreateTesla(int client)
{
	RemoveProjectile(g_iTeslaEntity[client]);
	
	int tesla = CreateEntityByName("point_tesla");
	DispatchKeyValue(tesla, "m_flRadius", "30.0");
	DispatchKeyValue(tesla, "m_SoundName", "DoSpark");
	DispatchKeyValue(tesla, "beamcount_min", "4");
	DispatchKeyValue(tesla, "beamcount_max", "9");
	DispatchKeyValue(tesla, "texture", "sprites/physbeam.vmt");
	DispatchKeyValue(tesla, "m_Color", "255 255 255");
	DispatchKeyValue(tesla, "thick_min", "2.0");
	DispatchKeyValue(tesla, "thick_max", "2.0");
	DispatchKeyValue(tesla, "lifetime_min", "0.3");
	DispatchKeyValue(tesla, "lifetime_max", "0.3");
	DispatchKeyValue(tesla, "interval_min", "0.1");
	DispatchKeyValue(tesla, "interval_max", "0.2");
	DispatchSpawn(tesla);
	
	float vecAbsOrigin[3];
	GetClientAbsOrigin(client, vecAbsOrigin);
	TeleportEntity(tesla, vecAbsOrigin, NULL_VECTOR, NULL_VECTOR); 
	
	SetVariantString("!activator");
	AcceptEntityInput(tesla, "SetParent", client, tesla, 0);
	SetVariantString("weapon_hand_R");
	AcceptEntityInput(tesla, "SetParentAttachmentMaintainOffset", tesla, tesla, 0);
	
	ActivateEntity(tesla);
	AcceptEntityInput(tesla, "TurnOn");
	AcceptEntityInput(tesla, "DoSpark");
	
	return tesla;
}

void CreateTeslaDetonate(float vecOrigin[3])
{	
	int tesla = CreateEntityByName("point_tesla");
	
	DispatchKeyValueFloat(tesla, "m_flRadius", 250.0);
	DispatchKeyValue(tesla, "m_SoundName", "DoSpark");
	DispatchKeyValue(tesla, "beamcount_min", "64");
	DispatchKeyValue(tesla, "beamcount_max", "128");
	DispatchKeyValue(tesla, "texture", "sprites/physbeam.vmt");
	DispatchKeyValue(tesla, "m_Color", "255 255 255");
	DispatchKeyValueFloat(tesla, "thick_min", 2.0);
	DispatchKeyValueFloat(tesla, "thick_max", 3.5);
	DispatchKeyValueFloat(tesla, "lifetime_min", 1.5);
	DispatchKeyValueFloat(tesla, "lifetime_max", 3.0);
	DispatchKeyValueFloat(tesla, "interval_min", 0.1);
	DispatchKeyValueFloat(tesla, "interval_max", 0.2);
	DispatchSpawn(tesla);
	
	TeleportEntity(tesla, vecOrigin, NULL_VECTOR, NULL_VECTOR);
	
	ActivateEntity(tesla);
	
	AcceptEntityInput(tesla, "DoSpark");
	AcceptEntityInput(tesla, "DoSpark");
	AcceptEntityInput(tesla, "DoSpark");
	RequestFrame(RemoveTeslaDetonate, tesla);
}

public void RemoveTeslaDetonate(any entity)
{
	RemoveProjectile(entity);
}

stock bool IsValidClient(int client)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
		return true;
	return false;
}

stock void SetFlashbangCount(int client, int amount)
{
	SetAmmo(client, CSGO_FLASH_AMMO, amount);
}

stock int GetFlashbangCount(int client)
{
	return GetAmmo(client, CSGO_FLASH_AMMO);
}

stock void SetAmmo(int client, int item, int ammo)
{
	SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, item);
}

stock int GetAmmo(int client, int item)
{
	return GetEntProp(client, Prop_Send, "m_iAmmo", _, item);
}

stock void StunClient(int client, float flDuration)
{
	// 이미 스턴 상태라면..
	if(g_bIsStuned[client])
	{
		// 지금 걸린 스턴이 더 지속시간이 길다면
		if(g_flStunEndTime[client] > GetGameTime() + flDuration)
		{
			// 스턴을 무시한다.
			return;
		}
	}
	g_bIsStuned[client] = true;
	g_flStunEndTime[client] = GetGameTime() + flDuration;
	SetEntProp(client, Prop_Data, "m_fFlags", (GetEntProp(client, Prop_Data, "m_fFlags") | FL_ATCONTROLS));
	
	Fade(client, flDuration);
	Shake(client, flDuration);
}

stock void UnstunClient(int client)
{
	g_bIsStuned[client] = false;
	g_flStunEndTime[client] = 0.0;
	SetEntProp(client, Prop_Data, "m_fFlags", (GetEntProp(client, Prop_Data, "m_fFlags") & ~FL_ATCONTROLS));
}

/**********************************************************************************************
클라이언트에 대한 시각적 및 청각적 효과 관련 함수
***********************************************************************************************/

#define FFADE_IN		0x0001		// Fade In
#define FFADE_OUT		0x0002		// Fade out
#define FFADE_PURGE		0x0010		// Purges all other fades, replacing them with this one

stock void Fade(int client, float duration)
{
	Handle hFadeClient = StartMessageOne("Fade", client);
	if (hFadeClient == null)
		return;
	
	
	float FadePower = 1.0; // Scales the fade effect, 1.0 = Normal , 2.0 = 2 x Stronger fade, etc
	
	FadePower *= 1000.0; // duration => 밀리세컨드 단위이므로 1000을 곱해준다.
	int coloroffset = 255 - RoundToFloor(duration * 85);
	//지속시간 값이 적을수록 coloroffset값은 높아진다...
	
	int color[4];
	color[0] = 0;
	color[1] = 127;
	color[2] = 255;
	color[3] = 255-(coloroffset/2);
	
	if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(hFadeClient, "duration", RoundToFloor(duration*FadePower));
		PbSetInt(hFadeClient, "hold_time", 0);
		PbSetInt(hFadeClient, "flags", FFADE_IN | FFADE_PURGE);
		PbSetColor(hFadeClient, "clr", color);
	}
	else
	{
		BfWriteShort(hFadeClient, RoundToFloor(duration));	// FIXED 16 bit, with SCREENFADE_FRACBITS fractional, milliseconds duration
		BfWriteShort(hFadeClient, 0);	// FIXED 16 bit, with SCREENFADE_FRACBITS fractional, milliseconds duration until reset (fade & hold)
		BfWriteShort(hFadeClient, FFADE_IN | FFADE_PURGE); // fade type (in / out)
		BfWriteByte(hFadeClient, color[0]);	// fade red
		BfWriteByte(hFadeClient, color[1]);	// fade green
		BfWriteByte(hFadeClient, color[2]);	// fade blue
		BfWriteByte(hFadeClient, color[3]);// fade alpha
		
	}
	EndMessage();
//	delete hFadeClient;
}

stock void Shake(int client, float duration)
{
	Handle hShake = StartMessageOne("Shake", client, 1); // 이 StartMessageOne 함수의 세번째 인수값은 원래 0이었음. 2015/05/27
	if (hShake == null)
		return;
	
	float ShakePower = 25.0; // Scales the shake effect, 1.0 = Normal , 2.0 = 2 x Stronger shake, etc
	float shk = (duration * ShakePower);
	
	if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(hShake, "command", 0);
		PbSetFloat(hShake, "local_amplitude", shk);
		PbSetFloat(hShake, "frequency", 1.0);
		PbSetFloat(hShake, "duration", duration);
	}
	else
	{
		BfWriteByte(hShake,  0);
		BfWriteFloat(hShake, shk);
		BfWriteFloat(hShake, 1.0);
		BfWriteFloat(hShake, duration);
	}
	EndMessage();
//	delete hShake;
}