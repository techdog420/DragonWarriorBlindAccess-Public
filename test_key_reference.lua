-- Read-only key reference model: groups, real bindings, no command execution.
local reference = require "key_reference"
local tests = {}
local function env(emulator)
    local values = {key_position="C|F17", key_hp="H|F19", key_mod_settings="Shift+F11",
        key_mod_help="Shift+F12"}
    local cfg = {get=function(key) return values[key] end}
    return reference.new(cfg, emulator), values
end
function tests.bindings_are_live_and_alternatives_are_spoken()
    local r,v=env();r.move(1,0)
    assert(r.describe():find("C or F17",1,true))
    v.key_position="Ctrl+P|F22"
    assert(r.describe():find("Control plus P or F22",1,true))
    v.key_position=""
    assert(r.help():find("Not assigned",1,true))
end
function tests.groups_wrap_positions_remember_and_items_clamp()
    local r=env();r.move(1,0);r.move(0,1)
    assert(r.describe():find("Health and magic",1,true))
    r.move(1,0);r.move(-1,0)
    assert(r.describe():find("Health and magic",1,true))
    for _=1,50 do r.move(0,-1) end
    assert(r.describe():find("1 of 9",1,true))
    r.move(-1,0);r.move(-1,0)
    assert(r.describe():find("Mod Settings",1,true))
    r.move(1,0);assert(r.describe():find("Gameplay",1,true))
end
function tests.gameplay_binding_descriptions_identify_source()
    local r,v=env();r.move(0,1)
    assert(r.describe():find("F through the FCEUX keyboard bridge",1,true))
    v.enable_keyboard_input_bridge="false"
    assert(r.describe():find("bridge disabled",1,true))
    local b=env({is_bizhawk=true});b.move(0,1)
    assert(b.describe():find("X by default in BizHawk",1,true))
end
function tests.explanations_do_not_dispatch_actions_or_write_settings()
    local r,v=env();r.move(-1,0)
    assert(r.help():find("Control+Enter saves",1,true))
    r.move(-1,0)
    assert(r.help():find("Teleport skips",1,true))
    r.move(-1,0);r.move(0,1)
    assert(r.help():find("Poison-swamp",1,true))
    assert(v.key_mod_settings=="Shift+F11")
end
function tests.every_player_hotkey_has_one_reference_entry()
    local f=assert(io.open("config.lua","rb"));local source=f:read("*a");f:close()
    local counts={}
    local r=reference.new({get=function(key) counts[key]=(counts[key] or 0)+1;return key end})
    -- One initial item per group, then advance through that group's known size.
    for _,size in ipairs({5,9,11,6,5,2}) do
        r.describe()
        for _=2,size do r.move(0,1) end
        -- move reads the first binding in the next group; exclude that read.
        local old=counts;counts={};r.move(1,0);counts=old
    end
    for key in source:gmatch('key = "(key_[%w_]+)"') do
        if not key:find("^key_diag_") or key=="key_diag_tiles" then
            assert(counts[key]==1,key.." must appear exactly once")
        end
    end
end
local count=0
for name,test in pairs(tests) do test();count=count+1;print("PASS "..name) end
print("Ran "..count.." key reference tests")
