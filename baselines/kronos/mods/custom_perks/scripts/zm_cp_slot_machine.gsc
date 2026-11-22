#using scripts\common\shared_func_utility;
#using scripts\common\utility;
#using scripts\common\values;
#using scripts\mp\common\killstreaks\killstreaks;
#using scripts\mp\currency;
#using scripts\mp\loot\common_item;
#using scripts\mp\mp_agent;
#using scripts\mp\common\perks\zombie\zombie_perks;
#namespace zm_cp_slot_machine;
// Slot machine you walk up to (Ashes only for now, at the spot Gauty's Gold's machine used).
// USE opens the slot interface (bo7_slot_machine_post.lua); USE again spins; walking away closes it.
// First spin each round is free, then 5000, 10000, 15000... resetting every round.
// HUD channel pages (sent by cp_hud_page_cycle in zm_cp_custom_perks.gsc):
//   page 21 = near + open * 2 + spinning * 4 + poor * 8 + no_target_cooling_down * 16 + spins_this_round * 32   (max 3231)
//   page 22 = spin_id * 512 + reel1 * 64 + reel2 * 8 + reel3, spin_id 1..7 (0 = never spun; max 4095)
// Symbols: 0 cherry, 1 bell, 2 bar, 3 seven, 4 skull, 5 clover, 6 mega (x2 gem), 7 nega (upside-down 7).
// Payouts are mirrored in the Lua payout table.
function slot_machine_spots()
{
    slot_machine_add( "zm_sat_firefly", ( 25013.5, -84.999, 422.078 ), 90 );
}
function slot_machine_weights()
{
    // Chance out of 1000 for each symbol on each reel: cherry, bell, bar, seven, skull, clover, mega, nega.
    // Three of a kind: jackpot (sevens) 80^3 = about 1 in 1950, mega 75^3 = about 1 in 2370 (slightly rarer),
    // nega 70^3 = about 1 in 2900.
    return [ 270, 210, 165, 80, 100, 30, 75, 70 ];
}
// DEBUG: opening the machine while crouched makes every spin of that session a nega jackpot. Set to 0 to turn off.
function slot_machine_debug_crouch_jackpots()
{
    return 1;
}
// Elite types the nega jackpot can spawn; the ones not loaded on the current map are skipped.
function slot_machine_elite_subclasses()
{
    // Callisto is the elite Ashes' own elite rounds use (zmroundspawning zm_sat_firefly).
    return [ "zombie_callisto", "zombie_amalgam", "zombie_abom", "zombie_mangler" ];
}
// Seconds the reels spin in the interface; the payout lands when the last reel stops.
function slot_machine_spin_seconds()
{
    return 2.6;
}
// Seconds after closing the interface before opening it gives no-target again (the machine itself has no cooldown).
function slot_machine_cooldown_seconds()
{
    return 30;
}
function slot_machine_use_radius()
{
    return 90;
}
function slot_machine_spin_price( n_spins )
{
    return n_spins * 5000;
}
autoexec slot_machine_init()
{
    level thread slot_machine_start();
    level thread slot_machine_round_reset();
    level thread slot_machine_load_fx();
}
function slot_machine_add( str_map, v_origin, n_yaw )
{
    if ( "" + level.mapname != str_map )
    {
        return;
    }
    level.slot_origin = v_origin;
    level.slot_angles = ( 0, n_yaw, 0 );
}
function slot_machine_start()
{
    level endon( #"game_ended" );
    level utility::flag_wait( "StartGameTypeCallbackFinished" );
    slot_machine_spots();
    if ( !isdefined( level.slot_origin ) )
    {
        slot_machine_status( "no slot machine on " + level.mapname );
        return;
    }
    // Same timing as the custom perk machines: map scriptables are ready well after the first spawn.
    while ( level.players.size == 0 )
    {
        wait 1;
    }
    wait 16;
    // The armory (arsenal) is a script_model with an xmodel, not a standalone scriptable (arsenal.gsc
    // init_arsenal_machine), so copy the model off one of the map's own armories; only map-loaded models render.
    level.slot_model = undefined;
    if ( isarray( level.a_s_arsenal_locations ) )
    {
        foreach ( s_arsenal in level.a_s_arsenal_locations )
        {
            if ( isdefined( s_arsenal ) && isdefined( s_arsenal.mdl_arsenal ) && isdefined( s_arsenal.mdl_arsenal.model ) )
            {
                level.slot_model = s_arsenal.mdl_arsenal.model;
                break;
            }
        }
    }
    if ( !isdefined( level.slot_model ) ) level.slot_model = level.gamemodebundle.arsenalmodel ?? "t10_zm_weapon_machine_fxanim";
    level.slot_ent = spawn( "script_model", level.slot_origin );
    level.slot_ent.angles = level.slot_angles;
    slot_machine_status( "machine spawned: " + isdefined( level.slot_ent ) + ", model not set" );
    level thread slot_machine_use_loop();
    // Own thread so a bad model or missing part state can't stop the machine from working.
    level thread slot_machine_dress();
}
// Armory model with the same powered-on idle look enable_arsenal gives the real one.
function slot_machine_dress()
{
    level.slot_ent setmodel( level.slot_model );
    level.slot_ent disconnectpaths();
    slot_machine_status( "machine spawned: 1, model set" );
    if ( !level.slot_ent isscriptable() )
    {
        return;
    }
    level.slot_ent setscriptablepartstate( "anim", "power_on" );
    level.slot_ent setscriptablepartstate( "base", "arsenal_idle" );
}
function slot_machine_round_reset()
{
    level endon( #"game_ended" );
    while ( true )
    {
        level utility::waittill_any( "between_round_over", "round_end_finished", "on_round_end" );
        foreach ( player in level.players )
        {
            if ( isdefined( player ) ) player.slot_spins = 0;
        }
    }
}
function slot_machine_use_loop()
{
    level endon( #"game_ended" );
    while ( true )
    {
        wait 0.05;
        foreach ( player in level.players )
        {
            if ( !isdefined( player ) || isbot( player ) )
            {
                continue;
            }
            if ( !istrue( player.slot_listening ) )
            {
                player.slot_listening = true;
                player thread slot_machine_listen();
            }
            player.slot_near = isalive( player ) && !istrue( player.inlaststand ) && distance( player.origin, level.slot_origin ) <= slot_machine_use_radius();
            // Walking away or crouching closes the interface (Esc closes it through slot_machine_listen).
            // Crouch only counts when it starts while open, so opening it already crouched (jackpot debug) doesn't shut it.
            player.slot_crouch_now = player getstance() == "crouch";
            if ( !player.slot_near || ( player.slot_crouch_now && !istrue( player.slot_crouch_was ) ) )
            {
                player.slot_open = false;
            }
            player.slot_use_was = istrue( player.slot_use_held );
            player.slot_use_held = player usebuttonpressed();
            player.slot_cooling = gettime() < ( player.slot_cool_until ?? 0 );
            if ( player.slot_near && player.slot_use_held && !player.slot_use_was )
            {
                if ( !istrue( player.slot_open ) )
                {
                    player.slot_open = true;
                    player.slot_poor = false;
                    player.slot_debug_jackpots = slot_machine_debug_crouch_jackpots() && player.slot_crouch_now;
                }
                else if ( !istrue( player.slot_busy ) )
                {
                    player slot_machine_try_spin();
                }
            }
            // Zombies ignore the player while the interface is open, unless no-target is on cooldown.
            // Closing the interface after a no-target session starts the 30 s cooldown, so it can't be a safe spot.
            if ( istrue( player.slot_open ) && !istrue( player.slot_was_open ) && !player.slot_cooling )
            {
                player val::set( "slot_machine", "ignoreme", 1 );
                player.slot_ignored = true;
            }
            else if ( !istrue( player.slot_open ) && istrue( player.slot_ignored ) )
            {
                player val::reset( "slot_machine", "ignoreme" );
                player.slot_ignored = false;
                player.slot_cool_until = gettime() + int( slot_machine_cooldown_seconds() * 1000 );
                player.slot_cooling = true;
            }
            player.slot_was_open = istrue( player.slot_open );
            player.slot_crouch_was = player.slot_crouch_now;
            player.slot_ui = ( istrue( player.slot_near ) ? 1 : 0 ) + ( istrue( player.slot_open ) ? 2 : 0 ) + ( istrue( player.slot_busy ) ? 4 : 0 ) + ( istrue( player.slot_poor ) ? 8 : 0 ) + ( istrue( player.slot_cooling ) ? 16 : 0 ) + int( min( player.slot_spins ?? 0, 100 ) ) * 32;
        }
    }
}
// The Lua sends 23000 on the perk_choice_purchase channel when the pause menu (Esc) opens over the interface.
function slot_machine_listen()
{
    self endon( #"disconnect" );
    level endon( #"game_ended" );
    while ( true )
    {
        self waittill( #"luinotifyserver", channel, value );
        if ( !isdefined( channel ) || ( channel != "perk_choice_purchase" && channel != "custom_perk_choice_purchase" ) )
        {
            continue;
        }
        if ( value === 23000 || value === "23000" )
        {
            self.slot_open = false;
        }
    }
}
function slot_machine_try_spin()
{
    self.slot_price = slot_machine_spin_price( self.slot_spins ?? 0 );
    if ( self.slot_price > 0 && !self currency::attempt_purchase( currency::get_perk_machine_currency( "specialty_juggernog" ), self.slot_price, 1 ) )
    {
        self.slot_poor = true;
        return;
    }
    self.slot_poor = false;
    self.slot_spins = ( self.slot_spins ?? 0 ) + 1;
    self thread slot_machine_spin();
}
function slot_machine_roll()
{
    level.slot_weights = slot_machine_weights();
    level.slot_roll = randomint( 1000 );
    level.slot_sym = 0;
    while ( level.slot_sym < level.slot_weights.size - 1 && level.slot_roll >= level.slot_weights[ level.slot_sym ] )
    {
        level.slot_roll = level.slot_roll - level.slot_weights[ level.slot_sym ];
        level.slot_sym = level.slot_sym + 1;
    }
    return level.slot_sym;
}
function slot_machine_spin()
{
    self endon( #"disconnect" );
    self.slot_busy = true;
    self.slot_r1 = slot_machine_roll();
    self.slot_r2 = slot_machine_roll();
    self.slot_r3 = slot_machine_roll();
    if ( randomint( 100 ) < slot_machine_debug_skull_chance() )
    {
        self.slot_r1 = 4;
        self.slot_r2 = 4;
        self.slot_r3 = 4;
    }
    // Jackpot debug (opened crouched): every spin is a nega jackpot.
    if ( istrue( self.slot_debug_jackpots ) )
    {
        self.slot_r1 = 7;
        self.slot_r2 = 7;
        self.slot_r3 = 7;
    }
    self.slot_spin_id = ( self.slot_spin_id ?? 0 ) % 7 + 1;
    self.slot_hud = self.slot_spin_id * 512 + self.slot_r1 * 64 + self.slot_r2 * 8 + self.slot_r3;
    wait slot_machine_spin_seconds();
    self.slot_busy = false;
    self slot_machine_pay();
}
// Fireworks at the machine's base on a win; a jackpot gets a longer show with bursts overhead.
// Fireworks wait with the rewards: the biggest win since the last payout sets the length (bursts are 0.6 s apart).
function slot_machine_owe_fireworks( n_bursts )
{
    self.slot_owed_fireworks = int( max( self.slot_owed_fireworks ?? 0, n_bursts ) );
}
function slot_machine_fireworks( n_bursts )
{
    level endon( #"game_ended" );
    for ( i = 0; i < n_bursts; i++ )
    {
        if ( isdefined( level._effect[ "slot_fireworks_ground" ] ) ) playfx( level._effect[ "slot_fireworks_ground" ], level.slot_origin );
        if ( n_bursts > 4 && isdefined( level._effect[ "slot_fireworks_burst" ] ) ) playfx( level._effect[ "slot_fireworks_burst" ], level.slot_origin + ( randomintrange( -60, 60 ), randomintrange( -60, 60 ), 160 + randomint( 80 ) ) );
        playsoundatpos( level.slot_origin, #"prj_ammomod_fireworks_impact" );
        wait 0.6;
    }
}
function slot_machine_load_fx()
{
    level._effect[ "slot_fireworks_ground" ] = loadfxasset( "vfx_sat_zm_weapons_fireworks_ground" );
    level._effect[ "slot_fireworks_burst" ] = loadfxasset( "vfx_sat_zm_weapons_fireworks_burst_ch_yellow" );
}
// Payouts (keep in sync with PAYOUTS / resultText in bo7_slot_machine_post.lua). Minimum win 5000, jackpot 77777.
// Clovers pay on top of the normal result: one clover = a mystery perk can, two = three cans, three = nine cans.
function slot_machine_pay()
{
    self.slot_clovers = ( self.slot_r1 == 5 ? 1 : 0 ) + ( self.slot_r2 == 5 ? 1 : 0 ) + ( self.slot_r3 == 5 ? 1 : 0 );
    if ( self.slot_clovers == 3 )
    {
        self slot_machine_owe_fireworks( 12 );
        self.slot_owed_cans = ( self.slot_owed_cans ?? 0 ) + 9;
        self thread slot_machine_deliver();
        return;
    }
    if ( self.slot_clovers > 0 )
    {
        self slot_machine_owe_fireworks( 4 );
        self.slot_owed_cans = ( self.slot_owed_cans ?? 0 ) + ( self.slot_clovers == 2 ? 3 : 1 );
        self thread slot_machine_deliver();
    }
    if ( self.slot_r1 == self.slot_r2 && self.slot_r2 == self.slot_r3 )
    {
        if ( self.slot_r1 == 3 )
        {
            self slot_machine_owe_fireworks( 12 );
            self slot_machine_essence( 77777 );
            return;
        }
        // Mega jackpot: pays your current essence again (doubling it), counted the moment the reels stop.
        if ( self.slot_r1 == 6 )
        {
            self slot_machine_owe_fireworks( 12 );
            self.slot_mega = int( self currency::get_currency_amount( #"essence" ) ?? 0 );
            slot_machine_status( "mega jackpot: doubling " + self.slot_mega );
            if ( self.slot_mega > 0 ) self slot_machine_essence( self.slot_mega );
            else self thread slot_machine_deliver();
            return;
        }
        // Nega jackpot: the interface shuts and four elites spawn around the player.
        if ( self.slot_r1 == 7 )
        {
            self.slot_open = false;
            self thread slot_machine_nega();
            return;
        }
        // Every triple except skulls is a win.
        if ( self.slot_r1 != 4 ) self slot_machine_owe_fireworks( 4 );
        if ( self.slot_r1 == 2 )
        {
            self slot_machine_essence( 20000 );
            self slot_machine_killstreak();
            return;
        }
        if ( self.slot_r1 == 1 )
        {
            self slot_machine_essence( 15000 );
            self slot_machine_max_ammo();
            return;
        }
        if ( self.slot_r1 == 0 )
        {
            self slot_machine_essence( 40000 );
            return;
        }
        self slot_machine_down();
        return;
    }
    // Any two matching symbols other than skulls or clovers (a clover pair pays perk cans above).
    if ( slot_machine_is_pair( self.slot_r1, self.slot_r2 ) || slot_machine_is_pair( self.slot_r2, self.slot_r3 ) || slot_machine_is_pair( self.slot_r1, self.slot_r3 ) )
    {
        self slot_machine_owe_fireworks( 4 );
        self slot_machine_essence( 10000 );
        return;
    }
    if ( self.slot_r1 == 0 || self.slot_r2 == 0 || self.slot_r3 == 0 )
    {
        self slot_machine_owe_fireworks( 4 );
        self slot_machine_essence( 5000 );
        return;
    }
    if ( self.slot_clovers == 0 ) slot_machine_status( "no win" );
}
// Pairs of skulls, clovers or negas don't pay 10,000 (a mega pair does).
function slot_machine_is_pair( a, b )
{
    return a == b && a != 4 && a != 5 && a != 7;
}
// Nega jackpot: four elites spawn on the navmesh in a ring about 220 units around the player, one every 0.4 s,
// a second after the interface closes. Types come from slot_machine_elite_subclasses (only ones loaded on this map).
// Everything lives in self.slot_nega_* fields, not locals or a foreach variable: some script locals read back
// undefined in this build. Spawning uses mp_agent::spawnnewagentaitype (what Blood Wolf Bite's wolves use, known to
// work) and falls back to the shared spawn function. The zombie team comes from level.zombie_team, else from a live
// zombie. Each step reports into the bo7_cp_slot_machine_runtime dvar (type it in the console after a nega jackpot).
function slot_machine_nega()
{
    self endon( #"disconnect" );
    level endon( #"game_ended" );
    wait 1;
    self.slot_nega_subs = slot_machine_elite_subclasses();
    self.slot_nega_types = [];
    self.slot_nega_names = "";
    self.slot_nega_i = 0;
    while ( self.slot_nega_i < self.slot_nega_subs.size )
    {
        self.slot_nega_type = getaitypefromsubclass( self.slot_nega_subs[ self.slot_nega_i ] );
        if ( isdefined( self.slot_nega_type ) )
        {
            self.slot_nega_types[ self.slot_nega_types.size ] = self.slot_nega_type;
            self.slot_nega_names = self.slot_nega_names + self.slot_nega_subs[ self.slot_nega_i ] + " ";
        }
        self.slot_nega_i = self.slot_nega_i + 1;
    }
    // No elite loaded on this map: heavy armoured zombies instead, so the nega jackpot always does something.
    if ( self.slot_nega_types.size == 0 )
    {
        self.slot_nega_type = getaitypefromsubclass( "zombie_base_armored_heavy" );
        if ( isdefined( self.slot_nega_type ) )
        {
            self.slot_nega_types[ 0 ] = self.slot_nega_type;
            self.slot_nega_names = "zombie_base_armored_heavy (fallback) ";
        }
    }
    if ( self.slot_nega_types.size == 0 )
    {
        slot_machine_status( "nega: no elite type loaded on " + level.mapname + " (tried " + self.slot_nega_subs.size + " + fallback)" );
        return;
    }
    self.slot_nega_team = level.zombie_team;
    if ( !isdefined( self.slot_nega_team ) )
    {
        foreach ( ai in getaiarray() )
        {
            if ( isdefined( ai ) && isalive( ai ) && !( ai.team === self.team ) ) self.slot_nega_team = ai.team;
        }
    }
    if ( !isdefined( self.slot_nega_team ) ) self.slot_nega_team = "team_two_hundred";
    self.slot_nega_spawned = 0;
    self.slot_nega_n = 0;
    while ( self.slot_nega_n < 4 && isalive( self ) )
    {
        self.slot_nega_yaw = self.slot_nega_n * 90 + randomint( 40 );
        self.slot_nega_pos = getclosestpointonnavmesh( self.origin + anglestoforward( ( 0, self.slot_nega_yaw, 0 ) ) * 220 );
        if ( !isdefined( self.slot_nega_pos ) ) self.slot_nega_pos = getclosestpointonnavmesh( self.origin );
        if ( !isdefined( self.slot_nega_pos ) ) self.slot_nega_pos = self.origin;
        self.slot_nega_type = self.slot_nega_types[ randomint( self.slot_nega_types.size ) ];
        self.slot_nega_ai = mp_agent::spawnnewagentaitype( self.slot_nega_type, self.slot_nega_pos, ( 0, self.slot_nega_yaw + 180, 0 ), self.slot_nega_team );
        if ( !isdefined( self.slot_nega_ai ) )
        {
            self.slot_nega_ai = shared_func_utility::spawnnewaitype_sharedfunc( self.slot_nega_type, self.slot_nega_pos, ( 0, self.slot_nega_yaw + 180, 0 ), self.slot_nega_team );
        }
        if ( isdefined( self.slot_nega_ai ) ) self.slot_nega_spawned = self.slot_nega_spawned + 1;
        self.slot_nega_n = self.slot_nega_n + 1;
        wait 0.4;
    }
    playsoundatpos( self.origin, #"prj_ammomod_fireworks_impact" );
    slot_machine_status( "nega: " + self.slot_nega_spawned + "/4 spawned, team " + self.slot_nega_team + ", types: " + self.slot_nega_names );
}
// Three skulls: lethal damage, so the game puts the player into last stand like any other down.
// The damage filter (damage.gsc filterdamage) drops damage with no attacker unless it is MOD_FALLING,
// so try falling damage, then self-inflicted, then the nearest zombie, until the player is down.
function slot_machine_down()
{
    self endon( #"disconnect" );
    self.slot_open = false;
    self.slot_down_try = 0;
    while ( self.slot_down_try < 3 && isalive( self ) && !istrue( self.inlaststand ) )
    {
        self.slot_down_try = self.slot_down_try + 1;
        if ( self.slot_down_try == 1 )
        {
            self dodamage( self.health + 100000, self.origin, undefined, undefined, "MOD_FALLING" );
        }
        else if ( self.slot_down_try == 2 )
        {
            self dodamage( self.health + 100000, self.origin, self, self, "MOD_UNKNOWN" );
        }
        else
        {
            self.slot_down_by = undefined;
            foreach ( ai in getaiarray() )
            {
                if ( isdefined( ai ) && isalive( ai ) && !( ai.team === self.team ) && ( !isdefined( self.slot_down_by ) || distancesquared( ai.origin, self.origin ) < distancesquared( self.slot_down_by.origin, self.origin ) ) )
                {
                    self.slot_down_by = ai;
                }
            }
            if ( isdefined( self.slot_down_by ) ) self dodamage( self.health + 100000, self.origin, self.slot_down_by, self.slot_down_by, "MOD_UNKNOWN" );
        }
        waitframe();
        waitframe();
    }
    slot_machine_status( "three skulls: down attempt " + self.slot_down_try + ", in last stand " + istrue( self.inlaststand ) + ", alive " + isalive( self ) );
}
// DEBUG: percent chance a spin is forced to three skulls. Set to 0 for normal odds.
function slot_machine_debug_skull_chance()
{
    return 0;
}
// Rewards are held until the player closes the interface, then paid out 1 second later (slot_machine_deliver).
function slot_machine_essence( amount )
{
    self.slot_owed_essence = ( self.slot_owed_essence ?? 0 ) + amount;
    self thread slot_machine_deliver();
}
function slot_machine_max_ammo()
{
    self.slot_owed_ammo = 1;
    self thread slot_machine_deliver();
}
function slot_machine_killstreak()
{
    self.slot_owed_streaks = ( self.slot_owed_streaks ?? 0 ) + 1;
    self thread slot_machine_deliver();
}
function slot_machine_deliver()
{
    self notify( #"slot_machine_deliver" );
    self endon( #"slot_machine_deliver" );
    self endon( #"disconnect" );
    level endon( #"game_ended" );
    while ( istrue( self.slot_open ) || istrue( self.slot_busy ) )
    {
        wait 0.1;
    }
    wait 1;
    if ( ( self.slot_owed_ammo ?? 0 ) > 0 )
    {
        self.slot_owed_ammo = 0;
        foreach ( w_weapon in self getweaponslistprimaries() )
        {
            self givemaxammo( w_weapon );
        }
    }
    while ( ( self.slot_owed_streaks ?? 0 ) > 0 )
    {
        self.slot_owed_streaks = self.slot_owed_streaks - 1;
        self slot_machine_give_killstreak();
    }
    // Fireworks go off just before anything flies out of the machine, and keep going while it lands.
    if ( ( self.slot_owed_fireworks ?? 0 ) > 0 )
    {
        level thread slot_machine_fireworks( self.slot_owed_fireworks );
        self.slot_owed_fireworks = 0;
        wait 0.3;
    }
    if ( ( self.slot_owed_cans ?? 0 ) > 0 )
    {
        self.slot_paying_cans = self.slot_owed_cans;
        self.slot_owed_cans = 0;
        level thread slot_machine_spit_perk_cans( self.slot_paying_cans, self );
    }
    if ( ( self.slot_owed_essence ?? 0 ) > 0 )
    {
        self.slot_paying = self.slot_owed_essence;
        self.slot_owed_essence = 0;
        self slot_machine_pay_essence( self.slot_paying );
    }
}
// Mystery perk cans fly out of the machine the same way the vials do. The item is the stock random-perk can
// (itemspawnentry:zm_sat_item_perk_random, the "mystery" can the Easter eggs reward); picking it up gives a random perk.
// It's looked up by name at payout time, not written into the script as an asset reference (suspected of hanging
// the map load), and if this map has no such item the winner gets a random perk directly instead.
function slot_machine_spit_perk_cans( n_cans, e_winner )
{
    level endon( #"game_ended" );
    s = spawnstruct();
    s.from = level.slot_origin + ( 0, 0, 60 );
    s.opts = common_item::function_f5dfaa3bbdf99a33( level.slot_origin + anglestoforward( level.slot_angles ) * 70, s.from );
    s.opts.var_9161cf0784b6951d = 0;
    s.opts.var_2321e933cbdf46d8 = 10;
    s.opts.var_34444f0dda11f0d5 = 10;
    s.opts.optionaloverridegroundfloat = 2;
    s.opts.gravityarcstartorigin = s.from;
    s.opts.totalspawnquantity = n_cans;
    s.opts.timedcleanupdisabled = 1;
    s.spawned = 0;
    s.left = n_cans;
    // Plain while loop: a for loop counting on a struct field (s.i++) is the prime suspect for a map-load hang.
    while ( s.left > 0 )
    {
        s.left = s.left - 1;
        s.item = common_item::function_57b88e025e5fb03e( "itemspawnentry:zm_sat_item_perk_random", 1, s.opts );
        if ( isdefined( s.item ) )
        {
            s.spawned = s.spawned + 1;
        }
        else if ( isdefined( e_winner ) && isalive( e_winner ) )
        {
            e_winner zombie_perks::give_random_new_perk();
        }
        wait 0.15;
    }
    slot_machine_status( "mystery perks: " + s.spawned + " of " + n_cans + " spawned as cans, the rest given directly" );
}
// Same award as Killstreak Kool-Aid; a full killstreak slot gets 5000 essence instead.
function slot_machine_give_killstreak()
{
    if ( isdefined( self.streakdata ) && isdefined( self.streakdata.streaks ) && isdefined( self.streakdata.streaks[ 1 ] ) && self.streakdata.streaks[ 1 ].available === 1 )
    {
        self slot_machine_pay_essence( 5000 );
        return;
    }
    if ( !isdefined( level.streakglobals ) || !isdefined( level.streakglobals.streakbundles ) )
    {
        self slot_machine_pay_essence( 5000 );
        return;
    }
    level.slot_streaks = getarraykeys( level.streakglobals.streakbundles );
    if ( level.slot_streaks.size == 0 )
    {
        self slot_machine_pay_essence( 5000 );
        return;
    }
    self killstreaks::awardkillstreak( level.slot_streaks[ randomint( level.slot_streaks.size ) ], "other", undefined, undefined, undefined, 1 );
    slot_machine_status( "gave a killstreak" );
}
// Essence winnings fly out of the machine as vials, the way the Scarab piano Easter egg spits out its essence.
// A vial always pays its own item's fixed value when picked up (the plain large vial 600, the _2300 one 2300),
// whatever count it's spawned with, times double points. So a payout is split into vial types that add up to it
// exactly, biggest first: 10000 = 5 x 2000, 77777 = 38 x 2000 + 1000 + 500 + 200 + 77 paid directly (no vial is
// worth less than 100). All of these vials are in the Zombies item list, so they exist on every map.
function slot_machine_vial_types()
{
    return [
        [ 2000, %"itemspawnentry:zm_t10_item_essence_large_2000" ],
        [ 1000, %"itemspawnentry:zm_t10_item_essence_large_1000" ],
        [ 500, %"itemspawnentry:zm_t10_item_essence_small_500" ],
        [ 200, %"itemspawnentry:zm_t10_item_essence_small_200" ],
        [ 100, %"itemspawnentry:zm_t10_item_essence_small" ]
    ];
}
// Most vials one payout throws out (60 x 2000 = 120,000).
function slot_machine_max_vials()
{
    return 60;
}
function slot_machine_pay_essence( amount )
{
    level thread slot_machine_spit_vials( amount, self );
}
function slot_machine_spit_vials( amount, e_winner )
{
    level endon( #"game_ended" );
    // A struct per payout so two players being paid at once don't share counters.
    s = spawnstruct();
    s.left = amount;
    s.count = 0;
    s.types = slot_machine_vial_types();
    s.t = 0;
    s.from = level.slot_origin + ( 0, 0, 60 );
    s.opts = common_item::function_f5dfaa3bbdf99a33( level.slot_origin + anglestoforward( level.slot_angles ) * 70, s.from );
    s.opts.var_9161cf0784b6951d = 0;
    s.opts.var_2321e933cbdf46d8 = 10;
    s.opts.var_34444f0dda11f0d5 = 10;
    s.opts.optionaloverridegroundfloat = 2;
    s.opts.gravityarcstartorigin = s.from;
    s.opts.totalspawnquantity = int( amount / 2000 ) + 4;
    // Plain while loop on struct fields (a for loop with s.i++ was suspected of hanging a map load).
    // At most slot_machine_max_vials() vials; anything past that (a big mega jackpot) is paid directly below.
    while ( s.t < s.types.size && s.count < slot_machine_max_vials() )
    {
        if ( s.left < s.types[ s.t ][ 0 ] )
        {
            s.t = s.t + 1;
            continue;
        }
        common_item::function_61c2c0251e742ffd( s.types[ s.t ][ 1 ], s.types[ s.t ][ 0 ], s.opts );
        s.left = s.left - s.types[ s.t ][ 0 ];
        s.count = s.count + 1;
        wait 0.08;
    }
    // Under 100 left (no vial that small), or over the vial cap: the rest goes straight to the winner.
    if ( s.left > 0 && isdefined( e_winner ) )
    {
        e_winner currency::add_currency_amount( #"essence", s.left );
    }
    slot_machine_status( "spat out " + s.count + " vials for " + amount + " essence (" + s.left + " paid directly)" );
}
function slot_machine_status( message )
{
    setdvar( @"bo7_cp_slot_machine_runtime", message );
}
