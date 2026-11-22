// @augment major Shatter | Zombies frozen by the slam take double damage until they thaw.
// @augment major Aftershock | The slam leaves an ice patch for 8 seconds that slows zombies.
// @augment major Glacier | The slam also freezes special and elite zombies.
// @augment minor Cold Snap | Slam cooldown 4 seconds -> 2.5.
// @augment minor Wide Impact | Slam radius 30% larger.
// @augment minor Deep Freeze | The freeze lasts 5 seconds instead of 3.
// @augment minor Frostbite | Frozen zombies take 2% of their max health every second.
#using scripts\common\ai\aitypes\shared\zombie\zombie_utils;
#using scripts\common\status_effects\effect_slow;
#using scripts\common\utility;
#using scripts\mp\common\perks\zombie\zombie_perks;
#namespace perk_bull_ice_blast;
autoexec bull_ice_blast_init()
{
    level.bib_slam_fx = loadfxasset( "vfx_t10_gameplay_zm_weapons_frost_blast_explo" );
    level.bib_ice_fx = loadfxasset( "vfx_t10_gameplay_zm_weapons_fld_frost_blast_ice_slick" );
    level thread bull_ice_blast_register_perk();
}
function bull_ice_blast_register_perk()
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
    def["id"] = "bull_ice_blast";
    def["creator"] = "Gauty";
    def["code"] = 93;
    def["name"] = "Ice Cold Cola";
    def["description"] = "While in the air, press crouch to slam down. The impact damages and freezes nearby zombies for 3 seconds.";
    def["icon_material"] = "ui_icon_perks_ice_cold_cola";
    def["price"] = 2500;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_bull_ice_blast_perk;
    def["on_take"] = &take_bull_ice_blast_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        {}
        return;
    }
    level [[ level.cp_register_native ]]( "bull_ice_blast", level.cp_defs["bull_ice_blast"] );
    if ( isdefined( level.cp_register_damage_mod ) ) level [[ level.cp_register_damage_mod ]]( &bull_ice_blast_no_fall_damage, undefined, 1 );
    zombie_utils::register_zombie_agent_damage_callback( &bull_ice_blast_shatter );
    {}
}
function bull_ice_blast_has_minor( n )
{
    return ( self.cp_bull_ice_blast_minor ?? 0 ) == n || ( self.cp_bull_ice_blast_bonus ?? 0 ) == n;
}
function bull_ice_blast_shatter( params )
{
    if ( isdefined( params.idamage ) && gettime() < ( self.bib_shatter_until ?? 0 ) )
    {
        return params.idamage * 2;
    }
    return params.idamage;
}
function bull_ice_blast_no_fall_damage( sparams, n_damage )
{
    if ( isdefined( sparams.smeansofdeath ) && sparams.smeansofdeath == "MOD_FALLING" && gettime() <= ( self.bib_safe_until ?? 0 ) )
    {
        return 0;
    }
    return n_damage;
}
function give_bull_ice_blast_perk()
{
    self quiet_perk_bull_ice_blast_client_dvar( @"bo7_cp_client_owned_bull_ice_blast", "1" );
    self thread bull_ice_blast_watch();
}
function take_bull_ice_blast_perk( b_pause, str_perk, str_result, n_slot )
{
    self quiet_perk_bull_ice_blast_client_dvar( @"bo7_cp_client_owned_bull_ice_blast", "0" );
    self notify( "bull_ice_blast_stop" );
}
function bull_ice_blast_watch()
{
    self notify( "bull_ice_blast_stop" );
    self endon( "bull_ice_blast_stop" );
    self endon( #"disconnect" );
    level endon( #"game_ended" );
    self.bib_crouch_prev = true;
    while ( true )
    {
        wait 0.05;
        if ( !self zombie_perks::has_perk( "specialty_bull_ice_blast" ) )
        {
            return;
        }
        self.bib_crouch_now = self stancebuttonpressed();
        if ( isalive( self ) && !istrue( self.inlaststand ) && !self isonground() && istrue( self.bib_crouch_now ) && !istrue( self.bib_crouch_prev )
            && gettime() >= ( self.bib_ready_at ?? 0 ) )
        {
            self bull_ice_blast_slam();
        }
        self.bib_crouch_prev = self stancebuttonpressed();
    }
}
function bull_ice_blast_slam()
{
    self endon( #"disconnect" );
    self.bib_ready_at = gettime() + 4000;
    if ( self bull_ice_blast_has_minor( 1 ) ) self.bib_ready_at = gettime() + 2500;
    self.bib_radius = 220;
    if ( self bull_ice_blast_has_minor( 2 ) ) self.bib_radius = 286;
    self.bib_freeze = 3;
    if ( self bull_ice_blast_has_minor( 3 ) ) self.bib_freeze = 5;
    self.bib_major = self.cp_bull_ice_blast_major ?? 0;
    self.bib_land_by = gettime() + 2000;
    self.bib_ground = utility::groundpos( self.origin );
    self.bib_height = 0;
    if ( isdefined( self.bib_ground ) ) self.bib_height = max( 0, self.origin[2] - self.bib_ground[2] );
    self.bib_pct = min( 1, 0.25 + 0.25 * self.bib_height / 150 );
    {}
    self.bib_safe_until = gettime() + 2500;
    while ( isalive( self ) && !self isonground() && gettime() < self.bib_land_by )
    {
        self setvelocity( ( 0, 0, -1500 ) );
        waitframe();
    }
    self.bib_safe_until = gettime() + 500;
    if ( !isalive( self ) || !self isonground() )
    {
        return;
    }
    if ( isdefined( level.bib_slam_fx ) )
    {
        playfx( level.bib_slam_fx, self.origin );
    }
    self playrumbleonentity( "damage_heavy" );
    self.bib_hits = 0;
    foreach ( zombie in getaiarrayinradius( self.origin, self.bib_radius ) )
    {
        if ( !isdefined( zombie ) || !isalive( zombie ) || !isagent( zombie ) || ( isdefined( zombie.team ) && zombie.team == self.team ) )
        {
            continue;
        }
        zombie dodamage( max( 1, ( zombie.maxhealth ?? zombie.health ) * self.bib_pct ), zombie.origin, self, self, "MOD_ELEMENTAL_COLD", "<explicitweaponnone>", "none", undefined, 65536 );
        if ( isalive( zombie ) )
        {
            if ( self.bib_major == 3 )
                zombie effect_slow::slow( "bull_ice_blast", 0.0001, self.bib_freeze, self, undefined, 1, "cold" );
            else
                zombie effect_slow::slow( "bull_ice_blast", 0.0001, self.bib_freeze, self, undefined, undefined, "cold" );
            if ( self.bib_major == 1 ) zombie.bib_shatter_until = gettime() + self.bib_freeze * 1000;
            if ( self bull_ice_blast_has_minor( 4 ) ) zombie thread bull_ice_blast_frostbite( self, self.bib_freeze );
        }
        self.bib_hits = self.bib_hits + 1;
    }
    if ( self.bib_major == 2 ) level thread bull_ice_blast_aftershock( self.origin, self );
    {}
}
function bull_ice_blast_frostbite( owner, seconds )
{
    self endon( #"death" );
    self.bib_fb_left = seconds;
    while ( self.bib_fb_left > 0 )
    {
        wait 1;
        self.bib_fb_left = self.bib_fb_left - 1;
        if ( !isdefined( owner ) ) return;
        self dodamage( max( 1, ( self.maxhealth ?? self.health ) * 0.02 ), self.origin, owner, owner, "MOD_ELEMENTAL_COLD", "<explicitweaponnone>", "none", undefined, 65536 );
    }
}
function bull_ice_blast_aftershock( pos, owner )
{
    level endon( #"game_ended" );
    s = spawnstruct();
    if ( isdefined( level.bib_ice_fx ) ) s.fx = playfx( level.bib_ice_fx, pos + ( 0, 0, 2 ), undefined, undefined, undefined, undefined, 1 );
    s.end = gettime() + 8000;
    while ( gettime() < s.end )
    {
        foreach ( zombie in getaiarrayinradius( pos, 200 ) )
        {
            if ( !isdefined( zombie ) || !isalive( zombie ) || !isagent( zombie ) || ( isdefined( owner ) && zombie.team == owner.team ) ) continue;
            zombie effect_slow::slow( "bull_ice_blast_aftershock", 0.5, 1, owner, undefined, undefined, "cold" );
        }
        wait 0.5;
    }
    if ( isdefined( s.fx ) ) killfx( s.fx );
}
function quiet_perk_bull_ice_blast_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
