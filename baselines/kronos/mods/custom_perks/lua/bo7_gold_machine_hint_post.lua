local VERSION = 17
local placeNative
local TITLE = "GAUTY'S GOLD"
local DESCRIPTION = "Drink to earn 1.25x points."
local ICON = "ui_icon_perks_zm_Gautys_Gold"
local LAYOUT = {
    x = -225,
    y = 165,
    boxW = 150,
    boxH = 113,
    gap = 4,
    panelW = 296,
    titleH = 22,
    iconSize = 66,
}
local H = rawget(_G, "xhash")
local function log(...) end
local old = rawget(_G, "BO7GoldMachineHint")
if old and old.version == VERSION then return end
if old then
    old.enabled = false
    if old.widget then pcall(function() old.widget.root:closeTree() end) end
    if old.native then pcall(function() old.native.root:closeTree() end) end
end
local S = { version = VERSION, enabled = true, active = false }
rawset(_G, "BO7GoldMachineHint", S)
local function hk(name)
    if type(H) ~= "function" then return nil end
    local ok, v = pcall(H, name)
    if ok then return v end
    return nil
end
local function g(t, k)
    if t == nil then return nil end
    local ok, v = pcall(function()
        local hv = hk(k)
        local r
        if hv ~= nil then r = t[hv] end
        if r == nil then r = t[k] end
        return r
    end)
    if ok then return v end
    return nil
end
local function call(o, name, ...)
    local f = g(o, name)
    if type(f) ~= "function" then return nil end
    local ok, r = pcall(f, o, ...)
    if ok then return r end
    return nil
end
local function findFn(tbl, name)
    for _, key in ipairs({ name, hk(name), hk(name:lower()) }) do
        if key ~= nil then
            local ok, f = pcall(function() return tbl[key] end)
            if ok and type(f) == "function" then return key, f end
        end
    end
    return nil
end
local function readDvar(name)
    local getter = g(rawget(_G, "Dvar"), "GetDvarString")
    local hashDvar = rawget(_G, "xhashdvar") or g(rawget(_G, "CLUA"), "PushXHashDvar")
    if type(getter) ~= "function" or type(hashDvar) ~= "function" then return nil end
    local okH, h = pcall(hashDvar, name)
    if not okH then return nil end
    local ok, v = pcall(getter, h)
    if not ok or v == nil then return nil end
    return tostring(v)
end
local function localize(key, fallback)
    local f = g(rawget(_G, "Engine"), "Localize")
    if type(f) == "function" then
        local ok, r = pcall(f, key)
        if ok and type(r) == "string" and r ~= "" and r ~= key then return r end
    end
    return fallback
end
local function iconMaterial()
    local icon = ICON
    local cp = rawget(_G, "BO7CustomPerks")
    if cp and type(cp.resolvePerkPackIcon) == "function" then
        local ok, r = pcall(cp.resolvePerkPackIcon, icon)
        if ok and r ~= nil then icon = r end
    end
    if S.iconKey == icon and S.iconMat then return S.iconMat end
    local asset = icon
    local hashAsset = rawget(_G, "xhashasset") or g(rawget(_G, "CLUA"), "PushXHashAsset")
    if type(hashAsset) == "function" then
        local ok, v = pcall(hashAsset, icon)
        if ok and v ~= nil then asset = v end
    end
    local register = rawget(_G, "RegisterMaterial")
    if type(register) ~= "function" then return nil end
    local ok, mat = pcall(register, asset)
    if ok and mat ~= nil then
        S.iconKey, S.iconMat = icon, mat
        return mat
    end
    if not S.loggedIcon then S.loggedIcon = true; do end  end
    return nil
end
local function newElement(kind)
    local ctor = g(g(rawget(_G, "LUI"), kind), "new")
    if type(ctor) ~= "function" then error("LUI." .. kind .. ".new unavailable", 0) end
    local e = ctor()
    call(e, "SetHandleMouse", false)
    return e
end
local function place(e, x, y, w, h)
    call(e, "SetAnchorsAndPosition", 0.5, 0.5, 0.5, 0.5, x, x + w, y, y + h)
end
local function rect(parent, x, y, w, h, rgb, alpha)
    local e = newElement("UIImage")
    place(e, x, y, w, h)
    call(e, "SetRGB", rgb)
    call(e, "SetAlpha", alpha, 0)
    call(parent, "addElement", e)
    return e
end
local function text(parent, x, y, w, h, size, rgb, align, fontNames)
    local e = newElement("UIStyledText")
    place(e, x, y, w, h)
    local fonts = rawget(_G, "FONT_HANDLE")
    for _, name in ipairs(fontNames) do
        local font = g(fonts, name)
        if font then call(e, "SetFont", font); break end
    end
    call(e, "SetFontSize", size * (tonumber(rawget(_G, "_PT")) or 1))
    call(e, "SetRGB", rgb)
    call(e, "SetAlignment", align or 0)
    call(parent, "addElement", e)
    return e
end
local function setText(e, s)
    if e == nil then return end
    if call(e, "setText", s) == nil then call(e, "SetText", s) end
end
local function build()
    local lui = rawget(_G, "LUI")
    local getRoot = g(lui, "GetRoot")
    if type(getRoot) ~= "function" then return nil end
    local okRoot, root = pcall(getRoot)
    if not okRoot or root == nil then return nil end
    local L = LAYOUT
    local w = {}
    local container = newElement("UIElement")
    call(container, "SetAnchorsAndPosition", 0, 0, 0, 0, 0, 0, 0, 0)
    call(container, "SetAlpha", 0, 0)
    w.root = container
    local bx, by = L.x, L.y
    local px = bx + L.boxW + L.gap
    w.boxBg = rect(container, bx, by, L.boxW, L.boxH, 0x0d1013, 0.78)
    w.boxEdge = rect(container, bx, by, L.boxW, 1, 0x5a6470, 0.6)
    w.icon = newElement("UIImage")
    place(w.icon, bx + (L.boxW - L.iconSize) / 2, by + 10, L.iconSize, L.iconSize)
    call(w.icon, "SetAlpha", 1, 0)
    call(container, "addElement", w.icon)
    w.cost = text(container, bx + 4, by + L.boxH - 30, L.boxW - 8, 22, 22, 0xffffff, 1,
        { "SecondaryRegular", "TertiaryMedium", "PrimaryRegular" })
    w.titleBg = rect(container, px, by, L.panelW, L.titleH, 0x2b3644, 0.9)
    w.title = text(container, px + 8, by + 2, L.panelW - 16, L.titleH - 4, 18, 0xffffff, 0,
        { "PrimaryBold", "TertiaryMedium", "SecondaryRegular" })
    w.descBg = rect(container, px, by + L.titleH, L.panelW, L.boxH - L.titleH, 0x0d1013, 0.6)
    w.desc = text(container, px + 8, by + L.titleH + 10, L.panelW - 16, 22, 19, 0xc9ccd0, 0,
        { "SecondaryRegular", "TertiaryMedium", "PrimaryRegular" })
    w.aux = text(container, px + 8, by + L.boxH - 30, L.panelW - 16, 20, 17, 0xff3c3c, 0,
        { "SecondaryRegular", "TertiaryMedium", "PrimaryRegular" })
    call(root, "addElement", container)
    do end
    return w
end
local function costString(cost, notEnough)
    local key = notEnough and "shared_hintstrings/cost_essence_not_enough" or "shared_hintstrings/cost_essence"
    local fmt = localize(key, notEnough and "Cost ^B^1&&1" or "Cost ^B&&1")
    local out = fmt:gsub("&&1", tostring(cost))
    return out
end
local NATIVE_TYPE = "zminteractiveobjectbutton"
local NATIVE_MODULE = "ui.generated.widgets.ingame.zm.sat.zminteractiveobjectbutton"
local NATIVE_LARGE = { "BlurMask", "blur", "BACKER", "iconbacker", "icon", "icontext",
    "text", "description", "buttoncallout" }
local NATIVE_UNUSED = { "circlecentericon", "ProgressBar", "zminteractiveobjectsecondbuttontemp",
    "gobbleguminteractiveobjectamount", "warningbanner" }
function placeNative(w)
    call(w, "SetSnapToLocation", false)
    local x, y = LAYOUT.x, LAYOUT.y
    call(w, "SetAnchorsAndPosition", 0.5, 0.5, 0.5, 0.5, x, x + 40, y, y + 40)
end
local function buildNative()
    local build = g(rawget(_G, "MenuBuilder"), "BuildRegisteredType")
    if type(build) ~= "function" then error("MenuBuilder.BuildRegisteredType unavailable", 0) end
    local function try(name)
        if name == nil then return nil end
        local ok, w = pcall(build, name, { controllerIndex = 0 })
        if ok and w ~= nil then return w end
        return nil
    end
    local w = try(NATIVE_TYPE) or try(hk(NATIVE_TYPE))
    if w == nil then
        local req = rawget(_G, "requireUnlessHotload")
        if type(req) == "function" then
            pcall(req, NATIVE_MODULE, NATIVE_TYPE)
            pcall(req, hk(NATIVE_MODULE), hk(NATIVE_TYPE))
        end
        w = try(NATIVE_TYPE) or try(hk(NATIVE_TYPE))
    end
    if w == nil then error("could not build " .. NATIVE_TYPE, 0) end
    local n = { root = w }
    for _, name in ipairs(NATIVE_LARGE) do n[name] = g(w, name) end
    for _, name in ipairs(NATIVE_UNUSED) do n[name] = g(w, name) end
    n.buttonIcon = g(w, "InteractiveObjectButtonIcon")
    n.kbmprogress = g(w, "kbmprogress")
    local known = {}
    for k, v in pairs(n) do if v ~= nil then known[v] = true end end
    pcall(function()
        for k, v in pairs(w) do
            if type(k) ~= "string" and type(v) == "table" and not known[v] then
                local okId, id = pcall(function() return v.id end)
                if okId and id == k then
                    if type(g(v, "SetFontSize")) == "function" then n.aux = v else n.frame = v end
                end
            end
        end
    end)
    local okRoot, root = pcall(g(rawget(_G, "LUI"), "GetRoot"))
    if not okRoot or root == nil then error("LUI root unavailable", 0) end
    call(w, "SetAlpha", 0, 0)
    call(root, "addElement", w)
    placeNative(w)
    do end
    return n
end
local function nativeSetText(e, s)
    if e == nil then return end
    local okGet, cur = pcall(function() return e:getText() end)
    if okGet and cur == s then return end
    setText(e, s)
end
local function applyNative(n, state, cost)
    placeNative(n.root)
    for _, name in ipairs(NATIVE_LARGE) do
        call(n[name], "SetVisible", true)
        call(n[name], "SetAlpha", 1, 0)
    end
    if n.frame then call(n.frame, "SetVisible", true); call(n.frame, "SetAlpha", 1, 0) end
    if n.aux then call(n.aux, "SetVisible", true); call(n.aux, "SetAlpha", 1, 0) end
    for _, name in ipairs(NATIVE_UNUSED) do
        call(n[name], "SetVisible", false)
    end
    local mat = iconMaterial()
    if mat and n.icon then call(n.icon, "setImage", mat, 0) end
    nativeSetText(n.text, TITLE)
    nativeSetText(n.description, DESCRIPTION)
    local buy = localize("shared_hintstrings/perk_machine_buy", "^BBUY")
    if state == "owned" then
        nativeSetText(n.icontext, "")
        nativeSetText(n.aux, localize("shared_hintstrings/equipped", "^1^BEquipped"))
        nativeSetText(n.buttoncallout, "")
    elseif state == "poor" then
        nativeSetText(n.icontext, costString(cost, true))
        nativeSetText(n.aux, localize("shared_hintstrings/not_enough_essence", "^1^BNOT ENOUGH ESSENCE"))
        nativeSetText(n.buttoncallout, "")
    else
        nativeSetText(n.icontext, cost and costString(cost, false) or "")
        nativeSetText(n.aux, "")
        nativeSetText(n.buttoncallout, buy)
    end
    local glyph = state == "buy"
    call(n.buttonIcon, "SetVisible", glyph)
    call(n.buttonIcon, "SetAlpha", glyph and 1 or 0, 0)
    call(n.kbmprogress, "SetVisible", glyph)
    call(n.root, "SetAlpha", 1, 0)
end
local function show(state, cost)
    if S.native == nil and not S.nativeFailed then
        local ok, n = pcall(buildNative)
        if ok and n then
            S.native = n
        else
            S.nativeFailed = true
            do end
        end
    end
    if S.native then
        local key = state .. "|" .. tostring(cost)
        if S.shownKey ~= key then
            S.shownKey = key
            pcall(function() S.native.root:AnimateSequence("inRange") end)
            if state == "buy" then pcall(function() S.native.root:AnimateSequence("operable") end) end
        end
        applyNative(S.native, state, cost)
        return
    end
    if S.widget == nil then
        local ok, w = pcall(build)
        if not ok then
            if not S.loggedBuild then S.loggedBuild = true; do end  end
            return
        end
        S.widget = w
    end
    local w = S.widget
    if w == nil then return end
    local key = state .. "|" .. tostring(cost)
    if S.shownKey ~= key then
        S.shownKey = key
        local mat = iconMaterial()
        if mat then call(w.icon, "setImage", mat, 0) end
        setText(w.title, TITLE)
        setText(w.desc, DESCRIPTION)
        if state == "owned" then
            setText(w.cost, "")
            setText(w.aux, localize("shared_hintstrings/equipped", "^1^BEquipped"))
            call(w.aux, "SetRGB", 0xff3c3c)
        elseif state == "poor" then
            setText(w.cost, costString(cost, true))
            setText(w.aux, localize("shared_hintstrings/not_enough_essence", "^1^BNOT ENOUGH ESSENCE"))
            call(w.aux, "SetRGB", 0xff3c3c)
        else
            setText(w.cost, cost and costString(cost, false) or "")
            setText(w.aux, "Press ^BUSE^ to " .. localize("shared_hintstrings/perk_machine_buy", "^BBUY"))
            call(w.aux, "SetRGB", 0xffffff)
        end
    end
    call(w.root, "SetAlpha", 1, 0)
end
local function hide()
    S.shownKey = nil
    if S.native then call(S.native.root, "SetAlpha", 0, 0) end
    if S.widget then call(S.widget.root, "SetAlpha", 0, 0) end
end
local STATES = { "buy", "owned", "poor" }
do
    local v = 249 * 40000 + 3 * 10000 + 9999
    assert(v <= 10000000 and math.floor(v / 40000) == 249 and math.floor(v / 10000) % 4 == 3 and v % 10000 == 9999, "machine prompt packing")
    v = 97 * 40000 + 1 * 10000 + 300
    assert(math.floor(v / 40000) == 97 and math.floor(v / 10000) % 4 == 1 and (v % 10000) * 10 == 3000, "machine prompt packing 97")
end
local function perkByCode(code)
    local cp = rawget(_G, "BO7CustomPerks")
    for _, c in ipairs(cp and cp.customPerks or {}) do
        if c.code == code then return { c.name, c.hudIcon or c.icon, c.desc } end
    end
end
local function readPromptCode()
    local get = g(rawget(_G, "Game"), "getomnvar")
    if type(get) ~= "function" then return 0 end
    local ok, v = pcall(get, 0, "ui_br_objective_loot_id")
    return ok and tonumber(v) or 0
end
local function serverPrompt()
    local code = readPromptCode()
    if code ~= S.lastCode then S.lastCode = code; do end  end
    if code <= 0 then return nil end
    local perk = perkByCode(math.floor(code / 40000))
    local state = STATES[math.floor(code / 10000) % 4]
    if not perk or not state then return nil end
    return state, (code % 10000) * 10, perk
end
local DEBUG_DVARS = { "bo7_cp_machine_runtime" }
local function tick()
    local state, cost, perk = serverPrompt()
    if state then
        if perk[1] ~= TITLE or perk[3] ~= DESCRIPTION or perk[2] ~= ICON then
            TITLE, ICON, DESCRIPTION = perk[1], perk[2], perk[3]
            S.shownKey = nil
        end
        show(state, cost)
        S.active = true
    elseif S.active then
        S.active = false
        hide()
    end
end
local frame = rawget(_G, "Frame")
local dw = frame and (g(frame, "DoWork") or frame.DoWork)
local _, qfn
if dw then _, qfn = findFn(dw, "Queue") end
if qfn then
    qfn(dw, function()
        if not S.enabled then return false end
        local ok, err = pcall(tick)
        if not ok and not S.loggedErr then S.loggedErr = true; do end  end
        return true
    end)
    do end
else
    do end
end
