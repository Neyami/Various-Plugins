void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nero" );
	g_Module.ScriptInfo.SetContactInfo( "https://discord.gg/0wtJ6aAd7XOGI6vI" );

	g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @nerokick::ClientPutInServer );
	g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, @nerokick::ClientDisconnect );
}

void MapInit()
{
	g_Game.PrecacheModel( nerokick::m_sKickModel );

	g_SoundSystem.PrecacheSound( "bhl/kick.wav" );
	g_SoundSystem.PrecacheSound( "weapons/cbar_hitbod3.wav" );
	g_SoundSystem.PrecacheSound( "zombie/claw_strike1.wav" );

	g_Game.PrecacheGeneric( "sound/bhl/kick.wav" );
}

namespace nerokick
{

CClientCommand kick( "kick", "Brutal Half-Life kick!", @Kick );

const string m_sKickModel = "models/nero/v_kick.mdl";
const float m_flKickDelay = 0.8;
const float m_flKickRange = 64.0;
const float m_flKickDamage = 16.0;
const float m_flKickHitVelocity = 600.0;
const float m_flKickHitZBoost = 64.0;
array<float> m_flNextKick(33);

HookReturnCode ClientPutInServer( CBasePlayer@ pPlayer )
{
	m_flNextKick[pPlayer.entindex()] = 0.0;

	return HOOK_CONTINUE;
}

HookReturnCode ClientDisconnect( CBasePlayer@ pPlayer )
{
	m_flNextKick[pPlayer.entindex()] = 0.0;

	return HOOK_CONTINUE;
}

void Kick( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

	const int id = pPlayer.entindex();
	int iMode = args.ArgC() >= 2 ? atoi( args.Arg(1) ) : 1;

	string sWeaponModel;
	float flDamage = (iMode == 1 ? m_flKickDamage : 0);

	if( pPlayer.IsAlive() )
	{
		if( pPlayer.m_hActiveItem.GetEntity() is null ) return; //can't be used without a weapon for now

		if( (pPlayer.m_afPhysicsFlags & PFLAG_ONBARNACLE) != 0 ) return; //grabbed by a Barnacle

		if( m_flNextKick[id] >= g_Engine.time ) return; //cooldown

		CBasePlayerWeapon@ pWeapon = cast<CBasePlayerWeapon@>( pPlayer.m_hActiveItem.GetEntity() );

		//don't allow kick while attacking or reloading
		if( g_Engine.time < pWeapon.m_flNextPrimaryAttack or g_Engine.time < pWeapon.m_flNextSecondaryAttack or g_Engine.time < pWeapon.m_flNextTertiaryAttack ) return;
		if( pWeapon.m_fInReload ) return;

		pWeapon.m_flNextPrimaryAttack = g_Engine.time + m_flKickDelay;
		pWeapon.m_flNextSecondaryAttack = g_Engine.time + m_flKickDelay;
		pWeapon.m_flNextTertiaryAttack = g_Engine.time + m_flKickDelay;
		pWeapon.m_flTimeWeaponIdle = g_Engine.time + m_flKickDelay;
		pWeapon.SendWeaponAnim(0);

		if( pPlayer.pev.FlagBitSet(FL_ONGROUND) )
		{
			//todo somehow prevent motion until kick is done
			pPlayer.pev.velocity = g_vecZero;
		}

		sWeaponModel = pPlayer.pev.viewmodel;
		pPlayer.pev.viewmodel = m_sKickModel;

		TraceResult tr;

		Math.MakeVectors( pPlayer.pev.v_angle );
		Vector vecSrc	= pPlayer.GetGunPosition(); //Center() ??
		Vector vecEnd	= vecSrc + g_Engine.v_forward * m_flKickRange;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, pPlayer.edict(), tr );

		if( tr.flFraction >= 1.0 )
		{
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, pPlayer.edict(), tr );

			if( tr.flFraction < 1.0 )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

				if( pHit is null or pHit.IsBSPModel() )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, pPlayer.edict() );

				vecEnd = tr.vecEndPos;
			}
		}

		if( tr.flFraction >= 1.0 ) //hit nothing
		{
			//m_flNextKick[id] = g_Engine.time + m_flKickDelay;

			g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_WEAPON, "bhl/kick.wav", VOL_NORM, ATTN_NORM );
			//pPlayer.SetAnimation( PLAYER_ATTACK1 );
		}
		else
		{
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			//pPlayer.SetAnimation( PLAYER_ATTACK1 );

			//g_WeaponFuncs.ClearMultiDamage();
			//pEntity.TraceAttack( pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB );
			//g_WeaponFuncs.ApplyMultiDamage( pPlayer.pev, pPlayer.pev );

			bool bHitWorld = true;

			if( pEntity !is null )
			{
				//m_flNextKick[id] = g_Engine.time + m_flKickDelay;

				if( pPlayer.IRelationship(pEntity) > R_NO and pEntity.Classify() != CLASS_NONE and pEntity.Classify() != CLASS_MACHINE and pEntity.pev.takedamage != DAMAGE_NO and !pEntity.IsBSPModel() )
				{
					Math.MakeVectors( pPlayer.pev.v_angle );
					pEntity.pev.velocity = g_Engine.v_forward * m_flKickHitVelocity;
					pEntity.pev.velocity.z += m_flKickHitZBoost;

					pEntity.TakeDamage( pPlayer.pev, pPlayer.pev, flDamage, DMG_CLUB );

					g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_WEAPON, "weapons/cbar_hitbod3.wav", VOL_NORM, ATTN_NORM );

					bHitWorld = false;
				}
			}

			if( bHitWorld )
				g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_WEAPON, "zombie/claw_strike1.wav", VOL_NORM, ATTN_NORM );
		}

		m_flNextKick[id] = g_Engine.time + m_flKickDelay;
		g_Scheduler.SetTimeout( "KickResetModel", m_flKickDelay, id, sWeaponModel );
	}
}

void KickResetModel( const int &in id, const string &in sWeaponModel )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);

	if( pPlayer is null ) return;

	if( pPlayer.IsAlive() )
	{
		//some weapons can't be fired after kicking for some reason
		if( pPlayer.m_hActiveItem.GetEntity() !is null )
		{
			CBasePlayerWeapon@ pWeapon = cast<CBasePlayerWeapon@>( pPlayer.m_hActiveItem.GetEntity() );
			pWeapon.m_flNextPrimaryAttack = 0.0;
			pWeapon.m_flNextSecondaryAttack = 0.0;
			pWeapon.m_flNextTertiaryAttack = 0.0;
		}

		if( sWeaponModel == "" or sWeaponModel == m_sKickModel )
			pPlayer.DeployWeapon();
		else
			pPlayer.pev.viewmodel = sWeaponModel;
	}
}

} //namespace nerokick END
