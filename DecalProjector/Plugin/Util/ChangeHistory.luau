local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ChangeHistory = {}

local Root = script.Parent.Parent
local Guid = require(Root.Packages.Guid)

function ChangeHistory.Perform(name: string, action: () -> ())
    local guid = Guid.Create()
    local marker = ChangeHistoryService:TryBeginRecording(guid, name)

    if not marker then
        warn(`ChangeHistory: Failed to create undo marker for {name}`)
        return false, guid
    end

    local success = xpcall(action, function (err)
        warn(`ChangeHistory: Error performing change for {name}: {err}`)
    end)

    ChangeHistoryService:FinishRecording(marker, if success 
        then Enum.FinishRecordingOperation.Commit
        else Enum.FinishRecordingOperation.Cancel)

    return success, guid
end

return ChangeHistory