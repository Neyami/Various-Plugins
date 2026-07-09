/*
	Author: Nero

	From Half-Life 2 item_healthkit.cpp
							func_recharge.cpp
*/

namespace hl2
{

mixin class CBaseChargerHL2
{
	float		m_flNextCharge; 
	int		m_iReactivate ; // DeathMatch Delay until reactvated
	int		m_iJuice;
	int		m_iOn;			// 0 = off, 1 = startup, 2 = going
	float  	m_flSoundTime;
	
	int		m_nState;
	int		m_iCaps;

	//CBaseAnimating
	float m_flPrevAnimTime;

	bool SequenceLoops()
	{
		return false; //self.m_fSequenceLoops
	}

	void ResetSequence( int nSequence )
	{
		if( !SequenceLoops() )
			SetCycle( 0 );

		// Tracker 17868:  If the sequence number didn't actually change, but you call resetsequence info, it changes
		//  the newsequenceparity bit which causes the client to call m_flCycle.Reset() which causes a very slight 
		//  discontinuity in looping animations as they reset around to cycle 0.0.  This was causing the parentattached
		//  helmet on barney to hitch every time barney's idle cycled back around to its start.
		bool changed = nSequence != GetSequence() ? true : false;

		SetSequence( nSequence );
		if( changed or !SequenceLoops() )
			ResetSequenceInfo();
	}

	void ResetSequenceInfo()
	{
		if( GetSequence() == -1 )
		{
			// This shouldn't happen.  Setting m_nSequence blindly is a horrible coding practice.
			SetSequence( 0 );
		}

		// m_flAnimTime = gpGlobals->time;
		pev.framerate = 1.0; //m_flPlaybackRate
		//m_bSequenceFinished = false;
		//m_flLastEventCheck = 0;
	}

	void SetSequence( int nSequence )
	{
		if( pev.sequence != nSequence )
			pev.sequence = nSequence;
	}

	int GetSequence()
	{
		return pev.sequence;
	}

	float GetCycle() const //inline
	{
		return pev.frame; //m_flCycle
	}

	void SetCycle( float flCycle ) //inline
	{
		pev.frame = Math.clamp( 0.0, 255.0, flCycle * 255.0 );
	}

	float GetAnimTimeInterval() const
	{
		float flInterval;
		if( pev.animtime < g_Engine.time ) //m_flAnimTime
		{
			// estimate what it'll be this frame
			flInterval = Math.clamp( 0.0, 0.2, g_Engine.time - pev.animtime ); //MAX_ANIMTIME_INTERVAL, m_flAnimTime
		}
		else
		{
			// report actual
			flInterval = Math.clamp( 0.0, 0.2, pev.animtime - m_flPrevAnimTime ); //MAX_ANIMTIME_INTERVAL, m_flAnimTime
		}

		return flInterval;
	}
}

namespace item_healthcharger
{

const string HEALTH_CHARGER_MODEL_NAME		= "models/hl2/props_combine/health_charger001.mdl";
const float CHARGE_RATE									= 0.25;
const float CHARGES_PER_SECOND						= 1.0 / CHARGE_RATE;
const float CALLS_PER_SECOND							= 7.0 * CHARGES_PER_SECOND;

const float CHARGER_RECHARGETIME					= 30.0; //30 //g_pGameRules.FlHealthChargerRechargeTime()

const int SK_HEALTHCHARGER							= 50;
//ConVar	sk_healthcharger( "sk_healthcharger","0" );		

class CNewWallHealth : ScriptBaseEntity, CBaseChargerHL2
{
	float m_flNextCharge; 
	int		m_iReactivate ; // DeathMatch Delay until reactvated
	int		m_iJuice;
	int		m_iOn;			// 0 = off, 1 = startup, 2 = going
	float   m_flSoundTime;

	int		m_nState;
	int		m_iCaps;

	string		m_sOnPlayerUse; //string_t ??

	float m_flJuice;

    int GetJuice() const { return m_iJuice; }

	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if( szKey == "dmdelay" )
		{
			m_iReactivate = atoi( szValue );
			return true;
		}
		else if( szKey == "onplayeruse" )
		{
			m_sOnPlayerUse = szValue;
			return true;
		}

		return BaseClass.KeyValue( szKey, szValue );
	}

	void Spawn()
	{
		Precache();

		pev.movetype = MOVETYPE_NONE;
		pev.solid = SOLID_BBOX;

		g_EntityFuncs.SetModel( self, HEALTH_CHARGER_MODEL_NAME );

		g_EntityFuncs.SetOrigin( self, pev.origin );
		g_EntityFuncs.SetSize( self.pev, Vector(-0.281, -10.153, -20.244), Vector(7.733, 11.834, 19.951) );

		//this cocks up the "progress" bar
		//ResetSequence( 0 ); //ResetSequence( LookupSequence( "idle" ) );

		m_iJuice = SK_HEALTHCHARGER;

		m_nState = 0;

		m_iReactivate = 0;
		m_iCaps	= FCAP_CONTINUOUS_USE;

		m_flJuice = m_iJuice;
		SetCycle( 1.0 - (m_flJuice /  SK_HEALTHCHARGER) );
	}

	void Precache()
	{
		g_Game.PrecacheModel( HEALTH_CHARGER_MODEL_NAME );

		g_SoundSystem.PrecacheSound( "items/medshotno1.wav" );
		g_SoundSystem.PrecacheSound( "items/medshot4.wav" );
		g_SoundSystem.PrecacheSound( "items/medcharge4.wav" );
		g_SoundSystem.PrecacheSound( "items/medshot4.wav" );
	}

	int ObjectCaps() { return BaseClass.ObjectCaps() | m_iCaps; }

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float value )
	{ 
		// Make sure that we have a caller
		if( pActivator is null )
			return;

		// if it's not a player, ignore
		if( !pActivator.IsPlayer() )
			return;

		CBasePlayer@ pPlayer = cast<CBasePlayer@>( pActivator );

		// Reset to a state of continuous use.
		m_iCaps = FCAP_CONTINUOUS_USE;

		if( m_iOn != 0 )
		{
			float flCharges = CHARGES_PER_SECOND;
			float flCalls = CALLS_PER_SECOND;

			m_flJuice -= flCharges / flCalls;
			StudioFrameAdvance();
		}

		// if there is no juice left, turn it off
		if( m_iJuice <= 0 )
		{
			ResetSequence( 1 ); //ResetSequence( LookupSequence( "emptyclick" ) );
			m_nState = 1;			
			Off();
		}

		// if there is no juice left, make the deny noise.
		if( m_iJuice <= 0 )
		{
			if( m_flSoundTime <= g_Engine.time )
			{
				m_flSoundTime = g_Engine.time + 0.62;
				g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "items/medshotno1.wav", 0.7, ATTN_NORM ); //SNDLVL_75dB //EmitSound( "WallHealth.Deny" );
			}

			return;
		}

		if( pActivator.pev.health >= pActivator.pev.max_health )
		{
			if( pPlayer !is null )
				pPlayer.m_afButtonPressed &= ~IN_USE;

			// Make the user re-use me to get started drawing health.
			m_iCaps = FCAP_IMPULSE_USE;

			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "items/medshotno1.wav", 0.7, ATTN_NORM ); //SNDLVL_75dB //EmitSound( "WallHealth.Deny" );
			return;
		}

		pev.nextthink = g_Engine.time + CHARGE_RATE;
		SetThink( ThinkFunction(this.Off) );

		// Time to recharge yet?
		if( m_flNextCharge >= g_Engine.time )
			return;

		// Play the on sound or the looping charging sound
		if( m_iOn == 0 )
		{
			m_iOn++;
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "items/medshot4.wav", 0.7, ATTN_NORM ); //SNDLVL_75dB //EmitSound( "WallHealth.Start" );
			m_flSoundTime = 0.56 + g_Engine.time;

			if( !m_sOnPlayerUse.IsEmpty() )
				g_EntityFuncs.FireTargets( m_sOnPlayerUse, pActivator, self, USE_TOGGLE );
		}

		if( m_iOn == 1 and m_flSoundTime <= g_Engine.time )
		{
			m_iOn++;
			g_SoundSystem.EmitSound( self.edict(), CHAN_BODY, "items/medcharge4.wav", 0.7, ATTN_NORM ); //CHAN_STATIC, SNDLVL_75dB //EmitSound( filter, entindex(), "WallHealth.LoopingContinueCharge" );
		}

		// charge the player
		if( pActivator.TakeHealth(1, DMG_GENERIC) )
			m_iJuice--;

		// govern the rate of charge
		m_flNextCharge = g_Engine.time + 0.1;
	}

	void StudioFrameAdvance()
	{
		pev.framerate = 0; //m_flPlaybackRate

		float flMaxJuice = SK_HEALTHCHARGER;

		SetCycle( 1.0 - float(m_iJuice / flMaxJuice) );
	//	Msg( "Cycle: %1 - Juice: %2 - m_flJuice :%3 - Interval: %4\n", GetCycle(), m_iJuice, m_flJuice, GetAnimTimeInterval() );

		if( m_flPrevAnimTime == 0 )
			m_flPrevAnimTime = g_Engine.time;

		// Latch prev
		m_flPrevAnimTime = pev.animtime; //m_flAnimTime
		// Set current
		pev.animtime = g_Engine.time; //m_flAnimTime
	}

	void Recharge()
	{
		g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "items/medshot4.wav", 0.7, ATTN_NORM ); //SNDLVL_75dB //EmitSound( "WallHealth.Recharge" );
		m_flJuice = m_iJuice = SK_HEALTHCHARGER;
		m_nState = 0;

		ResetSequence( 0 ); //ResetSequence( LookupSequence( "idle" ) );
		StudioFrameAdvance();

		m_iReactivate = 0;

		SetThink( null );
	}

	void Off()
	{
		// Stop looping sound.
		if( m_iOn > 1 )
			g_SoundSystem.StopSound( self.edict(), CHAN_BODY, "items/medcharge4.wav" ); //StopSound( "WallHealth.LoopingContinueCharge" );

		if( m_nState == 1 )
			SetCycle( 1.0 );

		m_iOn = 0;
		m_flJuice = m_iJuice;

		if( m_iReactivate == 0 )
		{
			if( m_iJuice == 0 and CHARGER_RECHARGETIME > 0 )
			{
				m_iReactivate = CHARGER_RECHARGETIME;
				pev.nextthink = g_Engine.time + m_iReactivate;
				SetThink( ThinkFunction(this.Recharge) );
			}
			else
				SetThink( null );
		}
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "hl2::item_healthcharger::CNewWallHealth", "item_healthcharger" );
	g_Game.PrecacheOther( "item_healthcharger" );
}

} //end of namespace item_healthcharger

namespace item_suitcharger
{

const string HEALTH_CHARGER_MODEL_NAME			= "models/hl2/props_combine/suit_charger001.mdl";
const float CHARGE_RATE										= 0.25;
const float CHARGES_PER_SECOND							= 1 / CHARGE_RATE;
const float CITADEL_CHARGES_PER_SECOND			= 10 / CHARGE_RATE;
const float CALLS_PER_SECOND								= 7.0 * CHARGES_PER_SECOND;

const float CHARGER_RECHARGETIME						= 30.0; //30 //g_pGameRules.FlHEVChargerRechargeTime()

const int SK_SUITCHARGER									= 75;
const int SK_SUITCHARGER_CITADEL						= 500;
const int SK_SUITCHARGER_CITADEL_MAXARMOR	= 200;

//static ConVar	sk_suitcharger( "sk_suitcharger","75" );
//static ConVar	sk_suitcharger_citadel( "sk_suitcharger_citadel","500" );
//static ConVar	sk_suitcharger_citadel_maxarmor( "sk_suitcharger_citadel_maxarmor","200" );

const int SF_CITADEL_RECHARGER							= 8192; //0x2000;
const int SF_KLEINER_RECHARGER							= 16384; //0x4000; // Gives only 25 health

class CNewRecharge : ScriptBaseEntity, CBaseChargerHL2
{
	int m_iMaxJuice;
	
	string m_sOnHalfEmpty;
	string m_sOnEmpty;
	string m_sOnFull;
	string m_sOnPlayerUse;

	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if( szKey == "dmdelay" )
		{
			m_iReactivate = atoi( szValue );
			return true;
		}
		else if( szKey == "onhalfempty" )
		{
			m_sOnHalfEmpty = szValue;
			return true;
		}
		else if( szKey == "onempty" )
		{
			m_sOnEmpty = szValue;
			return true;
		}
		else if( szKey == "onfull" )
		{
			m_sOnFull = szValue;
			return true;
		}
		else if( szKey == "onplayeruse" )
		{
			m_sOnPlayerUse = szValue;
			return true;
		}
		else
			return BaseClass.KeyValue( szKey, szValue );

		return true;
	}
/*
    void AcceptInput( inputdata_t inputdata )
    {
        BaseAcceptInput( inputdata );

		if( GetInput(inputdata.input, "Recharge") ) InputRecharge( inputdata );
		else if( GetInput(inputdata.input, "SetCharge") ) InputSetCharge( inputdata );
    }
*/

	void Spawn()
	{
		Precache();

		pev.movetype = MOVETYPE_NONE;
		pev.solid = SOLID_BBOX; //SOLID_VPHYSICS
		//CreateVPhysics();

		g_EntityFuncs.SetModel( self, HEALTH_CHARGER_MODEL_NAME );
		//AddEffects( EF_NOSHADOW );

		g_EntityFuncs.SetOrigin( self, pev.origin );
		g_EntityFuncs.SetSize( self.pev, Vector(-0.247, -10.566, -24.341), Vector(8.316, 10.566, 24.087) );

		ResetSequence( 0 ); //ResetSequence( LookupSequence( "idle" ) );

		SetInitialCharge();

		UpdateJuice( MaxJuice() );

		m_nState = 0;		
		m_iCaps	= FCAP_CONTINUOUS_USE;

		//CreateVPhysics();

		m_iReactivate = 0;

		pev.framerate = 0; //the juice indicator won't spawn in the correct position without this blyat
		SetCycle( 1.0 - float(m_iJuice / MaxJuice()) );
	}

	void Precache()
	{
		g_Game.PrecacheModel( HEALTH_CHARGER_MODEL_NAME );

		//these should already be precached by default
		g_SoundSystem.PrecacheSound( "items/suitchargeno1.wav" );
		g_SoundSystem.PrecacheSound( "items/suitchargeok1.wav" );
		g_SoundSystem.PrecacheSound( "items/suitcharge1.wav" );
	}

	int ObjectCaps() { return (BaseClass.ObjectCaps() | m_iCaps ); }

	/*void InputRecharge( inputdata_t &in inputdata )
	{
		//g_Game.AlertMessage( at_notice, "InputRecharge for %1\n", GetDebugName() );
		Recharge();
	}

	void InputSetCharge( inputdata_t &in inputdata )
	{
		ResetSequence( 0 ); //ResetSequence( self.LookupSequence("idle") );

		int iJuice = atoi( inputdata.value );

		m_iMaxJuice = m_iJuice = iJuice;
		StudioFrameAdvance();
	}*/

	void SetInitialCharge()
	{
		if( pev.SpawnFlagBitSet(SF_KLEINER_RECHARGER) )
		{
			// The charger in Kleiner's lab.
			m_iMaxJuice =  25.0;
			return;
		}

		if( pev.SpawnFlagBitSet(SF_CITADEL_RECHARGER) )
		{
			m_iMaxJuice =  SK_SUITCHARGER_CITADEL;
			return;
		}

		m_iMaxJuice =  SK_SUITCHARGER;
	}

	void StudioFrameAdvance()
	{
		pev.framerate = 0; //m_flPlaybackRate

		float flMaxJuice = float( MaxJuice() + 0.1 );
		float flNewJuice = 1.0 - float( m_iJuice / flMaxJuice ); //m_flJuice was used but doesn't work properly in sven

		SetCycle( flNewJuice );
	//	g_Game.AlertMessage( at_notice, "Cycle: %1 - Juice: %2 - m_flJuice :%3 - Interval: %4\n", GetCycle(), m_iJuice, m_flJuice, GetAnimTimeInterval() ); //Msg

		if( m_flPrevAnimTime == 0 )
			m_flPrevAnimTime = g_Engine.time;

		// Latch prev
		m_flPrevAnimTime = pev.animtime; //m_flAnimTime
		// Set current
		pev.animtime = g_Engine.time; //m_flAnimTime
	}

	// Max juice for recharger
	int MaxJuice()	const
	{
		return m_iMaxJuice;
	}

	void UpdateJuice( int newJuice )
	{
		int oldJuice = m_iJuice;
		bool reduced = newJuice < oldJuice;

		// Update internal state first so output callbacks
		// see the new value and can't overwrite it later.
		m_iJuice = newJuice;

		//g_Game.AlertMessage( at_notice, "UpdateJuice: old=%1 new=%2\n", oldJuice, newJuice);

		if( reduced )
		{
			// Fire 1/2 way output and/or empty output
			int oneHalfJuice = int( MaxJuice() * 0.5 );

			if( newJuice <= oneHalfJuice and oldJuice > oneHalfJuice )
			{
				//g_Game.AlertMessage( at_notice, "Firing OnHalfEmpty!\n" );
				if( !m_sOnHalfEmpty.IsEmpty() )
					g_EntityFuncs.FireTargets( m_sOnHalfEmpty, self, self, USE_TOGGLE );
			}

			if( newJuice <= 0 )
			{
				//g_Game.AlertMessage(at_console, "Firing OnEmpty\n");
				if( !m_sOnEmpty.IsEmpty() )
					g_EntityFuncs.FireTargets( m_sOnEmpty, self, self, USE_TOGGLE );
			}
		}
		else if( newJuice != oldJuice and newJuice == MaxJuice() )
		{
			//g_Game.AlertMessage( at_notice, "Firing OnFull!\n" );
			if( !m_sOnFull.IsEmpty() )
				g_EntityFuncs.FireTargets( m_sOnFull, self, self, USE_TOGGLE );
		}
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float value )
	{
		// if it's not a player, ignore
		if( pActivator is null or !pActivator.IsPlayer() )
			return;

		CBasePlayer@ pPlayer = cast<CBasePlayer@>( pActivator );

		// Reset to a state of continuous use.
		m_iCaps = FCAP_CONTINUOUS_USE;

		if( m_iOn != 0 )
		{
			float flCharges = CHARGES_PER_SECOND;
			float flCalls = CALLS_PER_SECOND;

			if( pev.SpawnFlagBitSet(SF_CITADEL_RECHARGER) )
				 flCharges = CITADEL_CHARGES_PER_SECOND;

			StudioFrameAdvance();
		}

		// Only usable if you have the HEV suit on
		if( !pPlayer.HasSuit() ) //IsSuitEquipped
		{
			if( m_flSoundTime <= g_Engine.time )
			{
				m_flSoundTime = g_Engine.time + 0.62;
				g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "items/suitchargeno1.wav", 0.75, ATTN_NORM ); //SNDLVL_75dB //EmitSound( "SuitRecharge.Deny" );
			}

			return;
		}

		// if there is no juice left, turn it off
		if( m_iJuice <= 0 )
		{
			// Start our deny animation over again
			ResetSequence( 1 ); //ResetSequence( LookupSequence("emptyclick") );

			m_nState = 1;

			// Shut off
			Off();

			// Play a deny sound
			if( m_flSoundTime <= g_Engine.time )
			{
				m_flSoundTime = g_Engine.time + 0.62;
				g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "items/suitchargeno1.wav", 0.75, ATTN_NORM ); //SNDLVL_75dB //EmitSound( "SuitRecharge.Deny" );
			}

			return;
		}

		// Get our maximum armor value
		int nMaxArmor = int( pActivator.pev.armortype ); //100;
		if( pev.SpawnFlagBitSet(SF_CITADEL_RECHARGER) )
			nMaxArmor = SK_SUITCHARGER_CITADEL_MAXARMOR;

		int nIncrementArmor = 1;

		// The citadel charger gives more per charge and also gives health
		if( pev.SpawnFlagBitSet(SF_CITADEL_RECHARGER) )
		{
			nIncrementArmor = 10;

	/*#ifdef HL2MP
			nIncrementArmor = 2;
	#endif*/

			// Also give health for the citadel version.
			if( pActivator.pev.health < pActivator.pev.max_health and m_flNextCharge < g_Engine.time )
				pActivator.TakeHealth( 5, DMG_GENERIC );
		}

		// If we're over our limit, debounce our keys
		if( pPlayer.pev.armorvalue >= nMaxArmor )
		{
			// Citadel charger must also be at max health
			if( !pev.SpawnFlagBitSet(SF_CITADEL_RECHARGER) or (pev.SpawnFlagBitSet(SF_CITADEL_RECHARGER) and pActivator.pev.health >= pActivator.pev.max_health) )
			{
				// Make the user re-use me to get started drawing health.
				pPlayer.m_afButtonPressed &= ~IN_USE;
				m_iCaps = FCAP_IMPULSE_USE;

				g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "items/suitchargeno1.wav", 0.75, ATTN_NORM ); //SNDLVL_75dB //EmitSound( "SuitRecharge.Deny" );
				return;
			}
		}

		// This is bumped out if used within the time period
		pev.nextthink = g_Engine.time + CHARGE_RATE;
		SetThink( ThinkFunction(this.Off) );

		// Time to recharge yet?
		if( m_flNextCharge >= g_Engine.time )
			return;

		// Play the on sound or the looping charging sound
		if( m_iOn == 0 )
		{
			m_iOn++;
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "items/suitchargeok1.wav", 0.75, ATTN_NORM ); //SNDLVL_75dB //EmitSound( "SuitRecharge.Start" );
			m_flSoundTime = 0.56 + g_Engine.time;

			if( !m_sOnPlayerUse.IsEmpty() )
				g_EntityFuncs.FireTargets( m_sOnPlayerUse, pActivator, self, USE_TOGGLE );
		}

		if( m_iOn == 1 and m_flSoundTime <= g_Engine.time )
		{
			m_iOn++;
			g_SoundSystem.EmitSound( self.edict(), CHAN_BODY, "items/suitcharge1.wav", 0.75, ATTN_NORM ); //CHAN_STATIC, SNDLVL_75dB //EmitSound( filter, entindex(), "SuitRecharge.ChargingLoop" );
		}

		// Give armor if we need it
		if( pPlayer.pev.armorvalue < nMaxArmor )
		{
			UpdateJuice( m_iJuice - nIncrementArmor );
			IncrementArmorValue( pPlayer, nIncrementArmor, nMaxArmor );
		}

		// govern the rate of charge
		m_flNextCharge = g_Engine.time + 0.1;
	}

	void IncrementArmorValue( CBasePlayer@ pPlayer, int nCount, int nMaxValue ) //CBasePlayer::
	{ 
		pPlayer.pev.armorvalue += nCount;
		if( nMaxValue > 0 )
		{
			if( pPlayer.pev.armorvalue > nMaxValue )
				pPlayer.pev.armorvalue = nMaxValue;
		}
	}

	void Recharge()
	{
		//g_Game.AlertMessage( at_notice, "Recharge called\n" );

		g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "items/suitchargeok1.wav", 0.75, ATTN_NORM ); //SNDLVL_75dB //EmitSound( "SuitRecharge.Start" );
		ResetSequence( 0 ); //ResetSequence( LookupSequence("idle") );

		UpdateJuice( MaxJuice() );

		m_nState = 0;
		m_iReactivate = 0;
		StudioFrameAdvance();

		SetThink( ThinkFunction(this.SUB_DoNothing) );
	}

	void Off()
	{
		// Stop looping sound.
		if( m_iOn > 1 )
			g_SoundSystem.StopSound( self.edict(), CHAN_BODY, "items/suitcharge1.wav" ); //StopSound( "SuitRecharge.ChargingLoop" );

		if( m_nState == 1 )
			SetCycle( 1.0 );

		m_iOn = 0;

		if( m_iReactivate == 0 )
		{
			if( m_iJuice <= 0 and CHARGER_RECHARGETIME > 0 )
			{
				if( pev.SpawnFlagBitSet(SF_CITADEL_RECHARGER) )
					m_iReactivate = CHARGER_RECHARGETIME * 2;
				else
					m_iReactivate = CHARGER_RECHARGETIME;

				pev.nextthink = g_Engine.time + m_iReactivate;
				SetThink( ThinkFunction(this.Recharge) );
			}
			else
				SetThink( null );
		}
	}

	void SUB_DoNothing()
	{
		self.SUB_DoNothing();
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "hl2::item_suitcharger::CNewRecharge", "item_suitcharger" );
	g_Game.PrecacheOther( "item_suitcharger" );
}

} //end of namespace item_suitcharger

} //namespace hl2 END