#using scripts\common\callbacks;
#using scripts\common\powerups;
#using scripts\common\utility;
#using scripts\mp\common\perks\zombie\zombie_perks;
#namespace perk_nuka_cola;
autoexec nuka_cola_init()
{
    level thread nuka_cola_register_perk();
}
function nuka_cola_register_perk()
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
    def["id"] = "nuka_cola";
    def["creator"] = "Gauty";
    def["code"] = 88;
    def["name"] = "Nuka Cola";
    def["description"] = "Going down drops a Nuke powerup where you fell.";
    def["icon_material"] = "ui_icon_perks_nuka_cola";
    def["price"] = 2000;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_nuka_cola_perk;
    def["on_take"] = &take_nuka_cola_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        {}
        return;
    }
    level [[ level.cp_register_native ]]( "nuka_cola", level.cp_defs["nuka_cola"] );
    level callback::add( #"player_laststand_pre_enter", &nuka_cola_on_down );
    {}
}
function give_nuka_cola_perk()
{
    self.nk_owned = true;
    self quiet_perk_nuka_cola_client_dvar( @"bo7_cp_client_owned_nuka_cola", "1" );
}
function take_nuka_cola_perk( b_pause, str_perk, str_result, n_slot )
{
    self.nk_owned = false;
    self.nk_owned_until = gettime() + 2000;
    self quiet_perk_nuka_cola_client_dvar( @"bo7_cp_client_owned_nuka_cola", "0" );
}
function nuka_cola_on_down( params )
{
    if ( !isplayer( self ) )
    {
        return;
    }
    if ( !( istrue( self.nk_owned ) || self zombie_perks::has_perk( "specialty_nuka_cola" ) || gettime() < ( self.nk_owned_until ?? 0 ) ) )
    {
        return;
    }
    self.nk_owned_until = 0;
    level thread powerups::powerup_drop( "nuke", self.origin + ( 0, 0, 40 ) );
    {}
}
function quiet_perk_nuka_cola_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
