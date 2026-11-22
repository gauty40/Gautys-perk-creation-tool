// @augment major Golden Payout | Increases points from 1.25x to 1.35x while the perk is active.
// @augment major Golden Refund | Purchases have a 10% chance to refund their full cost.
// @augment major Scrap Dividend | Earn 25% more salvage.
// @augment minor Golden Strike | Awards double points for melee kills.
// @augment minor Gold Rush | Headshot kills give 5% more points.
// @augment minor Bargain Hunter | Purchases cost 5% less.
// @augment minor Payday | At the end of every round, earn 5% of your current points.
#using scripts\common\ai\aitypes\shared\zombie\zombie_utils;
#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\mp\common\perks\zombie\zombie_perks;
#using scripts\mp\zm\points;
#using scripts\mp\currency;
#namespace perk_gautys_gold;
autoexec gautys_gold_init()
{
    {}
    level thread gautys_gold_register_perk();
}
function gautys_gold_register_perk()
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
    def["id"] = "gautys_gold";
    def["creator"] = "Gauty";
    def["code"] = 82;
    def["name"] = "Gauty's Gold";
    def["description"] = "Earns 1.25x points while this perk is active.";
    def["icon_material"] = "ui_icon_perks_zm_Gautys_Gold";
    def["price"] = 2500;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_gautys_gold_perk;
    def["on_take"] = &take_gautys_gold_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        {}
        return;
    }
    level [[ level.cp_register_native ]]( "gautys_gold", level.cp_defs["gautys_gold"] );
    callback::add("currency_sub", &gautys_gold_refund_purchase);
    callback::add("currency_sub", &gautys_gold_bargain_hunter);
    callback::add("currency_add", &gautys_gold_salvage_bonus);
    zombie_utils::register_zombie_agent_damage_callback( &gautys_gold_headshot_watch );
    if ( !isdefined( level.gautys_gold_point_hook_running ) )
    {
        level.gautys_gold_point_hook_running = 1;
        level thread gautys_gold_point_hook_watch();
    }
    {}
    {}
}
function gautys_gold_point_hook_watch()
{
    level endon( #"game_ended" );
    while ( 1 )
    {
        if ( !isdefined( level.modifyunifiedpointscallback ) )
        {
            if ( !isdefined( level.gautys_gold_point_hook_missing_logged ) )
            {
                level.gautys_gold_point_hook_missing_logged = 1;
                {}
            }
        }
        else if ( level.modifyunifiedpointscallback != &gautys_gold_modify_points )
        {
            level.gautys_gold_original_point_callback = level.modifyunifiedpointscallback;
            level.modifyunifiedpointscallback = &gautys_gold_modify_points;
            {}
            {}
        }
        wait 1;
    }
}
function gautys_gold_modify_points( points, event, player, objweapon, eventinfo )
{
    if ( !isdefined( level.gautys_gold_original_point_callback ) )
    {
        return points;
    }
    points = player [[ level.gautys_gold_original_point_callback ]]( points, event, player, objweapon, eventinfo );
    if ( isplayer( player ) &&
         isdefined( player.gautys_gold_melee_augment ) &&
         player.gautys_gold_melee_augment &&
         isdefined( eventinfo ) &&
         isdefined( eventinfo.smeansofdeath ) &&
         eventinfo.smeansofdeath == "MOD_MELEE" )
    {
        points = points * 2;
    }
    if ( isplayer( player ) && istrue( player.has_gautys_gold ) && gautys_gold_has_minor( player, 2 ) && gettime() - ( player.gg_headshot_kill_at ?? -1000 ) <= 100 )
    {
        points = points * 1.05;
    }
    return int( points );
}
function gautys_gold_has_minor( player, n )
{
    return ( player.cp_gold_minor ?? 0 ) == n || ( player.cp_gold_bonus ?? 0 ) == n;
}
function gautys_gold_headshot_watch( params )
{
    if ( isdefined( params.idamage ) && isplayer( params.eattacker ) && isdefined( params.shitloc ) && isdefined( self.health )
        && params.idamage >= self.health && ( params.shitloc == "head" || params.shitloc == "helmet" || params.shitloc == "neck" ) )
    {
        params.eattacker.gg_headshot_kill_at = gettime();
    }
    return params.idamage;
}
function gautys_gold_bargain_hunter( params )
{
    if ( !isplayer( self ) || !istrue( self.has_gautys_gold ) || !gautys_gold_has_minor( self, 3 ) ) return;
    if ( !isdefined( params ) || !isdefined( params.amount ) || params.amount <= 0 || !isdefined( params.currencytype ) ) return;
    self.gg_bargain = int( params.amount * 0.05 );
    if ( self.gg_bargain < 1 ) return;
    self currency::add_currency_amount( params.currencytype, self.gg_bargain, #"gautys_gold_bargain", params.info );
    {}
}
function gautys_gold_payday()
{
    self endon( #"death_or_disconnect" );
    self endon( "take_gautys_gold" );
    level endon( #"game_ended" );
    while ( true )
    {
        level utility::waittill_any( "between_round_over", "round_end_finished", "on_round_end" );
        if ( gettime() < ( self.gg_payday_next ?? 0 ) || !gautys_gold_has_minor( self, 4 ) ) continue;
        self.gg_payday_next = gettime() + 10000;
        self.gg_payday = int( self currency::get_currency_amount( #"essence" ) * 0.05 );
        if ( self.gg_payday < 1 ) continue;
        self currency::add_currency_amount( #"essence", self.gg_payday, #"gautys_gold_payday" );
        {}
    }
}
function give_gautys_gold_perk()
{
    self quiet_perk_gautys_gold_client_dvar( @"bo7_cp_client_owned_gautys_gold", "1" );
    self.has_gautys_gold = 1;
    self.gautys_gold_major_augment = -1;
    self.gautys_gold_last_report = undefined;
    self.gautys_gold_melee_augment = 0;
    self points::set_point_scalar( 1.25, "gautys_gold" );
    self thread gautys_gold_apply_augments();
    self thread gautys_gold_payday();
}
function take_gautys_gold_perk( b_pause, str_perk, str_result, n_slot )
{
    self quiet_perk_gautys_gold_client_dvar( @"bo7_cp_client_owned_gautys_gold", "0" );
    self.has_gautys_gold = 0;
    self.gautys_gold_major_augment = 0;
    self.gautys_gold_melee_augment = 0;
    self notify( "take_gautys_gold" );
    self points::set_point_scalar( 1, "gautys_gold" );
}
function gautys_gold_apply_augments()
{
    self endon( #"death_or_disconnect" );
    self endon( "take_gautys_gold" );
    while ( self.has_gautys_gold == 1 )
    {
        n_pick = 0;
        n_major_augment = 0;
        n_minor_augment = 0;
        n_bonus_augment = 0;
        str_pick_source = "unsynced";
        if ( isdefined( self.cp_gold_major ) )
        {
            n_pick = self.cp_picks["gautys_gold"];
            n_major_augment = self.cp_gold_major;
            n_minor_augment = self.cp_gold_minor;
            n_bonus_augment = self.cp_gold_bonus;
            str_pick_source = "player_sync";
        }
        if ( n_major_augment != self.gautys_gold_major_augment )
        {
            n_point_multiplier = n_major_augment == 1 ? 1.35 : 1.25;
            self points::set_point_scalar( n_point_multiplier, "gautys_gold" );
            self.gautys_gold_major_augment = n_major_augment;
        }
        if ( n_minor_augment == 1 || n_bonus_augment == 1 )
        {
            self.gautys_gold_melee_augment = 1;
        }
        else
        {
            self.gautys_gold_melee_augment = 0;
        }
        report = "source=" + str_pick_source + " pick=" + n_pick + " major=" + n_major_augment + " minor=" + n_minor_augment + " bonus=" + n_bonus_augment + " scalar=" + n_point_multiplier;
        if ( !isdefined( self.gautys_gold_last_report ) || self.gautys_gold_last_report != report )
        {
            self.gautys_gold_last_report = report;
            {}
        }
        wait 0.25;
    }
}
function gautys_gold_refund_purchase(params)
{
    if (!isplayer(self) || !istrue(self.has_gautys_gold) || (self.cp_gold_major ?? 0) != 2) return;
    if (!isdefined(params) || !isdefined(params.amount) || params.amount <= 0 || !isdefined(params.currencytype)) return;
    if (isdefined(level.cp_disabled_native) && isdefined(params.info))
    {
        foreach (ref, disabled in level.cp_disabled_native)
        {
            if (params.info == ref || params.info == getxhash(ref)) return;
        }
    }
    if (randomint(100) >= 10) return;
    self currency::add_currency_amount(params.currencytype, params.amount, #"gautys_gold_refund", params.info);
    {}
}
function gautys_gold_salvage_bonus(params)
{
    if (!isplayer(self) || !istrue(self.has_gautys_gold) || (self.cp_gold_major ?? 0) != 3) return;
    if (!isdefined(params) || !isdefined(params.amount) || params.amount <= 0 || !isdefined(params.currencytype)) return;
    if (params.currencytype != #"salvage" || (isdefined(params.reason) && params.reason == #"gautys_gold_salvage")) return;
    self.gg_salvage_extra = (self.gg_salvage_extra ?? 0) + params.amount * 0.25;
    if (self.gg_salvage_extra < 1) return;
    self.gg_salvage_pay = int(self.gg_salvage_extra);
    self.gg_salvage_extra = self.gg_salvage_extra - self.gg_salvage_pay;
    self currency::add_currency_amount(#"salvage", self.gg_salvage_pay, #"gautys_gold_salvage");
    {}
}
function quiet_perk_gautys_gold_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
