-- emulator_compat.lua
-- Emulator API adapter layer.
--
-- The project is written against FCEUX's Lua globals. BizHawk exposes similar
-- concepts with different names and call signatures, so this module keeps the
-- rest of the gameplay code on a stable FCEUX-shaped API while BizHawk is the
-- default runtime.

local M = {
    name = "unknown",
    is_fceux = false,
    is_bizhawk = false,
    ppu_stats = {
        read_calls = 0,
        cache_hits = 0,
        cache_misses = 0,
        direct_reads = 0,
        domain_reads = 0,
        cache_flushes = 0,
    },
}

function M.get_ppu_read_count()
    return M.ppu_stats.read_calls
end

function M.get_ppu_stats_snapshot()
    return {
        read_calls = M.ppu_stats.read_calls,
        cache_hits = M.ppu_stats.cache_hits,
        cache_misses = M.ppu_stats.cache_misses,
        direct_reads = M.ppu_stats.direct_reads,
        domain_reads = M.ppu_stats.domain_reads,
        cache_flushes = M.ppu_stats.cache_flushes,
    }
end

function M.reset_ppu_stats()
    for key in pairs(M.ppu_stats) do
        M.ppu_stats[key] = 0
    end
end

local function has_global(name)
    return rawget(_G, name) ~= nil
end

if has_global("FCEU") then
    M.name = "fceux"
    M.is_fceux = true
    _G.DW_EMULATOR_COMPAT = M
    return M
end

if not has_global("emu") then
    _G.DW_EMULATOR_COMPAT = M
    return M
end

M.name = "bizhawk"
M.is_bizhawk = true

local bizhawk_emu = emu
local bizhawk_memory = memory
local bizhawk_mainmemory = mainmemory
local bizhawk_joypad = joypad
local bizhawk_input = input
local bizhawk_console = console
local bizhawk_ppu = ppu
local ppu_frame_cache = {}
local rom_byte_cache = {}
local ppu_cache_age_frames = 0
local PPU_CACHE_HOLD_FRAMES = 120

function M.clear_ppu_cache()
    ppu_frame_cache = {}
    ppu_cache_age_frames = 0
    M.ppu_stats.cache_flushes = M.ppu_stats.cache_flushes + 1
end

local function log_message(message)
    message = tostring(message or "")
    if bizhawk_console and bizhawk_console.log then
        bizhawk_console.log(message)
    elseif print then
        print(message)
    end
end

FCEU = FCEU or {}
FCEU.frameadvance = FCEU.frameadvance or function()
    ppu_cache_age_frames = ppu_cache_age_frames + 1
    if ppu_cache_age_frames >= PPU_CACHE_HOLD_FRAMES then
        ppu_frame_cache = {}
        ppu_cache_age_frames = 0
        M.ppu_stats.cache_flushes = M.ppu_stats.cache_flushes + 1
    end
    return bizhawk_emu.frameadvance()
end
FCEU.message = FCEU.message or log_message

BIT = BIT or function(bit_index)
    return 2 ^ bit_index
end

if not AND then
    local bit_lib = rawget(_G, "bit32") or rawget(_G, "bit")
    if bit_lib and bit_lib.band then
        AND = function(a, b)
            return bit_lib.band(a or 0, b or 0)
        end
    else
        AND = function(a, b)
            a = math.floor(tonumber(a) or 0)
            b = math.floor(tonumber(b) or 0)
            local result = 0
            local bit_value = 1
            while a > 0 or b > 0 do
                if (a % 2 == 1) and (b % 2 == 1) then
                    result = result + bit_value
                end
                a = math.floor(a / 2)
                b = math.floor(b / 2)
                bit_value = bit_value * 2
            end
            return result
        end
    end
end

local is_cart_work_ram_address
local read_cart_work_ram_byte
local write_cart_work_ram_byte

local function read_u8(address)
    address = math.floor(tonumber(address) or 0)
    if is_cart_work_ram_address(address) then
        local value = read_cart_work_ram_byte(address)
        if value ~= nil then
            return value
        end
    end
    if bizhawk_mainmemory and bizhawk_mainmemory.read_u8 then
        return bizhawk_mainmemory.read_u8(address)
    end
    if bizhawk_memory and bizhawk_memory.read_u8 then
        return bizhawk_memory.read_u8(address)
    end
    if bizhawk_memory and bizhawk_memory.readbyte then
        return bizhawk_memory.readbyte(address)
    end
    error("BizHawk memory read_u8/readbyte API is unavailable")
end

local function write_u8(address, value)
    address = math.floor(tonumber(address) or 0)
    value = value or 0
    if is_cart_work_ram_address(address) and write_cart_work_ram_byte(address, value) then
        return
    end
    if bizhawk_mainmemory and bizhawk_mainmemory.write_u8 then
        return bizhawk_mainmemory.write_u8(address, value)
    end
    if bizhawk_memory and bizhawk_memory.write_u8 then
        return bizhawk_memory.write_u8(address, value)
    end
    if bizhawk_memory and bizhawk_memory.writebyte then
        return bizhawk_memory.writebyte(address, value)
    end
    error("BizHawk memory write_u8/writebyte API is unavailable")
end

memory = {
    readbyte = read_u8,
    writebyte = write_u8,
}

local ppu_domain_logged = false
local ppu_failure_logged = false
local ppu_read_candidate = nil
local rom_domain_logged = false
local rom_failure_logged = false
local rom_read_candidate = nil
local cart_ram_domain_logged = false
local cart_ram_read_candidate = nil
local cart_ram_write_candidate = nil
local memory_domains_cache = nil
local memory_domain_set_cache = nil

local CART_WORK_RAM_START = 0x6000
local CART_WORK_RAM_END = 0x7FFF

function is_cart_work_ram_address(address)
    return address >= CART_WORK_RAM_START and address <= CART_WORK_RAM_END
end

local function cart_ram_offset(address)
    return address - CART_WORK_RAM_START
end

local function raw_read_u8_from_domain(address, domain)
    if address == nil then
        return nil
    end
    if bizhawk_memory and bizhawk_memory.read_u8 then
        local ok, value = pcall(bizhawk_memory.read_u8, address, domain)
        if ok and type(value) == "number" then
            return value
        end
    end
    if bizhawk_memory and bizhawk_memory.readbyte then
        local ok, value = pcall(bizhawk_memory.readbyte, address, domain)
        if ok and type(value) == "number" then
            return value
        end
    end
    return nil
end

local function raw_write_u8_to_domain(address, domain, value)
    if address == nil then
        return false
    end
    if bizhawk_memory and bizhawk_memory.write_u8 then
        local ok = pcall(bizhawk_memory.write_u8, address, value, domain)
        if ok then
            return true
        end
    end
    if bizhawk_memory and bizhawk_memory.writebyte then
        local ok = pcall(bizhawk_memory.writebyte, address, value, domain)
        if ok then
            return true
        end
    end
    return false
end

local CART_RAM_CANDIDATES = {
    { domain = "System Bus", mapping = "cpu_bus", address_for = function(address) return address end },
    { domain = "PRG RAM", mapping = "cart_offset", address_for = cart_ram_offset },
    { domain = "PRG-RAM", mapping = "cart_offset", address_for = cart_ram_offset },
    { domain = "Cart RAM", mapping = "cart_offset", address_for = cart_ram_offset },
    { domain = "Cartridge RAM", mapping = "cart_offset", address_for = cart_ram_offset },
    { domain = "Save RAM", mapping = "cart_offset", address_for = cart_ram_offset },
    { domain = "SRAM", mapping = "cart_offset", address_for = cart_ram_offset },
    { domain = "WRAM", mapping = "cart_offset", address_for = cart_ram_offset },
}

function read_cart_work_ram_byte(address)
    if cart_ram_read_candidate then
        local value = raw_read_u8_from_domain(
            cart_ram_read_candidate.address_for(address),
            cart_ram_read_candidate.domain)
        if value ~= nil then
            return value
        end
        cart_ram_read_candidate = nil
    end

    for _, candidate in ipairs(CART_RAM_CANDIDATES) do
        local mapped_address = candidate.address_for(address)
        local value = raw_read_u8_from_domain(mapped_address, candidate.domain)
        if value ~= nil then
            cart_ram_read_candidate = candidate
            if not cart_ram_domain_logged then
                log_message(string.format(
                    "BizHawk cart RAM adapter using memory domain: %s (%s)",
                    candidate.domain,
                    candidate.mapping or "unknown"))
                cart_ram_domain_logged = true
            end
            return value
        end
    end

    return nil
end

function write_cart_work_ram_byte(address, value)
    if cart_ram_write_candidate then
        if raw_write_u8_to_domain(
            cart_ram_write_candidate.address_for(address),
            cart_ram_write_candidate.domain,
            value) then
            return true
        end
        cart_ram_write_candidate = nil
    end

    for _, candidate in ipairs(CART_RAM_CANDIDATES) do
        local mapped_address = candidate.address_for(address)
        if raw_write_u8_to_domain(mapped_address, candidate.domain, value) then
            cart_ram_write_candidate = candidate
            return true
        end
    end

    return false
end

local function get_memory_domain_list()
    if memory_domains_cache then
        return memory_domains_cache
    end

    memory_domain_set_cache = {}
    if not bizhawk_memory or not bizhawk_memory.getmemorydomainlist then
        memory_domains_cache = {}
        return memory_domains_cache
    end

    local ok, domains = pcall(bizhawk_memory.getmemorydomainlist)
    if not ok or type(domains) ~= "table" then
        memory_domains_cache = {}
        return memory_domains_cache
    end

    memory_domains_cache = domains
    for _, name in ipairs(memory_domains_cache) do
        memory_domain_set_cache[name] = true
    end
    return memory_domains_cache
end

local function domain_exists(domain)
    local domains = get_memory_domain_list()
    if #domains == 0 then
        return true
    end
    return memory_domain_set_cache[domain] == true
end

local function format_memory_domain_list()
    local domains = get_memory_domain_list()
    if #domains == 0 then
        return "unavailable"
    end
    table.sort(domains)
    return table.concat(domains, ", ")
end

local function ppu_nametable_offset(address)
    return (address - 0x2000) % 0x1000
end

local function identity_address(address)
    return address
end

local function prg_with_ines_header_offset(address)
    if address < 0x10 then
        local header = {0x4E, 0x45, 0x53, 0x1A}
        return nil, header[address + 1] or 0
    end
    return address - 0x10
end

local read_u8_from_domain

local function read_candidate_byte(candidate, address)
    local mapped_address, direct_value = candidate.address_for(address)
    if direct_value ~= nil then
        return direct_value
    end
    return read_u8_from_domain(mapped_address, candidate.domain)
end

local ROM_META_START = 0x002A
local ROM_META_SIZE = 5
local ROM_MAP_COUNT = 30

local function score_rom_candidate(candidate)
    local score = 0

    if read_candidate_byte(candidate, 0) == 0x4E
    and read_candidate_byte(candidate, 1) == 0x45
    and read_candidate_byte(candidate, 2) == 0x53
    and read_candidate_byte(candidate, 3) == 0x1A then
        score = score + 100
    else
        score = score - 100
    end

    local sane_metadata = 0
    for map_id = 0, ROM_MAP_COUNT - 1 do
        local base = ROM_META_START + map_id * ROM_META_SIZE
        local ptr_lo = read_candidate_byte(candidate, base)
        local ptr_hi = read_candidate_byte(candidate, base + 1)
        local width_max = read_candidate_byte(candidate, base + 2)
        local height_max = read_candidate_byte(candidate, base + 3)
        local border = read_candidate_byte(candidate, base + 4)

        if type(ptr_lo) == "number"
        and type(ptr_hi) == "number"
        and type(width_max) == "number"
        and type(height_max) == "number"
        and type(border) == "number" then
            local ptr = ptr_lo + ptr_hi * 256
            if ptr >= 0x8000 and ptr <= 0xFFFF
            and width_max <= 0x1F
            and height_max <= 0x1F
            and border <= 0x0F then
                sane_metadata = sane_metadata + 1
            end
        end
    end
    score = score + sane_metadata * 5

    -- The starting throne room is a useful canary because a 16-byte domain
    -- mismatch makes its height collapse, which clips the stairs corridor.
    local throne_base = ROM_META_START + 0x05 * ROM_META_SIZE
    local throne_w = read_candidate_byte(candidate, throne_base + 2)
    local throne_h = read_candidate_byte(candidate, throne_base + 3)
    if type(throne_w) == "number"
    and type(throne_h) == "number"
    and throne_w >= 8 and throne_w <= 15
    and throne_h >= 8 and throne_h <= 15 then
        score = score + 20
    end

    return score
end

local function make_domain_reader(domain)
    if bizhawk_memory and bizhawk_memory.read_u8 then
        return function(address)
            return bizhawk_memory.read_u8(address, domain)
        end
    end
    if bizhawk_memory and bizhawk_memory.readbyte then
        return function(address)
            return bizhawk_memory.readbyte(address, domain)
        end
    end
    return nil
end

read_u8_from_domain = function(address, domain)
    if address == nil then
        return nil
    end
    if not domain_exists(domain) then
        return nil
    end
    if bizhawk_memory and bizhawk_memory.read_u8 then
        local ok, value = pcall(bizhawk_memory.read_u8, address, domain)
        if ok and type(value) == "number" then
            return value
        end
    end
    if bizhawk_memory and bizhawk_memory.readbyte then
        local ok, value = pcall(bizhawk_memory.readbyte, address, domain)
        if ok and type(value) == "number" then
            return value
        end
    end
    return nil
end

local function score_ppu_candidate(candidate, address)
    local mapped_address = candidate.address_for(address)
    local primary = read_u8_from_domain(mapped_address, candidate.domain)
    if primary == nil then
        return nil
    end

    local mirrored = read_u8_from_domain(candidate.address_for(0x2400), candidate.domain)
    local score = 1
    if mirrored ~= nil then
        score = score + 2
    end
    return score, primary
end

local function read_ppu_byte(address)
    address = math.floor(tonumber(address) or 0)
    M.ppu_stats.read_calls = M.ppu_stats.read_calls + 1
    local cached = ppu_frame_cache[address]
    if cached ~= nil then
        M.ppu_stats.cache_hits = M.ppu_stats.cache_hits + 1
        return cached
    end

    M.ppu_stats.cache_misses = M.ppu_stats.cache_misses + 1
    if bizhawk_ppu and bizhawk_ppu.readbyte then
        local value = bizhawk_ppu.readbyte(address)
        M.ppu_stats.direct_reads = M.ppu_stats.direct_reads + 1
        ppu_frame_cache[address] = value
        return value
    end

    if ppu_read_candidate then
        local value = ppu_read_candidate.reader(ppu_read_candidate.address_for(address))
        M.ppu_stats.domain_reads = M.ppu_stats.domain_reads + 1
        ppu_frame_cache[address] = value
        return value
    end

    local candidates = {
        { domain = "PPU Bus", address_for = function(a) return a end },
        { domain = "PPU Memory", address_for = function(a) return a end },
        { domain = "PPU", address_for = function(a) return a end },
        { domain = "VRAM", address_for = function(a) return a end },
        { domain = "CIRAM", address_for = ppu_nametable_offset },
        { domain = "Nametables", address_for = ppu_nametable_offset },
        { domain = "Name Table RAM", address_for = ppu_nametable_offset },
        { domain = "CIRAM (nametables)", address_for = ppu_nametable_offset },
    }

    local best_candidate = nil
    local best_value = nil
    local best_score = -1
    for _, candidate in ipairs(candidates) do
        local score, value = score_ppu_candidate(candidate, address)
        if score and score > best_score then
            best_candidate = candidate
            best_value = value
            best_score = score
        end
    end

    if best_candidate then
        best_candidate.reader = make_domain_reader(best_candidate.domain)
        if best_candidate.reader then
            ppu_read_candidate = best_candidate
        end
        if not ppu_domain_logged then
            log_message("BizHawk PPU adapter using memory domain: " .. best_candidate.domain)
            ppu_domain_logged = true
        end
        ppu_frame_cache[address] = best_value
        M.ppu_stats.domain_reads = M.ppu_stats.domain_reads + 1
        return best_value
    end

    if not ppu_failure_logged then
        log_message("BizHawk PPU adapter could not find a readable PPU domain. Available domains: " .. format_memory_domain_list())
        ppu_failure_logged = true
    end
    ppu_frame_cache[address] = 0
    return 0
end

ppu = {
    readbyte = read_ppu_byte,
}

local function read_rom_byte(address)
    address = math.floor(tonumber(address) or 0)
    local cached = rom_byte_cache[address]
    if cached ~= nil then
        return cached
    end

    if rom_read_candidate then
        local mapped_address, direct_value = rom_read_candidate.address_for(address)
        if direct_value ~= nil then
            rom_byte_cache[address] = direct_value
            return direct_value
        end
        local value = rom_read_candidate.reader(mapped_address)
        rom_byte_cache[address] = value
        return value
    end

    local candidates = {
        { domain = "ROM", mapping = "identity", address_for = identity_address },
        { domain = "ROM", mapping = "prg_offset", address_for = prg_with_ines_header_offset },
        { domain = "System Bus", mapping = "identity", address_for = identity_address },
        { domain = "PRG ROM", mapping = "prg_offset", address_for = prg_with_ines_header_offset },
        { domain = "PRG-ROM", mapping = "prg_offset", address_for = prg_with_ines_header_offset },
        { domain = "PRG", mapping = "prg_offset", address_for = prg_with_ines_header_offset },
        { domain = "Cart ROM", mapping = "prg_offset", address_for = prg_with_ines_header_offset },
        { domain = "Cartridge ROM", mapping = "prg_offset", address_for = prg_with_ines_header_offset },
    }

    local best_candidate = nil
    local best_score = nil
    local best_value = nil

    for _, candidate in ipairs(candidates) do
        local value = read_candidate_byte(candidate, address)
        local data_probe = read_candidate_byte(candidate, 0x10)
        if value ~= nil and data_probe ~= nil then
            local reader = make_domain_reader(candidate.domain)
            local _, direct_value = candidate.address_for(address)
            if reader or direct_value ~= nil then
                local score = score_rom_candidate(candidate)
                if not best_score or score > best_score then
                    best_candidate = candidate
                    best_candidate.reader = reader
                    best_score = score
                    best_value = value
                end
            end
        end
    end

    if best_candidate then
        rom_read_candidate = best_candidate
        if not rom_domain_logged then
            log_message(string.format(
                "BizHawk ROM adapter using memory domain: %s (%s, score=%d)",
                best_candidate.domain,
                best_candidate.mapping or "unknown",
                best_score or 0))
            rom_domain_logged = true
        end
        rom_byte_cache[address] = best_value
        return best_value
    end

    if not rom_failure_logged then
        log_message("BizHawk ROM adapter could not find a readable ROM domain. Available domains: " .. format_memory_domain_list())
        rom_failure_logged = true
    end
    rom_byte_cache[address] = 0
    return 0
end

rom = {
    readbyte = read_rom_byte,
}

local BUTTON_TO_BIZHAWK = {
    up = "Up",
    down = "Down",
    left = "Left",
    right = "Right",
    A = "A",
    B = "B",
    start = "Start",
    select = "Select",
}

local BIZHAWK_BUTTON_ALIASES = {
    up = {"up", "Up", "P1 Up"},
    down = {"down", "Down", "P1 Down"},
    left = {"left", "Left", "P1 Left"},
    right = {"right", "Right", "P1 Right"},
    A = {"A", "P1 A"},
    B = {"B", "P1 B"},
    start = {"start", "Start", "P1 Start"},
    select = {"select", "Select", "P1 Select"},
}

local function table_has_any(source, names)
    if not source then
        return false
    end
    for _, name in ipairs(names) do
        if source[name] then
            return true
        end
    end
    return false
end

local function normalize_joypad(source)
    local normalized = {}
    for project_name, aliases in pairs(BIZHAWK_BUTTON_ALIASES) do
        normalized[project_name] = table_has_any(source, aliases)
    end
    return normalized
end

local function to_bizhawk_buttons(project_buttons)
    local converted = {}
    for project_name, bizhawk_name in pairs(BUTTON_TO_BIZHAWK) do
        converted[bizhawk_name] = project_buttons and project_buttons[project_name] or false
    end
    return converted
end

joypad = {
    read = function(controller)
        if not bizhawk_joypad or not bizhawk_joypad.get then
            return {}
        end
        return normalize_joypad(bizhawk_joypad.get(controller or 1))
    end,

    set = function(controller, buttons)
        if type(controller) == "table" then
            buttons = controller
            controller = 1
        end
        if not bizhawk_joypad or not bizhawk_joypad.set then
            return
        end
        return bizhawk_joypad.set(to_bizhawk_buttons(buttons or {}), controller or 1)
    end,
}

input = {
    get = function()
        if bizhawk_input and bizhawk_input.get then
            return bizhawk_input.get() or {}
        end
        return {}
    end,
}

_G.DW_EMULATOR_COMPAT = M
return M
