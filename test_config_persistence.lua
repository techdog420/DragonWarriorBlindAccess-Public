-- Config save transaction tests use an in-memory filesystem with injected failures.
local function env()
    local e={files={}, fail={}}
    local path="dw_access.ini"
    local initial="; custom comment\r\nenable_auto_step=true ; keep inline\r\ncustom_setting=untouched\r\noverworld_auto_walk_continuous=false\r\n"
    e.files[path]=initial
    local fs={}
    function fs.open(name,mode)
        if e.fail.open and mode=="wb" then return nil,"write denied" end
        if mode=="r" or mode=="rb" then
            if not e.files[name] then return nil,"missing file" end
            return {read=function() return e.files[name] end,close=function() return true end}
        end
        if mode=="w" or mode=="wb" then e.files[name]="" end
        return {write=function(_,value)
            if e.fail.write then return nil,"disk full" end
            e.files[name]=(e.files[name] or "")..value;return true
        end,close=function() if e.fail.close then return nil,"flush failed" end return true end}
    end
    local os_mock={remove=function(name) e.files[name]=nil;return true end,
        rename=function(a,b)
            if e.fail.replace and a==path..".tmp" then return nil,"replacement denied" end
            if e.fail.backup and b==path..".bak" then return nil,"backup denied" end
            if e.files[b] then return nil,"exists" end
            if not e.files[a] then return nil,"missing" end
            e.files[b]=e.files[a];e.files[a]=nil;return true
        end}
    local chunk=assert(loadfile("config.lua"))
    setfenv(chunk,setmetatable({io=fs,os=os_mock,debug={getinfo=function() return {source="@config.lua"} end}}, {__index=_G}))
    e.config=chunk()
    e.original=e.files[path] -- include normal new-setting migration
    return e
end
local tests={}
function tests.preserve_comments_unknown_keys_and_backup()
    local e=env();assert(e.config.save_changes({enable_auto_step="false"}))
    local s=e.files['dw_access.ini']
    assert(s:find("enable_auto_step=false ; keep inline",1,true))
    assert(s:find("custom_setting=untouched",1,true))
    assert(s:find("; custom comment\r\n",1,true))
    assert(e.files['dw_access.ini.bak']==e.original)
    assert(e.config.get('enable_auto_step')=='false')
end
function tests.failures_do_not_change_memory_or_original()
    for _,fault in ipairs({'open','write','close','backup','replace'}) do
        local e=env();e.fail[fault]=true
        local ok,err=e.config.save_changes({enable_auto_step="false"})
        assert(not ok and err, fault)
        assert(e.files['dw_access.ini']==e.original, fault)
        assert(e.config.get('enable_auto_step')=='true',fault)
    end
end
function tests.no_changes_no_write_and_invalid_input_rejected()
    local e=env();e.fail.open=true
    assert(e.config.save_changes({}))
    assert(not e.config.save_changes({enable_auto_step="false\nmalicious=true"}))
    assert(not e.config.save_changes({unknown="true"}))
    assert(e.files['dw_access.ini']==e.original)
end
function tests.duplicate_keys_and_external_edits()
    local e=env()
    e.files['dw_access.ini']=e.original.."enable_auto_step=true\nexternal_key=recent\n"
    assert(e.config.save_changes({enable_auto_step="false"}))
    local s=e.files['dw_access.ini']
    assert(not s:find("enable_auto_step=true",1,true))
    assert(s:find("external_key=recent",1,true))
end
local count=0
for name,test in pairs(tests) do test();count=count+1;print("PASS "..name) end
print("Ran "..count.." config persistence tests")
