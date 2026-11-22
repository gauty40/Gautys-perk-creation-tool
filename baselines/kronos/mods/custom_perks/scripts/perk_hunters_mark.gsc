// @augment major Bear the mark | A marked zombie that drops below 20% health is killed by the next hit.
// @augment major Cursed | Marked zombies take 100% more damage instead of 50%.
// @augment major Big Game Hunter | Allows Hunter's Hooch to activate on special and elite zombies.
// @augment minor Quick Hunt | Cooldown time reduced by 50%.
// @augment minor Lingering Mark | The mark lasts 6 seconds longer.
// @augment minor Open Season | Killing the marked zombie resets the cooldown instantly.
// @augment minor Bounty | Killing the marked zombie gives 25 points.
#using scripts\common\utility;
#using scripts\mp\currency;
#using scripts\mp\objidpoolmanager;
#using scripts\common\ai\aitypes\zombie_base\zombie_base_dismemberment;
#using scripts\common\ai\aitypes\shared\zombie\zombie_utils;
#using scripts\mp\common\perks\zombie\zombie_perks;
#namespace perk_hunters_mark;
autoexec hunters_mark_init()
{
    setdvar(@"bo7_hm_marker_ids", ",");
    level thread hunters_mark_register_perk();
}
function hunters_mark_cooldown_ms()
{
    return 20000;
}
function hunters_mark_duration_ms()
{
    return 8000;
}
function hunters_mark_bonus()
{
    return 0.5;
}
function hunters_mark_execute_fraction()
{
    return 0.2;
}
function hunters_mark_allow_special()
{
    return false;
}
function hunters_mark_special_health_ratio()
{
    return 4;
}
function hunters_mark_register_perk()
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
    def["id"] = "hunters_mark";
    def["creator"] = "Gauty";
    def["code"] = 87;
    def["name"] = "Hunter's Hooch";
    def["description"] = "The first regular zombie you damage is marked for 8 seconds. Marked zombies take 50% more damage from everyone (20 second cooldown).";
    def["icon_material"] = "ui_icons_perks_zm_hunters_hooch";
    def["price"] = 2500;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_hunters_mark_perk;
    def["on_take"] = &take_hunters_mark_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        {}
        return;
    }
    level [[ level.cp_register_native ]]( "hunters_mark", level.cp_defs["hunters_mark"] );
    zombie_utils::register_zombie_agent_damage_callback( &hunters_mark_on_zombie_damage );
    {}
}
give_hunters_mark_perk()
{
    self notify( "specialty_hunters_mark_stop" );
    self quiet_perk_hunters_mark_client_dvar( @"bo7_cp_client_owned_hunters_mark", "1" );
    {}
}
take_hunters_mark_perk( b_pause, str_perk, str_result, n_slot )
{
    self quiet_perk_hunters_mark_client_dvar( @"bo7_cp_client_owned_hunters_mark", "0" );
    {}
    self notify( "specialty_hunters_mark_stop" );
}
function hunters_mark_major( e_player )
{
    if ( isdefined( e_player.cp_hunters_mark_major ) )
    {
        return e_player.cp_hunters_mark_major;
    }
    return 0;
}
function hunters_mark_has_minor( e_player, n_index )
{
    n_minor = 0;
    if ( isdefined( e_player.cp_hunters_mark_minor ) )
    {
        n_minor = e_player.cp_hunters_mark_minor;
    }
    n_bonus = 0;
    if ( isdefined( e_player.cp_hunters_mark_bonus ) )
    {
        n_bonus = e_player.cp_hunters_mark_bonus;
    }
    return n_minor == n_index || n_bonus == n_index;
}
function hunters_mark_on_zombie_damage( params )
{
    n_damage = params.idamage;
    e_attacker = params.eattacker;
    if ( !isdefined( n_damage ) || !isdefined( self ) || !isalive( self ) )
    {
        return n_damage;
    }
    self hunters_mark_note_health();
    if ( isplayer( e_attacker ) && e_attacker zombie_perks::has_perk( "specialty_hunters_mark" ) && !hunters_mark_is_marked() )
    {
        if ( !isdefined( e_attacker.hm_ready_at ) || gettime() >= e_attacker.hm_ready_at )
        {
            if ( hunters_mark_major(e_attacker) == 3 || hunters_mark_allow_special() || self hunters_mark_is_regular() )
            {
                self hunters_mark_apply( e_attacker );
            }
        }
    }
    if ( hunters_mark_is_marked() )
    {
        n_damage = n_damage * ( 1 + self.hm_bonus );
        if ( self.hm_execute && !self hunters_hooch_is_boss() && isdefined( self.health ) && isdefined( self.maxhealth ) && self.maxhealth > 0 )
        {
            if ( ( self.health - n_damage ) <= self.maxhealth * hunters_mark_execute_fraction() && n_damage < self.health )
            {
                n_damage = self.health;
                {}
            }
        }
    }
    return n_damage;
}
function hunters_mark_note_health()
{
    if ( !isdefined( self.maxhealth ) || self.maxhealth <= 0 )
    {
        return;
    }
    if ( !isdefined( level.hm_base_health ) || !isdefined( level.hm_base_at ) || ( gettime() - level.hm_base_at ) > 60000 )
    {
        level.hm_base_health = self.maxhealth;
        level.hm_base_at = gettime();
        return;
    }
    if ( self.maxhealth < level.hm_base_health )
    {
        level.hm_base_health = self.maxhealth;
        level.hm_base_at = gettime();
    }
}
function hunters_mark_is_regular()
{
    if (self hunters_hooch_is_boss()) return false;
    if (isdefined(self.aicategory)) return self.aicategory == "normal";
    if ( isdefined( self.maxhealth ) && isdefined( level.hm_base_health ) && level.hm_base_health > 0 )
    {
        if ( self.maxhealth > level.hm_base_health * hunters_mark_special_health_ratio() )
        {
            {}
            return false;
        }
    }
    return true;
}
function hunters_hooch_is_boss()
{
    return (isdefined(self.aicategory) && self.aicategory == "boss") || isdefined(self.bosshealthsettings);
}
function hunters_mark_is_marked()
{
    if ( !isdefined( self.hm_until ) || gettime() >= self.hm_until )
    {
        return false;
    }
    if ( !isdefined( self.hm_owner ) || !isdefined( self.hm_owner.health ) || !self.hm_owner zombie_perks::has_perk( "specialty_hunters_mark" ) )
    {
        return false;
    }
    return true;
}
function hunters_mark_apply( e_owner )
{
    n_cooldown = hunters_mark_cooldown_ms();
    n_duration = hunters_mark_duration_ms();
    n_bonus = hunters_mark_bonus();
    b_execute = false;
    n_major = hunters_mark_major( e_owner );
    if ( n_major == 2 )
    {
        n_bonus = 1.0;
    }
    if ( n_major == 1 )
    {
        b_execute = true;
    }
    if ( hunters_mark_has_minor( e_owner, 1 ) )
    {
        n_cooldown = int( n_cooldown / 2 );
    }
    if ( hunters_mark_has_minor( e_owner, 2 ) )
    {
        n_duration = n_duration + 6000;
    }
    n_now = gettime();
    e_owner.hm_ready_at = n_now + n_cooldown;
    e_owner.hm_charge_duration = n_cooldown;
    self.hm_owner = e_owner;
    self.hm_until = n_now + n_duration;
    self.hm_bonus = n_bonus;
    self.hm_execute = b_execute;
    self thread hunters_mark_pulse_fx( self.hm_until );
    self thread hunters_hooch_head_marker(self.hm_until);
    self thread hunters_mark_watch_death( e_owner, self.hm_until );
    {}
}
function hunters_mark_watch_death( e_owner, n_until )
{
    self waittill( #"death" );
    if ( !isdefined( e_owner ) || gettime() >= n_until || !e_owner zombie_perks::has_perk( "specialty_hunters_mark" ) )
    {
        return;
    }
    if ( hunters_mark_has_minor( e_owner, 4 ) )
    {
        e_owner currency::add_currency_amount( #"essence", 25, #"hunters_hooch_bounty" );
        {}
    }
    if ( !hunters_mark_has_minor( e_owner, 3 ) )
    {
        return;
    }
    e_owner.hm_ready_at = gettime();
    {}
}
function hunters_hooch_head_marker(n_until)
{
    level endon(#"game_ended");
    objid = objidpoolmanager::requestobjectiveid(1);
    if (!isdefined(objid) || objid == -1)
    {
        {}
        return;
    }
    objective_position(objid, self.origin + (0, 0, 88));
    objective_state(objid, "current");
    if (!isdefined(level.hm_marker_objectives)) level.hm_marker_objectives = [];
    level.hm_marker_objectives[objid] = true;
    hunters_hooch_publish_markers();
    objective_icon(objid, "empty_ring_default");
    objective_settint(objid, 255, 255, 255);
    objective_setbackground(objid, 0);
    objective_setshowdistance(objid, 0);
    objective_setplayintro(objid, 0);
    objective_setownerteam(objid, undefined);
    objidpoolmanager::objective_set_is_zone(objid, 0);
    objidpoolmanager::objective_playermask_showtoallplayers(objid);
    {}
    while (isdefined(self) && isalive(self) && gettime() < n_until)
    {
        if (self.hm_until != n_until || !self hunters_mark_is_marked()) break;
        position = self.origin + (0, 0, 88);
        if (self tagexists("j_head")) position = self gettagorigin("j_head") + (0, 0, 18);
        objective_position(objid, position);
        wait 0.05;
    }
    level.hm_marker_objectives[objid] = undefined;
    hunters_hooch_publish_markers();
    objidpoolmanager::returnobjectiveid(objid);
}
function hunters_hooch_publish_markers()
{
    ids = ",";
    foreach (id, active in level.hm_marker_objectives)
    {
        if (istrue(active)) ids = ids + id + ",";
    }
    setdvar(@"bo7_hm_marker_ids", ids);
    foreach (player in level.players)
    {
        if (isdefined(player)) player quiet_perk_hunters_mark_client_dvar(@"bo7_hm_marker_ids", ids);
    }
}
function hunters_mark_pulse_fx(n_until)
{
    level endon(#"game_ended");
    self notify("hunters_hooch_visual_stop");
    self endon("hunters_hooch_visual_stop");
    if (!self isscriptable() || !self getscriptablehaspart("frenzied_guard")) return;
    previous_state = "";
    while (isalive(self) && gettime() < n_until && self hunters_mark_is_marked())
    {
        state = "frenzied_guard_on";
        if (self zombie_base_dismemberment::is_crawling() && self getscriptableparthasstate("frenzied_guard", "frenzied_guard_crawler_on"))
            state = "frenzied_guard_crawler_on";
        if (state != previous_state)
        {
            self setscriptablepartstate("frenzied_guard", state, 1);
            previous_state = state;
        }
        wait 0.1;
    }
    if (isdefined(self) && self isscriptable() && self getscriptablehaspart("frenzied_guard"))
        self setscriptablepartstate("frenzied_guard", "frenzied_guard_off", 1);
}
function quiet_perk_hunters_mark_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
