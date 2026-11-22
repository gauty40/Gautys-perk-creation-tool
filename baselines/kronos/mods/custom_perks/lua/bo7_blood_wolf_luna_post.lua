local previous = rawget(_G, "BO7BloodWolfLuna")
if previous then previous.enabled = false end
local S = { enabled = true }
rawset(_G, "BO7BloodWolfLuna", S)
local NAME = "Luna"
local H = rawget(_G, "xhash")
local function get(t, k) if t == nil then return nil end local ok, v = pcall(function() return t[k] end); return ok and v or nil end
local function log(message)
    local dp = nil
    if type(dp) == "function" then pcall(dp, "[BloodWolfLuna] " .. message) end
end
local function isHoundName(name)
    if type(name) ~= "string" or name == "" then return false end
    if name:upper():find("HOUND", 1, true) then return true end
    local localize = get(rawget(_G, "Engine"), "Localize")
    if type(localize) == "function" then
        local ok, text = pcall(localize, name)
        if ok and type(text) == "string" and text:upper():find("HOUND", 1, true) then return true end
    end
    return false
end
assert(isHoundName("Hellhound") and isHoundName("ZM/HELLHOUND") and not isHoundName("Mangler") and not isHoundName(nil), "luna name match")
local function wrap(tbl, name, store, makeWrapper)
    local key, current = name, get(tbl, name)
    if type(current) ~= "function" and type(H) == "function" then
        local ok, hashed = pcall(H, name)
        if ok and hashed ~= nil then key, current = hashed, get(tbl, hashed) end
    end
    if type(current) ~= "function" then
        S.missing = S.missing or {}
        if not S.missing[store] then S.missing[store] = true; log("not found yet: " .. store) end
        return false
    end
    local wrappers = rawget(_G, "BO7BloodWolfLunaWrappers") or {}
    rawset(_G, "BO7BloodWolfLunaWrappers", wrappers)
    if current == wrappers[store] and S.installed and S.installed[store] then return true end
    local base = current
    if current == wrappers[store] then base = wrappers[store .. "Base"] end
    local wrapper = makeWrapper(base)
    if not pcall(function() tbl[key] = wrapper end) then return false end
    wrappers[store], wrappers[store .. "Base"] = wrapper, base
    S.installed = S.installed or {}
    S.installed[store] = true
    log("wrapped " .. store)
    return true
end
local function global(name)
    local v = rawget(_G, name)
    if v == nil then v = get(_G, name) end
    if v == nil and type(H) == "function" then
        local ok, hashed = pcall(H, name)
        if ok and hashed ~= nil then v = rawget(_G, hashed) or get(_G, hashed) end
    end
    return v
end
local function report()
    if S.reported or (S.installed and S.installed.names) then return end
    S.frames = (S.frames or 0) + 1
    if S.frames < 600 then return end
    S.reported = true
    local hashed = type(H) == "function" and select(2, pcall(H, "HEALTHBAR")) or nil
    log("names still not hooked: rawget=" .. type(rawget(_G, "HEALTHBAR")) .. " _G.HEALTHBAR=" .. type(get(_G, "HEALTHBAR"))
        .. " hashed=" .. type(hashed ~= nil and get(_G, hashed) or nil)
        .. " getentityname=" .. type(get(global("HEALTHBAR"), "getentityname")))
end
local STATE_NAMES = { "friendly", "companion", "enemy" }
local STATE_HASHES = {}
if type(H) == "function" then
    for _, n in ipairs(STATE_NAMES) do
        local ok, h = pcall(H, n)
        if ok and h ~= nil then STATE_HASHES[#STATE_HASHES + 1] = { hash = h, name = n } end
    end
end
local function stateOf(sequence)
    if type(sequence) == "string" then
        local lower = sequence:lower()
        for _, n in ipairs(STATE_NAMES) do if lower == n then return n end end
    end
    for _, e in ipairs(STATE_HASHES) do
        if sequence == e.hash or tostring(sequence) == tostring(e.hash) then return e.name end
    end
end
local function install()
    local bar = global("HEALTHBAR")
    local function renamed(name)
        local state = S.state
        S.state = nil
        if not (S.enabled and isHoundName(name)) then return name end
        local friendly = state == "friendly" or state == "companion" or state == "nameplate"
        S.seen = S.seen or {}
        local key = tostring(state) .. "/" .. tostring(friendly)
        if not S.seen[key] then
            S.seen[key] = true
            log("hound name: last state " .. tostring(state) .. ", renamed " .. tostring(friendly))
        end
        if friendly then return NAME end
        return name
    end
    local names = wrap(bar, "getentityname", "names", function(base)
        return function(...)
            local name = base(...)
            local ok, result = pcall(renamed, name)
            if ok then return result end
            return name
        end
    end)
    local plate = wrap(bar, "getentitynameplateanchoroptions", "plate", function(base)
        return function(...)
            if S.enabled then S.state = "nameplate" end
            return base(...)
        end
    end)
    local states = wrap(global("ACTIONS"), "AnimateSequence", "states", function(base)
        return function(widget, sequence, ...)
            if S.enabled then
                local ok, state = pcall(stateOf, sequence)
                if ok and state then S.state = state end
            end
            return base(widget, sequence, ...)
        end
    end)
    return names and plate and states
end
pcall(install)
local dw = get(rawget(_G, "Frame"), "DoWork")
local queue
for _, key in ipairs({ "Queue", type(H) == "function" and H("Queue") or "Queue" }) do
    local f = get(dw, key)
    if type(f) == "function" then queue = f; break end
end
if queue then
    queue(dw, function()
        if not S.enabled then return false end
        pcall(install)
        pcall(report)
        return true
    end)
else
    log("no frame queue")
end
