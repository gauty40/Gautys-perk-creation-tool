local previous = rawget(_G, "BO7WhosWhoPrompt")
if previous then
    previous.enabled = false
    if previous.group then pcall(function() previous.group:close() end) end
    if previous.cd then pcall(function() previous.cd:close() end) end
end
local S = { enabled = true }
rawset(_G, "BO7WhosWhoPrompt", S)
local REVIVE_MS = 1500
local BAR_W, BAR_H, BAR_Y = 420, 12, 700
local BLUE, RED = 0x50c8ff, 0xff4040
local CD_X, CD_W, CD_TOP, CD_BOTTOM = 1832, 22, 330, 750
local function get(t, k) if t == nil then return nil end local ok, v = pcall(function() return t[k] end); return ok and v or nil end
local function log(message)
    local dp = nil
    if type(dp) == "function" then pcall(dp, "[WhosWho] " .. message) end
end
local function readTrail()
    local f = get(rawget(_G, "Dvar"), "GetDvarString")
    local h = rawget(_G, "xhashdvar") or get(rawget(_G, "CLUA"), "PushXHashDvar")
    if type(f) ~= "function" or type(h) ~= "function" then return nil end
    local okH, name = pcall(h, "bo7_cp_whos_who_runtime")
    if not okH then return nil end
    local ok, v = pcall(f, name)
    return ok and v or nil
end
local function inFrontend()
    local f = get(rawget(_G, "Engine"), "InFrontend")
    local ok, v = false, nil
    if type(f) == "function" then ok, v = pcall(f) end
    return not ok or v ~= false
end
local function decode(page)
    page = tonumber(page) or 0
    return math.floor(page / 24) * 2, math.floor(page / 12) % 2 == 1, page % 12
end
local function page24()
    local pages = get(rawget(_G, "BO7CustomPerks"), "hudPages")
    return pages and pages[24] or 0
end
local function progressOf(v)
    if v < 2 then return nil end
    return math.min(9, v - 2) / 9
end
do
    local bar, ghost, rv = decode(37 * 24 + 12 + 11)
    assert(bar == 74 and ghost and rv == 11 and progressOf(rv) == 1, "whos who decode ghost")
    bar, ghost, rv = decode(50 * 24 + 1)
    assert(bar == 100 and not ghost and rv == 1 and progressOf(rv) == nil and progressOf(2) == 0, "whos who decode prompt")
    assert(50 * 24 + 12 + 11 <= 1695, "page 24 fits the omnvar")
end
local function newText(parent, l, r, t, b, size)
    local text = LUI.UIText.new()
    text:SetAnchorsAndPosition(0, 1, 0, 1, l, r, t, b)
    local font = get(rawget(_G, "FONT_HANDLE"), "PrimaryBold")
    if font then pcall(function() text:SetFont(font) end) end
    if size then pcall(function() text:SetFontSize(size * (rawget(_G, "_PT") or 1)) end) end
    pcall(function() text:SetAlignment(LUI.Alignment.Center) end)
    text:SetRGB(0xffffff)
    parent:addElement(text)
    return text
end
local function newGroup(root)
    local group = LUI.UIElement.new()
    group:SetAnchorsAndPosition(0, 1, 0, 1, 0, 1920, 0, 1080)
    pcall(function() group:setHandleMouse(false) end)
    group:SetAlpha(0)
    root:addElement(group)
    return group
end
local function newImage(parent, rgb, alpha)
    local image = LUI.UIImage.new()
    image:SetRGB(rgb)
    if alpha then image:SetAlpha(alpha) end
    parent:addElement(image)
    return image
end
local function build(root)
    local group = newGroup(root)
    local text = newText(group, 460, 1460, BAR_Y - 46, BAR_Y - 12)
    text:setText("HOLD USE TO REVIVE CLONE")
    local left = 960 - BAR_W / 2
    local track = newImage(group, 0x101018, 0.85)
    track:SetAnchorsAndPosition(0, 1, 0, 1, left - 2, left + BAR_W + 2, BAR_Y - 2, BAR_Y + BAR_H + 2)
    S.group, S.text, S.track, S.fill, S.left = group, text, track, newImage(group, BLUE), left
end
local function buildCountdown(root)
    local group = newGroup(root)
    local title = newText(group, CD_X - 90, CD_X + CD_W + 90, CD_TOP - 40, CD_TOP - 12, 22)
    title:setText("WHO'S WHO")
    local track = newImage(group, 0x101018, 0.85)
    track:SetAnchorsAndPosition(0, 1, 0, 1, CD_X - 3, CD_X + CD_W + 3, CD_TOP - 3, CD_BOTTOM + 3)
    S.cd, S.cdFill, S.cdPct = group, newImage(group, BLUE), nil
end
local function setFill(p, ms)
    S.fill:SetAnchorsAndPosition(0, 1, 0, 1, S.left, S.left + math.max(1, BAR_W * p), BAR_Y, BAR_Y + BAR_H, ms or 0)
end
local function setCountdown(p, ms)
    local top = CD_BOTTOM - math.max(1, (CD_BOTTOM - CD_TOP) * p)
    S.cdFill:SetAnchorsAndPosition(0, 1, 0, 1, CD_X, CD_X + CD_W, top, CD_BOTTOM, ms or 0)
    S.cdFill:SetRGB(p <= 0.25 and RED or BLUE)
end
local function updateCountdown(root, bar, ghost)
    if not ghost then
        if S.cd and S.cdShown then S.cd:SetAlpha(0, 200); S.cdShown = false end
        S.cdPct = nil
        return
    end
    if not S.cd then buildCountdown(root) end
    if not S.cdShown then S.cd:SetAlpha(1, 200); S.cdShown = true end
    if bar == S.cdPct then return end
    setCountdown(bar / 100, S.cdPct and 1000 or 0)
    S.cdPct = bar
end
local function update(root)
    local trail = readTrail()
    if type(trail) == "string" and trail ~= "" and trail ~= S.trail then S.trail = trail; log("server:" .. trail) end
    local bar, ghost, v = 0, false, 0
    if not inFrontend() then bar, ghost, v = decode(page24()) end
    if v ~= S.logged then S.logged = v; log("prompt state " .. v) end
    if ghost ~= S.loggedGhost then S.loggedGhost = ghost; log("ghost " .. tostring(ghost)) end
    updateCountdown(root, bar, ghost)
    if v == 0 then
        if S.group and S.shown then S.group:SetAlpha(0, 150); S.shown = false end
        S.last = 0
        return
    end
    if not S.group then build(root) end
    if not S.shown then S.group:SetAlpha(1, 150); S.shown = true end
    if v == S.last then return end
    S.last = v
    local p = progressOf(v)
    if not p then
        S.text:setText("HOLD USE TO REVIVE CLONE")
        S.fill:SetAlpha(0)
        setFill(0)
        return
    end
    S.text:setText("REVIVING CLONE")
    S.fill:SetAlpha(1)
    setFill(p)
    setFill(1, math.floor((1 - p) * REVIVE_MS))
end
local function hudRoot()
    local lui = rawget(_G, "LUI")
    local f = get(get(lui, "UIRoot"), "GetRootForControllerIndex")
    if type(f) == "function" then local ok, r = pcall(f, 0); if ok and r then return r end end
    f = get(lui, "GetRoot")
    if type(f) == "function" then local ok, r = pcall(f); if ok and r then return r end end
end
local function step()
    if not S.enabled then return false end
    local root = hudRoot()
    if not root then return true end
    if root ~= S.root then
        S.root, S.group, S.shown, S.last, S.cd, S.cdShown, S.cdPct = root, nil, false, nil, nil, false, nil
        log("hud root " .. tostring(root))
    end
    local ok, err = pcall(update, root)
    if not ok and err ~= S.err then S.err = err; log("update error: " .. tostring(err)) end
    return true
end
local function findQueue()
    local frame = rawget(_G, "Frame")
    local dw = get(frame, "DoWork")
    local H = rawget(_G, "xhash")
    for _, key in ipairs({ "Queue", type(H) == "function" and H("Queue") or "Queue", type(H) == "function" and H("queue") or "queue" }) do
        local f = get(dw, key)
        if type(f) == "function" then return dw, f end
    end
end
local dw, queue = findQueue()
if queue then
    queue(dw, step)
    log("prompt loaded (frame queue)")
else
    local function tick()
        if not step() then return end
        local root = S.root
        local okW, timer = pcall(function() return root:Wait(50) end)
        if okW and timer then timer.onComplete = tick end
    end
    log("prompt loaded (wait loop)")
    tick()
end
