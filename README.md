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
