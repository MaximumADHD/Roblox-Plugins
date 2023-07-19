--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @ MaximumADHD, 2018-2022
--   Quick Insert Plugin
--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------------------------------------------------------------------------------------
--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local MarketplaceService = game:GetService("MarketplaceService")
local PluginGuiService = game:GetService("PluginGuiService")
local InsertService = game:GetService("InsertService")
local AssetService = game:GetService("AssetService")
local Selection = game:GetService("Selection")
local Players = game:GetService("Players")
local Studio = settings().Studio

local PLUGIN_TITLE = "Quick Insert"
local PLUGIN_DESC  = "Toggles the Quick Insert widget, which lets you paste any assetid and insert an asset."
local PLUGIN_ICON  = "rbxassetid://425778638"

local WIDGET_ID = "QuickInsertGui"
local WIDGET_INFO = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, false)

local ASSET_ID_MATCHES = {
	"^(%d+)$",
	-- CDN asset links
	"^rbxassetid://(%d+)",
	"^%w*%.?roblox%.com%.?/asset/%?id=(%d+)",
	-- Website asset links
	"^%w*%.?roblox%.com%.?/library/(%d+)",
	"^%w*%.?roblox%.com%.?/catalog/(%d+)",
	"^%w*%.?roblox%.com%.?/[%w_%-]+%-item%?[&=%w%-_%%%+]*id=(%d+)",
	"^%w*%.?roblox%.com%.?/[Mm]y/[Ii]tem%.aspx%?[&=%w%-_%%%+]*[Ii][Dd]=(%d+)",
	"^create%.roblox%.com%.?/dashboard/creations/catalog/(%d+)",
	"^create%.roblox%.com%.?/dashboard/creations/marketplace/(%d+)",
	"^create%.roblox%.com%.?/marketplace/asset/(%d+)",
	"^%w*%.?roblox%.com%.?/plugins/(%d+)",
}

--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Interface
--------------------------------------------------------------------------------------------------------------------------------------------------------------

if plugin.Name:find(".rbxm") then
	WIDGET_ID ..= "_Local"
	PLUGIN_TITLE ..= " (LOCAL)"
end

local old = PluginGuiService:FindFirstChild(WIDGET_ID)

if old then
	old:Destroy()
end

local ui = script.UI
local input = ui.Input
local errorLbl = ui.Error

local modules = script.Modules
local assetMap = require(modules.AssetMap)
local themeConfig = require(modules.ThemeConfig)


local toolbar: PluginToolbar do
	if not _G.Toolbar2032622 then
		_G.Toolbar2032622 = plugin:CreateToolbar("MaximumADHD")
	end

	toolbar = _G.Toolbar2032622
end

local button: PluginToolbarButton = toolbar:CreateButton(PLUGIN_TITLE, PLUGIN_DESC, PLUGIN_ICON)
local pluginGui = plugin:CreateDockWidgetPluginGui(WIDGET_ID, WIDGET_INFO)

pluginGui.Title = PLUGIN_TITLE
pluginGui.Name = WIDGET_ID

ui.Parent = pluginGui

--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Functions
--------------------------------------------------------------------------------------------------------------------------------------------------------------

-- UTF-8 BOMs were the worst invention ever
local function stripBom(str: string): string
	return string.gsub(string.gsub(str, "^\226\129\160", ""), "^\239\187\191", "")
end

local function sanitiseLink(link: string): string
	return string.gsub(string.match(stripBom(link) :: string, "^%s*(.-)%s*$") :: string, "^https?://", "")
end

local function getIdFromLink(link: string): number?
	link = sanitiseLink(link)

	for _, v in ipairs(ASSET_ID_MATCHES) do
		local assetId = tonumber(string.match(link, v) :: string)

		if assetId then
			return assetId
		end
	end

	return nil
end

local function onThemeChanged()
	local theme: StudioTheme = Studio.Theme
	
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
	task.wait(2)
	
	if errorLbl.Text == text then
		errorLbl.Text = ""
	end
end

local function isHeadAsset(assetType: Enum.AssetType)
	return assetType.Name:sub(-4) == "Head"
end

local function isAccessoryAsset(assetType: Enum.AssetType)
	return assetType.Name:sub(-9) == "Accessory"
end


local function isImageAsset(assetType: Enum.AssetType)
	return assetType.Name:sub(-5) == "Image"
end

local function isAudioAsset(assetType: Enum.AssetType)
	return assetType.Name:sub(-5) == "Audio"
end

local function onFocusLost(enterPressed)
	if enterPressed then
		local success, errorMsg = pcall(function ()
			local assetId = getIdFromLink(input.Text)
			ChangeHistoryService:SetWaypoint("Insert")
			
			if not (assetId and assetId > 770) then
				error("Invalid AssetId!", 2)
			end

			local info = MarketplaceService:GetProductInfo(assert(assetId))
			local assetType = assetMap[info.AssetTypeId]

			local isHead = isHeadAsset(assetType)
			local isAccessory = isAccessoryAsset(assetType)
			
			local success, errorMsg = pcall(function()
				local everything: {Instance} = {}

				if isHead or isAccessory then
					local asset: Instance
					local hDesc = Instance.new("HumanoidDescription")
					
					if isHead then
						hDesc.Head = assetId
					elseif isAccessory then
						hDesc.HatAccessory = tostring(assetId)
					end

					local dummy = Players:CreateHumanoidModelFromDescription(hDesc, Enum.HumanoidRigType.R15)
					asset = Instance.new("Folder")

					if isHead then
						local head = dummy:FindFirstChild("Head")

						if head and head:IsA("BasePart") then
							head.BrickColor = BrickColor.Gray()
							head.Parent = asset
						end
					elseif isAccessory then
						local accessory = dummy:FindFirstChildWhichIsA("Accoutrement", true)

						if accessory then
							accessory.Parent = asset
						end
					end
					
					for _, desc in asset:GetDescendants() do
						if desc:IsA("Vector3Value") then
							local parent = desc.Parent

							if parent and desc.Name:sub(1, 8) == "Original" then
								if parent:IsA("Attachment") then
									parent.Position = desc.Value
								elseif parent:IsA("BasePart") then
									parent.Size = desc.Value
								end
							end
						end
					end

					everything = asset:GetChildren()
				elseif isImageAsset(assetType) then
					local decal = Instance.new("Decal")

					decal.Name = tostring(info.Name)
					decal.Texture = "rbxassetid://"..tostring(assetId)

					table.insert(everything, decal)
				elseif isAudioAsset(assetType) then
					local sound = Instance.new("Sound")

					sound.Name = tostring(info.Name)
					sound.SoundId = "rbxassetid://"..tostring(assetId)

					table.insert(everything, sound)
				else
					everything = game:GetObjects("rbxassetid://"..tostring(assetId))
				end

				for _, item in everything do
					item.Parent = workspace
				end

				Selection:Set(everything)
			end)
			
			if not success then
				setError(errorMsg)
			end
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
