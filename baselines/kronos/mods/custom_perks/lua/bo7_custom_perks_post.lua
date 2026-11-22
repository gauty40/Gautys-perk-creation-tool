local ENABLE_AUGMENT_HOOKS = true
local ENABLE_WUNDERFIZZ_KBM_HOOKS = true
local ENABLE_GRID_PROBES = false
local VERBOSE_AUGMENT_LOGS = false
local H = rawget(_G, "xhash")
local LOUD_RUNTIME = {
    bo7_cp_nuka_cola_runtime = true, bo7_cp_magnet_margarita_runtime = true, bo7_cp_dam_a_nade_runtime = true,
    bo7_cp_pack_a_box_runtime = true, bo7_cp_blood_wolf_bite_runtime = true, bo7_cp_bull_ice_blast_runtime = true,
    bo7_cp_overclock_runtime = true, bo7_cp_wunderfizz_runtime = true, bo7_cp_banana_colada_runtime = true,
    bo7_cp_jug2_runtime = true, bo7_cp_killing_time_runtime = true, bo7_cp_killstreak_kool_aid_runtime = true,
    bo7_cp_whos_who_runtime = true, bo7_cp_samurais_sake_runtime = true, bo7_cp_twin_spirit_runtime = true,
}
local function log(...) end
if type(H) ~= "function" then do end ; return end
local old = rawget(_G, "BO7CustomPerks")
if old and old.version == 183 then return end
if old then
    old.enabled = false
    if old.cherryChargeSquare then pcall(function() old.cherryChargeSquare:closeTree() end) end
    for _, slot in ipairs(old.overflowPerkIcons or {}) do
        local widget = slot.root or slot
        pcall(function() widget:SetAlpha(0, 0) end)
    end
    if old.stockHudNativePerkContainer then
        local alpha = tonumber(old.stockHudNativePerkAlpha) or 1
        pcall(function() old.stockHudNativePerkContainer:SetAlpha(alpha, 0) end)
    end
end
local previous = old
local S = { version = 183, enabled = true, ticks = 0, hooks = {}, bundles = {}, owned = {}, vitalityLootOptions = {}, augmentLootOptions = {}, pickLoaded = {}, pickLoadTries = {} }
rawset(_G, "BO7CustomPerks", S)
local vitalitySelection = rawget(_G, "BO7VitalityAugmentSelection")
if type(vitalitySelection) ~= "table" then
    vitalitySelection = { major = 0, minor = 0, pending = { major = false, minor = false } }
    rawset(_G, "BO7VitalityAugmentSelection", vitalitySelection)
elseif type(vitalitySelection.pending) ~= "table" then
    vitalitySelection.pending = { major = false, minor = false }
end
if type(vitalitySelection.failureLogged) ~= "table" then
    vitalitySelection.failureLogged = {}
end
local AUGMENT_MINOR_OFFSET = 5
local CUSTOM = {
    {
        ref = "specialty_bandolier", code = 78, name = "Bandolier Bandit",
        creator = "Gauty",
        desc = "Your weapons hold 50% more reserve ammo.",
        icon = "ui_icon_perks_zm_bandolier",
    },
    {
        ref = "specialty_tortoise", code = 73, name = "Victorious Tortoise",
        creator = "Gauty",
        desc = "Take 32% less damage while wearing armor.",
        icon = "ui_icon_perks_zm_tortoise",
    },
    {
        ref = "specialty_gautys_gold", code = 82, name = "Gauty's Gold",
        creator = "Gauty",
        desc = "Earns 1.25x points while this perk is active.",
        icon = "ui_icon_perks_zm_Gautys_Gold",
    },
    {
        ref = "specialty_blaze_phase", code = 84, name = "Blaze Phase",
        creator = "Gauty",
        desc = "Crouch to charge, stand up to launch yourself forward. The longer you charge, the further you go.",
        icon = "ui_icon_perks_zm_blaze_phase",
    },
    {
        ref = "specialty_vitality", code = 70, name = "Vitality",
        creator = "Gauty",
        desc = "Regenerates health while crouched.",
        icon = "ui_icon_perks_zm_custom",
    },
    { ref = "specialty_jug2", code = 71, name = "Roo Brew",
      creator = "Gauty", desc = "Jump five times as high. Equip Moon Hop to reduce gravity for 5 seconds after jumping.", icon = "ui_icons_perks_zm_roo_brew" },
    { ref = "specialty_hunters_mark", code = 87, name = "Hunter's Hooch",
      creator = "Gauty", desc = "The first regular zombie you damage is marked for 8 seconds. Marked zombies take 50% more damage from everyone (20 second cooldown).", icon = "ui_icons_perks_zm_hunters_hooch" },
    { ref = "specialty_electric_cherry", code = 72, name = "Electric Cherry",
      creator = "Gauty", desc = "Reloading shocks nearby zombies and stuns survivors for 2 seconds (30 second cooldown). The emptier your magazine, the more damage: up to 50% of their max health.", icon = "ui_icons_perks_zm_electric_cherry_full", hudIcon = "ui_icons_perks_zm_electric_cherry" },
    { ref = "specialty_axe_shot", code = 86, name = "Axe Shot",
      creator = "Gauty", desc = "Firing launches a spinning axe (at most one every 0.3 seconds) that cuts through zombies for 60% of your held weapon's body-shot damage.", icon = "ui_icon_perks_zm_axe_shot" },
    { ref = "specialty_nuka_cola", code = 88, name = "Nuka Cola",
      creator = "Gauty", desc = "Going down drops a Nuke powerup where you fell.", icon = "ui_icon_perks_nuka_cola" },
    { ref = "specialty_magnet_margarita", code = 89, name = "Magnet Margarita",
      creator = "Gauty", desc = "Powerups drift toward you, stopping just short so you still choose when to grab them.", icon = "ui_icon_perks_magnet_margarita" },
    { ref = "specialty_dam_a_nade", code = 90, name = "Dam-A-Nade",
      creator = "Gauty", desc = "Explosives deal 50% more damage. Carry one extra lethal and tactical, refilled at the end of every round.", icon = "ui_icon_perks_dam_a_nade" },
    { ref = "specialty_pack_a_box", code = 91, name = "Pack-A-Box",
      creator = "Gauty", desc = "Mystery Box weapons can come out Pack-a-Punched: 50% PaP 1, 10% PaP 2, 1% PaP 3, 0.5% PaP 4.", icon = "ui_icon_perks_pack_a_box" },
    { ref = "specialty_blood_wolf_bite", code = 92, name = "Blood Wolf Bite",
      creator = "Gauty", desc = "Dealing heavy damage in a short time summons a friendly hellhound that hunts zombies for 30 seconds (45 second cooldown).", icon = "ui_icon_perks_blood_wolf_bite" },
    { ref = "specialty_bull_ice_blast", code = 93, name = "Ice Cold Cola",
      creator = "Gauty", desc = "While in the air, press crouch to slam down. The impact damages and freezes nearby zombies for 3 seconds; the higher you slam from, the more damage.", icon = "ui_icon_perks_ice_cold_cola" },
    { ref = "specialty_banana_colada", code = 94, name = "Banana Colada",
      creator = "Gauty", desc = "Sliding leaves a toxic trail behind you. Zombies that walk through it fall over and take damage. 15 second cooldown.", icon = "ui_icon_perks_zm_banana_colada" },
    { ref = "specialty_killstreak_kool_aid", code = 95, name = "Killstreak Kool-Aid",
      creator = "Gauty", desc = "Every 150 kills earns you a random killstreak for free.", icon = "ui_icon_perks_killstreak_kool_aid" },
    { ref = "specialty_whos_who", code = 96, name = "Who's Who",
      creator = "Gauty", desc = "Instead of going down, leave a clone behind with your weapons and perks and escape as a ghost. Revive your clone within 60 seconds to get them back, or die. Once per round.", icon = "ui_icon_perks_whos_who" },
    { ref = "specialty_samurais_sake", code = 97, name = "Samurai's Sake",
      creator = "Zura", desc = "Melee hits reach further and ignore zombie armor, and you take 20% less damage holding a melee weapon. Every 30 melee kills unleashes an explosion around you.", icon = "ui_icon_perks_samurais_sake" },
    { ref = "specialty_twin_spirit", code = 98, name = "Twin Spirit",
      creator = "Gauty", desc = "A wisp orbits you. Every shot you fire, the wisp fires a copy at the same target." },
}
local PLACEHOLDER_ICON = "ui_icon_perks_placeholder"
for _, c in ipairs(CUSTOM) do
    if type(c.icon) ~= "string" or c.icon == "" then c.icon = PLACEHOLDER_ICON end
end
S.customPerks = CUSTOM
local PERK_PACK_ICONS = {
    ["specialty_juggernog"] = "ui_icon_perks_zm_juggernaut",
    ["specialty_quickrevive"] = "ui_icon_perks_zm_quickrevive",
    ["specialty_speedcola"] = "ui_icon_perks_zm_speedloader",
    ["specialty_staminup"] = "ui_icon_perks_zm_staminup",
    ["specialty_deadshot"] = "ui_icon_perks_zm_deadshot",
    ["specialty_elemental_pop"] = "ui_icon_perks_zm_elemental_pop",
    ["specialty_phd_flopper"] = "ui_icon_perks_zm_phdslider",
    ["specialty_death_perception"] = "ui_icon_perks_zm_deathperception",
    ["specialty_vulture_aid"] = "ui_icon_perks_vulture_aid",
    ["specialty_m_mod"] = "ui_icon_perks_melee_macchiato",
    ["specialty_d_mod"] = "ui_icon_perks_double_tap",
    ["specialty_w_mod"] = "ui_icon_perks_wisp_tea",
    ["specialty_y_mod"] = "ui_icon_perks_widows_wine_cooldown",
    ["specialty_z_mod"] = "ui_icon_perks_zm_mulekick",
}
local perkPackRefs = {}
for ref in pairs(PERK_PACK_ICONS) do perkPackRefs[#perkPackRefs + 1] = ref end
for _, ref in ipairs(perkPackRefs) do
    local image = PERK_PACK_ICONS[ref]
    local hashed = H(ref)
    if hashed ~= nil then PERK_PACK_ICONS[hashed] = image; PERK_PACK_ICONS[tostring(hashed)] = image end
end
S.perkPackIcons = PERK_PACK_ICONS
local byRef = {}
for _, c in ipairs(CUSTOM) do
    byRef[c.ref] = c
    local refHash = H(c.ref)
    if refHash ~= nil then
        byRef[refHash] = c
        byRef[tostring(refHash)] = c
    end
end
local isCustomPerkAvailable
local function hk(name)
    local ok, v = pcall(H, name)
    if ok then return v end
    return nil
end
local function g(t, k)
    if type(t) ~= "table" then return nil end
    local hv = hk(k)
    local v
    if hv ~= nil then v = t[hv] end
    if v == nil then v = t[k] end
    return v
end
local function s(t, k, v)
    local hv = hk(k)
    if hv ~= nil then t[hv] = v end
    t[k] = v
end
local function allFnKeys(tbl, name)
    local keys, seen = {}, {}
    for _, key in ipairs({ name, hk(name), hk(name:lower()) }) do
        if key ~= nil and not seen[key] then
            seen[key] = true
            local ok, f = pcall(function() return tbl[key] end)
            if ok and type(f) == "function" then keys[#keys + 1] = { key = key, fn = f } end
        end
    end
    return keys
end
local function findFn(tbl, name)
    local candidates = { name, hk(name), hk(name:lower()) }
    for _, key in ipairs(candidates) do
        local ok, f = pcall(function() return tbl[key] end)
        if ok and type(f) == "function" then return key, f end
    end
    return nil
end
local function restorePrototypeAugmentHooks()
    if type(previous) ~= "table" or type(previous.hooks) ~= "table" then return end
    local hookTargets = {
        { "augmentPerkList", rawget(_G, "PERK"), "getallperks" },
        { "vitalityPerkList", rawget(_G, "ZMPERK"), "getperklist" },
        { "augmentFullCache", rawget(_G, "ZMAUGMENT"), "createfullaugmentcache" },
        { "augmentUnlocked", rawget(_G, "LOOT"), "isunlockedwithid" },
        { "augmentFullList", rawget(_G, "ZMAUGMENT"), "initfullaugmentlist" },
        { "augmentTypeList", rawget(_G, "ZMAUGMENT"), "inittypeaugmentlist" },
        { "augmentRefreshList", rawget(_G, "ZMAUGMENT"), "refreshaugmentlistdata" },
        { "augmentEquippedRead", rawget(_G, "ZMAUGMENT"), "getequippedaugmentbyref" },
        { "augmentEquippedWrite", rawget(_G, "ZMAUGMENT"), "modifyselectedaugment" },
        { "vitalityFullAugmentRows", rawget(_G, "ZMAUGMENT"), "initfullaugmentlist" },
        { "vitalityTypedAugmentRows", rawget(_G, "ZMAUGMENT"), "inittypeaugmentlist" },
        { "vitalityAugmentUnlock", rawget(_G, "LOOT"), "isunlockedwithid" },
        { "vitalityAugmentRead", rawget(_G, "ZMAUGMENT"), "getequippedaugmentbyref" },
        { "vitalityAugmentWrite", rawget(_G, "ZMAUGMENT"), "modifyselectedaugment" },
    }
    for _, target in ipairs(hookTargets) do
        local state = previous.hooks[target[1]]
        if type(state) == "table" and type(state.wrapper) == "function" and type(state.original) == "function" then
            for _, entry in ipairs(allFnKeys(target[2], target[3])) do
                if entry.fn == state.wrapper then target[2][entry.key] = state.original end
            end
        end
    end
    local perks = rawget(_G, "ZMPERK")
    local perkList = perks and g(perks, "zmperklist")
    if type(perkList) == "table" then
        for index = #perkList, 1, -1 do
            local ref = g(perkList[index], "ref")
        end
    end
    local augment = rawget(_G, "ZMAUGMENT")
    if type(augment) == "table" then
        for _, name in ipairs({ "augmentlist_full", "augmentlist_major", "augmentlist_minor" }) do
            local list = g(augment, name)
            if type(list) == "table" then
            end
        end
    end
end
local function customPackIcon(icon)
    if type(icon) ~= "string" then return icon end
    local packs = rawget(_G, "BO7CustomPerkIconPacks")
    if type(packs) ~= "table" then return icon end
    local getter = g(rawget(_G, "Dvar"), "GetDvarString")
    local hash = rawget(_G, "xhashdvar") or g(rawget(_G, "CLUA"), "PushXHashDvar")
    local selected
    if type(getter) == "function" and type(hash) == "function" then
        local ok, value = pcall(getter, hash("kr_perk_icons"))
        if ok and value ~= nil then selected = tostring(value) end
    end
    if not selected or selected == "" then selected = packs.defaultPack or "Black Ops 7" end
    local pack = packs.packs and packs.packs[selected:lower()]
    return pack and pack[icon] or icon
end
S.resolvePerkPackIcon = customPackIcon
local function bundleFor(c, original)
    if S.bundles[c.ref] then return S.bundles[c.ref] end
    local base = original("specialty_juggernog")
    if base == nil then return nil end
    local b = {}
    local ok = pcall(function() for k, v in pairs(base) do b[k] = v end end)
    if not ok or next(b) == nil then b = setmetatable({}, { __index = base }) end
    s(b, "ref", c.ref)
    s(b, "name", c.name)
    s(b, "description", c.desc)
    s(b, "shortdesc", c.desc)
    s(b, "augmentlist", nil)
    if c.icon then
        local icon = customPackIcon(c.icon)
        local assetHash = rawget(_G, "xhashasset") or g(rawget(_G, "CLUA"), "PushXHashAsset")
        if type(assetHash) == "function" then
            local hashed, value = pcall(assetHash, icon)
            if hashed and value ~= nil then icon = value end
        end
        for _, f in ipairs({ "hudimage", "image", "legacyimage", "bwimage" }) do s(b, f, icon) end
    end
    S.bundles[c.ref] = b
    return b
end
local function installPerk()
    local PERK = rawget(_G, "PERK")
    if type(PERK) ~= "table" then return false end
    local keys = allFnKeys(PERK, "GetBundleByRef")
    if #keys == 0 then return false end
    local original = keys[1].fn
    if S.hooks.perkWrapper then
        local all = true
        for _, e in ipairs(keys) do if e.fn ~= S.hooks.perkWrapper then all = false end end
        if all then return true end
        original = S.hooks.perkOriginal or original
    else
        S.hooks.perkOriginal = original
    end
    local wrapper = function(ref, ...)
        local c = byRef[ref] or byRef[tostring(ref)]
        if c then
            local b = bundleFor(c, S.hooks.perkOriginal)
            if b then return b end
        end
        return S.hooks.perkOriginal(ref, ...)
    end
    for _, e in ipairs(keys) do PERK[e.key] = wrapper end
    S.hooks.perkWrapper = wrapper
    if not S.loggedPerk then S.loggedPerk = true; do end  end
    return true
end
local seenRefs = {}
local function addCells(tab)
    if type(tab) ~= "table" then return end
    local ref = g(tab, "ref")
    local items = g(tab, "items")
    local key = tostring(ref)
    if not seenRefs[key] then
        seenRefs[key] = true
        local refs = {}
        if type(items) == "table" then
            for i, it in ipairs(items) do if i <= 8 then refs[#refs + 1] = tostring(g(it, "itemref")) end end
        end
        do end
    end
    if (ref ~= "wunderfizz_perks" and ref ~= hk("wunderfizz_perks") and tostring(ref) ~= tostring(hk("wunderfizz_perks"))) or type(items) ~= "table" then return end
    local fallbackTemplate = items[1]
    local nativeSwitches = {
        ["specialty_juggernog"] = "bo7_cp_off_native_juggernog",
        ["specialty_quickrevive"] = "bo7_cp_off_native_quick_revive",
        ["specialty_speedcola"] = "bo7_cp_off_native_speedcola",
        ["specialty_staminup"] = "bo7_cp_off_native_staminup",
        ["specialty_deadshot"] = "bo7_cp_off_native_deadshot",
        ["specialty_elemental_pop"] = "bo7_cp_off_native_elemental_pop",
        ["specialty_phd_flopper"] = "bo7_cp_off_native_phd_flopper",
        ["specialty_death_perception"] = "bo7_cp_off_native_death_perception",
        ["specialty_vulture_aid"] = "bo7_cp_off_native_vulture_aid",
        ["specialty_m_mod"] = "bo7_cp_off_native_m_mod",
        ["specialty_d_mod"] = "bo7_cp_off_native_d_mod",
        ["specialty_w_mod"] = "bo7_cp_off_native_w_mod",
        ["specialty_y_mod"] = "bo7_cp_off_native_y_mod",
        ["specialty_z_mod"] = "bo7_cp_off_native_z_mod",
    }
    for i = #items, 1, -1 do
        local itemRef = g(items[i], "itemref")
        for nativeRef, setting in pairs(nativeSwitches) do
            if (itemRef == nativeRef or itemRef == hk(nativeRef) or tostring(itemRef) == tostring(hk(nativeRef))) and (function() local getter = g(rawget(_G, "Dvar"), "GetDvarString"); local hash = rawget(_G, "xhashdvar"); if type(getter) ~= "function" or type(hash) ~= "function" then return false end; local ok, value = pcall(getter, hash(setting)); return ok and tostring(value) == "1" end)() then
                table.remove(items, i)
                break
            end
        end
    end
    local present, template = {}, nil
    for _, it in ipairs(items) do
        local r = g(it, "itemref")
        present[r or ""] = it
        if r == "specialty_juggernog" or r == hk("specialty_juggernog") then template = it end
    end
    if not template then template = items[1] or fallbackTemplate end
    if not template then return end
    local hashedRefs = type(g(template, "itemref")) == "number"
    local customItems = {}
    for _, c in ipairs(CUSTOM) do
      if c.cell ~= false and isCustomPerkAvailable and isCustomPerkAvailable(c) then
        local item = present[c.ref] or present[hk(c.ref) or ""]
        if not item then
            item = {}
            for k, v in pairs(template) do item[k] = v end
            local refValue = c.ref
            if hashedRefs then refValue = hk(c.ref) or c.ref end
            s(item, "itemref", refValue)
            for _, f in ipairs({ "maxpurchasederrorstring", "progressiongating", "unlockitemref", "loottype", "omnvaritem",
                                 "itempurchasecountomnvar", "itempurchasestockomnvar", "maxstack", "haspurchaselimit", "purchaselimit" }) do
                s(item, f, nil)
            end
            s(item, "menuitemindex", 1700 + c.code)
            s(item, "purchasenotify", "perk_choice_purchase")
            s(item, "showtail", true)
            present[refValue] = item
        end
        for _, f in ipairs({ "maxpurchasederrorstring", "progressiongating", "unlockitemref", "loottype", "omnvaritem",
                             "itempurchasecountomnvar", "itempurchasestockomnvar", "maxstack", "haspurchaselimit", "purchaselimit" }) do
            s(item, f, nil)
        end
        s(item, "displayname", c.name)
        s(item, "shortdisplayname", c.name)
        s(item, "description", c.desc)
        s(item, "menuitemindex", 1700 + c.code)
        s(item, "purchasenotify", "perk_choice_purchase")
        if c.icon then s(item, "image", c.icon); s(item, "toplineimage", c.icon) end
        customItems[#customItems + 1] = item
      end
    end
    for index = #items, 1, -1 do
        local itemRef = g(items[index], "itemref")
        if byRef[itemRef] or byRef[tostring(itemRef)] then
            table.remove(items, index)
        end
    end
    for _, item in ipairs(customItems) do
        s(item, "tabitemindex", #items + 1)
        table.insert(items, item)
    end
    if S.loggedCells ~= #customItems then
        S.loggedCells = #customItems
        do end
        local fields = {}
        for k, v in pairs(tab) do
            local t = type(v)
            fields[#fields + 1] = tostring(k) .. "=" .. ((t == "table") and ("table#" .. #v) or (t == "function" and "fn" or tostring(v)))
        end
        do end
        local tmplFields = {}
        for k, v in pairs(items[1]) do tmplFields[#tmplFields + 1] = tostring(k) .. "=" .. tostring(v) end
        do end
    end
end
local function processResult(res)
    if type(res) ~= "table" then return end
    if type(g(res, "items")) == "table" then
        local ok, e = pcall(addCells, res)
        if not ok and not S.errCell then S.errCell = true; do end  end
    else
        for _, tab in ipairs(res) do
            local ok, e = pcall(addCells, tab)
            if not ok and not S.errCell then S.errCell = true; do end  end
        end
    end
end
local function hookMenuFn(PMU, name, tag)
    local keys = allFnKeys(PMU, name)
    if #keys == 0 then return false end
    local st = S.hooks[tag] or {}
    S.hooks[tag] = st
    if st.wrapper then
        local all = true
        for _, e in ipairs(keys) do if e.fn ~= st.wrapper then all = false end end
        if all then return true end
    else
        st.original = keys[1].fn
        st.wrapper = function(...)
            if tag == "buttonAction" then
                local button = select(1, ...)
                local ok, data = pcall(function() return button:getbuttondata() end)
                if ok and type(data) == "table" then
                    local index = g(data, "menuitemindex")
                    if index == 1770 or index == 1771 or index == 1772 then
                        local key = "loggedClick_" .. tostring(index)
                        if not S[key] then
                            S[key] = true
                            do end
                        end
                    end
                end
            end
            do end
            local res = st.original(...)
            do end
            if not S["called_" .. tag] then S["called_" .. tag] = true; do end  end
            processResult(res)
            do end
            return res
        end
    end
    for _, e in ipairs(keys) do PMU[e.key] = st.wrapper end
    if not st["logged"] then st.logged = true; do end  end
    return true
end
local function installMenu()
    local PMU = rawget(_G, "PurchaseMenuUtils")
    if type(PMU) ~= "table" then return false end
    local a = hookMenuFn(PMU, "setupmenutabinfo", "menuInfo")
    local b = hookMenuFn(PMU, "setuptabinfostruct", "tabStruct")
    local c = hookMenuFn(PMU, "zmhandlebuttonaction", "buttonAction")
    return a or b or c
end
local function installNotifyServer()
    local engine = rawget(_G, "Engine")
    if engine == nil then return false end
    local keys = allFnKeys(engine, "NotifyServer")
    if #keys == 0 then return false end
    local st = S.hooks.engineNotify
    if not st then
        st = { original = keys[1].fn }
        st.wrapper = function(channel, value, ...)
            if channel == "perk_choice_purchase" and (value == 1770 or value == 1771 or value == 1772) then
                do end
            end
            return st.original(channel, value, ...)
        end
        S.hooks.engineNotify = st
    end
    for _, e in ipairs(keys) do
        local ok, err = pcall(function() engine[e.key] = st.wrapper end)
        if not ok then
            if not st.failed then
                st.failed = true
                do end
            end
            return false
        end
    end
    if not st.logged then
        st.logged = true
        do end
    end
    return true
end
local function settingsStore(name)
    local p = rawget(_G, "BO7PerkPersist")
    if type(p) == "table" and p.enabled and p.has(name) then return p end
end
local function readDebugDvar(name)
    local store = settingsStore(name)
    if store then return store.get(name) end
    local dvar = rawget(_G, "Dvar")
    local getter = g(dvar, "GetDvarString")
    local hashDvar = rawget(_G, "xhashdvar") or rawget(_G, "PushXHashDvar")
    local clua = rawget(_G, "CLUA")
    if type(hashDvar) ~= "function" and type(clua) == "table" then
        hashDvar = g(clua, "PushXHashDvar")
    end
    if type(getter) ~= "function" or type(hashDvar) ~= "function" then
        if not S.errDvarReadback then
            S.errDvarReadback = true
            do end
        end
        return nil
    end
    local okHash, dvarHash = pcall(hashDvar, name)
    if not okHash then
        if not S.errDvarHash then
            S.errDvarHash = true
            do end
        end
        return nil
    end
    local ok, value = pcall(getter, dvarHash)
    if not ok then
        if not S.errDvarGet then
            S.errDvarGet = true
            do end
        end
        return nil
    end
    if value == nil then return nil end
    return tostring(value)
end
local function readCustomPerkManifest()
    if readDebugDvar("bo7_cp_perk_manifest_ready") ~= "1" then
        if not S.perkManifestWaitLogged then
            S.perkManifestWaitLogged = true
            do end
        end
        return nil
    end
    local raw = readDebugDvar("bo7_cp_registered_perks")
    if not raw or raw:sub(1, 3) ~= "v1:" then
        if not S.perkManifestInvalidLogged then
            S.perkManifestInvalidLogged = true
            do end
        end
        return nil
    end
    if S.perkManifestRaw ~= raw then
        local registered = {}
        for id in raw:sub(4):gmatch("[^,]+") do
            registered[id] = true
        end
        S.perkManifestRaw = raw
        S.perkManifest = registered
        do end
    end
    return S.perkManifest
end
isCustomPerkAvailable = function(perk)
    if type(perk) ~= "table" then return false end
    local manifest = readCustomPerkManifest()
    if not manifest then
        local frontend = g(rawget(_G, "Engine"), "InFrontend")
        local client = g(rawget(_G, "Game"), "getplayerclientnum")
        if type(frontend) ~= "function" or type(client) ~= "function" then return false end
        local frontOk, inFrontend = pcall(frontend)
        local slotOk, slot = pcall(client, 0)
        slot = slotOk and tonumber(slot) or nil
        if not frontOk or inFrontend ~= false or not slot or slot < 0 or slot > 3 or slot ~= math.floor(slot) then return false end
        if not S.loggedLocalPerkCatalog then
            S.loggedLocalPerkCatalog = true
            do end
        end
        return byRef[perk.ref] ~= nil
    end
    local id = perk.id or tostring(perk.ref or ""):gsub("^specialty_", "")
    return manifest[id] == true
end
local function installOwnedPerkDisplay()
    local perks = rawget(_G, "ZMPERK")
    if type(perks) ~= "table" then return false end
    local keys = allFnKeys(perks, "HasPerk")
    if #keys == 0 then return false end
    local st = S.hooks.ownedPerkDisplay
    if not st then
        st = { original = keys[1].fn }
        st.wrapper = function(controller, ref, ...)
            local custom = byRef[ref] or byRef[tostring(ref)]
            local fromServer = S.omnvarOwned
            local natives = S.nativeHudKey or {}
            local key = custom and custom.ref or natives[ref] or natives[tostring(ref)]
            if fromServer and key then return fromServer[key] == true end
            if custom then
                local owned = readDebugDvar("bo7_cp_client_owned_" .. custom.ref:gsub("^specialty_", ""))
                if owned == "1" or owned == "true" then
                    S.owned[custom.ref] = true
                elseif owned == "0" or owned == "false" then
                    S.owned[custom.ref] = false
                end
                local checkState = tostring(owned) .. "/" .. tostring(S.owned[custom.ref])
                if S["lastOwnedCheck_" .. custom.ref] ~= checkState then
                    S["lastOwnedCheck_" .. custom.ref] = checkState
                    do end
                end
                if S.owned[custom.ref] then return true end
            end
            return st.original(controller, ref, ...)
        end
        S.hooks.ownedPerkDisplay = st
    end
    for _, e in ipairs(keys) do perks[e.key] = st.wrapper end
    if not st.logged then
        st.logged = true
        do end
    end
    return true
end
local function perkHotbarActive()
    local hotbar = rawget(_G, "BO7PerkHotbar")
    local panel = type(hotbar) == "table" and hotbar.panel
    if not panel then return false end
    local ok, parent = pcall(function() return panel:getParent() end)
    return ok and parent ~= nil
end
local function customHudThemeActive()
    for _, name in ipairs({ "BO4HUDPost", "HaloUI" }) do
        local api = rawget(_G, name)
        local themes = g(api, "themes")
        local current = g(themes, "current")
        if type(current) == "function" then
            local ok, theme = pcall(current, 0)
            if ok and theme ~= nil then return true end
        end
    end
    return false
end
local function stockHudPerkDataLookup()
    local debugApi = rawget(_G, "debug")
    if type(debugApi) ~= "table" or type(debugApi.getinfo) ~= "function" then
        if not S.stockHudPerkLookupUnavailableLogged then
            S.stockHudPerkLookupUnavailableLogged = true
            do end
        end
        return false
    end
    for level = 2, 12 do
        local ok, info = pcall(debugApi.getinfo, level, "S")
        local source = ok and info and info.source
        if type(source) == "string" and source:lower():find("zmperkutils", 1, true) then
            if not S.stockHudPerkLookupLogged then
                S.stockHudPerkLookupLogged = true
                do end
            end
            return true
        end
    end
    return false
end
local function rankOf(c)
    local n = 0
    for _, other in ipairs(CUSTOM) do
        if other.code < c.code then n = n + 1 end
    end
    return n
end
local function hudIdFor(c)
    local id = 31 - rankOf(c)
    if id < 17 then return nil end
    local idsToRefs = g(rawget(_G, "ZMPERK"), "perks_id_to_ref")
    local current = type(idsToRefs) == "table" and idsToRefs[id] or nil
    if current ~= nil and not (byRef[current] or byRef[tostring(current)]) then return nil end
    return id
end
local function installHudPerkIds()
    local perks = rawget(_G, "ZMPERK")
    if type(perks) ~= "table" then return false end
    local keys = allFnKeys(perks, "getperkrefbyid")
    if #keys == 0 then return false end
    local st = S.hooks.hudPerkIds
    if not st then
        st = { original = keys[1].fn }
        st.wrapper = function(id, ...)
            for _, c in ipairs(CUSTOM) do
                if isCustomPerkAvailable and isCustomPerkAvailable(c) then
                    local customId = hudIdFor(c)
                    if customId and tonumber(id) == customId then
                        return c.ref
                    end
                end
            end
            return st.original(id, ...)
        end
        S.hooks.hudPerkIds = st
    end
    for _, e in ipairs(keys) do perks[e.key] = st.wrapper end
    local idsToRefs = g(perks, "perks_id_to_ref")
    if type(idsToRefs) == "table" then
        if not S.loggedNativeIds and #idsToRefs > 0 then
            S.loggedNativeIds = true
            local list = {}
            for id = 1, 31 do
                if idsToRefs[id] ~= nil then list[#list + 1] = id .. "=" .. tostring(idsToRefs[id]) end
            end
            do end
        end
        for _, c in ipairs(CUSTOM) do
            if isCustomPerkAvailable and isCustomPerkAvailable(c) then
                local customId = hudIdFor(c)
                if customId and customId >= 1 and customId <= 31 then
                    idsToRefs[customId] = c.ref
                    local logKey = "loggedHudId_" .. c.ref
                    if not S[logKey] then
                        S[logKey] = true
                        do end
                    end
                end
            end
        end
    end
    if not st.logged then
        st.logged = true
        do end
    end
    return true
end
local function closeOverflowPerkIcons()
    if S.cherryChargeSquare then pcall(function() S.cherryChargeSquare:closeTree() end); S.cherryChargeSquare = nil end
    for _, slot in ipairs(S.overflowPerkIcons or {}) do
        local widget = slot.root or slot
        pcall(function() widget:closeTree() end)
    end
    S.overflowPerkIcons = {}
    S.overflowPerkRoot = nil
    if S.perkIconLayer then pcall(function() S.perkIconLayer:closeTree() end) end
    S.perkIconLayer, S.perkIconLayerRoot = nil, nil
end
local function hideOverflowPerkIcons()
    if S.cherryChargeSquare then pcall(function() S.cherryChargeSquare:SetAlpha(0, 0) end) end
    for _, slot in ipairs(S.overflowPerkIcons or {}) do
        local widget = slot.root or slot
        pcall(function() widget:SetAlpha(0, 0) end)
    end
end
local function overflowPerkIconValue(item, ctrl)
    for _, name in ipairs({ "image", "icon", "imageName", "perkIcon", "hudimage", "legacyimage", "bwimage" }) do
        local keys = { name }
        local hashed = hk(name)
        if hashed ~= nil and hashed ~= name then keys[#keys + 1] = hashed end
        local lowerHashed = hk(name:lower())
        if lowerHashed ~= nil and lowerHashed ~= name and lowerHashed ~= hashed then
            keys[#keys + 1] = lowerHashed
        end
        for _, key in ipairs(keys) do
            local ok, source = pcall(function() return item[key] end)
            if ok and source ~= nil then
                local okValue, value = pcall(function()
                    local sourceType = type(source)
                    if sourceType ~= "table" and sourceType ~= "userdata" then return source end
                    if type(source.GetValue) == "function" then return source:GetValue(ctrl) end
                    return source
                end)
                if okValue and value ~= nil and value ~= "" then return value end
            end
        end
    end
end
local function stockHudOverflowPerkRefs()
    if S.stockHudOverflowRefsSnapshot and S.polls - S.stockHudOverflowRefsPoll < 3 then
        return S.stockHudOverflowRefsSnapshot
    end
    local value = readDebugDvar("bo7_cp_client_overflow_perks")
    if not value or value:sub(1, 3) ~= "v1:" then return nil end
    local refs = {}
    for ref in value:sub(4):gmatch("[^,]+") do
        refs[#refs + 1] = ref
    end
    S.stockHudOverflowRefsSnapshot = refs
    S.stockHudOverflowRefsPoll = S.polls
    return refs
end
local function slotHudStatus(...) end
local NATIVE_HUD_PERKS = { "specialty_juggernog", "specialty_quickrevive", "specialty_speedcola", "specialty_staminup",
    "specialty_deadshot", "specialty_elemental_pop", "specialty_phd_flopper", "specialty_death_perception",
    "specialty_vulture_aid", "specialty_m_mod", "specialty_d_mod", "specialty_w_mod", "specialty_y_mod",
    "specialty_z_mod" }
local NATIVE_HUD_KEY = {}
for _, ref in ipairs(NATIVE_HUD_PERKS) do
    NATIVE_HUD_KEY[ref] = ref
    local hashed = H(ref)
    if hashed ~= nil then NATIVE_HUD_KEY[hashed] = ref; NATIVE_HUD_KEY[tostring(hashed)] = ref end
end
S.nativeHudKey = NATIVE_HUD_KEY
local function collectHudPages()
    local frontend = g(rawget(_G, "Engine"), "InFrontend")
    local okFront, inFront = false, nil
    if type(frontend) == "function" then okFront, inFront = pcall(frontend) end
    if not okFront or inFront ~= false then S.hudPages = nil; S.nativeEternalOwned = nil; return end
    local get = g(rawget(_G, "Game"), "getomnvar")
    if type(get) ~= "function" then return end
    local ok, v = pcall(get, 0, "ui_br_objective_param")
    v = ok and tonumber(v) or nil
    if not v or v < 0 then return end
    S.hudPages = S.hudPages or {}
    S.hudPages[math.floor(v / 4096)] = v % 4096
end
local function decodeHudPages()
    local pages = S.hudPages
    if not pages then return nil end
    local function has(base, index)
        local bits = pages[base + math.floor(index / 12)] or 0
        return math.floor(bits / 2 ^ (index % 12)) % 2 == 1
    end
    local owned, eternal = {}, {}
    local function check(ref, index)
        if has(0, index) then owned[ref] = true end
        if has(12, index) then eternal[ref] = true end
    end
    for i, ref in ipairs(NATIVE_HUD_PERKS) do check(ref, i - 1) end
    for _, c in ipairs(CUSTOM) do check(c.ref, 14 + rankOf(c)) end
    return owned, eternal
end
local function stockHudOmnvarSnapshot()
    local owned, eternal = decodeHudPages()
    if not owned then return nil end
    S.eternalPerkRefs = eternal
    local order, placed = {}, {}
    for _, ref in ipairs(S.omnvarPerkOrder or {}) do
        if owned[ref] then order[#order + 1] = ref; placed[ref] = true end
    end
    for _, ref in ipairs(NATIVE_HUD_PERKS) do
        if owned[ref] and not placed[ref] then order[#order + 1] = ref; placed[ref] = true end
    end
    for _, c in ipairs(CUSTOM) do
        if owned[c.ref] and not placed[c.ref] then order[#order + 1] = c.ref; placed[c.ref] = true end
    end
    S.omnvarPerkOrder = order
    local get = g(rawget(_G, "Game"), "getomnvar")
    local ok, charge = false, nil
    if type(get) == "function" then ok, charge = pcall(get, 0, "ui_br_assassination_target") end
    charge = math.max(ok and tonumber(charge) or 0, 0)
    local function pct(step) return math.floor(step * 100 / 11 + 0.5) end
    S.cherryChargePercent = pct(math.floor(charge / 144))
    S.hunterChargePercent = pct(math.floor(charge / 12) % 12)
    S.widowChargePercent = pct(charge % 12)
    local okCooldown, cooldown = pcall(get, 0, "ui_br_objective_index")
    cooldown = math.max(0, math.min(224, okCooldown and tonumber(cooldown) or 224))
    S.bananaChargePercent = math.floor(math.floor(cooldown / 15) * 100 / 14 + 0.5)
    S.wolfChargePercent = math.floor((cooldown % 15) * 100 / 14 + 0.5)
    return "v1:" .. table.concat(order, ",")
end
local function localPlayerPerkSnapshot()
    local frontend = g(rawget(_G, "Engine"), "InFrontend")
    if type(frontend) ~= "function" then return nil end
    local okFront, isFront = pcall(frontend)
    if not okFront or isFront ~= false then return nil end
    local getClient = g(rawget(_G, "Game"), "getplayerclientnum")
    if type(getClient) ~= "function" then do end ; return nil end
    local okClient, slot = pcall(getClient, 0)
    slot = okClient and tonumber(slot) or nil
    local value = slot and readDebugDvar("bo7_cp_hud_slot_" .. tostring(slot))
    local prefix = "slot=" .. tostring(slot) .. ";v1:"
    if type(value) ~= "string" or value:sub(1, #prefix) ~= prefix then
        local fromOmnvars = stockHudOmnvarSnapshot()
        do end
        return fromOmnvars
    end
    local payload = value:sub(#prefix + 1)
    local cooldownPayload, banana, wolf = payload:match("^(.-);banana_pct:(%d+);wolf_pct:(%d+)$")
    S.bananaChargePercent = tonumber(banana) or 100
    S.wolfChargePercent = tonumber(wolf) or 100
    payload = cooldownPayload or payload
    local widowPayload, widowCharge = payload:match("^(.-);widow_pct:(%d+)$")
    S.widowChargePercent = tonumber(widowCharge) or 100
    payload = widowPayload or payload
    local hunterPayload, hunterCharge = payload:match("^(.-);hunter_pct:(%d+)$")
    S.hunterChargePercent = tonumber(hunterCharge) or 100
    payload = hunterPayload or payload
    local chargePayload, charge = payload:match("^(.-);cherry_pct:(%d+)$")
    S.cherryChargePercent = tonumber(charge) or 100
    payload = chargePayload or payload
    local owned, eternal = payload:match("^(.-);eternal:(.*)$")
    S.eternalPerkRefs = {}
    for ref in (eternal or ""):gmatch("[^,]+") do S.eternalPerkRefs[ref] = true end
    local result = "v1:" .. (owned or payload)
    do end
    return result
end
local function stockHudAllPerkRefs()
    if S.stockHudAllRefsSnapshot and S.polls - S.stockHudAllRefsPoll < 3 then
        return S.stockHudAllRefsSnapshot
    end
    local value = localPlayerPerkSnapshot() or readDebugDvar("bo7_cp_client_all_perks")
    if not value or value:sub(1, 3) ~= "v1:" then return nil end
    local refs, seen = {}, {}
    for ref in value:sub(4):gmatch("[^,]+") do
        if ref ~= "" and not seen[ref] then
            refs[#refs + 1] = ref
            seen[ref] = true
        end
    end
    S.stockHudAllRefsSnapshot = refs
    S.stockHudAllRefsPoll = S.polls
    return refs
end
local function stockHudPerkItemByRef(ref)
    S.stockHudOverflowItemsByRef = S.stockHudOverflowItemsByRef or {}
    local cached = S.stockHudOverflowItemsByRef[ref]
    if cached then return cached end
    local getBundle = g(rawget(_G, "PERK"), "GetBundleByRef")
    local customPerk = byRef[ref] or byRef[tostring(ref)]
    local icon = (customPerk and customPerk.icon) or PERK_PACK_ICONS[ref] or PERK_PACK_ICONS[tostring(ref)]
    if icon == nil and type(getBundle) == "function" then
        local okBundle, bundle = pcall(getBundle, ref)
        if okBundle and type(bundle) == "table" then
            icon = overflowPerkIconValue(bundle, 0)
        end
    end
    if icon == nil then
        local filters = g(rawget(_G, "PERK"), "filters")
        local getIcon = g(filters, "getperkicon")
        if type(getIcon) == "function" then
            local okIcon, value = pcall(getIcon, ref)
            if okIcon and value ~= nil and value ~= "" then icon = value end
        end
    end
    icon = customPackIcon(icon)
    local item = { icon = icon, ref = ref }
    if item.icon ~= nil then S.stockHudOverflowItemsByRef[ref] = item end
    return item
end
local function stockHudOwnedPerks()
    if S.stockHudOwnedSnapshot and S.polls - S.stockHudOwnedSnapshotPoll < 5 then
        return S.stockHudOwnedSnapshot
    end
    local zmPerk = rawget(_G, "ZMPERK")
    local getList = g(zmPerk, "getperklist")
    local hasPerkKeys = allFnKeys(zmPerk, "HasPerk")
    local getBundle = g(rawget(_G, "PERK"), "GetBundleByRef")
    if type(getList) ~= "function" or #hasPerkKeys == 0 or type(getBundle) ~= "function" then
        return nil
    end
    local okList, entries = pcall(getList)
    if not okList or type(entries) ~= "table" then
        okList, entries = pcall(getList, 0)
    end
    if not okList or type(entries) ~= "table" then return nil end
    local nativeOwned, customOwned, seen = {}, {}, {}
    local function addOwnedRef(ref, entry)
        if ref == nil then return end
        local custom = byRef[ref] or byRef[tostring(ref)]
        local refKey = custom and custom.ref or tostring(ref)
        if seen[refKey] then return end
        seen[refKey] = true
        local okOwned, isOwned = pcall(hasPerkKeys[1].fn, 0, ref)
        if okOwned and isOwned then
            local okBundle, bundle = pcall(getBundle, ref)
            if not okBundle or type(bundle) ~= "table" then bundle = g(entry, "data") end
            local icon = bundle and overflowPerkIconValue(bundle, 0)
            if icon then
                local destination = custom and customOwned or nativeOwned
                destination[#destination + 1] = { icon = icon, ref = ref }
            elseif not S.stockHudPerkIconMissingLogged then
                S.stockHudPerkIconMissingLogged = true
                do end
            end
        end
    end
    for _, entry in ipairs(entries) do
        addOwnedRef(g(entry, "ref"), entry)
    end
    for _, c in ipairs(CUSTOM) do
        if isCustomPerkAvailable and isCustomPerkAvailable(c) then
            addOwnedRef(c.ref)
        end
    end
    local owned = { native = nativeOwned, custom = customOwned }
    S.stockHudOwnedSnapshot = owned
    S.stockHudOwnedSnapshotPoll = S.polls
    return owned
end
local function overflowPerkList()
    local paths = {
        { "inGame", "ZM", "perks" },
        { "inGame", "ZM", "perks", "list" },
        { "inGame", "player", "perks" },
    }
    local roots = {}
    local plainRoot = rawget(_G, "DataSources")
    local hashedRoot = rawget(_G, "_DataSources")
    if plainRoot then roots[#roots + 1] = plainRoot end
    if hashedRoot and hashedRoot ~= plainRoot then roots[#roots + 1] = hashedRoot end
    local function child(node, key)
        local keys = { key }
        local hashed = hk(key)
        if hashed ~= nil and hashed ~= key then keys[#keys + 1] = hashed end
        local lowerHashed = hk(key:lower())
        if lowerHashed ~= nil and lowerHashed ~= key and lowerHashed ~= hashed then
            keys[#keys + 1] = lowerHashed
        end
        for _, candidate in ipairs(keys) do
            local ok, value = pcall(function() return node[candidate] end)
            if ok and value ~= nil then return value end
        end
    end
    for _, root in ipairs(roots) do
        for _, path in ipairs(paths) do
            local node = root
            for _, key in ipairs(path) do
                node = child(node, key)
                if node == nil then break end
            end
            if node then
                local okList, valid = pcall(function()
                    return type(node.GetCountValue) == "function"
                        and type(node.GetDataSourceAtIndex) == "function"
                end)
                if okList and valid then return node end
            end
        end
    end
end
local function stockHudActivePerkOrder()
    local roots = {}
    local hashedRoot = rawget(_G, "_DataSources")
    local plainRoot = rawget(_G, "DataSources")
    if hashedRoot then roots[#roots + 1] = hashedRoot end
    if plainRoot and plainRoot ~= hashedRoot then roots[#roots + 1] = plainRoot end
    local paths = {
        { "zm", "in_game", "player", "perks", "active_perks" },
        { "inGame", "ZM", "player", "perks", "active_perks" },
    }
    local function readValue(node, controller)
        local ok, value = pcall(function()
            if type(node) == "table" or type(node) == "userdata" then
                local getter = node.GetValue
                if type(getter) == "function" then return getter(node, controller) end
            end
            return node
        end)
        return ok and value or nil
    end
    for _, root in ipairs(roots) do
        if root then
            for _, path in ipairs(paths) do
                local node = root
                for _, key in ipairs(path) do
                    node = g(node, key)
                    if node == nil then break end
                end
                if node then
                    local count = tonumber(readValue(g(node, "count"), 0))
                    local getPerkRef = g(rawget(_G, "ZMPERK"), "getperkrefbyid")
                    if count and count >= 0 and count <= 24 and type(getPerkRef) == "function" then
                        local refs, valid = {}, true
                        for index = 1, math.floor(count) do
                            local okSlot, slot = pcall(function() return node[index] end)
                            local id = okSlot and tonumber(readValue(g(slot, "id"), 0))
                            if not id or id <= 0 then
                                valid = false
                                break
                            end
                            local okRef, ref = pcall(getPerkRef, id)
                            if not okRef or ref == nil then
                                valid = false
                                break
                            end
                            refs[#refs + 1] = ref
                        end
                        if valid then return refs end
                    end
                end
            end
        end
    end
end
local function stockHudRoot()
    local lui = rawget(_G, "LUI")
    if type(lui) ~= "table" or type(lui.GetRoot) ~= "function" then return nil end
    local ok, root = pcall(lui.GetRoot)
    return ok and root or nil
end
local function installNativePerkCapture()
    local lui = rawget(_G, "LUI")
    local targets = {
        { owner = rawget(_G, "MenuBuilder"), name = "BuildRegisteredType", key = "nativePerkCapture", method = false },
        { owner = g(lui, "UIElement"), name = "AddWidget", key = "nativePerkAddWidget", method = true },
    }
    for _, target in ipairs(targets) do
        local keys = allFnKeys(target.owner, target.name)
        if #keys > 0 then
            local st = S.hooks[target.key]
            if not st then
                st = { original = keys[1].fn, method = target.method }
                st.wrapper = function(...)
                    local widget = st.original(...)
                    local name = select(st.method and 2 or 1, ...)
                    if S.enabled and widget and (name == "perkcontainer" or name == hk("perkcontainer")) then
                        S.nativePerkContainers = S.nativePerkContainers or setmetatable({}, { __mode = "k" })
                        if not S.nativePerkContainers[widget] then do end  end
                        S.nativePerkContainers[widget] = true
                        if S.fullPerkHudRendered then pcall(function() widget:SetAlpha(0, 0) end) end
                    end
                    return widget
                end
                S.hooks[target.key] = st
            end
            for _, entry in ipairs(keys) do target.owner[entry.key] = st.wrapper end
        end
    end
end
local function findNativePerkContainer(root)
    for widget in pairs(S.nativePerkContainers or {}) do
        local okParent, parent = pcall(function() return widget:getParent() end)
        if okParent and parent ~= nil then
            if S.stockHudNativePerkContainer ~= widget then
                S.stockHudNativePerkContainer = widget
                S.stockHudNativePerkRoot = root
                local okAlpha, alpha = pcall(function() return widget:GetAlpha() end)
                S.stockHudNativePerkAlpha = okAlpha and tonumber(alpha) or 1
            end
            return widget
        end
    end
    local cached = S.stockHudNativePerkContainer
    if cached and S.stockHudNativePerkRoot == root then
        local okParent, parent = pcall(function() return cached:getParent() end)
        if not okParent or parent ~= nil then return cached end
        S.stockHudNativePerkContainer = nil
    end
    if S.stockHudPerkContainerSearchRoot ~= root then
        S.stockHudPerkContainerSearchRoot = root
        S.stockHudPerkContainerSearchCooldown = 0
    elseif (S.stockHudPerkContainerSearchCooldown or 0) > 0 then
        S.stockHudPerkContainerSearchCooldown = S.stockHudPerkContainerSearchCooldown - 1
        return nil
    end
    local maxNodes = 20000
    local queue = { root }
    local visited = {}
    local cursor = 1
    while cursor <= #queue and cursor <= maxNodes do
        local node = queue[cursor]
        cursor = cursor + 1
        if node ~= nil and not visited[node] then
            visited[node] = true
            local okId, id = pcall(function() return g(node, "id") end)
            if okId and id == "perkcontainer" then
                S.stockHudNativePerkContainer = node
                S.stockHudNativePerkRoot = root
                local okAlpha, alpha = pcall(function() return node:GetAlpha() end)
                S.stockHudNativePerkAlpha = okAlpha and tonumber(alpha) or 1
                S.stockHudPerkContainerSearchCooldown = 0
                return node
            end
            local okFirst, child = pcall(function() return node:getFirstChild() end)
            if okFirst then
                local siblingSeen = {}
                local childCount = 0
                while child and not siblingSeen[child] and childCount < 256 and #queue < maxNodes do
                    siblingSeen[child] = true
                    childCount = childCount + 1
                    queue[#queue + 1] = child
                    local okNext, nextChild = pcall(function() return child:getNextSibling() end)
                    if not okNext then break end
                    child = nextChild
                end
            end
        end
    end
    S.stockHudPerkContainerSearchCooldown = 10
    if cursor > maxNodes and not S.stockHudPerkContainerSearchLimitLogged then
        S.stockHudPerkContainerSearchLimitLogged = true
        do end
    end
    return nil
end
local restoreNativePerkVisibility
local function restoreNativePerkContainer()
    S.fullPerkHudRendered = false
    local container = S.stockHudNativePerkContainer
    if container then
        local alpha = S.stockHudNativePerkAlpha
        if type(alpha) ~= "number" then alpha = 1 end
        pcall(function() container:SetAlpha(alpha, 0) end)
    end
    S.stockHudNativePerkContainer = nil
    S.stockHudNativePerkRoot = nil
    S.stockHudNativePerkAlpha = nil
    if restoreNativePerkVisibility then restoreNativePerkVisibility() end
end
local function hideNativePerkContainer(container)
    if not container then return false end
    if S.stockHudNativePerkContainer ~= container then
        S.stockHudNativePerkContainer = container
        local okAlpha, alpha = pcall(function() return container:GetAlpha() end)
        S.stockHudNativePerkAlpha = okAlpha and tonumber(alpha) or 1
    end
    local ok = pcall(function() container:SetAlpha(0, 0) end)
    return ok
end
local function stockHudPerkContainerVisible()
    local roots = {}
    local hashedRoot = rawget(_G, "_DataSources")
    local plainRoot = rawget(_G, "DataSources")
    if hashedRoot then roots[#roots + 1] = hashedRoot end
    if plainRoot and plainRoot ~= hashedRoot then roots[#roots + 1] = plainRoot end
    for _, root in ipairs(roots) do
        local node = root
        for _, key in ipairs({ "zm", "in_game", "player", "perks", "perk_container_visibility" }) do
            node = g(node, key)
            if node == nil then break end
        end
        if node ~= nil then
            local okValue, value = pcall(function()
                if type(node.GetValue) == "function" then return node:GetValue(0) end
                return nil
            end)
            if okValue and type(value) == "boolean" then return value end
        end
    end
    return true
end
local function nativePerkVisibilitySource()
    local roots = {}
    local hashedRoot = rawget(_G, "_DataSources")
    local plainRoot = rawget(_G, "DataSources")
    if hashedRoot then roots[#roots + 1] = hashedRoot end
    if plainRoot and plainRoot ~= hashedRoot then roots[#roots + 1] = plainRoot end
    for _, root in ipairs(roots) do
        local node = root
        for _, key in ipairs({ "zm", "in_game", "player", "perks", "perk_container_visibility" }) do
            node = g(node, key)
            if node == nil then break end
        end
        if node ~= nil then return node end
    end
    return nil
end
local function writeNativePerkVisibility(value)
    local source = nativePerkVisibilitySource()
    if source == nil then return false end
    local okModel, model = pcall(function()
        if type(source.GetModel) == "function" then return source:GetModel(0) end
        return nil
    end)
    local dataModel = rawget(_G, "DataModel")
    local setModelValue = g(dataModel, "SetModelValue")
    if okModel and model ~= nil and type(setModelValue) == "function" then
        pcall(setModelValue, model, value)
    end
    pcall(function()
        if type(source.SetValue) == "function" then source:SetValue(0, value) end
    end)
    local okValue, current = pcall(function() return source:GetValue(0) end)
    return okValue and current == value
end
local function hideNativePerkVisibility()
    local source = nativePerkVisibilitySource()
    if source == nil then return false end
    if S.stockHudNativePerkVisibilityOriginal == nil then
        local okValue, current = pcall(function() return source:GetValue(0) end)
        if okValue and type(current) == "boolean" then
            S.stockHudNativePerkVisibilityOriginal = current
        end
    end
    local okValue, current = pcall(function() return source:GetValue(0) end)
    if okValue and current == false then return true end
    return writeNativePerkVisibility(false)
end
restoreNativePerkVisibility = function()
    local original = S.stockHudNativePerkVisibilityOriginal
    if type(original) == "boolean" then writeNativePerkVisibility(original) end
    S.stockHudNativePerkVisibilityOriginal = nil
end
local CUSTOM_PERK_ROW_LIMIT = 20
local STOCK_HUD_NATIVE_PERK_LIMIT = 16
local DEBUG_PERK_HUD_AT_TOP = false
local CUSTOM_PERK_ROW_VERTICAL_SHIFT = 6
local CUSTOM_PERK_ROW_SPACING = 30
local CHARGE_BAR_REFS = { specialty_banana_colada = true, specialty_blood_wolf_bite = true,
    specialty_killstreak_kool_aid = true, specialty_samurais_sake = true }
local function appendPerkRows(rows, items, firstRow, maxColumns)
    local index = 1
    local row = firstRow
    while index <= #items do
        local rowCount = math.min(maxColumns, #items - index + 1)
        for column = 0, rowCount - 1 do
            rows[#rows + 1] = {
                item = items[index],
                row = row,
                column = column,
                rowCount = rowCount,
            }
            index = index + 1
        end
        row = row + 1
    end
end
local function buildFullPerkRows(refs)
    local native, custom, seen = {}, {}, {}
    for _, ref in ipairs(refs) do
        local customPerk = byRef[ref] or byRef[tostring(ref)]
        local key = customPerk and customPerk.ref or tostring(ref)
        if not seen[key] then
            seen[key] = true
            local item = stockHudPerkItemByRef(ref)
            if item.icon == nil then return nil end
            local destination = customPerk and custom or native
            destination[#destination + 1] = item
        end
    end
    local combined = {}
    for _, item in ipairs(native) do combined[#combined + 1] = item end
    for _, item in ipairs(custom) do combined[#combined + 1] = item end
    local rows = {}
    local bottom, upper = {}, {}
    if #combined <= CUSTOM_PERK_ROW_LIMIT then
        bottom = combined
    else
        local charged = {}
        for _, item in ipairs(combined) do
            if CHARGE_BAR_REFS[tostring(item.ref)] then
                charged[#charged + 1] = item
            elseif #bottom < CUSTOM_PERK_ROW_LIMIT then
                bottom[#bottom + 1] = item
            else
                upper[#upper + 1] = item
            end
        end
        for _, item in ipairs(charged) do upper[#upper + 1] = item end
    end
    appendPerkRows(rows, bottom, 0, CUSTOM_PERK_ROW_LIMIT)
    appendPerkRows(rows, upper, 1, CUSTOM_PERK_ROW_LIMIT)
    return rows, #combined
end
local function buildOverflowRows(items)
    local rows = {}
    appendPerkRows(rows, items, 1, 15)
    return rows
end
local function nativeEternalHudRefs()
    local refs = {}
    local getRef = g(rawget(_G, "ZMPERK"), "getperkrefbyid")
    if type(getRef) ~= "function" then return refs end
    local function mark(id)
        local ok, ref = pcall(getRef, id)
        if ok and ref ~= nil then
            refs[NATIVE_HUD_KEY[ref] or NATIVE_HUD_KEY[tostring(ref)] or tostring(ref)] = true
        end
    end
    local getOmnvar = g(rawget(_G, "Game"), "getomnvar")
    if type(getOmnvar) == "function" then
        for page = 1, 4 do
            local ok, packed = pcall(getOmnvar, 0, "ui_active_perks_" .. page)
            packed = ok and tonumber(packed) or nil
            if packed then
                packed = packed % 4294967296
                for slot = 0, 3 do
                    local bits = math.floor(packed / 2 ^ (slot * 7)) % 128
                    local id = bits % 32
                    if id > 0 and math.floor(bits / 32) % 2 == 1 then mark(id) end
                end
            end
        end
    end
    local function field(object, key)
        if object == nil then return nil end
        local hashed = type(key) == "string" and hk(key) or nil
        if hashed ~= nil then
            local ok, result = pcall(function() return object[hashed] end)
            if ok and result ~= nil then return result end
        end
        local ok, result = pcall(function() return object[key] end)
        if ok then return result end
    end
    local node = rawget(_G, "_DataSources")
    for _, key in ipairs({"zm", "in_game", "player", "perks", "active_perks"}) do
        node = field(node, key)
        if node == nil then return refs end
    end
    local function value(source)
        local getter = field(source, "GetValue")
        if type(getter) ~= "function" then return nil end
        local ok, result = pcall(getter, source, 0)
        if ok then return result end
    end
    local count = math.max(0, math.min(64, tonumber(value(field(node, "count"))) or 0))
    for index = 1, count do
        local entry = field(node, index)
        local permanent = value(field(entry, "is_perm"))
        if permanent == true or tonumber(permanent) == 1 then
            local id = value(field(entry, "id"))
            if id ~= nil then
                mark(id)
            end
        end
    end
    return refs
end
local function retainNativeEternalRefs(rows, observed)
    local retained = {}
    for _, row in ipairs(rows) do
        local ref = row.item and row.item.ref
        local key = ref and (NATIVE_HUD_KEY[ref] or NATIVE_HUD_KEY[tostring(ref)])
        if key and (observed[key] or (S.eternalPerkRefs and S.eternalPerkRefs[key]) or
            (S.nativeEternalOwned and S.nativeEternalOwned[key])) then
            retained[key] = true
        end
    end
    S.nativeEternalOwned = retained
    return retained
end
local function hudPerkMaterial(item, pack)
    local ref = item and item.ref
    local custom = ref and (byRef[ref] or byRef[tostring(ref)])
    local iconValue = (custom and (custom.hudIcon or custom.icon)) or (ref and (PERK_PACK_ICONS[ref] or PERK_PACK_ICONS[tostring(ref)])) or (item and overflowPerkIconValue(item, 0))
    if iconValue == nil then return nil end
    iconValue = customPackIcon(iconValue)
    local iconKey = pack .. ":" .. tostring(iconValue)
    local materialCache = S.stockHudPerkMaterials or {}
    S.stockHudPerkMaterials = materialCache
    local material = materialCache[iconKey]
    if material == nil then
        local asset = iconValue
        local hashAsset = rawget(_G, "xhashasset") or g(rawget(_G, "CLUA"), "PushXHashAsset")
        if type(iconValue) == "string" and type(hashAsset) == "function" then
            local okAsset, pushed = pcall(hashAsset, iconValue)
            if okAsset and pushed ~= nil then asset = pushed end
        end
        local register = rawget(_G, "RegisterMaterial")
        if type(register) ~= "function" then return nil end
        local okMaterial, registered = pcall(register, asset)
        if not okMaterial or registered == nil then return nil end
        material = registered
        materialCache[iconKey] = material
    end
    return iconKey, material
end
BO7PerkHotbar = BO7PerkHotbar or {}
BO7PerkHotbar.list = function()
    local refs = stockHudAllPerkRefs()
    if not refs then return nil end
    local pack = readDebugDvar("kr_perk_icons") or ""
    local out, seen = {}, {}
    for _, ref in ipairs(refs) do
        local custom = byRef[ref] or byRef[tostring(ref)]
        local key = custom and custom.ref or tostring(ref)
        if not seen[key] then
            seen[key] = true
            local iconKey, material = hudPerkMaterial(stockHudPerkItemByRef(ref), pack)
            if material then out[#out + 1] = { ref = key, key = iconKey, material = material } end
        end
    end
    return out
end
local function renderStockHudPerkIcons(root, rows, total)
    local nativeEternal = retainNativeEternalRefs(rows, nativeEternalHudRefs())
    local icons = S.overflowPerkIcons
    local pack = readDebugDvar("kr_perk_icons") or ""
    if S.activePerkIconPack ~= pack then
        S.activePerkIconPack = pack
        S.stockHudPerkMaterials = {}
        do end
    end
    local scale = 1.5 * math.max(0.82, 1 - math.max(0, total - CUSTOM_PERK_ROW_LIMIT) * 0.004)
    local materials = {}
    local selectedEternalFrame
    local frameStyle = tonumber(readDebugDvar("bo7_cp_eternal_frame_style")) or 0
    for _, entry in ipairs(rawget(_G, "BO7EternalFramePacks") or {}) do
        if entry.id == frameStyle then selectedEternalFrame = entry; break end
    end
    local eternalImage = selectedEternalFrame and selectedEternalFrame.material or "ui_icon_eternalperk"
    if S.eternalFrameImage ~= eternalImage then
        S.eternalFrameImage = eternalImage
        S.eternalFrameMaterial = nil
    end
    local eternalMaterial = S.eternalFrameMaterial
    if eternalMaterial == nil then
        local register = rawget(_G, "RegisterMaterial")
        local hashAsset = rawget(_G, "xhashasset") or g(rawget(_G, "CLUA"), "PushXHashAsset")
        if type(register) == "function" and type(hashAsset) == "function" then
            local ok, material = pcall(function() return register(hashAsset(eternalImage)) end)
            if ok and material then S.eternalFrameMaterial = material; eternalMaterial = material end
        end
    end
    for ordinal, row in ipairs(rows) do
        local iconKey, material = hudPerkMaterial(row.item, pack)
        if not material then return false end
        materials[ordinal] = { key = iconKey, value = material }
    end
    local okRender, renderError = pcall(function()
        for ordinal, row in ipairs(rows) do
            local slot = icons[ordinal]
            local isNew = slot == nil
            if isNew then
                local frame = LUI.UIElement.new()
                frame:SetHandleMouse(false)
                local image = LUI.UIImage.new()
                image:SetHandleMouse(false)
                local border = LUI.UIImage.new()
                border:SetHandleMouse(false)
                border:SetAlpha(0, 0)
                local chargeBackground = LUI.UIImage.new()
                chargeBackground:SetHandleMouse(false)
                chargeBackground:SetAlpha(0, 0)
                frame:addElement(chargeBackground)
                local widowBackground = LUI.UIImage.new()
                widowBackground:SetHandleMouse(false)
                widowBackground:SetAlpha(0, 0)
                frame:addElement(widowBackground)
                local blazeFlame = LUI.UIImage.new()
                blazeFlame:SetHandleMouse(false)
                blazeFlame:SetAlpha(0, 0)
                frame:addElement(blazeFlame)
                frame:addElement(image)
                frame:addElement(border)
                local bowstring = {}
                for i = 1, 2 do
                    local line = LUI.UIImage.new()
                    line:SetHandleMouse(false)
                    line:SetRGB(0xffffff)
                    line:SetAlpha(0, 0)
                    frame:addElement(line)
                    bowstring[i] = line
                end
                slot = { root = frame, image = image, eternalBorder = border, chargeBackground = chargeBackground, bowstring = bowstring, widowBackground = widowBackground, blazeFlame = blazeFlame }
            end
            local icon = slot.image
            if icon._bo7PerkIconKey ~= materials[ordinal].key then
                icon:setImage(materials[ordinal].value, 0)
                icon._bo7PerkIconKey = materials[ordinal].key
            end
            icon:SetAnchorsAndPosition(
                0, 1, 0, 1,
                scale, 31 * scale, 0, 30 * scale
            )
            local isCherry = row.item and tostring(row.item.ref) == "specialty_electric_cherry"
            local isWidow = row.item and tostring(row.item.ref) == "specialty_y_mod"
            if slot.widowBackground then
                local background = slot.widowBackground
                if isWidow then
                    if not S.widowBackgroundMaterial then
                        local hash = rawget(_G, "xhashasset") or g(rawget(_G, "CLUA"), "PushXHashAsset")
                        if type(hash) == "function" then S.widowBackgroundMaterial = RegisterMaterial(hash("gcp_perk_charge_shield")) end
                    end
                    if S.widowBackgroundMaterial then background:setImage(S.widowBackgroundMaterial, 0) end
                    background:SetAnchorsAndPosition(0, 1, 0, 1, scale, 31 * scale, 0, 30 * scale)
                    local shade = math.floor(math.max(0, math.min(100, S.widowChargePercent or 100)) * 255 / 100)
                    background:SetRGB(shade * 65793)
                end
                background:SetAlpha(isWidow and S.widowBackgroundMaterial and 1 or 0, 0)
            end
            local isBlaze = row.item and tostring(row.item.ref) == "specialty_blaze_phase"
            local isRoo = false
            if slot.blazeFlame then
                local flame = slot.blazeFlame
                local charge = 0
                if isBlaze or isRoo then
                    local getOmnvar = g(rawget(_G, "Game"), "getomnvar")
                    if type(getOmnvar) == "function" then
                        local okCharge, value = pcall(getOmnvar, 0, isRoo and "ui_br_objective_index" or "ui_br_objective_reward_tier")
                        charge = math.max(0, math.min(100, okCharge and tonumber(value) or 0)) / 100
                    end
                    if not S.blazeFlameMaterial then
                        local hash = rawget(_G, "xhashasset") or g(rawget(_G, "CLUA"), "PushXHashAsset")
                        if type(hash) == "function" then S.blazeFlameMaterial = RegisterMaterial(hash("gcp_perk_blaze_flame")) end
                    end
                end
                if (isBlaze or isRoo) and charge > 0 and S.blazeFlameMaterial then
                    flame:setImage(S.blazeFlameMaterial, 0)
                    local size = (40 + 14 * charge) * scale * (0.96 + math.random() * 0.08)
                    local centreX, centreY = 16 * scale, 15 * scale - 3
                    flame:SetAnchorsAndPosition(0, 1, 0, 1, centreX - size / 2, centreX + size / 2, centreY - size / 2, centreY + size / 2)
                    flame:SetAlpha(0.35 + 0.65 * charge, 0)
                else
                    flame:SetAlpha(0, 0)
                end
            end
            local isHunter = row.item and tostring(row.item.ref) == "specialty_hunters_mark"
            if slot.bowstring then
                local size = 30 * scale
                local charge = math.max(0, math.min(100, S.hunterChargePercent or 100)) / 100
                local centreX, centreY = 108 - 58 * charge, 111
                for i, line in ipairs(slot.bowstring) do
                    local x1, y1 = 108, i == 1 and 29 or 193
                    local dx, dy = centreX - x1, centreY - y1
                    local length = math.sqrt(dx * dx + dy * dy) * size / 256
                    local angle
                    if dx == 0 then angle = dy >= 0 and 90 or -90
                    else angle = math.deg(math.atan(dy / dx)); if dx < 0 then angle = angle + 180 end end
                    local x = scale + (x1 + centreX) * 0.5 * size / 256
                    local y = (y1 + centreY) * 0.5 * size / 256
                    local thickness = math.max(1, size * 3 / 256)
                    line:SetAnchorsAndPosition(0, 1, 0, 1, x - length / 2, x + length / 2, y - thickness / 2, y + thickness / 2)
                    line:SetZRotation(-angle, 0)
                    line:SetAlpha(isHunter and 1 or 0, 0)
                end
            end
            local background = slot.chargeBackground
            if background then
                local right = 31 * scale - 3
                background:SetAnchorsAndPosition(0, 1, 0, 1, right - 30, right, 3, 33)
                local charge = math.max(0, math.min(100, S.cherryChargePercent or 100)) / 100
                background:SetRGB(math.floor((1 - charge) * 255) * 65536 + math.floor(charge * 255) * 256)
                background:SetAlpha(isCherry and 1 or 0, 0)
            end
            local cooldownRef = row.item and tostring(row.item.ref)
            local cooldownPercent
            if cooldownRef == "specialty_banana_colada" then cooldownPercent = S.bananaChargePercent or 100 end
            if cooldownRef == "specialty_blood_wolf_bite" then cooldownPercent = S.wolfChargePercent or 100 end
            if cooldownRef == "specialty_killstreak_kool_aid" then
                local page = (S.hudPages and S.hudPages[24]) or 0
                cooldownPercent = (math.floor(page / 12) % 2 == 0) and math.floor(page / 24) * 2 or 0
            end
            if cooldownRef == "specialty_samurais_sake" then cooldownPercent = (S.hudPages and S.hudPages[23]) or 0 end
            if not slot.cooldownTrack then
                slot.cooldownTrack=LUI.UIImage.new();slot.cooldownFill=LUI.UIImage.new()
                for _,bar in ipairs({slot.cooldownTrack,slot.cooldownFill})do
                    bar:SetHandleMouse(false);slot.root:addElement(bar)
                end
            end
            local progress=math.max(0,math.min(100,cooldownPercent or 0))/100
            slot.cooldownTrack:SetAnchorsAndPosition(0,1,0,1,0,30*scale,-5*scale,-1*scale)
            slot.cooldownTrack:SetRGB(0x101018)
            slot.cooldownFill:SetAnchorsAndPosition(0,1,0,1,scale,(1+28*progress)*scale,-4*scale,-2*scale)
            slot.cooldownFill:SetRGB(0x50c8ff)
            slot.cooldownTrack:SetAlpha(cooldownPercent and 0.9 or 0,0)
            slot.cooldownFill:SetAlpha(cooldownPercent and progress>0 and 1 or 0,0)
            local ref = row.item and row.item.ref
            local refKey = ref and (NATIVE_HUD_KEY[ref] or NATIVE_HUD_KEY[tostring(ref)] or tostring(ref))
            local eternal = refKey and (nativeEternal[refKey] == true or
                (S.eternalPerkRefs and (S.eternalPerkRefs[refKey] == true or S.eternalPerkRefs[tostring(ref)] == true)))
            if slot.eternalBorder then
                if eternalMaterial then slot.eternalBorder:setImage(eternalMaterial, 0) end
                local iconSize = 30 * scale
                local frameScale = 1.10
                local source = selectedEternalFrame or {width = 320, height = 308, centerX = 156, centerY = 156, referenceSize = 256}
                frameScale = source.scale or frameScale
                local frameWidth = iconSize * (source.width / source.referenceSize) * frameScale
                local frameHeight = iconSize * (source.height / source.referenceSize) * frameScale
                local frameLeft = scale + iconSize / 2 - frameWidth * (source.centerX / source.width)
                local frameTop = iconSize / 2 - frameHeight * (source.centerY / source.height)
                slot.eternalBorder:SetAnchorsAndPosition(0, 1, 0, 1, frameLeft, frameLeft + frameWidth, frameTop, frameTop + frameHeight)
                slot.eternalBorder:SetAlpha(eternal and eternalMaterial and 1 or 0, 0)
            end
            local left = -row.rowCount * 34 / 2 + row.column *34
            if DEBUG_PERK_HUD_AT_TOP then
                local yTop = 24 + row.row * 41
                slot.root:SetAnchorsAndPosition(
                    0.5, 0.5, 0, 1,
                    left * scale, (left + 32) * scale,
                    yTop * scale, (yTop + 41) * scale
                )
            else
                local yTop = -41 - (row.row * CUSTOM_PERK_ROW_SPACING)
                    + CUSTOM_PERK_ROW_VERTICAL_SHIFT
                slot.root:SetAnchorsAndPosition(
                    0.5, 0.5, 1, 0,
                    left * scale, (left + 32) * scale,
                    yTop * scale, (yTop + 41) * scale
                )
            end
            slot.root:SetAlpha(1, 0)
            local layer = S.perkIconLayer
            if not layer or S.perkIconLayerRoot ~= root then
                layer = LUI.UIElement.new()
                layer.id = "bo7customperkicons"
                layer:SetAnchorsAndPosition(0, 0, 0, 0, 0, 0, 0, 0)
                root:addElement(layer)
                S.perkIconLayer, S.perkIconLayerRoot = layer, root
            end
            local okParent, parent = pcall(function() return slot.root:getParent() end)
            if not okParent or parent ~= layer then
                if okParent and parent then
                    if not pcall(function() slot.root:RemoveFromParent() end) then pcall(function() parent:RemoveElement(slot.root) end) end
                end
                layer:addElement(slot.root)
            end
            if isNew then icons[ordinal] = slot end
        end
        for ordinal = #rows + 1, #icons do
            icons[ordinal].root:SetAlpha(0, 0)
        end
    end)
    if not okRender then
        if not S.errOverflowRender then
            S.errOverflowRender = true
            do end
        end
        return false
    end
    return true
end
local function pauseMenuIsOpen()
    local cod = rawget(_G, "CoD")
    local getPauseMenu = g(cod, "GetPauseMenuFromCurrentContext")
    local flow = g(rawget(_G, "LUI"), "FlowManager")
    local isInStack = g(flow, "IsInStack")
    if type(getPauseMenu) ~= "function" or type(isInStack) ~= "function" then
        if not S.stockHudPauseCheckUnavailableLogged then
            S.stockHudPauseCheckUnavailableLogged = true
            do end
        end
        return false
    end
    local okMenu, menu = pcall(getPauseMenu)
    if not okMenu or menu == nil then return false end
    local okOpen, isOpen = pcall(isInStack, menu)
    return okOpen and isOpen == true
end
local function updateStockHudPerkOverflow()
    if perkHotbarActive() then
        closeOverflowPerkIcons()
        pcall(hideNativePerkVisibility)
        return
    end
    if customHudThemeActive() then
        restoreNativePerkContainer()
        closeOverflowPerkIcons()
        return
    end
    local engine = rawget(_G, "Engine")
    if type(engine) ~= "table" or type(engine.InFrontend) ~= "function" then
        restoreNativePerkContainer()
        closeOverflowPerkIcons()
        return
    end
    local okFrontend, frontend = pcall(engine.InFrontend)
    if not okFrontend or frontend then
        restoreNativePerkContainer()
        closeOverflowPerkIcons()
        return
    end
    local hudEditor = rawget(_G, "VegaHudEditor")
    if pauseMenuIsOpen() and not (type(hudEditor) == "table" and hudEditor.editing) then
        hideOverflowPerkIcons()
        return
    end
    local root = stockHudRoot()
    if not root then
        if not S.stockHudRootMissingLogged then
            S.stockHudRootMissingLogged = true
            do end
        end
        restoreNativePerkContainer()
        closeOverflowPerkIcons()
        return
    end
    if S.overflowPerkRoot ~= root then
        restoreNativePerkContainer()
        closeOverflowPerkIcons()
        S.overflowPerkRoot = root
        S.overflowPerkIcons = {}
    end
    local allRefs = stockHudAllPerkRefs()
    if allRefs then
        local nativeVisibilityHidden = false
        local nativeContainer = findNativePerkContainer(root)
        local fullRows, total = buildFullPerkRows(allRefs)
        if not fullRows then
            if not S.stockHudFullIconDataMissingLogged then
                S.stockHudFullIconDataMissingLogged = true
                do end
            end
        elseif renderStockHudPerkIcons(root, fullRows, total) then
            S.fullPerkHudRendered = true
            nativeVisibilityHidden = hideNativePerkVisibility()
            local nativeHidden = nativeContainer and hideNativePerkContainer(nativeContainer)
            local nativeStatus = nativeHidden and "widget hidden"
                or (nativeVisibilityHidden and "visibility model hidden" or "widget not found")
            local status = "GSC full total=" .. tostring(total) .. " native=" .. nativeStatus
            if S.stockHudOverflowStatus ~= status then
                S.stockHudOverflowStatus = status
                do end
            end
            return
        elseif nativeContainer and not S.stockHudPerkHideFailedLogged then
            S.stockHudPerkHideFailedLogged = true
            do end
        end
        if nativeVisibilityHidden or nativeContainer then
            hideOverflowPerkIcons()
            restoreNativePerkContainer()
            return
        end
        if not nativeContainer and not S.stockHudPerkContainerMissingLogged then
            S.stockHudPerkContainerMissingLogged = true
            do end
        end
    else
        restoreNativePerkContainer()
    end
    local overflowItems = {}
    local total
    local sourceName
    local owned = stockHudOwnedPerks()
    if owned then
        local native = owned.native or {}
        local custom = owned.custom or {}
        local combined = {}
        for _, item in ipairs(native) do combined[#combined + 1] = item end
        for _, item in ipairs(custom) do combined[#combined + 1] = item end
        total = #combined
        local activeOrder = stockHudActivePerkOrder()
        if activeOrder and (#activeOrder > 0 or total == 0) then
            local visibleRefs = {}
            for _, ref in ipairs(activeOrder) do
                local customItem = byRef[ref] or byRef[tostring(ref)]
                visibleRefs[customItem and customItem.ref or tostring(ref)] = true
            end
            for _, item in ipairs(combined) do
                local customItem = byRef[item.ref] or byRef[tostring(item.ref)]
                local key = customItem and customItem.ref or tostring(item.ref)
                if not visibleRefs[key] then
                    overflowItems[#overflowItems + 1] = item
                end
            end
            sourceName = "ZMPERK active"
        else
            for index = STOCK_HUD_NATIVE_PERK_LIMIT + 1, #combined do
                overflowItems[#overflowItems + 1] = combined[index]
            end
            sourceName = "ZMPERK catalog"
        end
    else
        local list = overflowPerkList()
        if list then
            local okCount, count = pcall(function() return list:GetCountValue(0) end)
            if okCount and tonumber(count) then
                total = math.max(0, math.floor(tonumber(count)))
                for index = STOCK_HUD_NATIVE_PERK_LIMIT, total do
                    local okItem, item = pcall(function() return list:GetDataSourceAtIndex(index - 1, 0) end)
                    if okItem and item ~= nil then overflowItems[#overflowItems + 1] = item end
                end
                sourceName = "HUD"
            end
        end
        if total == nil then
            if not S.stockHudListMissingLogged then
                S.stockHudListMissingLogged = true
                do end
            end
            hideOverflowPerkIcons()
            return
        end
    end
    local serverOverflowRefs = stockHudOverflowPerkRefs()
    if serverOverflowRefs then
        overflowItems = {}
        total = STOCK_HUD_NATIVE_PERK_LIMIT + #serverOverflowRefs
        for _, ref in ipairs(serverOverflowRefs) do
            overflowItems[#overflowItems + 1] = stockHudPerkItemByRef(ref)
        end
        sourceName = "GSC overflow"
    end
    local extra = #overflowItems
    local status = sourceName .. " total=" .. tostring(total) .. " extra=" .. tostring(extra)
    if S.stockHudOverflowStatus ~= status then
        S.stockHudOverflowStatus = status
        do end
    end
    local rows = buildOverflowRows(overflowItems)
    if not renderStockHudPerkIcons(root, rows, total) then hideOverflowPerkIcons() end
end
local VITALITY_REF = "specialty_vitality"
local VITALITY_REF_HASH = hk(VITALITY_REF)
local VITALITY_AUGMENTS = {
    major = {
        { name = "Rapid Recovery", description = "Doubles healing while crouched." },
        { name = "Siphon Pulse", description = "Damages nearby zombies while crouched." },
    },
    minor = {
        { name = "Potent Pulse", description = "Adds periodic healing while crouched." },
        { name = "Prone Recovery", description = "Also heals while prone." },
    },
}
local vitalitySelection = rawget(_G, "BO7VitalityAugmentSelection")
if type(vitalitySelection) ~= "table" then
    vitalitySelection = { major = 0, minor = 0, pending = { major = false, minor = false } }
    rawset(_G, "BO7VitalityAugmentSelection", vitalitySelection)
elseif type(vitalitySelection.pending) ~= "table" then
    vitalitySelection.pending = { major = false, minor = false }
end
local BANDOLIER_REF = "specialty_bandolier"
local BANDOLIER_REF_HASH = hk(BANDOLIER_REF)
local BANDOLIER_AUGMENTS = {
    major = {
        { name = "Stowed Reload", description = "Weapons you are not holding slowly refill their magazines from reserve ammo." },
        { name = "Deep Pockets", description = "Increases the extra reserve ammo from 50% to 100%." },
    },
    minor = {
        { name = "Restock", description = "At the end of every round, your weapons are refilled to the extended maximum." },
        { name = "Magazine Mule", description = "Killing a zombie has a 5% chance to refill the magazine of your held weapon." },
    },
}
local bandolierSelection = rawget(_G, "BO7BandolierAugmentSelection")
if type(bandolierSelection) ~= "table" then
    bandolierSelection = { major = 0, minor = 0, pending = { major = false, minor = false } }
    rawset(_G, "BO7BandolierAugmentSelection", bandolierSelection)
elseif type(bandolierSelection.pending) ~= "table" then
    bandolierSelection.pending = { major = false, minor = false }
end
local TORTOISE_REF = "specialty_tortoise"
local TORTOISE_REF_HASH = hk(TORTOISE_REF)
local TORTOISE_AUGMENTS = {
    major = {
        { name = "Thorns", description = "50% of the damage a zombie does to you is reflected back to the zombie." },
        { name = "Reinforced Shell", description = "Take an additional 5% less damage while wearing armor." },
    },
    minor = {
        { name = "Reserve Plate", description = "Hold an extra armor plate in reserve." },
        { name = "Crusader's Ale", description = "Half of your missing armor is repaired between rounds." },
    },
}
local tortoiseSelection = rawget(_G, "BO7TortoiseAugmentSelection")
if type(tortoiseSelection) ~= "table" then
    tortoiseSelection = { major = 0, minor = 0, pending = { major = false, minor = false } }
    rawset(_G, "BO7TortoiseAugmentSelection", tortoiseSelection)
elseif type(tortoiseSelection.pending) ~= "table" then
    tortoiseSelection.pending = { major = false, minor = false }
end
local GAUTYS_GOLD_REF = "specialty_gautys_gold"
local GAUTYS_GOLD_REF_HASH = hk(GAUTYS_GOLD_REF)
local GAUTYS_GOLD_AUGMENTS = {
    major = {
        { name = "Golden Payout", description = "Increases points from 1.25x to 1.35x while the perk is active." },
        { name = "Golden Refund", description = "Purchases have a 10% chance to refund their full cost." },
        { name = "Scrap Dividend", description = "Earn 25% more salvage." },
    },
    minor = {
        { name = "Golden Strike", description = "Awards double points for melee kills." },
        { name = "Gold Rush", description = "Headshot kills give 5% more points." },
        { name = "Bargain Hunter", description = "Purchases cost 5% less." },
        { name = "Payday", description = "At the end of every round, earn 5% of your current points." },
    },
}
local gautys_goldSelection = rawget(_G, "BO7GautysGoldAugmentSelection")
if type(gautys_goldSelection) ~= "table" then
    gautys_goldSelection = { major = 0, minor = 0, pending = { major = false, minor = false } }
    rawset(_G, "BO7GautysGoldAugmentSelection", gautys_goldSelection)
elseif type(gautys_goldSelection.pending) ~= "table" then
    gautys_goldSelection.pending = { major = false, minor = false }
end
local JUG2_REF = "specialty_jug2"
local JUG2_REF_HASH = hk(JUG2_REF)
local JUG2_AUGMENTS = {
    major = {
        { name = "Moon Hop", description = "Jump height becomes 2.5x. Jumping reduces your gravity by 50% for 5 seconds." },
        { name = "Hang Time", description = "Hold jump while falling to glide." },
        { name = "It's a Me!", description = "Landing on a normal zombie kills it and bounces you back up." },
    },
    minor = {
        { name = "Double Jump", description = "Press jump again while in the air to jump a second time." },
        { name = "Air Strafe", description = "Move 20% faster while in the air." },
        { name = "Spring Step", description = "Jumping out of a sprint carries you 20% further." },
        { name = "Gotta Go Fast!", description = "Sprint 10% faster." },
    },
}
local jug2Selection = rawget(_G, "BO7Jug2AugmentSelection")
if type(jug2Selection) ~= "table" then
    jug2Selection = { major = 0, minor = 0, pending = { major = false, minor = false } }
    rawset(_G, "BO7Jug2AugmentSelection", jug2Selection)
elseif type(jug2Selection.pending) ~= "table" then
    jug2Selection.pending = { major = false, minor = false }
end
local HUNTERS_MARK_REF = "specialty_hunters_mark"
local HUNTERS_MARK_REF_HASH = hk(HUNTERS_MARK_REF)
local HUNTERS_MARK_AUGMENTS = {
    major = {
        { name = "Bear the mark", description = "A marked zombie that drops below 20% health is killed by the next hit." },
        { name = "Cursed", description = "Marked zombies take 100% more damage instead of 50%." },
        { name = "Big Game Hunter", description = "Allows Hunter's Hooch to activate on special and elite zombies." },
    },
    minor = {
        { name = "Quick Hunt", description = "Cooldown time reduced by 50%." },
        { name = "Lingering Mark", description = "The mark lasts 6 seconds longer." },
        { name = "Open Season", description = "Killing the marked zombie resets the cooldown instantly." },
        { name = "Bounty", description = "Killing the marked zombie gives 25 points." },
    },
}
local hunters_markSelection = rawget(_G, "BO7HuntersMarkAugmentSelection")
if type(hunters_markSelection) ~= "table" then
    hunters_markSelection = { major = 0, minor = 0, pending = { major = false, minor = false } }
    rawset(_G, "BO7HuntersMarkAugmentSelection", hunters_markSelection)
elseif type(hunters_markSelection.pending) ~= "table" then
    hunters_markSelection.pending = { major = false, minor = false }
end
local ELECTRIC_CHERRY_REF = "specialty_electric_cherry"
local ELECTRIC_CHERRY_REF_HASH = hk(ELECTRIC_CHERRY_REF)
local ELECTRIC_CHERRY_AUGMENTS = {
    major = {
        { name = "Chain Lightning", description = "The reload shock can chain between zombies." },
        { name = "Static Salvage", description = "Zombies killed by the electric shock have a chance to give you an armor plate." },
        { name = "Unrestrained Current", description = "Allows Electric Cherry to activate on special and elite zombies." },
    },
    minor = {
        { name = "Quick Charge", description = "Cooldown time reduced by 50%." },
        { name = "Muscle Milk", description = "Melee hits on zombies also set off the electric shock (same cooldown)." },
        { name = "High Voltage", description = "The electric shock deals 5% more damage." },
        { name = "Long Fuse", description = "The stun lasts 4 seconds instead of 2." },
    },
}
local electric_cherrySelection = rawget(_G, "BO7ElectricCherryAugmentSelection")
if type(electric_cherrySelection) ~= "table" then
    electric_cherrySelection = { major = 0, minor = 0, pending = { major = false, minor = false } }
    rawset(_G, "BO7ElectricCherryAugmentSelection", electric_cherrySelection)
elseif type(electric_cherrySelection.pending) ~= "table" then
    electric_cherrySelection.pending = { major = false, minor = false }
end
local BLAZE_PHASE_REF = "specialty_blaze_phase"
local BLAZE_PHASE_REF_HASH = hk(BLAZE_PHASE_REF)
local BLAZE_PHASE_AUGMENTS = {
    major = {
        { name = "Wildfire", description = "The fire trail also burns special and elite zombies." },
        { name = "Flashpoint", description = "The dash ends in a fiery blast that damages and burns nearby zombies." },
        { name = "Firewalker", description = "You take no damage while dashing." },
        { name = "Running Hot", description = "Blaze Phase keeps charging while you move crouched." },
    },
    minor = {
        { name = "Inferno", description = "The fire trail deals 50% more damage." },
        { name = "Quick Ignition", description = "Charging is 25% faster: a full charge takes 5.6 seconds instead of 7.5." },
        { name = "Wide Burn", description = "Fire patches are 50% wider." },
        { name = "Slow Burn", description = "Fire patches last twice as long (40 seconds)." },
    },
}
local blaze_phaseSelection = rawget(_G, "BO7BlazePhaseAugmentSelection")
if type(blaze_phaseSelection) ~= "table" then
    blaze_phaseSelection = { major = 0, minor = 0, pending = { major = false, minor = false } }
    rawset(_G, "BO7BlazePhaseAugmentSelection", blaze_phaseSelection)
elseif type(blaze_phaseSelection.pending) ~= "table" then
    blaze_phaseSelection.pending = { major = false, minor = false }
end
local MAGNET_MARGARITA_REF = "specialty_magnet_margarita"
local MAGNET_MARGARITA_REF_HASH = hk(MAGNET_MARGARITA_REF)
local MAGNET_MARGARITA_AUGMENTS = {
    major = {
        { name = "Lucky Charm", description = "Zombies you kill have an extra 2.5% chance to drop a powerup." },
        { name = "Lodestone", description = "Pulls powerups from twice as far away." },
        { name = "Double Dip", description = "Grabbing a powerup has a 15% chance to drop another." },
        { name = "Long Pour", description = "Timed powerups you grab (Insta-Kill, Double Points, Fire Sale) last 1.5x as long." },
    },
    minor = {
        { name = "Quick Pull", description = "Powerups drift toward you twice as fast." },
        { name = "Close Call", description = "Powerups come all the way to you and are picked up automatically." },
        { name = "Point Magnet", description = "Every powerup you grab gives 100 points." },
        { name = "Armor Magnet", description = "Every powerup you grab repairs 25% of your armor." },
    },
}
local magnet_margaritaSelection = rawget(_G, "BO7MagnetMargaritaAugmentSelection")
if type(magnet_margaritaSelection) ~= "table" then
    magnet_margaritaSelection = { major = 0, minor = 0, pending = { major = false, minor = false } }
    rawset(_G, "BO7MagnetMargaritaAugmentSelection", magnet_margaritaSelection)
elseif type(magnet_margaritaSelection.pending) ~= "table" then
    magnet_margaritaSelection.pending = { major = false, minor = false }
end
local BANANA_COLADA_REF = "specialty_banana_colada"
local BANANA_COLADA_REF_HASH = hk(BANANA_COLADA_REF)
local BANANA_COLADA_AUGMENTS = {
    major = {
        { name = "Slick Slide", description = "Slides are 15% faster and go 50% further." },
        { name = "Peel Out", description = "Sliding into zombies knocks them over." },
        { name = "Toxic Spill", description = "Slipped zombies are poisoned for 5 seconds." },
    },
    minor = {
        { name = "Long Spill", description = "The trail lasts twice as long (20 seconds)." },
        { name = "Wide Spill", description = "The trail is 50% wider." },
        { name = "Potent Peel", description = "Slips deal 15% of max health instead of 10%." },
        { name = "Slide Rush", description = "Move 10% faster for 3 seconds after a slide." },
        { name = "Quick Spill", description = "Reduce the trail cooldown from 15 seconds to 10 seconds." },
    },
}
local banana_coladaSelection = rawget(_G, "BO7BananaColadaAugmentSelection")
if type(banana_coladaSelection) ~= "table" then
    banana_coladaSelection = { major = 0, minor = 0, pending = { major = false, minor = false } }
    rawset(_G, "BO7BananaColadaAugmentSelection", banana_coladaSelection)
elseif type(banana_coladaSelection.pending) ~= "table" then
    banana_coladaSelection.pending = { major = false, minor = false }
end
local function augSelection(globalName)
    local sel = rawget(_G, globalName)
    if type(sel) ~= "table" then
        sel = { major = 0, minor = 0, pending = { major = false, minor = false } }
        rawset(_G, globalName, sel)
    elseif type(sel.pending) ~= "table" then
        sel.pending = { major = false, minor = false }
    end
    return sel
end
local DAM_A_NADE_REF = "specialty_dam_a_nade"
local DAM_A_NADE_AUGMENTS = {
    major = {
        { name = "Cluster Bomb", description = "Lethals split into 3 bomblets when they go off." },
        { name = "Scavenger", description = "Explosive kills have a 10% chance to refund a lethal." },
        { name = "Concussive Force", description = "Your explosions knock normal zombies over." },
    },
    minor = {
        { name = "Short Fuse", description = "Grenades explode 30% sooner." },
        { name = "Big Bang", description = "Zombies next to anything your explosives hit take half the damage too." },
        { name = "Deep Pockets", description = "Carry two extra lethals instead of one." },
        { name = "Shell Shock", description = "Zombies that survive your explosions are stunned for 2 seconds." },
    },
}
local PACK_A_BOX_REF = "specialty_pack_a_box"
local PACK_A_BOX_AUGMENTS = {
    major = {
        { name = "High Roller", description = "Every Pack-a-Punch chance is 50% higher." },
        { name = "Lucky Streak", description = "Getting a Pack-a-Punched box weapon makes your next box spin free." },
        { name = "Fire Sale Finder", description = "Each box spin has a 3% chance to drop a Fire Sale." },
        { name = "Rarity Bump", description = "Box weapons come out one rarity higher." },
    },
    minor = {
        { name = "Bargain Bin", description = "Box spins cost 10% less." },
        { name = "Second Look", description = "A spin that misses Pack-a-Punch gets a 25% chance to roll again." },
        { name = "Spin Streak", description = "Each spin that misses Pack-a-Punch adds 2% to the next one (resets on a hit)." },
        { name = "Salvage Spin", description = "Every box spin also gives 25 salvage." },
    },
}
local BLOOD_WOLF_BITE_REF = "specialty_blood_wolf_bite"
local BLOOD_WOLF_BITE_AUGMENTS = {
    major = {
        { name = "Pack Leader", description = "Summons two hounds instead of one." },
        { name = "Alpha", description = "Your hound deals triple damage to special and elite zombies." },
        { name = "Blood Bond", description = "While your hound is out, each kill it makes heals you 5%." },
    },
    minor = {
        { name = "Quick Call", description = "Cooldown 45 seconds -> 30." },
        { name = "Long Hunt", description = "The hound stays 45 seconds instead of 30." },
        { name = "Hellfire Hound", description = "The hound's bites set zombies on fire." },
        { name = "Hair Trigger", description = "Needs 5 zombies' worth of damage to summon instead of 8." },
    },
}
local BULL_ICE_BLAST_REF = "specialty_bull_ice_blast"
local BULL_ICE_BLAST_AUGMENTS = {
    major = {
        { name = "Shatter", description = "Zombies frozen by the slam take double damage until they thaw." },
        { name = "Aftershock", description = "The slam leaves an ice patch for 8 seconds that slows zombies." },
        { name = "Glacier", description = "The slam also freezes special and elite zombies." },
    },
    minor = {
        { name = "Cold Snap", description = "Slam cooldown 4 seconds -> 2.5." },
        { name = "Wide Impact", description = "Slam radius 30% larger." },
        { name = "Deep Freeze", description = "The freeze lasts 5 seconds instead of 3." },
        { name = "Frostbite", description = "Frozen zombies take 2% of their max health every second." },
    },
}
local AXE_SHOT_REF = "specialty_axe_shot"
local AXE_SHOT_AUGMENTS = {
    major = {
        { name = "Ricochet", description = "After its first hit, the axe flies on to the nearest other zombie." },
        { name = "Executioner", description = "Axe hits instantly kill zombies under 15% health." },
        { name = "Twin Blades", description = "Each launch throws two axes in a small spread." },
    },
    minor = {
        { name = "Sharpened", description = "Axes deal 60% more weapon damage." },
        { name = "Fast Hands", description = "One axe every 0.2 seconds instead of 0.3, but each axe deals half damage." },
        { name = "Long Throw", description = "Axes fly 50% further." },
        { name = "Bleed Out", description = "Zombies hit by an axe bleed for 1% of max health a second for 3 seconds." },
    },
}
local KILLSTREAK_KOOL_AID_REF = "specialty_killstreak_kool_aid"
local KILLSTREAK_KOOL_AID_AUGMENTS = {
    major = {
        { name = "Streak Feed", description = "Kills made by your killstreaks count double toward the next one." },
        { name = "Double Batch", description = "Each reward has a 20% chance to be two killstreaks." },
        { name = "Oh Yeah!", description = "Earning a killstreak blasts every zombie within 300 units of you." },
    },
    minor = {
        { name = "Refill", description = "Needs 120 kills instead of 150." },
        { name = "Brain Freeze", description = "Critical kills count double." },
        { name = "Sugar Rush", description = "Earning a killstreak refills your ammo." },
        { name = "Tall Glass", description = "Earning a killstreak gives 1000 Essence." },
    },
}
local WHOS_WHO_REF = "specialty_whos_who"
local WHOS_WHO_AUGMENTS = {
    major = {
        { name = "Fresh Start", description = "If your clone isn't revived in time, you live on as a fresh spawn instead of dying." },
        { name = "Hand-Me-Down", description = "Your ghost pistol has the Pack-a-Punch level and rarity of the gun you were holding." },
    },
    minor = {
        { name = "Extra Time", description = "1.5x as long to revive your clone (90 seconds)." },
    },
}
local AUG_PERKS = {
    { key = "magnet_margarita", label = "Magnet Margarita", ref = MAGNET_MARGARITA_REF, refHash = MAGNET_MARGARITA_REF_HASH, augments = MAGNET_MARGARITA_AUGMENTS,
      selection = magnet_margaritaSelection, pickDvar = "bo7_cp_magnet_margarita_pick", syncBase = 13000, ackDvar = "bo7_cp_magnet_margarita_pick_ack", minorLootOffset = 10, lootBase = 2147481080 },
    { key = "banana_colada", label = "Banana Colada", ref = BANANA_COLADA_REF, refHash = BANANA_COLADA_REF_HASH, augments = BANANA_COLADA_AUGMENTS,
      selection = banana_coladaSelection, pickDvar = "bo7_cp_banana_colada_pick", syncBase = 14000, ackDvar = "bo7_cp_banana_colada_pick_ack", minorLootOffset = 10, lootBase = 2147481100 },
    { key = "dam_a_nade", label = "Dam-A-Nade", ref = DAM_A_NADE_REF, refHash = hk(DAM_A_NADE_REF), augments = DAM_A_NADE_AUGMENTS,
      selection = augSelection("BO7DamANadeAugmentSelection"), pickDvar = "bo7_cp_dam_a_nade_pick", syncBase = 15000, ackDvar = "bo7_cp_dam_a_nade_pick_ack", minorLootOffset = 10, lootBase = 2147481120 },
    { key = "pack_a_box", label = "Pack-A-Box", ref = PACK_A_BOX_REF, refHash = hk(PACK_A_BOX_REF), augments = PACK_A_BOX_AUGMENTS,
      selection = augSelection("BO7PackABoxAugmentSelection"), pickDvar = "bo7_cp_pack_a_box_pick", syncBase = 16000, ackDvar = "bo7_cp_pack_a_box_pick_ack", minorLootOffset = 10, lootBase = 2147481140 },
    { key = "blood_wolf_bite", label = "Blood Wolf Bite", ref = BLOOD_WOLF_BITE_REF, refHash = hk(BLOOD_WOLF_BITE_REF), augments = BLOOD_WOLF_BITE_AUGMENTS,
      selection = augSelection("BO7BloodWolfBiteAugmentSelection"), pickDvar = "bo7_cp_blood_wolf_bite_pick", syncBase = 17000, ackDvar = "bo7_cp_blood_wolf_bite_pick_ack", minorLootOffset = 10, lootBase = 2147481160 },
    { key = "bull_ice_blast", label = "Ice Cold Cola", ref = BULL_ICE_BLAST_REF, refHash = hk(BULL_ICE_BLAST_REF), augments = BULL_ICE_BLAST_AUGMENTS,
      selection = augSelection("BO7BullIceBlastAugmentSelection"), pickDvar = "bo7_cp_bull_ice_blast_pick", syncBase = 18000, ackDvar = "bo7_cp_bull_ice_blast_pick_ack", minorLootOffset = 10, lootBase = 2147481180 },
    { key = "axe_shot", label = "Axe Shot", ref = AXE_SHOT_REF, refHash = hk(AXE_SHOT_REF), augments = AXE_SHOT_AUGMENTS,
      selection = augSelection("BO7AxeShotAugmentSelection"), pickDvar = "bo7_cp_axe_shot_pick", syncBase = 19000, ackDvar = "bo7_cp_axe_shot_pick_ack", minorLootOffset = 10, lootBase = 2147481200 },
    { key = "killstreak_kool_aid", label = "Killstreak Kool-Aid", ref = KILLSTREAK_KOOL_AID_REF, refHash = hk(KILLSTREAK_KOOL_AID_REF), augments = KILLSTREAK_KOOL_AID_AUGMENTS,
      selection = augSelection("BO7KillstreakKoolAidAugmentSelection"), pickDvar = "bo7_cp_killstreak_kool_aid_pick", syncBase = 20000, ackDvar = "bo7_cp_killstreak_kool_aid_pick_ack", minorLootOffset = 10, lootBase = 2147481220 },
    { key = "whos_who", label = "Who's Who", ref = WHOS_WHO_REF, refHash = hk(WHOS_WHO_REF), augments = WHOS_WHO_AUGMENTS,
      selection = augSelection("BO7WhosWhoAugmentSelection"), pickDvar = "bo7_cp_whos_who_pick", syncBase = 22000, ackDvar = "bo7_cp_whos_who_pick_ack", minorLootOffset = 10, lootBase = 2147481240 },
    { key = "blaze_phase", label = "Blaze Phase", ref = BLAZE_PHASE_REF, refHash = BLAZE_PHASE_REF_HASH, augments = BLAZE_PHASE_AUGMENTS,
      selection = blaze_phaseSelection, pickDvar = "bo7_cp_blaze_phase_pick", syncBase = 12000, ackDvar = "bo7_cp_blaze_phase_pick_ack", minorLootOffset = 10, lootBase = 2147481060 },
    { key = "electric_cherry", label = "Electric Cherry", ref = ELECTRIC_CHERRY_REF, refHash = ELECTRIC_CHERRY_REF_HASH, augments = ELECTRIC_CHERRY_AUGMENTS,
      selection = electric_cherrySelection, pickDvar = "bo7_cp_electric_cherry_pick", syncBase = 6000, ackDvar = "bo7_cp_electric_cherry_pick_ack", minorLootOffset = 5, lootBase = 2147483050 },
    { key = "hunters_mark", label = "Hunter's Hooch", ref = HUNTERS_MARK_REF, refHash = HUNTERS_MARK_REF_HASH, augments = HUNTERS_MARK_AUGMENTS,
      selection = hunters_markSelection, pickDvar = "bo7_cp_hunters_mark_pick", syncBase = 11000, ackDvar = "bo7_cp_hunters_mark_pick_ack", minorLootOffset = 10, lootBase = 2147481040 },
    { key = "jug2", label = "Roo Brew", ref = JUG2_REF, refHash = JUG2_REF_HASH, augments = JUG2_AUGMENTS,
      selection = jug2Selection, pickDvar = "bo7_cp_jug2_pick", syncBase = 10000, ackDvar = "bo7_cp_jug2_pick_ack", minorLootOffset = 10, lootBase = 2147481020 },
    { key = "bandolier", label = "Bandolier Bandit", ref = BANDOLIER_REF, refHash = BANDOLIER_REF_HASH, augments = BANDOLIER_AUGMENTS,
      selection = bandolierSelection, pickDvar = "bo7_cp_bandolier_pick", syncBase = 8000, ackDvar = "bo7_cp_bandolier_pick_ack", lootBase = 2147483020 },
    { key = "tortoise", label = "Victorious Tortoise", ref = TORTOISE_REF, refHash = TORTOISE_REF_HASH, augments = TORTOISE_AUGMENTS,
      selection = tortoiseSelection, pickDvar = "bo7_cp_tortoise_pick", syncBase = 7000, ackDvar = "bo7_cp_tortoise_pick_ack", lootBase = 2147483030 },
    { key = "gautys_gold", label = "Gauty's Gold", ref = GAUTYS_GOLD_REF, refHash = GAUTYS_GOLD_REF_HASH, augments = GAUTYS_GOLD_AUGMENTS,
      selection = gautys_goldSelection, pickDvar = "bo7_cp_gautys_gold_pick", syncBase = 4000, ackDvar = "bo7_cp_gold_pick_ack", lootBase = 2147483040 },
    { key = "vitality", label = "Vitality", ref = VITALITY_REF, refHash = VITALITY_REF_HASH, augments = VITALITY_AUGMENTS,
      selection = vitalitySelection, pickDvar = "bo7_cp_vitality_pick", syncBase = 5000, ackDvar = "bo7_cp_vitality_pick_ack", minorLootOffset = 10, lootBase = 2147481000 },
}
local function augPerkFor(ref)
    if ref == nil then return nil end
    for _, p in ipairs(AUG_PERKS) do
        if ref == p.ref or (p.refHash ~= nil and (ref == p.refHash or tostring(ref) == tostring(p.refHash))) then
            return p
        end
    end
    return nil
end
local function tryWriteAugmentDvar(name, value)
    local store = settingsStore(name)
    if store then return store.set(name, tostring(value)) end
    local dvar = rawget(_G, "Dvar")
    local setter = g(dvar, "SetDvarString")
    local hashDvar = rawget(_G, "xhashdvar") or rawget(_G, "PushXHashDvar")
    local clua = rawget(_G, "CLUA")
    if type(hashDvar) ~= "function" and type(clua) == "table" then
        hashDvar = g(clua, "PushXHashDvar")
    end
    local expected = tostring(value)
    local engine = rawget(_G, "Engine")
    local execNow = g(engine, "ExecNow")
    local ok, result = false, "setter unavailable"
    if type(setter) == "function" and type(hashDvar) == "function" then
        local okHash, dvarHash = pcall(hashDvar, name)
        if okHash then
            ok, result = pcall(setter, dvarHash, expected)
            local actual = readDebugDvar(name)
            if ok and actual == expected then return true end
        else
            result = "Dvar hash failed"
        end
    end
    if type(execNow) == "function" then
        local commandOk, commandError = pcall(execNow, "set " .. name .. " " .. expected .. "\n", 0)
        if not commandOk then
            do end
        end
        if readDebugDvar(name) == expected then return true end
    end
    if not vitalitySelection.failureLogged[name] then
        vitalitySelection.failureLogged[name] = true
        do end
    end
    return false
end
local PICK_DVAR = "bo7_cp_vitality_pick"
local function dvarTokenCandidates(name)
    local hashDvar = rawget(_G, "xhashdvar") or rawget(_G, "PushXHashDvar")
    local clua = rawget(_G, "CLUA")
    if type(hashDvar) ~= "function" and type(clua) == "table" then hashDvar = g(clua, "PushXHashDvar") end
    if type(hashDvar) ~= "function" then return {} end
    local ok, h = pcall(hashDvar, name)
    if not ok or h == nil then return {} end
    local list = {}
    local function add(t) if t and t ~= "" then list[#list + 1] = t end end
    local okT, text = pcall(tostring, h)
    if okT and type(text) == "string" then add(text:match("#x%x+")) end
    if type(h) == "string" then
        if h:sub(1, 2) == "#x" then add(h) else add("#x3" .. h); add("#x" .. h); add(h) end
    else
        local okF, hex = pcall(string.format, "%x", h)
        if not okF and math.tointeger then
            local okI, i = pcall(math.tointeger, h)
            if okI and i then okF, hex = pcall(string.format, "%x", i) end
        end
        if okF and hex then add("#x3" .. hex); add("#x" .. hex) end
        if okT then add(text) end
    end
    return list
end
local function persistDvar(name, value)
    local store = settingsStore(name)
    if store then
        local ok = store.set(name, tostring(value))
        if not ok then do end  end
        return ok
    end
    local engine = rawget(_G, "Engine")
    local execNow = g(engine, "ExecNow")
    if type(execNow) ~= "function" then
        if not S.errPersist then S.errPersist = true; do end  end
        return false
    end
    local expected = tostring(value)
    local list = dvarTokenCandidates(name)
    if S.goodTokenIndex and list[S.goodTokenIndex] then
        table.insert(list, 1, list[S.goodTokenIndex])
    end
    for i, token in ipairs(list) do
        pcall(execNow, "set " .. token .. " " .. expected .. "\n", 0)
        if readDebugDvar(name) == expected then
            if not S.goodToken then
                S.goodToken = true
                do end
            end
            return true
        end
    end
    if not S.errPersistFail then
        S.errPersistFail = true
        local tried = {}
        for _, t in ipairs(list) do tried[#tried + 1] = t end
        do end
    end
    return false
end
local function persistSelection(perk)
    perk = perk or AUG_PERKS[1]
    if not perk then return false end
    local major = math.max(0, math.min(#perk.augments.major, tonumber(perk.selection.major) or 0))
    local minor = math.max(0, math.min(#perk.augments.minor, tonumber(perk.selection.minor) or 0))
    local bonus = math.max(0, math.min(#perk.augments.minor, tonumber(perk.selection.bonus) or 0))
    if bonus == minor then bonus = 0 end
    return persistDvar(perk.pickDvar, bonus * 100 + major * 10 + minor)
end
local function loadOnePersisted(perk)
    if S.pickLoaded[perk.key] then return true end
    local raw = readDebugDvar(perk.pickDvar)
    if raw == nil then
        S.pickLoadTries[perk.key] = (S.pickLoadTries[perk.key] or 0) + 1
        return false
    end
    S.pickLoaded[perk.key] = true
    do end
    local n = tonumber(raw)
    if n and n >= 0 and n <= 999 then
        n = math.floor(n)
        local low = n % 100
        perk.selection.major = math.floor(low / 10)
        if perk.selection.major > #perk.augments.major then perk.selection.major=0 end
        perk.selection.minor = low % 10
        perk.selection.bonus = math.floor(n / 100)
        do end
    end
    return true
end
local function loadPersistedSelection()
    for _, perk in ipairs(AUG_PERKS) do
        loadOnePersisted(perk)
    end
end
local function writeAugmentDvar(perk, slot, value)
    if not perk then return false end
    loadOnePersisted(perk)
    perk.selection[slot] = value
    perk.selection.pending[slot] = true
    S.pickLoaded[perk.key] = true
    persistSelection(perk)
    return true
end
local function flushVitalityAugments()
    if readDebugDvar("bo7_cp_debug_state") == nil then return end
    for _, slot in ipairs({ "major", "minor" }) do
        local name = "bo7_cp_vitality_" .. slot
        local selected = tonumber(vitalitySelection[slot]) or 0
        if vitalitySelection.pending[slot] or tonumber(readDebugDvar(name)) ~= selected then
            if tryWriteAugmentDvar(name, selected) then
                vitalitySelection.pending[slot] = false
                vitalitySelection.failureLogged[name] = nil
                do end
            end
        end
    end
end
local function hookAugmentFunction(object, name, tag, handler)
    if type(object) ~= "table" then return false end
    local keys = allFnKeys(object, name)
    if #keys == 0 then return false end
    local state = S.hooks[tag]
    if not state then
        state = { original = keys[1].fn }
        state.wrapper = function(...)
            return handler(state.original, ...)
        end
        S.hooks[tag] = state
    else
        local allInstalled = true
        for _, entry in ipairs(keys) do
            if entry.fn ~= state.wrapper then allInstalled = false end
        end
        if allInstalled then return true end
    end
    for _, entry in ipairs(keys) do object[entry.key] = state.wrapper end
    return true
end
local function installAugmentHooks()
    local perks = rawget(_G, "PERK")
    if type(perks) == "table" then
        hookAugmentFunction(perks, "getallperks", "augmentPerkList", function(original, ...)
            local list = original(...)
            if type(list) ~= "table" then return list end
            for _, item in ipairs(list) do
                if isVitalityRef(g(item, "ref")) then return list end
            end
            list[#list + 1] = { ref = VITALITY_REF_HASH or VITALITY_REF }
            return list
        end)
    end
    local augment = rawget(_G, "ZMAUGMENT")
    if type(augment) ~= "table" then return false end
    local loot = rawget(_G, "LOOT")
    hookAugmentFunction(augment, "createfullaugmentcache", "augmentFullCache", function(original, controller, equipmentList, equipmentType, ...)
        if equipmentType ~= g(g(augment, "equipment_type"), "perk") or type(equipmentList) ~= "table" then
            return original(controller, equipmentList, equipmentType, ...)
        end
        local filtered = {}
        for _, entry in ipairs(equipmentList) do
            local ref = g(entry, "ref")
            if not isVitalityRef(ref) then
                filtered[#filtered + 1] = entry
            end
        end
        return original(controller, filtered, equipmentType, ...)
    end)
    hookAugmentFunction(loot, "isunlockedwithid", "augmentUnlocked", function(original, controller, lootId, ...)
        if S.vitalityLootOptions[tonumber(lootId)] then return true end
        return original(controller, lootId, ...)
    end)
    hookAugmentFunction(augment, "initfullaugmentlist", "augmentFullList", function(original, ...)
        local result = original(...)
        local ok, err = pcall(ensureVitalityAugments)
        if not ok then do end  end
        return result
    end)
    hookAugmentFunction(augment, "inittypeaugmentlist", "augmentTypeList", function(original, controller, equipmentType, ...)
        local result = original(controller, equipmentType, ...)
        local perkType = g(g(augment, "equipment_type"), "perk")
        if equipmentType == perkType then
            local ok, err = pcall(ensureVitalityAugments)
            if not ok then do end  end
        end
        return result
    end)
    hookAugmentFunction(augment, "refreshaugmentlistdata", "augmentRefreshList", function(original, controller, ref, ...)
        local result = original(controller, ref, ...)
        if not isVitalityRef(ref) then return result end
        local ok, err = pcall(function()
            if not ensureVitalityAugments() then return end
            local dataSources = rawget(_G, "_DataSources")
            local zm = g(dataSources, "zm")
            local frontend = g(zm, "frontend")
            local select = g(frontend, "augment_select")
            local function updateRows(listName, definitions, rows)
                local list = g(select, listName)
                if type(list) ~= "table" then return end
                for index, definition in ipairs(definitions) do
                    local entry = list[index]
                    local item = g(entry, "item")
                    if type(item) == "table" then
                        for field, value in pairs({
                            name = definition.name,
                            description = definition.description,
                            is_unlocked = true,
                            loot_id = g(rows[index], "lootid"),
                        }) do
                            local setter = g(g(item, field), "SetValue")
                            if type(setter) == "function" then
                                local success, message = pcall(setter, g(item, field), controller, value)
                                if not success then error(message) end
                            end
                        end
                    end
                end
            end
            local major = g(g(augment, "augmentlist_major"), VITALITY_REF)
            local minor = g(g(augment, "augmentlist_minor"), VITALITY_REF)
            updateRows("major_augment_list", VITALITY_AUGMENTS.major, major)
            updateRows("minor_augment_list", VITALITY_AUGMENTS.minor, minor)
        end)
        if not ok then do end  end
        return result
    end)
    hookAugmentFunction(augment, "getequippedaugmentbyref", "augmentEquippedRead", function(original, controller, ref, slot, equipmentType, ...)
        if isVitalityRef(ref) and equipmentType == g(g(augment, "equipment_type"), "perk") then
            local selectionSlot = slot == g(g(augment, "slot"), "major") and "major" or "minor"
            local selected = tonumber(vitalitySelection[selectionSlot]) or 0
            return math.max(0, math.min(#VITALITY_AUGMENTS[selectionSlot], selected))
        end
        return original(controller, ref, slot, equipmentType, ...)
    end)
    hookAugmentFunction(augment, "modifyselectedaugment", "augmentEquippedWrite", function(original, controller, selected, lootId, ref, equipmentType, ...)
        if not isVitalityRef(ref) or equipmentType ~= g(g(augment, "equipment_type"), "perk") then
            return original(controller, selected, lootId, ref, equipmentType, ...)
        end
        local option = S.vitalityLootOptions[tonumber(lootId)]
        if not option then
            do end
            return
        end
        local dvarName = "bo7_cp_vitality_" .. option.slot
        local current = tonumber(vitalitySelection[option.slot]) or 0
        local value = current == option.index and 0 or option.index
        if not writeAugmentDvar(dvarName, option.slot, value) then return end
        local slot = option.slot == "major" and g(g(augment, "slot"), "major") or g(g(augment, "slot"), "minor")
        local refresh = g(augment, "refreshequippedaugmentdata")
        if type(refresh) == "function" then
            local ok, err = pcall(refresh, controller, slot, value)
            if not ok then do end  end
        end
        do end
    end)
    local perkList = g(rawget(_G, "ZMPERK"), "zmperklist")
    if type(perkList) == "table" then
        local found = false
        for _, entry in ipairs(perkList) do
            if isVitalityRef(g(entry, "ref")) then found = true; break end
        end
        if not found then
            local perk = rawget(_G, "PERK")
            local getBundle = perk and (g(perk, "GetBundleByRef"))
            if type(getBundle) == "function" then
                local bundle = getBundle(VITALITY_REF_HASH or VITALITY_REF)
                if bundle then
                    perkList[#perkList + 1] = { data = bundle, ref = VITALITY_REF_HASH or VITALITY_REF }
                    do end
                end
            end
        end
    end
    local requiredHooks = {
        "augmentPerkList", "augmentFullCache", "augmentUnlocked", "augmentFullList",
        "augmentTypeList", "augmentRefreshList", "augmentEquippedRead", "augmentEquippedWrite",
    }
    local allInstalled = true
    for _, tag in ipairs(requiredHooks) do
        if not S.hooks[tag] then allInstalled = false; break end
    end
    if allInstalled and not S.loggedAugmentHooks then
        S.loggedAugmentHooks = true
        do end
    end
    return true
end
local function installVitalityPerkList()
    local perks = rawget(_G, "ZMPERK")
    if type(perks) ~= "table" then return false end
    return hookAugmentFunction(perks, "getperklist", "vitalityPerkList", function(original, ...)
        local list = original(...)
        if type(list) ~= "table" then
            if not S.loggedPerkListFailure then
                S.loggedPerkListFailure = true
                do end
            end
            return list
        end
        for _, perk in ipairs(AUG_PERKS) do
            local present = false
            for _, entry in ipairs(list) do
                if augPerkFor(g(entry, "ref")) == perk then
                    present = true
                    if perk.key == "electric_cherry" then
                        local custom = byRef[perk.ref]
                        local bundle = custom and bundleFor(custom, S.hooks.perkOriginal)
                        if bundle then s(entry, "data", bundle) end
                    end
                    break
                end
            end
            if not present then
                local lib = rawget(_G, "PERK")
                local getBundle = lib and g(lib, "GetBundleByRef")
                local ref = perk.refHash or perk.ref
                local ok, bundle = false, nil
                if type(getBundle) == "function" then ok, bundle = pcall(getBundle, ref) end
                if ok and type(bundle) == "table" and g(bundle, "zombiesperk") and g(bundle, "showninmenu") then
                    local entry = {}
                    s(entry, "data", bundle)
                    s(entry, "ref", ref)
                    list[#list + 1] = entry
                    if not S["loggedPerkList_" .. perk.key] then
                        S["loggedPerkList_" .. perk.key] = true
                        do end
                    end
                elseif not S["loggedPerkListFail_" .. perk.key] then
                    S["loggedPerkListFail_" .. perk.key] = true
                    do end
                end
            end
        end
        return list
    end)
end
local function makeAugmentRows(perk)
    if not perk then return false end
    local augment = rawget(_G, "ZMAUGMENT")
    if type(augment) ~= "table" then return false end
    local full = g(augment, "augmentlist_full")
    local juggernog = g(full, "specialty_juggernog")
    if type(full) ~= "table" or type(juggernog) ~= "table" then return false end
    local majorType = g(g(augment, "type"), "major")
    local minorType = g(g(augment, "type"), "minor")
    local sources = { major = {}, minor = {} }
    for _, row in ipairs(juggernog) do
        local rowType = g(row, "type")
        local slot = rowType == majorType and "major" or (rowType == minorType and "minor" or nil)
        if slot then
            sources[slot][#sources[slot] + 1] = row
        end
    end
    if #sources.major < 1 or #sources.minor < 1 then
        if not S.loggedAugmentSourceFailure then
            S.loggedAugmentSourceFailure = true
            do end
        end
        return false
    end
    local rowsBySlot = { major = {}, minor = {} }
    for _, slot in ipairs({ "major", "minor" }) do
        for index, definition in ipairs(perk.augments[slot]) do
            local row = {}
            local source = sources[slot][((index - 1) % #sources[slot]) + 1]
            for key, value in pairs(source) do row[key] = value end
            local lootId = perk.lootBase + (slot == "major" and index or index + (perk.minorLootOffset or AUGMENT_MINOR_OFFSET))
            s(row, "displayname", definition.name)
            s(row, "description", definition.description)
            s(row, "lootid", lootId)
            s(row, "IsUnlocked", true)
            s(row, "isUnlocked", true)
            s(row, "isResearchComplete", false)
            s(row, "amountNeededToUnlock", 0)
            s(row, "hideinequipui", false)
            s(row, "equipmenttype", g(g(augment, "equipment_type"), "perk"))
            rowsBySlot[slot][index] = row
            S.augmentLootOptions[lootId] = { perk = perk, slot = slot, index = index }
        end
    end
    local combined = {}
    for _, slot in ipairs({ "major", "minor" }) do
        for _, row in ipairs(rowsBySlot[slot]) do combined[#combined + 1] = row end
    end
    combined.isSorted = true
    combined.isResearchComplete = true
    combined.totalProgress = 0
    s(full, perk.ref, combined)
    local logKey = "loggedAugmentRows_" .. perk.key
    if not S[logKey] then
        S[logKey] = true
        do end
    end
    return rowsBySlot
end
local function markDisabledStockAugments()
    local augment = rawget(_G, "ZMAUGMENT")
    local localize = g(rawget(_G, "Engine"), "Localize")
    if type(augment) ~= "table" or type(localize) ~= "function" then return end
    for _, listName in ipairs({ "augmentlist_full", "augmentlist_major", "augmentlist_minor" }) do
        local rows = g(g(augment, listName), "specialty_elemental_pop")
        if type(rows) == "table" then
            for _, row in ipairs(rows) do
                local raw = g(row, "displayname")
                local ok, text = pcall(localize, raw)
                if raw ~= "Disabled" and ok and string.lower(tostring(text or "")):find("electric cherry", 1, true) then
                    s(row, "displayname", "Disabled")
                    s(row, "description", "This augment is disabled.")
                end
            end
        end
    end
end
local function installVitalityAugmentHooks()
    local augment = rawget(_G, "ZMAUGMENT")
    if type(augment) ~= "table" then return false end
    local perks = rawget(_G, "ZMPERK")
    if type(perks) ~= "table" then return false end
    local loot = rawget(_G, "LOOT")
    local perkEquipment = g(g(augment, "equipment_type"), "perk")
    local slotIds = g(augment, "slot") or {}
    hookAugmentFunction(augment, "initfullaugmentlist", "vitalityFullAugmentRows", function(original, ...)
        local result = original(...)
        for _, perk in ipairs(AUG_PERKS) do
            local ok, rowsOrError = pcall(makeAugmentRows, perk)
            if not ok then
                do end
            elseif not rowsOrError then
                do end
            end
        end
        pcall(markDisabledStockAugments)
        return result
    end)
    hookAugmentFunction(augment, "inittypeaugmentlist", "vitalityTypedAugmentRows", function(original, controller, equipmentType, ...)
        local result = original(controller, equipmentType, ...)
        if equipmentType ~= perkEquipment then return result end
        local majorLists = g(augment, "augmentlist_major")
        local minorLists = g(augment, "augmentlist_minor")
        for _, perk in ipairs(AUG_PERKS) do
            local ok, rowsOrError = pcall(makeAugmentRows, perk)
            if not ok then
                do end
            elseif rowsOrError then
                if type(majorLists) == "table" then s(majorLists, perk.ref, rowsOrError.major) end
                if type(minorLists) == "table" then s(minorLists, perk.ref, rowsOrError.minor) end
            end
        end
        pcall(markDisabledStockAugments)
        return result
    end)
    hookAugmentFunction(augment, "refreshaugmentlistdata", "customAugmentListRefresh", function(original, controller, ref, ...)
        local result = original(controller, ref, ...)
        local perk = augPerkFor(ref)
        if not perk then return result end
        local ok, err = pcall(function()
            local rows = makeAugmentRows(perk)
            if not rows then return end
            local select = g(g(g(rawget(_G, "_DataSources"), "zm"), "frontend"), "augment_select")
            local function setValue(field, value)
                local setter = g(field, "SetValue")
                if type(setter) == "function" then pcall(setter, field, controller, value) end
            end
            local function fill(listName, source)
                local list = g(select, listName)
                if list == nil then return end
                for i = 1, #source do
                    local item = g(list[i], "item")
                    local row = source[i]
                    if item ~= nil then
                        setValue(g(item, "name"), g(row, "displayname"))
                        setValue(g(item, "description"), g(row, "description"))
                        setValue(g(item, "icon"), g(row, "icon"))
                        setValue(g(item, "type"), g(row, "type"))
                        setValue(g(item, "is_unlocked"), true)
                        setValue(g(item, "loot_id"), g(row, "lootid"))
                    end
                end
                for i = #source + 1, math.max(#list, #source + 12) do
                    rawset(list, i, nil)
                end
                setValue(g(list, "count"), #source)
            end
            fill("major_augment_list", rows.major)
            fill("minor_augment_list", rows.minor)
        end)
        if not ok and not S.loggedRefreshErr then
            S.loggedRefreshErr = true
            do end
        end
        return result
    end)
    hookAugmentFunction(loot, "isunlockedwithid", "vitalityAugmentUnlock", function(original, controller, lootId, ...)
        local option = S.augmentLootOptions[tonumber(lootId)]
        if option then return true end
        return original(controller, lootId, ...)
    end)
    hookAugmentFunction(augment, "getequippedaugmentbyref", "vitalityAugmentRead", function(original, controller, ref, slot, equipmentType, ...)
        local perk = augPerkFor(ref)
        if not perk or equipmentType ~= perkEquipment then
            return original(controller, ref, slot, equipmentType, ...)
        end
        if slot == g(slotIds, "major") then
            return math.max(0, math.min(#perk.augments.major, tonumber(perk.selection.major) or 0))
        elseif slot == g(slotIds, "minor") then
            return math.max(0, math.min(#perk.augments.minor, tonumber(perk.selection.minor) or 0))
        elseif slot == g(slotIds, "bonus_minor") then
            return math.max(0, math.min(#perk.augments.minor, tonumber(perk.selection.bonus) or 0))
        end
        return 0
    end)
    hookAugmentFunction(augment, "modifyselectedaugment", "vitalityAugmentWrite", function(original, controller, selected, lootId, ref, equipmentType, ...)
        local perk = augPerkFor(ref)
        if not perk or equipmentType ~= perkEquipment then
            return original(controller, selected, lootId, ref, equipmentType, ...)
        end
        local option = S.augmentLootOptions[tonumber(lootId)]
        if not option or option.perk ~= perk then
            do end
            return
        end
        local refresh = g(augment, "refreshequippedaugmentdata")
        local function refreshSlot(slotId, value)
            if type(refresh) ~= "function" then return end
            local ok, err = pcall(refresh, controller, slotId, value)
            if not ok then do end  end
        end
        if option.slot == "major" then
            local current = tonumber(perk.selection.major) or 0
            local selectedIndex = current == option.index and 0 or option.index
            if not writeAugmentDvar(perk, "major", selectedIndex) then return end
            refreshSlot(g(slotIds, "major"), selectedIndex)
            do end
            return
        end
        local minor = tonumber(perk.selection.minor) or 0
        local bonus = tonumber(perk.selection.bonus) or 0
        local index = option.index
        if index == minor then
            minor, bonus = bonus, 0
        elseif index == bonus then
            bonus = 0
        elseif minor == 0 then
            minor = index
        else
            bonus = index
        end
        loadOnePersisted(perk)
        perk.selection.minor = minor
        perk.selection.bonus = bonus
        perk.selection.pending.minor = true
        perk.selection.pending.bonus = true
        S.pickLoaded[perk.key] = true
        persistSelection(perk)
        refreshSlot(g(slotIds, "minor"), minor)
        refreshSlot(g(slotIds, "bonus_minor"), bonus)
        local item = g(g(g(g(rawget(_G, "_DataSources"), "zm"), "frontend"), "augment_list"), "focused_equipment_item")
        local okRead, readBack = pcall(function() return g(item, "equipped_augment_bonus_minor_index"):GetValue(controller) end)
        do end
    end)
    local required = {
        "vitalityFullAugmentRows", "vitalityTypedAugmentRows",
        "vitalityAugmentUnlock", "vitalityAugmentRead", "vitalityAugmentWrite",
    }
    for _, name in ipairs(required) do
        if not S.hooks[name] then return false end
    end
    if not S.loggedVitalityAugmentHooks then
        S.loggedVitalityAugmentHooks = true
        do end
    end
    return true
end
restorePrototypeAugmentHooks()
local function diag(...) end
local packFn = table.pack or function(...) return { n = select("#", ...), ... } end
local unpackFn = table.unpack or unpack
local function describeArgs(...) end
local function probeFn(...) end
local function traceAllFunctions(...) end
local function isWheelEvent(e)
    return e.qualifier == "mousewheel" or e.key == "MWHEELUP" or e.key == "MWHEELDOWN"
end
local function isNavEvent(e)
    local b = e.button
    return e.key ~= nil and (b == "up" or b == "down" or b == "left" or b == "right")
end
local kbmConfigured = setmetatable({}, { __mode = "k" })
local function configureWunderfizzKBM(menu, grid)
    kbmConfigured[menu] = true
    pcall(function() grid:SetUseMouseWheelRawInput(true) end)
    local okRule, rule = pcall(function() return menu.inputRule end)
    if okRule and type(rule) == "table" and type(rule.predicate) == "function" then
        local orig = rule.predicate
        rule.predicate = function(e, ...)
            if type(e) == "table" and e.name == "gamepad_button" and (isWheelEvent(e) or isNavEvent(e)) then
                return false
            end
            return orig(e, ...)
        end
    else
        do end
    end
    pcall(function()
        menu:addEventHandler("gamepad_button", function(_, e)
            if type(e) ~= "table" or not e.down or not isWheelEvent(e) then return end
            local dir = e.button
            if e.key == "MWHEELUP" then dir = "up" elseif e.key == "MWHEELDOWN" then dir = "down" end
            if dir == "up" or dir == "down" then
                if not S.loggedWheelFallback then S.loggedWheelFallback = true; do end  end
                grid:HandleMouseScroll(dir)
                return true
            end
        end)
    end)
    do end
end
local CLASSIC_WF_COSTS = {
    ["specialty_juggernog"]=2500,
    ["specialty_quickrevive"]=1500,
    ["specialty_speedcola"]=3000,
    ["specialty_staminup"]=2000,
    ["specialty_deadshot"]=1500,
    ["specialty_elemental_pop"]=3000,
    ["specialty_phd_flopper"]=2000,
    ["specialty_death_perception"]=2000,
    ["specialty_vulture_aid"]=3000,
    ["specialty_m_mod"]=3000,
    ["specialty_d_mod"]=2000,
    ["specialty_w_mod"]=2500,
    ["specialty_y_mod"]=4000,
    ["specialty_z_mod"]=4000,
    ["specialty_axe_shot"]=2500,
    ["specialty_banana_colada"]=2000,
    ["specialty_bandolier"]=2500,
    ["specialty_blaze_phase"]=2500,
    ["specialty_blood_wolf_bite"]=3000,
    ["specialty_bull_ice_blast"]=2500,
    ["specialty_dam_a_nade"]=2500,
    ["specialty_electric_cherry"]=2500,
    ["specialty_gautys_gold"]=2500,
    ["specialty_hunters_mark"]=2500,
    ["specialty_jug2"]=2500,
    ["specialty_killstreak_kool_aid"]=3000,
    ["specialty_whos_who"]=2000,
    ["specialty_samurais_sake"]=3000,
    ["specialty_twin_spirit"]=2500,
    ["specialty_magnet_margarita"]=2000,
    ["specialty_nuka_cola"]=2000,
    ["specialty_pack_a_box"]=3000,
    ["specialty_tortoise"]=2500,
    ["specialty_vitality"]=2500,
}
local function installClassicWunderfizzPricing()
    local pmu = rawget(_G, "PurchaseMenuUtils")
    local original = g(pmu, "GetItemCost")
    if type(original) ~= "function" or original == S.classicWfPricing then return end
    local wrapper = function(item, category, controller, ...)
        local mode = readDebugDvar("bo7_cp_wf_classic_prices") or ""
        local enabled = readDebugDvar("bo7_cp_wf_classic_enabled")=="1" or mode~="" or readDebugDvar("bo7_cp_classic_perk_cost")=="1"
        if S.enabled and enabled and item then
            local ref = g(item,"itemref")
            local prices = mode
            if mode=="v2"then
                prices=""
                for page=0,7 do prices=prices..(readDebugDvar("bo7_cp_wf_prices_"..page)or "")end
            end
            for name,cost in prices:gmatch("([^:;]+):(%d+);")do
                if ref==name or ref==H(name)then return tonumber(cost)end
            end
            for name,cost in pairs(CLASSIC_WF_COSTS)do
                if ref==name or ref==H(name)then return cost end
            end
        end
        return original(item, category, controller, ...)
    end
    pmu.GetItemCost=wrapper
    pmu[H("GetItemCost")]=wrapper
    S.classicWfPricing = wrapper
    if not S.classicWfPricingLogged then
        S.classicWfPricingLogged = true
        do end
    end
end
local function installKBMScrollSupport()
    local PMU = rawget(_G, "PurchaseMenuUtils")
    if type(PMU) ~= "table" then return false end
    S.kbmWrapped = S.kbmWrapped or {}
    local ours = {}
    for _, st in pairs(S.hooks) do
        if type(st) == "table" and st.wrapper then ours[st.wrapper] = true end
    end
    local snapshot = {}
    for k, v in pairs(PMU) do
        if type(v) == "function" and not ours[v] and k ~= "GetItemCost" and k ~= H("GetItemCost") then snapshot[#snapshot + 1] = { key = k, fn = v } end
    end
    for _, e in ipairs(snapshot) do
        local known = S.kbmWrapped[e.key]
        if known ~= e.fn then
            local fn = e.fn
            local wrapper
            wrapper = function(...)
                local res = packFn(fn(...))
                for i = 1, select("#", ...) do
                    local a = select(i, ...)
                    if type(a) == "table" or type(a) == "userdata" then
                        local ok, grid = pcall(function() return a.perkgridlayout end)
                        if ok and grid and not kbmConfigured[a] then
                            local okC, errC = pcall(configureWunderfizzKBM, a, grid)
                            if not okC then do end  end
                        end
                    end
                end
                return unpackFn(res, 1, res.n)
            end
            PMU[e.key] = wrapper
            S.kbmWrapped[e.key] = wrapper
        end
    end
    return true
end
local function installGridProbes(...) end
local function syncLuaAugmentRows()
    if not ENABLE_AUGMENT_HOOKS or S.appliedLuaAugmentRows then return end
    local augment = rawget(_G, "ZMAUGMENT")
    if type(augment) ~= "table" then return end
    local full = g(augment, "augmentlist_full")
    local juggernog = g(full, "specialty_juggernog")
    if type(full) ~= "table" or type(juggernog) ~= "table" then return end
    local majorLists = g(augment, "augmentlist_major")
    local minorLists = g(augment, "augmentlist_minor")
    if type(majorLists) ~= "table" or type(minorLists) ~= "table" then return end
    local allReady = true
    for _, perk in ipairs(AUG_PERKS) do
        local ok, rows = pcall(makeAugmentRows, perk)
        if not ok then
            allReady = false
            do end
        elseif rows then
            s(majorLists, perk.ref, rows.major)
            s(minorLists, perk.ref, rows.minor)
        else
            allReady = false
        end
    end
    if allReady then S.appliedLuaAugmentRows = true end
end
local function syncCoopAugmentPicks()
    local engine = rawget(_G, "Engine")
    local frontend = g(engine, "InFrontend")
    if type(frontend) ~= "function" then return end
    local okFront, inFrontend = pcall(frontend)
    if not okFront or inFrontend ~= false then
        S.augmentSync = {}
        S.hudSlotRegistration = nil
        S.augmentSyncCursor = 0
        S.augmentSyncDelay = 0
        S.augmentNextSendAt = nil
        return
    end
    local connected = g(engine, "IsConnectedToGameServer")
    if type(connected) == "function" then
        local okConnected, isConnected = pcall(connected)
        if not okConnected or not isConnected then return end
    end
    local paused = g(engine, "IsPaused")
    if type(paused) == "function" then
        local okPaused, isPaused = pcall(paused)
        if okPaused and isPaused then return end
    end
    local notify = g(engine, "NotifyServer")
    if type(notify) ~= "function" then return end
    local clock = g(engine, "GetMilliseconds")
    if type(clock) ~= "function" then return end
    local clockOk, syncNow = pcall(clock)
    if not clockOk or type(syncNow) ~= "number" then return end
    if S.augmentNextSendAt and syncNow < S.augmentNextSendAt then return end
    if stockHudActivePerkOrder() == nil then
        if not S.augmentWaitingForGameplay then
            S.augmentWaitingForGameplay = true
            do end
        end
        return
    end
    if S.augmentWaitingForGameplay then
        S.augmentWaitingForGameplay = false
        do end
    end
    S.augmentSync = S.augmentSync or {}
    S.augmentSyncDelay = math.max(0, (S.augmentSyncDelay or 0) - 1)
    if S.augmentSyncDelay > 0 then return end
    local getClient = g(rawget(_G, "Game"), "getplayerclientnum")
    if type(getClient) == "function" then
        local okClient, slot = pcall(getClient, 0)
        slot = okClient and tonumber(slot) or nil
        if slot and slot >= 0 and slot <= 3 and slot == math.floor(slot) then
            local registration = S.hudSlotRegistration
            if not registration or registration.slot ~= slot then
                registration = { slot = slot, attempts = 0 }
                S.hudSlotRegistration = registration
            end
            local packet = readDebugDvar("bo7_cp_hud_slot_" .. tostring(slot))
            local prefix = "slot=" .. tostring(slot) .. ";v1:"
            local accepted = type(packet) == "string" and packet:sub(1, #prefix) == prefix
            local clock = g(engine, "GetMilliseconds")
            local clockOk, now = false, nil
            if type(clock) == "function" then clockOk, now = pcall(clock) end
            local canRetry = clockOk and type(now) == "number" and
                (not registration.nextSendAt or now >= registration.nextSendAt)
            if (registration.attempts == 0 or not accepted) and registration.attempts < 60 and canRetry then
                registration.attempts = registration.attempts + 1
                registration.nextSendAt = now + 2000
                S.augmentNextSendAt = syncNow + 500
                S.augmentSyncDelay = 12
                local ok, err = pcall(notify, "perk_choice_purchase", 9000 + slot)
                do end
                if not ok then do end  end
                return
            end
        end
    end
    for offset = 1, #AUG_PERKS do
        local index = ((S.augmentSyncCursor or 0) + offset - 1) % #AUG_PERKS + 1
        local perk = AUG_PERKS[index]
        if perk.syncBase and loadOnePersisted(perk) then
            local state = S.augmentSync[perk.key] or {}
            S.augmentSync[perk.key] = state
            if perk.key=="jug2" and tonumber(perk.selection.major)==4 then perk.selection.major=0 end
            local major = math.floor(math.max(0, math.min(#perk.augments.major, tonumber(perk.selection.major) or 0)))
            local minor = math.floor(math.max(0, math.min(#perk.augments.minor, tonumber(perk.selection.minor) or 0)))
            local bonus = math.floor(math.max(0, math.min(#perk.augments.minor, tonumber(perk.selection.bonus) or 0)))
            if bonus == minor then bonus = 0 end
            local pick = bonus * 100 + major * 10 + minor
            local accepted = readDebugDvar(perk.ackDvar) == "accepted:" .. tostring(pick)
            if accepted and state.ackLogged ~= pick then
                state.ackLogged = pick
                do end
            end
            if state.pick ~= pick then
                state.pick = pick
                state.attempts = 0
                state.ackLogged = nil
                state.nextSendAt = nil
            end
            if ( (state.attempts or 0) == 0 or not accepted ) and (state.attempts or 0) < 30 and
                (not state.nextSendAt or syncNow >= state.nextSendAt) then
                state.attempts = (state.attempts or 0) + 1
                state.nextSendAt = syncNow + 2000
                S.augmentNextSendAt = syncNow + 500
                S.augmentSyncCursor = index
                S.augmentSyncDelay = 12
                local ok, err = pcall(notify, "perk_choice_purchase", perk.syncBase + pick)
                do end
                if not ok then do end  end
                return
            end
        end
    end
end
local function poll()
    if S.enabled then
        local okPricing, errPricing = pcall(installClassicWunderfizzPricing)
        if not okPricing and not S.errClassicPricing then
            S.errClassicPricing = true
            do end
        end
    end
    local okCapture, errCapture = pcall(installNativePerkCapture)
    if not okCapture and not S.errNativeCapture then S.errNativeCapture = true; do end  end
    S.polls = (S.polls or 0) + 1
    local okOwned, owned = pcall(decodeHudPages)
    S.omnvarOwned = okOwned and owned or nil
    local okGold, errGold = pcall(syncCoopAugmentPicks)
    if not okGold and not S.goldSyncError then S.goldSyncError = true; do end  end
    local okAugments, errAugments = pcall(syncLuaAugmentRows)
    if not okAugments and not S.errLuaAugmentRows then
        S.errLuaAugmentRows = true
        do end
    end
    if ENABLE_AUGMENT_HOOKS then
        local okL, eL = pcall(loadPersistedSelection)
        if not okL and not S.errLoad then S.errLoad = true; do end  end
        if S.polls % 50 == 0 then
            for _, perk in ipairs(AUG_PERKS) do
                local major = tonumber(perk.selection.major) or 0
                local minor = tonumber(perk.selection.minor) or 0
                if S.pickLoaded[perk.key] and (major > 0 or minor > 0) then
                    local bonus = tonumber(perk.selection.bonus) or 0
                    if bonus == minor then bonus = 0 end
                    local expected = tostring(bonus * 100 + major * 10 + minor)
                    if readDebugDvar(perk.pickDvar) ~= expected then pcall(persistSelection, perk) end
                end
            end
        end
    end
    for _, c in ipairs(CUSTOM) do
        if isCustomPerkAvailable(c) then
            local owned = readDebugDvar("bo7_cp_client_owned_" .. c.ref:gsub("^specialty_", ""))
            local isOwned
            if owned == "1" or owned == "true" then
                isOwned = true
            elseif owned == "0" or owned == "false" then
                isOwned = false
            end
            if isOwned ~= nil and S.owned[c.ref] ~= isOwned then
                S.owned[c.ref] = isOwned
                do end
            end
        end
    end
    if S.polls == 40 then
        do end
        do end
        if not S.hooks.engineNotify then
            do end
        end
    end
    local ok1, e1 = pcall(installPerk)
    if not ok1 and not S.err1 then S.err1 = true; do end  end
    local ok2, e2 = pcall(installMenu)
    if not ok2 and not S.err2 then S.err2 = true; do end  end
    local ok3, e3 = pcall(installNotifyServer)
    if not ok3 and not S.err3 then S.err3 = true; do end  end
    local ok4, e4 = pcall(installOwnedPerkDisplay)
    if not ok4 and not S.errOwnedDisplay then S.errOwnedDisplay = true; do end  end
    local ok5, e5 = pcall(installHudPerkIds)
    if not ok5 and not S.errHudPerkIds then S.errHudPerkIds = true; do end  end
    S.refreshPerkHud = function() return pcall(updateStockHudPerkOverflow) end
    local okOverflow, eOverflow = pcall(updateStockHudPerkOverflow)
    if not okOverflow and not S.errStockHudOverflow then
        S.errStockHudOverflow = true
        do end
    end
    if ENABLE_GRID_PROBES then
        local okP, eP = pcall(installGridProbes)
        if not okP and not S.errProbes then S.errProbes = true; do end  end
    end
    if ENABLE_AUGMENT_HOOKS and ENABLE_WUNDERFIZZ_KBM_HOOKS then
        local okKBM, eKBM = pcall(installKBMScrollSupport)
        if not okKBM and not S.errKBM then S.errKBM = true; do end  end
    end
    if ENABLE_AUGMENT_HOOKS then
        local ok6, e6 = pcall(installVitalityPerkList)
        if not ok6 and not S.errVitalityPerkList then S.errVitalityPerkList = true; do end  end
        local ok7, e7 = pcall(installVitalityAugmentHooks)
        if not ok7 and not S.errVitalityAugmentHooks then S.errVitalityAugmentHooks = true; do end  end
    elseif not S.loggedAugmentsOff then
        S.loggedAugmentsOff = true
        do end
    end
end
local frame = rawget(_G, "Frame")
local dw = frame and (g(frame, "DoWork") or frame.DoWork)
local qkey, qfn
if dw then qkey, qfn = findFn(dw, "Queue") end
if qfn then
    qfn(dw, function()
        if not S.enabled then return false end
        pcall(collectHudPages)
        S.ticks = S.ticks + 1
        if S.ticks >= 5 then S.ticks = 0; poll() end
        return true
    end)
else
    do end
end
if previous and (previous.version == 19 or previous.version == 20 or previous.version == 21) then
    do end
end
poll()
do
    local list = dvarTokenCandidates("lumen_mod_menu_request")
    do end
end
do end
