// @augment major Cluster Bomb | Lethals split into 3 bomblets when they go off.
// @augment major Scavenger | Explosive kills have a 10% chance to refund a lethal.
// @augment major Concussive Force | Your explosions knock normal zombies over.
// @augment minor Short Fuse | Grenades explode 30% sooner.
// @augment minor Big Bang | Zombies next to anything your explosives hit take half the damage too.
// @augment minor Deep Pockets | Carry two extra lethals instead of one.
// @augment minor Shell Shock | Zombies that survive your explosions are stunned for 2 seconds.
#using scripts\common\ai\aitypes\shared\zombie\zombie_knockdown;
#using scripts\common\ai\aitypes\shared\zombie\zombie_utils;
#using scripts\common\status_effects\effect_stun;
#using scripts\common\utility;
#using scripts\mp\common\perks\zombie\zombie_perks;
#using scripts\mp\equipment;
#namespace perk_dam_a_nade;
autoexec dam_a_nade_init()
{
    level.dn_fx_bomblet = loadfxasset( "vfx_jup_ob_gameplay_zm_weapons_perk_pdh_explo_med" );
    level thread dam_a_nade_register_perk();
}
function dam_a_nade_register_perk()
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
    def["id"] = "dam_a_nade";
    def["creator"] = "Gauty";
    def["code"] = 90;
    def["name"] = "Dam-A-Nade";
    def["description"] = "Explosives deal 50% more damage. Carry one extra lethal and tactical, refilled at the end of every round.";
    def["icon_material"] = "ui_icon_perks_dam_a_nade";
    def["price"] = 2500;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_dam_a_nade_perk;
    def["on_take"] = &take_dam_a_nade_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        {}
        return;
    }
    level [[ level.cp_register_native ]]( "dam_a_nade", level.cp_defs["dam_a_nade"] );
    zombie_utils::register_zombie_agent_damage_callback( &dam_a_nade_on_zombie_damage );
    {}
}
function give_dam_a_nade_perk()
{
    self quiet_perk_dam_a_nade_client_dvar( @"bo7_cp_client_owned_dam_a_nade", "1" );
    self dam_a_nade_refill();
    self thread dam_a_nade_round_refill();
    self thread dam_a_nade_watch_throws();
}
function take_dam_a_nade_perk( b_pause, str_perk, str_result, n_slot )
{
    self quiet_perk_dam_a_nade_client_dvar( @"bo7_cp_client_owned_dam_a_nade", "0" );
    self notify( "dam_a_nade_stop" );
}
function dam_a_nade_has_minor( player, n )
{
    return isdefined( player ) && ( ( player.cp_dam_a_nade_minor ?? 0 ) == n || ( player.cp_dam_a_nade_bonus ?? 0 ) == n );
}
function dam_a_nade_is_explosive( mod )
{
    return isdefined( mod ) && ( mod == "MOD_GRENADE" || mod == "MOD_GRENADE_SPLASH" || mod == "MOD_EXPLOSIVE"
        || mod == "MOD_PROJECTILE" || mod == "MOD_PROJECTILE_SPLASH" );
}
function dam_a_nade_on_zombie_damage( params )
{
    if ( !isdefined( params.idamage ) || !isplayer( params.eattacker ) || !dam_a_nade_is_explosive( params.smeansofdeath ) )
    {
        return params.idamage;
    }
    if ( !params.eattacker zombie_perks::has_perk( "specialty_dam_a_nade" ) )
    {
        return params.idamage;
    }
    self.dn_damage = params.idamage * 1.5;
    self.dn_owner = params.eattacker;
    if ( self.dn_damage >= self.health )
    {
        if ( ( self.dn_owner.cp_dam_a_nade_major ?? 0 ) == 2 && randomint( 100 ) < 10 && gettime() >= ( self.dn_owner.dn_scav_next ?? 0 ) )
        {
            self.dn_owner.dn_scav_next = gettime() + 1000;
            self.dn_owner dam_a_nade_give_lethal();
        }
    }
    else
    {
        if ( ( self.dn_owner.cp_dam_a_nade_major ?? 0 ) == 3 && ( !isdefined( self.aicategory ) || self.aicategory == "normal" )
            && gettime() >= ( self.dn_knock_next ?? 0 ) && !self zombie_knockdown::is_knockdowned() )
        {
            self.dn_knock_next = gettime() + 2000;
            self zombie_knockdown::knockdown_ai( self.dn_owner.origin, 200 );
        }
        if ( dam_a_nade_has_minor( self.dn_owner, 4 ) && gettime() >= ( self.dn_stun_next ?? 0 ) )
        {
            self.dn_stun_next = gettime() + 3000;
            self thread effect_stun::stun( "dam_a_nade_shell_shock", 2, self.dn_owner, undefined, undefined, undefined );
        }
    }
    if ( dam_a_nade_has_minor( self.dn_owner, 2 ) && !istrue( level.dn_splashing ) )
    {
        level.dn_splashing = true;
        foreach ( other in getaiarrayinradius( self.origin, 70 ) )
        {
            if ( !isdefined( other ) || other == self || !isalive( other ) || !isagent( other ) || other.team == self.dn_owner.team )
            {
                continue;
            }
            if ( ( other.dn_splash_time ?? 0 ) == gettime() ) continue;
            other.dn_splash_time = gettime();
            other dodamage( params.idamage * 0.5, other.origin, self.dn_owner, self.dn_owner, "MOD_EXPLOSIVE", "<explicitweaponnone>", "none", undefined, 65536 );
        }
        level.dn_splashing = false;
    }
    return self.dn_damage;
}
function dam_a_nade_give_lethal()
{
    self.dn_ref = self equipment_mp::getcurrentequipment( "primary" );
    if ( !isdefined( self.dn_ref ) ) return;
    self.dn_cap = self dam_a_nade_cap( self.dn_ref, "primary" );
    self.dn_have = self equipment_mp::getequipmentammo( self.dn_ref );
    if ( !isdefined( self.dn_cap ) || !isdefined( self.dn_have ) || self.dn_have >= self.dn_cap ) return;
    self equipment_mp::setequipmentammo( self.dn_ref, self.dn_have + 1, self.dn_cap );
    {}
}
function dam_a_nade_cap( ref, slot )
{
    self.dn_base_max = self equipment_mp::getequipmentmaxammo( ref );
    if ( !isdefined( self.dn_base_max ) || self.dn_base_max <= 0 ) return undefined;
    if ( slot == "primary" && dam_a_nade_has_minor( self, 3 ) ) return self.dn_base_max + 2;
    return self.dn_base_max + 1;
}
function dam_a_nade_refill()
{
    self dam_a_nade_refill_slot( "primary" );
    self dam_a_nade_refill_slot( "secondary" );
    {}
}
function dam_a_nade_refill_slot( slot )
{
    self.dn_ref = self equipment_mp::getcurrentequipment( slot );
    if ( !isdefined( self.dn_ref ) )
    {
        return;
    }
    self.dn_cap = self dam_a_nade_cap( self.dn_ref, slot );
    if ( !isdefined( self.dn_cap ) )
    {
        return;
    }
    self equipment_mp::setequipmentammo( self.dn_ref, self.dn_cap, self.dn_cap );
}
function dam_a_nade_round_refill()
{
    self notify( "dam_a_nade_stop" );
    self endon( "dam_a_nade_stop" );
    self endon( #"disconnect" );
    level endon( #"game_ended" );
    while ( true )
    {
        level utility::waittill_any( "between_round_over", "round_end_finished", "on_round_end" );
        if ( gettime() < ( self.dn_next_refill ?? 0 ) || !isalive( self ) || !self zombie_perks::has_perk( "specialty_dam_a_nade" ) )
        {
            continue;
        }
        self.dn_next_refill = gettime() + 10000;
        self dam_a_nade_refill();
    }
}
function dam_a_nade_watch_throws()
{
    self endon( "dam_a_nade_stop" );
    self endon( #"disconnect" );
    level endon( #"game_ended" );
    while ( true )
    {
        self waittill( #"grenade_fire", grenade, objweapon );
        if ( !isdefined( grenade ) || !self zombie_perks::has_perk( "specialty_dam_a_nade" ) ) continue;
        if ( !self dam_a_nade_is_lethal( grenade, objweapon ) ) continue;
        if ( dam_a_nade_has_minor( self, 1 ) && isdefined( self.dn_throw_ref )
            && ( self.dn_throw_ref == "equip_frag" || self.dn_throw_ref == "equip_semtex" || self.dn_throw_ref == "equip_thermobaric_grenade" || issubstr( self.dn_throw_ref, "equip_cluster_grenade" ) ) )
        {
            level thread dam_a_nade_short_fuse( grenade );
        }
        if ( ( self.cp_dam_a_nade_major ?? 0 ) == 1 )
        {
            level thread dam_a_nade_cluster( grenade, self );
        }
    }
}
function dam_a_nade_is_lethal( grenade, objweapon )
{
    self.dn_throw_ref = self equipment_mp::getcurrentequipment( "primary" );
    if ( !isdefined( self.dn_throw_ref ) ) return false;
    if ( isdefined( grenade.equipmentref ) ) return grenade.equipmentref == self.dn_throw_ref;
    if ( !isdefined( objweapon ) || !isdefined( level.equipment ) || !isdefined( level.equipment.table[ self.dn_throw_ref ] ) ) return false;
    return isdefined( level.equipment.table[ self.dn_throw_ref ].objweapon ) && level.equipment.table[ self.dn_throw_ref ].objweapon.basename == objweapon.basename;
}
function dam_a_nade_short_fuse( grenade )
{
    grenade endon( #"death" );
    wait 2.4;
    if ( isdefined( grenade ) ) grenade detonate();
}
function dam_a_nade_cluster( grenade, owner )
{
    level endon( #"game_ended" );
    s = spawnstruct();
    s.pos = grenade.origin;
    while ( isdefined( grenade ) )
    {
        s.pos = grenade.origin;
        waitframe();
    }
    if ( !isdefined( owner ) ) return;
    s.i = 0;
    while ( s.i < 3 )
    {
        s.i = s.i + 1;
        s.angle = randomint( 360 );
        s.dist = 80 + randomint( 60 );
        s.drop = s.pos + ( cos( s.angle ) * s.dist, sin( s.angle ) * s.dist, 0 );
        level thread dam_a_nade_bomblet( s.drop, owner, 0.25 + 0.15 * s.i );
    }
}
function dam_a_nade_bomblet( pos, owner, delay )
{
    level endon( #"game_ended" );
    wait delay;
    if ( !isdefined( owner ) ) return;
    if ( isdefined( level.dn_fx_bomblet ) ) playfx( level.dn_fx_bomblet, pos );
    foreach ( zombie in getaiarrayinradius( pos, 120 ) )
    {
        if ( !isdefined( zombie ) || !isalive( zombie ) || !isagent( zombie ) || zombie.team == owner.team ) continue;
        zombie dodamage( max( 1, ( zombie.maxhealth ?? zombie.health ) * 0.2 ), pos, owner, owner, "MOD_EXPLOSIVE", "<explicitweaponnone>", "none", undefined, 65536 );
    }
}
function quiet_perk_dam_a_nade_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
