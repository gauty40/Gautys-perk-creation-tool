local C=rawget(_G,"CLUA")
local H=rawget(_G,"xhash") or rawget(_G,"PushXHash") or (type(C)=="table" and C.PushXHash)
local HD=rawget(_G,"xhashdvar") or rawget(_G,"PushXHashDvar") or (type(C)=="table" and C.PushXHashDvar)
local function log(...) end
if type(H)~="function" or type(HD)~="function" then do end ;return end
local old=rawget(_G,"BO7VitalityIcon")
if old and old.version==2 then if old.ensureTimer then pcall(old.ensureTimer) end return end
if old then old.enabled=false end
local S={version=2,enabled=true}
rawset(_G,"BO7VitalityIcon",S)
local MATERIAL="ui_icon_perks_zm_custom"
local SIZE=40
local X,Y=24,-230
local function get(o,k)
    if o==nil then return nil end
    local ok,v=pcall(function()return o[k]end)
    if ok and v~=nil then return v end
    local ok2,v2=pcall(function()return o[H(k)]end)
    if ok2 then return v2 end
    return nil
end
local function call(o,k,...)
    local f=get(o,k)
    if type(f)=="function" then return f(o,...) end
    return nil
end
local function readDvar()
    local api=rawget(_G,"Dvar")
    local f=get(api,"GetDvarString")
    if type(f)~="function" then return nil end
    local ok,v=pcall(f,HD("bo7_vitality_icon"))
    if ok and v~=nil then return tostring(v) end
    return nil
end
local function inMatch()
    local e=rawget(_G,"Engine")
    local f=get(e,"InFrontend")
    return type(f)=="function" and f()==false
end
local function rootElement()
    local L=rawget(_G,"LUI")
    local f=get(L,"GetRoot")
    if type(f)=="function" then
        local ok,r=pcall(f)
        if ok and r then return r end
    end
    return get(L,"primaryRoot")
end
local function newElement(kind)
    local f=get(get(rawget(_G,"LUI"),kind),"new")
    if type(f)~="function" then return nil end
    return f()
end
local function material()
    if S.material~=nil then return S.material or nil end
    local register=rawget(_G,"RegisterMaterial")
    local asset=rawget(_G,"xhashasset") or get(C,"PushXHashAsset")
    local ok,m=pcall(function()
        return register(type(asset)=="function" and asset(MATERIAL) or MATERIAL)
    end)
    S.material=(ok and m) or false
    if not S.material then do end  end
    return S.material or nil
end
local function removeIcon()
    if S.icon then pcall(call,S.icon,"closeTree") end
    S.icon=nil
end
local function showIcon(root)
    if S.icon then
        local ok,p=pcall(call,S.icon,"getParent")
        if ok and p==root then return end
        removeIcon()
    end
    local m=material()
    if not m then return end
    local img=newElement("UIImage")
    if not img then do end  return end
    call(img,"SetAnchorsAndPosition",0,1,1,0,X,X+SIZE,Y,Y+SIZE)
    call(img,"setImage",m)
    call(img,"SetRGB",0xffffff)
    call(img,"SetAlpha",1)
    call(img,"SetHandleMouse",false)
    call(img,"setFocusable",false)
    call(root,"addElement",img)
    S.icon=img
end
local function tick()
    local root=rootElement()
    if not root then return end
    if inMatch() and readDvar()=="1" then showIcon(root) else removeIcon() end
end
local function ensureTimer()
    if not S.enabled then return end
    local root=rootElement()
    if not root then return end
    local ok,parent=pcall(call,S.timer,"getParent")
    if ok and parent==root then return end
    if S.timer then pcall(call,S.timer,"closeTree") end
    S.timer=nil
    local host=newElement("UIElement")
    if not host then return end
    call(host,"SetHandleMouse",false)
    call(host,"setFocusable",false)
    call(root,"addElement",host)
    S.timer=host
    local function schedule()
        if not S.enabled or S.timer~=host then return end
        if call(host,"getParent")~=rootElement() then
            S.timer=nil
            call(host,"closeTree")
            ensureTimer()
            return
        end
        local anim=call(host,"Wait",100)
        if not anim then return end
        anim.onComplete=function()
            if not S.enabled or S.timer~=host then return end
            local okTick,err=pcall(tick)
            if not okTick and not S.err then S.err=true;do end  end
            pcall(schedule)
        end
    end
    schedule()
end
S.ensureTimer=ensureTimer
pcall(ensureTimer)
do end
