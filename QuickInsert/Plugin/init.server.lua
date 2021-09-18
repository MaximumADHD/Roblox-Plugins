--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @ CloneTrooper1019, 2018-2019
--   Quick Insert Plugin
--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------------------------------------------------------------------------------------

local AssetService = game:GetService("AssetService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local PluginGuiService = game:GetService("PluginGuiService")
local InsertService = game:GetService("InsertService")
local Selection = game:GetService("Selection") 
local Studio = settings():GetService("Studio")

local PLUGIN_TITLE = "Quick Insert"
local PLUGIN_DESC  = "Toggles the Quick Insert widget, which lets you paste any assetid and insert an asset."
local PLUGIN_ICON  = "rbxassetid://425778638"

local WIDGET_ID = "QuickInsertGui"
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

local modules = script.Modules
local assetNames = require(modules.AssetNames)
local themeConfig = require(modules.ThemeConfig)

if not _G.Toolbar2032622 then
	_G.Toolbar2032622 = plugin:CreateToolbar("CloneTrooper1019")
end

local button = _G.Toolbar2032622:CreateButton(PLUGIN_TITLE, PLUGIN_DESC, PLUGIN_ICON)

local pluginGui = plugin:CreateDockWidgetPluginGui(WIDGET_ID,WIDGET_INFO)
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

local function setError(e)
	errorLbl.Text = e
	warn(e)
end

local function onErrorTextChanged()
	local text = errorLbl.Text
	wait(2)
	
	if errorLbl.Text == text then
		errorLbl.Text = ""
	end
end

local function onFocusLost(enterPressed)
	if enterPressed then
		ChangeHistoryService:SetWaypoint("Insert")
		
		local success,errorMsg = pcall(function ()
			local baseAssetId = tonumber(input.Text:match("%d+"))
			
			if not (baseAssetId and baseAssetId > 770) then
				error("Invalid AssetId!", 2)
			end

			local info = MarketplaceService:GetProductInfo(baseAssetId)
			local assetIds
			
			if assetNames[info.AssetTypeId] == "Package" then
				assetIds = AssetService:GetAssetIdsForPackage(baseAssetId)
			else
				assetIds = { baseAssetId }
			end
		
			local everything = {}
			local hasMultiple = (#assetIds > 1)
			
			for _,assetId in pairs(assetIds) do
				local success, errorMsg = pcall(function ()
					local parent
					
					if hasMultiple then
						local assetInfo = MarketplaceService:GetProductInfo(assetId)
						local assetName = assetNames[assetInfo.AssetTypeId]
						
						parent = Instance.new("Folder")
						parent.Name = assetName
						parent.Parent = workspace
						
						table.insert(everything, parent)
					else
						parent = workspace
					end
					
					local asset = InsertService:LoadAsset(assetId)
					
					for _,item in pairs(asset:GetChildren()) do
						if not hasMultiple then
							table.insert(everything, item)
						end
						
						item.Parent = parent
					end
				end)
				
				if not success then
					setError(errorMsg)
				end
			end
			
			Selection:Set(everything)
		end)
		
		if success then
			ChangeHistoryService:SetWaypoint("Inserted")
		else
			setError(errorMsg)
		end
	end
	
	input.Text = ""
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Connections
--------------------------------------------------------------------------------------------------------------------------------------------------------------

local pluginGuiEnabled = pluginGui:GetPropertyChangedSignal("Enabled")
local errorTextChanged = errorLbl:GetPropertyChangedSignal("Text")

onEnabledChanged()
onThemeChanged()

pluginGuiEnabled:Connect(onEnabledChanged)
Studio.ThemeChanged:Connect(onThemeChanged)

errorTextChanged:Connect(onErrorTextChanged)
input.FocusLost:Connect(onFocusLost)

button.Click:Connect(onButtonClick)

--------------------------------------------------------------------------------------------------------------------------------------------------------------