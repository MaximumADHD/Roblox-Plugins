local FFlag = {}
local GlobalSettings = settings()

function FFlag:__index(key)
    local exists, value = pcall(function ()
        return GlobalSettings:GetFFlag(key)
    end)

    if not exists then
        value = true
    end

    rawset(self, key, value)
    return value
end

function FFlag:__newindex()
    error("FFlag table is read-only.", 2)
end

return setmetatable({}, FFlag)