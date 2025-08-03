//Version 1.8
// Airstrike by Nero
// ============================
// .airstrike <1-25> <0-12>
// Drops grenades/rockets/mortars on the targeted area
// provided there is sky above. (or player is looking at the sky)
//
// Thanks to: DeepBlueSea, w00tguy123, R4to0

const int SATCHEL_DETONATE_TIME = 2.0f;
int SPREAD_MIN;
int SPREAD_MAX;
const int iMaxTypes = 14;
float last_airstrike = 0.0f;
CCVar@ m_pASAnywhere;
CCVar@ m_pASDelay;
CCVar@ m_pASMaxAmount;
CCVar@ m_pASMinSpread;
CCVar@ m_pASMaxSpread;

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nero" );
	g_Module.ScriptInfo.SetContactInfo( "https://discord.gg/0wtJ6aAd7XOGI6vI" );
	
	g_Module.ScriptInfo.SetMinimumAdminLevel( ADMIN_YES );

	@m_pASAnywhere = CCVar( "airstrike-anywhere", 0, "Allow airstrikes anywhere or only where there is sky?. (default: 0)", ConCommandFlag::AdminOnly );
	@m_pASDelay = CCVar( "airstrike-delay", 0.5, "Minimum delay in seconds between airstrikes. (default: 0.5)", ConCommandFlag::AdminOnly );
	@m_pASMaxAmount = CCVar( "airstrike-max", 25, "Maximum of projectiles fired by airstrike. (default: 25)", ConCommandFlag::AdminOnly );
	@m_pASMinSpread = CCVar( "airstrike-minspread", -150, "Minimum projectile spread. (default: -150)", ConCommandFlag::AdminOnly );
	@m_pASMaxSpread = CCVar( "airstrike-maxspread", 150, "Maximum projectile spread. (default: 150)", ConCommandFlag::AdminOnly );
}

CClientCommand airstrike( "airstrike", "Launches projectiles from the sky.", @AirstrikeCMD );
CClientCommand airstrike_anywhere( "airstrike_anywhere", "Allow airstrikes anywhere or only where there is sky?. (default: 0)", @AirstrikeSettings );
CClientCommand airstrike_delay( "airstrike_delay", "Minimum delay in seconds between airstrikes. (default: 0.5)", @AirstrikeSettings );
CClientCommand airstrike_max( "airstrike_max", "Maximum of projectiles fired by airstrike. (default: 25)", @AirstrikeSettings );
CClientCommand airstrike_minspread( "airstrike_minspread", "Minimum projectile spread. (default: -150)", @AirstrikeSettings );
CClientCommand airstrike_maxspread( "airstrike_maxspread", "Maximum projectile spread. (default: 150)", @AirstrikeSettings );

void MapInit()
{
	g_Game.PrecacheModel( "models/mortarshell.mdl" );
	g_Game.PrecacheModel( "models/hvr.mdl" );
	g_Game.PrecacheModel( "sprites/mommaspit.spr" );
	g_Game.PrecacheModel( "sprites/mommaspout.spr" );
	g_Game.PrecacheModel( "sprites/mommablob.spr" );
	g_Game.PrecacheModel( "sprites/bigspit.spr" );
	g_Game.PrecacheModel( "sprites/tinyspit.spr" );
	g_Game.PrecacheModel( "sprites/lgtning.spr" );

	g_SoundSystem.PrecacheSound( "weapons/ofmortar.wav" );
	g_SoundSystem.PrecacheSound( "bullchicken/bc_acid1.wav" );
	g_SoundSystem.PrecacheSound( "bullchicken/bc_spithit1.wav" );
	g_SoundSystem.PrecacheSound( "bullchicken/bc_spithit2.wav" );

	last_airstrike = 0.0;
}

void AirstrikeCMD( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();
	
	Vector vecSrc;
	TraceResult tr;
	int iCount;
	int iType;
	float astime;
	astime = last_airstrike;
	edict_t@ owner;
	
	if( astime > 0 && astime + m_pASDelay.GetFloat() > g_Engine.time )
	{
		g_EngineFuncs.ClientPrintf( pPlayer, print_center, "Airstrike cooldown: " + ( astime + m_pASDelay.GetFloat() - g_Engine.time ) + " second(s).\n" );

		return;
	}

	if( args.ArgC() < 2 )//If no args are supplied
	{
		iCount = 6;
		iType = 1;
		@owner = pPlayer.edict();
	}
	else if( args.ArgC() == 2 )//If one arg is supplied (amount)
	{
		if( args.Arg(1) == "help" )
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "<arg> optional parameter\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, ".airstrike <amount 0-" + m_pASMaxAmount.GetInt() + "> <type 1-" + iMaxTypes + "> <worldspawn? 0/1.\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "0 = Random Airstrike. 1 = Mortar. 2 = Contact Grenade. 3 = RPG Rocket.\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "4 = Apache Rocket. 5 = Hand Grenade. 6 = Mortar Shell. 7 = Banana Cluster Grenade.\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "8 = Displacer Portal. 9 = Bigmomma Spit. 10 = Squid Spit. 11 = Shock Beam.\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "12 = Crossbow Bolt. 13 = Satchel Charge. 14 = Tripmine.\n" );

			return;
		}

		if( atoi( args.Arg( 1 ) ) > 0 && atoi( args.Arg( 1 ) ) <= m_pASMaxAmount.GetInt() )
			iCount = atoi( args.Arg( 1 ) );
		else if( atoi( args.Arg( 1 ) ) < 1 || atoi( args.Arg( 1 ) ) > m_pASMaxAmount.GetInt()  )
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "Minimum of 1 projectile. Maximum of " + m_pASMaxAmount.GetInt() + ".\n" );

			return;
		}
		iType = 1;
		@owner = pPlayer.edict();
	}
	else if( args.ArgC() == 3 )//If two args are supplied (amount and type)
	{
		if( atoi( args.Arg( 1 ) ) > 0 && atoi( args.Arg( 1 ) ) <= m_pASMaxAmount.GetInt() )
			iCount = atoi( args.Arg( 1 ) );
		else if( atoi( args.Arg( 1 ) ) < 1 || atoi( args.Arg( 1 ) ) > m_pASMaxAmount.GetInt()  )
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "Minimum of 1 projectile. Maximum of " + m_pASMaxAmount.GetInt() + ".\n" );

			return;
		}
		
		if( atoi( args.Arg( 2 ) ) >= 0 && atoi( args.Arg( 2 ) ) <= iMaxTypes )
			iType = atoi( args.Arg( 2 ) );
		else
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "Valid types: 0-" + iMaxTypes + "\n" );

			return;
		}

		@owner = pPlayer.edict();
	}
	else if( args.ArgC() == 4 )//If three args are supplied (amount, type, and owner)
	{
		if( atoi( args.Arg( 1 ) ) > 0 && atoi( args.Arg( 1 ) ) <= m_pASMaxAmount.GetInt() )
			iCount = atoi( args.Arg( 1 ) );
		else if( atoi( args.Arg( 1 ) ) < 1 || atoi( args.Arg( 1 ) ) > m_pASMaxAmount.GetInt()  )
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "Minimum of 1 projectile. Maximum of " + m_pASMaxAmount.GetInt() + ".\n" );

			return;
		}
		
		if( atoi( args.Arg( 2 ) ) >= 0 && atoi( args.Arg( 2 ) ) <= iMaxTypes )
			iType = atoi( args.Arg( 2 ) );
		else
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "Valid types: 0-" + iMaxTypes + "\n" );

			return;
		}

		if( args.Arg(3) == "1" )
			@owner = g_EntityFuncs.Instance(0).edict();
		else
			@owner = pPlayer.edict();
		
	}
	// see if we're pointed at the sky
	vecSrc = pPlayer.EyePosition();

	Math.MakeVectors( pPlayer.pev.v_angle );
	g_Utility.TraceLine( vecSrc, vecSrc + g_Engine.v_forward * 8192, ignore_monsters, pPlayer.edict(), tr );

	if( m_pASAnywhere.GetInt() == 0 )
	{
		if( g_EngineFuncs.PointContents( tr.vecEndPos ) != CONTENTS_SKY )
		{
			// We hit something but it wasn't sky, so let's see if there is sky above it
			vecSrc = tr.vecEndPos;

			g_Utility.TraceLine( vecSrc, vecSrc + Vector(0, 0, 1) * 8192, ignore_monsters, pPlayer.edict(), tr );

			if( g_EngineFuncs.PointContents( tr.vecEndPos ) != CONTENTS_SKY )// No sky above it either
			{
				g_EngineFuncs.ClientPrintf( pPlayer, print_center, "Airstrikes have to come from the sky!\n" );
				return;
			}
		}
	}

	last_airstrike = g_Engine.time;
	doAirstrike( pPlayer, tr.vecEndPos, iCount, iType, owner );
}

void doAirstrike( CBasePlayer@ pPlayer, Vector airstrike_entry, int iCount, int iType, edict_t@ owner )
{
	Vector vecSrc;
	array<CBaseEntity@> pRockets(iCount);
	TraceResult tr;

	// find the direction from the entry point to the target
	vecSrc = m_pASAnywhere.GetInt() == 0 ? airstrike_entry + Vector(0, 0, -1) : airstrike_entry;

	// Precision airstrike!
	if( iCount == 1 )
	{
		SPREAD_MIN = 0;
		SPREAD_MAX = 0;
	}
	else
	{
		SPREAD_MIN = m_pASMinSpread.GetInt();
		SPREAD_MAX = m_pASMaxSpread.GetInt();
	}

	for( int i = 0; i < iCount; ++i )
	{
		switch ( iType )
		{
			case 0: doRandomAirstrike( pPlayer, i, iCount, vecSrc, owner ); break;
			case 1:
			{
				g_Utility.TraceLine( vecSrc + Vector(0, 0, 1024), vecSrc - Vector(0, 0, 1024), dont_ignore_monsters, pPlayer.edict(), tr );
				@pRockets[i] = g_EntityFuncs.Create( "monster_mortar", tr.vecEndPos + Vector(Math.RandomLong(SPREAD_MIN, SPREAD_MAX), Math.RandomLong(SPREAD_MIN, SPREAD_MAX), 0), Vector( -90,0,0 ), false, owner );
				pRockets[i].pev.nextthink = g_Engine.time + 0;
				break;
			}
			case 2: @pRockets[i] = g_EntityFuncs.ShootContact( pPlayer.pev, vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( 0,0,0 ) ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -800, -500 )); break;
			case 3: @pRockets[i] = g_EntityFuncs.CreateRPGRocket( vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( 90,0,0 ), g_Engine.v_forward * 250, pPlayer.edict() ); pRockets[i].pev.nextthink = 0.01; pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -800, -500 )); break;
			case 4: @pRockets[i] = g_EntityFuncs.Create( "hvr_rocket", vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( -90,0,0 ), false, pPlayer.edict() ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -800, -500 )); break;
			case 5: @pRockets[i] = g_EntityFuncs.ShootTimed( pPlayer.pev, vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector(0,0,0), 3 ); break;
			case 6: @pRockets[i] = g_EntityFuncs.ShootMortar( pPlayer.pev, vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector(0,0,0) ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -400, -250 )); break;
			case 7: @pRockets[i] = g_EntityFuncs.ShootBananaCluster( pPlayer.pev, vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector(0,0,0) ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -800, -500 )); break;
			case 8: @pRockets[i] = g_EntityFuncs.CreateDisplacerPortal( vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( 0,0,0 ), pPlayer.edict(), 250, 300 ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -400, -250 )); break;
			case 9: @pRockets[i] = g_EntityFuncs.Create( "bmortar", vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( -90,0,0 ), false, pPlayer.edict() ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -800, -500 )); break;
			case 10: @pRockets[i] = g_EntityFuncs.Create( "squidspit", vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( -90,0,0 ), false, pPlayer.edict() ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -800, -500 )); break;
			case 11: @pRockets[i] = g_EntityFuncs.Create( "shock_beam", vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( -90,0,0 ), false, pPlayer.edict() ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -1440, -1140 )); break;
			case 12: @pRockets[i] = g_EntityFuncs.Create( "crossbow_bolt", vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( -90,0,0 ), false, pPlayer.edict() ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -1440, -1140 )); break;
			case 13: @pRockets[i] = g_EntityFuncs.Create( "monster_satchel", vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( -90,0,0 ), false, pPlayer.edict() ); g_Scheduler.SetTimeout( "DetonateSatchels", SATCHEL_DETONATE_TIME, EHandle(pRockets[i]) ); break;
			case 14:
			{
				g_Utility.TraceLine( vecSrc + Vector(0, 0, 1024), vecSrc - Vector(0, 0, 1024), ignore_monsters, pPlayer.edict(), tr );
				Vector angles = Math.VecToAngles( tr.vecPlaneNormal );
				g_EntityFuncs.Create( "monster_tripmine", tr.vecEndPos + Vector(Math.RandomLong(SPREAD_MIN, SPREAD_MAX), Math.RandomLong(SPREAD_MIN, SPREAD_MAX), 0) + tr.vecPlaneNormal * 8, angles, false, owner );
				break;
			}
		}
	}
}

void doRandomAirstrike( CBasePlayer@ pPlayer, int i, int iCount, Vector vecSrc, edict_t@ owner )
{
	int iRand = Math.RandomLong( 1, 12 );
	array<CBaseEntity@> pRockets(iCount);
	TraceResult tr;

	// Precision airstrike!
	if( iCount == 1)
	{
		SPREAD_MIN = 0;
		SPREAD_MAX = 0;
	}
	else
	{
		SPREAD_MIN = m_pASMinSpread.GetInt();
		SPREAD_MAX = m_pASMaxSpread.GetInt();
	}
	
	switch ( iRand )
	{
		case 1:
		{
			g_Utility.TraceLine( vecSrc + Vector(0, 0, 1024), vecSrc - Vector(0, 0, 1024), dont_ignore_monsters, pPlayer.edict(), tr );
			@pRockets[i] = g_EntityFuncs.Create( "monster_mortar", tr.vecEndPos + Vector(Math.RandomLong(SPREAD_MIN, SPREAD_MAX), Math.RandomLong(SPREAD_MIN, SPREAD_MAX), 0), Vector( -90,0,0 ), false, owner );
			pRockets[i].pev.nextthink = g_Engine.time + 0;
			break;
		}
		case 2: @pRockets[i] = g_EntityFuncs.ShootContact( pPlayer.pev, vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( 0,0,0 ) ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -800, -500 )); break;
		case 3: @pRockets[i] = g_EntityFuncs.CreateRPGRocket( vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( 90,0,0 ), g_Engine.v_forward * 250, pPlayer.edict() ); pRockets[i].pev.nextthink = 0.01; pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -800, -500 )); break;
		case 4: @pRockets[i] = g_EntityFuncs.Create( "hvr_rocket", vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( -90,0,0 ), false, pPlayer.edict() ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -800, -500 )); break;
		case 5: @pRockets[i] = g_EntityFuncs.ShootTimed( pPlayer.pev, vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector(0,0,0), 3 ); break;
		case 6: @pRockets[i] = g_EntityFuncs.ShootMortar( pPlayer.pev, vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector(0,0,0) ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -400, -250 )); break;
		case 7: @pRockets[i] = g_EntityFuncs.ShootBananaCluster( pPlayer.pev, vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector(0,0,0) ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -800, -500 )); break;
		case 8: @pRockets[i] = g_EntityFuncs.CreateDisplacerPortal( vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( 0,0,0 ), pPlayer.edict(), 250, 300 ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -400, -250 )); break;
		case 9: @pRockets[i] = g_EntityFuncs.Create( "bmortar", vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( -90,0,0 ), false, pPlayer.edict() ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -800, -500 )); break;
		case 10: @pRockets[i] = g_EntityFuncs.Create( "squidspit", vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( -90,0,0 ), false, pPlayer.edict() ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -800, -500 )); break;
		case 11: @pRockets[i] = g_EntityFuncs.Create( "shock_beam", vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( -90,0,0 ), false, pPlayer.edict() ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -1440, -1140 )); break;
		case 12: @pRockets[i] = g_EntityFuncs.Create( "crossbow_bolt", vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( -90,0,0 ), false, pPlayer.edict() ); pRockets[i].pev.velocity = Vector( 0, 0, Math.RandomLong( -1440, -1140 )); break;
		case 13: @pRockets[i] = g_EntityFuncs.Create( "monster_satchel", vecSrc + Vector( Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), Math.RandomLong( SPREAD_MIN, SPREAD_MAX ), 0 ), Vector( -90,0,0 ), false, pPlayer.edict() ); g_Scheduler.SetTimeout( "DetonateSatchels", SATCHEL_DETONATE_TIME, EHandle(pRockets[i]) ); break;
		case 14:
		{
			g_Utility.TraceLine( vecSrc + Vector(0, 0, 1024), vecSrc - Vector(0, 0, 1024), ignore_monsters, pPlayer.edict(), tr );
			Vector angles = Math.VecToAngles( tr.vecPlaneNormal );
			g_EntityFuncs.Create( "monster_tripmine", tr.vecEndPos + Vector(Math.RandomLong(SPREAD_MIN, SPREAD_MAX), Math.RandomLong(SPREAD_MIN, SPREAD_MAX), 0) + tr.vecPlaneNormal * 8, angles, false, owner );
			break;
		}
	}
}

void DetonateSatchels( EHandle& in ent )
{
	CBaseEntity@ pSatchel = null;
	@pSatchel = ent.GetEntity();
	CBaseEntity@ pPlayer = g_EntityFuncs.Instance( pSatchel.pev.owner );
	
	pSatchel.Use( pPlayer, pPlayer, USE_ON, 0 );
}

void AirstrikeSettings( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

	if( pPlayer is null )
	{
		g_Game.AlertMessage( at_console, "[AIRSTRIKE] AirstrikeSettings: pPlayer is null!\n" );
		return;
	}

	if( args.ArgC() < 2 )//If no args are supplied
	{
		if( args.Arg(0) == ".airstrike_anywhere" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"airstrike_anywhere\" is \"" + m_pASAnywhere.GetInt() + "\"\n" );
		else if( args.Arg(0) == ".airstrike_delay" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"airstrike_delay\" is \"" + m_pASDelay.GetFloat() + "\"\n" );
		else if( args.Arg(0) == ".airstrike_max" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"airstrike_max\" is \"" + m_pASMaxAmount.GetInt() + "\"\n" );
		else if( args.Arg(0) == ".airstrike_minspread" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"airstrike_minspread\" is \"" + m_pASMinSpread.GetInt() + "\"\n" );
		else if( args.Arg(0) == ".airstrike_maxspread" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"airstrike_maxspread\" is \"" + m_pASMaxSpread.GetInt() + "\"\n" );
	}
	else if( args.ArgC() == 2 )//If one arg is supplied (value to set)
	{
		if( args.Arg(0) == ".airstrike_anywhere" && Math.clamp(0, 1, atoi(args.Arg(1))) != m_pASAnywhere.GetInt() )
		{
			m_pASAnywhere.SetInt( Math.clamp(0, 1, atoi(args.Arg(1))) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"airstrike_anywhere\" changed to \"" + m_pASAnywhere.GetInt() + "\"\n" );
		}
		else if( args.Arg(0) == ".airstrike_delay" && atof(args.Arg(1)) != m_pASDelay.GetFloat() )
		{
			m_pASDelay.SetFloat( Math.clamp(0.0f, 60.0f, atof(args.Arg(1))) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"airstrike_delay\" changed to \"" + m_pASDelay.GetFloat() + "\"\n" );
		}
		else if( args.Arg(0) == ".airstrike_max" && args.Arg(1) != m_pASMaxAmount.GetInt() )
		{
			m_pASMaxAmount.SetInt( Math.clamp(0, 250, atoi(args.Arg(1))) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"airstrike_max\" changed to \"" + m_pASMaxAmount.GetInt() + "\"\n" );
		}
		else if( args.Arg(0) == ".airstrike_minspread" && args.Arg(1) != m_pASMinSpread.GetInt() )
		{
			m_pASMinSpread.SetInt( Math.clamp(-400, 0, atoi(args.Arg(1))) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"airstrike_minspread\" changed to \"" + m_pASMinSpread.GetInt() + "\"\n" );
		}
		else if( args.Arg(0) == ".airstrike_maxspread" && args.Arg(1) != m_pASMaxSpread.GetInt() )
		{
			m_pASMaxSpread.SetInt( Math.clamp(0, 400, atoi(args.Arg(1))) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"airstrike_maxspread\" changed to \"" + m_pASMaxSpread.GetInt() + "\"\n" );
		}
	}
}