-- chars.lua
-- Dragon Warrior custom text encoding lookup table.
-- The game uses its own character set (not ASCII). Each byte in the screen
-- buffer maps to a specific character through this table.
-- Source: DataCrystal text table (https://datacrystal.tcrf.net/wiki/Dragon_Warrior/TBL)

local M = {}

-- Build the decode table: byte value -> character string
-- Unmapped bytes will return nil (we treat those as empty/unknown)
local decode = {}

-- 0x00-0x09: digits 0-9
for i = 0, 9 do
    decode[i] = tostring(i)
end

-- 0x0A-0x23: lowercase a-z (26 letters)
for i = 0, 25 do
    decode[0x0A + i] = string.char(string.byte("a") + i)
end

-- 0x24-0x3D: uppercase A-Z (26 letters)
for i = 0, 25 do
    decode[0x24 + i] = string.char(string.byte("A") + i)
end

-- Punctuation and special characters
-- Source: https://datacrystal.tcrf.net/wiki/Dragon_Warrior/TBL
decode[0x3E] = '"'   -- opening quotation mark
decode[0x3F] = '"'   -- closing quotation mark
decode[0x40] = "'"   -- apostrophe
decode[0x41] = "*"   -- asterisk
decode[0x42] = ""    -- cursor arrow (selection indicator on menus)
decode[0x43] = ""    -- cursor arrow variant
decode[0x44] = ":"   -- colon
decode[0x45] = ".."  -- double dot
decode[0x46] = "."   -- period (variant)
decode[0x47] = "."   -- period (variant)
decode[0x48] = ","   -- comma
decode[0x49] = "-"   -- hyphen
decode[0x4B] = "?"   -- question mark
decode[0x4C] = "!"   -- exclamation mark
decode[0x4D] = ";"   -- semicolon
decode[0x4E] = ")"   -- closing parenthesis
decode[0x4F] = "("   -- opening parenthesis
decode[0x50] = "'"   -- opening single quote / backtick
decode[0x51] = "'"   -- opening single quote / backtick (variant)
decode[0x52] = "."   -- period (main form used in dialogue)
decode[0x53] = "'"   -- closing single quote
decode[0x54] = "'"   -- closing single quote (variant)
decode[0x5F] = " "   -- space

-- Special macro bytes (used in shop dialogue, etc.)
-- 0xF5 = gold cost macro — we represent it as a placeholder
decode[0xF5] = "[GOLD]"

-- Store the table in the module
M.decode = decode

-- decode_byte(b): Convert a single byte to its character representation.
-- Returns the character string, or nil if the byte has no mapping.
function M.decode_byte(b)
    return decode[b]
end

-- decode_bytes(bytes): Convert a table of byte values to a string.
-- Skips bytes that have no mapping (treats them as non-text tiles).
function M.decode_bytes(bytes)
    local parts = {}
    for i = 1, #bytes do
        local ch = decode[bytes[i]]
        if ch then
            parts[#parts + 1] = ch
        end
    end
    return table.concat(parts)
end

return M
