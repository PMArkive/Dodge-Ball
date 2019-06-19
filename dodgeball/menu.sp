// 상점 메뉴
void ShopMenu(int client, int menuTime=MENU_TIME_FOREVER)
{	
	Menu menu = new Menu(sound_selection);
	menu.SetTitle("== 상점 ==\n현재 KP: %i", g_iKillPoint[client]);
	
	int cost;
	// 이미 사용중이 아니어야 한다.
	// 라운드가 종료된 상태가 아니어야 한다.
	// 준비 시간에는 KP가 없더라도 허용하지만, 준비시간이 아니라면 KP가 필요하다.
	cost = 3;
	menu.AddItem("", "[Straight Ball | 1 Round] - 3KP\n- 볼이 직선으로 날아갑니다.", (!g_bUseStraightBall[client] && !g_bRoundEnded && (IsWarmupPeriod() || g_iKillPoint[client] >= cost))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	cost = 4;
	menu.AddItem("", "[Bounce Ball | 1 Round] - 4KP\n- 볼이 물체에 닿으면 튕겨나옵니다.", (!g_bUseBounceBall[client] && !g_bRoundEnded && (IsWarmupPeriod() || g_iKillPoint[client] >= cost))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	cost = 3;
	menu.AddItem("", "[Double Fire | 1 Round] - 3KP\n- 1초 후 같은 위치에서 추가 볼이 날아갑니다.", (!g_bUseDoubleFire[client] && !g_bRoundEnded && (IsWarmupPeriod() || g_iKillPoint[client] >= cost))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	cost = 2;
	menu.AddItem("", "[Electric Ball | x1] - 2KP\n- 맞은 적은 최대 3초간 경직됩니다.", (GetAmmo(client, CSGO_HEGRENADE_AMMO)<10 && !g_bRoundEnded && (IsWarmupPeriod() || g_iKillPoint[client] >= cost))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	cost = 2;
	menu.AddItem("", "[Repulsive Ball | x1] - 2KP\n- 닿은 물체에 붙어 10초간 척력장을 형성합니다.", (GetAmmo(client, CSGO_HEGRENADE_AMMO)<10 && !g_bRoundEnded && (IsWarmupPeriod() || g_iKillPoint[client] >= cost))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	
	menu.Display(client, menuTime);
}

public int sound_selection(Menu menu, MenuAction action, int client, int item)
{
	if(action == MenuAction_Select)
	{
		if (g_bRoundEnded)	return;
		
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			switch(item)
			{
				case 0:
				{
					if(g_iKillPoint[client] >= 3 || IsWarmupPeriod())
					{
						PrintToChat(client, "[Dodge Ball] Straight Ball을 구매하셨습니다.");
						if(!IsWarmupPeriod())
							g_iKillPoint[client] -= 3;
						
						g_bUseStraightBall[client] = true;
					}
					else
					{
						PrintToChat(client, "[Dodge Ball] 킬 포인트가 부족합니다.");
					}
				}
				case 1:
				{
					if(g_iKillPoint[client] >= 4 || IsWarmupPeriod())
					{
						PrintToChat(client, "[Dodge Ball] Bounce Ball을 구매하셨습니다.");
						if(!IsWarmupPeriod())
							g_iKillPoint[client] -= 4;
						
						g_bUseBounceBall[client] = true;
					}
					else
					{
						PrintToChat(client, "[Dodge Ball] 킬 포인트가 부족합니다.");
					}
				}
				case 2:
				{
					if(g_iKillPoint[client] >= 3 || IsWarmupPeriod())
					{
						PrintToChat(client, "[Dodge Ball] Double Fire를 구매하셨습니다.");
						if(!IsWarmupPeriod())
							g_iKillPoint[client] -= 3;
						
						g_bUseDoubleFire[client] = true;
					}
					else
					{
						PrintToChat(client, "[Dodge Ball] 킬 포인트가 부족합니다.");
					}
				}
				case 3:
				{
					if(g_iKillPoint[client] >= 2 || IsWarmupPeriod())
					{
						PrintToChat(client, "[Dodge Ball] Electric Ball을 구매하셨습니다.");
						if(!IsWarmupPeriod())
							g_iKillPoint[client] -= 2;
						
						GivePlayerItem(client, "weapon_hegrenade");
					}
					else
					{
						PrintToChat(client, "[Dodge Ball] 킬 포인트가 부족합니다.");
					}
				}
				case 4:
				{
					if(g_iKillPoint[client] >= 2 || IsWarmupPeriod())
					{
						PrintToChat(client, "[Dodge Ball] Repulsive Ball을 구매하셨습니다.");
						if(!IsWarmupPeriod())
							g_iKillPoint[client] -= 2;
						
						GivePlayerItem(client, "weapon_decoy");
					}
					else
					{
						PrintToChat(client, "[Dodge Ball] 킬 포인트가 부족합니다.");
					}
				}
			}
			ShopMenu(client, 3);
		}		
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}