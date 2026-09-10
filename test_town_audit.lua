local audit = require "town_audit"
local function equal(a,b,msg) assert(a==b, (msg or "mismatch") .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local tests = {}
local function fixture(opts)
    opts=opts or {}
    local captured, saved, frontier_calls, order = nil, nil, 0, {}
    local ctx = {map_id=8, map_name="Brecconary", x=1, y=15,
        targets=opts.targets or {
            {id="npc_3",name="Blocked",type="npc",x=10,y=10},
            {id="npc_1",name="Inn",type="npc",service=true,x=5,y=5,interaction_x=5,interaction_y=3},
            {id="npc_2",name="Crowded",type="npc",x=7,y=7}}, evidence={doors={},model="v1"}}
    local deps={
        now=function() return "2026-09-10T12:00:00Z" end,
        log=function() end, speak=function() end,
        capture=function() if opts.refuse then return nil,"not field" end return ctx end,
        changed=function() return opts.changed end,
        save=function(r)
            if opts.save_throw then error("disk unavailable") end
            if opts.save_fail then return nil,"disk full" end
            saved=r
            return {json="test.json",text="test.txt"}
        end,
        plan=function(_,obj,skip)
            order[#order+1]=obj.id
            local reachable=obj.name~="Blocked" and (obj.name~="Crowded" or skip)
            return {reachable=reachable, path_mode=obj.service and "direct" or "adjacent",
                goal_x=obj.interaction_x or obj.x, goal_y=obj.interaction_y or obj.y,
                path=reachable and {{x=5,y=3}} or nil, face_dir="south"}
        end,
        return_path=function(_,stand,skip) equal(stand.x,5,"return starts at approach spot"); return skip and {} or nil end,
        frontier=function(_,obj,goals)
            frontier_calls=frontier_calls+1
            captured=goals
            return {frontiers={{from_x=1,from_y=2,dir="right",dest_x=2,dest_y=2,
                approach="west",reason="blocked_directional",bridge_to_target=true,hidden_bridge_to_target=false}}}
        end,
    }
    local c=audit.new(deps)
    return c,opts,function() return saved,frontier_calls,captured,order end
end
function tests.budgeted_classification_return_and_live_status()
    local c,_,results=fixture()
    assert(c:start())
    c:tick(true)
    equal(#c.result.rows,1,"one target per tick")
    equal(c.result.rows[1].name,"Inn","services first")
    c:tick(true);c:tick(true)
    local saved,frontiers,goals=results()
    equal(c.active,false)
    equal(saved.status,"complete")
    equal(saved.counts.modeled_reachable,1)
    equal(saved.counts.npc_obstructed,1)
    equal(saved.counts.model_blocked,1)
    equal(saved.counts.return_concerns,2)
    equal(frontiers,1,"only map failures need frontiers")
    equal(#goals,4,"ordinary NPC frontiers target adjacent stands")
    equal(saved.rows[1].live_arrival,"untested")
    equal(saved.rows[1].return_route.status,"npc_obstructed")
end
function tests.shared_frontier_grouping_and_counter_goals()
    local c,_,results=fixture({targets={
        {id="a",name="Blocked",type="npc",service=true,x=25,y=25,interaction_x=23,interaction_y=25},
        {id="b",name="Blocked",type="npc",service=true,x=25,y=25,interaction_x=23,interaction_y=25}}})
    assert(c:start());c:tick(true);c:tick(true)
    local saved,_,goals=results()
    equal(#saved.groups,1,"shared edge deduplicated")
    equal(#saved.groups[1].targets,2)
    equal(goals[1].x,23,"frontier uses public counter stand")
    equal(#goals,1)
end
function tests.partial_report_on_context_change_and_stop()
    local c,opts,results=fixture()
    assert(c:start());c:tick(true)
    opts.changed="hero_position_changed";c:tick(true)
    local saved=results()
    equal(saved.status,"aborted");equal(#saved.rows,1)
    local d=fixture();assert(d:start());d:stop();equal(d.result.status,"stopped")
end
function tests.refusal_and_empty_map()
    local c=fixture({refuse=true});equal(c:start(),false)
    c=fixture();equal(c:start("garbage"),false)
    c=fixture({targets={}});assert(c:start());c:tick(true);equal(c.result.status,"complete")
end
function tests.save_errors_are_reported_without_crashing()
    for _, flag in ipairs({"save_fail","save_throw"}) do
        local c=fixture({targets={},[flag]=true});assert(c:start());c:tick(true)
        equal(c.active,false);assert(c:report():find("Save failed",1,true))
    end
end
function tests.unique_persistent_reports_escape_text()
    local c=fixture({targets={{id="quote",name='Inn "special"\nline',type="npc",service=true,x=5,y=5}}})
    assert(c:start());c:tick(true)
    local dir=(os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp") .. "/"
    local first=assert(audit.save_report(c.result,dir))
    local second=assert(audit.save_report(c.result,dir))
    assert(first.json~=second.json,"reports must not overwrite")
    local f=assert(io.open(first.json,"rb"));local text=f:read("*a");f:close()
    assert(text:find('\\"special\\"',1,true),"JSON quotes escaped")
    assert(text:find('\\u000a',1,true),"JSON controls escaped")
    for _, paths in ipairs({first,second}) do os.remove(paths.json);os.remove(paths.text) end
end
local failed,total=0,0
for name,fn in pairs(tests) do
    total=total+1;local ok,err=pcall(fn)
    if ok then print("PASS "..name) else failed=failed+1;print("FAIL "..name..": "..tostring(err)) end
end
print("Ran "..total.." town audit tests")
if failed>0 then os.exit(1) end
