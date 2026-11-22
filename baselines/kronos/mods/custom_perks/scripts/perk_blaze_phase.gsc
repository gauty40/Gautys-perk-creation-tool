#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\common\trace;
#using scripts\common\status_effects\effect_burn;
#using scripts\mp\common\perks\zombie\zombie_perks;
#namespace perk_blaze_phase;
autoexec blaze_phase_init()
{
    {}
    level.bp_trail_fx = loadfxasset("vfx_t10_core_strk_napalm_fire_ground_med_1");
    level.bp_dash_fx = loadfxasset("vfx_t10_gameplay_zm_ai_aether_shroud_quickmove");
    level.bp_flash_fx = loadfxasset("vfx_jup_ob_gameplay_zm_weapons_perk_pdh_explo_med");
    level thread blaze_phase_register_perk();
    level thread blaze_phase_watch_players();
}
function blaze_phase_min_charge()
{
    return 0.3;
}
function blaze_phase_full_charge()
{
    return 7.5;
}
function blaze_phase_max_distance()
{
    return 1300;
}
function blaze_phase_speed()
{
    return 950;
}
function blaze_phase_cooldown()
{
    return 0.5;
}
function blaze_phase_kill_radius()
{
    return 64;
}
function blaze_phase_kill_height()
{
    return 100;
}
function blaze_phase_kills_per_frame()
{
    return 3;
}
function blaze_phase_kill_any()
{
    return 0;
}
function blaze_phase_register_perk()
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
    def["id"] = "blaze_phase";
    def["creator"] = "Gauty";
    def["code"] = 84;
    def["name"] = "Blaze Phase";
    def["description"] = "Crouch and hold still to charge, stand up to launch yourself forward. The longer you charge, the further you go.";
    def["icon_material"] = "ui_icon_perks_zm_blaze_phase";
    def["price"] = 2500;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_blaze_phase_perk;
    def["on_take"] = &take_blaze_phase_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        {}
        return;
    }
    level [[ level.cp_register_native ]]( "blaze_phase", level.cp_defs["blaze_phase"] );
    if ( isdefined( level.cp_register_damage_mod ) ) level [[ level.cp_register_damage_mod ]]( &blaze_phase_firewalker );
    {}
    {}
}
function give_blaze_phase_perk()
{
    if (istrue(self.bp_owned)) return;
    {}
    self.bp_owned = true;
    self.bp_ready_at = 0;
    self notify("specialty_blaze_phase_stop");
    self quiet_perk_blaze_phase_client_dvar( @"bo7_cp_client_owned_blaze_phase", "1" );
    {}
    self.bp_dashing = 0;
    self thread blaze_phase_loop();
}
function blaze_phase_loop()
{
    self notify("specialty_blaze_phase_stop");
    self.bp_loop_time = gettime();
    {}
    self endon( #"death_or_disconnect" );
    self endon( "specialty_blaze_phase_stop" );
    level endon( #"game_ended" );
    n_charge_start = undefined;
    n_crouch_since = undefined;
    b_full_rumbled = 0;
    self.bp_ready_at = 0;
    while ( istrue(self.bp_owned) )
    {
        self.bp_loop_time = gettime();
        waitframe();
        if ( !isdefined( n_charge_start ) ) self blaze_phase_send_charge( 0 );
        if ( !isalive( self ) || istrue( self.inlaststand ) || istrue( self.bp_dashing ) )
        {
            n_charge_start = undefined;
            n_crouch_since = undefined;
            continue;
        }
        n_now = gettime();
        eye_height = self geteye()[2] - self.origin[2];
        str_stance = "stand";
        if (eye_height < 25) str_stance = "prone";
        else if (eye_height < 50) str_stance = "crouch";
        if (!isdefined(self.bp_height_log_at) || n_now >= self.bp_height_log_at)
        {
            self.bp_height_log_at = n_now + 10000;
            held_ms = 0;
            if (isdefined(n_crouch_since)) held_ms = n_now - n_crouch_since;
            {}
        }
        if (str_stance == "crouch")
        {
            if (!isdefined(n_crouch_since)) n_crouch_since = n_now;
            if (n_now - n_crouch_since < 5000) continue;
        }
        else n_crouch_since = undefined;
        if ( str_stance == "crouch" )
        {
            if ( !isdefined( n_charge_start ) && n_now >= self.bp_ready_at )
            {
                n_charge_start = n_now;
                self.bp_charge_acc = 0;
                self.bp_charge_tick = n_now;
                b_full_rumbled = 0;
                {}
            }
            if ( isdefined( n_charge_start ) )
            {
                self.bp_charge_rate = ( ( (self.cp_blaze_phase_minor ?? 0) == 2 || (self.cp_blaze_phase_bonus ?? 0) == 2 ) ? ( 1 / 0.75 ) : 1 );
                self.bp_vel = self getvelocity();
                if ( length( ( self.bp_vel[0], self.bp_vel[1], 0 ) ) < 15 || ( self.cp_blaze_phase_major ?? 0 ) == 4 )
                {
                    self.bp_charge_acc = self.bp_charge_acc + ( n_now - self.bp_charge_tick ) / 1000.0 * self.bp_charge_rate;
                }
                self.bp_charge_tick = n_now;
                n_charge = self.bp_charge_acc;
                self.bp_charge_pct = int( min( 100, n_charge * 100 / blaze_phase_full_charge() ) );
                self blaze_phase_send_charge( max( 1, self.bp_charge_pct ) );
                if ( !b_full_rumbled && n_charge >= blaze_phase_full_charge() )
                {
                    b_full_rumbled = 1;
                    self playrumbleonentity( "zombie_field_upgrade_wand_fire" );
                    {}
                }
            }
            continue;
        }
        if ( !isdefined( n_charge_start ) )
        {
            continue;
        }
        n_charge = self.bp_charge_acc ?? 0;
        n_charge_start = undefined;
        if ( str_stance != "stand" || n_charge < blaze_phase_min_charge() )
        {
            {}
            continue;
        }
        if (n_charge <= 2.5)
            n_distance = n_charge * 240;
        else if (n_charge <= 5)
            n_distance = 600 + (n_charge - 2.5) * 80;
        else
            n_distance = 800 + (n_charge - 5) * 200;
        if (n_distance > blaze_phase_max_distance()) n_distance = blaze_phase_max_distance();
        self.bp_ready_at = n_now + int( blaze_phase_cooldown() * 1000 );
        self thread blaze_phase_dash( n_distance );
    }
}
function blaze_phase_send_charge(pct)
{
    if (self.bp_charge_sent === pct) return;
    self.bp_charge_sent = pct;
    self setclientomnvar("ui_br_objective_reward_tier", pct);
}
function blaze_phase_dash(n_distance)
{
    self blaze_phase_velocity_dash(n_distance);
}
function blaze_phase_velocity_dash(n_distance)
{
    if (!istrue(self.bp_owned) || istrue(self.bp_dashing) || self islinked()) return;
    if (!isdefined(level.bp_dash_contents))
    {
        level.bp_dash_contents = physics_createcontents(["physicscontents_edge", "physicscontents_glass", "physicscontents_water", "physicscontents_missileclip", "physicscontents_item", "physicscontents_vehicleclip", "physicscontents_itemclip", "physicscontents_clipshot", "physicscontents_characterproxy", "physicscontents_playerclip", "physicscontents_vehicle"]);
    }
    self.bp_dash_target = n_distance;
    self.bp_dash_speed = 1750;
    self.bp_dash_old_vel = self getvelocity();
    self.bp_dash_dir = vectornormalize(self.bp_dash_old_vel);
    if (self.bp_dash_old_vel[0] < 65 && self.bp_dash_old_vel[0] > -65 && self.bp_dash_old_vel[1] < 65 && self.bp_dash_old_vel[1] > -65)
        self.bp_dash_dir = vectornormalize(anglestoforward(self.angles));
    self.bp_dash_vel = self.bp_dash_old_vel + (clamp(self.bp_dash_dir[0] * 2500, -1750, 1750), clamp(self.bp_dash_dir[1] * 2500, -1750, 1750), clamp(self.bp_dash_dir[2], -50, 50));
    self.bp_dash_centre = self getcentroid();
    if (self tagexists("tag_flash")) self.bp_dash_centre = self gettagorigin("tag_flash");
    self.bp_dash_hit = trace::sphere_trace(self.bp_dash_centre, self.bp_dash_centre + vectornormalize(self.bp_dash_vel) * 32, 16, arraycombine(level.players, getaiarrayinradius(self.origin, 1024)), level.bp_dash_contents, undefined, 1);
    if (isdefined(self.bp_dash_hit) && isdefined(self.bp_dash_hit["fraction"]) && self.bp_dash_hit["fraction"] < 1 && distance2d(self.bp_dash_hit["position"], self.bp_dash_centre) < 24)
    {
        {}
        return;
    }
    self.bp_dashing = true;
    if (isdefined(level.bp_dash_fx)) playfxontag(level.bp_dash_fx, self, "j_spine4");
    level thread blaze_phase_trail_patch(self.origin, self);
    self.bp_dash_trail_pos = self.origin;
    self.bp_dash_travelled = 0;
    self.bp_dash_deadline = gettime() + int((self.bp_dash_target / self.bp_dash_speed) * 1000);
    {}
    waitframe();
    if (!isdefined(self)) return;
    if (isalive(self) && !istrue(self.inlaststand)) self thread blaze_phase_hold_velocity();
    while (isdefined(self) && isalive(self) && istrue(self.bp_owned) && istrue(self.bp_dashing) && !istrue(self.inlaststand) && gettime() < self.bp_dash_deadline)
    {
        self.bp_dash_prev = self.origin;
        waitframe();
        if (!isdefined(self)) return;
        self.bp_dash_step = distance2d(self.origin, self.bp_dash_prev);
        if (self.bp_dash_step > 0) self thread blaze_phase_dash_kill(self.bp_dash_prev, self.bp_dash_dir, self.bp_dash_step);
        self.bp_dash_travelled = self.bp_dash_travelled + self.bp_dash_step;
        if (distance(self.origin, self.bp_dash_trail_pos) >= 64)
        {
            self.bp_dash_trail_pos = self.origin;
            level thread blaze_phase_trail_patch(self.bp_dash_trail_pos, self);
        }
    }
    if (isdefined(self))
    {
        self.bp_dashing = false;
        if (isalive(self) && (self.cp_blaze_phase_major ?? 0) == 2) self blaze_phase_flashpoint();
        if (isalive(self))
        {
            self setvelocity(self.bp_dash_old_vel);
            if (isdefined(level.bp_dash_fx)) stopfxontag(level.bp_dash_fx, self, "j_spine4");
        }
        self.bp_ready_at = gettime() + 500;
        {}
    }
}
function blaze_phase_hold_velocity()
{
    self endon(#"death_or_disconnect");
    while (istrue(self.bp_dashing))
    {
        self setvelocity(self.bp_dash_vel);
        waitframe();
    }
}
function blaze_phase_cleanup_anchor()
{
    self.bp_dashing = false;
}
function blaze_phase_dash_kill( v_start, v_dir, n_distance )
{
    self endon( #"death_or_disconnect" );
    self endon( "specialty_blaze_phase_stop" );
    n_radius = blaze_phase_kill_radius();
    v_middle = v_start + v_dir * ( n_distance / 2 );
    a_near = getaiarrayinradius( v_middle, n_distance / 2 + n_radius + 32 );
    a_hit = [];
    foreach ( zombie in a_near )
    {
        if ( !isdefined( zombie ) || !isalive( zombie ) || !isagent( zombie ) )
        {
            continue;
        }
        if ( istrue( zombie.magic_bullet_shield ) || istrue( zombie.damageshield ) )
        {
            continue;
        }
        if ( !blaze_phase_kill_any() && zombie.aicategory != "normal" )
        {
            continue;
        }
        n_along = ( zombie.origin[ 0 ] - v_start[ 0 ] ) * v_dir[ 0 ] + ( zombie.origin[ 1 ] - v_start[ 1 ] ) * v_dir[ 1 ];
        n_along = max( 0, min( n_along, n_distance ) );
        v_closest = v_start + v_dir * n_along;
        if ( distance( ( zombie.origin[ 0 ], zombie.origin[ 1 ], 0 ), ( v_closest[ 0 ], v_closest[ 1 ], 0 ) ) > n_radius )
        {
            continue;
        }
        if ( abs( zombie.origin[ 2 ] - v_start[ 2 ] ) > blaze_phase_kill_height() )
        {
            continue;
        }
        a_hit[ a_hit.size ] = zombie;
    }
    if ( a_hit.size == 0 )
    {
        return;
    }
    a_hit = sortbydistance( a_hit, v_start );
    n_this_frame = 0;
    n_killed = 0;
    foreach ( zombie in a_hit )
    {
        if ( isdefined( zombie ) && isalive( zombie ) )
        {
            zombie.forceannihilate = 1;
            zombie kill( zombie.origin, self, self );
            n_killed++;
        }
        n_this_frame++;
        if ( n_this_frame >= blaze_phase_kills_per_frame() )
        {
            n_this_frame = 0;
            waitframe();
        }
    }
    {}
}
function take_blaze_phase_perk( b_pause, str_perk, str_result, n_slot )
{
    self blaze_phase_cleanup_anchor();
    self.bp_owned = false;
    self quiet_perk_blaze_phase_client_dvar( @"bo7_cp_client_owned_blaze_phase", "0" );
    {}
    self.bp_dashing = 0;
    self blaze_phase_send_charge( 0 );
    self notify( "specialty_blaze_phase_stop" );
}
function blaze_phase_watch_players()
{
    {}
    level endon(#"game_ended");
    level utility::flag_wait_all("StartGameTypeCallbackFinished", "zombie_perks_init_complete");
    for (;;)
    {
        foreach (player in level.players)
        {
            if (!isdefined(player)) continue;
            owned = player blaze_phase_is_owned();
            if (owned && isalive(player))
            {
                if (!istrue(player.bp_owned)) player give_blaze_phase_perk();
                else if (!isdefined(player.bp_loop_time) || gettime()-player.bp_loop_time > 1500)
                {
                    player thread blaze_phase_loop();
                    {}
                }
            }
            else if (istrue(player.bp_owned)) player take_blaze_phase_perk(false, "specialty_blaze_phase", "watchdog", 0);
        }
        wait 0.25;
    }
}
function blaze_phase_is_owned()
{
    if (isdefined(self.perks_active))
    {
        foreach (ref in self.perks_active)
            if (ref == "specialty_blaze_phase" || ref == #"specialty_blaze_phase") return true;
    }
    if (isdefined(self.a_perks))
    {
        foreach (ref, active in self.a_perks)
            if ((ref == "specialty_blaze_phase" || ref == #"specialty_blaze_phase") && active) return true;
    }
    return false;
}
function blaze_phase_trail_patch(origin, owner)
{
    if (!isdefined(level.bp_tp_pos) || level.bp_tp_pos.size == 0)
    {
        level.bp_tp_pos = [];
        level.bp_tp_end = [];
        level.bp_tp_owner = [];
        level.bp_tp_fx = [];
        level.bp_tp_rad = [];
    }
    level.bp_tp_n = level.bp_tp_pos.size;
    level.bp_tp_pos[level.bp_tp_n] = origin;
    level.bp_tp_owner[level.bp_tp_n] = owner;
    level.bp_tp_rad[level.bp_tp_n] = 64;
    if ((owner.cp_blaze_phase_minor ?? 0) == 3 || (owner.cp_blaze_phase_bonus ?? 0) == 3) level.bp_tp_rad[level.bp_tp_n] = 96;
    level.bp_tp_end[level.bp_tp_n] = gettime() + 20000;
    if ((owner.cp_blaze_phase_minor ?? 0) == 4 || (owner.cp_blaze_phase_bonus ?? 0) == 4) level.bp_tp_end[level.bp_tp_n] = gettime() + 40000;
    if (isdefined(level.bp_trail_fx))
        level.bp_tp_fx[level.bp_tp_n] = playfx(level.bp_trail_fx, origin + (0, 0, 4), undefined, undefined, undefined, undefined, 1);
    if (!istrue(level.bp_tp_running)) level thread blaze_phase_trail_think();
}
function blaze_phase_trail_think()
{
    level endon(#"game_ended");
    level.bp_tp_running = true;
    while (isdefined(level.bp_tp_pos) && level.bp_tp_pos.size > 0)
    {
        level.bp_tp_live = 0;
        level.bp_tp_i = -1;
        while (level.bp_tp_i + 1 < level.bp_tp_pos.size)
        {
            level.bp_tp_i++;
            if (level.bp_tp_end[level.bp_tp_i] <= 0) continue;
            if (gettime() >= level.bp_tp_end[level.bp_tp_i])
            {
                level.bp_tp_end[level.bp_tp_i] = 0;
                if (isdefined(level.bp_tp_fx[level.bp_tp_i])) killfx(level.bp_tp_fx[level.bp_tp_i]);
                continue;
            }
            level.bp_tp_live++;
            if (!isdefined(level.bp_tp_owner[level.bp_tp_i])) continue;
            foreach (zombie in getaiarrayinradius(level.bp_tp_pos[level.bp_tp_i], level.bp_tp_rad[level.bp_tp_i] ?? 64))
                zombie blaze_phase_ignite(level.bp_tp_owner[level.bp_tp_i]);
        }
        if (level.bp_tp_live == 0) level.bp_tp_pos = [];
        wait 0.25;
    }
    level.bp_tp_running = false;
}
function blaze_phase_ignite(owner)
{
    if (!isagent(self) || !isalive(self)) return;
    if ((owner.cp_blaze_phase_major ?? 0) != 1 && isdefined(self.aicategory) && self.aicategory != "normal") return;
    if (isdefined(self.bp_next_trail_burn) && gettime() < self.bp_next_trail_burn) return;
    self.bp_next_trail_burn = gettime() + 1000;
    self.bp_burn_damage = max(1, (self.maxhealth ?? self.health) * 0.02);
    if ((owner.cp_blaze_phase_minor ?? 0) == 1 || (owner.cp_blaze_phase_bonus ?? 0) == 1) self.bp_burn_damage = self.bp_burn_damage * 1.5;
    self dodamage(self.bp_burn_damage, self.origin, owner, owner, "MOD_BURNED", "<explicitweaponnone>", "none", undefined, 65536);
    if (isalive(self)) self effect_burn::burn(3, self.bp_burn_damage, 1, owner, "blaze_phase_trail", undefined, undefined, "fire");
    if (!istrue(level.bp_ignite_logged))
    {
        level.bp_ignite_logged = true;
        {}
    }
}
function blaze_phase_flashpoint()
{
    if (isdefined(level.bp_flash_fx)) playfx(level.bp_flash_fx, self.origin);
    foreach (zombie in getaiarrayinradius(self.origin, 200))
    {
        if (!isdefined(zombie) || !isalive(zombie) || !isagent(zombie) || zombie.team == self.team) continue;
        zombie.bp_flash_damage = max(1, (zombie.maxhealth ?? zombie.health) * 0.2);
        zombie dodamage(zombie.bp_flash_damage, zombie.origin, self, self, "MOD_BURNED", "<explicitweaponnone>", "none", undefined, 65536);
        if (isalive(zombie)) zombie effect_burn::burn(3, zombie.bp_flash_damage * 0.1, 1, self, "blaze_phase_flashpoint", undefined, undefined, "fire");
    }
    {}
}
function blaze_phase_firewalker(sparams, n_damage)
{
    if (istrue(self.bp_dashing) && (self.cp_blaze_phase_major ?? 0) == 3) return 0;
    return n_damage;
}
function quiet_perk_blaze_phase_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
