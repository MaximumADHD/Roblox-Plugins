local Root = script.Parent.Parent
local React = require(Root.Packages.React)
local PluginContext = React.createContext(newproxy() :: Plugin)

local function PluginProvider(props)
    return React.createElement(PluginContext.Provider, {
        value = props.Plugin
    }, props.children)
end

return {
    Context = PluginContext,
    Provider = PluginProvider,
}