/*QUAKED target_healthbar (0 1 0) (-8 -8 -8) (8 8 8) PVS_ONLY PLAYERNAME DISPLAYNAME
* 
* Hook up health bars to monsters.
* "delay" is how long to show the health bar for after death.
* "message" is their displayed name (one name for both healthbars)
* "offset" is the vertical distance between the two healthbars
*
* the following are untested
* "leftbarbg" is the sprite for the left part of the healthbar background
* "rightbarbg" is the sprite for the right part of the healthbar background
* "leftbar" is the sprite for the left part of the healthbar
* "rightbar" is the sprite for the right part of the healthbar
*
* maximum of two healthbars active at any one time (use only one target_healthbar per separate healthbar) eg:
* .ent_create target_healthbar "targetname:hb1:target:zombie1:message:ZOMBIES:delay:3"
* .ent_create target_healthbar "targetname:hb1:target:zombie2:message:ZOMBIES:delay:3"
*
* the message of the latest triggered target_healthbar will be used as the name
* for now, if using custom healthbar sprites, split them into two equal parts and set m_flWidthMax to the total width (make sure it's divisible by 2), no more than 1024 (due to hardcoded limits :aRage:)
* 
* Can be used on players and breakable objects with the appropriate spawnflag
* The DISPLAYNAME spawnflag will only work on monsters
*/

namespace target_healthbar
{

const float THINK_RATE	= 0.25; //0.025 original

const int SPAWNFLAG_HEALTHBAR_PVS_ONLY			= 1;
const int SPAWNFLAG_HEALTHBAR_PLAYERNAME		= 2;
const int SPAWNFLAG_HEALTHBAR_DISPLAYNAME	= 4;

const int MAX_HEALTH_BARS			= 2; //2 max, at least for now (limited by the number of sprite channels blyat)
const int HUD_TEXT_HEALTHBAR	= 1;
const int HUD_SPRITE_HB_BG_L		= 1;
const int HUD_SPRITE_HB_BG_R		= 2;
const int HUD_SPRITE_HB_L			= 3;
const int HUD_SPRITE_HB_R			= 4;

//these two need to be global
array<EHandle> g_arrehHealthBarEntities( MAX_HEALTH_BARS );
string CONFIG_HEALTH_BAR_NAME = "";

class target_healthbar : ScriptBaseEntity
{
	private EHandle m_hTarget;
	private float m_flDelay = 3.0;
	private int m_iBarValue;
	private float m_flTimeToRemove;
	private float m_flOffset = 0.035; //distance between the two healthbars
	private float m_flWidthMax = 944; //472 per bar
	private string m_sHealthbarBGLeft = "quake2/healthbar_bg-left.spr";
	private string m_sHealthbarBGRight = "quake2/healthbar_bg-right.spr";
	private string m_sHealthbarLeft = "quake2/healthbar-left.spr";
	private string m_sHealthbarRight = "quake2/healthbar-right.spr";

	private HUDTextParams m_textParms;
	private HUDSpriteParams m_hudParamsHealthbarBG_L;
	private HUDSpriteParams m_hudParamsHealthbarBG_R;
	private HUDSpriteParams m_hudParamsHealthbar_L;
	private HUDSpriteParams m_hudParamsHealthbar_R;

	private int m_iLastBarValue = -99999;
	private float m_flNextPVSCheck = 0.0;

	private array<bool> m_bVisibleToPlayer( 33, false );
	array<bool> m_bHUDInitializedPlayer( 33, false );

	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if( szKey == "delay" )
		{
			m_flDelay = atof( szValue );
			return true;
		}
		else if( szKey == "offset" )
		{
			m_flOffset = atof( szValue );
			return true;
		}
		else if( szKey == "leftbarbg" )
		{
			m_sHealthbarBGLeft = szValue;
			return true;
		}
		else if( szKey == "rightbarbg" )
		{
			m_sHealthbarBGRight = szValue;
			return true;
		}
		else if( szKey == "leftbar" )
		{
			m_sHealthbarLeft = szValue;
			return true;
		}
		else if( szKey == "rightbar" )
		{
			m_sHealthbarRight = szValue;
			return true;
		}
		else if( szKey == "widthmax" )
		{
			m_flWidthMax = atof( szValue );
			return true;
		}
		else
			return BaseClass.KeyValue( szKey, szValue );
	}

	void Spawn()
	{
		if( string(pev.target).IsEmpty() )
		{
			g_Game.AlertMessage( at_error, "%1: missing target\n", self.GetClassname() );
			g_EntityFuncs.Remove( self );
			return;
		}

		if( !pev.SpawnFlagBitSet(SPAWNFLAG_HEALTHBAR_PLAYERNAME|SPAWNFLAG_HEALTHBAR_DISPLAYNAME) and string(pev.message).IsEmpty() )
		{
			g_Game.AlertMessage( at_error, "%1: missing message\n", self.GetClassname() );
			g_EntityFuncs.Remove( self );
			return;
		}

		Precache();

		m_iBarValue = 0; //max

		InitializeHUDParams();

		SetUse( UseFunction(this.use_target_healthbar) );
	}

	void Precache()
	{
		g_Game.PrecacheModel( "sprites/" + m_sHealthbarBGLeft );
		g_Game.PrecacheModel( "sprites/" + m_sHealthbarBGRight );
		g_Game.PrecacheModel( "sprites/" + m_sHealthbarLeft );
		g_Game.PrecacheModel( "sprites/" + m_sHealthbarRight );
	}

	void InitializeHUDParams()
	{
		m_textParms.fadeinTime = 0.0;
		m_textParms.fadeoutTime = 0.1;
		m_textParms.holdTime = 99999.0; //0.02;
		m_textParms.effect = 0;
		m_textParms.channel = HUD_TEXT_HEALTHBAR;
		m_textParms.x = -1.0;
		m_textParms.y = 0.1;
		m_textParms.r1 = 0;
		m_textParms.g1 = 255;
		m_textParms.b1 = 255;
		m_textParms.r2 = 0;
		m_textParms.g2 = 0;
		m_textParms.b2 = 255;

		m_hudParamsHealthbarBG_L.channel = IsTopHealthbar() ? HUD_SPRITE_HB_BG_L : HUD_SPRITE_HB_BG_L+4;
		m_hudParamsHealthbarBG_L.flags = HUD_SPR_MASKED;
		m_hudParamsHealthbarBG_L.spritename = m_sHealthbarBGLeft;
		m_hudParamsHealthbarBG_L.x = 0.25;
		m_hudParamsHealthbarBG_L.y = 0.13 + GetHealthbarOffset();
		m_hudParamsHealthbarBG_L.color1 = RGBA_WHITE;
		m_hudParamsHealthbarBG_L.holdTime = 99999.0;

		m_hudParamsHealthbarBG_R.channel = IsTopHealthbar() ? HUD_SPRITE_HB_BG_R : HUD_SPRITE_HB_BG_R+4;
		m_hudParamsHealthbarBG_R.flags = HUD_SPR_MASKED;
		m_hudParamsHealthbarBG_R.spritename = m_sHealthbarBGRight;
		m_hudParamsHealthbarBG_R.x = 0.5;
		m_hudParamsHealthbarBG_R.y = 0.13 + GetHealthbarOffset();
		m_hudParamsHealthbarBG_R.color1 = RGBA_WHITE;
		m_hudParamsHealthbarBG_R.holdTime = 99999.0;

		int iHalfWidth = int( m_flWidthMax / 2 );

		m_hudParamsHealthbar_L.fadeinTime = 0.0;
		m_hudParamsHealthbar_L.fadeoutTime = 0.1;
		m_hudParamsHealthbar_L.holdTime = 99999.0; //0.02;
		m_hudParamsHealthbar_L.effect = 0;
		m_hudParamsHealthbar_L.channel = IsTopHealthbar() ? HUD_SPRITE_HB_L : HUD_SPRITE_HB_L+4;
		m_hudParamsHealthbar_L.flags = HUD_SPR_MASKED;
		m_hudParamsHealthbar_L.spritename = m_sHealthbarLeft;
		m_hudParamsHealthbar_L.x = 0.25;
		m_hudParamsHealthbar_L.y = 0.13 + GetHealthbarOffset();
		m_hudParamsHealthbar_L.width = (m_iBarValue >= iHalfWidth) ? iHalfWidth : m_iBarValue; //hudParamsHealthbar_L.width = m_iBarValue > (m_flWidthMax/2) ? 0 : m_iBarValue;
		m_hudParamsHealthbar_L.color1 = RGBA_WHITE;
		m_hudParamsHealthbar_L.frame = 0;

		m_hudParamsHealthbar_R.fadeinTime = 0.0;
		m_hudParamsHealthbar_R.fadeoutTime = 0.1;
		m_hudParamsHealthbar_R.holdTime = 99999.0; //0.02;
		m_hudParamsHealthbar_R.effect = 0;
		m_hudParamsHealthbar_R.channel = IsTopHealthbar() ? HUD_SPRITE_HB_R : HUD_SPRITE_HB_R+4;
		m_hudParamsHealthbar_R.flags = HUD_SPR_MASKED;
		m_hudParamsHealthbar_R.spritename = m_sHealthbarRight;
		m_hudParamsHealthbar_R.x = 0.5;
		m_hudParamsHealthbar_R.y = 0.13 + GetHealthbarOffset();
		m_hudParamsHealthbar_R.width = (m_iBarValue > iHalfWidth) ? m_iBarValue - iHalfWidth : 0; //hudParamsHealthbar_R.width = m_iBarValue - int( m_flWidthMax / 2 );
		m_hudParamsHealthbar_R.color1 = RGBA_WHITE;
		m_hudParamsHealthbar_R.frame = 0;
	}

	void HealthbarThink()
	{
		UpdateHealthbarValue();

		DrawHUD();

		pev.nextthink = g_Engine.time + THINK_RATE;
	}

	void use_target_healthbar( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		CBaseEntity@ target = g_EntityFuncs.FindEntityByTargetname( null, string(pev.target) );

		if( target is null )
		{
			g_Game.AlertMessage( at_error, "%1: no target\n", self.GetClassname() );

			g_EntityFuncs.Remove( self );
			return;
		}

		for( int i = 0; i < MAX_HEALTH_BARS; i++ )
		{
			if( g_arrehHealthBarEntities[i].IsValid() )
				continue;

			m_hTarget = EHandle( target );
			g_arrehHealthBarEntities[i] = EHandle( self );

			if( target.pev.FlagBitSet(FL_CLIENT) and pev.SpawnFlagBitSet(SPAWNFLAG_HEALTHBAR_PLAYERNAME) )
				CONFIG_HEALTH_BAR_NAME = string( target.pev.netname );
			else if( target.pev.FlagBitSet(FL_MONSTER) and pev.SpawnFlagBitSet(SPAWNFLAG_HEALTHBAR_DISPLAYNAME) )
			{
				CBaseMonster@ pMonster = target.MyMonsterPointer();
				if( pMonster !is null )
					CONFIG_HEALTH_BAR_NAME = string( pMonster.m_FormattedName );
			}
			else
				CONFIG_HEALTH_BAR_NAME = string( pev.message );

			SetUse( null );

			InitializeHUD();

			SetThink( ThinkFunction(this.HealthbarThink) );
			pev.nextthink = g_Engine.time + THINK_RATE;

			return;
		}

		g_Game.AlertMessage( at_error, "%1: too many health bars\n", self.GetClassname() );
		g_EntityFuncs.Remove( self );
	}

	void ResetHUDInitialized()
	{
		for( int i = 1; i <= g_Engine.maxClients; ++i )
		{
			if( GetTopHealthbar() !is null )
			{
				GetTopHealthbar().m_bHUDInitializedPlayer[ i ] = false;
				GetTopHealthbar().InitializeHUD();
			}

			if( GetBottomHealthbar() !is null )
			{
				GetBottomHealthbar().m_bHUDInitializedPlayer[ i ] = false;
				GetBottomHealthbar().InitializeHUD();
			}
		}
	}

	bool IsTopHealthbar()
	{
		if( g_arrehHealthBarEntities[0].IsValid() and g_arrehHealthBarEntities[0].GetEntity() is self )
			return true;

		return false;
	}

	target_healthbar@ GetTopHealthbar()
	{
		if( g_arrehHealthBarEntities[0].IsValid() )
			return cast<target_healthbar@>( CastToScriptClass(g_arrehHealthBarEntities[0].GetEntity()) );

		return null;
	}

	target_healthbar@ GetBottomHealthbar()
	{
		if( g_arrehHealthBarEntities[1].IsValid() )
			return cast<target_healthbar@>( CastToScriptClass(g_arrehHealthBarEntities[1].GetEntity()) );

		return null;
	}

	float GetHealthbarOffset()
	{
		if( g_arrehHealthBarEntities[0].IsValid() and g_arrehHealthBarEntities[1].IsValid() )
		{
			if( g_arrehHealthBarEntities[1].GetEntity() is self )
				return m_flOffset;
		}

		return 0.0;
	}

	void InitializeHUD()
	{
		for( int i = 1; i <= g_Engine.maxClients; ++i )
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);

			if( pPlayer is null or !pPlayer.IsConnected() )
			{
				m_bVisibleToPlayer[i] = false;
				continue;
			}

			if( pev.SpawnFlagBitSet(SPAWNFLAG_HEALTHBAR_PVS_ONLY) )
				m_bVisibleToPlayer[i] = inPVS( pPlayer );
			else
				m_bVisibleToPlayer[i] = true;
		}

		for( int i = 1; i <= g_Engine.maxClients; ++i )
		{
			if( !m_bVisibleToPlayer[i] )
				continue;

			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

			if( pPlayer is null or !pPlayer.IsConnected() )
			{
				m_bVisibleToPlayer[ i ] = false;
				m_bHUDInitializedPlayer[ i ] = false;
				continue;
			}

			if( !m_bHUDInitializedPlayer[i] )
			{
				DrawText( pPlayer );
				DrawBackground( pPlayer );
				DrawHealthbar( pPlayer );

				m_bHUDInitializedPlayer[ i ] = true;
			}
		}
	}

	void DrawText( CBasePlayer@ pPlayer )
	{
		const string name = CONFIG_HEALTH_BAR_NAME;

		CG_DrawHUDString( pPlayer, name );
	}

	void CG_DrawHUDString( CBasePlayer@ pPlayer, const string &in sString )
	{
		g_PlayerFuncs.HudMessage( pPlayer, m_textParms, sString + "\n" );
	}

	void DrawBackground( CBasePlayer@ pPlayer )
	{
		m_hudParamsHealthbarBG_L.channel = IsTopHealthbar() ? HUD_SPRITE_HB_BG_L : HUD_SPRITE_HB_BG_L+4;
		m_hudParamsHealthbarBG_L.y = 0.13 + GetHealthbarOffset();
		g_PlayerFuncs.HudCustomSprite( pPlayer, m_hudParamsHealthbarBG_L );

		m_hudParamsHealthbarBG_R.channel = IsTopHealthbar() ? HUD_SPRITE_HB_BG_R : HUD_SPRITE_HB_BG_R+4;
		m_hudParamsHealthbarBG_R.y = 0.13 + GetHealthbarOffset();
		g_PlayerFuncs.HudCustomSprite( pPlayer, m_hudParamsHealthbarBG_R );
	}

	void UpdateHealthbarValue()
	{
		if( m_flTimeToRemove > 0.0 )
		{
			if( m_flTimeToRemove < g_Engine.time )
				g_EntityFuncs.Remove( self );
		}
		else
		{
			// enemy dead
			if( !m_hTarget.IsValid() or m_hTarget.GetEntity().pev.health <= 0 or m_hTarget.GetEntity().pev.deadflag != DEAD_NO )
			{
				if( m_flDelay > 0.0 )
				{
					m_flTimeToRemove = g_Engine.time + m_flDelay;
					m_iBarValue = 1; //minimum value AKA monster is dead
				}
				else
					g_EntityFuncs.Remove( self );
	
				return;
			}

			float health_remaining = m_hTarget.GetEntity().pev.health / m_hTarget.GetEntity().pev.max_health;
			m_iBarValue = int( health_remaining * m_flWidthMax );
		}
	}

	bool inPVS( CBasePlayer@ pPlayer )
	{
		if( m_hTarget.IsValid() )
		{
			edict_t@ pEntity = g_EngineFuncs.EntitiesInPVS( m_hTarget.GetEntity().edict() );
			while( pEntity !is null )
			{
				CBaseEntity@ pNext = g_EntityFuncs.Instance( pEntity );
				if( pNext !is null )
				{
					@pEntity = @pNext.pev.chain;

					if( pNext is pPlayer )
						return true;
				}
			}
		}

		return false;
	}

	void DrawHealthbar( CBasePlayer@ pPlayer )
	{
		//"moving" healthbar
		int iHalfWidth = int( m_flWidthMax / 2 );

		m_hudParamsHealthbar_L.channel = IsTopHealthbar() ? HUD_SPRITE_HB_L : HUD_SPRITE_HB_L+4;
		m_hudParamsHealthbar_L.y = 0.13 + GetHealthbarOffset();
		m_hudParamsHealthbar_L.width = (m_iBarValue >= iHalfWidth) ? iHalfWidth : m_iBarValue; //hudParamsHealthbar_L.width = m_iBarValue > (m_flWidthMax/2) ? 0 : m_iBarValue;
		g_PlayerFuncs.HudCustomSprite( pPlayer, m_hudParamsHealthbar_L );

		if( m_iBarValue > (m_flWidthMax/2) )
		{
			m_hudParamsHealthbar_R.channel = IsTopHealthbar() ? HUD_SPRITE_HB_R : HUD_SPRITE_HB_R+4;
			m_hudParamsHealthbar_R.y = 0.13 + GetHealthbarOffset();
			m_hudParamsHealthbar_R.width = (m_iBarValue > iHalfWidth) ? m_iBarValue - iHalfWidth : 0; //hudParamsHealthbar_R.width = m_iBarValue - int( m_flWidthMax / 2 );
			g_PlayerFuncs.HudCustomSprite( pPlayer, m_hudParamsHealthbar_R );
		}
		else
			g_PlayerFuncs.HudToggleElement( pPlayer, IsTopHealthbar() ? HUD_SPRITE_HB_R : HUD_SPRITE_HB_R+4, false );
	}

	void DrawHUD()
	{
		bool bBarChanged = (m_iBarValue != m_iLastBarValue);

		if( bBarChanged )
			m_iLastBarValue = m_iBarValue;

		// PVS checks less frequently
		if( m_flNextPVSCheck <= g_Engine.time )
		{
			m_flNextPVSCheck = g_Engine.time + 0.5;

			for( int i = 1; i <= g_Engine.maxClients; ++i )
			{
				CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);

				if( pPlayer is null or !pPlayer.IsConnected() )
				{
					m_bVisibleToPlayer[i] = false;
					continue;
				}

				if( pev.SpawnFlagBitSet(SPAWNFLAG_HEALTHBAR_PVS_ONLY) )
					m_bVisibleToPlayer[i] = inPVS( pPlayer );
				else
					m_bVisibleToPlayer[i] = true;
			}
		}

		for( int i = 1; i <= g_Engine.maxClients; ++i )
		{
			if( !m_bVisibleToPlayer[i] )
				continue;

			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

			if( pPlayer is null or !pPlayer.IsConnected() )
			{
				m_bVisibleToPlayer[ i ] = false;
				m_bHUDInitializedPlayer[ i ] = false;
				continue;
			}

			if( !m_bHUDInitializedPlayer[i] )
			{
				DrawText( pPlayer );
				DrawBackground( pPlayer );
				DrawHealthbar( pPlayer );

				m_bHUDInitializedPlayer[ i ] = true;
			}
			else if( bBarChanged )
				DrawHealthbar(pPlayer);
		}
	}

	void RemoveHUD()
	{
		int iOffset = IsTopHealthbar() ? 0 : 4;

		for( int i = 1; i <= g_Engine.maxClients; ++i )
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

			if( pPlayer !is null and pPlayer.IsConnected() )
			{
				g_PlayerFuncs.HudToggleElement( pPlayer, HUD_SPRITE_HB_BG_L + iOffset, false );
				g_PlayerFuncs.HudToggleElement( pPlayer, HUD_SPRITE_HB_BG_R + iOffset, false );
				g_PlayerFuncs.HudToggleElement( pPlayer, HUD_SPRITE_HB_L + iOffset, false );
				g_PlayerFuncs.HudToggleElement( pPlayer, HUD_SPRITE_HB_R + iOffset, false );

				//HudToggleElement doesn't work for this blyat
				if( IsTopHealthbar() and GetBottomHealthbar() is null )
				{
					m_textParms.holdTime = 0.01;
					g_PlayerFuncs.HudMessage( pPlayer, m_textParms, "" );
				}

				//g_Game.AlertMessage( at_notice, "target_healthbar %1 RemoveHUD for player %2\n", pev.targetname, pPlayer.pev.netname );
			}
		}
	}

	void UpdateOnRemove()
	{
		ResetHUDInitialized();
		RemoveHUD();

		//update their position in the hierarchy
		if( g_arrehHealthBarEntities[0].IsValid() and g_arrehHealthBarEntities[1].IsValid() )
		{
			if( g_arrehHealthBarEntities[0].GetEntity() is self )
			{
				g_arrehHealthBarEntities[0] = g_arrehHealthBarEntities[1];
				g_arrehHealthBarEntities[1] = null;
			}
		}
		else if( g_arrehHealthBarEntities[0].GetEntity() is self )
			g_arrehHealthBarEntities[0] = null;

		//Call this again because reasons OLOLOLOLOLOLOLOLOLOOLLL I know exactly what I'm doing
		ResetHUDInitialized();
		RemoveHUD();

		BaseClass.UpdateOnRemove();
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "target_healthbar::target_healthbar", "target_healthbar" );
	g_Game.PrecacheOther( "target_healthbar" );
}


} //end of namespace target_healthbar

/* TODO
	Update healthbars in MonsterTakeDamage hook instead ??
*/