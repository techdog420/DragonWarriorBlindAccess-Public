-- key_combo.lua
-- Helpers for configurable hotkeys such as "N", "Ctrl+N", or "Shift+F".

local M = {}

local MODIFIER_ALIASES = {
    ctrl = {
        "Ctrl", "Control", "LeftCtrl", "RightCtrl", "LeftControl", "RightControl",
        "Left Control", "Right Control", "LControlKey", "RControlKey",
    },
    shift = {
        "Shift", "LeftShift", "RightShift", "Left Shift", "Right Shift",
        "LShiftKey", "RShiftKey",
    },
    alt = {
        "Alt", "LeftAlt", "RightAlt", "Left Alt", "Right Alt", "LMenu", "RMenu",
    },
}

local SPECIAL_ALIASES = {
    space = {"Space", "space", "SPACE"},
    enter = {"Enter", "Return", "enter", "return", "ENTER", "RETURN"},
    tab = {"Tab", "tab", "TAB"},
    backspace = {"Backspace", "Back", "backspace", "BACKSPACE"},
}

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function canonical_modifier(part)
    local cleaned = trim(part):lower():gsub("[%s_-]", "")
    if cleaned == "ctrl" or cleaned == "control" or cleaned == "ctl" then
        return "ctrl"
    end
    if cleaned == "shift" then
        return "shift"
    end
    if cleaned == "alt" or cleaned == "option" then
        return "alt"
    end
    return nil
end

local function aliases_for_part(part)
    part = trim(part)
    if part == "" then return {} end

    local modifier = canonical_modifier(part)
    if modifier then
        return MODIFIER_ALIASES[modifier] or {part}
    end

    local special = SPECIAL_ALIASES[part:lower()]
    if special then
        return special
    end

    if #part == 1 then
        return {part:upper(), part:lower()}
    end
    return {part}
end

function M.parse(spec)
    local parts = {}
    spec = trim(spec)
    if spec == "" then return parts end
    for part in spec:gmatch("[^+]+") do
        local aliases = aliases_for_part(part)
        if #aliases > 0 then
            parts[#parts + 1] = aliases
        end
    end
    return parts
end

function M.is_combo(spec)
    return #M.parse(spec) > 1
end

local function any_alias_down(keys, aliases)
    for _, alias in ipairs(aliases) do
        if keys and keys[alias] then
            return true
        end
    end
    return false
end

function M.is_down(keys, spec)
    return M.is_down_parsed(keys, M.parse(spec))
end

-- Same as is_down but takes the already-parsed parts table from M.parse().
-- Used by callers that hold the parsed form to avoid per-frame re-parsing.
function M.is_down_parsed(keys, parts)
    if not parts or #parts == 0 then return false end
    for _, aliases in ipairs(parts) do
        if not any_alias_down(keys, aliases) then
            return false
        end
    end
    return true
end

function M.is_pressed(keys, prev_keys, spec)
    return M.is_down(keys, spec) and not M.is_down(prev_keys, spec)
end

function M.add_aliases(allowed, spec)
    for _, aliases in ipairs(M.parse(spec)) do
        for _, alias in ipairs(aliases) do
            allowed[alias] = true
        end
    end
end

return M
