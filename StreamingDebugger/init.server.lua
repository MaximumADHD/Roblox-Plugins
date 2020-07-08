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
local PLUGIN_ICON  = "rbxassetid://5313153339"

local WIDGET_ID = "StreamingDebuggerGui"
local WIDGET_INFO  = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, false)

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

local toolbar = plugin:CreateToolbar("CloneTrooper1019")
local button = toolbar:CreateButton(PLUGIN_TITLE, PLUGIN_DESC, PLUGIN_ICON)

local pluginGui = plugin:CreateDockWidgetPluginGui(WIDGET_ID, WIDGET_INFO)
pluginGui.Title = PLUGIN_TITLE
pluginGui.Name = WIDGET_ID

local memoryLimit
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

local function setError(e)
	if e then
		background.ZIndex = 3
		errorLbl.ZIndex = 4
		
		errorLbl.Text = e
		errorLbl.Visible = true
	else
		background.ZIndex = 1
		errorLbl.Visible = false
	end
end

local function canApplyLimit()
	if not workspace.StreamingEnabled then
		return false, "Streaming is not enabled!"
	end

	if not RunService:IsRunning() then
		return false, "Game is not running!"
	end

	if RunService:IsServer() then
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
	local canApply, errorMsg = canApplyLimit()

	if canApply then
		local available = NetworkSettings.FreeMemoryMBytes
		
		if errorLbl.Visible then
			setError(nil)
		end
		
		NetworkSettings.ExtraMemoryUsed = available - memoryLimit
	else
		setError(errorMsg)
		
		if not RunService:IsServer() then
			NetworkSettings.ExtraMemoryUsed = 0
		end
	end
	
	if RunService:IsRunning() and not RunService:IsServer() then
		NetworkSettings.RenderStreamedRegions = pluginGui.Enabled
	end
end

local function onFocusLost(enterPressed)
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
RunService.Heartbeat:Connect(update)

input.FocusLost:Connect(onFocusLost)
button.Click:Connect(onButtonClick)

--------------------------------------------------------------------------------------------------------------------------------------------------------------