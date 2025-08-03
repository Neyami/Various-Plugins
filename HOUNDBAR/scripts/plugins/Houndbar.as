void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nero" );
	g_Module.ScriptInfo.SetContactInfo( "https://discord.gg/0wtJ6aAd7XOGI6vI" );

	g_Hooks.RegisterHook( Hooks::Player::PlayerPostThink, @Houndbar::PlayerPostThink );
	g_Hooks.RegisterHook( Hooks::Weapon::WeaponSecondaryAttack, @Houndbar::WeaponSecondaryAttack );
}

void MapInit()
{
	g_SoundSystem.PrecacheSound( "houndeye/he_attack1.wav" );
	g_SoundSystem.PrecacheSound( "houndeye/he_attack3.wav" );	
	Houndbar::m_iSpriteTexture = g_Game.PrecacheModel( "sprites/shockwave.spr" );
}

namespace Houndbar
{

const int HOUNDEYE_MAX_ATTACK_RADIUS = 384;
const float HOUNDEYE_DMG_BLAST = 15;
const float HOUNDEYE_ATTACK_CHARGETIME = 1.23;

int m_iSpriteTexture;
array<float> m_flSonicAttack(33);

HookReturnCode PlayerPostThink( CBasePlayer@ pPlayer )
{
	int id = pPlayer.entindex();

	if( m_flSonicAttack[id] > 0.0f and m_flSonicAttack[id] < g_Engine.time )
	{
		SonicAttack( EHandle(pPlayer) );
		m_flSonicAttack[id] = 0.0f;
	}

	return HOOK_CONTINUE;
}

HookReturnCode WeaponSecondaryAttack( CBasePlayer@ pPlayer, CBasePlayerWeapon@ pWeapon )
{
	if( pWeapon.GetClassname() == "weapon_crowbar" )
	{
		WarmUp( EHandle(pPlayer) );
		m_flSonicAttack[ pPlayer.entindex() ] = g_Engine.time + HOUNDEYE_ATTACK_CHARGETIME;
		pWeapon.m_flTimeWeaponIdle = pWeapon.m_flNextPrimaryAttack = pWeapon.m_flNextSecondaryAttack = pWeapon.m_flNextTertiaryAttack = g_Engine.time + HOUNDEYE_ATTACK_CHARGETIME;

		return HOOK_HANDLED;
	}

	return HOOK_CONTINUE;
}

void WarmUp( EHandle &in ePlayer )
{
	CBasePlayer@ pPlayer = null;
	if( ePlayer.IsValid() ) @pPlayer = cast<CBasePlayer@>( ePlayer.GetEntity() );
	if( pPlayer is null ) return;

	switch( Math.RandomLong(0, 1) )
	{
		case 0: g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_WEAPON, "houndeye/he_attack1.wav", 0.7f, ATTN_NORM ); break;
		case 1: g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_WEAPON, "houndeye/he_attack3.wav", 0.7f, ATTN_NORM ); break;
	}
}

void SonicAttack( EHandle &in ePlayer )
{
	CBasePlayer@ pPlayer = null;
	if( ePlayer.IsValid() ) @pPlayer = cast<CBasePlayer@>( ePlayer.GetEntity() );
	if( pPlayer is null ) return;

	float		flAdjustedDamage;
	float		flDist;

	switch( Math.RandomLong(0, 2) )
	{
		case 0: g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_WEAPON, "houndeye/he_blast1.wav", VOL_NORM, ATTN_NORM ); break;
		case 1: g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_WEAPON, "houndeye/he_blast2.wav", VOL_NORM, ATTN_NORM ); break;
		case 2: g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_WEAPON, "houndeye/he_blast3.wav", VOL_NORM, ATTN_NORM ); break;
	}

	// blast circles
	NetworkMessage m1( MSG_PAS, NetworkMessages::SVC_TEMPENTITY, pPlayer.pev.origin );
		m1.WriteByte( TE_BEAMCYLINDER );
		m1.WriteCoord( pPlayer.pev.origin.x );
		m1.WriteCoord( pPlayer.pev.origin.y );
		m1.WriteCoord( pPlayer.pev.origin.z + 16 );
		m1.WriteCoord( pPlayer.pev.origin.x );
		m1.WriteCoord( pPlayer.pev.origin.y );
		m1.WriteCoord( pPlayer.pev.origin.z + 16 + HOUNDEYE_MAX_ATTACK_RADIUS / .2); // reach damage radius over .3 seconds
		m1.WriteShort( m_iSpriteTexture );
		m1.WriteByte( 0 ); // startframe
		m1.WriteByte( 0 ); // framerate
		m1.WriteByte( 2 ); // life
		m1.WriteByte( 16 );  // width
		m1.WriteByte( 0 );   // noise
		m1.WriteByte( 188 );   // r, g, b
		m1.WriteByte( 220 );   // r, g, b
		m1.WriteByte( 255 );   // r, g, b
		m1.WriteByte( 255 ); // brightness
		m1.WriteByte( 0 );		// speed
	m1.End();

	NetworkMessage m2( MSG_PAS, NetworkMessages::SVC_TEMPENTITY, pPlayer.pev.origin );
		m2.WriteByte( TE_BEAMCYLINDER );
		m2.WriteCoord( pPlayer.pev.origin.x );
		m2.WriteCoord( pPlayer.pev.origin.y );
		m2.WriteCoord( pPlayer.pev.origin.z + 16 );
		m2.WriteCoord( pPlayer.pev.origin.x );
		m2.WriteCoord( pPlayer.pev.origin.y );
		m2.WriteCoord( pPlayer.pev.origin.z + 16 + ( HOUNDEYE_MAX_ATTACK_RADIUS / 2 ) / .2); // reach damage radius over .3 seconds
		m2.WriteShort( m_iSpriteTexture );
		m2.WriteByte( 0 ); // startframe
		m2.WriteByte( 0 ); // framerate
		m2.WriteByte( 2 ); // life
		m2.WriteByte( 16 );  // width
		m2.WriteByte( 0 );   // noise
		m2.WriteByte( 188 );   // r, g, b
		m2.WriteByte( 220 );   // r, g, b
		m2.WriteByte( 255 );   // r, g, b
		m2.WriteByte( 255 ); // brightness
		m2.WriteByte( 0 );		// speed
	m2.End();

	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, pPlayer.pev.origin, HOUNDEYE_MAX_ATTACK_RADIUS, "*", "classname")) !is null )
	{
		if( pEntity.pev.takedamage != DAMAGE_NO and pEntity.edict() !is pPlayer.edict() )
		{
			if( !pEntity.pev.ClassNameIs("monster_houndeye") )
			{// houndeyes don't hurt other houndeyes with their attack

				// houndeyes do FULL damage if the ent in question is visible. Half damage otherwise.
				// This means that you must get out of the houndeye's attack range entirely to avoid damage.
				// Calculate full damage first

				flAdjustedDamage = HOUNDEYE_DMG_BLAST;

				flDist = (pEntity.Center() - pPlayer.pev.origin).Length();

				flAdjustedDamage -= ( flDist / HOUNDEYE_MAX_ATTACK_RADIUS ) * flAdjustedDamage;

				if( !pPlayer.FVisible(pEntity, true) )
				{
					if( pEntity.IsPlayer() )
					{
						// if this entity is a client, and is not in full view, inflict half damage. We do this so that players still 
						// take the residual damage if they don't totally leave the houndeye's effective radius. We restrict it to clients
						// so that monsters in other parts of the level don't take the damage and get pissed.
						flAdjustedDamage *= 0.5;
					}
					else if( !pEntity.pev.ClassNameIs("func_breakable") and !pEntity.pev.ClassNameIs("func_pushable") ) 
					{
						// do not hurt nonclients through walls, but allow damage to be done to breakables
						flAdjustedDamage = 0;
					}
				}

				if( flAdjustedDamage > 0 )
					pEntity.TakeDamage( pPlayer.pev, pPlayer.pev, flAdjustedDamage, DMG_SONIC | DMG_ALWAYSGIB );
			}
		}
	}
}

} //namespace Houndbar END