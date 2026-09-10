local frontier=require "route_frontier"
local function scene(wall,directional,runtime,goals)
    local walk={[0]={[0]=true,[1]=not wall,[2]=true}}
    return frontier.analyze({map_id=8,start_x=0,start_y=0,goal_x=2,goal_y=0,goal_points=goals,
        walkability=walk,blocking=runtime or directional or {},
        map_reader={get_map_dimensions=function() return 3,1 end,
            get_directional_blocks=function() return directional or {} end,
            get_walkability_details=function(_,x) return {effective_walkable=walk[0][x],reason="tile_type",tile_type=wall and x==1 and 0 or 1} end},
        route_manager={is_cell_runtime_blocked=function(_,x,y) return runtime and runtime[x..","..y] end}})
end
local tests={}
function tests.wall_bridge_ranked_without_claiming_passability()
    local r=scene(true)
    assert(not r.target_reachable);assert(r.frontiers[1].hidden_bridge_to_target)
    assert(r.frontiers[1].dest_x==1);assert(r.frontiers[1].approach=="west")
end
function tests.directional_and_runtime_rules_preserved()
    local r=scene(false,{["1,0"]={west=true}})
    assert(not r.target_reachable);assert(r.frontiers[1].reason=="blocked_directional")
    assert(r.frontiers[1].bridge_to_target)
    r=scene(true,nil,{["1,0"]={west=true}})
    assert(r.frontiers[1].reason=="blocked_runtime");assert(not r.frontiers[1].hidden_bridge_to_target)
end
function tests.multiple_approach_spots_include_reachable_stand()
    local r=scene(true,nil,nil,{{x=0,y=0},{x=2,y=0}})
    assert(r.target_reachable,"any valid approach can make target reachable")
end
function tests.opposite_direction_is_not_blocked()
    local r=scene(false,{["1,0"]={east=true}})
    assert(r.target_reachable,"east entry restriction must not block west entry")
end
local failed,total=0,0
for name,fn in pairs(tests) do
    total=total+1;local ok,err=pcall(fn)
    if ok then print("PASS "..name) else failed=failed+1;print("FAIL "..name..": "..tostring(err)) end
end
print("Ran "..total.." route frontier tests")
if failed>0 then os.exit(1) end
