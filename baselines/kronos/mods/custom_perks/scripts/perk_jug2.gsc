// @augment major Moon Hop | Jump height becomes 2.5x. Jumping reduces your gravity by 50% for 5 seconds.
// @augment major Hang Time | Hold jump while falling to glide.
// @augment major It's a Me! | Landing on a normal zombie kills it and bounces you back up.
// @augment minor Double Jump | Press jump again in the air to jump a second time.
// @augment minor Air Strafe | Move 20% faster while in the air.
// @augment minor Spring Step | Jumping out of a sprint carries you 20% further.
// @augment minor Gotta Go Fast! | Sprint 10% faster.
#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\common\values;
#using scripts\mp\common\perks\zombie\zombie_perks;
#namespace perk_jug2;
autoexec jug2_init()
{
    level thread jug2_register_perk();
}
function jug2_register_perk()
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
    def["id"] = "jug2";
    def["creator"] = "Gauty";
    def["code"] = 71;
    def["name"] = "Roo Brew";
    def["description"] = "Jump five times as high. Equip Moon Hop to reduce gravity for 5 seconds after jumping.";
    def["icon_material"] = "ui_icons_perks_zm_roo_brew";
    def["price"] = 2500;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_jug2_perk;
    def["on_take"] = &take_jug2_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        {}
        return;
    }
    level [[ level.cp_register_native ]]( "jug2", level.cp_defs["jug2"] );
    level callback::add(#"jump_begin", &roo_brew_on_jump);
    {}
    {}
}
function give_jug2_perk()
{
    self roo_brew_reset_gravity();
    self notify("roo_brew_stop");
    self quiet_perk_jug2_client_dvar(@"bo7_cp_client_owned_jug2", "1");
    self roo_brew_apply_jump_height();
    self.roo_charge_start = undefined;
    self roo_brew_send_charge(0);
    self roo_brew_charge_jump();
    self thread roo_brew_gravity_watch();
}
function roo_brew_has_minor(n)
{
    return (self.cp_jug2_minor ?? 0) == n || (self.cp_jug2_bonus ?? 0) == n;
}
function roo_brew_on_jump(params)
{
    if (!isplayer(self) || !isalive(self) || istrue(self.inlaststand)) return;
    if (!self zombie_perks::has_perk("specialty_jug2")) return;
    if (self roo_brew_has_minor(3) && istrue(self.roo_sprinting)) self thread roo_brew_spring_step();
    if ((self.cp_jug2_major ?? 0) != 1) return;
    self.roo_brew_gravity_until = gettime() + 5000;
    self.roo_brew_gravity_active = true;
    self setgravityscale(0.5);
}
function roo_brew_spring_step()
{
    self endon(#"disconnect");
    waitframe();
    self.roo_ss_vel = self getvelocity();
    self setvelocity((self.roo_ss_vel[0] * 1.2, self.roo_ss_vel[1] * 1.2, self.roo_ss_vel[2]));
}
function roo_brew_apply_jump_height()
{
    self.roo_h = 5;
    if ((self.cp_jug2_major ?? 0) == 1) self.roo_h = 2.5;
    if (!isdefined(self.roo_brew_height) || self.roo_brew_height != self.roo_h)
    {
        self setjumpheightscale(self.roo_h);
        self.roo_brew_height = self.roo_h;
    }
}
function roo_brew_reset_gravity()
{
    if (istrue(self.roo_brew_gravity_active) || istrue(self.roo_gliding)) self setgravityscale(1);
    self.roo_brew_gravity_active = false;
    self.roo_gliding = false;
    self.roo_brew_gravity_until = undefined;
}
function roo_brew_gravity_watch()
{
    self endon(#"disconnect");
    self endon("roo_brew_stop");
    level endon(#"game_ended");
    wait 0.15;
    while (true)
    {
        if (!self zombie_perks::has_perk("specialty_jug2"))
        {
            self val::reset("roo_loaded_leap", "allow_jump");
            self.roo_charge_start = undefined;
            self.roo_charge_blocked = false;
            self roo_brew_send_charge(0);
            self roo_brew_reset_gravity();
            self roo_brew_speed(false);
            return;
        }
        if (istrue(self.roo_brew_gravity_active))
        {
            if (!isalive(self) || istrue(self.inlaststand) || (self.cp_jug2_major ?? 0) != 1 || gettime() >= self.roo_brew_gravity_until)
                self roo_brew_reset_gravity();
        }
        self roo_brew_apply_jump_height();
        self.roo_on_ground = self isonground();
        self.roo_pressed = self jumpbuttonpressed();
        self.roo_vel = self getvelocity();
        if (self.roo_on_ground) self.roo_sprinting = self issprinting();
        self roo_brew_charge_jump();
        self roo_brew_double_jump();
        self roo_brew_hang_time();
        self roo_brew_stomp();
        self roo_brew_speed(isalive(self) && !istrue(self.inlaststand));
        wait 0.05;
    }
}
function roo_brew_double_jump()
{
    if (!self roo_brew_has_minor(1)) return;
    if (self.roo_on_ground)
    {
        self.roo_dj_used = false;
        self.roo_dj_released = false;
        return;
    }
    if (!istrue(self.roo_pressed))
    {
        self.roo_dj_released = true;
        return;
    }
    if (istrue(self.roo_dj_released) && !istrue(self.roo_dj_used) && isalive(self) && !istrue(self.inlaststand))
    {
        self.roo_dj_used = true;
        self.roo_dj_vel = self getvelocity();
        self setvelocity((self.roo_dj_vel[0], self.roo_dj_vel[1], 420));
        {}
    }
}
function roo_brew_hang_time()
{
    self.roo_glide_want = (self.cp_jug2_major ?? 0) == 2 && !self.roo_on_ground && istrue(self.roo_pressed) && self.roo_vel[2] < 0 && isalive(self);
    if (self.roo_glide_want && !istrue(self.roo_gliding))
    {
        self.roo_gliding = true;
        self setgravityscale(0.25);
    }
    else if (!self.roo_glide_want && istrue(self.roo_gliding))
    {
        self.roo_gliding = false;
        self setgravityscale(1);
    }
}
function roo_brew_stomp()
{
    if ((self.cp_jug2_major ?? 0) != 3 || self.roo_on_ground || self.roo_vel[2] >= 0 || gettime() < (self.roo_stomp_next ?? 0)) return;
    foreach (zombie in getaiarrayinradius(self.origin, 48))
    {
        if (!isdefined(zombie) || !isalive(zombie) || !isagent(zombie) || zombie.team == self.team) continue;
        if (isdefined(zombie.aicategory) && zombie.aicategory != "normal") continue;
        if (zombie.origin[2] > self.origin[2] || self.origin[2] - zombie.origin[2] > 90) continue;
        zombie dodamage(zombie.health + 1, zombie.origin, self, self, "MOD_IMPACT", "<explicitweaponnone>", "none", undefined, 65536);
        self.roo_stomp_next = gettime() + 300;
        self.roo_stomp_vel = self getvelocity();
        self setvelocity((self.roo_stomp_vel[0], self.roo_stomp_vel[1], 350));
        {}
        return;
    }
}
function roo_brew_speed(alive)
{
    self.roo_speed_want = 1;
    if (alive && self roo_brew_has_minor(2) && !self.roo_on_ground) self.roo_speed_want = 1.2;
    else if (alive && self roo_brew_has_minor(4) && self.roo_on_ground && self issprinting()) self.roo_speed_want = 1.1;
    if ((self.roo_speed ?? 1) == self.roo_speed_want) return;
    self.roo_speed = self.roo_speed_want;
    self setmovespeedscale(self.roo_speed);
}
function take_jug2_perk(b_pause, str_perk, str_result, n_slot)
{
    self val::reset("roo_loaded_leap", "allow_jump");
    self.roo_charge_start = undefined;
    self.roo_charge_blocked = false;
    self roo_brew_send_charge(0);
    self roo_brew_reset_gravity();
    self roo_brew_speed(false);
    self notify("roo_brew_stop");
    self quiet_perk_jug2_client_dvar(@"bo7_cp_client_owned_jug2", "0");
    self setjumpheightscale(1);
    self.roo_brew_height = undefined;
}
function roo_brew_charge_jump()
{
    if (istrue(self.roo_charge_blocked)) self val::reset("roo_loaded_leap", "allow_jump");
    self.roo_charge_blocked = false;
    self.roo_charge_start = undefined;
    if ((self.cp_jug2_major ?? 0) == 4) self.cp_jug2_major = 0;
}
function roo_brew_send_charge(pct)
{
    if (self.roo_charge_sent === pct) return;
    self.roo_charge_sent = pct;
}
function quiet_perk_jug2_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
