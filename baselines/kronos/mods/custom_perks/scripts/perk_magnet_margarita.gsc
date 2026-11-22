#using scripts\common\callbacks;
#using scripts\common\powerups;
#using scripts\common\utility;
#using scripts\mp\armor;
#using scripts\mp\common\perks\zombie\zombie_perks;
#using scripts\mp\currency;
#namespace perk_magnet_margarita;
autoexec magnet_margarita_init()
{
    level thread magnet_margarita_register_perk();
}
function magnet_margarita_register_perk()
{
    level endon( #"game_ended" );
    level utility::flag_wait_all( "StartGameTypeCallbackFinished", "zombie_perks_init_complete" );
    if ( !level.zombie_perks_in_use )
    {
        return;
    }
    if ( !isdefined( level.cp_register ) || !isdefined( level.cp_register_native ) )
    {
        {}
        return;
    }
    def = [];
    def["id"] = "magnet_margarita";
    def["creator"] = "Gauty";
    def["code"] = 89;
    def["name"] = "Magnet Margarita";
    def["description"] = "Powerups drift toward you, stopping just short so you still choose when to grab them.";
    def["icon_material"] = "ui_icon_perks_magnet_margarita";
    def["price"] = 2000;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_magnet_margarita_perk;
    def["on_take"] = &take_magnet_margarita_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        {}
        return;
    }
    level [[ level.cp_register_native ]]( "magnet_margarita", level.cp_defs["magnet_margarita"] );
    level thread magnet_margarita_think();
    level.mm_lucky_drops = [ "full_ammo", "insta_kill", "bonus_points_team", "full_armor" ];
    level callback::add( #"on_ai_killed", &magnet_margarita_lucky_charm );
    level callback::add( #"player_powerup", &magnet_margarita_on_grab );
    if ( !istrue( level.mm_timeout_hooked ) )
    {
        level.mm_timeout_hooked = 1;
        level.mm_prev_timeout_override = level.powerup_timeout_override;
        level.powerup_timeout_override = &magnet_margarita_long_pour;
    }
    {}
}
function magnet_margarita_long_pour( n_lifetime )
{
    self.mm_lifetime = n_lifetime;
    if ( isdefined( level.mm_prev_timeout_override ) )
    {
        self.mm_lifetime = self [[ level.mm_prev_timeout_override ]]( self.mm_lifetime );
    }
    if ( isplayer( self ) && ( self.cp_magnet_margarita_major ?? 0 ) == 4 && self zombie_perks::has_perk( "specialty_magnet_margarita" ) )
    {
        self.mm_lifetime = self.mm_lifetime * 1.5;
    }
    return self.mm_lifetime;
}
function give_magnet_margarita_perk()
{
    self quiet_perk_magnet_margarita_client_dvar( @"bo7_cp_client_owned_magnet_margarita", "1" );
}
function take_magnet_margarita_perk( b_pause, str_perk, str_result, n_slot )
{
    self quiet_perk_magnet_margarita_client_dvar( @"bo7_cp_client_owned_magnet_margarita", "0" );
}
function magnet_margarita_lucky_charm( params )
{
    if ( !isdefined( params ) || !isplayer( params.eattacker ) || ( params.eattacker.cp_magnet_margarita_major ?? 0 ) != 1 )
    {
        return;
    }
    if ( !params.eattacker zombie_perks::has_perk( "specialty_magnet_margarita" ) || randomint( 1000 ) >= 25 )
    {
        return;
    }
    level thread powerups::powerup_drop( level.mm_lucky_drops[ randomint( level.mm_lucky_drops.size ) ], self.origin + ( 0, 0, 40 ) );
    {}
}
function magnet_margarita_has_minor( player, n )
{
    return ( player.cp_magnet_margarita_minor ?? 0 ) == n || ( player.cp_magnet_margarita_bonus ?? 0 ) == n;
}
function magnet_margarita_think()
{
    level endon( #"game_ended" );
    while ( true )
    {
        wait 0.05;
        level.mm_list = powerups::get_active_powerups();
        if ( !isdefined( level.mm_list ) )
        {
            continue;
        }
        foreach ( powerup in level.mm_list )
        {
            if ( !isdefined( powerup ) || powerup islinked() )
            {
                continue;
            }
            level.mm_target = undefined;
            level.mm_best = 999999;
            foreach ( player in level.players )
            {
                if ( !isdefined( player ) || !isalive( player ) || istrue( player.inlaststand ) || !player zombie_perks::has_perk( "specialty_magnet_margarita" ) )
                {
                    continue;
                }
                level.mm_dist = distance( powerup.origin, player.origin + ( 0, 0, 40 ) );
                level.mm_range = 1200;
                if ( ( player.cp_magnet_margarita_major ?? 0 ) == 2 ) level.mm_range = 2400;
                if ( level.mm_dist <= level.mm_range && level.mm_dist < level.mm_best )
                {
                    level.mm_best = level.mm_dist;
                    level.mm_target = player;
                }
            }
            if ( !isdefined( level.mm_target ) )
            {
                continue;
            }
            level.mm_stop = 64;
            if ( magnet_margarita_has_minor( level.mm_target, 2 ) ) level.mm_stop = 0;
            if ( level.mm_best <= level.mm_stop )
            {
                continue;
            }
            level.mm_speed = 15;
            if ( magnet_margarita_has_minor( level.mm_target, 1 ) ) level.mm_speed = 30;
            level.mm_step = min( level.mm_speed, level.mm_best - level.mm_stop );
            powerup moveto( powerup.origin + vectornormalize( level.mm_target.origin + ( 0, 0, 40 ) - powerup.origin ) * level.mm_step, 0.05 );
        }
    }
}
function magnet_margarita_on_grab( params )
{
    if ( !isdefined( params ) || !isplayer( params.player ) || !params.player zombie_perks::has_perk( "specialty_magnet_margarita" ) )
    {
        return;
    }
    if ( ( params.player.cp_magnet_margarita_major ?? 0 ) == 3 && randomint( 100 ) < 15 && isdefined( params.powerup ) )
    {
        level thread powerups::powerup_drop( level.mm_lucky_drops[ randomint( level.mm_lucky_drops.size ) ], params.powerup.origin + ( 30, 30, 0 ) );
        {}
    }
    if ( magnet_margarita_has_minor( params.player, 3 ) )
    {
        params.player currency::add_currency_amount( #"essence", 100, #"magnet_margarita_points" );
    }
    if ( magnet_margarita_has_minor( params.player, 4 ) && ( params.player.armorhealth ?? 0 ) > 0 && ( params.player.maxarmorhealth ?? 0 ) > 0 )
    {
        params.player armor::setarmorhealth( min( params.player.maxarmorhealth, params.player.armorhealth + params.player.maxarmorhealth * 0.25 ) );
    }
}
function quiet_perk_magnet_margarita_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
