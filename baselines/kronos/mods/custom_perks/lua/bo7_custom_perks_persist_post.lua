local previous = rawget(_G, "BO7PerkPersist")
if previous then previous.enabled = false end
local S = { enabled = true, ticks = 0, loaded = false, values = {} }
rawset(_G, "BO7PerkPersist", S)
local STORE_DVAR, KEY = "kronos_bo6_var", "bo7cp"
local DVARS = {
    "bo7_cp_vitality_pick", "bo7_cp_bandolier_pick", "bo7_cp_tortoise_pick", "bo7_cp_gautys_gold_pick",
    "bo7_cp_off_vitality", "bo7_cp_off_bandolier", "bo7_cp_off_tortoise", "bo7_cp_off_gautys_gold",
    "bo7_cp_off_blaze_phase", "bo7_cp_off_native_juggernog", "bo7_cp_off_native_quick_revive",
    "bo7_cp_off_native_speedcola", "bo7_cp_off_native_staminup", "bo7_cp_off_native_deadshot",
    "bo7_cp_off_native_elemental_pop", "bo7_cp_off_native_phd_flopper", "bo7_cp_off_native_death_perception",
    "bo7_cp_off_native_vulture_aid", "bo7_cp_off_native_m_mod", "bo7_cp_off_native_d_mod", "bo7_cp_off_native_w_mod",
    "bo7_cp_off_native_y_mod", "bo7_cp_off_native_z_mod", "bo7_cp_eternal_frame_style", "bo7_cp_jug2_pick",
    "bo7_cp_off_jug2", "bo7_cp_hunters_mark_pick", "bo7_cp_off_hunters_mark", "bo7_cp_electric_cherry_pick",
    "bo7_cp_off_electric_cherry", "bo7_cp_off_machines",
    "bo7_cp_off_axe_shot", "bo7_cp_wunderfizz_round", "bo7_cp_blaze_phase_pick",
    "bo7_cp_off_nuka_cola", "bo7_cp_off_magnet_margarita", "bo7_cp_off_dam_a_nade", "bo7_cp_off_pack_a_box",
    "bo7_cp_off_blood_wolf_bite", "bo7_cp_off_bull_ice_blast",
    "bo7_cp_oc_frag", "bo7_cp_oc_semtex", "bo7_cp_oc_cluster", "bo7_cp_oc_molotov", "bo7_cp_oc_c4",
    "bo7_cp_oc_thermobaric", "bo7_cp_oc_axe", "bo7_cp_oc_stun", "bo7_cp_oc_decoy", "bo7_cp_oc_shockstick",
    "bo7_cp_oc_smoke", "bo7_cp_oc_gas",
    "bo7_cp_oc_monkey", "bo7_cp_oc_kazimir",
    "bo7_cp_oc_turret", "bo7_cp_oc_impact", "bo7_cp_oc_stim", "bo7_cp_oc_psych", "bo7_cp_oc_hunterbot",
    "bo7_cp_off_banana_colada", "bo7_cp_magnet_margarita_pick", "bo7_cp_banana_colada_pick",
    "bo7_cp_perk_limit",
    "bo7_cp_dam_a_nade_pick", "bo7_cp_pack_a_box_pick", "bo7_cp_blood_wolf_bite_pick", "bo7_cp_bull_ice_blast_pick",
    "bo7_cp_axe_shot_pick",
    "bo7_cp_classic_wunderfizz", "bo7_cp_classic_perk_cost",
    "bo7_cp_perkaholic_classic",
    "bo7_cp_off_killstreak_kool_aid", "bo7_cp_killstreak_kool_aid_pick",
    "bo7_cp_off_whos_who", "bo7_cp_whos_who_pick",
    "bo7_cp_off_samurais_sake",
    "bo7_cp_off_twin_spirit",
}
local INDEX = {}
for i, name in ipairs(DVARS) do INDEX[name] = i end
local function get(t, key)
    if t == nil then return nil end
    local ok, value = pcall(function() return t[key] end)
    if ok then return value end
end
local function log(...) end
local function hashOf(name)
    local f = rawget(_G, "xhashdvar") or get(rawget(_G, "CLUA"), "PushXHashDvar")
    if type(f) == "function" then local ok, h = pcall(f, name); if ok then return h end end
    return name
end
local function read(name)
    local f = get(rawget(_G, "Dvar"), "GetDvarString")
    if type(f) ~= "function" then return "" end
    local ok, v = pcall(f, hashOf(name))
    return ok and v ~= nil and tostring(v) or ""
end
local function writeStore(value)
    if read(STORE_DVAR) == value then return true end
    local f = get(rawget(_G, "Dvar"), "SetDvarString")
    if type(f) == "function" then pcall(f, hashOf(STORE_DVAR), value) end
    if read(STORE_DVAR) == value then return true end
    local exec = get(rawget(_G, "Engine"), "ExecNow")
    if type(exec) == "function" and not value:find("\"", 1, true) then
        pcall(exec, "set " .. STORE_DVAR .. " \"" .. value .. "\"\n", 0)
    end
    return read(STORE_DVAR) == value
end
local function clean(v) v = tostring(v or ""); return (v:match("^%d+$") and tonumber(v) <= 999) and v or "" end
local function pack(values)
    local out = {}
    for i = 1, #DVARS do local v = values[i] or ""; out[i] = v ~= "" and v or "-" end
    return table.concat(out, ".")
end
local function unpack(s)
    local values, i = {}, 0
    for v in (s .. "."):gmatch("([^.]*)%.") do i = i + 1; values[i] = clean(v ~= "-" and v or "") end
    return values
end
assert(pack(unpack("211..3-")) == "211.-.-" .. string.rep(".-", #DVARS - 3), "bo7cp pack/unpack")
assert(unpack(pack({ "5", "", "7" }))[3] == "7", "bo7cp keeps slots")
local function entry() return (";" .. read(STORE_DVAR)):match(";" .. KEY .. "=([^;]*)") end
local function writeEntry()
    local value = pack(S.values)
    if entry() == value then S.written = value; return true end
    local out = {}
    for e in read(STORE_DVAR):gmatch("[^;]+") do
        if e:match("^([^=]*)=") ~= KEY then out[#out + 1] = e end
    end
    out[#out + 1] = KEY .. "=" .. value
    local ok = writeStore(table.concat(out, ";") .. ";")
    if ok then S.written = value elseif not S.writeFailLogged then
        S.writeFailLogged = true
        do end
    end
    return ok
end
local function load(saved)
    S.values, S.loaded = unpack(saved or ""), true
    S.written = saved
    local n = 0
    for i = 1, #DVARS do if S.values[i] ~= "" then n = n + 1 end end
    do end
end
S.has = function(name) return INDEX[name] ~= nil end
S.get = function(name)
    if not S.loaded then local saved = entry(); if saved then load(saved) end end
    if not S.loaded then return nil end
    return S.values[INDEX[name]] or ""
end
S.set = function(name, value)
    local i = INDEX[name]
    if not i then return false end
    if not S.loaded then load(entry()) end
    S.values[i] = clean(value)
    return writeEntry()
end
local function tick()
    S.ticks = S.ticks + 1
    local saved = entry()
    if not S.loaded then
        if saved then load(saved) elseif S.ticks >= 6 then load(nil) end
        return
    end
    if saved ~= pack(S.values) and (saved ~= nil or S.written ~= nil) then
        if writeEntry() then do end  end
    end
end
local function loop()
    if not S.enabled then return end
    local ok, err = pcall(tick)
    if not ok then do end  end
    local getRoot = get(rawget(_G, "LUI"), "GetRoot")
    local okR, root = false, nil
    if type(getRoot) == "function" then okR, root = pcall(getRoot) end
    local okW, timer = false, nil
    if okR and root then okW, timer = pcall(function() return root:Wait(1000) end) end
    if okW and timer then timer.onComplete = loop else do end  end
end
loop()
