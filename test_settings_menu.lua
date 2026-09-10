-- Deterministic menu interaction tests, without emulator or disk writes.
local combo = require "key_combo"
local function env()
    local values = {key_mod_settings="Shift+F11", key_mod_help="Shift+F12",
        enable_auto_step="true", overworld_auto_walk_continuous="false",
        darkness_navigation_limits="balanced", object_nav_speech_coalesce_frames="18",
        auto_walk_progress_interval="6", travel_warnings="true", low_health_warning="true", low_health_threshold_percent="25"}
    local e = {messages={}, saved={}, stopped=0}
    local cfg = {get=function(k) return values[k] end,
        get_default=function(k) return values[k] end,
        save_changes=function(changes)
            if e.fail then return nil, "disk full" end
            e.saved[#e.saved+1] = changes
            return true
        end}
    local chunk = assert(loadfile("settings_menu.lua"))
    setfenv(chunk, setmetatable({require=function(name)
        if name == "config" then return cfg end
        if name == "key_combo" then return combo end
        if name == "key_reference" then return require("key_reference") end
        if name == "tolk" then return {output_interrupt=function(s) e.messages[#e.messages+1]=s end} end
        error(name)
    end, package={loaded={}}}, {__index=_G}))
    e.menu=chunk()
    function e.update(keys, joy, reason)
        return e.menu.update(keys or {}, joy or {}, reason, function() e.stopped=e.stopped+1 end)
    end
    function e.tap(keys) e.update({}); return e.update(keys) end
    function e.open() e.tap({Shift=true,F11=true}) end
    function e.last() return e.messages[#e.messages] end
    return e
end
local tests = {}
function tests.save_and_release_gate()
    local e=env(); e.open()
    assert(e.stopped==1 and e.menu.is_open())
    assert(e.last():find("Control+Enter saves",1,true))
    e.tap({Enter=true}); e.tap({Left=true}); e.tap({Enter=true})
    e.tap({Ctrl=true,Enter=true})
    assert(not e.menu.is_open() and e.saved[1].enable_auto_step=="false")
    assert(e.saved[1].darkness_navigation_limits==nil)
    assert(e.update({Enter=true}) and e.menu.is_capturing())
    assert(e.update({}, {A=true}) and e.menu.is_capturing())
    assert(e.update({}) and not e.menu.is_capturing())
    assert(not e.update({}))
end
function tests.cancel_edit_and_discard_session()
    local e=env(); e.open(); e.tap({Enter=true}); e.tap({Left=true})
    e.tap({Escape=true}); assert(e.menu.is_open())
    e.tap({Ctrl=true,Enter=true}); assert(next(e.saved[1])==nil)
    e.update({}); e.open(); e.tap({Enter=true}); e.tap({Left=true}); e.tap({Enter=true})
    e.tap({Escape=true}); assert(#e.saved==1 and not e.menu.is_open())
end
function tests.groups_remember_option_and_edit_arrows_do_not_switch_group()
    local e=env();e.open();e.tap({Down=true});e.tap({Right=true});e.tap({Left=true})
    assert(e.last():find("Overworld auto-walk",1,true))
    e.tap({Enter=true});e.tap({Right=true});assert(e.last():find("Continuous",1,true))
    e.tap({Enter=true});e.tap({Ctrl=true,Enter=true})
    assert(e.saved[1].overworld_auto_walk_continuous=="true")
end
function tests.failure_preserves_pending_changes_and_retry()
    local e=env();e.open();e.tap({Enter=true});e.tap({Left=true});e.tap({Enter=true})
    e.fail=true;e.tap({Ctrl=true,Enter=true})
    assert(e.menu.is_open() and e.last():find("disk full",1,true))
    e.fail=false;e.tap({Ctrl=true,Enter=true});assert(e.saved[1].enable_auto_step=="false")
end
function tests.restore_requires_confirmation_and_is_staged()
    local e=env();e.open();e.tap({Enter=true});e.tap({Left=true});e.tap({Enter=true})
    e.tap({Left=true});e.tap({Down=true});e.tap({Enter=true})
    assert(e.last():find("Enter confirms",1,true))
    e.tap({Escape=true});e.tap({Ctrl=true,Enter=true})
    assert(e.saved[1].enable_auto_step=="false")
    e.update({});e.open();e.tap({Enter=true});e.tap({Enter=true})
    assert(#e.saved==1 and e.menu.is_open())
end
function tests.refusal_and_help_do_not_change_game_or_settings()
    local e=env();e.update({Shift=true,F11=true},{},"Close the command menu first")
    assert(e.stopped==0 and not e.menu.is_open() and e.last():find("unavailable",1,true))
    e.update({});e.tap({Shift=true,F12=true});assert(#e.saved==0 and e.stopped==1 and e.menu.is_open())
end
function tests.held_keys_do_not_repeat_and_help_keeps_edit()
    local e=env();e.open();e.tap({Enter=true});e.tap({Left=true})
    e.update({Left=true});e.tap({Shift=true,F12=true});assert(e.menu.is_open())
    e.tap({Ctrl=true,Enter=true});assert(#e.saved==0)
    e.tap({Enter=true});e.tap({Ctrl=true,Enter=true});assert(e.saved[1].enable_auto_step=="false")
end
function tests.reference_uses_shared_capture_and_never_edits_or_saves()
    local e=env(); e.tap({Shift=true,F12=true})
    assert(e.menu.is_open() and e.last():find("Key Reference",1,true))
    e.tap({Right=true}); assert(e.last():find("Information",1,true))
    e.tap({Enter=true}); assert(e.last():find("coordinates",1,true))
    e.tap({Ctrl=true,Enter=true}); assert(#e.saved==0 and e.menu.is_open())
    e.tap({Shift=true,F11=true}); assert(e.last():find("coordinates",1,true))
    e.tap({U=true}); assert(#e.saved==0)
    e.tap({Escape=true}); assert(not e.menu.is_open())
    assert(e.update({}, {up=true}) and e.menu.is_capturing())
    e.update({}); assert(not e.menu.is_capturing())
end
function tests.settings_contextual_help_preserves_pending_edits()
    local e=env();e.open();e.tap({Enter=true});e.tap({Left=true});e.tap({Enter=true})
    e.tap({Shift=true,F12=true})
    assert(e.last():find("On completes one tile",1,true) and e.menu.is_open())
    assert(not e.last():find("Key Reference.",1,true))
    e.tap({Ctrl=true,Enter=true});assert(e.saved[1].enable_auto_step=="false")
end
function tests.low_health_options_are_staged_and_saved()
    local e=env();e.open();e.tap({Right=true});e.tap({Right=true});e.tap({Down=true})
    assert(e.last():find("Low-health warning: On",1,true))
    e.tap({Enter=true});e.tap({Left=true});e.tap({Enter=true});e.tap({Down=true})
    assert(e.last():find("Low-health threshold: 25 percent",1,true))
    e.tap({Enter=true});e.tap({Right=true});e.tap({Enter=true})
    assert(#e.saved==0)
    e.tap({Ctrl=true,Enter=true})
    assert(e.saved[1].low_health_warning=="false" and e.saved[1].low_health_threshold_percent=="30")
end
local count=0
for name,test in pairs(tests) do test();count=count+1;print("PASS "..name) end
print("Ran "..count.." settings menu tests")
