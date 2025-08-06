void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nero" );
	g_Module.ScriptInfo.SetContactInfo( "https://www.reddit.com/r/svencoop/\n" );
  
	@MedkitRegen::cvar_flRechargeRate = CCVar( "mr-rate", 1.0, "Rate of regen-ticks. (default: 1.0)", ConCommandFlag::AdminOnly );
	@MedkitRegen::cvar_iRechargeAmount = CCVar( "mr-amount", 5, "Amount of medkit-ammo to give. (default: 5)", ConCommandFlag::AdminOnly );

	if( MedkitRegen::g_pThinkFunc !is null )
		g_Scheduler.RemoveTimer( MedkitRegen::g_pThinkFunc );

	@MedkitRegen::g_pThinkFunc = g_Scheduler.SetInterval( "MedkitRegen", MedkitRegen::cvar_flRechargeRate.GetFloat() );
}

namespace MedkitRegen
{

CClientCommand mr_rate( "mr_rate", "Rate of regen-ticks. (default: 1.0)", @MRSettings );
CClientCommand mr_amount( "mr_amount", "Amount of medkit-ammo to give. (default: 5)", @MRSettings );

CScheduledFunction@ g_pThinkFunc = null;
CCVar@ cvar_flRechargeRate;
CCVar@ cvar_iRechargeAmount;

void MedkitRegen()
{
	for( int i = 1; i <= g_Engine.maxClients; ++i )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);

		if( pPlayer is null or !pPlayer.IsConnected() or !pPlayer.IsAlive() )
			continue;

		if( pPlayer.m_rgAmmo(g_PlayerFuncs.GetAmmoIndex("health")) <= (pPlayer.GetMaxAmmo("health") - cvar_iRechargeAmount.GetInt()) )
			pPlayer.m_rgAmmo( g_PlayerFuncs.GetAmmoIndex("health"), pPlayer.m_rgAmmo(g_PlayerFuncs.GetAmmoIndex("health")) + cvar_iRechargeAmount.GetInt() );
		
	}
}

void MRSettings( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

	if( g_PlayerFuncs.AdminLevel(pPlayer) < ADMIN_YES )
	{
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "That command is only for admins." );
		return;
	}

	if( args.ArgC() < 2 ) //If no args are supplied
	{
		if( args.Arg(0) == ".mr_rate" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"mr_rate\" is \"" + cvar_flRechargeRate.GetFloat() + "\"\n" );
		else if( args.Arg(0) == ".mr_amount" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"mr_amount\" is \"" + cvar_iRechargeAmount.GetInt() + "\"\n" );
	}
	else if( args.ArgC() == 2 ) //If one arg is supplied (value to set)
	{
		if( args.Arg(0) == ".mr_rate" and atof(args.Arg(1)) != cvar_flRechargeRate.GetFloat() )
		{
			cvar_flRechargeRate.SetFloat( atof(args.Arg(1)) );

			if( g_pThinkFunc !is null )
				g_Scheduler.RemoveTimer( g_pThinkFunc );

			@g_pThinkFunc = g_Scheduler.SetInterval( "MedkitRegen", cvar_flRechargeRate.GetFloat() );

			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"mr_rate\" changed to \"" + cvar_flRechargeRate.GetFloat() + "\"\n" );
		}
		else if( args.Arg(0) == ".mr_amount" and atoi(args.Arg(1)) != cvar_iRechargeAmount.GetInt() )
		{
			cvar_iRechargeAmount.SetInt( atoi(args.Arg(1)) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"mr_amount\" changed to \"" + cvar_iRechargeAmount.GetInt() + "\"\n" );
		}
	}
}


}
