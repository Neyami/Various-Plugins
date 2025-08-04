/*
* Author(s): Nero
* https://www.reddit.com/r/svencoop
*
* Console Command(s): 
*
* .langsave
* Forces playerLanguages.txt to save (if any changes have been made).
* Admin only.
*
*
* Chat Command(s)
*
* !lang languageCode
* Sets your language
* Public
*
* !lang menu
* Opens the language selection menu
* Public
*/

#include "../../ChatCommandManager" //By the svencoop team, should come with the game (svencoop\scripts\) my slightly modified version is case-insensitive.
#include "../../localization"

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nero" );
	g_Module.ScriptInfo.SetContactInfo( "https://www.reddit.com/r/svencoop/\n" );

	g_Hooks.RegisterHook( Hooks::Game::MapChange, @lang::MapChange );
	g_Hooks.RegisterHook( Hooks::Player::ClientSay, @lang::ClientSay );
	g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @lang::ClientPutInServer );
	@lang::g_ChatCommands = ChatCommandSystem::ChatCommandManager();

	lang::g_ChatCommands.AddCommand( ChatCommandSystem::ChatCommand("!lang", @lang::lang_cmd_handle, false, 1, "(languagecode/menu) - choose your preferred language.") );
	lang::Initialize( "scripts/plugins/data/lang/localization.txt" );
}

void MapInit()
{
	lang::g_dicStoredPlayerLanguages.deleteAll();
	lang::g_dicRecentLangChanges.deleteAll();

	lang::LoadPlayerLanguages();
}

namespace lang
{

const bool DEBUGMODE = true;

const string FILE_PLAYERLANG = "scripts/plugins/store/localization/playerLanguages.txt";

CClientCommand langsave( "langsave", "Forces playerLanguages.txt to save (if any changes have been made).", @SavePlayerLanguagesCMD );

ChatCommandSystem::ChatCommandManager@ g_ChatCommands = null;
dictionary g_dicStoredPlayerLanguages;
dictionary g_dicRecentLangChanges;

CTextMenu@ langMenu = null;

HookReturnCode MapChange( const string &in sNextMap )
{
	if( DEBUGMODE )
		g_Game.AlertMessage( at_notice, "[LOCALIZATION DEBUG]: MapChange\n" );

	UpdatePlayerLanguages();

	return HOOK_CONTINUE;
}

HookReturnCode ClientSay( SayParameters@ pParams )
{
	if( g_ChatCommands.ExecuteCommand( pParams ) )
		return HOOK_CONTINUE; //HOOK_HANDLED;

	return HOOK_CONTINUE;
}

HookReturnCode ClientPutInServer( CBasePlayer@ pPlayer )
{
	//Fix for when plugins are reloaded
	if( g_dicStoredPlayerLanguages.getSize() == 0 )
		LoadPlayerLanguages();

	string sSteamId = g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() );
	if( g_dicStoredPlayerLanguages.exists(sSteamId) )
		SetKV( pPlayer, KVN_LANGUAGE, int(g_dicStoredPlayerLanguages[sSteamId]) );

	return HOOK_CONTINUE;
}

void lang_cmd_handle( SayParameters@ pParams )
{
	pParams.ShouldHide = true;

	const CCommand@ args = pParams.GetArguments();
	CBasePlayer@ pPlayer = pParams.GetPlayer();

	if( args.ArgC() >= 2 ) // one arg supplied; menu, or languagecode
	{
		string szArg = args.Arg(1);

		if( DEBUGMODE )
			g_Game.AlertMessage( at_notice, "lang_cmd_handle: %1\n", szArg );

		if( szArg.ToLowercase() == "menu" )
			DisplayLangMenu( pPlayer );
		else
		{
			if( SetLanguage(pPlayer, szArg) )
				lang::ClientPrint( pPlayer, HUD_PRINTTALK, "LANGUAGE_SET", lang::getLanguageName(pPlayer, szArg) );
			else
				lang::ClientPrint( pPlayer, HUD_PRINTTALK, "LANGUAGE_UNKNOWN" );
		}
	}
}

bool SetLanguage( CBasePlayer@ pPlayer, string sLanguageCode )
{
	int iFindIndex = arrsLanguagesCodes.find( sLanguageCode );
	if( iFindIndex >= 0 )
	{
		string sLanguage = string( dicLanguageNames[arrsLanguagesCodes[iFindIndex]] );
		array<string> parsed = sLanguage.Split(",");

		SetKV( pPlayer, KVN_LANGUAGE, iFindIndex );

		string sSteamId = g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() );
		g_dicRecentLangChanges[sSteamId] = iFindIndex;
		g_dicStoredPlayerLanguages[sSteamId] = iFindIndex;

		return true;
	}

	return false;
}

void DisplayLangMenu( CBasePlayer@ pPlayer )
{
	@langMenu = CTextMenu( TextMenuPlayerSlotCallback(langMenuCallback) );
		langMenu.SetTitle( lang::getLocalizedText(pPlayer, "MENU_LANGUAGE") );

		for( uint i = 0; i < arrsLanguagesCodes.length(); ++i )
		{
			string sLanguageName = lang::getLanguageName( null, arrsLanguagesCodes[i], LANGNAME_ENGLISH );
			langMenu.AddItem( sLanguageName, any(arrsLanguagesCodes[i]) );
		}

	langMenu.Register();

	langMenu.Open( 0, 0, pPlayer );
}

void langMenuCallback( CTextMenu@ menu, CBasePlayer@ pPlayer, int iSlot, const CTextMenuItem@ pItem )
{
	//is this check necessary ??
	if( pItem !is null and pPlayer !is null )
	{
		string sLanguageCode;
		pItem.m_pUserData.retrieve( sLanguageCode );

		int iFindIndex = arrsLanguagesCodes.find( sLanguageCode );
		if( iFindIndex != LANG_INVALID )
		{
			if( SetLanguage(pPlayer, sLanguageCode) )
				lang::ClientPrint( pPlayer, HUD_PRINTTALK, "LANGUAGE_SET", lang::getLanguageName(pPlayer, sLanguageCode) );
			else
				lang::ClientPrint( pPlayer, HUD_PRINTTALK, "LANGUAGE_UNKNOWN" );
		}
	}
}

void LoadPlayerLanguages()
{
	File@ file = g_FileSystem.OpenFile( FILE_PLAYERLANG, OpenFile::READ );

	if( file !is null and file.IsOpen() )
	{
		while( !file.EOFReached() )
		{
			string sLine;
			file.ReadLine(sLine);
			//fix for linux
			string sFix = sLine.SubString( sLine.Length() - 1, 1 );
			if( sFix == " " or sFix == "\n" or sFix == "\r" or sFix == "\t" )
				sLine = sLine.SubString( 0, sLine.Length() - 1 );

			//comment
			if( sLine.SubString(0,1) == "#" or sLine.SubString(0,1) == ";" or sLine.SubString(0,2) == "//" or sLine.IsEmpty() )
				continue;

			if( !sLine.StartsWith("STEAM") )
				continue;

			array<string> parsed = sLine.Split(" ");
			if( parsed.length() >= 2 )
			{
				g_dicStoredPlayerLanguages[ parsed[0] ] = atoi( parsed[1] );
				if( DEBUGMODE )
					g_Game.AlertMessage( at_notice, "[LOCALIZATION DEBUG] Added languageIndex %1 to %2\n", parsed[1], parsed[0] );
			}
		}

		file.Close();
	}
	else
	{
		g_Game.AlertMessage( at_logged, "[LOCALIZATION] Installation error: cannot locate player languages file\n" );
		g_Game.AlertMessage( at_logged, "[LOCALIZATION] Which should be in %1\n", FILE_PLAYERLANG );
	}
}

void SavePlayerLanguagesCMD( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

	if( g_PlayerFuncs.AdminLevel(pPlayer) < ADMIN_YES )
	{
		ClientPrint( pPlayer, HUD_PRINTCONSOLE, "ADMIN_ONLY" );
		return;
	}

	if( g_dicRecentLangChanges.getSize() <= 0 )
	{
		ClientPrint( pPlayer, HUD_PRINTCONSOLE, "ADMIN_NOTHING" );
		return;
	}

	SavePlayerLanguages();
	g_dicRecentLangChanges.deleteAll();
}
 
void SavePlayerLanguages()
{
	//Fix for when plugins are reloaded
	if( g_dicStoredPlayerLanguages.getSize() == 0 )
		LoadPlayerLanguages();

	File@ file = g_FileSystem.OpenFile( FILE_PLAYERLANG, OpenFile::WRITE );
	if( file !is null and file.IsOpen() )
	{
		array<string> arrsKeys = g_dicStoredPlayerLanguages.getKeys();
		for( uint i = 0; i < arrsKeys.length(); ++i )
		{
			string sStringToWrite = arrsKeys[i] + " " + int(g_dicStoredPlayerLanguages[arrsKeys[i]]) + "\n";
			file.Write( sStringToWrite );

			if( DEBUGMODE )
				g_Game.AlertMessage( at_notice, "Wrote to file: %1\n", sStringToWrite );
		}

		file.Close();
	}
	else
	{
		g_Game.AlertMessage( at_logged, "[LOCALIZATION] Installation error: cannot locate player languages file\n" );
		g_Game.AlertMessage( at_logged, "[LOCALIZATION] Which should be in %1\n", FILE_PLAYERLANG );
	}
}

void UpdatePlayerLanguages()
{
	if( g_dicRecentLangChanges.getSize() <= 0 )
		return;

	SavePlayerLanguages();
}

void SetKV( CBaseEntity@ pEntity, const string &in sKey, const int &in iValue )
{
	if( pEntity is null ) return;

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	pCustom.SetKeyvalue( sKey, iValue );
}

} //namespace lang END

/* TODO
	Check for STEAM_ID_PENDING / STEAM_ID_LAN / BOT ??

	Auto-create playerLanguages.txt if it doesn't exist ??

	Add !lang languageName instead of languageCode ??
*/