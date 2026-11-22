#using scripts\common\ai\aitypes\shared\zombie\zombie_utils;
#using scripts\common\callbacks;
#using scripts\common\trace;
#using scripts\common\utility;
#using scripts\mp\common\perks\zombie\zombie_perks;
#using scripts\mp\damagefeedback;
#using scripts\mp\mp_agent_damage;
#using scripts\mp\common\utility\weapon;
#namespace perk_twin_spirit;
// DEBUG: 1 keeps the wisp out for as long as you own the perk.
// 0 summons it like Wisp Tea (the stock kill count, gone after the stock summon time).
function twin_spirit_always_on()
{
    return 1;
}
// Seconds between the player's hit and the wisp's copy.
function twin_spirit_echo_delay()
{
    return 0;
}
autoexec twin_spirit_init()
{
    level thread twin_spirit_register_perk();
}
function twin_spirit_register_perk()
{
    level endon( #"game_ended" );
    level utility::flag_wait_all( "StartGameTypeCallbackFinished", "zombie_perks_init_complete" );
    if ( !level.zombie_perks_in_use )
    {
        return;
    }
    if ( !isdefined( level.cp_register ) || !isdefined( level.cp_register_native ) )
    {
        twin_spirit_status( "custom perk manager unavailable" );
        return;
    }
    def = [];
    def["id"] = "twin_spirit";
    def["creator"] = "Gauty";
    def["code"] = 98;
    def["name"] = "Twin Spirit";
    def["description"] = "A wisp orbits you. Every shot you fire, the wisp fires a copy at the same target.";
    def["price"] = 2500;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_twin_spirit_perk;
    def["on_take"] = &take_twin_spirit_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        twin_spirit_status( "registration rejected" );
        return;
    }
    level [[ level.cp_register_native ]]( "twin_spirit", level.cp_defs["twin_spirit"] );
    level callback::add( #"on_ai_killed", &twin_spirit_on_kill );
    level thread twin_spirit_load_fx();
    twin_spirit_status( "registered" );
}
// Wisp Tea's own beam (its healing-beam augment), used as the wisp's tracer.
function twin_spirit_load_fx()
{
    level._effect[ "twin_spirit_beam" ] = loadfxasset( "vfx_sat_gameplay_zm_ai_perks_wisp_tea_healing_beam" );
}
function give_twin_spirit_perk()
{
    self notify( #"twin_spirit_taken" );
    self.ts_kills = 0;
    // Per-player zombie damage callback: runs for every zombie this player damages.
    if ( !isdefined( self.a_func_zombie_agent_damage_callback ) || !arraycontains( self.a_func_zombie_agent_damage_callback, &twin_spirit_on_zombie_damage ) )
    {
        self zombie_utils::register_zombie_agent_damage_callback( &twin_spirit_on_zombie_damage );
    }
    twin_spirit_status( "given, damage hooks on player: " + self.a_func_zombie_agent_damage_callback.size );
    self thread twin_spirit_fire_watch();
    if ( twin_spirit_always_on() )
    {
        self thread twin_spirit_keep_alive();
    }
}
function take_twin_spirit_perk( b_pause, str_perk, str_result, n_slot )
{
    self notify( #"twin_spirit_taken" );
    // The damage callback stays registered but does nothing once the wisp is gone.
    self twin_spirit_delete();
}
// Respawns the wisp after death or downs while the perk is owned (debug always-on mode).
function twin_spirit_keep_alive()
{
    self endon( #"disconnect" );
    self endon( #"twin_spirit_taken" );
    while ( true )
    {
        // Check the mover, not the scriptable: isdefined on a scriptable may not report it, which respawned a wisp every second.
        if ( !isdefined( self.ts_mover ) && isalive( self ) && self.sessionstate == "playing" )
        {
            self twin_spirit_spawn();
        }
        wait 1;
    }
}
// Wisp Tea's summon rule: enough kills since the last wisp, then it stays for the stock summon time.
function twin_spirit_on_kill( params )
{
    if ( twin_spirit_always_on() || !isdefined( params ) || !isplayer( params.eattacker ) )
    {
        return;
    }
    level.ts_player = params.eattacker;
    if ( isdefined( level.ts_player.ts_mover ) || !level.ts_player zombie_perks::has_perk( "specialty_twin_spirit" ) )
    {
        return;
    }
    level.ts_player.ts_kills = ( level.ts_player.ts_kills ?? 0 ) + 1;
    if ( level.ts_player.ts_kills >= ( level.perkbundles[ "specialty_w_mod" ].var_76b6fd591d237684 ?? 10 ) )
    {
        level.ts_player.ts_kills = 0;
        level.ts_player twin_spirit_spawn();
        level.ts_player thread twin_spirit_expire( level.perkbundles[ "specialty_w_mod" ].wmodsummontime ?? 30 );
    }
}
function twin_spirit_expire( seconds )
{
    self endon( #"disconnect" );
    self endon( #"twin_spirit_taken" );
    wait seconds;
    self twin_spirit_delete();
}
// Same spawn as Wisp Tea: the perk bundle's wisp scriptable, parented to a tag_origin mover.
function twin_spirit_spawn()
{
    if ( isdefined( self.ts_mover ) )
    {
        return;
    }
    if ( !isdefined( level.perkbundles[ "specialty_w_mod" ] ) || !isdefined( level.perkbundles[ "specialty_w_mod" ].var_10289c72a22feea1 ) )
    {
        twin_spirit_status( "no Wisp Tea bundle on this map" );
        return;
    }
    self.ts_spawn_pos = self twin_spirit_hover_pos();
    self.ts_mover = utility::spawn_model( "tag_origin", self.ts_spawn_pos, self.angles );
    self.ts_wisp = spawnscriptable( level.perkbundles[ "specialty_w_mod" ].var_10289c72a22feea1, self.ts_spawn_pos, self.angles );
    self.ts_wisp utility::scriptable_setparententity( self.ts_mover );
    self.ts_wisp utility::scriptable_setpartstate( "wisp", "on" );
    self.ts_wisp utility::scriptable_setpartstate( "audio", "on_default" );
    if ( isdefined( level._effect[ #"w_mod_spawn" ] ) ) playfxontag( level._effect[ #"w_mod_spawn" ], self.ts_mover, "tag_origin" );
    self thread twin_spirit_orbit();
    twin_spirit_status( "wisp spawned" );
}
// Hover spot above the player's right shoulder (units right / up / forward of the eye, turning with the player's yaw),
// so the wisp's shots start close to the player's own line of fire.
function twin_spirit_hover_pos()
{
    self.ts_yaw = ( 0, self getplayerangles()[ 1 ], 0 );
    return self geteye() + anglestoright( self.ts_yaw ) * 22 + ( 0, 0, 14 ) + anglestoforward( self.ts_yaw ) * -4;
}
function twin_spirit_orbit()
{
    // Only one orbit thread per player, ever.
    self notify( #"twin_spirit_orbit" );
    self endon( #"twin_spirit_orbit" );
    self endon( #"disconnect" );
    self endon( #"twin_spirit_taken" );
    self endon( #"twin_spirit_gone" );
    while ( isdefined( self.ts_mover ) )
    {
        if ( !isalive( self ) || !( self.sessionstate == "playing" ) )
        {
            self thread twin_spirit_delete();
            return;
        }
        self.ts_orbit_pos = self twin_spirit_hover_pos();
        // Face where the player looks, like the stock idle wisp.
        self.ts_mover rotateto( ( 0, self.angles[ 1 ], 0 ), 0.1 );
        // A big jump (teleport, fast travel) snaps the wisp instead of dragging it across the map.
        if ( distancesquared( self.ts_mover.origin, self.ts_orbit_pos ) > 250000 )
        {
            self.ts_mover.origin = self.ts_orbit_pos;
        }
        else
        {
            self.ts_mover moveto( self.ts_orbit_pos, 0.05 );
        }
        wait 0.05;
    }
}
function twin_spirit_delete()
{
    self notify( #"twin_spirit_gone" );
    if ( isdefined( self.ts_mover ) && isdefined( level._effect[ #"w_mod_despawn" ] ) ) playfx( level._effect[ #"w_mod_despawn" ], self.ts_mover.origin );
    if ( isdefined( self.ts_wisp ) && self.ts_wisp isscriptableinstance() ) self.ts_wisp freescriptable();
    if ( isdefined( self.ts_mover ) ) self.ts_mover delete();
    self.ts_wisp = undefined;
    self.ts_mover = undefined;
}
// self = the zombie. Each bullet the owner lands is echoed by the wisp at the same zombie.
function twin_spirit_on_zombie_damage( params )
{
    if ( !isdefined( params ) || isdefined( self.ts_echo ) || !isplayer( params.eattacker ) || !isdefined( params.eattacker.ts_mover ) )
    {
        return params.idamage;
    }
    // A hit right after the wisp fired its real bullet is that bullet: never echo it, or the wisp would echo itself forever.
    if ( ( params.eattacker.ts_pending ?? 0 ) > 0 && gettime() - ( params.eattacker.ts_fire_time ?? 0 ) < 250 )
    {
        params.eattacker.ts_pending = params.eattacker.ts_pending - 1;
        return params.idamage;
    }
    level.ts_seen = ( level.ts_seen ?? 0 ) + 1;
    if ( !isdefined( params.smeansofdeath ) || !( issubstr( params.smeansofdeath, "BULLET" ) || params.smeansofdeath == "MOD_HEAD_SHOT" ) )
    {
        return params.idamage;
    }
    // Only measures the player's real shot damage, for the fallback hit; the shots themselves come from twin_spirit_fire_watch.
    params.eattacker thread twin_spirit_measure( self, params.idamage, self.health );
    return params.idamage;
}
// idamage here is before the game's later multipliers, so keep the health the shot really removed.
function twin_spirit_measure( e_zombie, n_damage, n_health_before )
{
    self endon( #"disconnect" );
    self.ts_shot_damage = n_damage;
    waitframe();
    if ( isdefined( e_zombie ) && isalive( e_zombie ) && isdefined( n_health_before ) && n_health_before - e_zombie.health > n_damage )
    {
        self.ts_shot_damage = n_health_before - e_zombie.health;
    }
}
// Every trigger pull, hit or miss: the wisp fires at the spot the player was aiming at, after the delay.
function twin_spirit_fire_watch()
{
    self endon( #"disconnect" );
    self endon( #"twin_spirit_taken" );
    while ( true )
    {
        self waittill( #"weapon_fired" );
        // The wisp's own magicbullet also raises weapon_fired on the player; firing back at it looped forever.
        if ( ( self.ts_mb_expect ?? 0 ) > 0 && gettime() - ( self.ts_mb_time ?? 0 ) < 150 )
        {
            self.ts_mb_expect = self.ts_mb_expect - 1;
            continue;
        }
        level.ts_shots = ( level.ts_shots ?? 0 ) + 1;
        if ( !isdefined( self.ts_mover ) )
        {
            continue;
        }
        self.ts_fire_weapon = self getcurrentweapon();
        if ( !isdefined( self.ts_fire_weapon ) || weapon::iscacmeleeweapon( self.ts_fire_weapon ) )
        {
            continue;
        }
        self.ts_fire_eye = self geteye();
        self.ts_fire_dir = anglestoforward( self getplayerangles() );
        // Own thread per shot so a failed trace or bullet never stops this watcher.
        self thread twin_spirit_wisp_shot( self.ts_fire_weapon, self.ts_fire_eye, self.ts_fire_dir );
    }
}
function twin_spirit_wisp_shot( w_weapon, v_eye, v_dir )
{
    self endon( #"disconnect" );
    // Aim point at the moment of firing: whatever the crosshair was on, or far along the aim line.
    self.ts_aim_end = v_eye + v_dir * 8000;
    self.ts_aim_hit = physics_raycast( v_eye, self.ts_aim_end, trace::create_default_contents(), undefined, 0, "physicsquery_closest", 0, 0 );
    self.ts_shot_pos = self.ts_aim_end;
    self.ts_shot_ent = undefined;
    if ( isdefined( self.ts_aim_hit[ 0 ] ) )
    {
        self.ts_shot_pos = self.ts_aim_hit[ 0 ][ "position" ] ?? self.ts_aim_end;
        self.ts_shot_ent = self.ts_aim_hit[ 0 ][ "entity" ];
    }
    // Hand this shot's values over as arguments: overlapping full-auto shots would overwrite shared fields during the wait.
    self twin_spirit_wisp_wait( w_weapon, self.ts_shot_pos, self.ts_shot_ent, self.ts_shot_damage ?? 0 );
}
function twin_spirit_wisp_wait( w_weapon, v_pos, e_target, n_damage )
{
    if ( twin_spirit_echo_delay() > 0 ) wait twin_spirit_echo_delay();
    if ( !isdefined( self.ts_mover ) )
    {
        return;
    }
    // If the crosshair was on an enemy, aim at where it is now; otherwise shoot the remembered spot.
    if ( isdefined( e_target ) && isagent( e_target ) && isalive( e_target ) && !( e_target.team === self.team ) )
    {
        e_target.ts_aim_pos = e_target.origin + ( 0, 0, 50 );
        if ( e_target tagexists( "j_spine4" ) ) e_target.ts_aim_pos = e_target gettagorigin( "j_spine4" );
        // Damage measured now, after the player's own bullet from this trigger pull has landed.
        self twin_spirit_fire_at( w_weapon, e_target.ts_aim_pos, e_target, self.ts_shot_damage ?? n_damage );
        return;
    }
    self twin_spirit_fire_at( w_weapon, v_pos, undefined, self.ts_shot_damage ?? n_damage );
}
function twin_spirit_fire_at( w_weapon, v_pos, e_target, n_damage )
{
    self thread twin_spirit_tracer( v_pos );
    // Real bullet from the player's gun out of the wisp, as the stock ZM benchmark fires one at zombies.
    self.ts_pending = ( self.ts_pending ?? 0 ) + 1;
    self.ts_fire_time = gettime();
    if ( isdefined( e_target ) ) e_target.ts_mb_health = e_target.health;
    // Start a little toward the target so the bullet doesn't begin inside the wisp's own bounds.
    self thread twin_spirit_magic_bullet( w_weapon, self.ts_mover.origin + vectornormalize( v_pos - self.ts_mover.origin ) * 12, v_pos );
    waitframe();
    waitframe();
    self.ts_pending = 0;
    if ( !isdefined( e_target ) || !isalive( e_target ) || e_target.health < e_target.ts_mb_health )
    {
        if ( isdefined( e_target ) ) level.ts_mb_landed = ( level.ts_mb_landed ?? 0 ) + 1;
        twin_spirit_status( "shots " + level.ts_shots + ", real bullets landed " + ( level.ts_mb_landed ?? 0 ) + ", fallbacks " + ( level.ts_fallbacks ?? 0 ) );
        return;
    }
    if ( !isdefined( self.ts_mover ) || n_damage <= 0 )
    {
        return;
    }
    // Fallback: the real bullet did nothing to the enemy it was aimed at, so deal the copy the way Wisp Tea deals damage.
    level.ts_fallbacks = ( level.ts_fallbacks ?? 0 ) + 1;
    e_target.ts_echo = 1;
    e_target dodamage( n_damage, self.ts_mover.origin, self, self, "MOD_UNKNOWN", "<explicitweaponnone>", "torso_upper", undefined, 1073807360 );
    if ( isdefined( e_target ) ) e_target.ts_echo = undefined;
    // That damage path shows no number or hitmarker, so show them the way zm_damage does for normal hits.
    self thread twin_spirit_feedback( e_target, n_damage, w_weapon, v_pos );
    twin_spirit_status( "shots " + level.ts_shots + ", real bullets landed " + ( level.ts_mb_landed ?? 0 ) + ", fallbacks " + level.ts_fallbacks );
}
// Own thread so a weapon magicbullet rejects only fails this shot.
function twin_spirit_magic_bullet( w_weapon, v_start, v_end )
{
    // Old unmatched expectations (bullets that raised no notify, e.g. the Ray Gun) are dropped by the 150 ms window.
    if ( gettime() - ( self.ts_mb_time ?? 0 ) >= 150 ) self.ts_mb_expect = 0;
    self.ts_mb_expect = ( self.ts_mb_expect ?? 0 ) + 1;
    self.ts_mb_time = gettime();
    magicbullet( w_weapon, v_start, v_end, self, undefined, undefined, 1, 1 );
}
// Own thread so a bad argument here never cancels the damage itself.
function twin_spirit_feedback( e_zombie, n_damage, w_weapon, v_pos )
{
    self.ts_killed = !isdefined( e_zombie ) || !isalive( e_zombie );
    mp_agent_damage::display_damage_number( self, e_zombie, "torso_upper", "MOD_RIFLE_BULLET", w_weapon, int( n_damage ), v_pos, 0, undefined, 0, 0 );
    self damagefeedback::updatedamagefeedback( "standard", self.ts_killed );
}
// Beam needs two entities, so the far end is a tag_origin at the hit point (it stays put if the zombie dies).
function twin_spirit_tracer( v_hit )
{
    // Stock Wisp Tea hit puff at the impact point (first, so it still shows if the beam fails).
    if ( isdefined( level._effect[ #"w_mod_damage" ] ) ) playfx( level._effect[ #"w_mod_damage" ], v_hit );
    self.ts_tracer_end = utility::spawn_model( "tag_origin", v_hit, ( 0, 0, 0 ) );
    self.ts_tracer_from = self.ts_mover;
    self.ts_beam = playfxontagsbetweenclients( level._effect[ "twin_spirit_beam" ], self.ts_tracer_from, "tag_origin", self.ts_tracer_end, "tag_origin" );
    level.ts_tracer_end = self.ts_tracer_end;
    level.ts_beam = self.ts_beam;
    level thread twin_spirit_tracer_cleanup( self.ts_beam, self.ts_tracer_end );
}
function twin_spirit_tracer_cleanup( e_beam, e_end )
{
    wait 0.15;
    if ( isdefined( e_beam ) ) e_beam delete();
    if ( isdefined( e_end ) ) e_end delete();
}
function twin_spirit_status( message )
{
    setdvar( @"bo7_cp_twin_spirit_runtime", message );
}
