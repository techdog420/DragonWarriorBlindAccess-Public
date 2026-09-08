-- Low health uses the real deferred queue with a synthetic gameplay snapshot.
local health = require "low_health"
local delivery = require "warning_delivery"
local function env()
    local e={queue=delivery.new({neutral_frames=2}), snapshot={hp=100,max_hp=100,level=10}, logs={}, submits=0}
    e.detector=health.new({
        output_warning=function(text) e.submits=e.submits+1;return e.queue:submit(text) end,
        update_warning=function(id,text) return e.queue:update(id,text) end,
        cancel_warning=function(id) return e.queue:cancel(id) end,
    },function(text) e.logs[#e.logs+1]=text end)
    function e.tick(hp, enabled, threshold, eligible)
        if hp~=nil then e.snapshot.hp=hp end
        e.detector.update(e.snapshot, eligible~=false, enabled~=false, threshold or 25)
    end
    return e
end
local tests={}
function tests.exact_threshold_and_no_repeats_while_low()
    local e=env();e.tick(26);assert(e.submits==0)
    e.tick(25);assert(e.submits==1)
    assert(e.queue:take_ready()[1].text=="Low health. HP 25 of 100.")
    for hp=24,1,-1 do e.tick(hp) end
    assert(e.submits==1 and e.queue:take_ready()==nil)
end
function tests.healing_above_rearms_but_healing_below_does_not()
    local e=env();e.tick(10);e.queue:take_ready();e.tick(20);e.tick(15)
    assert(e.submits==1)
    e.tick(26);e.tick(25);assert(e.submits==2)
end
function tests.loading_low_and_reload_each_warn_once()
    local e=env();e.tick(15,false);assert(e.submits==0)
    e.tick(15);e.tick(15);assert(e.submits==1)
    local reloaded=env();reloaded.tick(15);assert(reloaded.submits==1)
end
function tests.held_input_keeps_latest_hp_and_preserves_other_warnings()
    local e=env();e.queue:observe_input(true)
    e.queue:submit("Light expired")
    e.tick(25);e.tick(12);assert(e.submits==1 and not e.queue:take_ready())
    e.queue:observe_input(false);assert(not e.queue:take_ready())
    e.queue:observe_input(false)
    local ready=e.queue:take_ready()
    assert(#ready==2 and ready[1].text=="Light expired" and ready[2].text=="Low health. HP 12 of 100.")
end
function tests.healing_death_and_disable_cancel_only_pending_health()
    for _,reason in ipairs({'healed','dead','disabled','title'}) do
        local e=env();e.queue:observe_input(true);e.tick(20);e.queue:submit("Light expired")
        if reason=='healed' then e.tick(80)
        elseif reason=='dead' then e.tick(0)
        elseif reason=='disabled' then e.tick(20,false)
        else e.tick(20,true,25,false) end
        e.queue:observe_input(false);e.queue:observe_input(false)
        local ready=e.queue:take_ready()
        assert(#ready==1 and ready[1].text=="Light expired",reason)
    end
end
function tests.invalid_gameplay_never_warns()
    for _,s in ipairs({{hp=0,max_hp=100,level=10},{hp=10,max_hp=0,level=10},
        {hp=10,max_hp=100,level=0},{hp=10,max_hp=100,level=255},{hp=110,max_hp=100,level=10}}) do
        local e=env();e.snapshot=s;e.tick();assert(e.submits==0)
    end
    local e=env();e.tick(1,true,25,false);assert(e.submits==0)
    e.tick(1);assert(e.submits==1)
end
function tests.threshold_uses_percent_without_rounding_up_hp()
    local e=env();e.snapshot.max_hp=149;e.tick(38);assert(e.submits==0)
    e.tick(37);assert(e.submits==1)
    assert(e.queue:take_ready()[1].text=="Low health. HP 37 of 149.")
end
function tests.threshold_changes_recheck_and_max_hp_changes_update_pending()
    local e=env();e.queue:observe_input(true);e.tick(40);assert(e.submits==0)
    e.tick(40,true,50);assert(e.submits==1)
    e.tick(40,true,25);assert(e.queue:get_state().pending_count==0)
    e.tick(40,true,50);assert(e.submits==2)
    e.snapshot.max_hp=120;e.tick(40,true,50)
    e.queue:observe_input(false);e.queue:observe_input(false)
    assert(e.queue:take_ready()[1].text=="Low health. HP 40 of 120.")
end
function tests.threshold_validation()
    for _,bad in ipairs({'invalid',0,101,-1,math.huge}) do assert(health.threshold(bad)==25) end
    assert(health.threshold(nil)==25 and health.threshold('50')==50)
    assert(health.threshold(1)==1 and health.threshold(100)==100)
end
function tests.same_state_reload_cancels_old_pending_episode()
    local e=env();e.queue:observe_input(true);e.tick(20)
    e.detector.reset();assert(e.queue:get_state().pending_count==0)
    e.tick(20);assert(e.submits==2 and e.queue:get_state().pending_count==1)
end
local count=0
for name,test in pairs(tests) do test();count=count+1;print('PASS '..name) end
print('Ran '..count..' low health tests')
