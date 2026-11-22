#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\mp\common\perks\zombie\zombie_perks;
#using scripts\mp\playerhealth;
#using scripts\mp\common\utility\lui_game_event_aggregator;
#namespace perk_vitality;
// @augment major Rapid Recovery | Doubles healing while crouched.
// @augment major Siphon Pulse | Damages nearby zombies while crouched.
// @augment minor Potent Pulse | Adds periodic healing while crouched.
// @augment minor Prone Recovery | Also heals while prone.
autoexec vitality_init()
{
    {}
    {}
    {}
    level thread vitality_register_perk();
}
function vitality_register_perk()
{
    level endon( #"game_ended" );
    level utility::flag_wait_all( "StartGameTypeCallbackFinished", "zombie_perks_init_complete" );
    if ( !level.zombie_perks_in_use )
    {
        {}
        return;
    }
    if ( !isdefined( level.cp_register ) || !isdefined( level.cp_register_native ) )
    {
        {}
        return;
    }
    def = [];
    def["id"] = "vitality";
    def["creator"] = "Gauty";
    def["code"] = 70;
    def["name"] = "Vitality";
    def["description"] = "Regenerates health while crouched.";
    def["icon_material"] = "ui_icon_perks_zm_custom";
    def["price"] = 2500;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_vitality_perk;
    def["on_take"] = &take_vitality_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        {}
        return;
    }
    level [[ level.cp_register_native ]]( "vitality", level.cp_defs["vitality"] );
    {}
    {}
    {}
}
give_vitality_perk()
{
    self quiet_perk_vitality_client_dvar( @"bo7_cp_client_owned_vitality", "1" );
    {}
    {}
    bundle = level.perkbundles[ "specialty_juggernog" ];
    if ( !isdefined( self.maxhealth ) )
    {
        return;
    }
    if ( !utility::ent_flag( "disable_player_heal_items" ) )
    {
        self.health = self.maxhealth;
    }
    n_max_total_health = self.maxhealth + bundle.var_f40eb2103401205e;
    self.maxhealth = n_max_total_health;
    callback::callback( "on_player_max_health_change", { #new_max_health:n_max_total_health } );
    playerhealth::forcehealthregendelay( self, 1, 1 );
    self.vitality_candidate = undefined;
    self.vitality_stable_stance = "unknown";
    self thread vitality_crouch_regen();
    self thread vitality_augment_effects();
}
function vitality_crouch_regen()
{
    self endon( #"death_or_disconnect" );
    while ( self zombie_perks::has_perk( "specialty_vitality" ) )
    {
        wait 0.1;
        if ( !isdefined( self.health ) || !isdefined( self.maxhealth ) || !isalive( self ) )
        {
            return;
        }
        eye_height = self geteye()[2] - self.origin[2];
        raw_pose = "stand";
        if (eye_height < 25) raw_pose = "prone";
        else if (eye_height < 50) raw_pose = "crouch";
        now = gettime();
        if (!isdefined(self.vitality_candidate) || self.vitality_candidate != raw_pose)
        {
            self.vitality_candidate = raw_pose;
            self.vitality_candidate_since = now;
        }
        self.vitality_stable_stance = "unknown";
        if (now - self.vitality_candidate_since >= 5000) self.vitality_stable_stance = raw_pose;
        if ( self.vitality_stable_stance == "crouch" && self.health < self.maxhealth )
        {
            self.health = minint( self.health + 5, self.maxhealth );
        }
    }
}
function vitality_augment_effects()
{
    self endon( #"death_or_disconnect" );
    n_tick = 0;
    while ( self zombie_perks::has_perk( "specialty_vitality" ) )
    {
        wait 0.1;
        n_tick = n_tick + 1;
        if ( !isdefined( self.health ) || !isdefined( self.maxhealth ) || !isalive( self ) )
        {
            return;
        }
        n_major_augment = 0;
        if ( isdefined( self.cp_vitality_major ) )
        {
            n_major_augment = self.cp_vitality_major;
        }
        n_minor_augment = 0;
        if ( isdefined( self.cp_vitality_minor ) )
        {
            n_minor_augment = self.cp_vitality_minor;
        }
        n_bonus_augment = 0;
        if ( isdefined( self.cp_vitality_bonus ) )
        {
            n_bonus_augment = self.cp_vitality_bonus;
        }
        s_pick = "player_sync";
        n_extra_heal = 0;
        eye_height = self geteye()[2] - self.origin[2];
        raw_pose = "stand";
        if (eye_height < 25) raw_pose = "prone";
        else if (eye_height < 50) raw_pose = "crouch";
        now = gettime();
        if (!isdefined(self.vitality_candidate) || self.vitality_candidate != raw_pose)
        {
            self.vitality_candidate = raw_pose;
            self.vitality_candidate_since = now;
        }
        self.vitality_stable_stance = "unknown";
        if (now - self.vitality_candidate_since >= 5000) self.vitality_stable_stance = raw_pose;
        if (!isdefined(self.vitality_height_log_at) || now >= self.vitality_height_log_at)
        {
            self.vitality_height_log_at = now + 10000;
            {}
        }
        str_stance = self.vitality_stable_stance;
        if (!isdefined(str_stance)) str_stance = "unknown";
        {}
        if ( str_stance == "crouch" )
        {
            if ( n_major_augment == 1 )
            {
                n_extra_heal = n_extra_heal + 5;
            }
            if ( n_major_augment == 2 )
            {
                vitality_damage_nearby_zombies( 5 );
            }
            if ( ( n_minor_augment == 1 || n_bonus_augment == 1 ) && ( n_tick % 2 ) == 0 )
            {
                n_extra_heal = n_extra_heal + 5;
            }
        }
        else if ( ( n_minor_augment == 2 || n_bonus_augment == 2 ) && (str_stance == "crouch" || str_stance == "prone") )
        {
            n_extra_heal = 5;
        }
        if ( n_extra_heal > 0 && self.health < self.maxhealth )
        {
            self.health = minint( self.health + n_extra_heal, self.maxhealth );
        }
    }
}
function vitality_damage_nearby_zombies( n_damage )
{
    zombies = getaiarrayinradius( self.origin, 400 );
    foreach ( zombie in zombies )
    {
        if ( isagent( zombie ) && isalive( zombie ) )
        {
            zombie dodamage( n_damage, zombie.origin, self, self, "MOD_ELEMENTAL_ELEC", "<explicitweaponnone>", "none", undefined, 65536 );
        }
    }
}
take_vitality_perk( b_pause, str_perk, str_result, n_slot )
{
    self quiet_perk_vitality_client_dvar( @"bo7_cp_client_owned_vitality", "0" );
    {}
    {}
    bundle = level.perkbundles[ "specialty_juggernog" ];
    n_base_health = int( getmatchrulesdata( "commonOption", "maxHealth" ) );
    n_max_total_health = max( n_base_health, self.maxhealth - bundle.var_f40eb2103401205e );
    self.maxhealth = n_max_total_health;
    if ( isalive( self ) )
    {
        self.health = n_max_total_health;
    }
    callback::callback( "on_player_max_health_change", { #new_max_health:n_max_total_health } );
}
function quiet_perk_vitality_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
