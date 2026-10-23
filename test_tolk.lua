-- Exercise pipe failures without starting a process or touching player files.
local warning_delivery = require "warning_delivery"
local function environment(fault)
    local e = {writes = {}, messages = {}, logs = {}}
    local pipe = {}
    function pipe:write(value)
        e.writes[#e.writes + 1] = value
        if fault == "write" then return nil, "broken pipe" end
        if fault == "throw" then error("broken pipe") end
        return self
    end
    function pipe:flush()
        if fault == "flush" then return nil, "flush failed" end
        return true
    end
    local fake_io = {
        open = function()
            return {write = function(_, value) e.logs[#e.logs + 1] = value end,
                    close = function() return true end}
        end,
        popen = function(_, mode)
            if mode == "w" then return pipe end
            return {read = function() return "D:\\test" end, close = function() end}
        end,
    }
    local chunk = assert(loadfile("tolk.lua"))
    setfenv(chunk, setmetatable({
        io = fake_io,
        os = {remove = function() end, date = os.date, clock = os.clock},
        debug = {getinfo = function() return {source = "@D:\\test\\tolk.lua"} end},
        require = function(name)
            if name == "ffi" then error("no FFI in FCEUX") end
            if name == "config" then return {get = function() return nil end} end
            if name == "warning_delivery" then return warning_delivery end
            error("unexpected module " .. name)
        end,
        print = function() end,
        FCEU = {message = function(value) e.messages[#e.messages + 1] = value end},
    }, {__index = _G}))
    e.tolk = chunk()
    return e
end

local tests = {}
function tests.successful_transport_keeps_bridge_available()
    local e = environment()
    e.tolk.output_interrupt("Test")
    assert(e.writes[1] == "interrupt:Test\n")
    assert(e.tolk.is_ready())
    assert(e.tolk.get_last_error() == nil)
    assert(#e.messages == 0)
end
function tests.failed_writes_and_flushes_mark_bridge_unavailable()
    for _, fault in ipairs({"write", "flush", "throw"}) do
        local e = environment(fault)
        e.tolk.output_interrupt("First")
        assert(not e.tolk.is_ready(), fault .. " must invalidate readiness")
        assert(e.tolk.get_last_error():find("bridge write failed", 1, true))
        assert(e.messages[#e.messages] == "First", "message should reach fallback")
        e.tolk.output_interrupt("Second")
        assert(#e.writes == 1, "do not retry a broken pipe on every frame")
        assert(e.messages[#e.messages] == "Second")
    end
end

local count = 0
for name, test in pairs(tests) do test(); count = count + 1; print("PASS " .. name) end
print("Ran " .. count .. " speech transport tests")
