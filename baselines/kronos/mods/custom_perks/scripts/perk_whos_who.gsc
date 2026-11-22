// @augment major Fresh Start | If your clone isn't revived in time, you live on as a fresh spawn instead of dying.
// @augment major Hand-Me-Down | Your ghost pistol has the Pack-a-Punch level and rarity of the gun you were holding.
// @augment minor Extra Time | 1.5x as long to revive your clone (90 seconds).
#using scripts\common\utility;
#using scripts\mp\common\perks\zombie\zombie_perks;
#using scripts\mp\common\utility\damage;
#using scripts\mp\loot\common_item_weapon;
#using scripts\mp\pack_a_punch;
#using scripts\mp\common\utility\weapon_utility;
#using scripts\mp\objidpoolmanager;
#using scripts\mp\zm\zm_utility;
#namespace perk_whos_who;
function whos_who_clone_seconds()
{
    return 60;
}
function whos_who_revive_seconds()
{
    return 1.5;
}
function whos_who_has_minor( player, n )
{
    return isdefined( player ) && ( ( player.cp_whos_who_minor ?? 0 ) == n || ( player.cp_whos_who_bonus ?? 0 ) == n );
}
autoexec whos_who_init()
{
    level thread whos_who_register_perk();
}
function whos_who_register_perk()
{
    level endon( #"game_ended" );
    level utility::flag_wait_all( "StartGameTypeCallbackFinished", "zombie_perks_init_complete" );
    if ( !level.zombie_perks_in_use )
    {
        return;
    }
    if ( !isdefined( level.cp_register ) || !isdefined( level.cp_register_native ) || !isdefined( level.cp_register_damage_mod ) )
    {
        whos_who_status( "custom perk manager unavailable" );
        return;
    }
    def = [];
    def["id"] = "whos_who";
    def["creator"] = "Gauty";
    def["code"] = 96;
    def["name"] = "Who's Who";
    def["description"] = "Instead of going down, leave a clone behind with your weapons and perks and escape as a ghost. Revive your clone within 60 seconds to get them back, or die. Once per round.";
    def["icon_material"] = "ui_icon_perks_whos_who";
    def["price"] = 2000;
    def["drink_from"] = "specialty_quickrevive";
    def["on_give"] = &give_whos_who_perk;
    def["on_take"] = &take_whos_who_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        whos_who_status( "registration rejected" );
        return;
    }
    level [[ level.cp_register_native ]]( "whos_who", level.cp_defs["whos_who"] );
    level [[ level.cp_register_damage_mod ]]( &whos_who_damage_mod, 1 );
    level thread whos_who_round_counter();
    whos_who_status( "registered" );
}
function whos_who_round_counter()
{
    level endon( #"game_ended" );
    level.ww_round = 0;
    while ( true )
    {
        level utility::waittill_any( "between_round_over", "round_end_finished", "on_round_end" );
        level.ww_round = level.ww_round + 1;
    }
}
function give_whos_who_perk()
{
    self quiet_perk_whos_who_client_dvar( @"bo7_cp_client_owned_whos_who", "1" );
}
function take_whos_who_perk( b_pause, str_perk, str_result, n_slot )
{
    self quiet_perk_whos_who_client_dvar( @"bo7_cp_client_owned_whos_who", "0" );
}
function whos_who_damage_mod( sparams, n_damage )
{
    if ( !isdefined( n_damage ) || n_damage <= 0 )
    {
        return n_damage;
    }
    if ( gettime() < ( self.ww_safe_until ?? 0 ) )
    {
        return 0;
    }
    if ( istrue( self.ww_active ) || istrue( self.inlaststand ) || !self zombie_perks::has_perk( "specialty_whos_who" ) )
    {
        return n_damage;
    }
    if ( isdefined( self.ww_used_round ) && self.ww_used_round == ( level.ww_round ?? 0 ) )
    {
        return n_damage;
    }
    self.ww_health_damage = n_damage;
    if ( isdefined( level.cp_preview_health_damage ) )
    {
        self.ww_health_damage = self [[ level.cp_preview_health_damage ]]( sparams, n_damage );
    }
    if ( self.health - self.ww_health_damage > 0 )
    {
        return n_damage;
    }
    self.ww_active = true;
    self.ww_used_round = level.ww_round ?? 0;
    self.ww_safe_until = gettime() + 2000;
    self thread whos_who_activate();
    return 0;
}
function whos_who_activate()
{
    self endon( #"disconnect" );
    self.ww_body_origin = self.origin;
    self.ww_body_angles = self.angles;
    level.ww_trail = "";
    whos_who_status( "triggered" );
    self thread whos_who_clone_think();
    zombie_perks::take_perk( "specialty_whos_who" );
    self thread whos_who_stash_perks();
    self thread whos_who_stash_weapons();
    self thread whos_who_spawn_clone();
    self thread whos_who_marker();
    waitframe();
    self.ww_escape = self whos_who_find_escape();
    if ( isdefined( self.ww_escape ) )
    {
        self setorigin( self.ww_escape );
    }
    if ( isdefined( self.maxhealth ) ) self.health = self.maxhealth;
    whos_who_status( "teleported " + isdefined( self.ww_escape ) );
    self thread whos_who_ghost_effects( true );
}
function whos_who_stash_perks()
{
    self.ww_perks = [];
    if ( !isdefined( self.perks_active ) )
    {
        return;
    }
    foreach ( ref in self.perks_active )
    {
        if ( !isdefined( ref ) || ref == "specialty_choice" || ref == "specialty_whos_who" || arraycontains( self.ww_perks, ref ) )
        {
            continue;
        }
        if ( isdefined( self.perma_perks ) && ( arraycontains( self.perma_perks, ref ) || ( isstring( ref ) && arraycontains( self.perma_perks, getxhash( ref ) ) ) ) )
        {
            continue;
        }
        self.ww_perks[ self.ww_perks.size ] = ref;
    }
    foreach ( ref in self.ww_perks )
    {
        zombie_perks::take_perk( ref );
    }
    whos_who_status( "perks stashed " + self.ww_perks.size );
}
function whos_who_stash_weapons()
{
    self.ww_prev_saved = self.a_saved_weapons;
    self.a_saved_weapons = undefined;
    self zm_utility::save_curr_loadout( "whos_who" );
    self.ww_loadout = self.a_saved_weapons;
    self.a_saved_weapons = self.ww_prev_saved;
    whos_who_status( "loadout saved " + isdefined( self.ww_loadout ) );
    self zm_utility::take_zombie_loadout_weapons( 0, 0, 1, 1, 1, 1, 0 );
    whos_who_status( "weapons taken" );
    self.ww_pistol = weapon_utility::makeweaponwithdefaults( level.laststandweapon ?? "t10_pi_p14_mable_mp" );
    if ( isdefined( self.ww_pistol ) )
    {
        self giveweapon( self.ww_pistol, undefined, 0, -1, 1 );
        self assignweaponprimaryslot( self.ww_pistol );
        self givemaxammo( self.ww_pistol );
        self switchtoweaponimmediate( self.ww_pistol );
    }
    whos_who_status( "pistol given " + isdefined( self.ww_pistol ) );
    if ( ( self.cp_whos_who_major ?? 0 ) == 2 && isdefined( self.ww_pistol ) && isdefined( self.ww_loadout ) )
    {
        self.ww_source = self.ww_loadout[ "primary" ];
        if ( isdefined( self.ww_loadout[ "secondary" ][ "weapon" ] ) && isdefined( self.old_weapon_obj ) && self.ww_loadout[ "secondary" ][ "weapon" ] == self.old_weapon_obj )
        {
            self.ww_source = self.ww_loadout[ "secondary" ];
        }
        if ( isdefined( self.ww_source[ "weapon" ] ) )
        {
            if ( ( self.ww_source[ "pap_level" ] ?? 0 ) > 0 ) self pack_a_punch::set_pap_level( self.ww_pistol, self.ww_source[ "pap_level" ], 1 );
            if ( isdefined( self.ww_source[ "rarity" ] ) ) self item_weapon::function_40e1cbd0e1f47d1a( self.ww_pistol, self.ww_source[ "rarity" ], 1 );
            whos_who_status( "hand-me-down pap " + ( self.ww_source[ "pap_level" ] ?? 0 ) + " rarity " + ( self.ww_source[ "rarity" ] ?? 0 ) );
        }
    }
}
function whos_who_restore()
{
    self thread whos_who_restore_weapons();
    self thread whos_who_restore_perks();
}
function whos_who_restore_weapons()
{
    if ( !isdefined( self.ww_loadout ) )
    {
        whos_who_status( "no saved loadout to restore" );
        return;
    }
    self.ww_prev_saved = self.a_saved_weapons;
    self.a_saved_weapons = self.ww_loadout;
    self zm_utility::restore_saved_loadout( undefined, 1, 1, 1, 0, 1 );
    self.a_saved_weapons = self.ww_prev_saved;
    self.ww_loadout = undefined;
    whos_who_status( "weapons restored" );
}
function whos_who_restore_perks()
{
    if ( !isdefined( self.ww_perks ) ) return;
    foreach ( ref in self.ww_perks )
    {
        if ( !self zombie_perks::has_perk( ref ) ) self zombie_perks::give_perk( ref, 0 );
    }
    whos_who_status( "perks restored " + self.ww_perks.size );
}
function whos_who_spawn_clone()
{
    self.ww_clone = spawn( "script_model", self.ww_body_origin );
    self.ww_clone.angles = ( 0, self.ww_body_angles[ 1 ], 0 );
    self.ww_clone.team = self.team;
    self.ww_clone.owner = self;
    whos_who_status( "clone spawned" );
    self.ww_clone thread whos_who_dress_clone( self );
}
function whos_who_dress_clone( owner )
{
    self setentityowner( owner );
    self setotherent( owner );
    if ( isdefined( owner.operatorcustomization ) && isdefined( owner.operatorcustomization.skinref ) )
    {
        self SetMoverTransientAvatar( owner.operatorcustomization.skinref, "super_combat_hologram_aether_shadow_clone" );
        whos_who_status( "clone avatar set" );
    }
    else
    {
        whos_who_status( "no operator skin for the clone avatar" );
    }
    self scriptmodelplayanim( "mp_stand_melee_hit_01_me_fists", "combatHolo_notify" );
    whos_who_status( "clone animated" );
    self setscriptablepartstate( #"fx", #"on" );
    whos_who_status( "clone glow on" );
}
function whos_who_marker()
{
    self.ww_objid = objidpoolmanager::requestobjectiveid( 1 );
    if ( !isdefined( self.ww_objid ) || self.ww_objid == -1 )
    {
        self.ww_objid = undefined;
        whos_who_status( "no free objective id for the marker" );
        return;
    }
    objective_position( self.ww_objid, self.ww_body_origin + ( 0, 0, 80 ) );
    objective_state( self.ww_objid, "current" );
    objective_icon( self.ww_objid, "ui_icon_zm_objective" );
    objective_settint( self.ww_objid, 80, 200, 255 );
    objective_setbackground( self.ww_objid, 1 );
    objective_setshowdistance( self.ww_objid, 1 );
    objective_setplayintro( self.ww_objid, 0 );
    objective_setownerteam( self.ww_objid, undefined );
    objidpoolmanager::objective_set_is_zone( self.ww_objid, 0 );
    objidpoolmanager::objective_playermask_showtoallplayers( self.ww_objid );
    whos_who_status( "marker placed " + self.ww_objid );
}
function whos_who_clone_think()
{
    self endon( #"disconnect" );
    level endon( #"game_ended" );
    self.ww_duration = whos_who_clone_seconds() * 1000;
    if ( whos_who_has_minor( self, 1 ) ) self.ww_duration = int( self.ww_duration * 1.5 );
    self.ww_expires = gettime() + self.ww_duration;
    self.ww_hold = 0;
    self.ww_reviver = undefined;
    self.ww_ghost = true;
    self.ww_left_pct = 100;
    whos_who_status( "revive loop running, " + self.ww_duration + " ms" );
    while ( true )
    {
        wait 0.05;
        self.ww_left_pct = int( clamp( ( self.ww_expires - gettime() ) * 100 / self.ww_duration, 0, 100 ) );
        if ( !isalive( self ) )
        {
            whos_who_status( "owner died; the clone is gone" );
            self whos_who_end( false );
            return;
        }
        if ( gettime() >= self.ww_expires )
        {
            self whos_who_end( false );
            if ( ( self.cp_whos_who_major ?? 0 ) == 1 )
            {
                whos_who_status( "time up; Fresh Start keeps the ghost alive, the loadout is gone" );
                return;
            }
            whos_who_status( "time up; killing the player" );
            if ( isalive( self ) ) self damage::_suicide();
            return;
        }
        self.ww_now_reviver = undefined;
        foreach ( player in level.players )
        {
            if ( !isdefined( player ) || !isalive( player ) || istrue( player.inlaststand ) || player.team != self.team ) continue;
            if ( distance( player.origin, self.ww_body_origin ) > 80 ) continue;
            player.ww_ui = 1;
            player.ww_ui_until = gettime() + 250;
            if ( !isdefined( self.ww_now_reviver ) && player usebuttonpressed() ) self.ww_now_reviver = player;
        }
        if ( !isdefined( self.ww_now_reviver ) || ( isdefined( self.ww_reviver ) && self.ww_reviver != self.ww_now_reviver ) )
        {
            self.ww_hold = 0;
            self.ww_reviver = self.ww_now_reviver;
            continue;
        }
        self.ww_reviver = self.ww_now_reviver;
        self.ww_hold = self.ww_hold + 0.05;
        self.ww_reviver.ww_ui = 2 + int( min( 100, self.ww_hold * 100 / whos_who_revive_seconds() ) );
        if ( self.ww_hold < whos_who_revive_seconds() ) continue;
        self.ww_reviver.ww_ui_until = 0;
        if ( self.ww_reviver != self && !istrue( self.inlaststand ) )
        {
            self setorigin( self.ww_body_origin );
            self setplayerangles( ( 0, self.ww_body_angles[ 1 ], 0 ) );
        }
        if ( istrue( self.inlaststand ) )
        {
            whos_who_status( "clone revived while the owner is down; returning the loadout when they get up" );
            self whos_who_end( true );
            return;
        }
        self whos_who_restore();
        whos_who_status( "clone revived; weapons and perks returned" );
        self whos_who_end( false );
        return;
    }
}
function whos_who_end( b_restore_later )
{
    self.ww_ghost = false;
    if ( isdefined( self.ww_objid ) )
    {
        objidpoolmanager::returnobjectiveid( self.ww_objid );
        self.ww_objid = undefined;
    }
    if ( isdefined( self.ww_clone ) )
    {
        self.ww_clone delete();
        self.ww_clone = undefined;
    }
    self thread whos_who_ghost_effects( false );
    if ( b_restore_later )
    {
        self thread whos_who_restore_when_up();
        return;
    }
    self.ww_active = false;
}
function whos_who_restore_when_up()
{
    self endon( #"disconnect" );
    level endon( #"game_ended" );
    while ( isalive( self ) && istrue( self.inlaststand ) )
    {
        wait 0.25;
    }
    if ( isalive( self ) ) self whos_who_restore();
    self.ww_active = false;
}
function whos_who_ghost_effects( b_on )
{
    self.ww_postfx = undefined;
    if ( isdefined( level.field_upgrade_bundles ) && isdefined( level.field_upgrade_bundles[ "super_aether_shroud" ] ) )
    {
        self.ww_postfx = level.field_upgrade_bundles[ "super_aether_shroud" ].var_67f9d640c30063e7;
    }
    if ( b_on )
    {
        if ( isdefined( self.ww_postfx ) ) pbgpostfxbundlestart( self, self.ww_postfx );
        else whos_who_status( "Aether Shroud screen effect isn't loaded on this map" );
        whos_who_status( "screen effect on" );
        self setscriptablepartstate( "aether_shroud_fx", "super_fx_on", 0 );
        whos_who_status( "body glow on" );
        return;
    }
    if ( isdefined( self.ww_postfx ) ) pbgpostfxbundleend( self, self.ww_postfx );
    self setscriptablepartstate( "aether_shroud_fx", "super_fx_deactivate", 0 );
}
function whos_who_find_escape()
{
    self.ww_found = undefined;
    self.ww_best = 0;
    self.ww_try = 0;
    while ( self.ww_try < 24 )
    {
        self.ww_try = self.ww_try + 1;
        self.ww_cand = getclosestpointonnavmesh( self.origin + anglestoforward( ( 0, randomint( 360 ), 0 ) ) * ( 500 + randomint( 500 ) ) );
        if ( !isdefined( self.ww_cand ) || !istrue( utility::callsharedfunc( #"zombie", #"hash_bad01cbc996e3dba", self.ww_cand ) ) ) continue;
        self.ww_dist = distance2d( self.ww_cand, self.origin );
        if ( self.ww_dist > self.ww_best )
        {
            self.ww_best = self.ww_dist;
            self.ww_found = self.ww_cand;
        }
    }
    if ( self.ww_best >= 250 )
    {
        return self.ww_found;
    }
    foreach ( player in level.players )
    {
        if ( isdefined( player ) && player != self && isalive( player ) && !istrue( player.inlaststand ) ) return player.origin;
    }
    return self.ww_found;
}
function whos_who_status( message )
{
    if ( !isdefined( level.ww_trail ) ) level.ww_trail = "";
    level.ww_trail = level.ww_trail + " > " + message;
    if ( level.ww_trail.size > 400 ) level.ww_trail = getsubstr( level.ww_trail, level.ww_trail.size - 400 );
    setdvar( @"bo7_cp_whos_who_runtime", level.ww_trail );
}
function quiet_perk_whos_who_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
