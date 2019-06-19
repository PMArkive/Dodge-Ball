/****************************** General *****************************/
public void OnMapStart()
{
	CleanUp(true, true, true);
	RequestFrame(SetConVars);
	
	g_iBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iGlowSprite = PrecacheModel("materials/sprites/blueflare1.vmt");
	g_iElecticSprite = PrecacheModel("sprites/physbeam.vmt");
	
	// 눈사람 머리
	PrecacheModel(FB_MODEL);
	
	PrecacheModel(MODEL_WIDGET);
}

public void OnClientPutInServer(int client)
{
	g_iKillPoint[client] = 0;
	
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponSwitchPost, OnSwitchWeapon);
	
	ResetClientVariables(client);
}

public void OnClientDisconnect(int client)
{
	g_iKillPoint[client] = 0;
	
	SDKUnhook(client, SDKHook_TraceAttack, OnTraceAttack);
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKUnhook(client, SDKHook_WeaponSwitchPost, OnSwitchWeapon);
	
	if(g_iTeslaEntity[client] > 0)
	{
		RemoveProjectile(g_iTeslaEntity[client]);
		g_iTeslaEntity[client] = -1;
	}
	ResetClientVariables(client);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (IsValidClient(victim))
	{
		char classname[64], weaponclassname[64];
		if(IsValidEdict(inflictor))
			GetEdictClassname(inflictor, classname, sizeof(classname));
		if(IsValidEdict(weapon))
			GetEdictClassname(weapon, weaponclassname, sizeof(weaponclassname));
		if (IsValidClient(attacker))
		{
			if (StrEqual(classname, "flashbang_projectile"))
			{
				/*
				float vecUpVector[3];
				vecUpVector[0] = 0.0;
				vecUpVector[1] = 0.0;
				vecUpVector[2] = 0.999999;
				
				ScaleVector(vecUpVector, 50000.0);
				TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vecUpVector);*/
				// 수정 없이 이미 데미지가 1000을 넘는다는 것은 traceattack에서 수정되었기 때문이다.(헤드샷)
				if(damage > 1000)
				{
					// 헤드샷으로 처리
					damagetype = damagetype | (1 << 30);
				}
				
				damage = 1337.0;
				return Plugin_Changed;
			}
			// 칼로 때렸을 때
			/*
			if (StrEqual(weaponclassname, "weapon_knife"))
			{
				if(damage > 100)
				{
					// 경직
					StunClient(victim, 1.25);
				}
				else if(damage > 50)
				{
					// 경직
					StunClient(victim, 0.5);
				}
				else
				{
					float vecUpVector[3];
					vecUpVector[0] = 0.0;
					vecUpVector[1] = 0.0;
					vecUpVector[2] = 0.999999;
					
					ScaleVector(vecUpVector, 300.0);
					TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vecUpVector);
				}
				return Plugin_Handled;
			}*/
		}
		
		if (StrEqual(classname, "hegrenade_projectile") && damagetype == DMG_BLAST)
		{
			// 같은 팀이 던진거면 중단.
			if(GetClientTeam(attacker) == GetClientTeam(victim))
				return Plugin_Stop;
			
			damage *= 5.0;
			if(damage > 100)
				damage = 100.0;
			
			if(damage >= 5)
			{
				StunClient(victim, 3.0 - (100 - damage)/33);
			}
			return Plugin_Handled;
		}
		
		
		if (attacker == 0 && damagetype & DMG_FALL)
		{
			return Plugin_Stop;
		}
	}
		
	return Plugin_Continue;
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (g_bRoundEnded)	return Plugin_Stop;
	
	if (IsClientInGame(victim) && IsClientInGame(attacker))
	{
		if(IsValidEdict(inflictor))
		{
			char classname[64];
			GetEdictClassname(inflictor, classname, sizeof(classname));
			if (StrEqual(classname, "flashbang_projectile"))
			{
				/*
				float vecUpVector[3];
				vecUpVector[0] = 0.0;
				vecUpVector[1] = 0.0;
				vecUpVector[2] = 0.999999;
				
				ScaleVector(vecUpVector, 50000.0);
				TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vecUpVector);*/
				
				// hitgroup that was damaged ; 1=hs 2=upper torso 3=lower torso 4=left arm 5=right arm 6=left leg 7=right leg
				if(ammotype == -1 /*&& (hitbox == 11 || hitbox == 20)*/ && hitgroup == 1)
				{
					//-1 12 4?
					damage = 1337.0;
					return Plugin_Changed;
				}
//				PrintToServer("att.: %N | victim: %N | ammotype: %i | hitbox: %i | hitgroup: %i",attacker, victim, ammotype, hitbox, hitgroup);
			}
		}
		if (GetClientTeam(victim) != GetClientTeam(attacker))
		{
			// 칼로 때린 경우
			if (damagetype == (DMG_NEVERGIB | DMG_SLASH) && ammotype == -1 && hitbox == 0 && hitgroup == 0) 
			{
				/*
				float victimAbsOrigin[3], attackerAbsOrigin[3], vector[3], vectorangles[3];
				GetClientAbsOrigin(victim,  victimAbsOrigin);
				GetClientAbsOrigin(attacker, attackerAbsOrigin);
				
				MakeVectorFromPoints(attackerAbsOrigin, victimAbsOrigin, vector);
				NormalizeVector(vector, vector);
				
				GetVectorAngles(vector, vectorangles);
				
				PrintToServer("damage: %f | Angle Diff: %f(%f)", damage, vectorangles[1], FloatAbs(vectorangles[1]));
				PrintToChat(attacker, "damage: %f | Angle Diff: %f(%f)", damage, vectorangles[1], FloatAbs(vectorangles[1]-180));
				
				// 120 >=
				*/
				
				if(damage == 180)
				{
					// 경직
					StunClient(victim, 1.25);
				}
				else if(damage == 65)
				{
					// 경직
					StunClient(victim, 0.5);
				}
				else if(damage == 25 || damage == 40 || damage == 90)
				{
					float vecUpVector[3];
					vecUpVector[0] = 0.0;
					vecUpVector[1] = 0.0;
					vecUpVector[2] = 0.999999;
					
					ScaleVector(vecUpVector, 300.0);
					TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vecUpVector);
				}
				return Plugin_Handled;
			}
		}
		if (GetClientTeam(victim) == GetClientTeam(attacker))
		{
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

public Action OnSwitchWeapon(int client, int weapon)
{
	char classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	
	if(StrEqual(classname, "weapon_hegrenade"))
	{
		g_iTeslaEntity[client] = CreateTesla(client);
	}
	else
	{
		if(g_iTeslaEntity[client] > 0)
		{
			RemoveProjectile(g_iTeslaEntity[client]);
			g_iTeslaEntity[client] = -1;
		}
	}
	
	if(StrEqual(classname, "weapon_knife"))
	{
		// 플래시뱅 프로젝타일이 생성되었을 때 true 값을 가진다.
		// 이 경우에만 자동 스왑하도록 설정.
		if(g_bAutoSwitchFb[client])
		{
			FakeClientCommand(client, "use weapon_flashbang");
			g_bAutoSwitchFb[client] = false;
		}
		
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

public Action OnNormalSoundEmit(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	char classname[64];
	GetEdictClassname(entity, classname, sizeof(classname));
	
	// 소리의 주체가 유인수류탄(척력 수류탄)일 경우
	if(StrEqual(classname, "decoy_projectile", false))
	{
		bool bIsRepulsionActivated = view_as<bool>(GetEntProp(entity, Prop_Send, "m_bIsLive"));
		
		// 그리고 척력수류탄이 활성화 상태일 경우
		if(bIsRepulsionActivated)
		{
			// 소리를 없앤다.
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

/****************************** Events ******************************/

public void OnPlayerSpawn(Event event, char[] name, bool broadcast)
{	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	int team = GetClientTeam(client);
	if((team == 2 || team == 3) && IsPlayerAlive(client))
	{
		RemoveGuns(client);
		GivePlayerItem(client, "weapon_knife");
		if(!IsFakeClient(client))
			GivePlayerItem(client, "weapon_flashbang");
		
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, 255, 255, 255, 255);
		
		ResetClientVariables(client);
		PrintToChat(client, "\x01 [Dodge Ball] \x05R\x01키를 이용해 상점을 이용하실 수 있습니다.");
	}
}

// 클라이언트가 죽을 때
public void OnPlayerDeath(Event event, char[] name, bool broadcast)
{	
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	bool headshot = event.GetBool("headshot"); 
	
	if(IsValidClient(attacker))
	{
		if(!IsWarmupPeriod())
		{
			g_iKillPoint[attacker]++;
			PrintToChat(attacker, "\x01 [Dodge Ball] 적을 처치하여 \x031\x01킬 포인트를 획득했습니다.");
			if(headshot) {
				g_iKillPoint[attacker]++;
				PrintToChat(attacker, "\x01 [Dodge Ball] 적을 \x05헤드샷\x01으로 처치하여 \x031\x01킬 포인트를 획득했습니다.");
			}
				
		}
		
		//스턴 상태 해제
		UnstunClient(client);
		
		if(g_iTeslaEntity[client] > 0)
		{
			RemoveProjectile(g_iTeslaEntity[client]);
			g_iTeslaEntity[client] = -1;
		}
		
		if(attacker != client)
		{
			int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
			if(ragdoll > 0 && IsValidEdict(ragdoll))
			{
				float vecRagdollVel[3];
				float vecForce[3];
				
				vecRagdollVel[2] = 500.0;
				
				float vecUpVector[3];
				vecUpVector[0] = 0.0;
				vecUpVector[1] = 0.0;
				vecUpVector[2] = 0.999999;
						
				ScaleVector(vecUpVector, 150000.0);
				
				// m_vecForce, m_vecRagdollVelocity
				GetEntPropVector(ragdoll, Prop_Send, "m_vecForce", vecForce);
				AddVectors(vecUpVector, vecForce, vecForce);
				SetEntPropVector(ragdoll, Prop_Send, "m_vecForce", vecForce);
			}
		}
	}
}

public Action OnDetonate(Event event, const char[] name, bool dontBroadcast)
{
//	int client = GetClientOfUserId(event.GetInt("userid"));
	
	float vecOrigin[3];
	vecOrigin[0] = event.GetFloat("x");
	vecOrigin[1] = event.GetFloat("y");
	vecOrigin[2] = event.GetFloat("z");
	
	CreateTeslaDetonate(vecOrigin);
}

// 라운드 시작
public void OnRoundStart(Event event, char[] name, bool dontBroadcast)
{
	CleanUp(false, false, true);
		
	g_bRoundEnded = false;
}

public Action OnRoundFreezeTimeEnd(Event event, char[] name, bool broadcast)
{
	CleanUp(false, false, true);
		
	g_bRoundEnded = false;
}

// 라운드 끝
public void OnRoundEnd(Event event, char[] name, bool broadcast)
{
	int winnerTeam = event.GetInt("winner");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(GetClientTeam(i) == winnerTeam)
			{
				g_iKillPoint[i] += 1;
				PrintToChat(i, "\x01 [Dodge Ball] 라운드에서 \x05승리\x01하여 \x031\x01킬 포인트를 획득했습니다.");
			}
		}
	}
	g_bRoundEnded = true;
	// 무기 삭제
	CleanUp(true, false, false);
}

/****************************** Entity Hook ***************************/
/*
public void trigger_multiple(const char[] output, int caller, int activator, float delay)
{
	char m_iName[15];
	GetEntPropString(caller, Prop_Data, "m_iName", m_iName, sizeof(m_iName));
	
	if(!StrEqual(m_iName, "trigger_repulsive")) return;
	
	int iBallEntity = GetEntPropEnt(caller, Prop_Data, "m_hOwnerEntity");
	
	PrintToChatAll("%s) %s", m_iName, output);
	if(StrEqual(output, "OnTouching"))
	{
		if(IsValidEdict(activator))
		{
			char classname[64];
			GetEdictClassname(activator, classname, sizeof(classname));
			
			if(StrEqual(classname, "flashbang_projectile", false))
			{
				float vecBallOrigin[3], vecActivatorOrigin[3], vecRepulseVector[3];
				GetEntPropVector(iBallEntity, Prop_Data, "m_vecAbsOrigin", vecBallOrigin);
				GetEntPropVector(activator, Prop_Data, "m_vecAbsOrigin", vecActivatorOrigin);
				MakeVectorFromPoints(vecBallOrigin, vecActivatorOrigin, vecRepulseVector);
				NormalizeVector(vecRepulseVector, vecRepulseVector);
				ScaleVector(vecRepulseVector, 300.0);
				TeleportEntity(activator, NULL_VECTOR, NULL_VECTOR, vecRepulseVector);
			}
		}
	}    
}*/

/****************************** Commands ******************************/

public Action SayHook(int client, char[] command, int argc)
{	
	char Msg[256];
	GetCmdArgString(Msg, sizeof(Msg));
	Msg[strlen(Msg) - 1] = '\0';
	
	if (StrEqual(Msg[1], "!상점", false) || StrEqual(Msg[1], "!shop", false))
	{
		if (IsPlayerAlive(client))
		{
			ShopMenu(client);
		}
	}
	return Plugin_Continue;
}
public Action BuyMenuEvent(int client, char[] command, int argc)
{	
	if (IsPlayerAlive(client))
	{
		ShopMenu(client);
	}
	return Plugin_Handled;
}