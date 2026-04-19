local Selection = game:GetService("Selection")

local Hooks = script.Parent
local useSignal = require(Hooks.useSignal)

local Root = Hooks.Parent
local React = require(Root.Packages.React)

local function useSelection(): { Instance }
    local selection, setSelection = React.useState(Selection:Get())

    useSignal(Selection.SelectionChanged, function ()
        setSelection(Selection:Get())
    end, {})

    return selection
end

return useSelection