--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @ CloneTrooper1019, 2020
--   Streaming Debugger
--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------------------------------------------------------------------------------------
local NetworkSettings = settings():GetService("NetworkSettings")
local PluginGuiService = game:GetService("PluginGuiService")

local RunService = game:GetService("RunService")
local Studio = settings():GetService("Studio")

local PLUGIN_TITLE = "Streaming Debugger"
local PLUGIN_DESC  = "Toggles the Streaming Debugger widget."
local PLUGIN_ICON  = "rbxassetid://5313525223"

local WIDGET_ID = "StreamingDebuggerGui"
local WIDGET_INFO  = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, false)

local IS_EDIT = RunService:IsEdit()
local IS_SERVER = RunService:IsServer()

local REAL_MEMORY_LIMIT = NetworkSettings.EmulatedTotalMemoryInMB

--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Interface
--------------------------------------------------------------------------------------------------------------------------------------------------------------

if plugin.Name:find(".rbxm") then
	WIDGET_ID = WIDGET_ID .. "_Local"
	PLUGIN_TITLE = PLUGIN_TITLE .. " (LOCAL)"
end

if PluginGuiService:FindFirstChild(WIDGET_ID) then
	PluginGuiService[WIDGET_ID]:Destroy()
end

local ui = script.UI
local input = ui.Input
local errorLbl = ui.Error
local background = ui.Background
local themeConfig = require(script.ThemeConfig)

if not _G.Toolbar2032622 then
	_G.Toolbar2032622 = plugin:CreateToolbar("CloneTrooper1019")
end

local button = _G.StreamingDebuggerButton
local memoryLimit

if not button then
	button = _G.Toolbar2032622:CreateButton(PLUGIN_TITLE, PLUGIN_DESC, PLUGIN_ICON)
	_G.StreamingDebuggerButton = button
end

local pluginGui = plugin:CreateDockWidgetPluginGui(WIDGET_ID, WIDGET_INFO)
pluginGui.Title = PLUGIN_TITLE
pluginGui.Name = WIDGET_ID
ui.Parent = pluginGui

--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Functions
--------------------------------------------------------------------------------------------------------------------------------------------------------------

local function onThemeChanged()
	local theme = Studio.Theme

	for name, config in pairs(themeConfig) do
		local element = ui:FindFirstChild(name)

		if element then
			for prop, guideColor in pairs(config) do
				element[prop] = theme:GetColor(guideColor)
			end
		end
	end
end

local function onEnabledChanged()
	button:SetActive(pluginGui.Enabled)
end

local function onButtonClick()
	pluginGui.Enabled = not pluginGui.Enabled
end

local function canApplyLimit()
	if not workspace.StreamingEnabled then
		return false, "Streaming is not enabled!"
	end

	if IS_EDIT then
		return false, "Game must be running!"
	end

	if IS_SERVER then
		return false, "Server perspective not available."
	end

	if not memoryLimit then
		return false
	end

	if not pluginGui.Enabled then
		return false
	end

	return true
end

local function update()
	local canLimit, errorMsg = canApplyLimit()
	local canApply = not (IS_EDIT or IS_SERVER)

	if errorMsg then
		background.ZIndex = 3
		errorLbl.ZIndex = 4

		errorLbl.Text = errorMsg
		errorLbl.Visible = true
	else
		background.ZIndex = 1
		errorLbl.Visible = false
	end

	if canApply then
		if canLimit then
			NetworkSettings.EmulatedTotalMemoryInMB = memoryLimit
		else
			NetworkSettings.EmulatedTotalMemoryInMB = REAL_MEMORY_LIMIT
		end

		if RunService:IsRunning() then
			NetworkSettings.RenderStreamedRegions = pluginGui.Enabled
		end
	end
end

local function onFocusLost()
	local limit = tonumber(input.Text:match("%d+"))

	if limit and limit > 0 then
		memoryLimit = limit
	else
		memoryLimit = nil
		input.Text = ""
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Connections
--------------------------------------------------------------------------------------------------------------------------------------------------------------

local pluginGuiEnabled = pluginGui:GetPropertyChangedSignal("Enabled")
pluginGuiEnabled:Connect(onEnabledChanged)

onEnabledChanged()
onThemeChanged()

Studio.ThemeChanged:Connect(onThemeChanged)
RunService.RenderStepped:Connect(update)

input.FocusLost:Connect(onFocusLost)
button.Click:Connect(onButtonClick)

--------------------------------------------------------------------------------------------------------------------------------------------------------------
