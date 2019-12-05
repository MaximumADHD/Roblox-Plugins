------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @ CloneTrooper1019, 2019
-- main.server.lua
------------------------------------------------------------------------------------------------------------------------------------------------------------
-- This is the main script for this fork of the terrain importer.
-- It mounts the importer widget into a PluginGui with a button to toggle it.
------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------------------------------------------------------------------------------------

local project = script.Parent
local terrainImporter = require(project.TerrainImporter)

local toolbar = plugin:CreateToolbar("Terrain")
local importButton = toolbar:CreateButton(
	"Import Terrain",
	"Create terrain heightmaps using PNG files!",
	"rbxasset://textures/TerrainTools/mt_terrain_import.png"
)

local dockWidgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 0, 0, 289)

local pluginGui = plugin:CreateDockWidgetPluginGui("TerrainImporter", dockWidgetInfo)
pluginGui.Title = "Terrain Importer"
pluginGui.Name = pluginGui.Title

local content = Instance.new("ScrollingFrame")
content.BorderSizePixel = 0
content.ScrollBarThickness = 17
content.Size = UDim2.new(1, 0, 1, 0)
content.CanvasSize = UDim2.new(1, 0, 0, 466)
content.ElasticBehavior = Enum.ElasticBehavior.Never
content.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
content.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
content.MidImage = "rbxasset://textures/TerrainTools/EdgesSquare17x1.png"
content.TopImage = "rbxasset://textures/TerrainTools/UpArrowButtonOpen17.png"
content.BottomImage = "rbxasset://textures/TerrainTools/DownArrowButtonOpen17.png"
content.Parent = pluginGui

terrainImporter:Setup(pluginGui, content)

------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Update Listeners
------------------------------------------------------------------------------------------------------------------------------------------------------------

local Studio = settings():GetService("Studio")
local enabledChanged = pluginGui:GetPropertyChangedSignal("Enabled")

local function onThemeChanged()
	local theme = Studio.Theme
	content.BackgroundColor3 = theme:GetColor("MainBackground")
end

local function onEnabledChanged()
	local enabled = pluginGui.Enabled
	terrainImporter:SetEnabled(enabled)
	importButton:SetActive(enabled)
end

local function onClicked()
	pluginGui.Enabled = not pluginGui.Enabled
end

onThemeChanged()
Studio.ThemeChanged:Connect(onThemeChanged)

onEnabledChanged()
enabledChanged:Connect(onEnabledChanged)

importButton.Click:Connect(onClicked)

------------------------------------------------------------------------------------------------------------------------------------------------------------