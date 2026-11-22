#using scripts\mp\perk_machines;
#using script_aa3bac81ad4fc8e;
#using scripts\common\callbacks;
#using scripts\common\utility;
#using scripts\common\values;
#using scripts\mp\armor;
#using scripts\mp\common\perks\zombie\zombie_perks;
#using scripts\mp\common\utility\lui_game_event_aggregator;
#using scripts\mp\currency;
#using scripts\mp\interaction;
#using scripts\mp\purchasemenu;
#namespace zm_cp_custom_perks;
autoexec cp_custom_perks_init()
{
    cp_restore_saved_settings();
    setdvar( @"bo7_cp_debug_state", "manager_autoexec" );
    {}
    setdvar( @"bo7_cp_perk_manifest_ready", "0" );
    setdvar( @"bo7_cp_registered_perks", "v1:" );
    {}
    setdvar( @"bo7_cp_hud_slot_0", "" );
    setdvar( @"bo7_cp_hud_slot_1", "" );
    setdvar( @"bo7_cp_hud_slot_2", "" );
    setdvar( @"bo7_cp_hud_slot_3", "" );
    level.cp_defs = [];
    level.cp_code_to_id = [];
    level.cp_custom_refs = [];
    level.cp_registered_perks = [];
    level.cp_register = &cp_register;
    level.cp_register_native = &cp_register_native;
    level.cp_damage_mods = [];
    level.cp_register_damage_mod = &cp_register_damage_mod;
    level.cp_preview_health_damage = &cp_preview_health_damage;
    level.cp_get_pick = &cp_get_pick;
    level.cp_has = &cp_has;
    level.cp_give = &cp_give;
    level.cp_take = &cp_take;
    lui_game_event_aggregator::registeronluieventcallback( &on_wunderfizz_purchase );
    level callback::add( #"player_spawned", &cp_gold_on_spawn );
    {}
    {}
    level callback::add( #"player_spawned", &cp_sync_manifest_on_spawn );
    setdvar( @"bo7_cp_machine_runtime", "loaded, waiting for a player to spawn" );
    level callback::add( #"player_spawned", &cp_machine_on_spawn );
    level thread cp_native_toggle_init();
    level thread cp_wunderfizz_override();
    level thread cp_perk_limit_override();
    level thread cp_classic_init();
    level thread cp_perkaholic_init();
    level callback::add( "zm_perk_obtained", &cp_ep_on_perk_obtained );
    level thread cp_initialize();
    level thread cp_install_damage_hook();
    level thread cp_hud_snapshot_watch();
    level thread cp_hud_page_cycle();
}
function cp_register_damage_mod( fn, b_last, b_first )
{
    if ( istrue( b_first ) )
    {
        if ( !isdefined( level.cp_damage_mods_first ) ) level.cp_damage_mods_first = [];
        level.cp_damage_mods_first[ level.cp_damage_mods_first.size ] = fn;
        return;
    }
    if ( istrue( b_last ) )
    {
        if ( !isdefined( level.cp_damage_mods_last ) ) level.cp_damage_mods_last = [];
        level.cp_damage_mods_last[ level.cp_damage_mods_last.size ] = fn;
        return;
    }
    level.cp_damage_mods[ level.cp_damage_mods.size ] = fn;
}
function cp_install_damage_hook()
{
    level endon( #"game_ended" );
    level utility::flag_wait_all( "StartGameTypeCallbackFinished", "zombie_perks_init_complete" );
    n_tries = 0;
    while ( !utility::issharedfuncdefined( #"zombie", #"hash_555f057b4e2d44f8" ) && n_tries < 100 )
    {
        wait 0.1;
        n_tries++;
    }
    if ( isdefined( level.cp_damage_hook_installed ) )
    {
        return;
    }
    level.cp_damage_hook_installed = 1;
    level.cp_base_damage_mod = undefined;
    if ( utility::issharedfuncdefined( #"zombie", #"hash_555f057b4e2d44f8" ) )
    {
        level.cp_base_damage_mod = utility::getsharedfunc( #"zombie", #"hash_555f057b4e2d44f8" );
    }
    utility::registersharedfunc( #"zombie", #"hash_555f057b4e2d44f8", &cp_player_damage_mod );
    setdvar( @"bo7_cp_damage_hook", isdefined( level.cp_base_damage_mod ) ? "wrapped" : "installed (no base)" );
}
function cp_player_damage_mod( sparams )
{
    n_damage = sparams.idamage;
    if ( isplayer( self ) && isdefined( level.cp_damage_mods_first ) && isdefined( n_damage ) )
    {
        foreach ( fn in level.cp_damage_mods_first )
        {
            n_damage = self [[ fn ]]( sparams, n_damage );
        }
        if ( !isdefined( n_damage ) || n_damage <= 0 )
        {
            return 0;
        }
        sparams.idamage = n_damage;
    }
    if ( isdefined( level.cp_base_damage_mod ) )
    {
        n_damage = self [[ level.cp_base_damage_mod ]]( sparams );
    }
    if ( !isplayer( self ) || !isdefined( n_damage ) )
    {
        return n_damage;
    }
    foreach ( fn in level.cp_damage_mods )
    {
        n_damage = self [[ fn ]]( sparams, n_damage );
    }
    if ( isdefined( level.cp_damage_mods_last ) )
    {
        foreach ( fn in level.cp_damage_mods_last )
        {
            n_damage = self [[ fn ]]( sparams, n_damage );
        }
    }
    return n_damage;
}
function cp_preview_health_damage( sparams, n_damage )
{
    if ( ( self.armorhealth ?? 0 ) <= 0 )
    {
        return n_damage;
    }
    [ n_health_damage, n_light_armor_damage ] = armor::function_4875d04d69b22ae( sparams.eattacker, sparams.einflictor, self, n_damage, sparams.objweapon, sparams.smeansofdeath, sparams.shitloc, sparams.idflags, sparams.var_cdd29ad5d1362c2, sparams.unmodifieddamage, sparams.partname, 1 );
    return n_health_damage ?? n_damage;
}
function cp_initialize()
{
    level endon( #"game_ended" );
    {}
    level utility::flag_wait( "StartGameTypeCallbackFinished" );
    if ( !level.zombie_perks_in_use )
    {
        setdvar( @"bo7_cp_registered_perks", "v1:" );
        setdvar( @"bo7_cp_perk_manifest_ready", "1" );
        {}
        return;
    }
    level utility::flag_wait_all(
        "zombie_perks_init_complete",
        "perk_machines_ready"
    );
    {}
    callback::add( "zm_perk_obtained", &cp_update_overflow_perks );
    callback::add( "zm_perk_lost", &cp_update_overflow_perks );
    callback::callback( "custom_perks_register", {} );
    wait 0.1;
    foreach ( id, def in level.cp_defs )
    {
        cp_register_native( id, def );
    }
    manifest = "v1:";
    delimiter = "";
    foreach ( id, is_registered in level.cp_registered_perks )
    {
        if ( is_registered && isdefined( level.cp_defs[ id ] ) )
        {
            manifest = manifest + delimiter + id;
            delimiter = ",";
        }
    }
    level.cp_client_manifest = manifest;
    setdvar( @"bo7_cp_registered_perks", manifest );
    setdvar( @"bo7_cp_perk_manifest_ready", "1" );
    level.cp_custom_perks_ready = 1;
    {}
    {}
    {}
    foreach ( player in level.players )
    {
        player cp_update_overflow_perks( {} );
        player cp_gold_open_sync();
        player thread cp_sync_manifest_to_client();
    }
}
function cp_update_overflow_perks( params )
{
    if ( isplayer( self ) )
    {
        self thread cp_refresh_owner_hud();
    }
}
function cp_refresh_owner_hud()
{
    self notify( "cp_owner_hud_refresh_restart" );
    self endon( "cp_owner_hud_refresh_restart" );
    self endon( #"disconnect" );
    level endon( #"game_ended" );
    wait 0.05;
    self cp_publish_owner_hud();
}
function cp_publish_owner_hud()
{
    if ( !isplayer( self ) )
    {
        return;
    }
    state = "v1:";
    delimiter = "";
    all_state = "v1:";
    all_delimiter = "";
    if ( isdefined( self.perks_active ) )
    {
        for ( i = 0; i < self.perks_active.size; i++ )
        {
            perk = self.perks_active[ i ];
            if ( isdefined( perk ) && perk != "specialty_choice" )
            {
                all_state = all_state + all_delimiter + perk;
                all_delimiter = ",";
                if ( i >= 16 )
                {
                    state = state + delimiter + perk;
                    delimiter = ",";
                }
            }
        }
    }
    owner_signature = all_state;
    owner_signature = owner_signature + ":" + ( self zombie_perks::has_perk( "specialty_vitality" ) ? "1" : "0" );
    owner_signature = owner_signature + ":" + ( self zombie_perks::has_perk( "specialty_electric_cherry" ) ? "1" : "0" );
    owner_signature = owner_signature + ":" + ( self zombie_perks::has_perk( "specialty_tortoise" ) ? "1" : "0" );
    owner_signature = owner_signature + ":" + ( self zombie_perks::has_perk( "specialty_bandolier" ) ? "1" : "0" );
    owner_signature = owner_signature + ":" + ( self zombie_perks::has_perk( "specialty_gautys_gold" ) ? "1" : "0" );
    owner_signature = owner_signature + ":" + ( self zombie_perks::has_perk( "specialty_jug2" ) ? "1" : "0" );
    if ( isdefined( self.cp_last_owner_hud_signature ) && self.cp_last_owner_hud_signature == owner_signature )
    {
        return;
    }
    self.cp_last_owner_hud_signature = owner_signature;
    self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_client_overflow_perks", state );
    self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_client_all_perks", all_state );
    owned_vitality = self zombie_perks::has_perk( "specialty_vitality" );
    self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_client_owned_vitality", owned_vitality ? "1" : "0" );
    owned_electric_cherry = self zombie_perks::has_perk( "specialty_electric_cherry" );
    self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_client_owned_electric_cherry", owned_electric_cherry ? "1" : "0" );
    owned_tortoise = self zombie_perks::has_perk( "specialty_tortoise" );
    self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_client_owned_tortoise", owned_tortoise ? "1" : "0" );
    owned_bandolier = self zombie_perks::has_perk( "specialty_bandolier" );
    self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_client_owned_bandolier", owned_bandolier ? "1" : "0" );
    owned_gautys_gold = self zombie_perks::has_perk( "specialty_gautys_gold" );
    self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_client_owned_gautys_gold", owned_gautys_gold ? "1" : "0" );
    owned_jug2 = self zombie_perks::has_perk( "specialty_jug2" );
    self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_client_owned_jug2", owned_jug2 ? "1" : "0" );
    self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_client_hud_ready", "1" );
}
function cp_register( def )
{
    if ( !isarray( def ) || !isdefined( def[ "id" ] ) || !isdefined( def[ "code" ] ) )
    {
        {}
        return false;
    }
    id = def[ "id" ];
    code = int( def[ "code" ] );
    if ( !isstring( id ) || code < 1 || code > 249 )
    {
        {}
        return false;
    }
    if ( isdefined( level.cp_defs[ id ] ) || isdefined( level.cp_code_to_id[ code ] ) )
    {
        {}
        return false;
    }
    def[ "code" ] = code;
    def[ "ref" ] = "specialty_" + id;
    if ( !isdefined( def[ "icon_material" ] ) ) def[ "icon_material" ] = "ui_icon_perks_placeholder";
    level.cp_defs[ id ] = def;
    level.cp_code_to_id[ code ] = id;
    level.cp_custom_refs[ def[ "ref" ] ] = id;
    return true;
}
cp_restore_saved_settings()
{
    level.cp_rs_names = [];
    level.cp_rs_names[0] = @"bo7_cp_vitality_pick";
    level.cp_rs_names[1] = @"bo7_cp_bandolier_pick";
    level.cp_rs_names[2] = @"bo7_cp_tortoise_pick";
    level.cp_rs_names[3] = @"bo7_cp_gautys_gold_pick";
    level.cp_rs_names[4] = @"bo7_cp_off_vitality";
    level.cp_rs_names[5] = @"bo7_cp_off_bandolier";
    level.cp_rs_names[6] = @"bo7_cp_off_tortoise";
    level.cp_rs_names[7] = @"bo7_cp_off_gautys_gold";
    level.cp_rs_names[8] = @"bo7_cp_off_blaze_phase";
    level.cp_rs_names[9] = @"bo7_cp_off_native_juggernog";
    level.cp_rs_names[10] = @"bo7_cp_off_native_quick_revive";
    level.cp_rs_names[11] = @"bo7_cp_off_native_speedcola";
    level.cp_rs_names[12] = @"bo7_cp_off_native_staminup";
    level.cp_rs_names[13] = @"bo7_cp_off_native_deadshot";
    level.cp_rs_names[14] = @"bo7_cp_off_native_elemental_pop";
    level.cp_rs_names[15] = @"bo7_cp_off_native_phd_flopper";
    level.cp_rs_names[16] = @"bo7_cp_off_native_death_perception";
    level.cp_rs_names[17] = @"bo7_cp_off_native_vulture_aid";
    level.cp_rs_names[18] = @"bo7_cp_off_native_m_mod";
    level.cp_rs_names[19] = @"bo7_cp_off_native_d_mod";
    level.cp_rs_names[20] = @"bo7_cp_off_native_w_mod";
    level.cp_rs_names[21] = @"bo7_cp_off_native_y_mod";
    level.cp_rs_names[22] = @"bo7_cp_off_native_z_mod";
    level.cp_rs_names[23] = @"bo7_cp_eternal_frame_style";
    level.cp_rs_names[24] = @"bo7_cp_jug2_pick";
    level.cp_rs_names[25] = @"bo7_cp_off_jug2";
    level.cp_rs_names[26] = @"bo7_cp_hunters_mark_pick";
    level.cp_rs_names[27] = @"bo7_cp_off_hunters_mark";
    level.cp_rs_names[28] = @"bo7_cp_electric_cherry_pick";
    level.cp_rs_names[29] = @"bo7_cp_off_electric_cherry";
    level.cp_rs_names[30] = @"bo7_cp_off_machines";
    level.cp_rs_names[31] = @"bo7_cp_off_axe_shot";
    level.cp_rs_names[32] = @"bo7_cp_wunderfizz_round";
    level.cp_rs_names[33] = @"bo7_cp_blaze_phase_pick";
    level.cp_rs_names[34] = @"bo7_cp_off_nuka_cola";
    level.cp_rs_names[35] = @"bo7_cp_off_magnet_margarita";
    level.cp_rs_names[36] = @"bo7_cp_off_dam_a_nade";
    level.cp_rs_names[37] = @"bo7_cp_off_pack_a_box";
    level.cp_rs_names[38] = @"bo7_cp_off_blood_wolf_bite";
    level.cp_rs_names[39] = @"bo7_cp_off_bull_ice_blast";
    level.cp_rs_names[40] = @"bo7_cp_oc_frag";
    level.cp_rs_names[41] = @"bo7_cp_oc_semtex";
    level.cp_rs_names[42] = @"bo7_cp_oc_cluster";
    level.cp_rs_names[43] = @"bo7_cp_oc_molotov";
    level.cp_rs_names[44] = @"bo7_cp_oc_c4";
    level.cp_rs_names[45] = @"bo7_cp_oc_thermobaric";
    level.cp_rs_names[46] = @"bo7_cp_oc_axe";
    level.cp_rs_names[47] = @"bo7_cp_oc_stun";
    level.cp_rs_names[48] = @"bo7_cp_oc_decoy";
    level.cp_rs_names[49] = @"bo7_cp_oc_shockstick";
    level.cp_rs_names[50] = @"bo7_cp_oc_smoke";
    level.cp_rs_names[51] = @"bo7_cp_oc_gas";
    level.cp_rs_names[52] = @"bo7_cp_oc_monkey";
    level.cp_rs_names[53] = @"bo7_cp_oc_kazimir";
    level.cp_rs_names[54] = @"bo7_cp_oc_turret";
    level.cp_rs_names[55] = @"bo7_cp_oc_impact";
    level.cp_rs_names[56] = @"bo7_cp_oc_stim";
    level.cp_rs_names[57] = @"bo7_cp_oc_psych";
    level.cp_rs_names[58] = @"bo7_cp_oc_hunterbot";
    level.cp_rs_names[59] = @"bo7_cp_off_banana_colada";
    level.cp_rs_names[60] = @"bo7_cp_magnet_margarita_pick";
    level.cp_rs_names[61] = @"bo7_cp_banana_colada_pick";
    level.cp_rs_names[62] = @"bo7_cp_perk_limit";
    level.cp_rs_names[63] = @"bo7_cp_dam_a_nade_pick";
    level.cp_rs_names[64] = @"bo7_cp_pack_a_box_pick";
    level.cp_rs_names[65] = @"bo7_cp_blood_wolf_bite_pick";
    level.cp_rs_names[66] = @"bo7_cp_bull_ice_blast_pick";
    level.cp_rs_names[67] = @"bo7_cp_axe_shot_pick";
    level.cp_rs_names[68] = @"bo7_cp_classic_wunderfizz";
    level.cp_rs_names[69] = @"bo7_cp_classic_perk_cost";
    level.cp_rs_names[70] = @"bo7_cp_perkaholic_classic";
    level.cp_rs_names[71] = @"bo7_cp_off_killstreak_kool_aid";
    level.cp_rs_names[72] = @"bo7_cp_killstreak_kool_aid_pick";
    level.cp_rs_names[73] = @"bo7_cp_off_whos_who";
    level.cp_rs_names[74] = @"bo7_cp_whos_who_pick";
    level.cp_rs_names[75] = @"bo7_cp_off_samurais_sake";
    level.cp_rs_names[76] = @"bo7_cp_off_twin_spirit";
    setdvar( @"bo7_cp_perkaholic_classic", "0" );
    setdvar( @"bo7_cp_classic_wunderfizz", "0" );
    setdvar( @"bo7_cp_classic_perk_cost", "0" );
    setdvar( @"bo7_cp_wunderfizz_round", "-1" );
    setdvar( @"bo7_cp_perk_limit", "0" );
    level.cp_rs_parts = strtok( getdvar( "kronos_bo6_var", "" ), ";" );
    level.cp_rs_i = 0;
    while ( level.cp_rs_i < level.cp_rs_parts.size )
    {
        level.cp_rs_kv = strtok( level.cp_rs_parts[level.cp_rs_i], "=" );
        if ( level.cp_rs_kv.size == 2 && level.cp_rs_kv[0] == "bo7cp" && !issubstr( level.cp_rs_kv[1], ".." ) )
        {
            level.cp_rs_vals = strtok( level.cp_rs_kv[1], "." );
            level.cp_rs_j = 0;
            while ( level.cp_rs_j < level.cp_rs_vals.size && level.cp_rs_j < level.cp_rs_names.size )
            {
                if ( level.cp_rs_vals[level.cp_rs_j] != "-" )
                {
                    setdvar( level.cp_rs_names[level.cp_rs_j], level.cp_rs_vals[level.cp_rs_j] );
                }
                level.cp_rs_j = level.cp_rs_j + 1;
            }
            setdvar( @"bo7_cp_settings_restored", "" + level.cp_rs_j );
        }
        level.cp_rs_i = level.cp_rs_i + 1;
    }
}
function cp_ep_has_cherry_augment()
{
    return self zombie_perks::has_perk( "specialty_elemental_pop" ) && istrue( self utility::callsharedfunc( #"zombie", #"hash_3930894d8d2f0ee6", "specialty_elemental_pop", #"elemental_pop_electric_cherry" ) );
}
function cp_ep_on_perk_obtained( params )
{
    self endon( #"disconnect" );
    if ( !isplayer( self ) || !self cp_ep_has_cherry_augment() )
    {
        return;
    }
    if ( isdefined( level.zombie_augments ) && isdefined( level.zombie_augments[ #"elemental_pop_electric_cherry" ] ) )
    {
        level.zombie_augments[ #"elemental_pop_electric_cherry" ].cooldowntime = 1000000;
    }
    waitframe();
    self.var_da857539a11929b4 = 100;
    self.last_electric_cherry = gettime();
}
function cp_wunderfizz_override()
{
    level endon( #"game_ended" );
    level.cp_wf_round = getdvarint( @"bo7_cp_wunderfizz_round", -1 );
    if ( level.cp_wf_round < 0 )
    {
        return;
    }
    while ( !isdefined( level.gametypebundle ) )
    {
        waitframe();
    }
    if ( level.cp_wf_round == 0 )
    {
        level.gametypebundle.disablewunderfizz = 1;
        {}
        {}
        return;
    }
    level.gametypebundle.var_c0e626638c3cdd4c = 1;
    level.gametypebundle.var_7910192e66e7774c = level.cp_wf_round;
    level.gametypebundle.var_d2a7b8fafa40d741 = 999;
    {}
    {}
}
function cp_perk_limit_override()
{
    level endon( #"game_ended" );
    level.cp_perk_limit = getdvarint( @"bo7_cp_perk_limit", 0 );
    while ( !isdefined( level.gametypebundle ) )
    {
        waitframe();
    }
    if ( level.cp_perk_limit <= 0 )
    {
        if ( !isdefined( level.gametypebundle.perklimit ) || level.gametypebundle.perklimit <= 0 )
        {
            return;
        }
        level.cp_pl_mode = level.gametypebundle.perklimit;
        level.cp_pl_i = 0;
        while ( level.cp_pl_i < 60 )
        {
            if ( isdefined( level._custom_perks ) && level._custom_perks.size - 1 > level.gametypebundle.perklimit )
            {
                level.gametypebundle.perklimit = level._custom_perks.size - 1;
                {}
            }
            level.cp_pl_i = level.cp_pl_i + 1;
            wait 1;
        }
        return;
    }
    level.gametypebundle.perklimit = level.cp_perk_limit;
    {}
}
function cp_classic_init()
{
    level endon( #"game_ended" );
    level utility::flag_wait_all( "StartGameTypeCallbackFinished", "zombie_perks_init_complete" );
    level.cp_classic_wf = getdvarint( @"bo7_cp_classic_wunderfizz", 0 ) == 1;
    level.cp_classic_cost = getdvarint( @"bo7_cp_classic_perk_cost", 0 ) == 1;
    if ( level.cp_classic_cost )
    {
        while ( !isdefined( level.gametypebundle ) ) waitframe();
        level.gametypebundle.var_2137b6b66219eb66 = 0;
        if ( utility::issharedfuncdefined( #"perk_machine", #"hash_dfdcc3fdc88af90c" ) )
        {
            level.cp_classic_prev_cost = utility::getsharedfunc( #"perk_machine", #"hash_dfdcc3fdc88af90c" );
        }
        utility::registersharedfunc( #"perk_machine", #"hash_dfdcc3fdc88af90c", &cp_classic_machine_cost );
        level thread cp_classic_wf_pricing_init();
        {}
    }
    if ( !level.cp_classic_wf )
    {
        return;
    }
    {}
    while ( true )
    {
        if ( isdefined( level.interacts ) && isdefined( level.perk_machine_func ) && isdefined( level.perk_machine_func[ "on_use_choice" ] ) )
        {
            foreach ( ent in level.interacts )
            {
                if ( !isdefined( ent ) || istrue( ent.cp_classic_wf ) || !isdefined( ent.s_perk_machine ) || !isdefined( ent.interact_use_callbacks ) )
                {
                    continue;
                }
                if ( ent.interact_use_callbacks[ 0 ] == level.perk_machine_func[ "on_use_choice" ] )
                {
                    ent.cp_classic_wf = true;
                    ent interaction::set_interact_use_callback( &cp_classic_wunderfizz_use );
                    {}
                }
            }
        }
        wait 2;
    }
}
function cp_classic_price( ref )
{
    if ( !isdefined( ref ) ) return undefined;
    if ( !isdefined( level.cp_classic_prices ) )
    {
        level.cp_classic_prices = [];
        level.cp_classic_prices[ "specialty_juggernog" ] = 2500;
        level.cp_classic_prices[ "specialty_quickrevive" ] = 1500;
        level.cp_classic_prices[ "specialty_speedcola" ] = 3000;
        level.cp_classic_prices[ "specialty_staminup" ] = 2000;
        level.cp_classic_prices[ "specialty_deadshot" ] = 1500;
        level.cp_classic_prices[ "specialty_elemental_pop" ] = 3000;
        level.cp_classic_prices[ "specialty_phd_flopper" ] = 2000;
        level.cp_classic_prices[ "specialty_death_perception" ] = 2000;
        level.cp_classic_prices[ "specialty_vulture_aid" ] = 3000;
        level.cp_classic_prices[ "specialty_m_mod" ] = 3000;
        level.cp_classic_prices[ "specialty_d_mod" ] = 2000;
        level.cp_classic_prices[ "specialty_w_mod" ] = 2500;
        level.cp_classic_prices[ "specialty_y_mod" ] = 4000;
        level.cp_classic_prices[ "specialty_z_mod" ] = 4000;
    }
    if ( isdefined( level.cp_classic_prices[ ref ] ) ) return level.cp_classic_prices[ ref ];
    if ( isdefined( level.cp_defs ) )
    {
        foreach ( def in level.cp_defs )
        {
            if ( isdefined( def[ "ref" ] ) && def[ "ref" ] == ref ) return def[ "price" ];
        }
    }
    return undefined;
}
function cp_classic_machine_cost( usable )
{
    if ( isdefined( usable ) && isdefined( usable.script_notify ) )
    {
        level.cp_classic_p = cp_classic_price( usable.script_notify );
        if ( isdefined( level.cp_classic_p ) ) return level.cp_classic_p;
    }
    if ( isdefined( level.cp_classic_prev_cost ) ) return [[ level.cp_classic_prev_cost ]]( usable );
    return undefined;
}
function cp_perk_cost( ref )
{
    if ( istrue( level.cp_classic_cost ) )
    {
        self.cp_cost_classic = cp_classic_price( ref );
        if ( isdefined( self.cp_cost_classic ) ) return self.cp_cost_classic;
    }
    return self zombie_perks::function_77331fd62580dd0a();
}
function cp_classic_wunderfizz_use( player )
{
    if ( !isdefined( player ) || !isplayer( player ) || istrue( player.interactions_disabled ) || !isalive( player ) || istrue( player.inlaststand ) )
    {
        return;
    }
    if ( isdefined( level.gametypebundle.perklimit ) && level.gametypebundle.perklimit > 0 && ( player.num_perks ?? 0 ) >= level.gametypebundle.perklimit )
    {
        return;
    }
    if ( player cp_at_perk_limit() || player zombie_perks::has_all_perks() )
    {
        return;
    }
    if ( isdefined( self.s_perk_machine ) && isdefined( self.s_perk_machine.mdl_perk_machine ) && self.s_perk_machine.mdl_perk_machine getscriptablepartstate( "base" ) == "power_off" )
    {
        return;
    }
    player.cp_wf_cost = player zombie_perks::function_77331fd62580dd0a();
    player.cp_wf_currency = #"essence";
    if ( isdefined( self.s_perk_machine ) && isdefined( self.s_perk_machine.script_currency ) ) player.cp_wf_currency = self.s_perk_machine.script_currency;
    if ( !player currency::attempt_purchase( player.cp_wf_currency, player.cp_wf_cost, 1, undefined, #"perk" ) )
    {
        return;
    }
    player.cp_wf_perk = player zombie_perks::give_random_new_perk( undefined, undefined, undefined, 1 );
    if ( !isdefined( player.cp_wf_perk ) )
    {
        player currency::add_currency_amount( player.cp_wf_currency, player.cp_wf_cost, #"classic_wunderfizz_refund" );
        return;
    }
    player.cp_wf_params = spawnstruct();
    player.cp_wf_params.perkref = player.cp_wf_perk;
    player.cp_wf_params.cost = player.cp_wf_cost;
    player.cp_wf_params.currency = player.cp_wf_currency;
    player.cp_wf_params.source = #"wunderfizz";
    player callback::callback( "zm_perk_purchased", player.cp_wf_params );
    {}
}
function cp_at_perk_limit()
{
    return isdefined( level.cp_perk_limit ) && level.cp_perk_limit > 0 && isdefined( self.num_perks ) && self.num_perks >= level.cp_perk_limit;
}
function cp_perk_disabled( id )
{
    return getdvarint("bo7_cp_off_" + id, 0) == 1;
}
function cp_register_native( id, def )
{
    if ( cp_perk_disabled( id ) )
    {
        {}
        return;
    }
    ref = def[ "ref" ];
    drink_from = def[ "drink_from" ] ?? "specialty_juggernog";
    if ( !isdefined( level.perkbundles ) )
    {
        {}
        return;
    }
    src = level.perkbundles[ drink_from ];
    if ( !isdefined( src ) )
    {
        {}
        return;
    }
    if ( !isdefined( level._custom_perks ) )
    {
        level._custom_perks = [];
    }
    if ( isdefined( level._custom_perks[ ref ] ) )
    {
        {}
        return;
    }
    custom_bundle = spawnstruct();
    custom_bundle.name = def[ "name" ] ?? id;
    custom_bundle.description = def[ "description" ] ?? "";
    custom_bundle.var_4f05ecd6a02ee78c = src.var_4f05ecd6a02ee78c;
    custom_bundle.zmperkcost = src.zmperkcost;
    custom_bundle.zmperkmachineradiusoverride = src.zmperkmachineradiusoverride;
    custom_bundle.zmperkscriptable = src.zmperkscriptable;
    custom_bundle.zmperkgesture = src.zmperkgesture;
    custom_bundle.zmperkhinticon = def[ "icon_material" ] ?? src.zmperkhinticon;
    custom_bundle.zmperksound = src.zmperksound;
    custom_bundle.var_ccd5d2ff97067631 = src.var_ccd5d2ff97067631 ?? undefined;
    custom_bundle.var_8cded1959bcc76fd = src.var_8cded1959bcc76fd ?? undefined;
    custom_bundle.var_e77b4be2fc4d857f = src.var_e77b4be2fc4d857f ?? undefined;
    custom_bundle.zombiesperk = 1;
    custom_bundle.showninmenu = 1;
    level.perkbundles[ ref ] = custom_bundle;
    if ( isdefined( level.zmperkidbyref ) && isdefined( level.zmperkidbyref[ drink_from ] ) )
    {
        hud_perk_id = cp_rank_hud_perk_id( id );
        if ( hud_perk_id > 0 )
        {
            level.zmperkidbyref[ ref ] = hud_perk_id;
            {}
        }
        else
        {
            level.zmperkidbyref[ ref ] = level.zmperkidbyref[ drink_from ];
            {}
        }
    }
    str_currency = currency::get_perk_machine_currency( drink_from );
    n_fixed_cost = def[ "price" ] ?? src.zmperkcost;
    func_give = def[ "on_give" ];
    func_take = def[ "on_take" ];
    if ( !isdefined( func_give ) )
    {
        func_give = &cp_noop_give;
    }
    if ( !isdefined( func_take ) )
    {
        func_take = &cp_noop_take;
    }
    level thread zombie_perks::enable_perk_for_level(
        ref,
        str_currency,
        n_fixed_cost,
        func_give,
        func_take,
        1,
        1
    );
    level.cp_registered_perks[ id ] = 1;
    {}
}
function cp_perk_rank( id )
{
    level.cp_rank_n = 0;
    foreach ( other_id, other_def in level.cp_defs )
    {
        if ( other_def[ "code" ] < level.cp_defs[ id ][ "code" ] )
        {
            level.cp_rank_n = level.cp_rank_n + 1;
        }
    }
    return level.cp_rank_n;
}
function cp_rank_hud_perk_id( id )
{
    level.cp_rank_id = 31 - cp_perk_rank( id );
    if ( level.cp_rank_id < 17 )
    {
        return 0;
    }
    foreach ( perk_ref, perk_id in level.zmperkidbyref )
    {
        if ( perk_id == level.cp_rank_id && !isdefined( level.cp_custom_refs[ perk_ref ] ) )
        {
            return 0;
        }
    }
    return level.cp_rank_id;
}
function cp_noop_give()
{
}
function cp_noop_take( b_pause, str_perk, str_result, n_slot )
{
}
function cp_has( player, id )
{
    if ( !isdefined( player ) || !isdefined( level.cp_defs[ id ] ) )
    {
        return false;
    }
    return player zombie_perks::has_perk( level.cp_defs[ id ][ "ref" ] );
}
function cp_give( id )
{
    if (cp_perk_disabled(id)) return;
    if ( !isdefined( level.cp_defs[ id ] ) )
    {
        {}
        return;
    }
    zombie_perks::give_perk( level.cp_defs[ id ][ "ref" ], 1 );
}
function cp_take( id )
{
    if ( !isdefined( level.cp_defs[ id ] ) )
    {
        {}
        return;
    }
    zombie_perks::take_perk( level.cp_defs[ id ][ "ref" ] );
}
function on_wunderfizz_purchase( channel, menuitemindex )
{
    if ( self cp_receive_generated_electric_cherry( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_hunters_mark( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_jug2( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_blaze_phase( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_magnet_margarita( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_banana_colada( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_dam_a_nade( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_pack_a_box( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_blood_wolf_bite( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_bull_ice_blast( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_axe_shot( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_killstreak_kool_aid( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_whos_who( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_vitality( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_tortoise( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_gautys_gold( channel, menuitemindex ) ) return;
    if ( self cp_receive_generated_bandolier( channel, menuitemindex ) ) return;
    if ( !isdefined( channel ) || !isdefined( menuitemindex ) )
    {
        return;
    }
    if ( channel != "custom_perk_choice_purchase" && channel != "perk_choice_purchase" )
    {
        return;
    }
    if ( menuitemindex == 9000 || ( isstring( menuitemindex ) && menuitemindex == "9000" ) )
    {
        if ( isplayer( self ) )
        {
            self.cp_hud_slot = 0;
            self.cp_hud_watch_snapshot = undefined;
            self cp_publish_slot_perks();
        }
        return;
    }
    if ( menuitemindex == 9001 || ( isstring( menuitemindex ) && menuitemindex == "9001" ) )
    {
        if ( isplayer( self ) )
        {
            self.cp_hud_slot = 1;
            self.cp_hud_watch_snapshot = undefined;
            self cp_publish_slot_perks();
        }
        return;
    }
    if ( menuitemindex == 9002 || ( isstring( menuitemindex ) && menuitemindex == "9002" ) )
    {
        if ( isplayer( self ) )
        {
            self.cp_hud_slot = 2;
            self.cp_hud_watch_snapshot = undefined;
            self cp_publish_slot_perks();
        }
        return;
    }
    if ( menuitemindex == 9003 || ( isstring( menuitemindex ) && menuitemindex == "9003" ) )
    {
        if ( isplayer( self ) )
        {
            self.cp_hud_slot = 3;
            self.cp_hud_watch_snapshot = undefined;
            self cp_publish_slot_perks();
        }
        return;
    }
    if ( menuitemindex == 5000 || ( isstring( menuitemindex ) && menuitemindex == "5000" ) )
    {
        self cp_receive_vitality_pick( channel, 5000 );
        return;
    }
    if ( menuitemindex == 5001 || ( isstring( menuitemindex ) && menuitemindex == "5001" ) )
    {
        self cp_receive_vitality_pick( channel, 5001 );
        return;
    }
    if ( menuitemindex == 5002 || ( isstring( menuitemindex ) && menuitemindex == "5002" ) )
    {
        self cp_receive_vitality_pick( channel, 5002 );
        return;
    }
    if ( menuitemindex == 5010 || ( isstring( menuitemindex ) && menuitemindex == "5010" ) )
    {
        self cp_receive_vitality_pick( channel, 5010 );
        return;
    }
    if ( menuitemindex == 5011 || ( isstring( menuitemindex ) && menuitemindex == "5011" ) )
    {
        self cp_receive_vitality_pick( channel, 5011 );
        return;
    }
    if ( menuitemindex == 5012 || ( isstring( menuitemindex ) && menuitemindex == "5012" ) )
    {
        self cp_receive_vitality_pick( channel, 5012 );
        return;
    }
    if ( menuitemindex == 5020 || ( isstring( menuitemindex ) && menuitemindex == "5020" ) )
    {
        self cp_receive_vitality_pick( channel, 5020 );
        return;
    }
    if ( menuitemindex == 5021 || ( isstring( menuitemindex ) && menuitemindex == "5021" ) )
    {
        self cp_receive_vitality_pick( channel, 5021 );
        return;
    }
    if ( menuitemindex == 5022 || ( isstring( menuitemindex ) && menuitemindex == "5022" ) )
    {
        self cp_receive_vitality_pick( channel, 5022 );
        return;
    }
    if ( menuitemindex == 5100 || ( isstring( menuitemindex ) && menuitemindex == "5100" ) )
    {
        self cp_receive_vitality_pick( channel, 5100 );
        return;
    }
    if ( menuitemindex == 5102 || ( isstring( menuitemindex ) && menuitemindex == "5102" ) )
    {
        self cp_receive_vitality_pick( channel, 5102 );
        return;
    }
    if ( menuitemindex == 5110 || ( isstring( menuitemindex ) && menuitemindex == "5110" ) )
    {
        self cp_receive_vitality_pick( channel, 5110 );
        return;
    }
    if ( menuitemindex == 5112 || ( isstring( menuitemindex ) && menuitemindex == "5112" ) )
    {
        self cp_receive_vitality_pick( channel, 5112 );
        return;
    }
    if ( menuitemindex == 5120 || ( isstring( menuitemindex ) && menuitemindex == "5120" ) )
    {
        self cp_receive_vitality_pick( channel, 5120 );
        return;
    }
    if ( menuitemindex == 5122 || ( isstring( menuitemindex ) && menuitemindex == "5122" ) )
    {
        self cp_receive_vitality_pick( channel, 5122 );
        return;
    }
    if ( menuitemindex == 5200 || ( isstring( menuitemindex ) && menuitemindex == "5200" ) )
    {
        self cp_receive_vitality_pick( channel, 5200 );
        return;
    }
    if ( menuitemindex == 5201 || ( isstring( menuitemindex ) && menuitemindex == "5201" ) )
    {
        self cp_receive_vitality_pick( channel, 5201 );
        return;
    }
    if ( menuitemindex == 5210 || ( isstring( menuitemindex ) && menuitemindex == "5210" ) )
    {
        self cp_receive_vitality_pick( channel, 5210 );
        return;
    }
    if ( menuitemindex == 5211 || ( isstring( menuitemindex ) && menuitemindex == "5211" ) )
    {
        self cp_receive_vitality_pick( channel, 5211 );
        return;
    }
    if ( menuitemindex == 5220 || ( isstring( menuitemindex ) && menuitemindex == "5220" ) )
    {
        self cp_receive_vitality_pick( channel, 5220 );
        return;
    }
    if ( menuitemindex == 5221 || ( isstring( menuitemindex ) && menuitemindex == "5221" ) )
    {
        self cp_receive_vitality_pick( channel, 5221 );
        return;
    }
    if ( menuitemindex == 6000 || ( isstring( menuitemindex ) && menuitemindex == "6000" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6000 );
        return;
    }
    if ( menuitemindex == 6001 || ( isstring( menuitemindex ) && menuitemindex == "6001" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6001 );
        return;
    }
    if ( menuitemindex == 6002 || ( isstring( menuitemindex ) && menuitemindex == "6002" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6002 );
        return;
    }
    if ( menuitemindex == 6003 || ( isstring( menuitemindex ) && menuitemindex == "6003" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6003 );
        return;
    }
    if ( menuitemindex == 6010 || ( isstring( menuitemindex ) && menuitemindex == "6010" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6010 );
        return;
    }
    if ( menuitemindex == 6011 || ( isstring( menuitemindex ) && menuitemindex == "6011" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6011 );
        return;
    }
    if ( menuitemindex == 6012 || ( isstring( menuitemindex ) && menuitemindex == "6012" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6012 );
        return;
    }
    if ( menuitemindex == 6013 || ( isstring( menuitemindex ) && menuitemindex == "6013" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6013 );
        return;
    }
    if ( menuitemindex == 6020 || ( isstring( menuitemindex ) && menuitemindex == "6020" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6020 );
        return;
    }
    if ( menuitemindex == 6021 || ( isstring( menuitemindex ) && menuitemindex == "6021" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6021 );
        return;
    }
    if ( menuitemindex == 6022 || ( isstring( menuitemindex ) && menuitemindex == "6022" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6022 );
        return;
    }
    if ( menuitemindex == 6023 || ( isstring( menuitemindex ) && menuitemindex == "6023" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6023 );
        return;
    }
    if ( menuitemindex == 6100 || ( isstring( menuitemindex ) && menuitemindex == "6100" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6100 );
        return;
    }
    if ( menuitemindex == 6102 || ( isstring( menuitemindex ) && menuitemindex == "6102" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6102 );
        return;
    }
    if ( menuitemindex == 6103 || ( isstring( menuitemindex ) && menuitemindex == "6103" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6103 );
        return;
    }
    if ( menuitemindex == 6110 || ( isstring( menuitemindex ) && menuitemindex == "6110" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6110 );
        return;
    }
    if ( menuitemindex == 6112 || ( isstring( menuitemindex ) && menuitemindex == "6112" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6112 );
        return;
    }
    if ( menuitemindex == 6113 || ( isstring( menuitemindex ) && menuitemindex == "6113" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6113 );
        return;
    }
    if ( menuitemindex == 6120 || ( isstring( menuitemindex ) && menuitemindex == "6120" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6120 );
        return;
    }
    if ( menuitemindex == 6122 || ( isstring( menuitemindex ) && menuitemindex == "6122" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6122 );
        return;
    }
    if ( menuitemindex == 6123 || ( isstring( menuitemindex ) && menuitemindex == "6123" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6123 );
        return;
    }
    if ( menuitemindex == 6200 || ( isstring( menuitemindex ) && menuitemindex == "6200" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6200 );
        return;
    }
    if ( menuitemindex == 6201 || ( isstring( menuitemindex ) && menuitemindex == "6201" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6201 );
        return;
    }
    if ( menuitemindex == 6203 || ( isstring( menuitemindex ) && menuitemindex == "6203" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6203 );
        return;
    }
    if ( menuitemindex == 6210 || ( isstring( menuitemindex ) && menuitemindex == "6210" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6210 );
        return;
    }
    if ( menuitemindex == 6211 || ( isstring( menuitemindex ) && menuitemindex == "6211" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6211 );
        return;
    }
    if ( menuitemindex == 6213 || ( isstring( menuitemindex ) && menuitemindex == "6213" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6213 );
        return;
    }
    if ( menuitemindex == 6220 || ( isstring( menuitemindex ) && menuitemindex == "6220" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6220 );
        return;
    }
    if ( menuitemindex == 6221 || ( isstring( menuitemindex ) && menuitemindex == "6221" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6221 );
        return;
    }
    if ( menuitemindex == 6223 || ( isstring( menuitemindex ) && menuitemindex == "6223" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6223 );
        return;
    }
    if ( menuitemindex == 6300 || ( isstring( menuitemindex ) && menuitemindex == "6300" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6300 );
        return;
    }
    if ( menuitemindex == 6301 || ( isstring( menuitemindex ) && menuitemindex == "6301" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6301 );
        return;
    }
    if ( menuitemindex == 6302 || ( isstring( menuitemindex ) && menuitemindex == "6302" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6302 );
        return;
    }
    if ( menuitemindex == 6310 || ( isstring( menuitemindex ) && menuitemindex == "6310" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6310 );
        return;
    }
    if ( menuitemindex == 6311 || ( isstring( menuitemindex ) && menuitemindex == "6311" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6311 );
        return;
    }
    if ( menuitemindex == 6312 || ( isstring( menuitemindex ) && menuitemindex == "6312" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6312 );
        return;
    }
    if ( menuitemindex == 6320 || ( isstring( menuitemindex ) && menuitemindex == "6320" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6320 );
        return;
    }
    if ( menuitemindex == 6321 || ( isstring( menuitemindex ) && menuitemindex == "6321" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6321 );
        return;
    }
    if ( menuitemindex == 6322 || ( isstring( menuitemindex ) && menuitemindex == "6322" ) )
    {
        self cp_receive_electric_cherry_pick( channel, 6322 );
        return;
    }
    if ( menuitemindex == 7000 || ( isstring( menuitemindex ) && menuitemindex == "7000" ) )
    {
        self cp_receive_tortoise_pick( channel, 7000 );
        return;
    }
    if ( menuitemindex == 7001 || ( isstring( menuitemindex ) && menuitemindex == "7001" ) )
    {
        self cp_receive_tortoise_pick( channel, 7001 );
        return;
    }
    if ( menuitemindex == 7010 || ( isstring( menuitemindex ) && menuitemindex == "7010" ) )
    {
        self cp_receive_tortoise_pick( channel, 7010 );
        return;
    }
    if ( menuitemindex == 7011 || ( isstring( menuitemindex ) && menuitemindex == "7011" ) )
    {
        self cp_receive_tortoise_pick( channel, 7011 );
        return;
    }
    if ( menuitemindex == 7020 || ( isstring( menuitemindex ) && menuitemindex == "7020" ) )
    {
        self cp_receive_tortoise_pick( channel, 7020 );
        return;
    }
    if ( menuitemindex == 7021 || ( isstring( menuitemindex ) && menuitemindex == "7021" ) )
    {
        self cp_receive_tortoise_pick( channel, 7021 );
        return;
    }
    if ( menuitemindex == 7100 || ( isstring( menuitemindex ) && menuitemindex == "7100" ) )
    {
        self cp_receive_tortoise_pick( channel, 7100 );
        return;
    }
    if ( menuitemindex == 7110 || ( isstring( menuitemindex ) && menuitemindex == "7110" ) )
    {
        self cp_receive_tortoise_pick( channel, 7110 );
        return;
    }
    if ( menuitemindex == 7120 || ( isstring( menuitemindex ) && menuitemindex == "7120" ) )
    {
        self cp_receive_tortoise_pick( channel, 7120 );
        return;
    }
    if ( menuitemindex == 8000 || ( isstring( menuitemindex ) && menuitemindex == "8000" ) )
    {
        self cp_receive_bandolier_pick( channel, 8000 );
        return;
    }
    if ( menuitemindex == 8001 || ( isstring( menuitemindex ) && menuitemindex == "8001" ) )
    {
        self cp_receive_bandolier_pick( channel, 8001 );
        return;
    }
    if ( menuitemindex == 8002 || ( isstring( menuitemindex ) && menuitemindex == "8002" ) )
    {
        self cp_receive_bandolier_pick( channel, 8002 );
        return;
    }
    if ( menuitemindex == 8010 || ( isstring( menuitemindex ) && menuitemindex == "8010" ) )
    {
        self cp_receive_bandolier_pick( channel, 8010 );
        return;
    }
    if ( menuitemindex == 8011 || ( isstring( menuitemindex ) && menuitemindex == "8011" ) )
    {
        self cp_receive_bandolier_pick( channel, 8011 );
        return;
    }
    if ( menuitemindex == 8012 || ( isstring( menuitemindex ) && menuitemindex == "8012" ) )
    {
        self cp_receive_bandolier_pick( channel, 8012 );
        return;
    }
    if ( menuitemindex == 8020 || ( isstring( menuitemindex ) && menuitemindex == "8020" ) )
    {
        self cp_receive_bandolier_pick( channel, 8020 );
        return;
    }
    if ( menuitemindex == 8021 || ( isstring( menuitemindex ) && menuitemindex == "8021" ) )
    {
        self cp_receive_bandolier_pick( channel, 8021 );
        return;
    }
    if ( menuitemindex == 8022 || ( isstring( menuitemindex ) && menuitemindex == "8022" ) )
    {
        self cp_receive_bandolier_pick( channel, 8022 );
        return;
    }
    if ( menuitemindex == 8100 || ( isstring( menuitemindex ) && menuitemindex == "8100" ) )
    {
        self cp_receive_bandolier_pick( channel, 8100 );
        return;
    }
    if ( menuitemindex == 8102 || ( isstring( menuitemindex ) && menuitemindex == "8102" ) )
    {
        self cp_receive_bandolier_pick( channel, 8102 );
        return;
    }
    if ( menuitemindex == 8110 || ( isstring( menuitemindex ) && menuitemindex == "8110" ) )
    {
        self cp_receive_bandolier_pick( channel, 8110 );
        return;
    }
    if ( menuitemindex == 8112 || ( isstring( menuitemindex ) && menuitemindex == "8112" ) )
    {
        self cp_receive_bandolier_pick( channel, 8112 );
        return;
    }
    if ( menuitemindex == 8120 || ( isstring( menuitemindex ) && menuitemindex == "8120" ) )
    {
        self cp_receive_bandolier_pick( channel, 8120 );
        return;
    }
    if ( menuitemindex == 8122 || ( isstring( menuitemindex ) && menuitemindex == "8122" ) )
    {
        self cp_receive_bandolier_pick( channel, 8122 );
        return;
    }
    if ( menuitemindex == 8200 || ( isstring( menuitemindex ) && menuitemindex == "8200" ) )
    {
        self cp_receive_bandolier_pick( channel, 8200 );
        return;
    }
    if ( menuitemindex == 8201 || ( isstring( menuitemindex ) && menuitemindex == "8201" ) )
    {
        self cp_receive_bandolier_pick( channel, 8201 );
        return;
    }
    if ( menuitemindex == 8210 || ( isstring( menuitemindex ) && menuitemindex == "8210" ) )
    {
        self cp_receive_bandolier_pick( channel, 8210 );
        return;
    }
    if ( menuitemindex == 8211 || ( isstring( menuitemindex ) && menuitemindex == "8211" ) )
    {
        self cp_receive_bandolier_pick( channel, 8211 );
        return;
    }
    if ( menuitemindex == 8220 || ( isstring( menuitemindex ) && menuitemindex == "8220" ) )
    {
        self cp_receive_bandolier_pick( channel, 8220 );
        return;
    }
    if ( menuitemindex == 8221 || ( isstring( menuitemindex ) && menuitemindex == "8221" ) )
    {
        self cp_receive_bandolier_pick( channel, 8221 );
        return;
    }
    if ( menuitemindex == 4000 || ( isstring( menuitemindex ) && menuitemindex == "4000" ) )
    {
        self cp_receive_gold_pick( channel, 4000 );
        return;
    }
    if ( menuitemindex == 4001 || ( isstring( menuitemindex ) && menuitemindex == "4001" ) )
    {
        self cp_receive_gold_pick( channel, 4001 );
        return;
    }
    if ( menuitemindex == 4010 || ( isstring( menuitemindex ) && menuitemindex == "4010" ) )
    {
        self cp_receive_gold_pick( channel, 4010 );
        return;
    }
    if ( menuitemindex == 4011 || ( isstring( menuitemindex ) && menuitemindex == "4011" ) )
    {
        self cp_receive_gold_pick( channel, 4011 );
        return;
    }
    if ( menuitemindex == 4020 || ( isstring( menuitemindex ) && menuitemindex == "4020" ) )
    {
        self cp_receive_gold_pick( channel, 4020 );
        return;
    }
    if ( menuitemindex == 4021 || ( isstring( menuitemindex ) && menuitemindex == "4021" ) )
    {
        self cp_receive_gold_pick( channel, 4021 );
        return;
    }
    if ( menuitemindex == 4100 || ( isstring( menuitemindex ) && menuitemindex == "4100" ) )
    {
        self cp_receive_gold_pick( channel, 4100 );
        return;
    }
    if ( menuitemindex == 4110 || ( isstring( menuitemindex ) && menuitemindex == "4110" ) )
    {
        self cp_receive_gold_pick( channel, 4110 );
        return;
    }
    if ( menuitemindex == 4120 || ( isstring( menuitemindex ) && menuitemindex == "4120" ) )
    {
        self cp_receive_gold_pick( channel, 4120 );
        return;
    }
    {}
    if ( menuitemindex == 1770 || ( isstring( menuitemindex ) && menuitemindex == "1770" ) )
    {
        self thread purchase_custom_perk( "vitality", "specialty_vitality" );
    }
    else if ( menuitemindex == 1778 || ( isstring( menuitemindex ) && menuitemindex == "1778" ) )
    {
        self thread purchase_custom_perk( "bandolier", "specialty_bandolier" );
    }
    else if ( menuitemindex == 1773 || ( isstring( menuitemindex ) && menuitemindex == "1773" ) )
    {
        self thread purchase_custom_perk( "tortoise", "specialty_tortoise" );
    }
    else if ( menuitemindex == 1782 || ( isstring( menuitemindex ) && menuitemindex == "1782" ) )
    {
        self thread purchase_custom_perk( "gautys_gold", "specialty_gautys_gold" );
    }
    else if ( menuitemindex == 1771 || ( isstring( menuitemindex ) && menuitemindex == "1771" ) )
    {
        self thread purchase_custom_perk( "jug2", "specialty_jug2" );
    }
    else if ( menuitemindex == 1772 || ( isstring( menuitemindex ) && menuitemindex == "1772" ) )
    {
        self thread purchase_custom_perk( "electric_cherry", "specialty_electric_cherry" );
    }
    else if ( menuitemindex == 1784 || ( isstring( menuitemindex ) && menuitemindex == "1784" ) )
    {
        self thread purchase_custom_perk( "blaze_phase", "specialty_blaze_phase" );
    }
    else if ( menuitemindex == 1787 || ( isstring( menuitemindex ) && menuitemindex == "1787" ) )
    {
        self thread purchase_custom_perk( "hunters_mark", "specialty_hunters_mark" );
    }
    else if ( isdefined( level.cp_code_to_id[ int( menuitemindex ) - 1700 ] ) )
    {
        self thread purchase_custom_perk( level.cp_code_to_id[ int( menuitemindex ) - 1700 ], "specialty_" + level.cp_code_to_id[ int( menuitemindex ) - 1700 ] );
    }
    else
    {
        {}
        {}
    }
}
function purchase_custom_perk( id, ref, perk_currency = undefined )
{
    level endon( #"game_ended" );
    {}
    if ( !isdefined( level.perkbundles ) || !isdefined( level.perkbundles[ ref ] ) ||
         !isdefined( level._custom_perks ) || !isdefined( level._custom_perks[ ref ] ) )
    {
        {}
        {}
        return;
    }
    {}
    if ( self zombie_perks::has_perk( ref ) )
    {
        {}
        {}
        return;
    }
    if ( self cp_at_perk_limit() )
    {
        {}
        return;
    }
    if ( !isdefined( self.s_perk_choice_machine ) )
    {
        {}
        {}
        return;
    }
    perk_cost = self cp_perk_cost( ref );
    str_currency = perk_currency ?? currency::get_perk_machine_currency( "specialty_juggernog" );
    {}
    if ( !self currency::attempt_purchase( str_currency, perk_cost, 1, undefined, #"perk", ref ) )
    {
        {}
        {}
        purchasemenu::function_93f934ea2f1c06f8( 3 );
        return;
    }
    {}
    if ( isdefined( level.gametypebundle.var_d2a7b8fafa40d741 ) && level.gametypebundle.var_d2a7b8fafa40d741 > 0 )
    {
        if ( !isdefined( self.total_purchased_perks ) )
        {
            self.total_purchased_perks = 0;
        }
        if ( !isdefined( self.perkspurchased ) )
        {
            self.perkspurchased = [];
        }
        if ( !isdefined( level.var_af8e5ce115d7696f ) )
        {
            level.var_af8e5ce115d7696f = 0;
        }
        self.total_purchased_perks++;
        self.perkspurchased[ ref ] = 1;
        level.var_af8e5ce115d7696f++;
        level notify( #"perk_purchased" );
        n_perk_purchased_threshold = level.gametypebundle.var_d2a7b8fafa40d741 + level.players.size;
        if ( level.var_af8e5ce115d7696f >= n_perk_purchased_threshold )
        {
            level.var_865fa84b8f7cc220 = 1;
        }
    }
    b_playing_gesture = 0;
    if ( !self isgestureplaying() )
    {
        gesture = level._custom_perks[ ref ].perk_bottle_weapon;
        if ( isdefined( gesture ) )
        {
            self thread zombie_perks::play_perk_drinking_gesture( gesture );
            b_playing_gesture = 1;
        }
    }
    if ( isdefined( self.s_perk_choice_machine ) &&
         isdefined( self.s_perk_choice_machine.mdl_perk_machine ) )
    {
        paramsused = spawnstruct();
        paramsused.perk_machine = self.s_perk_choice_machine.mdl_perk_machine;
        paramsused.perk = ref;
        callback::callback( "zm_perk_machine_used", paramsused );
    }
    zombie_perks::give_perk( ref, 1, b_playing_gesture );
    {}
    paramspurchased = spawnstruct();
    paramspurchased.perkref = ref;
    paramspurchased.cost = perk_cost;
    paramspurchased.currency = str_currency;
    paramspurchased.source = #"wunderfizz";
    callback::callback( "zm_perk_purchased", paramspurchased );
    purchasemenu::function_93f934ea2f1c06f8( 1 );
    self notify( #"wunderfizz_purchase" );
    {}
    {}
}
function cp_sync_manifest_on_spawn( params )
{
    if ( isplayer( self ) && level.zombie_perks_in_use )
    {
        self thread cp_sync_manifest_to_client();
    }
}
function cp_sync_manifest_to_client()
{
    self thread cp_send_classic_prices();
    self notify( "cp_manifest_sync_restart" );
    self endon( "cp_manifest_sync_restart" );
    self endon( #"disconnect" );
    level endon( #"game_ended" );
    attempts = 0;
    while ( !isdefined( level.cp_client_manifest ) && attempts < 300 )
    {
        wait 0.1;
        attempts++;
    }
    if ( !isdefined( level.cp_client_manifest ) )
    {
        return;
    }
    for ( resend = 0; resend < 3; resend++ )
    {
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_registered_perks", level.cp_client_manifest );
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_perk_manifest_ready", "1" );
        self thread cp_refresh_owner_hud();
        wait 1;
    }
}
function cp_gold_on_spawn( params )
{
    if ( isplayer( self ) && level.zombie_perks_in_use )
    {
        self cp_gold_open_sync();
    }
}
function cp_gold_open_sync()
{
    if ( isdefined( self.cp_gold_major ) )
    {
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_gold_pick_ack", "accepted:" + self.cp_picks["gautys_gold"] );
    }
    else
    {
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_gold_pick_ack", "pending" );
    }
}
function cp_receive_gold_pick( channel, value )
{
    if ( !isdefined( channel ) || ( channel != "perk_choice_purchase" && channel != "custom_perk_choice_purchase" ) || !isplayer( self ) || !isdefined( value ) )
    {
        return;
    }
    {}
    if ( value == 4000 || ( isstring( value ) && value == "4000" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["gautys_gold"] = 0;
        self.cp_gold_major = 0;
        self.cp_gold_minor = 0;
        self.cp_gold_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_gold_pick_ack", "accepted:0" );
        {}
        return;
    }
    if ( value == 4001 || ( isstring( value ) && value == "4001" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["gautys_gold"] = 1;
        self.cp_gold_major = 0;
        self.cp_gold_minor = 1;
        self.cp_gold_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_gold_pick_ack", "accepted:1" );
        {}
        return;
    }
    if ( value == 4010 || ( isstring( value ) && value == "4010" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["gautys_gold"] = 10;
        self.cp_gold_major = 1;
        self.cp_gold_minor = 0;
        self.cp_gold_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_gold_pick_ack", "accepted:10" );
        {}
        return;
    }
    if ( value == 4011 || ( isstring( value ) && value == "4011" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["gautys_gold"] = 11;
        self.cp_gold_major = 1;
        self.cp_gold_minor = 1;
        self.cp_gold_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_gold_pick_ack", "accepted:11" );
        {}
        return;
    }
    if ( value == 4020 || ( isstring( value ) && value == "4020" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["gautys_gold"] = 20;
        self.cp_gold_major = 2;
        self.cp_gold_minor = 0;
        self.cp_gold_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_gold_pick_ack", "accepted:20" );
        {}
        return;
    }
    if ( value == 4021 || ( isstring( value ) && value == "4021" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["gautys_gold"] = 21;
        self.cp_gold_major = 2;
        self.cp_gold_minor = 1;
        self.cp_gold_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_gold_pick_ack", "accepted:21" );
        {}
        return;
    }
    if ( value == 4100 || ( isstring( value ) && value == "4100" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["gautys_gold"] = 100;
        self.cp_gold_major = 0;
        self.cp_gold_minor = 0;
        self.cp_gold_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_gold_pick_ack", "accepted:100" );
        {}
        return;
    }
    if ( value == 4110 || ( isstring( value ) && value == "4110" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["gautys_gold"] = 110;
        self.cp_gold_major = 1;
        self.cp_gold_minor = 0;
        self.cp_gold_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_gold_pick_ack", "accepted:110" );
        {}
        return;
    }
    if ( value == 4120 || ( isstring( value ) && value == "4120" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["gautys_gold"] = 120;
        self.cp_gold_major = 2;
        self.cp_gold_minor = 0;
        self.cp_gold_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_gold_pick_ack", "accepted:120" );
        {}
        return;
    }
    {}
}
function cp_get_pick( player, id )
{
    if ( isplayer( player ) && isdefined( player.cp_picks ) && isdefined( player.cp_picks[id] ) )
    {
        return player.cp_picks[id];
    }
    return 0;
}
function cp_receive_vitality_pick( channel, value )
{
    if ( !isplayer( self ) || !isdefined( value ) || ( channel != "perk_choice_purchase" && channel != "custom_perk_choice_purchase" ) )
    {
        return;
    }
    if ( value == 5000 || ( isstring( value ) && value == "5000" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 0;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:0" );
        {}
        return;
    }
    if ( value == 5001 || ( isstring( value ) && value == "5001" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 1;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 1;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:1" );
        {}
        return;
    }
    if ( value == 5002 || ( isstring( value ) && value == "5002" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 2;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 2;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:2" );
        {}
        return;
    }
    if ( value == 5010 || ( isstring( value ) && value == "5010" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 10;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:10" );
        {}
        return;
    }
    if ( value == 5011 || ( isstring( value ) && value == "5011" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 11;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 1;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:11" );
        {}
        return;
    }
    if ( value == 5012 || ( isstring( value ) && value == "5012" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 12;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 2;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:12" );
        {}
        return;
    }
    if ( value == 5020 || ( isstring( value ) && value == "5020" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 20;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:20" );
        {}
        return;
    }
    if ( value == 5021 || ( isstring( value ) && value == "5021" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 21;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 1;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:21" );
        {}
        return;
    }
    if ( value == 5022 || ( isstring( value ) && value == "5022" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 22;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 2;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:22" );
        {}
        return;
    }
    if ( value == 5100 || ( isstring( value ) && value == "5100" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 100;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:100" );
        {}
        return;
    }
    if ( value == 5102 || ( isstring( value ) && value == "5102" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 102;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 2;
        self.cp_vitality_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:102" );
        {}
        return;
    }
    if ( value == 5110 || ( isstring( value ) && value == "5110" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 110;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:110" );
        {}
        return;
    }
    if ( value == 5112 || ( isstring( value ) && value == "5112" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 112;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 2;
        self.cp_vitality_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:112" );
        {}
        return;
    }
    if ( value == 5120 || ( isstring( value ) && value == "5120" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 120;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:120" );
        {}
        return;
    }
    if ( value == 5122 || ( isstring( value ) && value == "5122" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 122;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 2;
        self.cp_vitality_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:122" );
        {}
        return;
    }
    if ( value == 5200 || ( isstring( value ) && value == "5200" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 200;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:200" );
        {}
        return;
    }
    if ( value == 5201 || ( isstring( value ) && value == "5201" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 201;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 1;
        self.cp_vitality_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:201" );
        {}
        return;
    }
    if ( value == 5210 || ( isstring( value ) && value == "5210" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 210;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:210" );
        {}
        return;
    }
    if ( value == 5211 || ( isstring( value ) && value == "5211" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 211;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 1;
        self.cp_vitality_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:211" );
        {}
        return;
    }
    if ( value == 5220 || ( isstring( value ) && value == "5220" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 220;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:220" );
        {}
        return;
    }
    if ( value == 5221 || ( isstring( value ) && value == "5221" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["vitality"] = 221;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 1;
        self.cp_vitality_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:221" );
        {}
        return;
    }
}
function cp_receive_electric_cherry_pick( channel, value )
{
    if ( !isplayer( self ) || !isdefined( value ) || ( channel != "perk_choice_purchase" && channel != "custom_perk_choice_purchase" ) )
    {
        return;
    }
    if ( value == 6000 || ( isstring( value ) && value == "6000" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 0;
        self.cp_electric_cherry_major = 0;
        self.cp_electric_cherry_minor = 0;
        self.cp_electric_cherry_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:0" );
        {}
        return;
    }
    if ( value == 6001 || ( isstring( value ) && value == "6001" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 1;
        self.cp_electric_cherry_major = 0;
        self.cp_electric_cherry_minor = 1;
        self.cp_electric_cherry_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:1" );
        {}
        return;
    }
    if ( value == 6002 || ( isstring( value ) && value == "6002" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 2;
        self.cp_electric_cherry_major = 0;
        self.cp_electric_cherry_minor = 2;
        self.cp_electric_cherry_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:2" );
        {}
        return;
    }
    if ( value == 6003 || ( isstring( value ) && value == "6003" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 3;
        self.cp_electric_cherry_major = 0;
        self.cp_electric_cherry_minor = 3;
        self.cp_electric_cherry_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:3" );
        {}
        return;
    }
    if ( value == 6010 || ( isstring( value ) && value == "6010" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 10;
        self.cp_electric_cherry_major = 1;
        self.cp_electric_cherry_minor = 0;
        self.cp_electric_cherry_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:10" );
        {}
        return;
    }
    if ( value == 6011 || ( isstring( value ) && value == "6011" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 11;
        self.cp_electric_cherry_major = 1;
        self.cp_electric_cherry_minor = 1;
        self.cp_electric_cherry_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:11" );
        {}
        return;
    }
    if ( value == 6012 || ( isstring( value ) && value == "6012" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 12;
        self.cp_electric_cherry_major = 1;
        self.cp_electric_cherry_minor = 2;
        self.cp_electric_cherry_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:12" );
        {}
        return;
    }
    if ( value == 6013 || ( isstring( value ) && value == "6013" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 13;
        self.cp_electric_cherry_major = 1;
        self.cp_electric_cherry_minor = 3;
        self.cp_electric_cherry_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:13" );
        {}
        return;
    }
    if ( value == 6020 || ( isstring( value ) && value == "6020" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 20;
        self.cp_electric_cherry_major = 2;
        self.cp_electric_cherry_minor = 0;
        self.cp_electric_cherry_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:20" );
        {}
        return;
    }
    if ( value == 6021 || ( isstring( value ) && value == "6021" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 21;
        self.cp_electric_cherry_major = 2;
        self.cp_electric_cherry_minor = 1;
        self.cp_electric_cherry_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:21" );
        {}
        return;
    }
    if ( value == 6022 || ( isstring( value ) && value == "6022" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 22;
        self.cp_electric_cherry_major = 2;
        self.cp_electric_cherry_minor = 2;
        self.cp_electric_cherry_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:22" );
        {}
        return;
    }
    if ( value == 6023 || ( isstring( value ) && value == "6023" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 23;
        self.cp_electric_cherry_major = 2;
        self.cp_electric_cherry_minor = 3;
        self.cp_electric_cherry_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:23" );
        {}
        return;
    }
    if ( value == 6100 || ( isstring( value ) && value == "6100" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 100;
        self.cp_electric_cherry_major = 0;
        self.cp_electric_cherry_minor = 0;
        self.cp_electric_cherry_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:100" );
        {}
        return;
    }
    if ( value == 6102 || ( isstring( value ) && value == "6102" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 102;
        self.cp_electric_cherry_major = 0;
        self.cp_electric_cherry_minor = 2;
        self.cp_electric_cherry_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:102" );
        {}
        return;
    }
    if ( value == 6103 || ( isstring( value ) && value == "6103" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 103;
        self.cp_electric_cherry_major = 0;
        self.cp_electric_cherry_minor = 3;
        self.cp_electric_cherry_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:103" );
        {}
        return;
    }
    if ( value == 6110 || ( isstring( value ) && value == "6110" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 110;
        self.cp_electric_cherry_major = 1;
        self.cp_electric_cherry_minor = 0;
        self.cp_electric_cherry_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:110" );
        {}
        return;
    }
    if ( value == 6112 || ( isstring( value ) && value == "6112" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 112;
        self.cp_electric_cherry_major = 1;
        self.cp_electric_cherry_minor = 2;
        self.cp_electric_cherry_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:112" );
        {}
        return;
    }
    if ( value == 6113 || ( isstring( value ) && value == "6113" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 113;
        self.cp_electric_cherry_major = 1;
        self.cp_electric_cherry_minor = 3;
        self.cp_electric_cherry_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:113" );
        {}
        return;
    }
    if ( value == 6120 || ( isstring( value ) && value == "6120" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 120;
        self.cp_electric_cherry_major = 2;
        self.cp_electric_cherry_minor = 0;
        self.cp_electric_cherry_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:120" );
        {}
        return;
    }
    if ( value == 6122 || ( isstring( value ) && value == "6122" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 122;
        self.cp_electric_cherry_major = 2;
        self.cp_electric_cherry_minor = 2;
        self.cp_electric_cherry_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:122" );
        {}
        return;
    }
    if ( value == 6123 || ( isstring( value ) && value == "6123" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 123;
        self.cp_electric_cherry_major = 2;
        self.cp_electric_cherry_minor = 3;
        self.cp_electric_cherry_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:123" );
        {}
        return;
    }
    if ( value == 6200 || ( isstring( value ) && value == "6200" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 200;
        self.cp_electric_cherry_major = 0;
        self.cp_electric_cherry_minor = 0;
        self.cp_electric_cherry_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:200" );
        {}
        return;
    }
    if ( value == 6201 || ( isstring( value ) && value == "6201" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 201;
        self.cp_electric_cherry_major = 0;
        self.cp_electric_cherry_minor = 1;
        self.cp_electric_cherry_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:201" );
        {}
        return;
    }
    if ( value == 6203 || ( isstring( value ) && value == "6203" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 203;
        self.cp_electric_cherry_major = 0;
        self.cp_electric_cherry_minor = 3;
        self.cp_electric_cherry_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:203" );
        {}
        return;
    }
    if ( value == 6210 || ( isstring( value ) && value == "6210" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 210;
        self.cp_electric_cherry_major = 1;
        self.cp_electric_cherry_minor = 0;
        self.cp_electric_cherry_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:210" );
        {}
        return;
    }
    if ( value == 6211 || ( isstring( value ) && value == "6211" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 211;
        self.cp_electric_cherry_major = 1;
        self.cp_electric_cherry_minor = 1;
        self.cp_electric_cherry_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:211" );
        {}
        return;
    }
    if ( value == 6213 || ( isstring( value ) && value == "6213" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 213;
        self.cp_electric_cherry_major = 1;
        self.cp_electric_cherry_minor = 3;
        self.cp_electric_cherry_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:213" );
        {}
        return;
    }
    if ( value == 6220 || ( isstring( value ) && value == "6220" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 220;
        self.cp_electric_cherry_major = 2;
        self.cp_electric_cherry_minor = 0;
        self.cp_electric_cherry_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:220" );
        {}
        return;
    }
    if ( value == 6221 || ( isstring( value ) && value == "6221" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 221;
        self.cp_electric_cherry_major = 2;
        self.cp_electric_cherry_minor = 1;
        self.cp_electric_cherry_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:221" );
        {}
        return;
    }
    if ( value == 6223 || ( isstring( value ) && value == "6223" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 223;
        self.cp_electric_cherry_major = 2;
        self.cp_electric_cherry_minor = 3;
        self.cp_electric_cherry_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:223" );
        {}
        return;
    }
    if ( value == 6300 || ( isstring( value ) && value == "6300" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 300;
        self.cp_electric_cherry_major = 0;
        self.cp_electric_cherry_minor = 0;
        self.cp_electric_cherry_bonus = 3;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:300" );
        {}
        return;
    }
    if ( value == 6301 || ( isstring( value ) && value == "6301" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 301;
        self.cp_electric_cherry_major = 0;
        self.cp_electric_cherry_minor = 1;
        self.cp_electric_cherry_bonus = 3;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:301" );
        {}
        return;
    }
    if ( value == 6302 || ( isstring( value ) && value == "6302" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 302;
        self.cp_electric_cherry_major = 0;
        self.cp_electric_cherry_minor = 2;
        self.cp_electric_cherry_bonus = 3;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:302" );
        {}
        return;
    }
    if ( value == 6310 || ( isstring( value ) && value == "6310" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 310;
        self.cp_electric_cherry_major = 1;
        self.cp_electric_cherry_minor = 0;
        self.cp_electric_cherry_bonus = 3;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:310" );
        {}
        return;
    }
    if ( value == 6311 || ( isstring( value ) && value == "6311" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 311;
        self.cp_electric_cherry_major = 1;
        self.cp_electric_cherry_minor = 1;
        self.cp_electric_cherry_bonus = 3;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:311" );
        {}
        return;
    }
    if ( value == 6312 || ( isstring( value ) && value == "6312" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 312;
        self.cp_electric_cherry_major = 1;
        self.cp_electric_cherry_minor = 2;
        self.cp_electric_cherry_bonus = 3;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:312" );
        {}
        return;
    }
    if ( value == 6320 || ( isstring( value ) && value == "6320" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 320;
        self.cp_electric_cherry_major = 2;
        self.cp_electric_cherry_minor = 0;
        self.cp_electric_cherry_bonus = 3;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:320" );
        {}
        return;
    }
    if ( value == 6321 || ( isstring( value ) && value == "6321" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 321;
        self.cp_electric_cherry_major = 2;
        self.cp_electric_cherry_minor = 1;
        self.cp_electric_cherry_bonus = 3;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:321" );
        {}
        return;
    }
    if ( value == 6322 || ( isstring( value ) && value == "6322" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["electric_cherry"] = 322;
        self.cp_electric_cherry_major = 2;
        self.cp_electric_cherry_minor = 2;
        self.cp_electric_cherry_bonus = 3;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_electric_cherry_pick_ack", "accepted:322" );
        {}
        return;
    }
}
function cp_receive_tortoise_pick( channel, value )
{
    if ( !isplayer( self ) || !isdefined( value ) || ( channel != "perk_choice_purchase" && channel != "custom_perk_choice_purchase" ) )
    {
        return;
    }
    if ( value == 7000 || ( isstring( value ) && value == "7000" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["tortoise"] = 0;
        self.cp_tortoise_major = 0;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_tortoise_pick_ack", "accepted:0" );
        {}
        return;
    }
    if ( value == 7001 || ( isstring( value ) && value == "7001" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["tortoise"] = 1;
        self.cp_tortoise_major = 0;
        self.cp_tortoise_minor = 1;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_tortoise_pick_ack", "accepted:1" );
        {}
        return;
    }
    if ( value == 7010 || ( isstring( value ) && value == "7010" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["tortoise"] = 10;
        self.cp_tortoise_major = 1;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_tortoise_pick_ack", "accepted:10" );
        {}
        return;
    }
    if ( value == 7011 || ( isstring( value ) && value == "7011" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["tortoise"] = 11;
        self.cp_tortoise_major = 1;
        self.cp_tortoise_minor = 1;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_tortoise_pick_ack", "accepted:11" );
        {}
        return;
    }
    if ( value == 7020 || ( isstring( value ) && value == "7020" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["tortoise"] = 20;
        self.cp_tortoise_major = 2;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_tortoise_pick_ack", "accepted:20" );
        {}
        return;
    }
    if ( value == 7021 || ( isstring( value ) && value == "7021" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["tortoise"] = 21;
        self.cp_tortoise_major = 2;
        self.cp_tortoise_minor = 1;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_tortoise_pick_ack", "accepted:21" );
        {}
        return;
    }
    if ( value == 7100 || ( isstring( value ) && value == "7100" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["tortoise"] = 100;
        self.cp_tortoise_major = 0;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_tortoise_pick_ack", "accepted:100" );
        {}
        return;
    }
    if ( value == 7110 || ( isstring( value ) && value == "7110" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["tortoise"] = 110;
        self.cp_tortoise_major = 1;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_tortoise_pick_ack", "accepted:110" );
        {}
        return;
    }
    if ( value == 7120 || ( isstring( value ) && value == "7120" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["tortoise"] = 120;
        self.cp_tortoise_major = 2;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_tortoise_pick_ack", "accepted:120" );
        {}
        return;
    }
}
function cp_receive_bandolier_pick( channel, value )
{
    if ( !isplayer( self ) || !isdefined( value ) || ( channel != "perk_choice_purchase" && channel != "custom_perk_choice_purchase" ) )
    {
        return;
    }
    if ( value == 8000 || ( isstring( value ) && value == "8000" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 0;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:0" );
        {}
        return;
    }
    if ( value == 8001 || ( isstring( value ) && value == "8001" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 1;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 1;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:1" );
        {}
        return;
    }
    if ( value == 8002 || ( isstring( value ) && value == "8002" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 2;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 2;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:2" );
        {}
        return;
    }
    if ( value == 8010 || ( isstring( value ) && value == "8010" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 10;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:10" );
        {}
        return;
    }
    if ( value == 8011 || ( isstring( value ) && value == "8011" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 11;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 1;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:11" );
        {}
        return;
    }
    if ( value == 8012 || ( isstring( value ) && value == "8012" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 12;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 2;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:12" );
        {}
        return;
    }
    if ( value == 8020 || ( isstring( value ) && value == "8020" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 20;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:20" );
        {}
        return;
    }
    if ( value == 8021 || ( isstring( value ) && value == "8021" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 21;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 1;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:21" );
        {}
        return;
    }
    if ( value == 8022 || ( isstring( value ) && value == "8022" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 22;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 2;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:22" );
        {}
        return;
    }
    if ( value == 8100 || ( isstring( value ) && value == "8100" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 100;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:100" );
        {}
        return;
    }
    if ( value == 8102 || ( isstring( value ) && value == "8102" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 102;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 2;
        self.cp_bandolier_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:102" );
        {}
        return;
    }
    if ( value == 8110 || ( isstring( value ) && value == "8110" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 110;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:110" );
        {}
        return;
    }
    if ( value == 8112 || ( isstring( value ) && value == "8112" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 112;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 2;
        self.cp_bandolier_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:112" );
        {}
        return;
    }
    if ( value == 8120 || ( isstring( value ) && value == "8120" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 120;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:120" );
        {}
        return;
    }
    if ( value == 8122 || ( isstring( value ) && value == "8122" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 122;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 2;
        self.cp_bandolier_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:122" );
        {}
        return;
    }
    if ( value == 8200 || ( isstring( value ) && value == "8200" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 200;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:200" );
        {}
        return;
    }
    if ( value == 8201 || ( isstring( value ) && value == "8201" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 201;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 1;
        self.cp_bandolier_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:201" );
        {}
        return;
    }
    if ( value == 8210 || ( isstring( value ) && value == "8210" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 210;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:210" );
        {}
        return;
    }
    if ( value == 8211 || ( isstring( value ) && value == "8211" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 211;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 1;
        self.cp_bandolier_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:211" );
        {}
        return;
    }
    if ( value == 8220 || ( isstring( value ) && value == "8220" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 220;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:220" );
        {}
        return;
    }
    if ( value == 8221 || ( isstring( value ) && value == "8221" ) )
    {
        if ( !isdefined( self.cp_picks ) )
        {
            self.cp_picks = [];
        }
        self.cp_picks["bandolier"] = 221;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 1;
        self.cp_bandolier_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:221" );
        {}
        return;
    }
}
function cp_hud_snapshot_watch()
{
    level endon( #"game_ended" );
    level utility::flag_wait_all( "StartGameTypeCallbackFinished", "zombie_perks_init_complete" );
    {}
    while ( true )
    {
        foreach ( player in level.players )
        {
            if ( isdefined( player ) && isplayer( player ) )
            {
                player cp_publish_slot_perks();
            }
        }
        wait 0.5;
    }
}
function cp_publish_slot_perks()
{
    hud_slot = -1;
    if ( isdefined( self.cp_hud_slot ) )
    {
        hud_slot = self.cp_hud_slot;
    }
    if ( hud_slot > 3 )
    {
        {}
        return;
    }
    refs = [];
    if ( isdefined( self.perks_active ) )
    {
        foreach ( ref in self.perks_active )
        {
            if ( isdefined( ref ) && ref != "specialty_choice" && !arraycontains( refs, ref ) )
            {
                refs[ refs.size ] = ref;
            }
        }
    }
    if ( isdefined( self.a_perks ) )
    {
        foreach ( ref, active in self.a_perks )
        {
            if ( isdefined( active ) && ref != "specialty_choice" && !arraycontains( refs, ref ) )
            {
                refs[ refs.size ] = ref;
            }
        }
    }
    snapshot = "slot=" + hud_slot + ";v1:";
    delimiter = "";
    foreach ( ref in refs )
    {
        snapshot = snapshot + delimiter + ref;
        delimiter = ",";
    }
    snapshot = snapshot + ";eternal:";
    delimiter = "";
    if (isdefined(self.perma_perks))
    {
        foreach (ref in refs)
        {
            if ( arraycontains( self.perma_perks, ref ) || ( isstring( ref ) && arraycontains( self.perma_perks, getxhash( ref ) ) ) )
            {
                snapshot = snapshot + delimiter + ref;
                delimiter = ",";
            }
        }
    }
    cherry_charge = 100;
    if (isdefined(self.ec_ready_at) && gettime() < self.ec_ready_at)
    {
        cherry_charge = 0;
        charge_duration = self.ec_charge_duration ?? 15000;
        if (charge_duration > 0) cherry_charge = int(100 * (1 - (self.ec_ready_at - gettime()) / charge_duration));
        if (cherry_charge < 0) cherry_charge = 0;
        if (cherry_charge > 100) cherry_charge = 100;
    }
    snapshot = snapshot + ";cherry_pct:" + cherry_charge;
    hunter_charge = 100;
    if (isdefined(self.hm_ready_at) && gettime() < self.hm_ready_at)
    {
        hunter_duration = self.hm_charge_duration ?? 20000;
        hunter_charge = 0;
        if (hunter_duration > 0) hunter_charge = int(100 * (1 - (self.hm_ready_at - gettime()) / hunter_duration));
        if (hunter_charge < 0) hunter_charge = 0;
        if (hunter_charge > 100) hunter_charge = 100;
    }
    snapshot = snapshot + ";hunter_pct:" + hunter_charge;
    widow_charge = 100;
    if (isdefined(self.var_aac6a355ba29b499) && isdefined(self.ymodcooldowntime))
    {
        widow_duration = self.ymodcooldowntime * 1000;
        if (self utility::callsharedfunc(#"zombie", #"hash_3930894d8d2f0ee6", "specialty_y_mod", #"y_mod_haste"))
        {
            reduction = (level.zombie_augments[#"y_mod_haste"].var_fbc7d2a7afe49740 ?? 5) * 1000;
            widow_duration = clamp(widow_duration - reduction, 1, self.ymodcooldowntime * 1000);
        }
        if (widow_duration > 0) widow_charge = int(100 * (gettime() - self.var_aac6a355ba29b499) / widow_duration);
        if (widow_charge < 0) widow_charge = 0;
        if (widow_charge > 100) widow_charge = 100;
    }
    snapshot = snapshot + ";widow_pct:" + widow_charge;
    self.cp_banana_pct = 100;
    if (gettime() < (self.bc_next_trail ?? 0))
        self.cp_banana_pct = int(clamp(100 * (1 - (self.bc_next_trail - gettime()) / (self.bc_cooldown ?? 15000)), 0, 100));
    self.cp_wolf_pct = 0;
    if (gettime() < (self.bw_ready_at ?? 0))
        self.cp_wolf_pct = int(clamp(100 * (1 - (self.bw_ready_at - gettime()) / (self.bw_cooldown_duration ?? 45000)), 0, 100));
    else if (gettime() <= (self.bw_window_end ?? 0) && (self.bw_goal ?? 0) > 0)
        self.cp_wolf_pct = int(clamp(100 * (self.bw_meter ?? 0) / self.bw_goal, 0, 100));
    snapshot = snapshot + ";banana_pct:" + self.cp_banana_pct + ";wolf_pct:" + self.cp_wolf_pct;
    if ( isdefined( self.cp_hud_watch_snapshot ) && self.cp_hud_watch_snapshot == snapshot )
    {
        return;
    }
    self.cp_hud_watch_snapshot = snapshot;
    self cp_send_hud_omnvars( refs, cherry_charge, hunter_charge, widow_charge );
    if ( hud_slot == 0 )
    {
        setdvar( @"bo7_cp_hud_slot_0", snapshot );
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_hud_slot_0", snapshot );
    }
    if ( hud_slot == 1 )
    {
        setdvar( @"bo7_cp_hud_slot_1", snapshot );
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_hud_slot_1", snapshot );
    }
    if ( hud_slot == 2 )
    {
        setdvar( @"bo7_cp_hud_slot_2", snapshot );
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_hud_slot_2", snapshot );
    }
    if ( hud_slot == 3 )
    {
        setdvar( @"bo7_cp_hud_slot_3", snapshot );
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_hud_slot_3", snapshot );
    }
    {}
}
function cp_send_hud_omnvars( refs, cherry_charge, hunter_charge, widow_charge )
{
    level.cp_hud_page_count = int( ( 14 + level.cp_defs.size + 11 ) / 12 );
    self.cp_hud_pages = [];
    for ( page = 0; page < level.cp_hud_page_count; page++ )
    {
        self.cp_hud_pages[ page ] = 0;
        self.cp_hud_pages[ 12 + page ] = 0;
    }
    foreach ( ref in refs )
    {
        self.cp_hud_index = cp_hud_perk_index( ref );
        if ( self.cp_hud_index < 0 )
        {
            continue;
        }
        self.cp_hud_page = int( self.cp_hud_index / 12 );
        self.cp_hud_bit = cp_pow2( self.cp_hud_index - self.cp_hud_page * 12 );
        self.cp_hud_pages[ self.cp_hud_page ] = self.cp_hud_pages[ self.cp_hud_page ] + self.cp_hud_bit;
        if ( isdefined( self.perma_perks ) && ( arraycontains( self.perma_perks, ref ) || ( isstring( ref ) && arraycontains( self.perma_perks, getxhash( ref ) ) ) ) )
        {
            self.cp_hud_pages[ 12 + self.cp_hud_page ] = self.cp_hud_pages[ 12 + self.cp_hud_page ] + self.cp_hud_bit;
        }
    }
    self setclientomnvar("ui_br_objective_index", int(self.cp_banana_pct * 14 / 100) * 15 + int(self.cp_wolf_pct * 14 / 100));
    self setclientomnvar( "ui_br_assassination_target", int( cherry_charge * 11 / 100 ) * 144 + int( hunter_charge * 11 / 100 ) * 12 + int( widow_charge * 11 / 100 ) );
}
function cp_hud_page_cycle()
{
    level endon( #"game_ended" );
    while ( true )
    {
        wait 0.05;
        foreach ( player in level.players )
        {
            if ( !isdefined( player ) || !isdefined( player.cp_hud_pages ) )
            {
                continue;
            }
            if ( !isdefined( player.cp_hud_page_i ) || player.cp_hud_page_i + 1 > level.cp_hud_page_count * 2 + 3 )
            {
                player.cp_hud_page_i = 0;
            }
            else
            {
                player.cp_hud_page_i = player.cp_hud_page_i + 1;
            }
            // Pages 21 / 22: slot machine interface state and last spin (zm_cp_slot_machine.gsc).
            if ( player.cp_hud_page_i == level.cp_hud_page_count * 2 + 2 )
            {
                player setclientomnvar( "ui_br_objective_param", 22 * 4096 + int( clamp( player.slot_hud ?? 0, 0, 4095 ) ) );
                continue;
            }
            if ( player.cp_hud_page_i == level.cp_hud_page_count * 2 + 3 )
            {
                player setclientomnvar( "ui_br_objective_param", 21 * 4096 + int( clamp( player.slot_ui ?? 0, 0, 4095 ) ) );
                continue;
            }
            if ( player.cp_hud_page_i == level.cp_hud_page_count * 2 + 1 )
            {
                player setclientomnvar( "ui_br_objective_param", 23 * 4096 + int( clamp( player.ss_pct ?? 0, 0, 100 ) ) );
                continue;
            }
            if ( player.cp_hud_page_i == level.cp_hud_page_count * 2 )
            {
                player.cp_ww_ui = 0;
                if ( gettime() < ( player.ww_ui_until ?? 0 ) ) player.cp_ww_ui = player.ww_ui ?? 0;
                if ( player.cp_ww_ui >= 2 ) player.cp_ww_ui = 2 + int( clamp( player.cp_ww_ui - 2, 0, 100 ) * 9 / 100 );
                player.cp_bar = player.kka_pct ?? 0;
                player.cp_ghost = 0;
                if ( istrue( player.ww_ghost ) )
                {
                    player.cp_bar = player.ww_left_pct ?? 0;
                    player.cp_ghost = 1;
                }
                player setclientomnvar( "ui_br_objective_param", 24 * 4096 + int( clamp( player.cp_bar, 0, 100 ) / 2 ) * 24 + player.cp_ghost * 12 + player.cp_ww_ui );
                continue;
            }
            player.cp_hud_page_key = player.cp_hud_page_i;
            if ( player.cp_hud_page_key >= level.cp_hud_page_count )
            {
                player.cp_hud_page_key = 12 + player.cp_hud_page_key - level.cp_hud_page_count;
            }
            player setclientomnvar( "ui_br_objective_param", player.cp_hud_page_key * 4096 + player.cp_hud_pages[ player.cp_hud_page_key ] );
        }
    }
}
function cp_hud_perk_index( ref )
{
    if ( !isstring( ref ) )
    {
        return -1;
    }
    if ( isdefined( level.cp_custom_refs[ ref ] ) )
    {
        return 14 + cp_perk_rank( level.cp_custom_refs[ ref ] );
    }
    if ( !isdefined( level.cp_hud_native_order ) )
    {
        level.cp_hud_native_order = [ "specialty_juggernog", "specialty_quickrevive", "specialty_speedcola", "specialty_staminup",
            "specialty_deadshot", "specialty_elemental_pop", "specialty_phd_flopper", "specialty_death_perception",
            "specialty_vulture_aid", "specialty_m_mod", "specialty_d_mod", "specialty_w_mod", "specialty_y_mod",
            "specialty_z_mod" ];
    }
    level.cp_hud_native_i = 0;
    foreach ( known in level.cp_hud_native_order )
    {
        if ( known == ref )
        {
            return level.cp_hud_native_i;
        }
        level.cp_hud_native_i = level.cp_hud_native_i + 1;
    }
    return -1;
}
function cp_pow2( n )
{
    level.cp_pow2 = 1;
    for ( i = 0; i < n; i++ )
    {
        level.cp_pow2 = level.cp_pow2 * 2;
    }
    return level.cp_pow2;
}
// BEGIN GENERATED COOP bandolier
// @coop_sync bandolier 8000
function cp_receive_generated_bandolier( channel, value )
{
    if ( !isplayer( self ) || !isdefined( value ) || ( channel != "perk_choice_purchase" && channel != "custom_perk_choice_purchase" ) ) return false;
    if ( value == 8000 || ( isstring( value ) && value == "8000" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 0;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:0" );
        {}
        return true;
    }
    if ( value == 8001 || ( isstring( value ) && value == "8001" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 1;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 1;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:1" );
        {}
        return true;
    }
    if ( value == 8002 || ( isstring( value ) && value == "8002" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 2;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 2;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:2" );
        {}
        return true;
    }
    if ( value == 8010 || ( isstring( value ) && value == "8010" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 10;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:10" );
        {}
        return true;
    }
    if ( value == 8011 || ( isstring( value ) && value == "8011" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 11;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 1;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:11" );
        {}
        return true;
    }
    if ( value == 8012 || ( isstring( value ) && value == "8012" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 12;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 2;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:12" );
        {}
        return true;
    }
    if ( value == 8020 || ( isstring( value ) && value == "8020" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 20;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:20" );
        {}
        return true;
    }
    if ( value == 8021 || ( isstring( value ) && value == "8021" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 21;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 1;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:21" );
        {}
        return true;
    }
    if ( value == 8022 || ( isstring( value ) && value == "8022" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 22;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 2;
        self.cp_bandolier_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:22" );
        {}
        return true;
    }
    if ( value == 8100 || ( isstring( value ) && value == "8100" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 100;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:100" );
        {}
        return true;
    }
    if ( value == 8102 || ( isstring( value ) && value == "8102" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 102;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 2;
        self.cp_bandolier_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:102" );
        {}
        return true;
    }
    if ( value == 8110 || ( isstring( value ) && value == "8110" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 110;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:110" );
        {}
        return true;
    }
    if ( value == 8112 || ( isstring( value ) && value == "8112" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 112;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 2;
        self.cp_bandolier_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:112" );
        {}
        return true;
    }
    if ( value == 8120 || ( isstring( value ) && value == "8120" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 120;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:120" );
        {}
        return true;
    }
    if ( value == 8122 || ( isstring( value ) && value == "8122" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 122;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 2;
        self.cp_bandolier_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:122" );
        {}
        return true;
    }
    if ( value == 8200 || ( isstring( value ) && value == "8200" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 200;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:200" );
        {}
        return true;
    }
    if ( value == 8201 || ( isstring( value ) && value == "8201" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 201;
        self.cp_bandolier_major = 0;
        self.cp_bandolier_minor = 1;
        self.cp_bandolier_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:201" );
        {}
        return true;
    }
    if ( value == 8210 || ( isstring( value ) && value == "8210" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 210;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:210" );
        {}
        return true;
    }
    if ( value == 8211 || ( isstring( value ) && value == "8211" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 211;
        self.cp_bandolier_major = 1;
        self.cp_bandolier_minor = 1;
        self.cp_bandolier_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:211" );
        {}
        return true;
    }
    if ( value == 8220 || ( isstring( value ) && value == "8220" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 220;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 0;
        self.cp_bandolier_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:220" );
        {}
        return true;
    }
    if ( value == 8221 || ( isstring( value ) && value == "8221" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["bandolier"] = 221;
        self.cp_bandolier_major = 2;
        self.cp_bandolier_minor = 1;
        self.cp_bandolier_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_bandolier_pick_ack", "accepted:221" );
        {}
        return true;
    }
    return false;
}
// END GENERATED COOP bandolier
// BEGIN GENERATED COOP gautys_gold
// @coop_sync gautys_gold 4000 (generic decode: any major/minor/bonus)
function cp_receive_generated_gautys_gold(channel, value)
{
    self cp_decode_pick( channel, value, 4000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["gautys_gold"] = self.cp_dec_pick;
    self.cp_gold_major = self.cp_dec_major;
    self.cp_gold_minor = self.cp_dec_minor;
    self.cp_gold_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_gold_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP gautys_gold
// BEGIN GENERATED COOP tortoise
// @coop_sync tortoise 7000
function cp_receive_generated_tortoise(channel, value)
{
    if (!isplayer(self) || !isdefined(value) || (channel != "perk_choice_purchase" && channel != "custom_perk_choice_purchase")) return false;
    if (value == 7000 || (isstring(value) && value == "7000"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 0;
        self.cp_tortoise_major = 0;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:0");
        return true;
    }
    if (value == 7001 || (isstring(value) && value == "7001"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 1;
        self.cp_tortoise_major = 0;
        self.cp_tortoise_minor = 1;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:1");
        return true;
    }
    if (value == 7002 || (isstring(value) && value == "7002"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 2;
        self.cp_tortoise_major = 0;
        self.cp_tortoise_minor = 2;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:2");
        return true;
    }
    if (value == 7010 || (isstring(value) && value == "7010"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 10;
        self.cp_tortoise_major = 1;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:10");
        return true;
    }
    if (value == 7011 || (isstring(value) && value == "7011"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 11;
        self.cp_tortoise_major = 1;
        self.cp_tortoise_minor = 1;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:11");
        return true;
    }
    if (value == 7012 || (isstring(value) && value == "7012"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 12;
        self.cp_tortoise_major = 1;
        self.cp_tortoise_minor = 2;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:12");
        return true;
    }
    if (value == 7020 || (isstring(value) && value == "7020"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 20;
        self.cp_tortoise_major = 2;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:20");
        return true;
    }
    if (value == 7021 || (isstring(value) && value == "7021"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 21;
        self.cp_tortoise_major = 2;
        self.cp_tortoise_minor = 1;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:21");
        return true;
    }
    if (value == 7022 || (isstring(value) && value == "7022"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 22;
        self.cp_tortoise_major = 2;
        self.cp_tortoise_minor = 2;
        self.cp_tortoise_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:22");
        return true;
    }
    if (value == 7100 || (isstring(value) && value == "7100"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 100;
        self.cp_tortoise_major = 0;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:100");
        return true;
    }
    if (value == 7102 || (isstring(value) && value == "7102"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 102;
        self.cp_tortoise_major = 0;
        self.cp_tortoise_minor = 2;
        self.cp_tortoise_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:102");
        return true;
    }
    if (value == 7110 || (isstring(value) && value == "7110"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 110;
        self.cp_tortoise_major = 1;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:110");
        return true;
    }
    if (value == 7112 || (isstring(value) && value == "7112"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 112;
        self.cp_tortoise_major = 1;
        self.cp_tortoise_minor = 2;
        self.cp_tortoise_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:112");
        return true;
    }
    if (value == 7120 || (isstring(value) && value == "7120"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 120;
        self.cp_tortoise_major = 2;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:120");
        return true;
    }
    if (value == 7122 || (isstring(value) && value == "7122"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 122;
        self.cp_tortoise_major = 2;
        self.cp_tortoise_minor = 2;
        self.cp_tortoise_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:122");
        return true;
    }
    if (value == 7200 || (isstring(value) && value == "7200"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 200;
        self.cp_tortoise_major = 0;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:200");
        return true;
    }
    if (value == 7201 || (isstring(value) && value == "7201"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 201;
        self.cp_tortoise_major = 0;
        self.cp_tortoise_minor = 1;
        self.cp_tortoise_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:201");
        return true;
    }
    if (value == 7210 || (isstring(value) && value == "7210"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 210;
        self.cp_tortoise_major = 1;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:210");
        return true;
    }
    if (value == 7211 || (isstring(value) && value == "7211"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 211;
        self.cp_tortoise_major = 1;
        self.cp_tortoise_minor = 1;
        self.cp_tortoise_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:211");
        return true;
    }
    if (value == 7220 || (isstring(value) && value == "7220"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 220;
        self.cp_tortoise_major = 2;
        self.cp_tortoise_minor = 0;
        self.cp_tortoise_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:220");
        return true;
    }
    if (value == 7221 || (isstring(value) && value == "7221"))
    {
        if (!isdefined(self.cp_picks)) self.cp_picks = [];
        self.cp_picks["tortoise"] = 221;
        self.cp_tortoise_major = 2;
        self.cp_tortoise_minor = 1;
        self.cp_tortoise_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_tortoise_pick_ack", "accepted:221");
        return true;
    }
    return false;
}
// END GENERATED COOP tortoise
// BEGIN GENERATED COOP vitality
// @coop_sync vitality 5000
function cp_receive_generated_vitality( channel, value )
{
    if ( !isplayer( self ) || !isdefined( value ) || ( channel != "perk_choice_purchase" && channel != "custom_perk_choice_purchase" ) ) return false;
    if ( value == 5000 || ( isstring( value ) && value == "5000" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 0;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:0" );
        {}
        return true;
    }
    if ( value == 5001 || ( isstring( value ) && value == "5001" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 1;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 1;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:1" );
        {}
        return true;
    }
    if ( value == 5002 || ( isstring( value ) && value == "5002" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 2;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 2;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:2" );
        {}
        return true;
    }
    if ( value == 5010 || ( isstring( value ) && value == "5010" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 10;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:10" );
        {}
        return true;
    }
    if ( value == 5011 || ( isstring( value ) && value == "5011" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 11;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 1;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:11" );
        {}
        return true;
    }
    if ( value == 5012 || ( isstring( value ) && value == "5012" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 12;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 2;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:12" );
        {}
        return true;
    }
    if ( value == 5020 || ( isstring( value ) && value == "5020" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 20;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:20" );
        {}
        return true;
    }
    if ( value == 5021 || ( isstring( value ) && value == "5021" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 21;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 1;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:21" );
        {}
        return true;
    }
    if ( value == 5022 || ( isstring( value ) && value == "5022" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 22;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 2;
        self.cp_vitality_bonus = 0;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:22" );
        {}
        return true;
    }
    if ( value == 5100 || ( isstring( value ) && value == "5100" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 100;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:100" );
        {}
        return true;
    }
    if ( value == 5102 || ( isstring( value ) && value == "5102" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 102;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 2;
        self.cp_vitality_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:102" );
        {}
        return true;
    }
    if ( value == 5110 || ( isstring( value ) && value == "5110" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 110;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:110" );
        {}
        return true;
    }
    if ( value == 5112 || ( isstring( value ) && value == "5112" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 112;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 2;
        self.cp_vitality_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:112" );
        {}
        return true;
    }
    if ( value == 5120 || ( isstring( value ) && value == "5120" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 120;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:120" );
        {}
        return true;
    }
    if ( value == 5122 || ( isstring( value ) && value == "5122" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 122;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 2;
        self.cp_vitality_bonus = 1;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:122" );
        {}
        return true;
    }
    if ( value == 5200 || ( isstring( value ) && value == "5200" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 200;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:200" );
        {}
        return true;
    }
    if ( value == 5201 || ( isstring( value ) && value == "5201" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 201;
        self.cp_vitality_major = 0;
        self.cp_vitality_minor = 1;
        self.cp_vitality_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:201" );
        {}
        return true;
    }
    if ( value == 5210 || ( isstring( value ) && value == "5210" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 210;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:210" );
        {}
        return true;
    }
    if ( value == 5211 || ( isstring( value ) && value == "5211" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 211;
        self.cp_vitality_major = 1;
        self.cp_vitality_minor = 1;
        self.cp_vitality_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:211" );
        {}
        return true;
    }
    if ( value == 5220 || ( isstring( value ) && value == "5220" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 220;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 0;
        self.cp_vitality_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:220" );
        {}
        return true;
    }
    if ( value == 5221 || ( isstring( value ) && value == "5221" ) )
    {
        if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
        self.cp_picks["vitality"] = 221;
        self.cp_vitality_major = 2;
        self.cp_vitality_minor = 1;
        self.cp_vitality_bonus = 2;
        self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_vitality_pick_ack", "accepted:221" );
        {}
        return true;
    }
    return false;
}
// END GENERATED COOP vitality
function cp_native_toggle_init()
{
    level endon(#"game_ended");
    level.cp_disabled_native = [];
    if (getdvarint(@"bo7_cp_off_native_juggernog", 0) == 1) level.cp_disabled_native["specialty_juggernog"] = true;
    if (getdvarint(@"bo7_cp_off_native_quick_revive", 0) == 1) level.cp_disabled_native["specialty_quickrevive"] = true;
    if (getdvarint(@"bo7_cp_off_native_speedcola", 0) == 1) level.cp_disabled_native["specialty_speedcola"] = true;
    if (getdvarint(@"bo7_cp_off_native_staminup", 0) == 1) level.cp_disabled_native["specialty_staminup"] = true;
    if (getdvarint(@"bo7_cp_off_native_deadshot", 0) == 1) level.cp_disabled_native["specialty_deadshot"] = true;
    if (getdvarint(@"bo7_cp_off_native_elemental_pop", 0) == 1) level.cp_disabled_native["specialty_elemental_pop"] = true;
    if (getdvarint(@"bo7_cp_off_native_phd_flopper", 0) == 1) level.cp_disabled_native["specialty_phd_flopper"] = true;
    if (getdvarint(@"bo7_cp_off_native_death_perception", 0) == 1) level.cp_disabled_native["specialty_death_perception"] = true;
    if (getdvarint(@"bo7_cp_off_native_vulture_aid", 0) == 1) level.cp_disabled_native["specialty_vulture_aid"] = true;
    if (getdvarint(@"bo7_cp_off_native_m_mod", 0) == 1) level.cp_disabled_native["specialty_m_mod"] = true;
    if (getdvarint(@"bo7_cp_off_native_d_mod", 0) == 1) level.cp_disabled_native["specialty_d_mod"] = true;
    if (getdvarint(@"bo7_cp_off_native_w_mod", 0) == 1) level.cp_disabled_native["specialty_w_mod"] = true;
    if (getdvarint(@"bo7_cp_off_native_y_mod", 0) == 1) level.cp_disabled_native["specialty_y_mod"] = true;
    if (getdvarint(@"bo7_cp_off_native_z_mod", 0) == 1) level.cp_disabled_native["specialty_z_mod"] = true;
    level utility::flag_wait_all("StartGameTypeCallbackFinished", "zombie_perks_init_complete");
    if (level.cp_disabled_native.size == 0) return;
    level thread cp_native_toggle_hide_machines();
    level callback::add("zm_perk_obtained", &cp_native_toggle_obtained);
    level callback::add("currency_sub", &cp_native_toggle_refund);
    while (true)
    {
        foreach (player in level.players)
        {
            foreach (ref, disabled in level.cp_disabled_native)
            {
                if (isdefined(player))
                {
                    if (!isdefined(player.disallow_zombie_perks)) player.disallow_zombie_perks = [];
                    if (!arraycontains(player.disallow_zombie_perks, ref)) player.disallow_zombie_perks[player.disallow_zombie_perks.size] = ref;
                }
                if (isdefined(player) && isalive(player) && player zombie_perks::has_perk(ref))
                    player thread cp_native_toggle_remove(ref);
            }
        }
        wait 0.25;
    }
}
function cp_native_toggle_hide_machines()
{
    level endon(#"game_ended");
    level utility::flag_wait("perk_machines_ready");
    wait 2;
    if (!isdefined(level.a_s_perk_machines))
    {
        cp_native_toggle_unregister();
        return;
    }
    level.cp_hidden_machines = "";
    level.cp_seen_machines = "";
    foreach (machine in level.a_s_perk_machines)
    {
        if (!isdefined(machine) || !isdefined(machine.mdl_perk_machine)) continue;
        level.cp_seen_machines = level.cp_seen_machines + " [" + machine.script_noteworthy + "/" + machine.mdl_perk_machine.model + "/" + machine.mdl_perk_machine.scriptablename + "]";
        foreach (ref, disabled in level.cp_disabled_native)
        {
            if ((isdefined(machine.script_noteworthy) && (machine.script_noteworthy == ref || machine.script_noteworthy == getxhash(ref)))
                || (isdefined(level._custom_perks[ref]) && isdefined(level._custom_perks[ref].str_scriptable)
                    && ((isdefined(machine.mdl_perk_machine.model) && issubstr("" + machine.mdl_perk_machine.model, "" + level._custom_perks[ref].str_scriptable))
                        || (isdefined(machine.mdl_perk_machine.scriptablename) && machine.mdl_perk_machine.scriptablename == level._custom_perks[ref].str_scriptable))))
            {
                machine.mdl_perk_machine.origin = machine.mdl_perk_machine.origin - (0, 0, 10000);
                if (isdefined(machine.mdl_perk_machine.interact) && isent(machine.mdl_perk_machine.interact))
                    machine.mdl_perk_machine.interact.origin = machine.mdl_perk_machine.origin;
                level.cp_hidden_machines = level.cp_hidden_machines + " " + ref;
            }
        }
    }
    setdvar(@"bo7_cp_machine_runtime", "stock machines hidden (switched off):" + level.cp_hidden_machines + " | map machines:" + level.cp_seen_machines);
    cp_native_toggle_unregister();
}
function cp_native_toggle_unregister()
{
    level.cp_removed_perks = [];
    foreach (ref, disabled in level.cp_disabled_native)
    {
        if (isdefined(level._custom_perks[ref]))
        {
            level.cp_removed_perks[ref] = level._custom_perks[ref];
            level._custom_perks[ref] = undefined;
        }
    }
    setdvar(@"bo7_cp_machine_runtime", "switched-off perks removed from the perk list: " + level.cp_removed_perks.size);
}
function cp_native_toggle_obtained(params)
{
    if (!isplayer(self) || !isdefined(params.specialtyperk)) return;
    foreach (ref, disabled in level.cp_disabled_native)
    {
        if (params.specialtyperk == ref || params.specialtyperk == getxhash(ref))
        {
            self thread cp_native_toggle_remove(ref);
            return;
        }
    }
}
function cp_native_toggle_remove(ref)
{
    self endon(#"disconnect");
    level endon(#"game_ended");
    if (!isdefined(self.cp_native_removing)) self.cp_native_removing = [];
    if (istrue(self.cp_native_removing[ref])) return;
    self.cp_native_removing[ref] = true;
    waitframe();
    if (self zombie_perks::has_perk(ref)) self zombie_perks::take_perk(ref);
    self.cp_native_removing[ref] = false;
}
function cp_native_toggle_refund(params)
{
    if (!isplayer(self) || !isdefined(params.amount) || params.amount <= 0 || !isdefined(params.info)) return;
    foreach (ref, disabled in level.cp_disabled_native)
    {
        if (params.info == ref || params.info == getxhash(ref))
        {
            self currency::add_currency_amount(params.currencytype, params.amount, #"disabled_perk_refund", ref);
            return;
        }
    }
}
function cp_decode_pick( channel, value, base )
{
    self.cp_dec_ok = false;
    if ( !isplayer( self ) || !isdefined( value ) || ( channel != "perk_choice_purchase" && channel != "custom_perk_choice_purchase" ) ) return;
    if ( isstring( value ) ) self.cp_dec_v = int( value );
    else self.cp_dec_v = value;
    if ( !isdefined( self.cp_dec_v ) || self.cp_dec_v < base || self.cp_dec_v >= base + 1000 ) return;
    self.cp_dec_pick = self.cp_dec_v - base;
    self.cp_dec_bonus = int( self.cp_dec_pick / 100 );
    self.cp_dec_major = int( self.cp_dec_pick / 10 ) % 10;
    self.cp_dec_minor = self.cp_dec_pick % 10;
    self.cp_dec_ok = true;
    if ( !isdefined( self.cp_picks ) ) self.cp_picks = [];
}
// BEGIN GENERATED COOP jug2
// @coop_sync jug2 10000 (generic decode: any major/minor/bonus)
function cp_receive_generated_jug2( channel, value )
{
    self cp_decode_pick( channel, value, 10000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["jug2"] = self.cp_dec_pick;
    self.cp_jug2_major = self.cp_dec_major;
    if (self.cp_jug2_major == 4) self.cp_jug2_major = 0;
    self.cp_jug2_minor = self.cp_dec_minor;
    self.cp_jug2_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_jug2_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP jug2
// BEGIN GENERATED COOP blaze_phase
// @coop_sync blaze_phase 12000 (generic decode: any major/minor/bonus)
function cp_receive_generated_blaze_phase( channel, value )
{
    self cp_decode_pick( channel, value, 12000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["blaze_phase"] = self.cp_dec_pick;
    self.cp_blaze_phase_major = self.cp_dec_major;
    self.cp_blaze_phase_minor = self.cp_dec_minor;
    self.cp_blaze_phase_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_blaze_phase_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP blaze_phase
// BEGIN GENERATED COOP magnet_margarita
// @coop_sync magnet_margarita 13000 (generic decode: any major/minor/bonus)
function cp_receive_generated_magnet_margarita( channel, value )
{
    self cp_decode_pick( channel, value, 13000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["magnet_margarita"] = self.cp_dec_pick;
    self.cp_magnet_margarita_major = self.cp_dec_major;
    self.cp_magnet_margarita_minor = self.cp_dec_minor;
    self.cp_magnet_margarita_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_magnet_margarita_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP magnet_margarita
// BEGIN GENERATED COOP banana_colada
// @coop_sync banana_colada 14000 (generic decode: any major/minor/bonus)
function cp_receive_generated_banana_colada( channel, value )
{
    self cp_decode_pick( channel, value, 14000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["banana_colada"] = self.cp_dec_pick;
    self.cp_banana_colada_major = self.cp_dec_major;
    self.cp_banana_colada_minor = self.cp_dec_minor;
    self.cp_banana_colada_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_banana_colada_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP banana_colada
// BEGIN GENERATED COOP dam_a_nade
// @coop_sync dam_a_nade 15000 (generic decode: any major/minor/bonus)
function cp_receive_generated_dam_a_nade( channel, value )
{
    self cp_decode_pick( channel, value, 15000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["dam_a_nade"] = self.cp_dec_pick;
    self.cp_dam_a_nade_major = self.cp_dec_major;
    self.cp_dam_a_nade_minor = self.cp_dec_minor;
    self.cp_dam_a_nade_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_dam_a_nade_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP dam_a_nade
// BEGIN GENERATED COOP pack_a_box
// @coop_sync pack_a_box 16000 (generic decode: any major/minor/bonus)
function cp_receive_generated_pack_a_box( channel, value )
{
    self cp_decode_pick( channel, value, 16000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["pack_a_box"] = self.cp_dec_pick;
    self.cp_pack_a_box_major = self.cp_dec_major;
    self.cp_pack_a_box_minor = self.cp_dec_minor;
    self.cp_pack_a_box_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_pack_a_box_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP pack_a_box
// BEGIN GENERATED COOP blood_wolf_bite
// @coop_sync blood_wolf_bite 17000 (generic decode: any major/minor/bonus)
function cp_receive_generated_blood_wolf_bite( channel, value )
{
    self cp_decode_pick( channel, value, 17000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["blood_wolf_bite"] = self.cp_dec_pick;
    self.cp_blood_wolf_bite_major = self.cp_dec_major;
    self.cp_blood_wolf_bite_minor = self.cp_dec_minor;
    self.cp_blood_wolf_bite_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_blood_wolf_bite_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP blood_wolf_bite
// BEGIN GENERATED COOP bull_ice_blast
// @coop_sync bull_ice_blast 18000 (generic decode: any major/minor/bonus)
function cp_receive_generated_bull_ice_blast( channel, value )
{
    self cp_decode_pick( channel, value, 18000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["bull_ice_blast"] = self.cp_dec_pick;
    self.cp_bull_ice_blast_major = self.cp_dec_major;
    self.cp_bull_ice_blast_minor = self.cp_dec_minor;
    self.cp_bull_ice_blast_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_bull_ice_blast_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP bull_ice_blast
// BEGIN GENERATED COOP axe_shot
// @coop_sync axe_shot 19000 (generic decode: any major/minor/bonus)
function cp_receive_generated_axe_shot( channel, value )
{
    self cp_decode_pick( channel, value, 19000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["axe_shot"] = self.cp_dec_pick;
    self.cp_axe_shot_major = self.cp_dec_major;
    self.cp_axe_shot_minor = self.cp_dec_minor;
    self.cp_axe_shot_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_axe_shot_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP axe_shot
// BEGIN GENERATED COOP killstreak_kool_aid
// @coop_sync killstreak_kool_aid 20000 (generic decode: any major/minor/bonus)
function cp_receive_generated_killstreak_kool_aid( channel, value )
{
    self cp_decode_pick( channel, value, 20000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["killstreak_kool_aid"] = self.cp_dec_pick;
    self.cp_killstreak_kool_aid_major = self.cp_dec_major;
    self.cp_killstreak_kool_aid_minor = self.cp_dec_minor;
    self.cp_killstreak_kool_aid_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_killstreak_kool_aid_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP killstreak_kool_aid
// BEGIN GENERATED COOP whos_who
// @coop_sync whos_who 22000 (generic decode: any major/minor/bonus; 21000-21999 belongs to Ring of Fire)
function cp_receive_generated_whos_who( channel, value )
{
    self cp_decode_pick( channel, value, 22000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["whos_who"] = self.cp_dec_pick;
    self.cp_whos_who_major = self.cp_dec_major;
    self.cp_whos_who_minor = self.cp_dec_minor;
    self.cp_whos_who_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_whos_who_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP whos_who
// BEGIN GENERATED COOP hunters_mark
// @coop_sync hunters_mark 11000 (generic decode: any major/minor/bonus)
function cp_receive_generated_hunters_mark( channel, value )
{
    self cp_decode_pick( channel, value, 11000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["hunters_mark"] = self.cp_dec_pick;
    self.cp_hunters_mark_major = self.cp_dec_major;
    self.cp_hunters_mark_minor = self.cp_dec_minor;
    self.cp_hunters_mark_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_hunters_mark_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP hunters_mark
// BEGIN GENERATED COOP electric_cherry
// @coop_sync electric_cherry 6000 (generic decode: any major/minor/bonus)
function cp_receive_generated_electric_cherry( channel, value )
{
    self cp_decode_pick( channel, value, 6000 );
    if ( !self.cp_dec_ok ) return false;
    self.cp_picks["electric_cherry"] = self.cp_dec_pick;
    self.cp_electric_cherry_major = self.cp_dec_major;
    self.cp_electric_cherry_minor = self.cp_dec_minor;
    self.cp_electric_cherry_bonus = self.cp_dec_bonus;
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_electric_cherry_pick_ack", "accepted:" + self.cp_dec_pick);
    return true;
}
// END GENERATED COOP electric_cherry
function cp_machine_spots()
{
    // Ashes: Gauty's Gold's old spot ( 25013.5, -84.999, 422.078 ) is now the slot machine (zm_cp_slot_machine.gsc).
    cp_machine_add( "zm_sat_firefly", "jug2", ( 13771.5, -4100.54, 411.801 ), 135.198, "specialty_staminup" );
    cp_machine_add( "zm_sat_firefly", "bandolier", ( 1925, -809.003, 508 ), -0.196381, "specialty_speedcola" );
    cp_machine_add( "zm_sat_firefly", "electric_cherry", ( -11503.9, 3635.85, 644 ), -143.02, "specialty_quickrevive" );
    cp_machine_add( "zm_sat_firefly", "tortoise", ( -8053.31, -6880.66, 1640 ), 143.259, "specialty_deadshot" );
    cp_machine_add( "zm_sat_firefly", "hunters_mark", ( 13559.7, 2587.27, 1056 ), -10.5747, "specialty_death_perception" );
    // Ashes, marked spots (2026-11-19). Gauty's Gold always goes in a map's starting room.
    cp_machine_add( "zm_sat_firefly", "gautys_gold", ( 24769, 680, 415 ), -90, "specialty_phd_flopper" );
    cp_machine_add( "zm_sat_firefly", "blood_wolf_bite", ( -8072, -5611, 1336 ), -127, "specialty_juggernog" );
    cp_machine_add( "zm_sat_firefly", "samurais_sake", ( -9184, -6444, 1640 ), -35, "specialty_speedcola" );
    cp_machine_add( "zm_sat_firefly", "whos_who", ( -13433, 4707, 416 ), -40, "specialty_quickrevive" );
    cp_machine_add( "zm_sat_firefly", "magnet_margarita", ( -11479, 3737, 419 ), 40, "specialty_staminup" );
    cp_machine_add( "zm_sat_firefly", "killstreak_kool_aid", ( 3447, -3564, 491 ), 2, "specialty_deadshot" );
    cp_machine_add( "zm_sat_firefly", "dam_a_nade", ( 3667, -2004, -289 ), 41, "specialty_death_perception" );
    cp_machine_add( "zm_sat_firefly", "twin_spirit", ( 14328, 2488, 902 ), -29, "specialty_phd_flopper" );
    // Ashes, marked spots (2026-11-20), same machine models as on Astra Malorum. Bull Ice Blast still needs a spot.
    cp_machine_add( "zm_sat_firefly", "vitality", ( 13463, 2613, 1184 ), -100, "specialty_juggernog" );
    cp_machine_add( "zm_sat_firefly", "blaze_phase", ( 13433, 1829, 1056 ), 33, "specialty_speedcola" );
    cp_machine_add( "zm_sat_firefly", "nuka_cola", ( 3494, -826, -222 ), -143, "specialty_quickrevive" );
    cp_machine_add( "zm_sat_firefly", "pack_a_box", ( 2647, -2052, 178 ), 38, "specialty_staminup" );
    cp_machine_add( "zm_sat_firefly", "banana_colada", ( -8000, -6302, 1336 ), 142, "specialty_deadshot" );
    // Astra Malorum. Machine models the map doesn't load fall back to the Juggernog machine.
    cp_machine_add( "zm_sat_ruby", "gautys_gold", ( -1593, 115, 193 ), 153, "specialty_phd_flopper" );
    cp_machine_add( "zm_sat_ruby", "vitality", ( -862, 1229, 246 ), -178, "specialty_juggernog" );
    cp_machine_add( "zm_sat_ruby", "blaze_phase", ( -52, 924, 250 ), 101, "specialty_speedcola" );
    cp_machine_add( "zm_sat_ruby", "nuka_cola", ( 1680, 1177, 252 ), 140, "specialty_quickrevive" );
    cp_machine_add( "zm_sat_ruby", "pack_a_box", ( 3732, -1758, 16 ), 82, "specialty_staminup" );
    cp_machine_add( "zm_sat_ruby", "banana_colada", ( 2164, -2841, 8 ), -1, "specialty_deadshot" );
    cp_machine_add( "zm_sat_ruby", "bull_ice_blast", ( 1116, -3681, 200 ), 90, "specialty_elemental_pop" );
    // Astra Malorum, marked spots (2026-11-20), same machine models as on Ashes. Mark 8 ( 1407, 954, 252 ) left out on purpose.
    cp_machine_add( "zm_sat_ruby", "jug2", ( -1003, -37, 258 ), 138, "specialty_staminup" );
    cp_machine_add( "zm_sat_ruby", "bandolier", ( 201, -900, 255 ), 96, "specialty_speedcola" );
    cp_machine_add( "zm_sat_ruby", "electric_cherry", ( 2627, -1043, 7 ), 156, "specialty_quickrevive" );
    cp_machine_add( "zm_sat_ruby", "tortoise", ( 4872, -1791, 16 ), 171, "specialty_deadshot" );
    cp_machine_add( "zm_sat_ruby", "hunters_mark", ( 4162, -2593, 0 ), 145, "specialty_death_perception" );
    cp_machine_add( "zm_sat_ruby", "blood_wolf_bite", ( 659, -2598, 72 ), -14, "specialty_juggernog" );
    cp_machine_add( "zm_sat_ruby", "samurais_sake", ( 234, -2373, 200 ), 176, "specialty_speedcola" );
    // Who's Who: was floating at ( 3084, 901, -38 ); lowered and moved 20 units back (against its facing).
    cp_machine_add( "zm_sat_ruby", "whos_who", ( 3103, 894, -54 ), 160, "specialty_quickrevive" );
    cp_machine_add( "zm_sat_ruby", "magnet_margarita", ( 4849, -41518, -13025 ), -179, "specialty_staminup" );
    // Moved 20 units back (against its facing) from ( 4988, -42706, -12995 ).
    cp_machine_add( "zm_sat_ruby", "killstreak_kool_aid", ( 4988, -42726, -12995 ), 90, "specialty_deadshot" );
    cp_machine_add( "zm_sat_ruby", "dam_a_nade", ( 3390, -41672, -13025 ), -6, "specialty_death_perception" );
    cp_machine_add( "zm_sat_ruby", "twin_spirit", ( 4015, -40593, -12595 ), 1, "specialty_phd_flopper" );
}
function cp_machine_delay()
{
    return 16;
}
function cp_machine_use_radius()
{
    return 90;
}
function cp_machine_say( str_text )
{
    {}
    setdvar( @"bo7_cp_machine_runtime", str_text );
}
function cp_machine_add( str_map, str_id, v_origin, n_yaw, str_model )
{
    if ( "" + level.mapname != str_map )
    {
        return;
    }
    level.cp_machine_origin[ str_id ] = v_origin;
    level.cp_machine_angles[ str_id ] = ( 0, n_yaw, 0 );
    level.cp_machine_model_ref[ str_id ] = str_model;
}
function cp_machine_model_for( str_id )
{
    if ( !isdefined( level.cp_machine_model_ref[ str_id ] ) )
    {
        return level.cp_machine_model;
    }
    if ( isdefined( level._custom_perks[ level.cp_machine_model_ref[ str_id ] ] ) && isdefined( level._custom_perks[ level.cp_machine_model_ref[ str_id ] ].str_scriptable ) )
    {
        return level._custom_perks[ level.cp_machine_model_ref[ str_id ] ].str_scriptable;
    }
    if ( isdefined( level.a_s_perk_machines ) )
    {
        foreach ( machine in level.a_s_perk_machines )
        {
            if ( isdefined( machine ) && isdefined( machine.script_noteworthy ) && ( machine.script_noteworthy == level.cp_machine_model_ref[ str_id ] || machine.script_noteworthy == getxhash( level.cp_machine_model_ref[ str_id ] ) ) && isdefined( machine.mdl_perk_machine ) && !isent( machine.mdl_perk_machine ) && isdefined( machine.mdl_perk_machine.scriptablename ) )
            {
                return machine.mdl_perk_machine.scriptablename;
            }
        }
    }
    if ( issubstr( level.cp_machine_model_ref[ str_id ], "specialty_" ) )
    {
        level.cp_machine_fallback[ str_id ] = true;
        return level.cp_machine_model;
    }
    return level.cp_machine_model_ref[ str_id ];
}
function cp_machine_on_spawn( params )
{
    if ( !isplayer( self ) || isdefined( level.cp_machines_started ) )
    {
        return;
    }
    level.cp_machines_started = true;
    level thread cp_machine_spawn_later();
}
function cp_machine_spawn_later()
{
    level endon( #"game_ended" );
    if ( getdvarint( @"bo7_cp_off_machines", 0 ) == 1 )
    {
        {}
        return;
    }
    wait cp_machine_delay();
    while ( !istrue( level.cp_custom_perks_ready ) )
    {
        wait 0.5;
    }
    level.cp_machine_origin = [];
    level.cp_machine_angles = [];
    level.cp_machine_model_ref = [];
    level.cp_machine_fallback = [];
    level.cp_machine_ent = [];
    cp_machine_spots();
    level.cp_machine_model = "t10_zm_machine_juggernog";
    if ( isdefined( level._custom_perks ) && isdefined( level._custom_perks[ "specialty_juggernog" ] ) && isdefined( level._custom_perks[ "specialty_juggernog" ].str_scriptable ) )
    {
        level.cp_machine_model = level._custom_perks[ "specialty_juggernog" ].str_scriptable;
    }
    level.cp_machine_report = "map " + level.mapname + ":";
    foreach ( id, v_spot in level.cp_machine_origin )
    {
        if ( !isdefined( level.cp_defs[ id ] ) || !istrue( level.cp_registered_perks[ id ] ) )
        {
            level.cp_machine_report = level.cp_machine_report + " " + id + "=not_registered";
            continue;
        }
        level.cp_machine_ent[ id ] = spawnscriptable( cp_machine_model_for( id ), level.cp_machine_origin[ id ], level.cp_machine_angles[ id ] );
        if ( isdefined( level.cp_machine_ent[ id ] ) )
        {
            if ( level.cp_machine_ent[ id ] getscriptablehaspart( "base" ) && level.cp_machine_ent[ id ] getscriptableparthasstate( "base", "power_activate" ) )
                level.cp_machine_ent[ id ] setscriptablepartstate( "base", "power_activate" );
            if ( level.cp_machine_ent[ id ] getscriptablehaspart( "icon" ) && level.cp_machine_ent[ id ] getscriptableparthasstate( "icon", "active" ) )
                level.cp_machine_ent[ id ] setscriptablepartstate( "icon", "active" );
            if ( level.cp_machine_ent[ id ] getscriptablehaspart( "use" ) && level.cp_machine_ent[ id ] getscriptableparthasstate( "use", "default" ) )
                level.cp_machine_ent[ id ] setscriptablepartstate( "use", "default" );
        }
        level.cp_machine_report = level.cp_machine_report + " " + id + "=" + isdefined( level.cp_machine_ent[ id ] ) + "(" + cp_machine_model_for( id ) + ( istrue( level.cp_machine_fallback[ id ] ) ? " FALLBACK: " + level.cp_machine_model_ref[ id ] + " not on this map" : "" ) + ")@" + level.cp_machine_origin[ id ][0] + "," + level.cp_machine_origin[ id ][1] + "," + level.cp_machine_origin[ id ][2];
    }
    level thread cp_machine_use_loop();
    {}
}
function cp_machine_currency()
{
    return currency::get_perk_machine_currency( "specialty_juggernog" );
}
function cp_machine_hint_state( str_id )
{
    self.cp_machine_can_buy = false;
    if ( !isdefined( str_id ) || !isalive( self ) || istrue( self.inlaststand ) )
    {
        return "";
    }
    self.cp_machine_cost = self cp_perk_cost( level.cp_defs[ str_id ][ "ref" ] );
    self.cp_machine_info = "|" + self.cp_machine_cost + "|" + level.cp_defs[ str_id ][ "icon_material" ] + "|" + level.cp_defs[ str_id ][ "name" ] + "|" + level.cp_defs[ str_id ][ "description" ];
    self.cp_machine_code = level.cp_defs[ str_id ][ "code" ] * 40000 + clamp( int( self.cp_machine_cost / 10 ), 0, 9999 );
    if ( self zombie_perks::has_perk( level.cp_defs[ str_id ][ "ref" ] ) )
    {
        self.cp_machine_code = self.cp_machine_code + 20000;
        return "owned" + self.cp_machine_info;
    }
    if ( self cp_at_perk_limit() )
    {
        return "";
    }
    if ( !self currency::can_afford( cp_machine_currency(), self.cp_machine_cost ) )
    {
        self.cp_machine_code = self.cp_machine_code + 30000;
        return "poor" + self.cp_machine_info;
    }
    self.cp_machine_can_buy = true;
    self.cp_machine_code = self.cp_machine_code + 10000;
    return "buy" + self.cp_machine_info;
}
function cp_machine_use_loop()
{
    level endon( #"game_ended" );
    while ( true )
    {
        wait 0.1;
        foreach ( e_player in level.players )
        {
            if ( !isdefined( e_player ) || isbot( e_player ) )
            {
                continue;
            }
            e_player.cp_machine_near = undefined;
            foreach ( id, v_spot in level.cp_machine_ent )
            {
                if ( distance( e_player.origin, level.cp_machine_origin[ id ] ) <= cp_machine_use_radius() )
                {
                    e_player.cp_machine_near = id;
                    break;
                }
            }
            e_player.cp_machine_hint_new = e_player cp_machine_hint_state( e_player.cp_machine_near );
            if ( !isdefined( e_player.cp_machine_hint ) || e_player.cp_machine_hint != e_player.cp_machine_hint_new )
            {
                e_player.cp_machine_hint = e_player.cp_machine_hint_new;
                e_player cp_machine_send_hint( e_player.cp_machine_hint );
            }
            e_player.cp_machine_use_was = istrue( e_player.cp_machine_use_held );
            e_player.cp_machine_use_held = e_player usebuttonpressed();
            if ( e_player.cp_machine_use_held && !e_player.cp_machine_use_was && istrue( e_player.cp_machine_can_buy ) )
            {
                if ( e_player cp_machine_try_purchase( e_player.cp_machine_near ) )
                {
                    e_player.cp_machine_hint = "";
                    e_player cp_machine_send_hint( "" );
                }
            }
        }
    }
}
function cp_machine_send_hint( str_state )
{
    if ( str_state == "" )
    {
        self.cp_machine_code = 0;
    }
    self setclientomnvar( "ui_br_objective_loot_id", self.cp_machine_code );
}
function cp_machine_try_purchase( str_id )
{
    if ( !isdefined( str_id ) || !isdefined( level.cp_defs[ str_id ] ) )
    {
        return false;
    }
    if ( self zombie_perks::has_perk( level.cp_defs[ str_id ][ "ref" ] ) || istrue( self.cp_machine_buying ) || self cp_at_perk_limit() )
    {
        return false;
    }
    self.cp_machine_cost = self cp_perk_cost( level.cp_defs[ str_id ][ "ref" ] );
    if ( !self currency::attempt_purchase( cp_machine_currency(), self.cp_machine_cost, 1, undefined, #"perk", level.cp_defs[ str_id ][ "ref" ] ) )
    {
        {}
        return false;
    }
    self.cp_machine_buying = true;
    if ( isdefined( level.cp_machine_ent[ str_id ] ) && level.cp_machine_ent[ str_id ] getscriptablehaspart( "use" ) && level.cp_machine_ent[ str_id ] getscriptableparthasstate( "use", "purchase" ) )
    {
        level.cp_machine_ent[ str_id ] setscriptablepartstate( "use", "purchase" );
        level.cp_machine_ent[ str_id ] thread cp_machine_reset_use_state();
    }
    self.cp_machine_gesture = 0;
    if ( !self isgestureplaying() && isdefined( level._custom_perks[ level.cp_defs[ str_id ][ "ref" ] ] ) && isdefined( level._custom_perks[ level.cp_defs[ str_id ][ "ref" ] ].perk_bottle_weapon ) )
    {
        self thread zombie_perks::play_perk_drinking_gesture( level._custom_perks[ level.cp_defs[ str_id ][ "ref" ] ].perk_bottle_weapon );
        self.cp_machine_gesture = 1;
    }
    zombie_perks::give_perk( level.cp_defs[ str_id ][ "ref" ], 1, self.cp_machine_gesture );
    self.cp_machine_buying = undefined;
    {}
    return true;
}
function cp_machine_reset_use_state()
{
    self endon( #"death" );
    wait 3;
    if ( self getscriptablehaspart( "use" ) && self getscriptableparthasstate( "use", "default" ) )
    {
        self setscriptablepartstate( "use", "default" );
    }
}
function cp_perkaholic_init()
{
    level endon( #"game_ended" );
    while ( !isdefined( level.bgb ) || !isdefined( level.bgb[ "perkaholic" ] ) || !isdefined( level.bgb[ "perkaholic" ].activation_func ) )
        wait 0.05;
    level.cp_perkaholic_activation = level.bgb[ "perkaholic" ].activation_func;
    level.bgb[ "perkaholic" ].activation_func = &cp_perkaholic_activate;
}
function cp_perkaholic_activate()
{
    self endon( #"disconnect" );
    if ( getdvarint( @"bo7_cp_perkaholic_classic", 0 ) != 1 )
    {
        self [[ level.cp_perkaholic_activation ]]();
        return;
    }
    foreach ( ref in getarraykeys( level._custom_perks ) )
    {
        if ( !val::get( "allow_zm_perks" ) || ref == "specialty_choice" || isdefined( level.cp_custom_refs[ ref ] ) || self zombie_perks::has_perk( ref ) )
            continue;
        self zombie_perks::give_perk( ref, 0 );
        waitframe();
    }
    self bgb::function_b62ba460d1b3dac9( "perkaholic" );
    waitframe();
}
function cp_classic_wf_pricing_init()
{
    level endon(#"game_ended");
    while (!isdefined(level.onluieventcallbackschannel)) waitframe();
    while (true)
    {
        level.gametypebundle.var_2137b6b66219eb66 = 0;
        level.cp_wf_channels = getarraykeys(level.onluieventcallbackschannel);
        for (level.cp_wf_ci = 0; level.cp_wf_ci < level.cp_wf_channels.size; level.cp_wf_ci++)
        {
            level.cp_wf_channel = level.cp_wf_channels[level.cp_wf_ci];
            for (level.cp_wf_i = 0; level.cp_wf_i < level.onluieventcallbackschannel[level.cp_wf_channel].size; level.cp_wf_i++)
            {
                if (level.onluieventcallbackschannel[level.cp_wf_channel][level.cp_wf_i] == &perk_machines::perk_choice_purchase)
                {
                    level.onluieventcallbackschannel[level.cp_wf_channel][level.cp_wf_i] = &cp_classic_native_wf_purchase;
                    {}
                }
            }
        }
        wait 0.5;
    }
}
function cp_classic_native_wf_purchase( channel, menuitemindex )
{
    if ( channel != "perk_choice_purchase" || !istrue( level.cp_classic_cost ) )
    {
        self perk_machines::perk_choice_purchase( channel, menuitemindex );
        return;
    }
    if ( !isdefined( menuitemindex ) || !isdefined( self.s_perk_choice_machine ) || !self val::get( "allow_zm_perks" ) ) return;
    item = purchasemenu::create_item_struct( #"wunderfizz", int( menuitemindex ) );
    if ( !isdefined( item ) || !isdefined( item.itemref ) || isdefined( level.cp_custom_refs[ item.itemref ] ) ) return;
    if ( !arraycontains( zombie_perks::get_perks_str_array(), item.itemref ) ) return;
    self purchase_custom_perk( item.itemref, item.itemref, item.currency );
}
function cp_send_classic_prices()
{
    self endon( #"disconnect" );
    level endon( #"game_ended" );
    while ( !isdefined( level.cp_classic_cost ) || !isdefined( level.cp_client_manifest ) ) wait 0.1;
    prices = "";
    page = 0;
    for ( i = 0; i < 8; i++ ) self quiet_zm_cp_custom_perks_client_dvar( "bo7_cp_wf_prices_" + i, "" );
    if ( level.cp_classic_cost )
    {
        foreach ( ref in getarraykeys( level._custom_perks ) )
        {
            cost = cp_classic_price( ref );
            if ( isdefined( cost ) )
            {
                entry = ref + ":" + cost + ";";
                if ( prices.size + entry.size > 700 && page < 7 )
                {
                    self quiet_zm_cp_custom_perks_client_dvar( "bo7_cp_wf_prices_" + page, prices );
                    page++;
                    prices = "";
                }
                prices += entry;
            }
        }
    }
    self quiet_zm_cp_custom_perks_client_dvar( "bo7_cp_wf_prices_" + page, prices );
    self quiet_zm_cp_custom_perks_client_dvar(@"bo7_cp_wf_classic_enabled", level.cp_classic_cost ? "1" : "0");
    self quiet_zm_cp_custom_perks_client_dvar( @"bo7_cp_wf_classic_prices", level.cp_classic_cost ? "v2" : "" );
}
function quiet_zm_cp_custom_perks_client_dvar(name, value)
{
    if (!isdefined(self.quiet_client_dvars)) { self.quiet_client_dvars=[]; self.quiet_client_dvar_times=[]; }
    if (isdefined(self.quiet_client_dvars[name]) && self.quiet_client_dvars[name] == value && gettime() < (self.quiet_client_dvar_times[name] ?? 0) + 10000) return;
    self.quiet_client_dvars[name]=value;
    self.quiet_client_dvar_times[name]=gettime();
    self setclientdvar(name,value);
}
