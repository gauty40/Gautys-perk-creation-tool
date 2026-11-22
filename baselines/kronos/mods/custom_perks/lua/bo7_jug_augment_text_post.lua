local CHANGES = {
 {
  ids = { "juggernog_turtle_shell", "juggernog_shielded" },
  match = "Turtle Shell",
  name = "Golden Armor",
  desc = "Armor regenerates over time.",
 },
 {
  ids = { "juggernog_well_constructed" },
  match = "Hardened Plates",
  name = "Hardened Plates",
  desc = "Increase your armor's durability.",
 },
 {
  ids = {},
  match = "Armormatic",
  name = "Armormatic",
  desc = "Increase how much an armor plate repairs your armor.",
 },
}
local EXTRA_ORIGINAL_DESCS = {
}
local TAG = "[JugAugText] "
local function log(...) end
local C = rawget(_G, "CLUA")
local H = rawget(_G, "xhash") or rawget(_G, "PushXHash") or (type(C) == "table" and C.PushXHash)
if type(H) ~= "function" then H = function(s) return s end end
local hcache = {}
local function hx(name)
 local v = hcache[name]
 if v == nil then
  local ok, r = pcall(H, name)
  v = (ok and r ~= nil) and r or false
  hcache[name] = v
 end
 return v or nil
end
local function get(tbl, name)
 if type(tbl) ~= "table" then return nil end
 local ok, v = pcall(function() return tbl[name] end)
 if ok and v ~= nil then return v end
 local h = hx(name)
 if h ~= nil then
  ok, v = pcall(function() return tbl[h] end)
  if ok then return v end
 end
end
local function put(tbl, name, value)
 if type(tbl) ~= "table" then return end
 local h = hx(name)
 if h ~= nil then pcall(function() tbl[h] = value end) end
 pcall(function() tbl[name] = value end)
end
local old = rawget(_G, "BO7JugAugmentText")
if old then old.enabled = false end
local S = { enabled = true, learned = {}, patched = {} }
rawset(_G, "BO7JugAugmentText", S)
local function live() local Z = rawget(_G, "BO7JugAugmentText"); return Z and Z.enabled end
local textName, textDesc = {}, {}
local function lower(s) return type(s) == "string" and s:lower() or nil end
for i, c in ipairs(CHANGES) do
 textName[lower(c.match)] = i
 textName[lower(c.name)] = i
end
for text, i in pairs(EXTRA_ORIGINAL_DESCS) do
 if CHANGES[i] then textDesc[lower(text)] = i end
end
local function localize(s)
 local E = rawget(_G, "Engine")
 local f = get(E, "Localize")
 if type(f) ~= "function" then return nil end
 local ok, r = pcall(f, s)
 if ok and type(r) == "string" then return r end
end
local idIndex
local function changeForId(v)
 if v == nil then return nil end
 if not idIndex then
  idIndex = {}
  for i, c in ipairs(CHANGES) do
   for _, id in ipairs(c.ids) do
    idIndex[id] = i
    local h = hx(id)
    if h ~= nil then idIndex[h] = i end
   end
  end
 end
 return idIndex[v] or (type(v) == "string" and idIndex[v:lower()]) or nil
end
local function changeForRow(row)
 for _, field in ipairs({ "ref", "id", "augment", "augmentref", "name" }) do
  local i = changeForId(get(row, field))
  if i then return i end
 end
 local raw = get(row, "displayname")
 for _, v in ipairs({ raw, type(raw) == "string" and localize(raw) or nil }) do
  local i = textName[lower(v)]
  if i then return i end
 end
end
local function learn(kind, text, i)
 if type(text) ~= "string" or text == "" then return end
 if text == CHANGES[i].name or text == CHANGES[i].desc then return end
 local l = lower(text)
 local map = kind == "name" and textName or textDesc
 if map[l] == nil then
  map[l] = i
  S.learned[#S.learned + 1] = kind .. ":" .. text
  do end
 end
end
local function patchRow(row)
 if type(row) ~= "table" then return end
 local i = changeForRow(row)
 if not i then return end
 local c = CHANGES[i]
 local rawName, rawDesc = get(row, "displayname"), get(row, "description")
 learn("name", rawName, i)
 learn("name", type(rawName) == "string" and localize(rawName) or nil, i)
 learn("desc", rawDesc, i)
 learn("desc", type(rawDesc) == "string" and localize(rawDesc) or nil, i)
 put(row, "displayname", c.name)
 put(row, "description", c.desc)
 if not S.patched[i] then
  S.patched[i] = true
  do end
 end
end
local function patchCaches()
 local Z = rawget(_G, "ZMAUGMENT")
 if type(Z) ~= "table" then return end
 for _, listName in ipairs({ "augmentlist_full", "augmentlist_major", "augmentlist_minor" }) do
  local lists = get(Z, listName)
  if type(lists) == "table" then
   local ok = pcall(function()
    for _, rows in pairs(lists) do
     if type(rows) == "table" then
      for _, row in pairs(rows) do patchRow(row) end
     end
    end
   end)
   if not ok and not S.warned then S.warned = true; do end  end
  end
 end
end
local function replacement(text)
 local l = lower(text)
 if not l then return nil end
 local i = textName[l]
 if i then return CHANGES[i].name end
 i = textDesc[l]
 if i then return CHANGES[i].desc end
end
local function localizeWrap(upper)
 return function(orig)
  return function(s, ...)
   local r = orig(s, ...)
   if live() then
    local n = replacement(s) or replacement(r)
    if n then return upper and n:upper() or n end
   end
   return r
  end
 end
end
local function setTextWrap(orig)
 return function(self, text, ...)
  if live() then
   local n = replacement(text)
   if n then text = n end
  end
  return orig(self, text, ...)
 end
end
local wrapped = rawget(_G, "BO7JugAugmentTextWrapped") or setmetatable({}, { __mode = "k" })
rawset(_G, "BO7JugAugmentTextWrapped", wrapped)
local function hook(tbl, name, make)
 if type(tbl) ~= "table" then return end
 for _, key in ipairs({ name, hx(name) }) do
  if key ~= nil then
   local ok, f = pcall(function() return tbl[key] end)
   if ok and type(f) == "function" then
    local d = wrapped[tbl]
    if not d then d = {}; wrapped[tbl] = d end
    if not d[key] then
     d[key] = true
     pcall(function() tbl[key] = make(f) end)
    end
   end
  end
 end
end
local function install()
 local E = rawget(_G, "Engine")
 if type(E) == "table" then
  hook(E, "Localize", localizeWrap(false))
  hook(E, "LocalizeString", localizeWrap(false))
  hook(E, "LocalizeToUpperString", localizeWrap(true))
  hook(E, "LocalizeToUpper", localizeWrap(true))
 end
 local L = rawget(_G, "LUI")
 if type(L) == "table" then
  for _, c in ipairs({ "UIText", "UIElement", "UIStyledText" }) do
   local cls = get(L, c)
   if type(cls) == "table" then
    hook(cls, "setText", setTextWrap)
    hook(cls, "SetText", setTextWrap)
   end
  end
 end
 local Z = rawget(_G, "ZMAUGMENT")
 if type(Z) == "table" then
  for _, fname in ipairs({ "initfullaugmentlist", "inittypeaugmentlist", "createfullaugmentcache", "refreshaugmentlistdata" }) do
   hook(Z, fname, function(orig)
    return function(...)
     local a, b, c, d = orig(...)
     if live() then pcall(patchCaches) end
     return a, b, c, d
    end
   end)
  end
 end
end
local function pass()
 pcall(install)
 pcall(patchCaches)
end
local function root()
 local L = rawget(_G, "LUI")
 local ok, r = pcall(function() return L.GetRoot() end)
 if ok and r then return r end
 return get(L, "primaryRoot")
end
local function tick()
 if not live() then return end
 pass()
 local r = root()
 if r then pcall(function() r:Wait(1000).onComplete = tick end) end
end
tick()
local MB = rawget(_G, "MenuBuilder")
if type(MB) == "table" and not rawget(_G, "BO7JugAugmentTextMB") then
 local orig = MB.BuildRegisteredType
 if type(orig) == "function" then
  rawset(_G, "BO7JugAugmentTextMB", true)
  MB.BuildRegisteredType = function(name, opts)
   if live() then pcall(pass) end
   return orig(name, opts)
  end
 end
end
local work = get(rawget(_G, "Frame"), "DoWork")
local queue = get(work, "Queue")
if type(queue) == "function" then
 local ticks = 0
 pcall(queue, work, function()
  if not live() then return false end
  ticks = ticks + 1
  if ticks >= 60 then ticks = 0; pcall(pass) end
  return true
 end)
end
do end
