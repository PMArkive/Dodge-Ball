void CleanUp(bool items, bool subjects, bool hostage)
{
	int maxent = GetMaxEntities();
	char name[64];
	for (int i=GetMaxClients();i<maxent;i++)
	{
		if ( IsValidEdict(i) && IsValidEntity(i) )
		{
			GetEdictClassname(i, name, sizeof(name));
			
			// 주인없는 무기 혹은 장비삭제(땅에 떨어진 물체)
			if (items && ( StrContains(name, "weapon_,item_") != -1 && IsValidEdict(GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity")) ))
			{
				RemoveEdict(i);
				continue;
			}
			
			// 바이존, 폭파지점, 인질 구출 등의 목적 오브젝트 삭제
			if (subjects && ((StrEqual("func_buyzone", name) || StrEqual("func_bomb_target", name)
			|| StrEqual("info_bomb_target", name) || StrEqual("func_hostage_rescue", name)
			|| StrEqual("func_escapezone", name))))
			{
				RemoveEdict(i);
				continue;
			}
			
			// 인질엔티티 삭제
			if(hostage && StrEqual(name, "hostage_entity"))
			{
				RemoveEdict(i);
				continue;
			}
		}
	}
}

stock bool ClearTimer(Handle &hTimer, bool autoClose=true)
{
	if(hTimer != null)
	{
		KillTimer(hTimer, autoClose);
		hTimer = null;
		return true;
	}
	return false;
}