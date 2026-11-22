// @augment major Slick Slide | Slides are 15% faster and go 50% further.
// @augment major Peel Out | Sliding into zombies knocks them over.
// @augment major Toxic Spill | Slipped zombies are poisoned for 5 seconds.
// @augment minor Long Spill | The trail lasts twice as long (20 seconds).
// @augment minor Wide Spill | The trail is 50% wider.
// @augment minor Potent Peel | Slips deal 15% of max health instead of 10%.
// @augment minor Slide Rush | Move 10% faster for 3 seconds after a slide.
// @augment minor Quick Spill | Reduce the trail cooldown from 15 seconds to 10 seconds.
#using scripts\common\ai\aitypes\shared\zombie\zombie_knockdown;
#using scripts\common\utility;
#using scripts\mp\common\perks\zombie\zombie_perks;
#namespace perk_banana_colada;
autoexec banana_colada_init()
{
    level.bc_fx = loadfxasset( "vfx_t10_gameplay_zm_augment_gas_cloud_concealing" );
    level thread banana_colada_register_perk();
}
function banana_colada_register_perk()
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
    def["id"] = "banana_colada";
    def["creator"] = "Gauty";
    def["code"] = 94;
    def["name"] = "Banana Colada";
    def["description"] = "Sliding leaves a toxic trail behind you. Zombies that walk through it fall over and take damage. 15 second cooldown.";
    def["icon_material"] = "ui_icon_perks_zm_banana_colada";
    def["price"] = 2000;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_banana_colada_perk;
    def["on_take"] = &take_banana_colada_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        {}
        return;
    }
    level [[ level.cp_register_native ]]( "banana_colada", level.cp_defs["banana_colada"] );
    {}
}
function give_banana_colada_perk()
{
    self.bc_next_trail = 0;
    self.bc_slide_on = false;
    self.bc_trail_active = false;
    self quiet_perk_banana_colada_client_dvar( @"bo7_cp_client_owned_banana_colada", "1" );
    self thread banana_colada_slide_watch();
}
function take_banana_colada_perk( b_pause, str_perk, str_result, n_slot )
{
    self quiet_perk_banana_colada_client_dvar( @"bo7_cp_client_owned_banana_colada", "0" );
    self notify( "banana_colada_stop" );
}
function banana_colada_slide_watch()
{
    self notify( "banana_colada_stop" );
    self endon( "banana_colada_stop" );
    self endon( #"disconnect" );
    level endon( #"game_ended" );
    while ( true )
    {
        wait 0.05;
        if ( !self zombie_perks::has_perk( "specialty_banana_colada" ) )
        {
            return;
        }
        if ( !isalive( self ) || !self issprintsliding() )
        {
            if ( istrue( self.bc_slide_on ) && banana_colada_has_minor( self, 4 ) ) self thread banana_colada_slide_rush();
            self.bc_trail_active = false;
            self.bc_slide_on = false;
            self.bc_slide_last = undefined;
            self.bc_was_sliding = false;
            continue;
        }
        if (!istrue(self.bc_slide_on))
        {
            self.bc_trail_active = gettime() >= (self.bc_next_trail ?? 0);
            if (self.bc_trail_active)
            {
                self.bc_cooldown = 15000;
                if (banana_colada_has_minor(self, 5)) self.bc_cooldown = 10000;
                self.bc_next_trail = gettime() + self.bc_cooldown;
            }
        }
        self.bc_slide_on = true;
        self banana_colada_slick_slide();
        if (!istrue(self.bc_trail_active)) continue;
        if ( ( self.cp_banana_colada_major ?? 0 ) == 2 )
        {
            foreach ( zombie in getaiarrayinradius( self.origin, 56 ) ) zombie banana_colada_slip( self, self.origin );
        }
        if ( isdefined( self.bc_slide_last ) && distance2d( self.origin, self.bc_slide_last ) < 40 ) continue;
        self.bc_slide_last = self.origin;
        banana_colada_patch( self.origin, self );
    }
}
function banana_colada_slick_slide()
{
    if ( ( self.cp_banana_colada_major ?? 0 ) != 1 ) return;
    self.bc_vel = self getvelocity();
    self.bc_speed_now = length( ( self.bc_vel[0], self.bc_vel[1], 0 ) );
    if ( self.bc_speed_now < 1 ) return;
    self.bc_dir = vectornormalize( ( self.bc_vel[0], self.bc_vel[1], 0 ) );
    if ( !istrue( self.bc_was_sliding ) )
    {
        self.bc_was_sliding = true;
        self.bc_slide_speed = self.bc_speed_now * 1.15;
    }
    else if ( self.bc_speed_now < self.bc_slide_speed )
    {
        self.bc_slide_speed = self.bc_slide_speed - ( self.bc_slide_speed - self.bc_speed_now ) * ( 2.0 / 3.0 );
    }
    else
    {
        self.bc_slide_speed = self.bc_speed_now;
    }
    self setvelocity( self.bc_dir * self.bc_slide_speed + ( 0, 0, self.bc_vel[2] ) );
}
function banana_colada_patch( origin, owner )
{
    if ( !isdefined( level.bc_pos ) || level.bc_pos.size == 0 )
    {
        level.bc_pos = [];
        level.bc_end = [];
        level.bc_owner = [];
        level.bc_fxh = [];
        level.bc_rad = [];
    }
    level.bc_n = level.bc_pos.size;
    level.bc_pos[ level.bc_n ] = origin;
    level.bc_owner[ level.bc_n ] = owner;
    level.bc_end[ level.bc_n ] = gettime() + 10000;
    if ( banana_colada_has_minor( owner, 1 ) ) level.bc_end[ level.bc_n ] = gettime() + 20000;
    level.bc_rad[ level.bc_n ] = 40;
    if ( banana_colada_has_minor( owner, 2 ) ) level.bc_rad[ level.bc_n ] = 60;
    if ( isdefined( level.bc_fx ) )
        level.bc_fxh[ level.bc_n ] = playfx( level.bc_fx, origin + ( 0, 0, 2 ), undefined, undefined, undefined, undefined, 1 );
    if ( !istrue( level.bc_running ) ) level thread banana_colada_trail_think();
}
function banana_colada_trail_think()
{
    level endon( #"game_ended" );
    level.bc_running = true;
    while ( isdefined( level.bc_pos ) && level.bc_pos.size > 0 )
    {
        level.bc_live = 0;
        level.bc_i = -1;
        while ( level.bc_i + 1 < level.bc_pos.size )
        {
            level.bc_i++;
            if ( level.bc_end[ level.bc_i ] <= 0 ) continue;
            if ( gettime() >= level.bc_end[ level.bc_i ] )
            {
                level.bc_end[ level.bc_i ] = 0;
                if ( isdefined( level.bc_fxh[ level.bc_i ] ) ) killfx( level.bc_fxh[ level.bc_i ] );
                continue;
            }
            level.bc_live++;
            if ( !isdefined( level.bc_owner[ level.bc_i ] ) ) continue;
            foreach ( zombie in getaiarrayinradius( level.bc_pos[ level.bc_i ], level.bc_rad[ level.bc_i ] ?? 40 ) )
                zombie banana_colada_slip( level.bc_owner[ level.bc_i ], level.bc_pos[ level.bc_i ] );
        }
        if ( level.bc_live == 0 ) level.bc_pos = [];
        wait 0.25;
    }
    level.bc_running = false;
}
function banana_colada_slip( owner, pos )
{
    if ( !isagent( self ) || !isalive( self ) ) return;
    if ( isdefined( self.bc_next_slip ) && gettime() < self.bc_next_slip ) return;
    self.bc_next_slip = gettime() + 2000;
    self.bc_slip_damage = max( 1, ( self.maxhealth ?? self.health ) * 0.1 );
    if ( banana_colada_has_minor( owner, 3 ) ) self.bc_slip_damage = max( 1, ( self.maxhealth ?? self.health ) * 0.15 );
    self dodamage( self.bc_slip_damage, self.origin, owner, owner, "MOD_ELEMENTAL_TOXIC", "<explicitweaponnone>", "none", undefined, 65536 );
    if ( !isalive( self ) ) return;
    if ( ( !isdefined( self.aicategory ) || self.aicategory == "normal" ) && !self zombie_knockdown::is_knockdowned() )
        self zombie_knockdown::knockdown_ai( pos, 200 );
    self thread banana_colada_toxic_look();
    if ( ( owner.cp_banana_colada_major ?? 0 ) == 3 ) self thread banana_colada_poison( owner );
    if ( !istrue( level.bc_logged ) )
    {
        level.bc_logged = true;
        {}
    }
}
function banana_colada_toxic_look()
{
    self endon( #"death" );
    if ( !self getscriptablehaspart( "toxic_growth_fx" ) ) return;
    self utility::scriptable_setpartstate( #"toxic_growth_fx", #"on" );
    wait 3;
    self utility::scriptable_setpartstate( #"toxic_growth_fx", #"disable" );
}
function banana_colada_has_minor( player, n )
{
    return isdefined( player ) && ( ( player.cp_banana_colada_minor ?? 0 ) == n || ( player.cp_banana_colada_bonus ?? 0 ) == n );
}
function banana_colada_poison( owner )
{
    self endon( #"death" );
    if ( istrue( self.bc_poisoned ) ) return;
    self.bc_poisoned = true;
    self.bc_poison_n = 0;
    while ( self.bc_poison_n < 5 )
    {
        wait 1;
        self.bc_poison_n = self.bc_poison_n + 1;
        self dodamage( max( 1, ( self.maxhealth ?? self.health ) * 0.02 ), self.origin, owner, owner, "MOD_ELEMENTAL_TOXIC", "<explicitweaponnone>", "none", undefined, 65536 );
    }
    self.bc_poisoned = false;
}
function banana_colada_slide_rush()
{
    self endon( #"disconnect" );
    self.bc_rush_until = gettime() + 3000;
    self setmovespeedscale( 1.1 );
    wait 3;
    if ( isdefined( self ) && gettime() >= self.bc_rush_until ) self setmovespeedscale( 1 );
}
function quiet_perk_banana_colada_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
