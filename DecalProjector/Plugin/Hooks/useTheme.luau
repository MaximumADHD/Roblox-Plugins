local Root = script.Parent.Parent
local React = require(Root.Packages.React)

local Contexts = Root.Contexts
local ThemeContext = require(Contexts.Theme)

local function useTheme(): ThemeContext.ThemeState
    return React.useContext(ThemeContext.Context)
end

return useTheme