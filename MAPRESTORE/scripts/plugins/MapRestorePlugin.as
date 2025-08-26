//called restore because if the commands start with "restart" people might accidentally restart the map instead D:
//inspired by Counter-Strike and the AMXX plugin Restore Map by rtxA

#include "../maprestore/maprestore"

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nero" );
	g_Module.ScriptInfo.SetContactInfo( "https://www.reddit.com/r/svencoop/\n" );
}

void MapActivate()
{
	maprestore::Initialize();
}