-- util.lua
local Util = {}
function Util.clamp(val, minv, maxv)
    return math.max(minv, math.min(maxv, val))
end
return Util
