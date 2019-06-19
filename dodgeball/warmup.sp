public Action BlockWarmupNoticeTextMsg(UserMsg msg_id, Handle pb, const int[] players, int playersNum, bool reliable, bool init) 
{
	char buffer[40]; 
	PbReadString(pb, "params", buffer, sizeof(buffer), 0);
	
//	PrintToServer("OMG! IT'S TEXT MSG!, %i\n%s", PbReadInt(pb, "msg_dst"), buffer);
	
	if(PbReadInt(pb, "msg_dst") == 3) 
	{
		// 준비시간이 다 되면 게임이 시작된다는 메세지를 없앤다.
		if(StrEqual(buffer, "#SFUI_Notice_Match_Will_Start_Chat", false)) 
		{
			if(GetPlayerCount() < 2)
			{
				return Plugin_Handled;
			}
		} 
	}
	return Plugin_Continue;
}

bool g_bRestartChecked = false;

public void OnGameFrame()
{
	// 준비 시간일 때
	if(IsWarmupPeriod())
	{
		if(GetPlayerCount() < 2)
		{
			PrintHintTextToAll("최소 %i명 이상이어야 플레이가 가능합니다.", 2);
			SetWarmupStartTime(GetGameTime()+0.5);
			return;
		}
			
		// 채택!
		if(GetRestartRoundTime() > 0.0)
		{
			if(!g_bRestartChecked)
			{
				if(GetWarmupLeftTime() < 0.0)
				{
					g_bRestartChecked = true;
					PrintToChatAll("준비 시간 종료! %i초 뒤 게임 시작!", RoundToNearest(GetRestartRoundTime()-GetGameTime()));
				}
			}
		}
		else
		{
			if(g_bRestartChecked)	g_bRestartChecked = false;
		}
		PrintHintTextToAll("지금은 준비 시간입니다: %.1f", GetWarmupLeftTime());
	}
	else // 준비 시간이 아닐 때
	{
		if(GetRoundLeftTime() <= 0)
		{
			if(!g_bRoundEnded)
			{
				CS_TerminateRound(GetConVarFloat(FindConVar("mp_round_restart_delay")), CSRoundEnd_Draw);
				g_bRoundEnded = true;
			}
		}
	}
}

stock bool IsWarmupPeriod()
{
	return view_as<bool>(GameRules_GetProp("m_bWarmupPeriod"));
}

stock float GetWarmupStartTime()
{
	return GameRules_GetPropFloat("m_fWarmupPeriodStart");
}

stock float GetWarmupEndTime()
{
//	return GameRules_GetPropFloat("m_fWarmupPeriodEnd");
	return (GetWarmupStartTime() + GetConVarFloat(FindConVar("mp_warmuptime")));
}

stock float GetWarmupLeftTime()
{
	return (GetWarmupEndTime() - GetGameTime());
}

stock void SetWarmupStartTime(float time)
{
	GameRules_SetPropFloat("m_fWarmupPeriodStart", time, _, true);
}

stock void SetWarmupEndTime(float time)
{
	GameRules_SetPropFloat("m_fWarmupPeriodEnd", time, _, true);
}

stock void RestartRound(float time)
{
	GameRules_SetPropFloat("m_flRestartRoundTime", time);
}

stock float GetRestartRoundTime()
{
	return GameRules_GetPropFloat("m_flRestartRoundTime");
}

stock float GetRoundStartTime()
{
	return GameRules_GetPropFloat("m_fRoundStartTime");
}

stock float GetRoundLeftTime()
{
	return ((GetConVarFloat(FindConVar("mp_roundtime"))*60 - (GetGameTime() - GetRoundStartTime())));
}

stock int GetPlayerCount()
{
	return (GetTeamClientCount(CS_TEAM_T) + GetTeamClientCount(CS_TEAM_CT));
}