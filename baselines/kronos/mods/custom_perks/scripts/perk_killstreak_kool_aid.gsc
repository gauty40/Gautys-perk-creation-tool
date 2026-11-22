// @augment major Streak Feed | Kills made by your killstreaks count double toward the next one.
// @augment major Double Batch | Each reward has a 20% chance to be two killstreaks.
// @augment major Oh Yeah! | Earning a killstreak blasts every zombie within 300 units of you.
// @augment minor Refill | Needs 120 kills instead of 150.
// @augment minor Brain Freeze | Critical kills count double.
// @augment minor Sugar Rush | Earning a killstreak refills your ammo.
// @augment minor Tall Glass | Earning a killstreak gives 1000 Essence.
#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\mp\common\killstreaks\killstreaks;
#using scripts\mp\common\perks\zombie\zombie_perks;
#using scripts\mp\currency;
#namespace perk_killstreak_kool_aid;
autoexec killstreak_kool_aid_init()
{
    level thread killstreak_kool_aid_register_perk();
}
function killstreak_kool_aid_register_perk()
{
    level endon( #"game_ended" );
    level utility::flag_wait_all( "StartGameTypeCallbackFinished", "zombie_perks_init_complete" );
    if ( !level.zombie_perks_in_use )
    {
        return;
    }
    if ( !isdefined( level.cp_register ) || !isdefined( level.cp_register_native ) )
    {
        killstreak_kool_aid_status( "custom perk manager unavailable" );
        return;
    }
    def = [];
    def["id"] = "killstreak_kool_aid";
    def["creator"] = "Gauty";
    def["code"] = 95;
    def["name"] = "Killstreak Kool-Aid";
    def["description"] = "Every 150 kills earns you a random killstreak for free.";
    def["icon_material"] = "ui_icon_perks_killstreak_kool_aid";
    def["price"] = 3000;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_killstreak_kool_aid_perk;
    def["on_take"] = &take_killstreak_kool_aid_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        killstreak_kool_aid_status( "registration rejected" );
        return;
    }
    level [[ level.cp_register_native ]]( "killstreak_kool_aid", level.cp_defs["killstreak_kool_aid"] );
    level.kka_base_need = 150;
    level callback::add( #"on_ai_killed", &killstreak_kool_aid_on_kill );
    killstreak_kool_aid_status( "registered; streaks on this map: " + killstreak_kool_aid_list_text() );
}
function give_killstreak_kool_aid_perk()
{
    self quiet_perk_killstreak_kool_aid_client_dvar( @"bo7_cp_client_owned_killstreak_kool_aid", "1" );
    if ( ( self.kka_pending ?? 0 ) > 0 ) self thread killstreak_kool_aid_deliver();
}
function take_killstreak_kool_aid_perk( b_pause, str_perk, str_result, n_slot )
{
    self quiet_perk_killstreak_kool_aid_client_dvar( @"bo7_cp_client_owned_killstreak_kool_aid", "0" );
}
function killstreak_kool_aid_has_minor( player, n )
{
    return isdefined( player ) && ( ( player.cp_killstreak_kool_aid_minor ?? 0 ) == n || ( player.cp_killstreak_kool_aid_bonus ?? 0 ) == n );
}
function killstreak_kool_aid_on_kill( params )
{
    if ( !isdefined( params ) || !isdefined( params.eattacker ) )
    {
        return;
    }
    level.kka_player = undefined;
    level.kka_from_streak = false;
    if ( isplayer( params.eattacker ) )
    {
        level.kka_player = params.eattacker;
    }
    else if ( isdefined( params.eattacker.owner ) && isplayer( params.eattacker.owner ) )
    {
        level.kka_player = params.eattacker.owner;
        level.kka_from_streak = true;
    }
    if ( !isdefined( level.kka_player ) || !level.kka_player zombie_perks::has_perk( "specialty_killstreak_kool_aid" ) )
    {
        return;
    }
    level.kka_add = 1;
    if ( level.kka_from_streak && ( level.kka_player.cp_killstreak_kool_aid_major ?? 0 ) == 1 ) level.kka_add = 2;
    if ( killstreak_kool_aid_has_minor( level.kka_player, 2 ) && isdefined( params.shitloc )
        && ( params.shitloc == "head" || params.shitloc == "helmet" || params.shitloc == "neck" ) )
    {
        level.kka_add = level.kka_add * 2;
    }
    level.kka_player.kka_kills = ( level.kka_player.kka_kills ?? 0 ) + level.kka_add;
    level.kka_player.kka_need = level.kka_base_need ?? 150;
    if ( killstreak_kool_aid_has_minor( level.kka_player, 1 ) ) level.kka_player.kka_need = int( level.kka_player.kka_need * 0.8 );
    if ( level.kka_player.kka_kills < level.kka_player.kka_need )
    {
        level.kka_player.kka_pct = int( level.kka_player.kka_kills * 100 / level.kka_player.kka_need );
        return;
    }
    level.kka_player.kka_kills = level.kka_player.kka_kills - level.kka_player.kka_need;
    level.kka_player.kka_pct = int( level.kka_player.kka_kills * 100 / level.kka_player.kka_need );
    level.kka_player.kka_pending = ( level.kka_player.kka_pending ?? 0 ) + 1;
    if ( ( level.kka_player.cp_killstreak_kool_aid_major ?? 0 ) == 2 && randomint( 100 ) < 20 )
    {
        level.kka_player.kka_pending = level.kka_player.kka_pending + 1;
    }
    level.kka_player thread killstreak_kool_aid_on_earn();
    level.kka_player thread killstreak_kool_aid_deliver();
}
function killstreak_kool_aid_on_earn()
{
    self endon( #"disconnect" );
    self playrumbleonentity( "damage_heavy" );
    if ( ( self.cp_killstreak_kool_aid_major ?? 0 ) == 3 && isalive( self ) )
    {
        foreach ( zombie in getaiarrayinradius( self.origin, 300 ) )
        {
            if ( !isdefined( zombie ) || !isalive( zombie ) || !isagent( zombie ) || ( isdefined( zombie.team ) && zombie.team == self.team ) )
            {
                continue;
            }
            zombie.kka_blast = zombie.health + 1;
            if ( isdefined( zombie.aicategory ) && zombie.aicategory != "normal" ) zombie.kka_blast = max( 1, ( zombie.maxhealth ?? zombie.health ) * 0.25 );
            zombie dodamage( zombie.kka_blast, zombie.origin, self, self, "MOD_EXPLOSIVE", "<explicitweaponnone>", "none", undefined, 65536 );
        }
    }
    if ( killstreak_kool_aid_has_minor( self, 3 ) )
    {
        foreach ( w_weapon in self getweaponslistprimaries() )
        {
            self givemaxammo( w_weapon );
        }
    }
    if ( killstreak_kool_aid_has_minor( self, 4 ) )
    {
        self currency::add_currency_amount( #"essence", 1000, #"killstreak_kool_aid_points" );
    }
}
function killstreak_kool_aid_deliver()
{
    self endon( #"disconnect" );
    level endon( #"game_ended" );
    self notify( "kka_deliver" );
    self endon( "kka_deliver" );
    while ( ( self.kka_pending ?? 0 ) > 0 )
    {
        if ( isalive( self ) && !istrue( self.inlaststand ) && !self killstreak_kool_aid_slot_full() )
        {
            self.kka_streak = killstreak_kool_aid_pick();
            if ( !isdefined( self.kka_streak ) )
            {
                killstreak_kool_aid_status( "no killstreaks are loaded on this map; " + self.kka_pending + " reward(s) waiting" );
                wait 5;
                continue;
            }
            self.kka_pending = self.kka_pending - 1;
            self killstreaks::awardkillstreak( self.kka_streak, "other", undefined, undefined, undefined, 1 );
            killstreak_kool_aid_status( "gave " + killstreak_kool_aid_name( self.kka_streak ) + "; " + self.kka_pending + " still waiting" );
        }
        wait 1;
    }
}
function killstreak_kool_aid_slot_full()
{
    if ( !isdefined( self.streakdata ) || !isdefined( self.streakdata.streaks ) )
    {
        return false;
    }
    self.kka_slot = self.streakdata.streaks[ 1 ];
    return isdefined( self.kka_slot ) && isdefined( self.kka_slot.available ) && self.kka_slot.available == 1;
}
function killstreak_kool_aid_pick()
{
    if ( !isdefined( level.streakglobals ) || !isdefined( level.streakglobals.streakbundles ) )
    {
        return undefined;
    }
    level.kka_names = getarraykeys( level.streakglobals.streakbundles );
    if ( level.kka_names.size == 0 )
    {
        return undefined;
    }
    return level.kka_names[ randomint( level.kka_names.size ) ];
}
function killstreak_kool_aid_name( streak )
{
    if ( isstring( streak ) ) return streak;
    return "(hashed name)";
}
function killstreak_kool_aid_list_text()
{
    if ( !isdefined( level.streakglobals ) || !isdefined( level.streakglobals.streakbundles ) )
    {
        return "none loaded yet";
    }
    level.kka_list = "";
    foreach ( key, bundle in level.streakglobals.streakbundles )
    {
        level.kka_list = level.kka_list + killstreak_kool_aid_name( key ) + " ";
    }
    return level.kka_list;
}
function killstreak_kool_aid_status( message )
{
    setdvar( @"bo7_cp_killstreak_kool_aid_runtime", message );
}
function quiet_perk_killstreak_kool_aid_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
