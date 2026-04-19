-- DecalProjector
-- Author: MaximumADHD
-- Created: 4/18/2026

local MainToolbar = plugin:CreateToolbar("Decal Projector")

local MainToggle = MainToolbar:CreateButton(
    "Decal Projector",
    "Open the Decal Projector",
    "rbxassetid://15658721128"
)

local MainWidget = (function ()
    local config = DockWidgetPluginGuiInfo.new(
        Enum.InitialDockState.Left,
        false, -- Initially enabled
        false, -- Override the previous state
        300, -- Default width
        600 -- Default height
    )

    local self = plugin:CreateDockWidgetPluginGuiAsync("DecalProjector", config)
    self.Title = "Decal Projector"
    self.Name = "DecalProjector"

    return self
end)()

local Packages = script.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local Components = script.Components
local Plugin = require(Components.Plugin)

local Contexts = script.Contexts
local ThemeContext = require(Contexts.Theme)
local PluginContext = require(Contexts.Plugin)

local Root = ReactRoblox.createRoot(MainWidget)
local mounted = false

local function mount()
    if mounted then
        return
    end
    
    local element = React.createElement<<any>>(PluginContext.Provider, {
        Plugin = plugin,
    }, {
        Theme = React.createElement<<any>>(ThemeContext.Provider, {}, {
            UI = React.createElement(Plugin),
        }),
    })
    
    Root:render(element :: React.Node)
    mounted = true
end

local function unmount()
    if not mounted then
        return
    end

    Root:unmount()
    mounted = false
end

local function updateActive()
    MainToggle:SetActive(MainWidget.Enabled)

    if MainWidget.Enabled then
        mount()
    else
        unmount()
    end
end

local function onToggleClicked()
    MainWidget.Enabled = not MainWidget.Enabled
    updateActive()
end

updateActive()
plugin.Unloading:Connect(unmount)
MainToggle.Click:Connect(onToggleClicked)