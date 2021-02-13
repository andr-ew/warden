local buf_time = 16777216 / 48000 --exact time from the sofctcut source

local Slice = { is_slice = true }

-- create a new slice from an old slice (the warden object handles this)
function Slice:new(o)
    o = o or {}

    --new bounds is assigned to old startend
    o.bounds = o.bounds or self.startend

    --new startend defaults to a copy of new bounds
    o.startend = o.startend or { o.bounds[1], o.bounds[2] }
    
    setmetatable(o, { __index = self })
    return o
end

function Slice:s_to_f(s) return s / self:get_boundary_length() end
function Slice:f_to_s(f) return f * self:get_boundary_length() end
function Slice:get_buffer() return self.buffer end
function Slice:get_boundary_start() return self.bounds[1] end
function Slice:get_boundary_end() return self.bounds[2] end
function Slice:get_boundary_length() return self.bounds[2] - self.bounds[1] end

function Slice:get_start(units) 
    local s = self.startend[1] - self.bounds[1] 

    if units == "fraction" then return self:s_to_f(s)
    else return s end
end
function Slice:get_end(units)
    local s = self.startend[2] - self.bounds[1] 
    
    if units == "fraction" then return self:s_to_f(s)
    else return s end
end
function Slice:get_length()
    return self.startend[2] - self.startend[1]
end

function Slice:set_start(t, units)
    t = (units == "fraction") and self:f_to_s(t) or t
    self.startend[1] = util.clamp(self.bounds[1], self.startend[2], t + self.bounds[1])
end

function Slice:set_end(t, units)
    t = (units == "fraction") and self:f_to_s(t) or t
    self.startend[2] = util.clamp(self.startend[1], self.bounds[2], t + self.bounds[1])
end

function Slice:set_length(t, units)
    t = (units == "fraction") and self:f_to_s(t) or t
    self.startend[2] = util.clamp(0, self.bounds[2], t + self.startend[1])
end

function Slice:update_voice(...)
    local voices = { ... }
    for i,v in ipairs(voices) do
        softcut.loop_start(v, self.startend[1])
        softcut.loop_end(v, self.startend[2])
        softcut.buffer(v, self.buffer)
    end
end

local warden = {}
warden.buffer = {
    Slice:new {
        startend = { 0, buf_time },
        buffer = 1
    },
    Slice:new {
        startend = { 0, buf_time },
        buffer = 2
    }
}

-- create n slices bound by the input
function warden.subloop(input, n)
    n = n or 1

    if input.is_slice and n == 1 then
        return input:new()
    elseif input.is_slice then
        local slices = {}
        for i = 1, n do slices[i] = warden.subloop(input, 1) end
        return slices
    else
        local slices = {}
        for k,v in pairs(input) do slices[k] = warden.subloop(v, n) end
        return slices
    end
end

-- divide input into n slices of equal length
function warden.divide(input, n)
    local slices = {}
    local divisions = {}

    local function add_divisions(slice, this_n)
        if slice.is_slice then
            table.insert(divisions, { n = this_n, slice = slice })
        else
            if this_n % #slice ~= 0 then 
                return 'warden.divide: n must be evenly divisible by the number of input slices!'
            end
            for k,v in pairs(slice) do
                add_division(v, this_n / #slice)
            end
        end
    end

    local err = add_divistions(input, n)
    if err then print(err); return end

    for _, div in ipairs(divisions) do
        local n, slice = div.n, div.slice

        local step = (slice.startend[2] - slice.startend[1]) / n
        local startend = { 0, 0 + step }

        for i = 1, n do
            table.insert(slices, slice:new { startend = startend })
            startend = { startend[1] + step, startend[2] + step }
        end
    end

    return slices
end
