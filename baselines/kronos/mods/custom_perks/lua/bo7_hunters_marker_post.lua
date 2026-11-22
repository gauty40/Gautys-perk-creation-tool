local H = rawget(_G, "xhash")
local function get(t, key)
    if not t then return nil end
    local ok, value = pcall(function() return t[key] end)
    if ok and value ~= nil then return value end
    if type(H) == "function" then
        ok, value = pcall(function() return t[H(key)] end)
        if ok then return value end
    end
end
local function log(...) end
local api = rawget(_G, "OBJECTIVEWIDGET")
local initialize = get(api, "initialize")
if type(initialize) ~= "function" then do end ; return end
local previous = rawget(_G, "BO7HoochWidgetImage")
if previous and previous.version == 4 then return end
if previous then previous.enabled = false end
local S = {version = 4, enabled = true}
local MARKER_ICONS = { empty_ring_default = true }
for _, hasher in ipairs({ rawget(_G, "xhashasset"), get(rawget(_G, "CLUA"), "PushXHashAsset"), H }) do
    if type(hasher) == "function" then
        local ok, v = pcall(hasher, "empty_ring_default")
        if ok and v ~= nil then MARKER_ICONS[v] = true; MARKER_ICONS[tostring(v)] = true end
    end
end
rawset(_G, "BO7HoochWidgetImage", S)
local function apply(widget)
    if not S.enabled then return end
    for _, entry in ipairs(widget._hoochHiddenBackers or {}) do
        local alpha = get(entry.element, "SetAlpha")
        if type(alpha) == "function" then alpha(entry.element, entry.alpha, 0) end
    end
    widget._hoochHiddenBackers = nil
    local dvar = get(rawget(_G, "Dvar"), "GetDvarString")
    local dh = rawget(_G, "xhashdvar") or get(rawget(_G, "CLUA"), "PushXHashDvar")
    if type(dvar) ~= "function" or type(dh) ~= "function" then return end
    local ids = dvar(dh("bo7_hm_marker_ids"))
    if type(ids) ~= "string" then ids = "," end
    local code = get(widget, "_objectiveCodeIndex")
    local data = get(widget, "_data")
    local id = code or get(data, "objectiveId")
    local matches = id ~= nil and ids:find("," .. tostring(id) .. ",", 1, true)
    if not matches then
        local source = get(get(widget, "_objectiveData"), "icon")
        local getValue = get(source, "GetValue")
        local ok, icon = false, nil
        if type(getValue) == "function" then ok, icon = pcall(getValue, source, get(widget, "_controllerIndex") or 0) end
        if ok and icon ~= nil and (MARKER_ICONS[icon] or MARKER_ICONS[tostring(icon)]) then matches = true end
    end
    if not matches and ids == "," then return end
    if not matches then
        local readObjectives = get(rawget(_G, "Game"), "getobjectives")
        local index = get(widget, "_objectiveIndex")
        if type(readObjectives) == "function" then
            local list, byGlobal = readObjectives(get(widget, "_controllerIndex") or 0)
            for serverId in ids:gmatch("%d+") do
                local row = type(byGlobal) == "table" and byGlobal[tonumber(serverId)]
                if row then
                    local rowIndex = get(row, "index")
                    if row == data or (index ~= nil and rowIndex == index) then matches = true end
                    if not matches and type(list) == "table" then
                        for clientIndex, entry in pairs(list) do
                            if entry == row and (clientIndex == index or entry == data) then matches = true; break end
                        end
                    end
                    if matches then id = tonumber(serverId); break end
                end
            end
        end
    end
    if not matches then
        local diagnostic = tostring(code) .. "/" .. tostring(get(widget, "_objectiveIndex")) .. "/" .. tostring(get(data, "objectiveId"))
        S.seen = S.seen or {}
        if not S.seen[diagnostic] then S.seen[diagnostic] = true; do end  end
        return
    end
    local icon = get(widget, "icon")
    local image = get(icon, "icon") or icon
    local setImage = get(image, "setImage")
    if type(setImage) ~= "function" then
        if not S.noImage then S.noImage = true; do end  end
        return
    end
    if not S.material then
        local ah = rawget(_G, "xhashasset") or get(rawget(_G, "CLUA"), "PushXHashAsset")
        local register = rawget(_G, "RegisterMaterial")
        if type(ah) ~= "function" or type(register) ~= "function" then return end
        S.material = register(ah("mark_marker"))
    end
    if S.material then
        setImage(image, S.material, 0)
        local hidden = {}
        local function hide(parent, key)
            local element = get(parent, key)
            if not element or element == image or element == icon then return end
            local alpha = get(element, "SetAlpha")
            if type(alpha) ~= "function" then return end
            local oldAlpha = 1
            local readAlpha = get(element, "GetCurrentAlpha")
            if type(readAlpha) == "function" then
                local ok, value = pcall(readAlpha, element)
                if ok and type(value) == "number" then oldAlpha = value end
            end
            hidden[#hidden + 1] = {element = element, alpha = oldAlpha}
            alpha(element, 0, 0)
        end
        for _, key in ipairs({"Frame", "BackgroundFrame", "StatusPlate", "iconbacker", "IconBacker", "Pulse", "Glow", "BlurMask"}) do hide(widget, key) end
        for _, key in ipairs({"iconbackplateleft", "iconbackplateright", "iconbacker", "Frame", "BackgroundFrame"}) do hide(icon, key) end
        widget._hoochHiddenBackers = hidden
        local rgb = get(image, "SetRGB")
        if type(rgb) == "function" then rgb(image, 0xffffff, 0) end
        if not S.applied then S.applied = true; do end  end
    end
end
local function update(widget)
    local ok, err = pcall(apply, widget)
    if not ok and not S.error then S.error = true; do end  end
end
local function wrapper(widget, ...)
    local result = initialize(widget, ...)
    local originalUpdate = get(widget, "Update")
    if type(originalUpdate) == "function" and widget._hoochImageWrapped ~= S then
        widget._hoochImageWrapped = S
        widget.Update = function(self, ...)
            local value = originalUpdate(self, ...)
            update(self)
            return value
        end
    end
    update(widget)
    return result
end
for _, key in ipairs({"initialize", type(H) == "function" and H("initialize") or "initialize"}) do
    if type(api[key]) == "function" then api[key] = wrapper end
end
do end
