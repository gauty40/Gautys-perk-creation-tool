local OVERCLOCKS_ENABLED = false
local previous = rawget(_G, "BO7PerkToggles")
if previous then
    previous.enabled = false
    if previous.panel then pcall(function() previous.panel:closeTree() end) end
end
local S = { enabled = true, hooks = {}, reported = {} }
rawset(_G, "BO7PerkToggles", S)
local H = rawget(_G, "xhash")
local perks = {
    {"vitality", "Vitality"}, {"bandolier", "Bandolier Bandit"},
    {"tortoise", "Victorious Tortoise"}, {"gautys_gold", "Gauty's Gold"},
    {"electric_cherry", "Electric Cherry"}, {"jug2", "Roo Brew"},
    {"blaze_phase", "Blaze Phase"},
    {"native_juggernog", "Juggernog", "specialty_juggernog"},
    {"native_quick_revive", "Quick Revive", "specialty_quickrevive"},
    {"native_speedcola", "Speed Cola", "specialty_speedcola"},
    {"native_staminup", "Stamin-Up", "specialty_staminup"},
    {"native_deadshot", "Deadshot Daiquiri", "specialty_deadshot"},
    {"native_elemental_pop", "Elemental Pop", "specialty_elemental_pop"},
    {"native_phd_flopper", "PhD Flopper", "specialty_phd_flopper"},
    {"native_death_perception", "Death Perception", "specialty_death_perception"},
    {"native_vulture_aid", "Vulture Aid", "specialty_vulture_aid"},
    {"native_m_mod", "Melee Macchiato", "specialty_m_mod"},
    {"native_d_mod", "Double Tap", "specialty_d_mod"},
    {"native_w_mod", "W Mod", "specialty_w_mod"},
    {"native_y_mod", "Y Mod", "specialty_y_mod"},
    {"native_z_mod", "Z Mod", "specialty_z_mod"}
}
local function get(t, key)
    if t == nil then return nil end
    local ok, value = pcall(function() return t[key] end)
    if ok and value ~= nil then return value end
    if type(H) == "function" then
        ok, value = pcall(function() return t[H(key)] end)
        if ok then return value end
    end
end
local function call(t, key, ...)
    local f = get(t, key)
    if type(f) == "function" then return f(t, ...) end
end
local function log(...) end
local function once(key, message)
    if not S.reported[key] then S.reported[key] = true; do end  end
end
local function dvarHash(name)
    local f = rawget(_G, "xhashdvar") or get(rawget(_G, "CLUA"), "PushXHashDvar")
    if type(f) == "function" then return f(name) end
    return name
end
local function store(name)
    local p = rawget(_G, "BO7PerkPersist")
    if type(p) == "table" and p.enabled and p.has(name) then return p end
end
local function read(name)
    local p = store(name)
    if p then local v = p.get(name); if v ~= nil then return v end end
    local f = get(rawget(_G, "Dvar"), "GetDvarString")
    if type(f) == "function" then
        local ok, value = pcall(f, dvarHash(name))
        if ok and value ~= nil then return tostring(value) end
    end
    return ""
end
local function write(name, value)
    local p = store(name)
    if p then
        local ok = p.set(name, value)
        if not ok then do end  end
        return ok
    end
    local f = get(rawget(_G, "Dvar"), "SetDvarString")
    if type(f) == "function" then pcall(f, dvarHash(name), value) end
    if read(name) == value then return true end
    local exec = get(rawget(_G, "Engine"), "ExecNow")
    if type(exec) == "function" then pcall(exec, "set " .. name .. " " .. value .. "\n", 0) end
    return read(name) == value
end
local function frontend()
    local f = get(rawget(_G, "Engine"), "InFrontend")
    return type(f) == "function" and f() == true
end
local function zombies()
    local f = get(rawget(_G, "GameModesUtils"), "isactivegamemodezm")
    return type(f) == "function" and f() == true
end
local function make(kind)
    local f = get(get(rawget(_G, "LUI"), kind), "new")
    assert(type(f) == "function", kind .. " unavailable")
    return f()
end
local function position(element, x, y, width, height)
    call(element, "SetAnchorsAndPosition", 0, 1, 0, 1, x, x + width, y, y + height)
end
local function text(parent, value, x, y, width, height)
    local t = make("UIText")
    position(t, x, y, width, height)
    call(t, "setText", value)
    call(t, "SetRGB", 0xffffff)
    call(parent, "addElement", t)
    return t
end
local function focus(button)
    call(button, "processEvent", { name = "gain_focus" })
end
local function rect(parent, x, y, width, height, color, alpha)
    local image = make("UIImage")
    position(image, x, y, width, height)
    call(image, "SetRGB", color)
    call(image, "SetAlpha", alpha or 1)
    call(parent, "addElement", image)
    return image
end
local SKIN = { fill = 0x101118, fillAlpha = 0.72, frame = 0x5a5d66, frameFocus = 0xa47bff, glow = 0x6a2cff,
               bar = 0xa47bff, text = 0xd9dae0, textOn = 0xffffff, off = 0x96999f }
local function skin(button, w, h)
    local s = { glow = rect(button, -5, -5, w + 10, h + 10, SKIN.glow, 0) }
    s.fill = rect(button, 0, 0, w, h, SKIN.fill, SKIN.fillAlpha)
    s.bar = rect(button, 0, 0, 3, h, SKIN.bar, 0)
    s.edges = { rect(button, 0, 0, w, 1, SKIN.frame), rect(button, 0, h - 1, w, 1, SKIN.frame),
                rect(button, 0, 0, 1, h, SKIN.frame), rect(button, w - 1, 0, 1, h, SKIN.frame) }
    return s
end
local function paintSkin(s, focused, on, label)
    call(s.glow, "SetAlpha", focused and 0.35 or 0)
    call(s.bar, "SetAlpha", on and 1 or 0)
    for _, edge in ipairs(s.edges) do call(edge, "SetRGB", focused and SKIN.frameFocus or SKIN.frame) end
    if label then call(label, "SetRGB", (focused or on) and SKIN.textOn or SKIN.text) end
end
local function skinFont(t)
    local fonts = rawget(_G, "FONT_HANDLE")
    local font = get(fonts, "PrimaryBlack") or get(fonts, "PrimaryBold")
    if font then call(t, "SetFont", font) end
    return t
end
local function icon(parent, material, x, y, size)
    local hud = rawget(_G, "BO7CustomPerks")
    if hud and type(hud.resolvePerkPackIcon) == "function" then material = hud.resolvePerkPackIcon(material) end
    local image = make("UIImage")
    position(image, x, y, size, size)
    local register = rawget(_G, "RegisterMaterial")
    local hash = rawget(_G, "xhashasset") or get(rawget(_G, "CLUA"), "PushXHashAsset")
    if type(register) == "function" then
        local ok, asset = pcall(function() return register(type(material) == "string" and type(hash) == "function" and hash(material) or material) end)
        if ok and asset then call(image, "setImage", asset) end
    end
    call(parent, "addElement", image)
    return image
end
local artwork = {
    vitality = {"ui_icon_perks_zm_custom", "Regenerate health while crouched. Your selected augments add further benefits."},
    bandolier = {"ui_icon_perks_zm_bandolier", "Carry additional reserve ammunition for your weapons."},
    tortoise = {"ui_icon_perks_zm_tortoise", "Reduce incoming damage while wearing armor."},
    gautys_gold = {"ui_icon_perks_zm_Gautys_Gold", "Earn additional points. Selected augments can improve earnings or refund purchases."},
    electric_cherry = {"ui_icons_perks_zm_electric_cherry", "Reload to unleash an electric shock that damages and stuns nearby zombies."},
    jug2 = {"ui_icons_perks_zm_roo_brew", "Jump five times as high. Moon Hop reduces gravity for five seconds after jumping."},
    blaze_phase = {"ui_icon_perks_zm_blaze_phase", "Hold a crouch to charge, then stand to burst forward and leave a burning trail."}
}
local open
local OVERCLOCKS = {
    { key = "frag", name = "FRAG", lethal = true,
      a = { "Shrapnel", "Zombies caught in the blast bleed for 5% of their max health per second for 3 seconds." },
      b = { "Cooked", "25% more damage, plus an extra blast that reaches further." } },
    { key = "cluster", name = "CLUSTER GRENADE", lethal = true,
      a = { "Payload", "The bomblets deal 50% more damage." },
      b = { "Frost Cluster", "Bomblet hits slow zombies by 50% for 3 seconds." } },
    { key = "semtex", name = "SEMTEX", lethal = true,
      a = { "Charged Stick", "A Semtex stuck to a normal zombie kills it outright." },
      b = { "Aftershock", "A second, smaller blast goes off 1 second after the first." } },
    { key = "molotov", name = "MOLOTOV", lethal = true,
      a = { "Napalm", "The landing spot keeps burning zombies for 12 seconds." },
      b = { "Cryo Blast", "Shatters into ice instead of fire: freezes zombies for 3 seconds and leaves freezing ice for 8 seconds." } },
    { key = "turret", name = "POINT TURRET", lethal = true,
      a = { "Hollow Points", "The turret deals 50% more damage." },
      b = { "Cryo Rounds", "Turret hits slow zombies by 40% for 2 seconds." } },
    { key = "c4", name = "C4", lethal = true,
      a = { "Shaped Charge", "50% more damage." },
      b = { "Void Charge", "The blast also deals void damage (25% of max health) to every zombie in a wide radius." } },
    { key = "axe", name = "COMBAT AXE", lethal = true,
      a = { "Ricochet", "A kill with the axe also kills the nearest zombie within range." },
      b = { "Hell Redeemed", "Kills with the axe give it straight back." } },
    { key = "impact", name = "IMPACT GRENADE", lethal = true,
      a = { "Concussive Impact", "Zombies that survive the blast are stunned for 3 seconds." },
      b = { "Bigger Bang", "An extra blast reaches further than the normal one." } },
    { key = "thermobaric", name = "THERMO GRENADE", lethal = true,
      a = { "Overpressure", "An extra blast reaches further than the normal one." },
      b = { "Shockwave", "Zombies that survive the blast are stunned for 5 seconds." } },
    { key = "stun", name = "STUN GRENADE", lethal = false,
      a = { "Long Daze", "Zombies in the blast are stunned for 6 seconds." },
      b = { "Shatter", "Zombies in the blast take 25% more damage from everything for 4 seconds." } },
    { key = "stim", name = "STIM SHOT", lethal = false,
      a = { "Adrenaline Rush", "Move 20% faster for 8 seconds after using it." },
      b = { "Second Wind", "Take 50% less damage for 5 seconds after using it." } },
    { key = "psych", name = "PSYCH GRENADE", lethal = false,
      a = { "Mind Melt", "Zombies in the cloud take 20% more damage from everything." },
      b = { "Bad Trip", "Leaves a cloud for 15 seconds that slows and damages zombies." } },
    { key = "hunterbot", name = "HUNTER BOT", lethal = false,
      a = { "Payload", "The bot's blast deals 50% more damage." },
      b = { "Cryo Bot", "The bot's blast freezes zombies for 3 seconds." } },
    { key = "decoy", name = "DECOY", lethal = false,
      a = { "Distraction", "Zombies near the decoy take 25% more damage while it's out." },
      b = { "Booby Trap", "Explodes when it runs out." } },
    { key = "kazimir", name = "LT53 KAZIMIR", lethal = false,
      a = { "Crush", "Zombies near the black hole take void damage while it's open." },
      b = { "Event Horizon", "The black hole lasts 50% longer (15 seconds)." } },
    { key = "shockstick", name = "SHOCK CHARGE", lethal = false,
      a = { "Overload", "The shock chains to 2 more zombies nearby." },
      b = { "Static Field", "Leaves a field that slows zombies by 50% for 4 seconds." } },
    { key = "monkey", name = "CYMBAL MONKEY", lethal = false,
      a = { "Big Bang", "Goes off with a much bigger extra blast." },
      b = { "Second Act", "Explodes a second time, 1 second later." } },
}
local openOverclocks
openOverclocks = function(parent, controller)
    if S.panel then call(S.panel, "closeTree"); S.panel = nil end
    local panel = make("UIVerticalNavigator")
    panel.id = "GautysOverclocks"
    position(panel, 0, 0, 1920, 1080)
    call(panel, "SetPriority", 1000)
    rect(panel, 0, 0, 1920, 1080, 0x0b0d10, 0.99)
    rect(panel, 0, 0, 1920, 80, 0x15171b)
    local title = text(panel, "OVERCLOCKS", 280, 30, 450, 36)
    call(title, "SetFontSize", 28 * (rawget(_G, "_PT") or 1))
    text(panel, "LETHALS", 96, 140, 560, 28)
    text(panel, "TACTICALS", 700, 140, 560, 28)
    rect(panel, 96, 176, 1164, 2, 0x4b4e53)
    rect(panel, 1330, 112, 1, 745, 0x393c42)
    local detailName = text(panel, "", 1372, 150, 448, 36)
    local detailPick = text(panel, "", 1372, 200, 448, 28)
    rect(panel, 1372, 240, 448, 1, 0x4b4e53)
    local detailA = text(panel, "", 1372, 262, 448, 150)
    local detailB = text(panel, "", 1372, 430, 448, 150)
    for _, t in ipairs({ detailA, detailB }) do
        call(t, "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
        call(t, "SetWordWrap", true)
    end
    text(panel, "Overclocks apply all match. Co-op uses the host's picks.", 1372, 790, 448, 52)
    local status = text(panel, "Press an equipment to cycle None / A / B.", 96, 884, 1184, 28)
    local buttons, skins, states, labels = {}, {}, {}, {}
    local selected = 1
    local function pickOf(i)
        local v = read("bo7_cp_oc_" .. OVERCLOCKS[i].key)
        return (v == "1" or v == "2") and tonumber(v) or 0
    end
    local function pickName(i)
        local p = pickOf(i)
        return p == 1 and OVERCLOCKS[i].a[1] or (p == 2 and OVERCLOCKS[i].b[1] or "None")
    end
    local function details()
        local oc = OVERCLOCKS[selected]
        if not oc then return end
        call(detailName, "setText", oc.name)
        call(detailPick, "setText", "Equipped: " .. pickName(selected))
        call(detailA, "setText", "A  " .. oc.a[1] .. "\n" .. oc.a[2])
        call(detailB, "setText", "B  " .. oc.b[1] .. "\n" .. oc.b[2])
        local p = pickOf(selected)
        call(detailA, "SetRGB", p == 1 and SKIN.frameFocus or SKIN.text)
        call(detailB, "SetRGB", p == 2 and SKIN.frameFocus or SKIN.text)
    end
    local function paint()
        for i = 1, #buttons do
            local p = pickOf(i)
            paintSkin(skins[i], i == selected, p > 0, labels[i])
            call(states[i], "setText", string.upper(pickName(i)))
            call(states[i], "SetRGB", p == 0 and SKIN.off or SKIN.frameFocus)
        end
        details()
    end
    local function close()
        call(panel, "closeTree")
        S.panel = nil
        open(parent, controller)
    end
    local lethalRow, tacticalRow = 0, 0
    for i, oc in ipairs(OVERCLOCKS) do
        local index = i
        local row
        if oc.lethal then row = lethalRow; lethalRow = lethalRow + 1 else row = tacticalRow; tacticalRow = tacticalRow + 1 end
        local button = make("UIButton")
        button.id = "Overclock_" .. oc.key
        position(button, oc.lethal and 96 or 700, 196 + row * 66, 560, 58)
        call(button, "setHandleMouse", true)
        call(button, "setFocusable", true)
        skins[i] = skin(button, 560, 58)
        local label = skinFont(text(button, oc.name, 16, 14, 300, 30))
        call(label, "SetFontSize", 20 * (rawget(_G, "_PT") or 1))
        labels[i] = label
        states[i] = text(button, "", 300, 16, 244, 28)
        call(states[i], "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
        call(states[i], "SetAlignment", 2)
        call(button, "registerEventHandler", "button_action", function()
            selected = index
            local nextPick = (pickOf(index) + 1) % 3
            if write("bo7_cp_oc_" .. oc.key, tostring(nextPick)) then
                call(status, "setText", oc.name .. ": " .. pickName(index) .. " (next match).")
                do end
            else
                call(status, "setText", "Could not save this overclock. See the console for details.")
                do end
            end
            paint()
            return true
        end)
        call(button, "registerEventHandler", "button_over", function() selected = index; paint() end)
        call(panel, "addElement", button)
        buttons[i] = button
    end
    rect(panel, 96, 940, 1728, 1, 0x4b4e53)
    local back = make("UIButton")
    position(back, 96, 967, 270, 50)
    local backSkin = skin(back, 270, 50)
    call(back, "setFocusable", true)
    call(back, "setHandleMouse", true)
    local backLabel = skinFont(text(back, "BACK", 16, 7, 246, 35))
    paintSkin(backSkin, false, false, backLabel)
    call(back, "registerEventHandler", "button_action", function() close(); return true end)
    call(back, "registerEventHandler", "button_over", function() paintSkin(backSkin, true, false, backLabel) end)
    call(panel, "addElement", back)
    local onBack = false
    call(panel, "registerEventHandler", "gamepad_button", function(_, event)
        if not event or event.down == false then return end
        if event.button == "secondary" then close(); return true end
        if onBack then
            if event.button == "up" then onBack = false; paintSkin(backSkin, false, false, backLabel); focus(buttons[selected]); paint(); return true end
            return
        end
        local lethals = lethalRow
        local nextIndex = selected
        if event.button == "up" then
            if selected ~= 1 and selected ~= lethals + 1 then nextIndex = selected - 1 end
        elseif event.button == "down" then
            if selected == lethals or selected == #buttons then
                onBack = true; paintSkin(backSkin, true, false, backLabel); focus(back); return true
            end
            nextIndex = selected + 1
        elseif event.button == "left" then
            if selected > lethals then nextIndex = math.min(selected - lethals, lethals) end
        elseif event.button == "right" then
            if selected <= lethals then nextIndex = math.min(selected + lethals, #buttons) end
        else return end
        selected = nextIndex
        focus(buttons[selected])
        paint()
        return true
    end)
    call(parent, "addElement", panel)
    S.panel = panel
    paint()
    focus(buttons[1])
    do end
end
open = function(parent, controller)
    if not frontend() then return end
    if S.panel then call(S.panel, "closeTree"); S.panel = nil end
    local allPerks = {}
    local hud = rawget(_G, "BO7CustomPerks")
    if hud and type(hud.customPerks) == "table" then
        for _, perk in ipairs(hud.customPerks) do
            local id = perk.ref:gsub("^specialty_", "")
            allPerks[#allPerks + 1] = {id, perk.name}
            artwork[id] = {perk.icon or "ui_icon_perks_zm_custom", perk.desc or "Custom perk.", perk.creator or ""}
        end
    else
        for _, perk in ipairs(perks) do if not perk[3] then allPerks[#allPerks + 1] = perk end end
    end
    for _, perk in ipairs(perks) do if perk[3] then allPerks[#allPerks + 1] = perk end end
    local pageCount = math.ceil(#allPerks / 16)
    local page = tonumber(S.page) or 1
    if page < 1 or page > pageCount then page = 1 end
    S.page = page
    local perks = {}
    for i = (page - 1) * 16 + 1, math.min(page * 16, #allPerks) do
        local entry = allPerks[i]
        if entry[3] then
            local getter = get(rawget(_G, "PERK"), "GetBundleByRef")
            local ok, bundle = false, nil
            if type(getter) == "function" then ok, bundle = pcall(getter, entry[3]) end
            if ok and bundle then
                local localize = get(rawget(_G, "Engine"), "Localize")
                local name, description = get(bundle, "name"), get(bundle, "description")
                if type(localize) == "function" then
                    local good, value = pcall(localize, name)
                    if good and value and value ~= "" then entry[2] = tostring(value) end
                    good, value = pcall(localize, description)
                    if good and value then description = tostring(value) end
                end
                local customHud = rawget(_G, "BO7CustomPerks")
                local packIcons = customHud and customHud.perkPackIcons
                artwork[entry[1]] = {(packIcons and packIcons[entry[3]]) or get(bundle, "hudimage") or get(bundle, "image") or "ui_icon_perks_zm_custom", type(description) == "string" and description or "Native Zombies perk."}
            end
            if not artwork[entry[1]] then artwork[entry[1]] = {"ui_icon_perks_zm_juggernaut", "Native Zombies perk; availability depends on the map."} end
            local packIcons = hud and hud.perkPackIcons
            local nativeIcon = packIcons and packIcons[entry[3]]
            if entry[1] == "native_quick_revive" then nativeIcon = "ui_icon_perks_zm_quickrevive" end
            if nativeIcon then artwork[entry[1]][1] = nativeIcon end
            artwork[entry[1]][3] = entry[3] == "specialty_y_mod" and "Treyarch. icon by: Zura" or "Treyarch"
        end
        perks[#perks + 1] = entry
    end
    local panel = make("UIVerticalNavigator")
    panel.id = "GautysCustomPerkToggles"
    position(panel, 0, 0, 1920, 1080)
    call(panel, "SetPriority", 1000)
    rect(panel, 0, 0, 1920, 1080, 0x0b0d10, 0.99)
    rect(panel, 0, 0, 1920, 80, 0x15171b)
    local title = text(panel, "CUSTOM PERKS", 280, 30, 450, 36)
    call(title, "SetFontSize", 28 * (rawget(_G, "_PT") or 1))
    text(panel, "PERK AVAILABILITY  /  " .. page .. " OF " .. pageCount, 96, 112, 600, 28)
    rect(panel, 96, 154, 1184, 2, 0x4b4e53)
    rect(panel, 96, 152, 265, 4, SKIN.bar)
    text(panel, "Choose the perks available in your next match.", 96, 178, 1184, 26)
    rect(panel, 1330, 112, 1, 745, 0x393c42)
    local creatorCredit = text(panel, "", 1372, 185, 448, 28)
    call(creatorCredit, "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
    local framePreview = make("UIImage")
    call(framePreview, "SetHandleMouse", false)
    call(panel, "addElement", framePreview)
    local detailIcon = icon(panel, artwork[perks[1][1]][1], 1458, 225, 200)
    local detailName = text(panel, perks[1][2], 1372, 470, 448, 42)
    local detailState = text(panel, "", 1372, 531, 448, 28)
    rect(panel, 1372, 580, 448, 1, 0x4b4e53)
    local detailDesc = text(panel, "", 1372, 610, 448, 120)
    call(detailDesc, "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
    call(detailDesc, "SetWordWrap", true)
    text(panel, "Co-op uses the host's settings.", 1372, 955, 448, 26)
    text(panel, "Changes apply next match.", 1372, 981, 448, 26)
    local status = text(panel, "Selections save automatically.", 96, 884, 1184, 28)
    local buttons, labels, skins, states = {}, {}, {}, {}
    local selected = 1
    local footerIndex = nil
    local footerButtons, footerFills = {}, {}
    local function close()
        call(panel, "closeTree")
        S.panel = nil
        call(parent, "processEvent", {name = "gain_focus"})
    end
    local function details()
        local perk = perks[selected]
        local disabled = read("bo7_cp_off_" .. perk[1]) == "1"
        local creator = artwork[perk[1]][3]
        if type(creator) ~= "string" then creator = "" end
        call(creatorCredit, "setText", creator ~= "" and ("Created By: " .. creator) or "")
        call(detailName, "setText", perk[2])
        call(detailState, "setText", disabled and "DISABLED" or "ENABLED")
        call(detailState, "SetRGB", disabled and SKIN.off or SKIN.frameFocus)
        call(detailDesc, "setText", artwork[perk[1]][2])
        local register = rawget(_G, "RegisterMaterial")
        local hash = rawget(_G, "xhashasset") or get(rawget(_G, "CLUA"), "PushXHashAsset")
        if type(register) == "function" then
            local ok, asset = pcall(function() local name = artwork[perk[1]][1]; local hud = rawget(_G, "BO7CustomPerks"); if hud and type(hud.resolvePerkPackIcon) == "function" then name = hud.resolvePerkPackIcon(name) end; return register(type(name) == "string" and type(hash) == "function" and hash(name) or name) end)
            if ok and asset then call(detailIcon, "setImage", asset) end
        end
    end
    local function paintCard(i)
        paintSkin(skins[i], i == selected, read("bo7_cp_off_" .. perks[i][1]) ~= "1", labels[i])
    end
    local function select(index)
        footerIndex = nil
        for _, s in ipairs(footerFills) do paintSkin(s, false, false) end
        selected = index
        for i = 1, #buttons do paintCard(i) end
        details()
    end
    local function refresh(i)
        local disabled = read("bo7_cp_off_" .. perks[i][1]) == "1"
        call(states[i], "setText", disabled and "OFF" or "ON")
        call(states[i], "SetRGB", disabled and SKIN.off or SKIN.frameFocus)
        if skins[i] then paintCard(i) end
        details()
    end
    for i, perk in ipairs(perks) do
        local index, id, name = i, perk[1], perk[2]
        local button = make("UIButton")
        button.id = "PerkToggle_" .. id
        local column, row = (i - 1) % 4, math.floor((i - 1) / 4)
        position(button, 96 + column * 300, 240 + row * 158, 284, 146)
        call(button, "setHandleMouse", true)
        call(button, "setFocusable", true)
        skins[i] = skin(button, 284, 146)
        icon(button, artwork[id][1], 100, 8, 84)
        labels[i] = skinFont(text(button, name, 12, 94, 260, 22))
        call(labels[i], "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
        rect(button, 16, 119, 252, 1, SKIN.frame)
        states[i] = text(button, "", 16, 123, 252, 20)
        call(states[i], "SetFontSize", 16 * (rawget(_G, "_PT") or 1))
        call(button, "registerEventHandler", "button_action", function()
            select(index)
            local key = "bo7_cp_off_" .. id
            local value = read(key) == "1" and "0" or "1"
            if write(key, value) then
                refresh(index)
                call(status, "setText", name .. (value == "1" and " disabled" or " enabled") .. " for the next match.")
                do end
            else
                call(status, "setText", "Could not save this setting. See the console for details.")
                do end
            end
            return true
        end)
        call(button, "registerEventHandler", "button_over", function() select(index) end)
        call(panel, "addElement", button)
        buttons[i] = button
        refresh(i)
    end
    rect(panel, 96, 940, 1728, 1, 0x4b4e53)
    local back = make("UIButton")
    position(back, 96, 967, 140, 50)
    footerFills[1] = skin(back, 140, 50)
    footerButtons[1] = back
    call(back, "setFocusable", true)
    call(back, "setHandleMouse", true)
    call(skinFont(text(back, "BACK", 16, 8, 116, 34)), "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
    call(back, "registerEventHandler", "button_action", function() close(); return true end)
    call(panel, "addElement", back)
    local function pageButton(label, x, w, change)
        local button = make("UIButton")
        position(button, x, 967, w, 50)
        footerFills[#footerFills + 1] = skin(button, w, 50)
        footerButtons[#footerButtons + 1] = button
        call(button, "setFocusable", true)
        call(button, "setHandleMouse", true)
        call(skinFont(text(button, label, 16, 8, w - 24, 34)), "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
        call(button, "registerEventHandler", "button_action", function()
            S.page = (page - 1 + change) % pageCount + 1
            open(parent, controller)
            return true
        end)
        call(panel, "addElement", button)
    end
    pageButton("PREVIOUS", 248, 170, -1)
    pageButton("NEXT", 430, 140, 1)
    local frameChoices = {{id = 0, name = "Default"}}
    for _, entry in ipairs(rawget(_G, "BO7EternalFramePacks") or {}) do frameChoices[#frameChoices + 1] = entry end
    local frameButton = make("UIButton")
    position(frameButton, 582, 967, 300, 50)
    footerFills[#footerFills + 1] = skin(frameButton, 300, 50)
    footerButtons[#footerButtons + 1] = frameButton
    call(frameButton, "setFocusable", true)
    call(frameButton, "setHandleMouse", true)
    local frameLabel = skinFont(text(frameButton, "", 16, 8, 276, 34))
    call(frameLabel, "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
    local function frameChoiceIndex()
        local selectedId = tonumber(read("bo7_cp_eternal_frame_style")) or 0
        for i, entry in ipairs(frameChoices) do if entry.id == selectedId then return i end end
        return 1
    end
    local function updateFrameLabel()
        call(frameLabel, "setText", "FRAME: " .. frameChoices[frameChoiceIndex()].name)
    end
    local function updateFramePreview()
        local source = frameChoices[frameChoiceIndex()]
        if not source.material then
            source = {material = "ui_icon_eternalperk", width = 320, height = 308, centerX = 156, centerY = 156, referenceSize = 256}
        end
        local size, frameScale = 200, source.scale or 1.10
        local width = size * (source.width / source.referenceSize) * frameScale
        local height = size * (source.height / source.referenceSize) * frameScale
        position(framePreview, 1458 + size / 2 - width * (source.centerX / source.width), 225 + size / 2 - height * (source.centerY / source.height), width, height)
        local register = rawget(_G, "RegisterMaterial")
        local hash = rawget(_G, "xhashasset") or get(rawget(_G, "CLUA"), "PushXHashAsset")
        if type(register) == "function" then
            local ok, asset = pcall(function() return register(type(hash) == "function" and hash(source.material) or source.material) end)
            if ok and asset then call(framePreview, "setImage", asset) end
        end
    end
    updateFrameLabel()
    updateFramePreview()
    call(frameButton, "registerEventHandler", "button_action", function()
        local nextChoice = frameChoices[frameChoiceIndex() % #frameChoices + 1]
        if write("bo7_cp_eternal_frame_style", tostring(nextChoice.id)) then
            updateFrameLabel()
            updateFramePreview()
            call(status, "setText", "Eternal perk frame: " .. nextChoice.name)
        else
            call(status, "setText", "Could not save the frame selection.")
        end
        return true
    end)
    call(panel, "addElement", frameButton)
    local machineButton = make("UIButton")
    position(machineButton, 894, 967, 300, 50)
    footerFills[#footerFills + 1] = skin(machineButton, 300, 50)
    footerButtons[#footerButtons + 1] = machineButton
    call(machineButton, "setFocusable", true)
    call(machineButton, "setHandleMouse", true)
    local machineLabel = skinFont(text(machineButton, "", 16, 8, 276, 34))
    call(machineLabel, "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
    local function updateMachineLabel()
        call(machineLabel, "setText", "PERK MACHINES: " .. (read("bo7_cp_off_machines") == "1" and "OFF" or "ON"))
    end
    updateMachineLabel()
    call(machineButton, "registerEventHandler", "button_action", function()
        local value = read("bo7_cp_off_machines") == "1" and "0" or "1"
        if write("bo7_cp_off_machines", value) then
            updateMachineLabel()
            call(status, "setText", "Custom perk machines " .. (value == "1" and "disabled" or "enabled") .. " for the next match.")
            do end
        else
            call(status, "setText", "Could not save the perk machine setting.")
            do end
        end
        return true
    end)
    call(panel, "addElement", machineButton)
    local wfChoices = {"", "0", "1", "2", "3", "4", "5", "6", "8", "10", "15", "20", "25", "30"}
    local wfButton = make("UIButton")
    position(wfButton, 1372, 796, 448, 44)
    footerFills[#footerFills + 1] = skin(wfButton, 448, 44)
    footerButtons[#footerButtons + 1] = wfButton
    call(wfButton, "setFocusable", true)
    call(wfButton, "setHandleMouse", true)
    local wfLabel = skinFont(text(wfButton, "", 16, 7, 424, 30))
    call(wfLabel, "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
    local function wfName(v)
        if v == "" then return "DEFAULT ROUND" elseif v == "0" then return "OFF" end
        return "ROUND " .. v
    end
    local function updateWfLabel() call(wfLabel, "setText", "WUNDERFIZZ: " .. wfName(read("bo7_cp_wunderfizz_round"))) end
    updateWfLabel()
    local function numberPrompt(button, title, description, defaultValue, maxLen, onDone)
        local openBox = get(rawget(_G, "ACTIONS"), "opengenericeditboxpopup")
        if type(openBox) ~= "function" then return false end
        return (pcall(openBox, button, controller, {
            title = title, description = description, defaultValue = defaultValue,
            maxInputStringLength = maxLen, verifyString = false,
            keyboardType = get(get(rawget(_G, "Enum"), "ui_keyboard_type"), "ui_keyboard_type_number"),
            textEditCompleteFunc = function(_, result)
                if not result or result.cancelled then return end
                onDone(tostring(result.text or ""):match("^%s*(.-)%s*$"))
            end
        }))
    end
    local function saveWf(nextValue)
        if write("bo7_cp_wunderfizz_round", nextValue) then
            updateWfLabel()
            call(status, "setText", "Wunderfizz: " .. string.lower(wfName(nextValue)) .. " for the next match.")
            do end
        else
            call(status, "setText", "Could not save the Wunderfizz setting.")
            do end
        end
    end
    call(wfButton, "registerEventHandler", "button_action", function()
        local cur = read("bo7_cp_wunderfizz_round")
        local opened = numberPrompt(wfButton, "WUNDERFIZZ ROUND", "Round the Wunderfizz spawns. 0 = off, empty = game default.", cur, 3, function(t)
            if t == "" then saveWf(""); return end
            local n = tonumber(t:match("^(%d+)$"))
            if not n then call(status, "setText", "Wunderfizz round must be a whole number (0 = off, empty = default)."); return end
            saveWf(tostring(n))
        end)
        if not opened then
            local nextValue = wfChoices[1]
            for i, v in ipairs(wfChoices) do if v == cur then nextValue = wfChoices[i % #wfChoices + 1] end end
            saveWf(nextValue)
        end
        return true
    end)
    call(panel, "addElement", wfButton)
    local function classicToggle(dvar, short, x, onText, offText)
        local b = make("UIButton")
        position(b, x, 746, 221, 44)
        footerFills[#footerFills + 1] = skin(b, 221, 44)
        footerButtons[#footerButtons + 1] = b
        call(b, "setFocusable", true)
        call(b, "setHandleMouse", true)
        local l = skinFont(text(b, "", 12, 7, 205, 30))
        call(l, "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
        local function update() call(l, "setText", short .. ": " .. (read(dvar) == "1" and "ON" or "OFF")) end
        update()
        call(b, "registerEventHandler", "button_action", function()
            local value = read(dvar) == "1" and "0" or "1"
            if write(dvar, value) then
                update()
                call(status, "setText", (value == "1" and onText or offText) .. " Applies next match.")
                do end
            else
                call(status, "setText", "Could not save the " .. short .. " setting.")
                do end
            end
            return true
        end)
        call(panel, "addElement", b)
    end
    classicToggle("bo7_cp_classic_wunderfizz", "CLASSIC FIZZ", 1372,
        "Classic Wunderfizz: it gives a random perk instead of opening its menu.", "Wunderfizz menu restored.")
    classicToggle("bo7_cp_classic_perk_cost", "CLASSIC COST", 1599,
        "Classic perk cost: every perk machine has its own fixed price.", "Perk prices grow with every perk owned again.")
    local limitChoices = {"", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "12", "15", "20"}
    local limitButton = make("UIButton")
    position(limitButton, 1372, 846, 448, 44)
    footerFills[#footerFills + 1] = skin(limitButton, 448, 44)
    footerButtons[#footerButtons + 1] = limitButton
    call(limitButton, "setFocusable", true)
    call(limitButton, "setHandleMouse", true)
    local limitLabel = skinFont(text(limitButton, "", 16, 7, 424, 30))
    call(limitLabel, "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
    local function limitName(v) return (v == "" or v == "0") and "NO LIMIT" or (v .. " PERKS") end
    local function updateLimitLabel() call(limitLabel, "setText", "PERK LIMIT: " .. limitName(read("bo7_cp_perk_limit"))) end
    updateLimitLabel()
    local function saveLimit(nextValue)
        if write("bo7_cp_perk_limit", nextValue) then
            updateLimitLabel()
            call(status, "setText", "Perk limit: " .. string.lower(limitName(nextValue)) .. " for the next match.")
            do end
        else
            call(status, "setText", "Could not save the perk limit.")
            do end
        end
    end
    call(limitButton, "registerEventHandler", "button_action", function()
        local cur = read("bo7_cp_perk_limit")
        local opened = numberPrompt(limitButton, "PERK LIMIT", "Most perks a player can buy. 0 = no limit.", cur == "" and "0" or cur, 2, function(t)
            local n = tonumber(t:match("^(%d+)$"))
            if not n then call(status, "setText", "Perk limit must be a whole number (0 = no limit)."); return end
            saveLimit(n == 0 and "" or tostring(n))
        end)
        if not opened then
            local nextValue = limitChoices[2]
            for i, v in ipairs(limitChoices) do if v == cur then nextValue = limitChoices[i % #limitChoices + 1] end end
            saveLimit(nextValue)
        end
        return true
    end)
    call(panel, "addElement", limitButton)
    if OVERCLOCKS_ENABLED then
    local ocButton = make("UIButton")
    position(ocButton, 1372, 112, 448, 44)
    footerFills[#footerFills + 1] = skin(ocButton, 448, 44)
    footerButtons[#footerButtons + 1] = ocButton
    call(ocButton, "setFocusable", true)
    call(ocButton, "setHandleMouse", true)
    local ocLabel = skinFont(text(ocButton, "EQUIPMENT OVERCLOCKS", 16, 7, 424, 30))
    call(ocLabel, "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
    call(ocButton, "registerEventHandler", "button_action", function()
        local ok, err = pcall(openOverclocks, parent, controller)
        if not ok then do end  end
        return true
    end)
    call(panel, "addElement", ocButton)
    end
    local perkaholic = make("UIButton")
    position(perkaholic, 1372, 896, 448, 44)
    footerFills[#footerFills + 1] = skin(perkaholic, 448, 44)
    footerButtons[#footerButtons + 1] = perkaholic
    call(perkaholic, "setFocusable", true)
    call(perkaholic, "setHandleMouse", true)
    local perkaholicLabel = skinFont(text(perkaholic, "", 12, 7, 424, 30))
    call(perkaholicLabel, "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
    local function updatePerkaholic()
        call(perkaholicLabel, "setText", "PERKAHOLIC: " .. (read("bo7_cp_perkaholic_classic") == "1" and "CLASSIC ONLY" or "CUSTOM INCLUDED"))
    end
    updatePerkaholic()
    call(perkaholic, "registerEventHandler", "button_action", function()
        local value = read("bo7_cp_perkaholic_classic") == "1" and "0" or "1"
        if write("bo7_cp_perkaholic_classic", value) then
            updatePerkaholic()
            call(status, "setText", "Perkaholic gives " .. (value == "1" and "native perks only." or "native and custom perks.") .. " Applies next match; host setting in co-op.")
        else
            call(status, "setText", "Could not save Perkaholic behaviour.")
        end
        return true
    end)
    call(panel, "addElement", perkaholic)
    local systemCredit = text(panel, "Custom perk system created by Gauty", 1372, 1007, 448, 28)
    call(systemCredit, "SetFontSize", 16 * (rawget(_G, "_PT") or 1))
    call(panel, "registerEventHandler", "button_secondary", function() close(); return true end)
    local function focusFooter(index)
        footerIndex = index
        for i, s in ipairs(footerFills) do paintSkin(s, i == index, false) end
        focus(footerButtons[index])
    end
    for i, button in ipairs(footerButtons) do
        local index = i
        call(button, "registerEventHandler", "button_over", function()
            footerIndex = index
            for j, s in ipairs(footerFills) do paintSkin(s, j == index, false) end
        end)
    end
    call(panel, "registerEventHandler", "gamepad_button", function(_, event)
        if not event or event.down == false then return end
        if event.button == "secondary" then close(); return true end
        if footerIndex then
            if event.button == "left" then focusFooter((footerIndex - 2) % #footerButtons + 1)
            elseif event.button == "right" then focusFooter(footerIndex % #footerButtons + 1)
            elseif event.button == "up" then select(selected); focus(buttons[selected])
            elseif event.button == "down" then return true
            else return end
            return true
        end
        local nextIndex = selected
        if event.button == "up" then nextIndex = selected > 4 and selected - 4 or selected
        elseif event.button == "down" then
            if selected + 4 > #buttons then
                focusFooter(1)
                return true
            end
            nextIndex = selected + 4
        elseif event.button == "left" then nextIndex = selected > 1 and selected - 1 or #buttons
        elseif event.button == "right" then nextIndex = selected < #buttons and selected + 1 or 1
        else return end
        select(nextIndex)
        focus(buttons[nextIndex])
        return true
    end)
    call(parent, "addElement", panel)
    S.panel = panel
    select(1)
    focus(buttons[1])
    do end
end
S.open = open
local function setValue(row, key, controller, value)
    local node = get(row, key)
    local f = get(node, "SetValue")
    assert(type(f) == "function", "missing button field " .. key)
    f(node, controller, value)
end
local function attach(menu, controller)
    if not frontend() or not zombies() then return end
    local ds = rawget(_G, "_DataSources")
    for _, key in ipairs({"mp", "weapons", "cac", "weapons_tab", "weapon_tab_buttons"}) do ds = get(ds, key) end
    assert(ds ~= nil, "weapons button datasource unavailable")
    local countNode = get(ds, "count")
    local count = tonumber(call(countNode, "GetValue", controller))
    assert(count and count >= 0 and count < 20, "invalid weapons button count")
    for i = 1, count do
        if call(get(get(ds, i), "auto_id"), "GetValue", controller) == "gautys_custom_perks" then return end
    end
    local insertion = 2
    local weapon = rawget(_G, "WEAPON")
    local loadoutId = get(get(weapon, "weapontabbuttonid"), "loadouts")
    for i = 1, count do
        local source = get(ds, i)
        local id = call(get(source, "button_id"), "GetValue", controller)
        local autoId = call(get(source, "auto_id"), "GetValue", controller)
        if (loadoutId ~= nil and id == loadoutId) or autoId == "loadouts_weaponmenubutton" then
            insertion = i + 1
            break
        end
    end
    if insertion > count + 1 then insertion = count + 1 end
    local fields = {"Label", "command", "is_locked", "unlock_string", "auto_id", "button_id"}
    for i = count, insertion, -1 do
        local source, destination = get(ds, i), get(ds, i + 1)
        assert(destination ~= nil, "weapons button row unavailable")
        for _, key in ipairs(fields) do
            setValue(destination, key, controller, call(get(source, key), "GetValue", controller))
        end
    end
    local row = get(ds, insertion)
    assert(row ~= nil, "weapons button row unavailable")
    setValue(row, "Label", controller, "CUSTOM PERKS")
    local commandNew = get(get(rawget(_G, "LUI"), "Command"), "new")
    assert(type(commandNew) == "function", "LUI.Command constructor unavailable")
    local command = commandNew(function()
        do end
        local ok, err = pcall(open, menu, controller)
        if not ok then do end  end
    end)
    setValue(row, "command", controller, command)
    setValue(row, "is_locked", controller, false)
    setValue(row, "unlock_string", controller, "")
    setValue(row, "auto_id", controller, "gautys_custom_perks")
    setValue(row, "button_id", controller, 1985)
    call(countNode, "SetValue", controller, count + 1)
    do end
end
local function hook()
    local owner = rawget(_G, "WEAPON")
    if type(owner) ~= "table" then return end
    local keys = {"initweapontabbuttonsdatasource"}
    if type(H) == "function" then keys[#keys + 1] = H(keys[1]) end
    for _, key in ipairs(keys) do
        local original = owner[key]
        if type(original) == "function" and S.hooks[key] ~= original then
            local wrapper = function(menu, controller, ...)
                local result = original(menu, controller, ...)
                local current = rawget(_G, "BO7PerkToggles")
                if current == S and S.enabled then
                    local ok, err = pcall(attach, menu, controller)
                    if not ok then
                        once("attach", "Native button list unavailable: " .. tostring(err))
                        if not get(menu, "gautysPerkToggleButton") then
                            local added, failure = pcall(function()
                                local button = make("UIButton")
                                position(button, 90, 810, 340, 55)
                                text(button, "CUSTOM PERKS", 12, 6, 320, 40)
                                call(button, "setHandleMouse", true)
                                call(button, "setFocusable", true)
                                call(button, "registerEventHandler", "button_action", function()
                                    local opened, detail = pcall(open, menu, controller)
                                    if not opened then do end  end
                                    return true
                                end)
                                call(menu, "addElement", button)
                                menu.gautysPerkToggleButton = button
                            end)
                            if not added then once("fallback", "ERROR adding fallback button: " .. tostring(failure)) end
                        end
                    end
                end
                return result
            end
            owner[key] = wrapper
            S.hooks[key] = wrapper
            once("hook", "Weapons tab hook installed")
        end
    end
end
local function isName(name, wanted)
    if name == wanted then return true end
    if type(H) == "function" then
        local ok, h = pcall(H, wanted)
        if ok and h ~= nil and name == h then return true end
    end
    return false
end
local function attachPauseFrameButton(list, controller)
    if frontend() or not list or get(list, "gautysFrameButton") then return end
    local choices = {{id = 0, name = "Default"}}
    for _, entry in ipairs(rawget(_G, "BO7EternalFramePacks") or {}) do choices[#choices + 1] = entry end
    local function index()
        local id = tonumber(read("bo7_cp_eternal_frame_style")) or 0
        for i, entry in ipairs(choices) do if entry.id == id then return i end end
        return 1
    end
    local builder = rawget(_G, "MenuBuilder")
    local okB, button = pcall(function() return get(builder, "BuildRegisteredType")("genericbutton", { controllerIndex = controller }) end)
    local label
    if okB and button and get(button, "text") then
        label = get(button, "text")
        call(label, "SetLeft", 52, 0)
    else
        button = make("UIButton")
        local s = skin(button, 500, 51)
        call(button, "setFocusable", true)
        call(button, "setHandleMouse", true)
        label = skinFont(text(button, "", 52, 8, 440, 34))
        call(label, "SetFontSize", 18 * (rawget(_G, "_PT") or 1))
        paintSkin(s, false, false, label)
        call(button, "registerEventHandler", "button_over", function() paintSkin(s, true, false, label) end)
        call(button, "registerEventHandler", "button_up", function() paintSkin(s, false, false, label) end)
    end
    button.id = "gautysFrameButton"
    call(button, "SetAnchorsAndPosition", 0, 0, 0, 1, 0, 0, 0, 51)
    local function refresh() call(label, "setText", "ETERNAL FRAME: " .. string.upper(choices[index()].name)) end
    refresh()
    call(button, "registerEventHandler", "button_action", function()
        local nextChoice = choices[index() % #choices + 1]
        if not write("bo7_cp_eternal_frame_style", tostring(nextChoice.id)) then do end  end
        refresh()
        return true
    end)
    local function relOf(e, m) local okR, v = pcall(function() return e[m](e) end); return okR and v or nil end
    local anchor = get(list, "LeaveGameButton")
    local nextOne = anchor and relOf(anchor, "getNextSibling")
    if nextOne and nextOne ~= relOf(list, "getLastChild") then anchor = nextOne end
    local placed = anchor and pcall(function() button:addElementAfter(anchor) end)
    if not placed then call(list, "addElement", button) end
    list.gautysFrameButton = button
    do end
end
local function hookPauseBuild()
    if S.pauseHooked then return end
    local builder = rawget(_G, "MenuBuilder")
    local original = get(builder, "BuildRegisteredType")
    if type(original) ~= "function" then return end
    S.pauseHooked = true
    local wrapper = function(name, options, ...)
        local widget = original(name, options, ...)
        if S.enabled and widget ~= nil and isName(name, "zmpausemenubuttons") then
            do end
            local ok, err = pcall(attachPauseFrameButton, widget, type(options) == "table" and options.controllerIndex or 0)
            if not ok then once("pauseFrameErr", "pause menu frame button error: " .. tostring(err)) end
        end
        return widget
    end
    local okSet, err = pcall(function()
        if builder.BuildRegisteredType ~= nil or type(H) ~= "function" then builder.BuildRegisteredType = wrapper else builder[H("BuildRegisteredType")] = wrapper end
    end)
    if okSet then do end  else do end  end
end
local function rel(e, method) local ok, v = pcall(function() return e[method](e) end); return ok and v or nil end
local function findById(el, id, depth)
    if el == nil or depth > 14 then return nil end
    local c, n = rel(el, "getFirstChild"), 0
    while c ~= nil and n < 500 do
        if isName(get(c, "id"), id) then return c end
        local hit = findById(c, id, depth + 1)
        if hit then return hit end
        c, n = rel(c, "getNextSibling"), n + 1
    end
end
local function hookPauseMenuBuild()
    if S.pauseMenuHooked then return end
    local builder = rawget(_G, "MenuBuilder")
    local original = get(builder, "buildMenu")
    if type(original) ~= "function" then return end
    S.pauseMenuHooked = true
    local wrapper = function(name, ...)
        local menu = original(name, ...)
        if S.enabled and menu ~= nil and not frontend() and (isName(name, "mppausemenu") or isName(name, "sppausemenu")) then
            local timer = call(menu, "Wait", 300)
            if timer then
                timer.onComplete = function()
                    local ok, err = pcall(function()
                        local function parentOf(e) local okP, p = pcall(function() return e:getParent() end); return okP and p or nil end
                        local top, guard = menu, 0
                        while parentOf(top) ~= nil and guard < 30 do top, guard = parentOf(top), guard + 1 end
                        local getRoot = get(rawget(_G, "LUI"), "GetRoot")
                        local list = findById(top, "zmpausemenubuttons", 0)
                        if not list and type(getRoot) == "function" then list = findById(getRoot(), "zmpausemenubuttons", 0) end
                        if not list then once("pauseListMissing", "pause menu open but no zmpausemenubuttons list found"); return end
                        if not get(list, "gautysFrameButton") then attachPauseFrameButton(list, 0) end
                    end)
                    if not ok then once("pauseFallbackErr", "pause list search error: " .. tostring(err)) end
                end
            end
        end
        return menu
    end
    local okSet, err = pcall(function()
        if builder.buildMenu ~= nil or type(H) ~= "function" then builder.buildMenu = wrapper else builder[H("buildMenu")] = wrapper end
    end)
    if not okSet then do end  end
end
local function tick()
    if not S.enabled then return end
    hook()
    hookPauseBuild()
    hookPauseMenuBuild()
    local f = get(rawget(_G, "LUI"), "GetRoot")
    if type(f) ~= "function" then return end
    local ok, root = pcall(f)
    if not ok or not root then return end
    local timer = call(root, "Wait", 1000)
    if timer then timer.onComplete = tick end
end
tick()
do end
