local LibStub = LibStub
local error = error

local major, minor = "LibEventBus-1.0", 1
if not LibStub then error(major .. " requires LibStub") end

local lib = LibStub:NewLibrary(major, minor)
if not lib then return end

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

-- Prototype
local proto = {}
proto.__index = proto

-- Bus Creation
local function NewBus(name, safe)
    local frame = CreateFrame("Frame")

    local bus = setmetatable({
        name         = name or "Bus",
        frame        = frame,
        handlers     = {},
        onceHandlers = {},
        nativeEvents = {},
        safe         = safe or true,
    }, proto)

    frame:SetScript("OnEvent", function(_, event, ...)
        bus:dispatch(event, ...)
    end)

    return bus
end

-- Internal helpers (instance methods)
function proto:registerEvent(event)
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

function proto:unregisterEvents(event, list)
    if #list > 0 then return end

    self.handlers[event] = nil

    if self.nativeEvents[event] then
        pcall(self.frame.UnregisterEvent, self.frame, event)
        self.nativeEvents[event] = nil
    end

    self.onceHandlers[event] = nil
end

function proto:dispatch(event, ...)
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

function proto:clearHandler(event, fn)
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

-- Public Bus API
function proto:RegisterEvent(event, fn)
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

function proto:RegisterEventOnce(event, fn)
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

function proto:UnregisterEvent(event, fn)
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

function proto:UnregisterAll(event)
    local list = self.handlers[event]
    if not list then return end

    for i = 1, #list do
        list[i] = nil
    end

    self.onceHandlers[event] = nil
    self:unregisterEvents(event, list)
end

function proto:TriggerEvent(event, ...)
    self:dispatch(event, ...)
end

function proto:IsRegistered(event)
    local list = self.handlers[event]
    return list and #list > 0 or false
end

-- Hooks (shared, not per-bus)
local hookedFuncs = {}
local hookedScripts = setmetatable({}, { __mode = "k" })

function proto:HookSecureFunc(frame, funcName, handler)
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

function proto:HookScript(frame, script, handler)
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

-- Global Bus Singleton
local globalBus

local function GetGlobalBus()
    if not globalBus then
        globalBus = NewBus("Global", true)
    end
    return globalBus
end

-- LibEvent API proxies
function lib:NewBus(...)
    return NewBus(...)
end

function lib:GetGlobalBus()
    return GetGlobalBus()
end

function lib:RegisterEvent(...)
    return GetGlobalBus():RegisterEvent(...)
end

function lib:RegisterEventOnce(...)
    return GetGlobalBus():RegisterEventOnce(...)
end

function lib:UnregisterEvent(...)
    return GetGlobalBus():UnregisterEvent(...)
end

function lib:UnregisterAll(...)
    return GetGlobalBus():UnregisterAll(...)
end

function lib:TriggerEvent(...)
    return GetGlobalBus():TriggerEvent(...)
end

function lib:IsRegistered(...)
    return GetGlobalBus():IsRegistered(...)
end

function lib:HookSecureFunc(...)
    return GetGlobalBus():HookSecureFunc(...)
end

function lib:HookScript(...)
    return GetGlobalBus():HookScript(...)
end
