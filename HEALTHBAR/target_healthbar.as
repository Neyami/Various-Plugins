/*QUAKED target_healthbar (0 1 0) (-8 -8 -8) (8 8 8) PVS_ONLY PLAYERNAME DISPLAYNAME
* 
* Hook up health bars to monsters.
* "delay" is how long to show the health bar for after death.
* "message" is their name (one name for both healthbars)
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

const int SPAWNFLAG_HEALTHBAR_PVS_ONLY			= 1;
const int SPAWNFLAG_HEALTHBAR_PLAYERNAME		= 2;
const int SPAWNFLAG_HEALTHBAR_DISPLAYNAME	= 4;

const int MAX_HEALTH_BARS			= 2; //2 max, at least for now
const int HUD_TEXT_HEALTHBAR	= 1;
const int HUD_SPRITE_HB_BG_L		= 1;
const int HUD_SPRITE_HB_BG_R		= 2;
const int HUD_SPRITE_HB_L			= 3;
const int HUD_SPRITE_HB_R			= 4;

//these two need to be global
array<EHandle> health_bar_entities( MAX_HEALTH_BARS );
string CONFIG_HEALTH_BAR_NAME = "";

class target_healthbar : ScriptBaseEntity
{
	private EHandle m_hTarget;
	private float m_flDelay;
	private int m_iBarValue;
	private float m_flTimeToRemove;
	private float m_flOffset = 0.035; //distance between the two healthbars
	private float m_flWidthMax = 944; //472 per bar
	private string m_sHealthbarBGLeft = "quake2/healthbar_bg-left.spr";
	private string m_sHealthbarBGRight = "quake2/healthbar_bg-right.spr";
	private string m_sHealthbarLeft = "quake2/healthbar-left.spr";
	private string m_sHealthbarRight = "quake2/healthbar-right.spr";

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

		if( !HasFlags(pev.spawnflags, SPAWNFLAG_HEALTHBAR_PLAYERNAME|SPAWNFLAG_HEALTHBAR_DISPLAYNAME) and string(pev.message).IsEmpty() )
		{
			g_Game.AlertMessage( at_error, "%1: missing message\n", self.GetClassname() );
			g_EntityFuncs.Remove( self );
			return;
		}

		Precache();

		m_iBarValue = 0; //max

		SetUse( UseFunction(this.use_target_healthbar) );
		SetThink( ThinkFunction(this.check_target_healthbar) );
		pev.nextthink = g_Engine.time + 0.025;
	}

	void Precache()
	{
		g_Game.PrecacheModel( "sprites/" + m_sHealthbarBGLeft );
		g_Game.PrecacheModel( "sprites/" + m_sHealthbarBGRight );
		g_Game.PrecacheModel( "sprites/" + m_sHealthbarLeft );
		g_Game.PrecacheModel( "sprites/" + m_sHealthbarRight );
	}

	void check_target_healthbar()
	{
		CBaseEntity@ target = g_EntityFuncs.FindEntityByTargetname( null, string(pev.target) );
		if( target is null /*or !target.pev.FlagBitSet(FL_MONSTER)*/ )
		{
			if( target !is null )
				g_Game.AlertMessage( at_error, "%1: target %2 does not appear to be a monster\n", self.GetClassname(), target.GetClassname() );

			g_EntityFuncs.Remove( self );
			return;
		}

		// just for sanity check
		//pev.health = target->spawn_count;
	}

	void HealthbarThink()
	{
		UpdateHealthbarValue();

		for( int i = 1; i <= g_Engine.maxClients; ++i )
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

			if( pPlayer !is null and pPlayer.IsConnected() )
			{
				if( HasFlags(pev.spawnflags, SPAWNFLAG_HEALTHBAR_PVS_ONLY) and !inPVS(pPlayer) )
					continue;

				DrawText( pPlayer );
				DrawHealthbar( pPlayer );
			}
		}

		pev.nextthink = g_Engine.time + 0.025;
	}

	void use_target_healthbar( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		CBaseEntity@ target = g_EntityFuncs.FindEntityByTargetname( null, string(pev.target) );

		if( target is null /*or ent->health != target->spawn_count*/ )
		{
			if( target !is null )
				g_Game.AlertMessage( at_error, "%1: target %2 changed from what it used to be\n", self.GetClassname(), target.GetClassname() );
			else
				g_Game.AlertMessage( at_error, "%1: no target\n", self.GetClassname() );

			g_EntityFuncs.Remove( self );
			return;
		}

		for( int i = 0; i < MAX_HEALTH_BARS; i++ )
		{
			if( health_bar_entities[i].IsValid() )
				continue;

			m_hTarget = EHandle( target );
			health_bar_entities[i] = EHandle( self );

			if( target.pev.FlagBitSet(FL_CLIENT) and HasFlags(pev.spawnflags, SPAWNFLAG_HEALTHBAR_PLAYERNAME) )
				CONFIG_HEALTH_BAR_NAME = string( target.pev.netname );
			else if( target.pev.FlagBitSet(FL_MONSTER) and HasFlags(pev.spawnflags, SPAWNFLAG_HEALTHBAR_DISPLAYNAME) )
			{
				CBaseMonster@ pMonster = target.MyMonsterPointer();
				if( pMonster !is null )
					CONFIG_HEALTH_BAR_NAME = string( pMonster.m_FormattedName );
			}
			else
				CONFIG_HEALTH_BAR_NAME = string( pev.message );

			SetUse( null );

			SetThink( ThinkFunction(this.HealthbarThink) );
			pev.nextthink = g_Engine.time + 0.025;

			return;
		}

		g_Game.AlertMessage( at_error, "%1: too many health bars\n", self.GetClassname() );
		g_EntityFuncs.Remove( self );
	}

	bool ShouldDrawText()
	{
		if( health_bar_entities[0].IsValid() and health_bar_entities[1].IsValid() )
		{
			if( health_bar_entities[1].GetEntity() is self )
				return true;
		}
		else if( health_bar_entities[0].IsValid() and health_bar_entities[0].GetEntity() is self )
			return true;

		return false;
	}

	float GetHealthbarOffset()
	{
		if( health_bar_entities[0].IsValid() and health_bar_entities[1].IsValid() )
		{
			if( health_bar_entities[1].GetEntity() is self )
				return m_flOffset;
		}

		return 0.0;
	}

	void DrawText( CBasePlayer@ pPlayer )
	{
		if( !ShouldDrawText() )
			return;

		const string name = CONFIG_HEALTH_BAR_NAME;

		CG_DrawHUDString( pPlayer, name );
	}

	void CG_DrawHUDString( CBasePlayer@ pPlayer, const string &in sString )
	{
		HUDTextParams textParms;
			textParms.fadeinTime = 0.0;
			textParms.fadeoutTime = 0.1;
			textParms.holdTime = 0.02;
			textParms.effect = 0;
			textParms.channel = HUD_TEXT_HEALTHBAR;
			textParms.x = -1.0;
			textParms.y = 0.1;
			textParms.r1 = 0;
			textParms.g1 = 255;
			textParms.b1 = 255;
			textParms.r2 = 0;
			textParms.g2 = 0;
			textParms.b2 = 255;

		g_PlayerFuncs.HudMessage( pPlayer, textParms, sString + "\n" );
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
					m_iBarValue = 1;
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
		//static background
		HUDSpriteParams hudParamsHealthbarBG_L;
			hudParamsHealthbarBG_L.fadeinTime = 0.0;
			hudParamsHealthbarBG_L.fadeoutTime = 0.1;
			hudParamsHealthbarBG_L.holdTime = 0.02;
			hudParamsHealthbarBG_L.effect = 0;
			hudParamsHealthbarBG_L.channel = ShouldDrawText() ? HUD_SPRITE_HB_BG_L : HUD_SPRITE_HB_BG_L+4;
			hudParamsHealthbarBG_L.flags = HUD_SPR_MASKED;
			hudParamsHealthbarBG_L.spritename = m_sHealthbarBGLeft;
			hudParamsHealthbarBG_L.x = 0.25;
			hudParamsHealthbarBG_L.y = 0.13 + GetHealthbarOffset();
			hudParamsHealthbarBG_L.color1 = RGBA_WHITE;

		hudParamsHealthbarBG_L.frame = 0;
		g_PlayerFuncs.HudCustomSprite( pPlayer, hudParamsHealthbarBG_L );

		HUDSpriteParams hudParamsHealthbarBG_R;
			hudParamsHealthbarBG_R.fadeinTime = 0.0;
			hudParamsHealthbarBG_R.fadeoutTime = 0.1;
			hudParamsHealthbarBG_R.holdTime = 0.02;
			hudParamsHealthbarBG_R.effect = 0;
			hudParamsHealthbarBG_R.channel = ShouldDrawText() ? HUD_SPRITE_HB_BG_R : HUD_SPRITE_HB_BG_R+4;
			hudParamsHealthbarBG_R.flags = HUD_SPR_MASKED;
			hudParamsHealthbarBG_R.spritename = m_sHealthbarBGRight;
			hudParamsHealthbarBG_R.x = 0.5;
			hudParamsHealthbarBG_R.y = 0.13 + GetHealthbarOffset();
			hudParamsHealthbarBG_R.color1 = RGBA_WHITE;

		hudParamsHealthbarBG_R.frame = 0;
		g_PlayerFuncs.HudCustomSprite( pPlayer, hudParamsHealthbarBG_R );

		if( m_iBarValue == 1 )
			return;

		//"moving" healthbar
		HUDSpriteParams hudParamsHealthbar_L;
			hudParamsHealthbar_L.fadeinTime = 0.0;
			hudParamsHealthbar_L.fadeoutTime = 0.1;
			hudParamsHealthbar_L.holdTime = 0.02;
			hudParamsHealthbar_L.effect = 0;
			hudParamsHealthbar_L.channel = ShouldDrawText() ? HUD_SPRITE_HB_L : HUD_SPRITE_HB_L+4;
			hudParamsHealthbar_L.flags = HUD_SPR_MASKED;
			hudParamsHealthbar_L.spritename = m_sHealthbarLeft;
			hudParamsHealthbar_L.x = 0.25;
			hudParamsHealthbar_L.y = 0.13 + GetHealthbarOffset();
			hudParamsHealthbar_L.width = m_iBarValue > (m_flWidthMax/2) ? 0 : m_iBarValue;
			hudParamsHealthbar_L.color1 = RGBA_WHITE;

		hudParamsHealthbar_L.frame = 0;
		g_PlayerFuncs.HudCustomSprite( pPlayer, hudParamsHealthbar_L );

		if( m_iBarValue > (m_flWidthMax/2) )
		{
			HUDSpriteParams hudParamsHealthbar_R;
				hudParamsHealthbar_R.fadeinTime = 0.0;
				hudParamsHealthbar_R.fadeoutTime = 0.1;
				hudParamsHealthbar_R.holdTime = 0.02;
				hudParamsHealthbar_R.effect = 0;
				hudParamsHealthbar_R.channel = ShouldDrawText() ? HUD_SPRITE_HB_R : HUD_SPRITE_HB_R+4;
				hudParamsHealthbar_R.flags = HUD_SPR_MASKED;
				hudParamsHealthbar_R.spritename = m_sHealthbarRight;
				hudParamsHealthbar_R.x = 0.5;
				hudParamsHealthbar_R.y = 0.13 + GetHealthbarOffset();
				hudParamsHealthbar_R.width = m_iBarValue - (m_flWidthMax/2);
				hudParamsHealthbar_R.color1 = RGBA_WHITE;

			hudParamsHealthbar_R.frame = 0;
			g_PlayerFuncs.HudCustomSprite( pPlayer, hudParamsHealthbar_R );
		}
		else
			g_PlayerFuncs.HudToggleElement( pPlayer, ShouldDrawText() ? HUD_SPRITE_HB_R : HUD_SPRITE_HB_R+4, false );
	}

	void UpdateOnRemove()
	{
		//update their position in the hierarchy
		if( health_bar_entities[0].IsValid() and health_bar_entities[1].IsValid() )
		{
			if( health_bar_entities[0].GetEntity() is self )
			{
				health_bar_entities[0] = health_bar_entities[1];
				health_bar_entities[1] = null;
			}
		}
		else if( health_bar_entities[0].GetEntity() is self )
			health_bar_entities[0] = null;

		BaseClass.UpdateOnRemove();
	}

	bool HasFlags( int iFlagVariable, int iFlags )
	{
		return (iFlagVariable & iFlags) != 0;
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "target_healthbar::target_healthbar", "target_healthbar" );
	g_Game.PrecacheOther( "target_healthbar" );
}

} //end of namespace target_healthbar