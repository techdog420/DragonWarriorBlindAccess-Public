-- warning_delivery.lua
-- Pure state machine for delaying important speech until manual input stops.
--
-- The module stores each warning as a separate record.  This is deliberate:
-- a future speech-history feature can retain message boundaries and metadata
-- instead of trying to split a combined speech string after the fact.

local M = {}

local MODIFIER_ONLY_KEYS = {
    alt = true,
    leftalt = true,
    rightalt = true,
    shift = true,
    leftshift = true,
    rightshift = true,
    control = true,
    leftcontrol = true,
    rightcontrol = true,
    ctrl = true,
    leftctrl = true,
    rightctrl = true,
    win = true,
    windows = true,
    leftwin = true,
    rightwin = true,
    leftwindows = true,
    rightwindows = true,
}

function M.keyboard_has_input(keys, physical_activity)
    if type(physical_activity) == "boolean" then return physical_activity end
    for name, pressed in pairs(keys or {}) do
        if pressed == true then
            local normalized = tostring(name):lower():gsub("[%s_%-]", "")
            if not MODIFIER_ONLY_KEYS[normalized]
               and not normalized:find("mouse", 1, true) then
                return true
            end
        end
    end
    return false
end

local function normalize_frames(value)
    local frames = math.floor(tonumber(value) or 0)
    if frames < 0 then
        return 0
    end
    return frames
end

function M.new(opts)
    opts = opts or {}

    local state = {
        neutral_frames_required = normalize_frames(opts.neutral_frames),
        neutral_frames = normalize_frames(opts.neutral_frames),
        input_active = false,
        pending = {},
        next_id = 1,
        disabled_kinds = {},
    }

    function state:set_neutral_frames(value)
        self.neutral_frames_required = normalize_frames(value)
        if self.neutral_frames > self.neutral_frames_required then
            self.neutral_frames = self.neutral_frames_required
        end
    end

    function state:observe_input(active)
        self.input_active = active == true
        if self.input_active then
            self.neutral_frames = 0
        elseif self.neutral_frames < self.neutral_frames_required then
            self.neutral_frames = self.neutral_frames + 1
        end
    end

    function state:submit(text, metadata)
        if text == nil or tostring(text) == "" then
            return nil
        end

        metadata = metadata or {}
        if self.disabled_kinds[metadata.kind or "warning"] then return nil end
        local record = {
            id = self.next_id,
            text = tostring(text),
            interrupt = metadata.interrupt ~= false,
            kind = metadata.kind or "warning",
            deferred = self.input_active
                or self.neutral_frames < self.neutral_frames_required,
        }
        self.next_id = self.next_id + 1
        self.pending[#self.pending + 1] = record
        return record
    end

    -- Address only the caller's pending warning; unrelated FIFO records survive.
    function state:cancel(id)
        for index, record in ipairs(self.pending) do
            if record.id == id then
                table.remove(self.pending, index)
                return record
            end
        end
        return nil
    end

    function state:update(id, text)
        for _, record in ipairs(self.pending) do
            if record.id == id then
                record.text = tostring(text)
                return record
            end
        end
        return nil
    end

    -- Cancel only the muted category; preserve other records and FIFO order.
    function state:set_kind_enabled(kind, enabled)
        self.disabled_kinds[kind] = not enabled
        local cancelled = {}
        if not enabled then
            for index = #self.pending, 1, -1 do
                if self.pending[index].kind == kind then
                    table.insert(cancelled, 1, table.remove(self.pending, index))
                end
            end
        end
        return cancelled
    end

    function state:take_ready()
        if self.input_active
           or self.neutral_frames < self.neutral_frames_required
           or #self.pending == 0 then
            return nil
        end

        local ready = self.pending
        self.pending = {}
        return ready
    end

    function state:get_state()
        return {
            input_active = self.input_active,
            neutral_frames = self.neutral_frames,
            neutral_frames_required = self.neutral_frames_required,
            pending_count = #self.pending,
        }
    end

    return state
end

return M
