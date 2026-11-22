#using scripts\common\ai\aitypes\shared\zombie\zombie_utils;
#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\mp\common\perks\zombie\zombie_perks;
#using scripts\mp\common\utility\perk;
#using scripts\mp\common\utility\weapon;
#namespace perk_samurais_sake;
function samurais_sake_kills_needed()
{
    return 30;
}
function samurais_sake_blast_radius()
{
    return 300;
}
autoexec samurais_sake_init()
{
    level thread samurais_sake_register_perk();
}
function samurais_sake_register_perk()
{
    level endon( #"game_ended" );
    level utility::flag_wait_all( "StartGameTypeCallbackFinished", "zombie_perks_init_complete" );
    if ( !level.zombie_perks_in_use )
    {
        return;
    }
    if ( !isdefined( level.cp_register ) || !isdefined( level.cp_register_native ) || !isdefined( level.cp_register_damage_mod ) )
    {
        samurais_sake_status( "custom perk manager unavailable" );
        return;
    }
    def = [];
    def["id"] = "samurais_sake";
    def["creator"] = "Zura";
    def["code"] = 97;
    def["name"] = "Samurai's Sake";
    def["description"] = "Melee hits reach further and ignore zombie armor, and you take 20% less damage holding a melee weapon. Every 30 melee kills unleashes an explosion around you.";
    def["icon_material"] = "ui_icon_perks_samurais_sake";
    def["price"] = 3000;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_samurais_sake_perk;
    def["on_take"] = &take_samurais_sake_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        samurais_sake_status( "registration rejected" );
        return;
    }
    level [[ level.cp_register_native ]]( "samurais_sake", level.cp_defs["samurais_sake"] );
    level [[ level.cp_register_damage_mod ]]( &samurais_sake_damage_mod );
    zombie_utils::register_zombie_agent_damage_callback( &samurais_sake_on_zombie_damage );
    level callback::add( #"on_ai_killed", &samurais_sake_on_kill );
    level thread samurais_sake_load_fx();
    samurais_sake_status( "registered" );
}
function samurais_sake_load_fx()
{
    level._effect[ "samurais_sake_blast" ] = loadfxasset( "vfx_jup_ob_gameplay_zm_weapons_perk_pdh_explo_med" );
}
function give_samurais_sake_perk()
{
    self quiet_perk_samurais_sake_client_dvar( @"bo7_cp_client_owned_samurais_sake", "1" );
    self perk::giveperk( "specialty_extendedmelee" );
}
function take_samurais_sake_perk( b_pause, str_perk, str_result, n_slot )
{
    self quiet_perk_samurais_sake_client_dvar( @"bo7_cp_client_owned_samurais_sake", "0" );
    self perk::removeperk( "specialty_extendedmelee" );
}
function samurais_sake_is_melee_weapon( w_weapon )
{
    return isdefined( w_weapon ) && weapon::iscacmeleeweapon( w_weapon );
}
function samurais_sake_damage_mod( sparams, n_damage )
{
    if ( !isdefined( n_damage ) || n_damage <= 0 || !self zombie_perks::has_perk( "specialty_samurais_sake" ) )
    {
        return n_damage;
    }
    if ( !samurais_sake_is_melee_weapon( self getcurrentweapon() ) )
    {
        return n_damage;
    }
    return n_damage * 0.8;
}
function samurais_sake_on_zombie_damage( params )
{
    if ( !isdefined( params ) || !isplayer( params.eattacker ) || !isdefined( params.metabonename ) )
    {
        return params.idamage;
    }
    if ( !( params.smeansofdeath === "MOD_MELEE" ) && !samurais_sake_is_melee_weapon( params.objweapon ) )
    {
        return params.idamage;
    }
    if ( !params.eattacker zombie_perks::has_perk( "specialty_samurais_sake" ) )
    {
        return params.idamage;
    }
    params.metabonename = undefined;
    return params.idamage;
}
function samurais_sake_on_kill( params )
{
    if ( !isdefined( params ) || !isplayer( params.eattacker ) || !params.eattacker zombie_perks::has_perk( "specialty_samurais_sake" ) )
    {
        return;
    }
    if ( !( params.smeansofdeath === "MOD_MELEE" ) && !samurais_sake_is_melee_weapon( params.sweapon ) )
    {
        return;
    }
    level.ss_player = params.eattacker;
    level.ss_player.ss_kills = ( level.ss_player.ss_kills ?? 0 ) + 1;
    if ( level.ss_player.ss_kills >= samurais_sake_kills_needed() )
    {
        level.ss_player.ss_kills = 0;
        level.ss_player thread samurais_sake_blast();
    }
    level.ss_player.ss_pct = int( level.ss_player.ss_kills * 100 / samurais_sake_kills_needed() );
}
function samurais_sake_blast()
{
    self endon( #"disconnect" );
    if ( !isalive( self ) )
    {
        return;
    }
    self.ss_blast_origin = self.origin;
    if ( isdefined( level._effect[ "samurais_sake_blast" ] ) ) playfx( level._effect[ "samurais_sake_blast" ], self.ss_blast_origin );
    self playrumbleonentity( "damage_heavy" );
    earthquake( 0.4, 0.6, self.ss_blast_origin, samurais_sake_blast_radius() );
    self.ss_hits = 0;
    foreach ( zombie in getaiarrayinradius( self.ss_blast_origin, samurais_sake_blast_radius() ) )
    {
        if ( !isdefined( zombie ) || !isalive( zombie ) || !isagent( zombie ) || ( isdefined( zombie.team ) && zombie.team == self.team ) )
        {
            continue;
        }
        zombie.ss_blast = zombie.health + 1;
        if ( isdefined( zombie.aicategory ) && zombie.aicategory != "normal" ) zombie.ss_blast = max( 1, ( zombie.maxhealth ?? zombie.health ) * 0.25 );
        zombie dodamage( zombie.ss_blast, zombie.origin, self, self, "MOD_EXPLOSIVE", "<explicitweaponnone>", "none", undefined, 65536 );
        self.ss_hits = self.ss_hits + 1;
    }
    samurais_sake_status( "blast hit " + self.ss_hits + " zombies" );
}
function samurais_sake_status( message )
{
    setdvar( @"bo7_cp_samurais_sake_runtime", message );
}
function quiet_perk_samurais_sake_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
