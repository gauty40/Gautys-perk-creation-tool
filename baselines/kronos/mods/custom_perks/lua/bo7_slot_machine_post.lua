-- Slot machine interface. The machine and all rules live on the server (zm_cp_slot_machine.gsc); this only draws.
-- HUD channel page 21 = near + open*2 + spinning*4 + poor*8 + no_target_cooling*16 + spins_this_round*32
-- HUD channel page 22 = spin_id*512 + reel1*64 + reel2*8 + reel3 (spin_id 1..7, 0 = never spun)
local previous = rawget(_G, "BO7SlotMachine")
if previous then
    previous.enabled = false
    for _, k in ipairs({ "group", "prompt" }) do
        if previous[k] then pcall(function() previous[k]:close() end) end
    end
end
local S = { enabled = true }
rawset(_G, "BO7SlotMachine", S)
local SYMBOLS = { [0] = "gcp_slot_cherry", "gcp_slot_bell", "gcp_slot_bar", "gcp_slot_seven", "gcp_slot_skull", "gcp_slot_clover", "gcp_slot_mega", "gcp_slot_nega" }
local CLOVER, MEGA, NEGA = 5, 6, 7
local GOLD, GREY, RED, WHITE, GREEN = 0xf5c328, 0x9a9aa6, 0xff4a4a, 0xffffff, 0x5ee07a
local PANEL_L, PANEL_R, PANEL_T, PANEL_B = 600, 1320, 160, 950
local REEL, GAP, REEL_T = 150, 20, 290
local TICK_MS = 70
-- Reel i stops after this many ticks (the last stops at about 2.6 s, when the server pays out).
local STOP_TICKS = { 20, 28, 37 }
-- Payout table shown in the interface (mirrors slot_machine_pay in zm_cp_slot_machine.gsc).
local PAYOUTS = {
    { { 6, 6, 6 }, "MEGA JACKPOT  DOUBLES YOUR ESSENCE", GOLD },
    { { 3, 3, 3 }, "JACKPOT  77,777", GOLD },
    { { 5, 5, 5 }, "9 MYSTERY PERK CANS", GREEN },
    { { 0, 0, 0 }, "40,000", WHITE },
    { { 2, 2, 2 }, "20,000 + KILLSTREAK", WHITE },
    { { 1, 1, 1 }, "15,000 + MAX AMMO", WHITE },
    { { 5, 5 }, "3 MYSTERY PERK CANS", GREEN },
    { { 5 }, "MYSTERY PERK CAN", GREEN },
    { {}, "ANY PAIR  10,000", WHITE },
    { { 0 }, "ANY CHERRY  5,000", WHITE },
    { { 4, 4, 4 }, "YOU GO DOWN", RED },
    { { 7, 7, 7 }, "NEGA JACKPOT  4 ELITES SPAWN", RED },
}
-- 12 rows from ROW_T, ROW_STEP apart, must end above PANEL_B.
local ROW_T, ROW_STEP, ROW_ICON = 606, 27, 24
local function get(t, k) if t == nil then return nil end local ok, v = pcall(function() return t[k] end); return ok and v or nil end
local function decodeSpin(v)
    v = tonumber(v) or 0
    local code = v % 512
    return math.floor(v / 512), math.floor(code / 64), math.floor(code / 8) % 8, code % 8
end
local function decodeState(v)
    v = tonumber(v) or 0
    return v % 2 == 1, math.floor(v / 2) % 2 == 1, math.floor(v / 4) % 2 == 1, math.floor(v / 8) % 2 == 1, math.floor(v / 32), math.floor(v / 16) % 2 == 1
end
local function priceText(spins)
    if spins == 0 then return "NEXT SPIN: FREE" end
    local n = tostring(spins * 5000):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return "NEXT SPIN: " .. n .. " ESSENCE"
end
-- Mirrors slot_machine_pay in zm_cp_slot_machine.gsc: the normal result, plus clover perk cans on top.
local function isPair(x, y) return x == y and x ~= 4 and x ~= CLOVER and x ~= NEGA end
local function resultText(a, b, c)
    local clovers = (a == CLOVER and 1 or 0) + (b == CLOVER and 1 or 0) + (c == CLOVER and 1 or 0)
    if clovers == 3 then return "9 MYSTERY PERKS!", true end
    local normal
    if a == b and b == c then
        normal = ({ [0] = "+40,000 ESSENCE", "+15,000 AND MAX AMMO!", "+20,000 AND A KILLSTREAK!", "JACKPOT! +77,777", "THREE SKULLS...",
            [MEGA] = "MEGA JACKPOT! ESSENCE DOUBLED!", [NEGA] = "NEGA JACKPOT... ELITES INCOMING" })[a]
        if a == 4 or a == NEGA then return normal, false end
    elseif isPair(a, b) or isPair(b, c) or isPair(a, c) then normal = "+10,000 ESSENCE"
    elseif a == 0 or b == 0 or c == 0 then normal = "+5,000 ESSENCE" end
    local clover = clovers == 2 and "3 MYSTERY PERKS" or clovers == 1 and "MYSTERY PERK" or nil
    if normal and clover then return normal .. " + " .. clover, true end
    if normal or clover then return normal or clover, true end
    return "NO WIN", false
end
do
    local spin, a, b, c = decodeSpin(7 * 512 + 7 * 64 + 6 * 8 + 4)
    assert(spin == 7 and a == 7 and b == 6 and c == 4 and 7 * 512 + 511 < 4096, "slot spin decode")
    assert(resultText(6, 6, 6) == "MEGA JACKPOT! ESSENCE DOUBLED!" and select(2, resultText(6, 6, 6)) == true, "mega result")
    assert(resultText(7, 7, 7) == "NEGA JACKPOT... ELITES INCOMING" and select(2, resultText(7, 7, 7)) == false, "nega result")
    assert(resultText(6, 6, 1) == "+10,000 ESSENCE" and resultText(7, 7, 1) == "NO WIN", "mega pair pays, nega pair doesn't")
    assert(ROW_T + (#PAYOUTS - 1) * ROW_STEP + ROW_ICON < PANEL_B, "payout rows fit the panel")
    local near, open, busy, poor, spins, cooling = decodeState(1 + 2 + 8 + 16 + 3 * 32)
    assert(near and open and not busy and poor and cooling and spins == 3 and 1 + 2 + 4 + 8 + 16 + 100 * 32 < 4096, "slot state decode")
    assert(priceText(0) == "NEXT SPIN: FREE" and priceText(1) == "NEXT SPIN: 5,000 ESSENCE" and priceText(3) == "NEXT SPIN: 15,000 ESSENCE", "slot price")
    assert(resultText(3, 3, 3) == "JACKPOT! +77,777" and resultText(0, 0, 0) == "+40,000 ESSENCE" and resultText(4, 4, 0) == "+5,000 ESSENCE"
        and resultText(1, 2, 1) == "+10,000 ESSENCE" and resultText(1, 2, 4) == "NO WIN", "slot results")
    assert(resultText(5, 5, 5) == "9 MYSTERY PERKS!" and resultText(5, 2, 4) == "MYSTERY PERK" and resultText(5, 5, 1) == "3 MYSTERY PERKS"
        and resultText(5, 0, 0) == "+10,000 ESSENCE + MYSTERY PERK" and resultText(5, 1, 0) == "+5,000 ESSENCE + MYSTERY PERK", "clover results")
end
-- UI sounds (stock aliases from the ZM safe dial and powerup splash). A missing alias just plays nothing.
local SPIN_TICK, REEL_STOP, WIN_SOUND = "evt_zm_safe_dial_turn", "evt_zm_safe_dial_switch", "uin_zm_sat_powerup_splash"
local function sound(alias)
    local f = get(rawget(_G, "Engine"), "PlaySound")
    if type(f) == "function" then pcall(f, alias) end
end
-- Esc: is the pause menu open? (same check the stock UI uses)
local function pauseOpen()
    local flow, cod = get(rawget(_G, "LUI"), "FlowManager"), rawget(_G, "CoD")
    local inStack, pauseName = get(flow, "IsInStack"), get(cod, "GetPauseMenuFromCurrentContext")
    if type(inStack) ~= "function" or type(pauseName) ~= "function" then return false end
    local ok, open = pcall(function() return inStack(pauseName()) end)
    return ok and open == true
end
-- Tells the server to close the interface (zm_cp_slot_machine.gsc slot_machine_listen).
local CLOSE_VALUE = 23000
local function sendClose()
    local f = get(rawget(_G, "Engine"), "NotifyServer")
    if type(f) == "function" then pcall(f, "perk_choice_purchase", CLOSE_VALUE) end
end
local materials = {}
local function material(name)
    if materials[name] then return materials[name] end
    local hash = rawget(_G, "xhashasset") or get(rawget(_G, "CLUA"), "PushXHashAsset")
    local register = rawget(_G, "RegisterMaterial")
    if type(hash) ~= "function" or type(register) ~= "function" then return nil end
    local ok, m = pcall(function() return register(hash(name)) end)
    if ok and m then materials[name] = m end
    return materials[name]
end
local function inFrontend()
    local f = get(rawget(_G, "Engine"), "InFrontend")
    local ok, v = false, nil
    if type(f) == "function" then ok, v = pcall(f) end
    return not ok or v ~= false
end
local function box(parent, rgb, alpha, l, t, r, b)
    local image = LUI.UIImage.new()
    image:SetRGB(rgb)
    image:SetAlpha(alpha)
    image:SetAnchorsAndPosition(0, 1, 0, 1, l, r, t, b)
    parent:addElement(image)
    return image
end
local function icon(parent, symbol, l, t, size)
    local image = box(parent, 0xffffff, 1, l, t, l + size, t + size)
    local m = material(SYMBOLS[symbol])
    if m then image:setImage(m, 0) end
    return image
end
local function label(parent, l, t, r, b, size, align, text, rgb)
    local el = LUI.UIText.new()
    el:SetAnchorsAndPosition(0, 1, 0, 1, l, r, t, b)
    local font = get(rawget(_G, "FONT_HANDLE"), "PrimaryBold")
    if font then pcall(function() el:SetFont(font) end) end
    pcall(function() el:SetFontSize(size * (rawget(_G, "_PT") or 1)) end)
    pcall(function() el:SetAlignment(align == "left" and LUI.Alignment.Left or LUI.Alignment.Center) end)
    el:SetRGB(rgb or WHITE)
    el:setText(text or "")
    parent:addElement(el)
    return el
end
local function layer(root)
    local group = LUI.UIElement.new()
    group:SetAnchorsAndPosition(0, 1, 0, 1, 0, 1920, 0, 1080)
    pcall(function() group:setHandleMouse(false) end)
    group:SetAlpha(0)
    root:addElement(group)
    return group
end
local function build(root)
    S.prompt = layer(root)
    label(S.prompt, 460, 690, 1460, 724, 26, nil, "PRESS USE TO PLAY THE SLOT MACHINE", GOLD)
    local group = layer(root)
    box(group, GOLD, 1, PANEL_L - 4, PANEL_T - 4, PANEL_R + 4, PANEL_B + 4)
    box(group, 0x101018, 0.95, PANEL_L, PANEL_T, PANEL_R, PANEL_B)
    label(group, PANEL_L, PANEL_T + 18, PANEL_R, PANEL_T + 66, 44, nil, "SLOTS", GOLD)
    S.coolText = label(group, PANEL_L, PANEL_T + 64, PANEL_R, PANEL_T + 84, 18, nil, "", RED)
    local reelsL = 960 - (3 * REEL + 2 * GAP) / 2
    S.reels = {}
    for i = 1, 3 do
        local l = reelsL + (i - 1) * (REEL + GAP)
        box(group, GOLD, 1, l - 3, REEL_T - 3, l + REEL + 3, REEL_T + REEL + 3)
        box(group, 0xf2ecdc, 1, l, REEL_T, l + REEL, REEL_T + REEL)
        S.reels[i] = icon(group, 3, l + 8, REEL_T + 8, REEL - 16)
    end
    S.result = label(group, PANEL_L, REEL_T + REEL + 14, PANEL_R, REEL_T + REEL + 50, 30, nil, "", GOLD)
    S.price = label(group, PANEL_L, REEL_T + REEL + 58, PANEL_R, REEL_T + REEL + 86, 24, nil, "", WHITE)
    S.help = label(group, PANEL_L, REEL_T + REEL + 90, PANEL_R, REEL_T + REEL + 114, 20, nil, "", GREY)
    box(group, GOLD, 0.6, PANEL_L + 60, ROW_T - 10, PANEL_R - 60, ROW_T - 8)
    for row, p in ipairs(PAYOUTS) do
        local t = ROW_T + (row - 1) * ROW_STEP
        for i, symbol in ipairs(p[1]) do icon(group, symbol, 720 + (i - 1) * (ROW_ICON + 4), t, ROW_ICON) end
        label(group, 850, t + 2, PANEL_R - 40, t + ROW_ICON, 20, "left", p[2], p[3])
    end
    S.group = group
end
local function setReel(i, symbol)
    local m = material(SYMBOLS[symbol])
    if m then S.reels[i]:setImage(m, 0) end
end
local function showResult(a, b, c)
    local text, win = resultText(a, b, c)
    S.result:setText(text)
    local bad = a == b and b == c and (a == 4 or a == NEGA)
    S.result:SetRGB(win and GOLD or bad and RED or GREY)
end
local function spin(a, b, c)
    S.token = (S.token or 0) + 1
    local token, ticks, final = S.token, 0, { a, b, c }
    S.result:setText("")
    local function tick()
        if not S.enabled or S.token ~= token or not S.group then return end
        ticks = ticks + 1
        if ticks < STOP_TICKS[3] and ticks % 2 == 0 then sound(SPIN_TICK) end
        for i = 1, 3 do
            if ticks < STOP_TICKS[i] then setReel(i, math.random(0, #SYMBOLS))
            elseif ticks == STOP_TICKS[i] then setReel(i, final[i]); sound(REEL_STOP) end
        end
        if ticks >= STOP_TICKS[3] then
            showResult(a, b, c)
            if select(2, resultText(a, b, c)) then sound(WIN_SOUND) end
            return
        end
        local ok, timer = pcall(function() return S.group:Wait(TICK_MS) end)
        if ok and timer then timer.onComplete = tick end
    end
    tick()
end
local function show(el, on, flag)
    if S[flag] ~= on then S[flag] = on; el:SetAlpha(on and 1 or 0, 150) end
end
local function update(root)
    local pages = get(rawget(_G, "BO7CustomPerks"), "hudPages")
    local state = pages and pages[21]
    if inFrontend() or state == nil then
        if S.group then show(S.group, false, "groupShown"); show(S.prompt, false, "promptShown") end
        return
    end
    local near, open, busy, poor, spins, cooling = decodeState(state)
    -- Build (and touch the custom images) only when the player first walks up to the machine.
    if not S.group then
        if not near then return end
        build(root)
    end
    -- Esc: hide straight away and keep asking the server to close until it reports closed.
    if open and pauseOpen() then
        S.closeWait = (S.closeWait or 0) - 1
        if S.closeWait <= 0 then S.closeWait = 30; sendClose() end
        open = false
    else
        S.closeWait = 0
    end
    -- No-target cooldown: the machine still works, zombies just keep chasing you.
    if cooling ~= S.shownCooling then
        S.shownCooling = cooling
        S.coolText:setText(cooling and "NO TARGET COOLING DOWN: ZOMBIES CAN STILL SEE YOU" or "")
    end
    show(S.prompt, near and not open, "promptShown")
    show(S.group, open, "groupShown")
    S.price:setText(poor and "NOT ENOUGH ESSENCE" or priceText(spins))
    S.price:SetRGB(poor and RED or WHITE)
    S.help:setText(busy and "SPINNING..." or "USE: SPIN     CROUCH / ESC / WALK AWAY: CLOSE AND COLLECT")
    local spinId, a, b, c = decodeSpin(pages[22])
    if S.lastSpin == nil then
        -- First reading: show the last result without replaying it.
        S.lastSpin = spinId
        if spinId > 0 then setReel(1, a); setReel(2, b); setReel(3, c); showResult(a, b, c) end
    elseif spinId ~= S.lastSpin then
        S.lastSpin = spinId
        spin(a, b, c)
    end
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
        S.root, S.group, S.prompt, S.groupShown, S.promptShown, S.lastSpin = root, nil, nil, nil, nil, nil
        S.token = (S.token or 0) + 1
    end
    pcall(update, root)
    return true
end
local function findQueue()
    local dw = get(rawget(_G, "Frame"), "DoWork")
    local H = rawget(_G, "xhash")
    for _, key in ipairs({ "Queue", type(H) == "function" and H("Queue") or "Queue", type(H) == "function" and H("queue") or "queue" }) do
        local f = get(dw, key)
        if type(f) == "function" then return dw, f end
    end
end
local dw, queue = findQueue()
if queue then
    queue(dw, step)
else
    local function tick()
        if not step() then return end
        local okW, timer = pcall(function() return S.root:Wait(50) end)
        if okW and timer then timer.onComplete = tick end
    end
    tick()
end
