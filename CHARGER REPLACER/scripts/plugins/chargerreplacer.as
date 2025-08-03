/***********************
*		CAUTION		   *
*	MESSY CODE AHEAD   *
***********************/
void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nero" );
	g_Module.ScriptInfo.SetContactInfo( "https://discord.gg/0wtJ6aAd7XOGI6vI" );
	g_Module.ScriptInfo.SetMinimumAdminLevel( ADMIN_YES );
}

void MapInit()
{
	for( uint i = 0; i < ChargerReplacer::g_CRDisabledMaps.length(); i++ )
	{
		if( g_Engine.mapname == ChargerReplacer::g_CRDisabledMaps[i] )
			return;
	}

	g_Game.PrecacheModel( ChargerReplacer::MODEL_HEALTH );
	g_Game.PrecacheModel( ChargerReplacer::MODEL_HEV );
	g_Game.PrecacheModel( "sprites/glow01.spr" );

	if( ChargerReplacer::g_bUseCustomSounds )
	{
		g_SoundSystem.PrecacheSound( ChargerReplacer::SOUND_HEALTH_START );
		g_SoundSystem.PrecacheSound( ChargerReplacer::SOUND_HEALTH_LOOP );
		g_SoundSystem.PrecacheSound( ChargerReplacer::SOUND_HEALTH_DENIED );
		g_SoundSystem.PrecacheSound( ChargerReplacer::SOUND_HEV_START );
		g_SoundSystem.PrecacheSound( ChargerReplacer::SOUND_HEV_LOOP );
		g_SoundSystem.PrecacheSound( ChargerReplacer::SOUND_HEV_DENIED );

		//precache for downloading to clients
		g_Game.PrecacheGeneric( "sound/" + ChargerReplacer::SOUND_HEALTH_START );
		g_Game.PrecacheGeneric( "sound/" + ChargerReplacer::SOUND_HEALTH_LOOP );
		g_Game.PrecacheGeneric( "sound/" + ChargerReplacer::SOUND_HEALTH_DENIED );
		g_Game.PrecacheGeneric( "sound/" + ChargerReplacer::SOUND_HEV_START );
		g_Game.PrecacheGeneric( "sound/" + ChargerReplacer::SOUND_HEV_LOOP );
		g_Game.PrecacheGeneric( "sound/" + ChargerReplacer::SOUND_HEV_DENIED );
	}
}

void MapActivate()
{
	for( uint i = 0; i < ChargerReplacer::g_CRDisabledMaps.length(); i++ )
	{
		if( g_Engine.mapname == ChargerReplacer::g_CRDisabledMaps[i] )
			return;
	}

	ChargerReplacer::Replace(16);
}

namespace ChargerReplacer
{

//test cmd
//CClientCommand replace( "replace", "Replaces brush chargers with models.", @ReplaceCMD );

//CUSTOMIZATION BEGIN
const bool g_bUseCustomSounds		= false;
const string SOUND_HEALTH_START		= "barnacle/bcl_bite3.wav";
const string SOUND_HEALTH_LOOP		= "barnacle/bcl_alert2.wav";
const string SOUND_HEALTH_DENIED	= "barnacle/bcl_chew3.wav";

const string SOUND_HEV_START		= "barnacle/bcl_bite3.wav";
const string SOUND_HEV_LOOP			= "barnacle/bcl_alert2.wav";
const string SOUND_HEV_DENIED		= "barnacle/bcl_chew3.wav";

const string MODEL_HEALTH		= "models/dgf_healthstation.mdl";
const string MODEL_HEV			= "models/dgf_hevstation.mdl";

array<string> g_CRDisabledMaps =
{
	"nero_test",
	"thismap",
	"thatmap",
	"bleh",
	"feh"
};
//CUSTOMIZATION END
/* test command
void ReplaceCMD( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();
	float flTraceLength = args.ArgC() == 1 ? 16 : atoi(args.Arg(1));

	Replace( flTraceLength );
}
*/
void Replace( const float flTraceLength )
{
	CBaseEntity@ pEntity = null;

	//todo set "zhlt_lightflags" "2" ?
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "func_healthcharger")) !is null )
	{
		TraceResult tr;
		Vector origin, vecPlaneNormal;

		//string orientation = ""; //for testing

		origin = pEntity.Center();

		g_Utility.TraceLine( origin, origin + Vector(flTraceLength, 0, 0), ignore_monsters, pEntity.edict(), tr );
		vecPlaneNormal = tr.vecPlaneNormal;

		if( tr.flFraction < 1.0f )
		{
			//g_Game.AlertMessage( at_console, "First trace hit!\n" );
			g_Utility.TraceLine( origin, origin - Vector(flTraceLength, 0, 0), ignore_monsters, pEntity.edict(), tr );
			//orientation = "South"; //for testing

			//g_Game.AlertMessage( at_console, "origin for %1 %2: %3 (%4)\n", pEntity.GetClassname(), pEntity.pev.targetname, origin.ToString(), orientation );

			ModifyHealthCharger( pEntity );
			SpawnCharger( 0, origin, vecPlaneNormal, pEntity.entindex() );

			continue;
		}
		else
		{
			//g_Game.AlertMessage( at_console, "First trace didn' hit, retrying!\n" );
			g_Utility.TraceLine( origin, origin - Vector(flTraceLength, 0, 0), ignore_monsters, pEntity.edict(), tr );
			vecPlaneNormal = tr.vecPlaneNormal;
		}

		if( tr.flFraction < 1.0f )
		{
			//g_Game.AlertMessage( at_console, "Second trace hit!\n" );
			g_Utility.TraceLine( origin, origin + Vector(flTraceLength, 0, 0), ignore_monsters, pEntity.edict(), tr );
			//orientation = "North"; //for testing

			//g_Game.AlertMessage( at_console, "origin for %1 %2: %3 (%4)\n", pEntity.GetClassname(), pEntity.pev.targetname, origin.ToString(), orientation );

			ModifyHealthCharger( pEntity );
			SpawnCharger( 0, origin, vecPlaneNormal, pEntity.entindex() );

			continue;
		}
		else
		{
			//g_Game.AlertMessage( at_console, "Second trace didn't hit, retrying!\n" );
			g_Utility.TraceLine( origin, origin + Vector(0, flTraceLength, 0), ignore_monsters, pEntity.edict(), tr );
			vecPlaneNormal = tr.vecPlaneNormal;
		}

		if( tr.flFraction < 1.0f )
		{
			//g_Game.AlertMessage( at_console, "Third trace hit!\n" );
			g_Utility.TraceLine( origin, origin - Vector(0, flTraceLength, 0), ignore_monsters, pEntity.edict(), tr );
			//orientation = "East"; //for testing

			//g_Game.AlertMessage( at_console, "origin for %1 %2: %3 (%4)\n", pEntity.GetClassname(), pEntity.pev.targetname, origin.ToString(), orientation );

			ModifyHealthCharger( pEntity );
			SpawnCharger( 0, origin, vecPlaneNormal, pEntity.entindex() );

			continue;
		}
		else
		{
			//g_Game.AlertMessage( at_console, "Third trace didn't hit, retrying!\n" );
			g_Utility.TraceLine( origin, origin - Vector(0, flTraceLength, 0), ignore_monsters, pEntity.edict(), tr );
			vecPlaneNormal = tr.vecPlaneNormal;
		}

		if( tr.flFraction < 1.0f )
		{
			//g_Game.AlertMessage( at_console, "Fourth trace hit!\n" );
			g_Utility.TraceLine( origin, origin + Vector(0, flTraceLength, 0), ignore_monsters, pEntity.edict(), tr );
			//orientation = "West"; //for testing

			//g_Game.AlertMessage( at_console, "origin for %1 %2: %3 (%4)\n", pEntity.GetClassname(), pEntity.pev.targetname, origin.ToString(), orientation );

			ModifyHealthCharger( pEntity );
			SpawnCharger( 0, origin, vecPlaneNormal, pEntity.entindex() );
		}
		else
			g_Game.AlertMessage( at_console, "[CHARGER REPLACER] ERROR: All traces hit something!\n" );
	}

	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "func_recharge")) !is null )
	{
		TraceResult tr;
		Vector origin, vecPlaneNormal;

		//string orientation = ""; //for testing

		origin = pEntity.Center();

		g_Utility.TraceLine( origin, origin + Vector(flTraceLength, 0, 0), ignore_monsters, pEntity.edict(), tr );
		vecPlaneNormal = tr.vecPlaneNormal;

		if( tr.flFraction < 1.0f )
		{
			//g_Game.AlertMessage( at_console, "First trace hit!\n" );
			g_Utility.TraceLine( origin, origin - Vector(flTraceLength, 0, 0), ignore_monsters, pEntity.edict(), tr );
			//orientation = "South"; //for testing

			//g_Game.AlertMessage( at_console, "origin for %1 %2: %3 (%4)\n", pEntity.GetClassname(), pEntity.pev.targetname, origin.ToString(), orientation );

			ModifyHevCharger( pEntity );
			SpawnCharger( 1, origin, vecPlaneNormal, pEntity.entindex() );

			continue;
		}
		else
		{
			//g_Game.AlertMessage( at_console, "First trace didn' hit, retrying!\n" );
			g_Utility.TraceLine( origin, origin - Vector(flTraceLength, 0, 0), ignore_monsters, pEntity.edict(), tr );
			vecPlaneNormal = tr.vecPlaneNormal;
		}

		if( tr.flFraction < 1.0f )
		{
			//g_Game.AlertMessage( at_console, "Second trace hit!\n" );
			g_Utility.TraceLine( origin, origin + Vector(flTraceLength, 0, 0), ignore_monsters, pEntity.edict(), tr );
			//orientation = "North"; //for testing

			//g_Game.AlertMessage( at_console, "origin for %1 %2: %3 (%4)\n", pEntity.GetClassname(), pEntity.pev.targetname, origin.ToString(), orientation );

			ModifyHevCharger( pEntity );
			SpawnCharger( 1, origin, vecPlaneNormal, pEntity.entindex() );

			continue;
		}
		else
		{
			//g_Game.AlertMessage( at_console, "Second trace didn't hit, retrying!\n" );
			g_Utility.TraceLine( origin, origin + Vector(0, flTraceLength, 0), ignore_monsters, pEntity.edict(), tr );
			vecPlaneNormal = tr.vecPlaneNormal;
		}

		if( tr.flFraction < 1.0f )
		{
			//g_Game.AlertMessage( at_console, "Third trace hit!\n" );
			g_Utility.TraceLine( origin, origin - Vector(0, flTraceLength, 0), ignore_monsters, pEntity.edict(), tr );
			//orientation = "East"; //for testing

			//g_Game.AlertMessage( at_console, "origin for %1 %2: %3 (%4)\n", pEntity.GetClassname(), pEntity.pev.targetname, origin.ToString(), orientation );

			ModifyHevCharger( pEntity );
			SpawnCharger( 1, origin, vecPlaneNormal, pEntity.entindex() );

			continue;
		}
		else
		{
			//g_Game.AlertMessage( at_console, "Third trace didn't hit, retrying!\n" );
			g_Utility.TraceLine( origin, origin - Vector(0, flTraceLength, 0), ignore_monsters, pEntity.edict(), tr );
			vecPlaneNormal = tr.vecPlaneNormal;
		}

		if( tr.flFraction < 1.0f )
		{
			//g_Game.AlertMessage( at_console, "Fourth trace hit!\n" );
			g_Utility.TraceLine( origin, origin + Vector(0, flTraceLength, 0), ignore_monsters, pEntity.edict(), tr );
			//orientation = "West"; //for testing

			//g_Game.AlertMessage( at_console, "origin for %1 %2: %3 (%4)\n", pEntity.GetClassname(), pEntity.pev.targetname, origin.ToString(), orientation );

			ModifyHevCharger( pEntity );
			SpawnCharger( 1, origin, vecPlaneNormal, pEntity.entindex() );
		}
		else
			g_Game.AlertMessage( at_console, "[CHARGER REPLACER] ERROR: All traces hit something!\n" );
	}
}

void ModifyHealthCharger( CBaseEntity@ pCharger )
{
	int id = pCharger.entindex();

	pCharger.pev.renderfx = kRenderFxGlowShell;
	pCharger.pev.rendercolor = Vector(0, 0, 0);
	pCharger.pev.rendermode = kRenderTransAlpha;
	pCharger.pev.renderamt = 0;

	g_EntityFuncs.DispatchKeyValue( pCharger.edict(), "TriggerOnEmpty", "dgf_health_empty_" + id );
	g_EntityFuncs.DispatchKeyValue( pCharger.edict(), "TriggerOnRecharged", "dgf_health_full_" + id );

	if( g_bUseCustomSounds )
	{
		g_EntityFuncs.DispatchKeyValue( pCharger.edict(), "CustomStartSound", SOUND_HEALTH_START );
		g_EntityFuncs.DispatchKeyValue( pCharger.edict(), "CustomLoopSound", SOUND_HEALTH_LOOP );
		g_EntityFuncs.DispatchKeyValue( pCharger.edict(), "CustomDeniedSound", SOUND_HEALTH_DENIED );
	}
}

void ModifyHevCharger( CBaseEntity@ pCharger )
{
	int id = pCharger.entindex();

	pCharger.pev.renderfx = kRenderFxGlowShell;
	pCharger.pev.rendercolor = Vector(0, 0, 0);
	pCharger.pev.rendermode = kRenderTransAlpha;
	pCharger.pev.renderamt = 0;

	g_EntityFuncs.DispatchKeyValue( pCharger.edict(), "TriggerOnEmpty", "dgf_hev_empty_" + id );
	g_EntityFuncs.DispatchKeyValue( pCharger.edict(), "TriggerOnRecharged", "dgf_hev_full_" + id );

	if( g_bUseCustomSounds )
	{
		g_EntityFuncs.DispatchKeyValue( pCharger.edict(), "CustomStartSound", SOUND_HEV_START );
		g_EntityFuncs.DispatchKeyValue( pCharger.edict(), "CustomLoopSound", SOUND_HEV_LOOP );
		g_EntityFuncs.DispatchKeyValue( pCharger.edict(), "CustomDeniedSound", SOUND_HEV_DENIED );
	}
}

void SpawnCharger( const uint &in uiType, const Vector &in origin, const Vector &in vecPlaneNormal, const int &in id )
{
	dictionary keys;
	CBaseEntity@ pEntity = null;
	Vector angles = Math.VecToAngles( vecPlaneNormal );

	keys[ "origin" ] = origin.ToString();
	keys[ "angles" ] = angles.ToString();

	if( uiType == 0 )
		keys[ "targetname" ] = "dgf_health_model_" + id;
	else
		keys[ "targetname" ] = "dgf_hev_model_" + id;

	//the model
	@pEntity = g_EntityFuncs.CreateEntity( "info_target", keys, true );

	if( pEntity !is null )
	{
		if( uiType == 0 )
			g_EntityFuncs.SetModel( pEntity, MODEL_HEALTH );
		else
			g_EntityFuncs.SetModel( pEntity, MODEL_HEV );

		g_EntityFuncs.SetSize( pEntity.pev, g_vecZero, g_vecZero );

		g_EntityFuncs.SetOrigin( pEntity, origin );
		pEntity.pev.angles = angles;
		pEntity.pev.solid = SOLID_NOT;
		pEntity.pev.movetype = MOVETYPE_NOCLIP;
	}

	//entity that changes the model's skin when it's empty
	keys.deleteAll();

	keys[ "origin" ] = origin.ToString();
	keys[ "angles" ] = angles.ToString();

	if( uiType == 0 )
	{
		keys[ "targetname" ] = "dgf_health_empty_" + id;
		keys[ "target" ] = "dgf_health_model_" + id;
		keys[ "message" ] = "dgf_health_light_" + id;
	}
	else
	{
		keys[ "targetname" ] = "dgf_hev_empty_" + id;
		keys[ "target" ] = "dgf_hev_model_" + id;
		keys[ "message" ] = "dgf_hev_light_" + id;
	}

	keys[ "m_iszValueName" ] = "skin";
	keys[ "m_iszNewValue" ] = "1";

	g_EntityFuncs.CreateEntity( "trigger_changevalue", keys, true );

	//entity that changes the model's skin when it's full
	keys.deleteAll();

	keys[ "origin" ] = origin.ToString();
	keys[ "angles" ] = angles.ToString();

	if( uiType == 0 )
	{
		keys[ "targetname" ] = "dgf_health_full_" + id;
		keys[ "target" ] = "dgf_health_model_" + id;
		keys[ "message" ] = "dgf_health_light_" + id;
	}
	else
	{
		keys[ "targetname" ] = "dgf_hev_full_" + id;
		keys[ "target" ] = "dgf_hev_model_" + id;
		keys[ "message" ] = "dgf_hev_light_" + id;
	}

	keys[ "m_iszValueName" ] = "skin";
	keys[ "m_iszNewValue" ] = "0";

	g_EntityFuncs.CreateEntity( "trigger_changevalue", keys, true );

	//charger glow sprites and light
	if( uiType == 0 )
	{
		keys.deleteAll();
		Math.MakeVectors( angles );

		Vector tempOrigin = origin + g_Engine.v_forward * 4 + g_Engine.v_right * 8 + g_Engine.v_up * 16;

		keys[ "origin" ] = tempOrigin.ToString();

		keys[ "targetname" ] = "dgf_health_light_" + id;
		keys[ "rendercolor" ] = "0 0 0";
		keys[ "rendermode" ] = "3";
		keys[ "renderamt" ] = "60";
		keys[ "model" ] = "sprites/glow01.spr";
		keys[ "spawnflags" ] = "1";
		keys[ "scale" ] = "1.3";
		keys[ "framerate" ] = "10.0";
		keys[ "vp_type" ] = "0";

		g_EntityFuncs.CreateEntity( "env_sprite", keys, true );

		tempOrigin = origin + g_Engine.v_forward * 4 - g_Engine.v_right * 8 + g_Engine.v_up * 16;

		keys[ "origin" ] = tempOrigin.ToString();
		keys[ "rendercolor" ] = "255 0 0";

		g_EntityFuncs.CreateEntity( "env_sprite", keys, true );

		tempOrigin = origin + g_Engine.v_forward * 4 + g_Engine.v_right * 6;

		keys[ "origin" ] = tempOrigin.ToString();
		keys[ "rendercolor" ] = "0 128 255";
		keys[ "renderamt" ] = "100";
		keys[ "scale" ] = "1";

		g_EntityFuncs.CreateEntity( "env_sprite", keys, true );

		tempOrigin = origin + g_Engine.v_forward * 4 - g_Engine.v_right * 5 - g_Engine.v_up * 13;

		keys[ "origin" ] = tempOrigin.ToString();
		keys[ "rendercolor" ] = "255 0 0";
		keys[ "renderamt" ] = "120";

		g_EntityFuncs.CreateEntity( "env_sprite", keys, true );

		/*//toggled light (probably not possible)
		keys.deleteAll();

		keys[ "targetname" ] = "dgf_health_light_" + id;
		keys[ "_light" ] = "255 255 255 15";
		keys[ "style" ] = "0";
		keys[ "_fade" ] = "1.0";
		keys[ "_falloff" ] = "0";

		tempOrigin = origin + g_Engine.v_forward * 4 + g_Engine.v_right * 8 + g_Engine.v_up * 16;

		keys[ "origin" ] = tempOrigin.ToString();

		g_EntityFuncs.CreateEntity( "light", keys, true );

		keys[ "_light" ] = "255 0 0 20";

		tempOrigin = origin + g_Engine.v_forward * 4 - g_Engine.v_right * 8 + g_Engine.v_up * 16;

		keys[ "origin" ] = tempOrigin.ToString();

		g_EntityFuncs.CreateEntity( "light", keys, true );

		keys[ "_light" ] = "0 64 255 25";

		tempOrigin = origin + g_Engine.v_forward * 4 + g_Engine.v_right * 6;

		keys[ "origin" ] = tempOrigin.ToString();

		g_EntityFuncs.CreateEntity( "light", keys, true );

		keys[ "_light" ] = "255 0 0 20";

		tempOrigin = origin + g_Engine.v_forward * 4 - g_Engine.v_right * 5 - g_Engine.v_up * 13;

		keys[ "origin" ] = tempOrigin.ToString();

		g_EntityFuncs.CreateEntity( "light", keys, true );*/
	}
	else
	{
		keys.deleteAll();
		Math.MakeVectors( angles );

		Vector tempOrigin = origin + g_Engine.v_forward * 4 - g_Engine.v_right * 8 + g_Engine.v_up * 9;

		keys[ "origin" ] = tempOrigin.ToString();

		keys[ "targetname" ] = "dgf_hev_light_" + id;
		keys[ "rendercolor" ] = "58 200 55";
		keys[ "rendermode" ] = "3";
		keys[ "renderamt" ] = "80";
		keys[ "model" ] = "sprites/glow01.spr";
		keys[ "spawnflags" ] = "1";
		keys[ "scale" ] = "1";
		keys[ "framerate" ] = "10.0";

		g_EntityFuncs.CreateEntity( "env_sprite", keys, true );

		tempOrigin = origin + g_Engine.v_forward * 4 - g_Engine.v_right * 7 - g_Engine.v_up * 1;

		keys[ "origin" ] = tempOrigin.ToString();
		keys[ "rendercolor" ] = "181 186 69";

		g_EntityFuncs.CreateEntity( "env_sprite", keys, true );

		tempOrigin = origin + g_Engine.v_forward * 4 - g_Engine.v_right * 8 + g_Engine.v_up * 9;

		keys[ "origin" ] = tempOrigin.ToString();
		keys[ "rendercolor" ] = "255 0 0";
		keys[ "spawnflags" ] = "0";

		g_EntityFuncs.CreateEntity( "env_sprite", keys, true );

		/*//toggled light (probably not possible)
		keys.deleteAll();

		keys[ "targetname" ] = "dgf_hev_light_" + id;
		keys[ "_light" ] = "58 200 55 25";
		keys[ "style" ] = "0";
		keys[ "_fade" ] = "1.0";
		keys[ "_falloff" ] = "0";

		tempOrigin = origin + g_Engine.v_forward * 4 - g_Engine.v_right * 8 + g_Engine.v_up * 9;

		keys[ "origin" ] = tempOrigin.ToString();

		g_EntityFuncs.CreateEntity( "light", keys, true );

		//constant light (probably not possible)
		keys.deleteAll();

		keys[ "_light" ] = "255 0 0 20";
		keys[ "style" ] = "0";
		keys[ "_fade" ] = "1.0";
		keys[ "_falloff" ] = "0";

		tempOrigin = origin + g_Engine.v_forward * 4 - g_Engine.v_right * 8 + g_Engine.v_up * 9;

		keys[ "origin" ] = tempOrigin.ToString();

		g_EntityFuncs.CreateEntity( "light", keys, true );*/
	}
}

} //namespace ChargerReplacer END
