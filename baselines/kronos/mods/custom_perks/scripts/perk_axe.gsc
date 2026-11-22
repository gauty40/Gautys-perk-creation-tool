// @augment major Ricochet | After its first hit, the axe flies on to the nearest other zombie.
// @augment major Executioner | Axe hits instantly kill zombies under 15% health.
// @augment major Twin Blades | Each launch throws two axes in a small spread.
// @augment minor Sharpened | Axes deal 60% more weapon damage.
// @augment minor Fast Hands | One axe every 0.2 seconds instead of 0.3, but each axe deals half damage.
// @augment minor Long Throw | Axes fly 50% further.
// @augment minor Bleed Out | Zombies hit by an axe bleed for 1% of max health a second for 3 seconds.
#using scripts\common\utility;
#using scripts\common\trace;
#using scripts\mp\common\perks\zombie\zombie_perks;
#namespace perk_axe_shot;
autoexec axe_shot_init()
{
    level thread axe_shot_register();
}
function axe_shot_register()
{
    level endon(#"game_ended");
    level utility::flag_wait_all("StartGameTypeCallbackFinished", "zombie_perks_init_complete");
    if (!level.zombie_perks_in_use) return;
    if (!isdefined(level.cp_register) || !isdefined(level.cp_register_native))
    {
        {}
        return;
    }
    def = [];
    def["id"] = "axe_shot";
    def["code"] = 86;
    def["name"] = "Axe Shot";
    def["creator"] = "Gauty";
    def["description"] = "Firing launches a spinning axe (at most one every 0.3 seconds) that cuts through zombies for 60% of your held weapon's body-shot damage.";
    def["icon_material"] = "ui_icon_perks_zm_axe_shot";
    def["price"] = 2500;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_axe_shot;
    def["on_take"] = &take_axe_shot;
    if (!level [[level.cp_register]](def))
    {
        {}
        return;
    }
    level [[level.cp_register_native]]("axe_shot", level.cp_defs["axe_shot"]);
}
function give_axe_shot()
{
    self notify("axe_shot_stop");
    self thread axe_shot_watch_fire();
}
function take_axe_shot(b_pause, str_perk, str_result, n_slot)
{
    self notify("axe_shot_stop");
}
function axe_shot_has_minor(n)
{
    return (self.cp_axe_shot_minor ?? 0) == n || (self.cp_axe_shot_bonus ?? 0) == n;
}
function axe_shot_watch_fire()
{
    self endon(#"disconnect");
    self endon("axe_shot_stop");
    level endon(#"game_ended");
    for (;;)
    {
        self waittill(#"weapon_fired");
        if (!isalive(self) || istrue(self.inlaststand)) continue;
        if (!self zombie_perks::has_perk("specialty_axe_shot")) continue;
        if (gettime() < (self.axe_shot_next ?? 0)) continue;
        self.axe_shot_next = gettime() + 300;
        if (self axe_shot_has_minor(2)) self.axe_shot_next = gettime() + 200;
        self.axe_shot_angles = self getplayerangles();
        self.axe_shot_eye = self geteye();
        self.axe_shot_weapon = self getcurrentweapon();
        if (!isdefined(self.axe_shot_weapon) || isnullweapon(self.axe_shot_weapon)) continue;
        if ((self.cp_axe_shot_major ?? 0) == 3)
        {
            self axe_shot_launch(-6);
            self axe_shot_launch(6);
        }
        else
        {
            self axe_shot_launch(0);
        }
    }
}
function axe_shot_launch(yaw_offset)
{
    self.axe_shot_dir = (self.axe_shot_angles[0], self.axe_shot_angles[1] + yaw_offset, 0);
    self.axe_shot_blade = spawn("script_model", self.axe_shot_eye + anglestoforward(self.axe_shot_dir) * 60 + anglestoright(self.axe_shot_dir) * 8);
    if (!isdefined(self.axe_shot_blade)) return;
    self.axe_shot_blade.angles = (90, self.axe_shot_dir[1] - 90, 0);
    self.axe_shot_blade setmodel("offhand_sat_throwing_axe_fe");
    self.axe_shot_blade.fwd = anglestoforward(self.axe_shot_dir);
    self.axe_shot_blade.shot_weapon = self.axe_shot_weapon;
    self.axe_shot_blade.shot_damage = self.axe_shot_weapon getmaxdamage(0);
    self.axe_shot_blade.shot_damage *= weapongetdamagelocationmodifier(self.axe_shot_weapon, "torso_upper", 0) ?? 1;
    self.axe_shot_blade thread axe_shot_fly(self);
}
function axe_shot_speed() { return 400; }
function axe_shot_fly(owner)
{
    level endon(#"game_ended");
    self.owner = owner;
    if (!isdefined(level.axe_shot_contents))
    {
        level.axe_shot_contents = physics_createcontents(["physicscontents_missileclip", "physicscontents_clipshot", "physicscontents_glass"]);
    }
    self.max_range = 600;
    if (owner axe_shot_has_minor(3)) self.max_range = 900;
    self.range = self.max_range;
    self.wall = trace::ray_trace(owner.axe_shot_eye, owner.axe_shot_eye + self.fwd * self.max_range, owner, level.axe_shot_contents);
    if (isdefined(self.wall) && isdefined(self.wall["fraction"])) self.range = self.max_range * self.wall["fraction"];
    self.flight = self.range / axe_shot_speed();
    if (self.flight < 0.05)
    {
        level thread axe_shot_remove(self, owner);
        return;
    }
    level thread axe_shot_despawn(self, owner);
    self moveto(self.origin + self.fwd * self.range, self.flight);
    self rotateyaw(1080 * self.flight, self.flight);
    self.hits = [];
    self.ricocheted = false;
    while (isdefined(self) && isdefined(self.owner))
    {
        foreach (zombie in getaiarrayinradius(self.origin, 96))
        {
            if (!axe_shot_can_hit(zombie, self)) continue;
            self.hits[zombie getentitynumber()] = 1;
            self axe_shot_hit(zombie);
            if ((self.owner.cp_axe_shot_major ?? 0) == 1 && !self.ricocheted)
            {
                self.ricocheted = true;
                self axe_shot_ricochet();
            }
        }
        wait 0.05;
    }
}
function axe_shot_hit(zombie)
{
    self.damage = max(1, self.shot_damage ?? 1) * 0.6;
    if (self.owner axe_shot_has_minor(1)) self.damage *= 1.6;
    if (self.owner axe_shot_has_minor(2)) self.damage *= 0.5;
    if ((self.owner.cp_axe_shot_major ?? 0) == 2 && zombie.health <= (zombie.maxhealth ?? zombie.health) * 0.15)
    {
        zombie dodamage(zombie.health + 1, zombie.origin, self.owner, self.owner, "MOD_UNKNOWN", "<explicitweaponnone>", "none", undefined, 65536);
    }
    else
    {
        zombie dodamage(self.damage, zombie.origin, self.owner, self.owner, "MOD_RIFLE_BULLET", self.shot_weapon, "torso_upper", undefined, 0);
    }
    if (isalive(zombie) && self.owner axe_shot_has_minor(4)) zombie thread axe_shot_bleed(self.owner);
}
function axe_shot_bleed(owner)
{
    self endon(#"death");
    if (istrue(self.axe_bleeding)) return;
    self.axe_bleeding = true;
    self.axe_bleed_n = 0;
    while (self.axe_bleed_n < 3)
    {
        wait 1;
        self.axe_bleed_n = self.axe_bleed_n + 1;
        if (!isdefined(owner)) break;
        self dodamage(max(1, (self.maxhealth ?? self.health) * 0.01), self.origin, owner, owner, "MOD_UNKNOWN", "<explicitweaponnone>", "none", undefined, 65536);
    }
    self.axe_bleeding = false;
}
function axe_shot_ricochet()
{
    self.next_target = undefined;
    self.next_dist = 300;
    foreach (zombie in getaiarrayinradius(self.origin, 300))
    {
        if (!isdefined(zombie) || !isalive(zombie) || isdefined(self.hits[zombie getentitynumber()])) continue;
        if (isdefined(zombie.team) && isdefined(self.owner.team) && zombie.team == self.owner.team) continue;
        if (distance(self.origin, zombie.origin) < self.next_dist)
        {
            self.next_dist = distance(self.origin, zombie.origin);
            self.next_target = zombie;
        }
    }
    if (!isdefined(self.next_target)) return;
    self.redirected = true;
    self.flight = max(0.1, self.next_dist / axe_shot_speed());
    self moveto(self.next_target.origin + (0, 0, 40), self.flight);
    self rotateyaw(1080 * self.flight, self.flight);
}
function axe_shot_despawn(axe, owner)
{
    axe endon(#"death");
    while (isdefined(axe))
    {
        axe.redirected = false;
        axe utility::waittill_any_timeout(axe.flight + 0.1, "movedone");
        if (!istrue(axe.redirected)) break;
    }
    level thread axe_shot_remove(axe, owner);
}
function axe_shot_remove(axe, owner)
{
    if (isdefined(axe)) axe delete();
}
function axe_shot_can_hit(zombie, blade)
{
    if (!isdefined(zombie) || !isalive(zombie) || isplayer(zombie)) return false;
    if (!isagent(zombie) && !issentient(zombie)) return false;
    if (isdefined(zombie.team) && isdefined(blade.owner.team) && zombie.team == blade.owner.team) return false;
    if (isdefined(blade.hits[zombie getentitynumber()])) return false;
    if (blade.origin[2] < zombie.origin[2] - 10 || blade.origin[2] > zombie.origin[2] + 85) return false;
    return distance((blade.origin[0], blade.origin[1], 0), (zombie.origin[0], zombie.origin[1], 0)) < 36;
}
