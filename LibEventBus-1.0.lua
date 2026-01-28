local MAJOR, MINOR = "LibEventBus-1.0", 1
if not LibStub then error(MAJOR .. " requires LibStub") end

local LibEvent = LibStub:NewLibrary(MAJOR, MINOR)
if not LibEvent then return end

-------------------------------------------------
-- Utilities
-------------------------------------------------

local pcall = pcall
local geterrorhandler = geterrorhandler
local type = type
local tostring = tostring
local setmetatable = setmetatable

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        geterrorhandler()(err)
        return false, err
    end
    return true
end

local function fastCall(fn, ...)
    return fn(...)
end

-------------------------------------------------
-- Bus Prototype
-------------------------------------------------

local BusProto = {}
BusProto.__index = BusProto

-------------------------------------------------
-- Bus Creation
-------------------------------------------------

local function NewBus(name, safe)
    local frame = CreateFrame("Frame")

    local bus = setmetatable({
        name         = name or "Bus",
        frame        = frame,
        handlers     = {},
        onceHandlers = {},
        nativeEvents = {},
        safe         = safe or true,
    }, BusProto)

    frame:SetScript("OnEvent", function(_, event, ...)
        bus:dispatch(event, ...)
    end)

    return bus
end

-------------------------------------------------
-- Internal helpers (instance methods)
-------------------------------------------------

function BusProto:registerEvent(event)
    local list = self.handlers[event]
    if list then return list end

    list = {}
    self.handlers[event] = list

    local ok = pcall(self.frame.RegisterEvent, self.frame, event)
    if ok then
        self.nativeEvents[event] = true
    end

    return list
end

function BusProto:unregisterEvents(event, list)
    if #list > 0 then return end

    self.handlers[event] = nil

    if self.nativeEvents[event] then
        pcall(self.frame.UnregisterEvent, self.frame, event)
        self.nativeEvents[event] = nil
    end

    self.onceHandlers[event] = nil
end

function BusProto:dispatch(event, ...)
    local list = self.handlers[event]
    if not list then return end

    local call = self.safe and safeCall or fastCall

    for i = 1, #list do
        local entry = list[i]
        if entry and entry.active then
            call(entry.fn, event, ...)
        end
    end

    if list.dirty then
        local write = 1
        for read = 1, #list do
            local entry = list[read]
            if entry and entry.active then
                list[write] = entry
                write = write + 1
            end
        end
        for i = write, #list do
            list[i] = nil
        end
        list.dirty = false
    end

    self:unregisterEvents(event, list)
end

function BusProto:clearHandler(event, fn)
    local list = self.handlers[event]
    if not list then return end

    for i = 1, #list do
        local entry = list[i]
        if entry.fn == fn then
            entry.active = false
            list.dirty = true
        end
    end
end

-------------------------------------------------
-- Public Bus API
-------------------------------------------------

function BusProto:RegisterEvent(event, fn)
    if type(event) ~= "string" or type(fn) ~= "function" then return end

    local list = self:registerEvent(event)

    for i = 1, #list do
        if list[i].fn == fn then
            return
        end
    end

    local entry = { fn = fn, active = true }
    list[#list + 1] = entry

    local bus = self
    return function()
        bus:UnregisterEvent(event, fn)
    end
end

function BusProto:RegisterEventOnce(event, fn)
    if type(event) ~= "string" or type(fn) ~= "function" then return end

    local map = self.onceHandlers[event]
    if not map then
        map = {}
        self.onceHandlers[event] = map
    end

    if map[fn] then return end

    local bus = self
    local function wrapper(evt, ...)
        bus:UnregisterEvent(event, wrapper)
        map[fn] = nil
        safeCall(fn, evt, ...)
    end

    map[fn] = wrapper
    self:RegisterEvent(event, wrapper)

    return function()
        bus:UnregisterEvent(event, wrapper)
    end
end

function BusProto:UnregisterEvent(event, fn)
    local list = self.handlers[event]
    if not list or type(fn) ~= "function" then return end

    local proxy = fn
    local map = self.onceHandlers[event]
    if map and map[fn] then
        proxy = map[fn]
        map[fn] = nil
    end

    self:clearHandler(event, proxy)
    self:unregisterEvents(event, list)
end

function BusProto:UnregisterAll(event)
    local list = self.handlers[event]
    if not list then return end

    for i = 1, #list do
        list[i] = nil
    end

    self.onceHandlers[event] = nil
    self:unregisterEvents(event, list)
end

function BusProto:TriggerEvent(event, ...)
    self:dispatch(event, ...)
end

function BusProto:IsRegistered(event)
    local list = self.handlers[event]
    return list and #list > 0 or false
end

-------------------------------------------------
-- Hooks (shared, not per-bus)
-------------------------------------------------

local hookedFuncs = {}
local hookedScripts = setmetatable({}, { __mode = "k" })

function BusProto:HookSecureFunc(frame, funcName, handler)
    if type(frame) == "string" then
        frame, funcName, handler = _G, frame, funcName
    end
    if type(handler) ~= "function" then return end

    local key = tostring(frame) .. ":" .. tostring(funcName)
    if hookedFuncs[key] then return end
    hookedFuncs[key] = true

    hooksecurefunc(frame, funcName, function(...)
        safeCall(handler, ...)
    end)
end

function BusProto:HookScript(frame, script, handler)
    if type(frame) ~= "table" or type(handler) ~= "function" then return end

    local set = hookedScripts[frame]
    if not set then
        set = {}
        hookedScripts[frame] = set
    end
    if set[script] then return end
    set[script] = true

    frame:HookScript(script, function(...)
        safeCall(handler, ...)
    end)
end

-------------------------------------------------
-- Global Bus Singleton
-------------------------------------------------

local GlobalBus

local function GetGlobalBus()
    if not GlobalBus then
        GlobalBus = NewBus("Global", true)
    end
    return GlobalBus
end

-------------------------------------------------
-- LibEvent API proxies
-------------------------------------------------

function LibEvent:NewBus(...)
    return NewBus(...)
end

function LibEvent:GetGlobalBus()
    return GetGlobalBus()
end

function LibEvent:RegisterEvent(...)
    return GetGlobalBus():RegisterEvent(...)
end

function LibEvent:RegisterEventOnce(...)
    return GetGlobalBus():RegisterEventOnce(...)
end

function LibEvent:UnregisterEvent(...)
    return GetGlobalBus():UnregisterEvent(...)
end

function LibEvent:UnregisterAll(...)
    return GetGlobalBus():UnregisterAll(...)
end

function LibEvent:TriggerEvent(...)
    return GetGlobalBus():TriggerEvent(...)
end

function LibEvent:IsRegistered(...)
    return GetGlobalBus():IsRegistered(...)
end

function LibEvent:HookSecureFunc(...)
    return GetGlobalBus():HookSecureFunc(...)
end

function LibEvent:HookScript(...)
    return GetGlobalBus():HookScript(...)
end
