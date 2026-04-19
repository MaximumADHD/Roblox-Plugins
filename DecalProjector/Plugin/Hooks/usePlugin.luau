local Root = script.Parent.Parent
local React = require(Root.Packages.React)

local Contexts = Root.Contexts
local PluginContext = require(Contexts.Plugin)

local function usePlugin(): Plugin
    return React.useContext(PluginContext.Context)
end

return usePlugin