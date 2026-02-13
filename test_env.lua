-- test_env.lua
-- Diagnostic script to check what FCEUX's Lua environment supports.
-- Load this in FCEUX (File > Load Lua Script) and watch the output pane
-- and the emulator screen for messages.

-- Check Lua version
print("Lua version: " .. (_VERSION or "unknown"))
FCEU.message("Lua version: " .. (_VERSION or "unknown"))

-- Check if LuaJIT FFI is available (it probably isn't)
local ffi_ok, ffi = pcall(require, "ffi")
if ffi_ok then
    print("FFI: AVAILABLE (LuaJIT detected)")
    FCEU.message("FFI available")
else
    print("FFI: NOT available (standard Lua 5.1)")
    FCEU.message("No FFI - standard Lua")
end

-- Check if io.popen is available (needed for pipe-based speech)
local popen_ok, popen_err = pcall(function()
    local p = io.popen("echo popen_test", "r")
    if p then
        local result = p:read("*a")
        p:close()
        return result
    end
end)
if popen_ok then
    print("io.popen: AVAILABLE")
    FCEU.message("io.popen available")
else
    print("io.popen: NOT available - " .. tostring(popen_err))
    FCEU.message("No io.popen")
end

-- Check io.popen write mode (needed to pipe text to a helper program)
local popen_w_ok, popen_w_err = pcall(function()
    local p = io.popen("more > NUL", "w")
    if p then
        p:write("test\n")
        p:close()
        return true
    end
end)
if popen_w_ok then
    print("io.popen write mode: AVAILABLE")
    FCEU.message("popen write: yes")
else
    print("io.popen write mode: NOT available - " .. tostring(popen_w_err))
    FCEU.message("popen write: no")
end

-- Check if os.execute is available
local exec_ok, exec_err = pcall(function()
    return os.execute("echo ok > NUL")
end)
if exec_ok then
    print("os.execute: AVAILABLE")
else
    print("os.execute: NOT available - " .. tostring(exec_err))
end

print("")
print("=== Diagnostic complete ===")
print("Check the messages above to see what's available.")

-- Keep the emulator running
while true do
    FCEU.frameadvance()
end
