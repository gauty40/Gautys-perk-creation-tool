// @augment major High Roller | Every Pack-a-Punch chance is 50% higher.
// @augment major Lucky Streak | Getting a Pack-a-Punched box weapon makes your next box spin free.
// @augment major Fire Sale Finder | Each box spin has a 3% chance to drop a Fire Sale.
// @augment major Rarity Bump | Box weapons come out one rarity higher.
// @augment minor Bargain Bin | Box spins cost 10% less.
// @augment minor Second Look | A spin that misses Pack-a-Punch gets a 25% chance to roll again.
// @augment minor Spin Streak | Each spin that misses Pack-a-Punch adds 2% to the next one (resets on a hit).
// @augment minor Salvage Spin | Every box spin also gives 25 salvage.
#using scripts\common\callbacks;
#using scripts\common\powerups;
#using scripts\common\utility;
#using scripts\mp\arsenal;
#using scripts\mp\common\perks\zombie\zombie_perks;
#using scripts\mp\currency;
#using scripts\mp\loot\common_item_weapon;
#using scripts\mp\pack_a_punch;
#namespace perk_pack_a_box;
autoexec pack_a_box_init()
{
    level thread pack_a_box_register_perk();
}
function pack_a_box_register_perk()
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
    def["id"] = "pack_a_box";
    def["creator"] = "Gauty";
    def["code"] = 91;
    def["name"] = "Pack-A-Box";
    def["description"] = "Mystery Box weapons can come out Pack-a-Punched: 50% PaP 1, 10% PaP 2, 1% PaP 3, 0.5% PaP 4.";
    def["icon_material"] = "ui_icon_perks_pack_a_box";
    def["price"] = 3000;
    def["drink_from"] = "specialty_juggernog";
    def["on_give"] = &give_pack_a_box_perk;
    def["on_take"] = &take_pack_a_box_perk;
    if ( !level [[ level.cp_register ]]( def ) )
    {
        {}
        return;
    }
    level [[ level.cp_register_native ]]( "pack_a_box", level.cp_defs["pack_a_box"] );
    level callback::add( "magicbox_purchase", &pack_a_box_on_box_weapon );
    {}
}
function give_pack_a_box_perk()
{
    self quiet_perk_pack_a_box_client_dvar( @"bo7_cp_client_owned_pack_a_box", "1" );
}
function take_pack_a_box_perk( b_pause, str_perk, str_result, n_slot )
{
    self quiet_perk_pack_a_box_client_dvar( @"bo7_cp_client_owned_pack_a_box", "0" );
}
function pack_a_box_has_minor( n )
{
    return ( self.cp_pack_a_box_minor ?? 0 ) == n || ( self.cp_pack_a_box_bonus ?? 0 ) == n;
}
function pack_a_box_roll()
{
    self.pab_mult = 1;
    if ( ( self.cp_pack_a_box_major ?? 0 ) == 1 ) self.pab_mult = 1.5;
    self.pab_bonus = 0;
    if ( self pack_a_box_has_minor( 3 ) ) self.pab_bonus = 20 * ( self.pab_streak ?? 0 );
    self.pab_roll = randomfloat( 1000 );
    self.pab_level = 0;
    if ( self.pab_roll < 5 * self.pab_mult ) self.pab_level = 4;
    else if ( self.pab_roll < 15 * self.pab_mult ) self.pab_level = 3;
    else if ( self.pab_roll < 115 * self.pab_mult ) self.pab_level = 2;
    else if ( self.pab_roll < 615 * self.pab_mult + self.pab_bonus ) self.pab_level = 1;
}
function pack_a_box_on_box_weapon( params )
{
    self endon( #"disconnect" );
    if ( !isplayer( self ) || !self zombie_perks::has_perk( "specialty_pack_a_box" ) )
    {
        return;
    }
    self.pab_cost = params.cost ?? 950;
    self.pab_currency = params.currency ?? #"essence";
    if ( istrue( self.pab_free_spin ) )
    {
        self.pab_free_spin = false;
        self currency::add_currency_amount( self.pab_currency, self.pab_cost, #"pack_a_box_lucky_streak" );
        {}
    }
    else if ( self pack_a_box_has_minor( 1 ) )
    {
        self currency::add_currency_amount( self.pab_currency, int( self.pab_cost * 0.1 ), #"pack_a_box_bargain" );
    }
    if ( self pack_a_box_has_minor( 4 ) )
    {
        self currency::add_currency_amount( #"salvage", 25, #"pack_a_box_salvage" );
    }
    if ( ( self.cp_pack_a_box_major ?? 0 ) == 3 && randomint( 100 ) < 3 )
    {
        level thread powerups::powerup_drop( "fire_sale", self.origin + anglestoforward( self.angles ) * 60 + ( 0, 0, 20 ) );
        {}
    }
    if ( !isdefined( params.objweapon ) || istrue( params.isscorestreak ) )
    {
        return;
    }
    self pack_a_box_roll();
    if ( self.pab_level == 0 && self pack_a_box_has_minor( 2 ) && randomint( 100 ) < 25 )
    {
        self pack_a_box_roll();
    }
    if ( self.pab_level == 0 ) self.pab_streak = ( self.pab_streak ?? 0 ) + 1;
    else self.pab_streak = 0;
    if ( self.pab_level == 0 && ( self.cp_pack_a_box_major ?? 0 ) != 4 )
    {
        return;
    }
    if ( isdefined( level.max_pack_a_punch_level ) && self.pab_level > level.max_pack_a_punch_level )
    {
        self.pab_level = level.max_pack_a_punch_level;
    }
    self.pab_weapon = params.objweapon;
    wait 0.5;
    if ( !isalive( self ) || !self hasweapon( self.pab_weapon ) )
    {
        {}
        return;
    }
    if ( ( self.cp_pack_a_box_major ?? 0 ) == 4 && self arsenal::can_increase_weapon_tier( self.pab_weapon ) )
    {
        self.pab_rarity = item_weapon::function_fb81bd2fe070faa6( self.pab_weapon );
        if ( isdefined( self.pab_rarity ) && self.pab_rarity < ( level.arsenal_max_weapon_rarity ?? 4 ) )
        {
            self arsenal::upgrade_rarity( self.pab_weapon, self.pab_rarity + 1 );
            {}
            waitframe();
            if ( !self hasweapon( self.pab_weapon ) ) self.pab_weapon = self getcurrentweapon();
        }
    }
    if ( self.pab_level == 0 )
    {
        return;
    }
    if ( !self pack_a_punch::can_pap( self.pab_weapon ) || self pack_a_punch::get_pap_level( self.pab_weapon ) > 0 )
    {
        {}
        return;
    }
    self pack_a_punch::pap_weapon( self.pab_weapon, self.pab_level - 1 );
    if ( ( self.cp_pack_a_box_major ?? 0 ) == 2 ) self.pab_free_spin = true;
    {}
}
function quiet_perk_pack_a_box_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
