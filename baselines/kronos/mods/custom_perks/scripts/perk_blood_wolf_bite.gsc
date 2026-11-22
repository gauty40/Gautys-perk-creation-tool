// @augment major Pack Leader | Summons two hounds instead of one.
// @augment major Alpha | Your hound deals triple damage to special and elite zombies.
// @augment major Blood Bond | While your hound is out, each kill it makes heals you 5%.
// @augment minor Quick Call | Cooldown 45 seconds -> 30.
// @augment minor Long Hunt | The hound stays 45 seconds instead of 30.
// @augment minor Hellfire Hound | The hound's bites set zombies on fire.
// @augment minor Hair Trigger | Needs 5 zombies' worth of damage to summon instead of 8.
#using scripts\common\ai\aitypes\shared\zombie\zombie_utils;
#using scripts\common\callbacks;
#using scripts\common\shared_func_utility;
#using scripts\common\status_effects\effect_burn;
#using scripts\common\utility;
#using scripts\mp\common\perks\zombie\zombie_perks;
#using scripts\mp\mp_agent;
#namespace perk_blood_wolf_bite;
autoexec blood_wolf_bite_init()
{
    level.bw_subclasses = [ "zombie_hellhound", "zombie_vermin", "zombie_loom_minion", "zombie_base" ];
    level thread blood_wolf_bite_register_perk();
}
function blood_wolf_bite_register_perk()
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
    def["id"] = "blood_wolf_bite";
    def["creator"] = "Gauty";
    def["code"] = 92;
    def["name"] = "Blood Wolf Bite";
    def["description"] = "Dealing heavy damage in a short time summons a friendly hellhound that hunts zombies for 30 seconds (45 second cooldown).";
    def["icon_material"] = "ui_icon_perks_blood_wolf_bite";
    def["price"] = 3000;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_blood_wolf_bite_perk;
    def["on_take"] = &take_blood_wolf_bite_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        {}
        return;
    }
    level [[ level.cp_register_native ]]( "blood_wolf_bite", level.cp_defs["blood_wolf_bite"] );
    zombie_utils::register_zombie_agent_damage_callback( &blood_wolf_bite_on_zombie_damage );
    level callback::add( #"on_ai_killed", &blood_wolf_bite_on_kill );
    {}
}
function give_blood_wolf_bite_perk()
{
    self quiet_perk_blood_wolf_bite_client_dvar( @"bo7_cp_client_owned_blood_wolf_bite", "1" );
}
function take_blood_wolf_bite_perk( b_pause, str_perk, str_result, n_slot )
{
    self quiet_perk_blood_wolf_bite_client_dvar( @"bo7_cp_client_owned_blood_wolf_bite", "0" );
}
function blood_wolf_bite_has_minor( player, n )
{
    return isdefined( player ) && ( ( player.cp_blood_wolf_bite_minor ?? 0 ) == n || ( player.cp_blood_wolf_bite_bonus ?? 0 ) == n );
}
function blood_wolf_bite_wolf_out()
{
    return ( isdefined( self.bw_wolf ) && isalive( self.bw_wolf ) ) || ( isdefined( self.bw_wolf2 ) && isalive( self.bw_wolf2 ) );
}
function blood_wolf_bite_on_zombie_damage( params )
{
    if ( !isdefined( params.idamage ) || !isdefined( params.eattacker ) )
    {
        return params.idamage;
    }
    if ( isdefined( params.eattacker.bw_owner ) )
    {
        self.bw_bite = params.idamage;
        if ( ( params.eattacker.bw_owner.cp_blood_wolf_bite_major ?? 0 ) == 2 && isdefined( self.aicategory ) && self.aicategory != "normal" )
        {
            self.bw_bite = params.idamage * 3;
        }
        if ( blood_wolf_bite_has_minor( params.eattacker.bw_owner, 3 ) && gettime() >= ( self.bw_burn_next ?? 0 ) )
        {
            self.bw_burn_next = gettime() + 1000;
            self thread effect_burn::burn( 3, max( 1, ( self.maxhealth ?? self.health ) * 0.02 ), 1, params.eattacker.bw_owner, "blood_wolf_bite_hellfire", undefined, undefined, "fire" );
        }
        return self.bw_bite;
    }
    if ( !isplayer( params.eattacker ) || !params.eattacker zombie_perks::has_perk( "specialty_blood_wolf_bite" ) )
    {
        return params.idamage;
    }
    if ( gettime() > ( params.eattacker.bw_window_end ?? 0 ) )
    {
        params.eattacker.bw_window_end = gettime() + 5000;
        params.eattacker.bw_meter = 0;
    }
    params.eattacker.bw_meter = params.eattacker.bw_meter + params.idamage;
    params.eattacker.bw_need = 8;
    if ( blood_wolf_bite_has_minor( params.eattacker, 4 ) ) params.eattacker.bw_need = 5;
    params.eattacker.bw_goal = ( self.maxhealth ?? 150 ) * params.eattacker.bw_need;
    if ( params.eattacker.bw_meter >= params.eattacker.bw_goal && gettime() >= ( params.eattacker.bw_ready_at ?? 0 )
        && !params.eattacker blood_wolf_bite_wolf_out() )
    {
        params.eattacker.bw_meter = 0;
        params.eattacker.bw_cooldown_duration = 45000;
        params.eattacker.bw_ready_at = gettime() + params.eattacker.bw_cooldown_duration;
        if ( blood_wolf_bite_has_minor( params.eattacker, 1 ) )
        {
            params.eattacker.bw_cooldown_duration = 30000;
            params.eattacker.bw_ready_at = gettime() + params.eattacker.bw_cooldown_duration;
        }
        params.eattacker thread blood_wolf_bite_summon();
    }
    return params.idamage;
}
function blood_wolf_bite_on_kill( params )
{
    if ( !isdefined( params ) || !isdefined( params.eattacker ) || !isdefined( params.eattacker.bw_owner ) ) return;
    if ( ( params.eattacker.bw_owner.cp_blood_wolf_bite_major ?? 0 ) != 3 || !isalive( params.eattacker.bw_owner ) ) return;
    params.eattacker.bw_owner.bw_heal = params.eattacker.bw_owner.maxhealth * 0.05;
    params.eattacker.bw_owner.health = int( min( params.eattacker.bw_owner.maxhealth, params.eattacker.bw_owner.health + params.eattacker.bw_owner.bw_heal ) );
}
function blood_wolf_bite_summon()
{
    self endon( #"disconnect" );
    self.bw_fwd = vectornormalize( anglestoforward( self.angles ) );
    self.bw_pos = getclosestpointonnavmesh( self.origin + self.bw_fwd * 256 );
    if ( !istrue( utility::callsharedfunc( #"zombie", #"hash_bad01cbc996e3dba", self.bw_pos ) ) )
    {
        self.bw_pos = getclosestpointonnavmesh( self.origin + self.bw_fwd * 128 );
    }
    if ( !isdefined( self.bw_pos ) || !istrue( utility::callsharedfunc( #"zombie", #"hash_bad01cbc996e3dba", self.bw_pos ) ) )
    {
        self.bw_pos = self.origin;
    }
    self.bw_type = undefined;
    self.bw_i = 0;
    while ( !isdefined( self.bw_type ) && self.bw_i < level.bw_subclasses.size )
    {
        self.bw_type = getaitypefromsubclass( level.bw_subclasses[ self.bw_i ] );
        self.bw_i = self.bw_i + 1;
    }
    if ( !isdefined( self.bw_type ) )
    {
        {}
        return;
    }
    self.bw_life = 30;
    if ( blood_wolf_bite_has_minor( self, 2 ) ) self.bw_life = 45;
    self.bw_wolf = self blood_wolf_bite_spawn( self.bw_pos );
    self.bw_wolf2 = undefined;
    if ( ( self.cp_blood_wolf_bite_major ?? 0 ) == 1 )
    {
        self.bw_pos2 = getclosestpointonnavmesh( self.bw_pos + anglestoright( self.angles ) * 64 );
        if ( !isdefined( self.bw_pos2 ) ) self.bw_pos2 = self.bw_pos;
        self.bw_wolf2 = self blood_wolf_bite_spawn( self.bw_pos2 );
    }
    if ( !isdefined( self.bw_wolf ) && !isdefined( self.bw_wolf2 ) )
    {
        {}
        return;
    }
    self playrumbleonentity( "damage_heavy" );
    {}
}
function blood_wolf_bite_spawn( pos )
{
    self.bw_new = mp_agent::spawnnewagentaitype( self.bw_type, pos, ( 0, self.angles[1], 0 ), self.team );
    if ( !isdefined( self.bw_new ) )
    {
        return undefined;
    }
    self.bw_new.disable_zombie_drops = 1;
    self.bw_new.ignore_enemy_count = 1;
    self.bw_new.bw_owner = self;
    self.bw_new zombie_utils::brainrot_ai( self, self.bw_life, 1 );
    self.bw_new.n_brainrot_damage = shared_func_utility::function_870440d8340968c0( "zombie_base", self.bw_new zombie_utils::get_zombie_round_difficulty() );
    self.bw_new.var_b7d346480d1fc488 = 1;
    return self.bw_new;
}
function quiet_perk_blood_wolf_bite_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
