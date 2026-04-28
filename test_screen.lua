-- test_screen.lua
-- Diagnostic: reads screen text from both CPU RAM and PPU nametable.
-- Writes output to screen_dump.txt.
-- Auto-dumps on load, then re-dumps on controller Select button.
-- TIP: Talk to someone in-game, then press Select while text is showing.

if not FCEU then
    print("SKIP: FCEUX globals are not available; load this diagnostic script in FCEUX to run it.")
    os.exit(0)
end

local chars = require "chars"

local SCREEN_BUF_START = 0x0400  -- CPU RAM shadow buffer
local SCREEN_WIDTH = 32
local SCREEN_HEIGHT = 30

-- PPU nametable addresses (where the NES actually stores visible tiles)
local PPU_NT0 = 0x2000  -- Nametable 0
local PPU_NT1 = 0x2400  -- Nametable 1

-- Output file
local source = debug.getinfo(1, "S").source
local script_dir = source:match("@?(.*[\\/])") or ""
local output_file = script_dir .. "screen_dump.txt"

local f = io.open(output_file, "w")
if not f then
    print("ERROR: Could not open " .. output_file)
    while true do FCEU.frameadvance() end
end

local function log(text)
    f:write(text .. "\n")
    f:flush()
end

-- Read a row of 32 bytes from a given base address using a read function
local function read_row_raw(base_addr, row, read_func)
    local hex = {}
    for col = 0, SCREEN_WIDTH - 1 do
        local val = read_func(base_addr + (row * SCREEN_WIDTH) + col)
        hex[#hex + 1] = string.format("%02X", val)
    end
    return table.concat(hex, " ")
end

-- Decode a row of bytes into text using chars table
local function decode_row(base_addr, row, read_func)
    local bytes = {}
    for col = 0, SCREEN_WIDTH - 1 do
        bytes[col + 1] = read_func(base_addr + (row * SCREEN_WIDTH) + col)
    end
    return chars.decode_bytes(bytes)
end

-- Check if a row has any non-trivial content
local function row_has_content(base_addr, row, read_func)
    for col = 0, SCREEN_WIDTH - 1 do
        local val = read_func(base_addr + (row * SCREEN_WIDTH) + col)
        if val ~= 0x5F and val ~= 0x00 and val ~= 0xFF and val ~= 0x24 then
            return true
        end
    end
    return false
end

-- Dump screen data from a given source
local function dump_source(label, base_addr, read_func)
    log("--- " .. label .. " ---")
    local found_any = false
    for row = 0, SCREEN_HEIGHT - 1 do
        if row_has_content(base_addr, row, read_func) then
            local decoded = decode_row(base_addr, row, read_func)
            local trimmed = decoded:match("^%s*(.-)%s*$") or ""
            log(string.format("Row %2d decoded: [%s]", row, trimmed))
            log(string.format("Row %2d raw:     %s", row, read_row_raw(base_addr, row, read_func)))
            found_any = true
        end
    end
    if not found_any then
        log("  (no content found)")
        -- Dump rows 18-27 raw anyway (dialogue window area)
        log("  Dialogue area rows 18-27 raw:")
        for row = 18, 27 do
            log(string.format("  Row %2d: %s", row, read_row_raw(base_addr, row, read_func)))
        end
    end
    log("")
end

-- Full dump from all sources
local function do_dump(label)
    log("")
    log("========================================")
    log("=== DUMP: " .. label .. " ===")
    log("========================================")

    -- 1. CPU RAM buffer
    dump_source("CPU RAM (0x0400-0x07BF)", SCREEN_BUF_START, memory.readbyte)

    -- 2. PPU Nametable 0 (if ppu.readbyte exists)
    if ppu and ppu.readbyte then
        dump_source("PPU Nametable 0 (0x2000)", PPU_NT0, ppu.readbyte)
        dump_source("PPU Nametable 1 (0x2400)", PPU_NT1, ppu.readbyte)
    else
        log("--- PPU readbyte NOT available ---")
        log("Checking what PPU functions exist...")
        for k, v in pairs(_G) do
            if type(k) == "string" and k:lower():find("ppu") then
                log("  Found: " .. k .. " (" .. type(v) .. ")")
                if type(v) == "table" then
                    for k2, v2 in pairs(v) do
                        log("    ." .. tostring(k2) .. " = " .. type(v2))
                    end
                end
            end
        end
        log("")
    end

    log("========================================")
    log("")
end

-- Startup
log("Script loaded.")
log("Talk to an NPC so dialogue text is on screen,")
log("then press Select on the controller to dump.")
FCEU.message("Screen test -> screen_dump.txt")

-- Auto-dump after a short delay
for i = 1, 10 do
    FCEU.frameadvance()
end
do_dump("initial (auto)")

-- Main loop: re-dump on Select
local prev_joy = {}
while true do
    local joy = joypad.read(1)
    if joy and joy.select and not prev_joy.select then
        do_dump("Select pressed")
        FCEU.message("Dump written to file")
    end
    if joy then
        prev_joy = joy
    end
    FCEU.frameadvance()
end
