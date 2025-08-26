Various plugins that I have made for Sven Co-op.

<BR>

# Airstrike
[Video](https://youtu.be/PXhFxZDNsbg)
* COMMANDS
    * `.airstrike help`
    * `.airstrike <amount 1-25> <type 0-12> <owner 0/1>` - Launches projectiles from the sky.

* CVARS
    * `.airstrike_anywhere` - Allow airstrikes anywhere or only where there is sky? (default: 0)

    * `.airstrike_delay` - Minimum delay in seconds between airstrikes. (default: 0.5)

    * `.airstrike_max` - Maximum of projectiles fired by airstrike. (default: 25)

    * `.airstrike_minspread` - Minimum projectile spread. (default: -150)

    * `.airstrike_maxspread` - Maximum projectile spread. (default: 150)

<BR>

# Kick

`.kick` - Kick enemies.

`.kick 0` - Kick with no damage.

<BR>

# Charger Replacer
[Video](https://youtu.be/-gEXcbFcpwI)

Automatically replaces all vanilla health and armor chargers on the map with any custom model and optionally sounds.

Go to the Customization part of the script and change the model to a custom model you have, preferably one that is the same size as the vanilla ones, or the lights will be off.

The lights are customized for a pair of charger models made by DGF: [Download](https://gamebanana.com/mods/167509)

The plugin can be disabled on certain maps by modifying `g_CRDisabledMaps`

<BR>

# Localization
[Video](https://youtu.be/4DtyB2vqBKY)  

The plugin handles saving and loading of player's chosen language.  

CONSOLE COMMAND(S):  

* `.langsave` - Forces playerLanguages.txt to save (if any changes have been made). - Admin only.  


CHAT COMMAND(S):  

* `!lang languageCode` - Sets your language - Public.  
* `!lang menu` - Opens the language selection menu - Public.  

1) Include scripts\localization in your script/plugin.  
2) Modify the three lists according to your wishes (enum lang_e, arrsLanguagesCodes, dicLanguageNames)  

3) Read the example language file in scripts\plugins\data\lang\localization.txt  
4) If your script is a map script, the file needs to be in scripts\maps\data\lang\  

5) Call lang::Initialize( "scripts/plugins/data/lang/langfile.txt" );
6) in PluginInit or MapInit  

FUNCTIONS:  

* `ClientPrint( CBasePlayer@ pPlayer, HUD hud, const string &in szFormat, string &in a1 = "", ... , string &in a8 = "" )`  
* `ClientPrintAll( CBasePlayer@ pPlayer, HUD hud, const string &in szFormat, string &in a1 = "", ... , string &in a8 = "" )`  
Does what the g_PlayerFuncs functions do but with snprintf formatting.  
USE DOLLARSIGNS $ INSTEAD OF PERCENT % IN szFormat.  
Up to 8 variables, can be any data type (probably :heh:)  
eg: `lang::ClientPrintAll( HUD_PRINTCENTER, "$1\n\n$2 : $3 $4 : $5", "ROUND_VAMPIRESWIN", "TITLE_SLAYER", GetTeamScore(TEAM_SLAYER), "TITLE_VAMPIRE", GetTeamScore(TEAM_VAMPIRE) );`  
eg: `lang::ClientPrintAll( HUD_PRINTNOTIFY, "NOTIF_STAKED", pPlayer.pev.netname, "Vampire Santa Claus" );`  

* `FormatMessage( CBasePlayer@ pPlayer, string &out szOutBuffer, const string &in szFormat, string &in a1 = "", ... , string &in a8 = "" )`  
Same rules as the ClientPrint functions, szOutBuffer is the resulting string.  

* `getLocalizedText( CBasePlayer@ pPlayer, const string &in sString )`  
Directly access one of the entries in the language file.  
eg: `teamMenu.SetTitle( lang::getLocalizedText(pPlayer, "MENU_TEAM") );`  

* `getLanguageName( CBasePlayer@ pPlayer, const string &in sLanguageCode, int iNameType = LANGNAME_ENGLISH )`  
Look at the enum langname_e and the dictionary dicLanguageNames for the explanation.  

<BR>

# MAPRESTORE

1) Include the maprestore script in your plugin / script.
2) `maprestore::Initialize();` in MapActivate (or MapInit ??)

* Commands  
`restore classname` - Restores all entities with the supplied classname. - Admin only.  
`restore *` - Restores all restorable entities. - Admin only.

* Functions  
`maprestore::RestoreAll();`  
`maprestore::RestoreByClass( sClassname );`  


# Medkit Regen

* Commands  
`.mr_rate` - Checks/sets regen rate (in seconds).  
`.mr_amount` - Checks/sets regen amount.

* CVars (can be added to map.cfg)  
`as_command mr-rate #`  
`as_command mr-amount #`

<BR>

