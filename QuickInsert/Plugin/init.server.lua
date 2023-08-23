--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @ MaximumADHD, 2018-2023
--   Quick Insert Plugin
--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------------------------------------------------------------------------------------
--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local MarketplaceService = game:GetService("MarketplaceService")
local PluginGuiService = game:GetService("PluginGuiService")
local InsertService = game:GetService("InsertService")
local AssetService = game:GetService("AssetService")
local TweenService = game:GetService("TweenService")
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

local HACK_PAD = "     %s     "

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

local options = ui.Options
local template = options.Template

local btnTween = TweenInfo.new(0.2)
local activeOption: Option? = nil

local assetInfoCache = {}
local buttons = {} :: {
	[Option]: {
		Button: OptionButton,
		Placeholder: string,
	}
}

type OptionButton = typeof(template)
type Option = "Asset" | "Avatar" | "Bundle"

local modules = script.Modules
local assetMap = require(modules.AssetMap)
local themeConfig = require(modules.ThemeConfig)

local toolbar: PluginToolbar do
	if not _G.Toolbar2032622 then
		_G.Toolbar2032622 = plugin:CreateToolbar("MaximumADHD")
	end

	toolbar = _G.Toolbar2032622
end

local button: PluginToolbarButton = toolbar:CreateButton(PLUGIN_TITLE, PLUGIN_DESC, PLUGIN_ICON) :: any
local pluginGui = plugin:CreateDockWidgetPluginGui(WIDGET_ID, WIDGET_INFO)

pluginGui.Title = PLUGIN_TITLE
pluginGui.Name = WIDGET_ID

ui.Parent = pluginGui
template.Parent = nil

--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Functions
--------------------------------------------------------------------------------------------------------------------------------------------------------------

local function getProductInfo(assetid: number)
	local info = assetInfoCache[assetId] or MarketplaceService:GetProductInfo(assetId)

	if not assetInfoCache[assetId] then
		assetInfoCache[assetId] = info
	end

	return info
end

local function getIdFromLink(link: string): number?
	link = (link:match("^%s*(.-)%s*$") or ""):gsub("^https?://", "")

	for _, fragment in ipairs(ASSET_ID_MATCHES) do
		local match = link:match(fragment)
		local assetId = match and tonumber(match)

		if assetId then
			return assetId
		end
	end

	return nil
end

local function onThemeChanged()
	local theme: StudioTheme = Studio.Theme :: any
	
	for i, desc in ui:GetDescendants() do
		local config = themeConfig[desc.Name]

		if config then
			-- stylua: ignore
			local style = if desc:GetAttribute("IsActive")
				then Enum.StudioStyleGuideModifier.Default
				else Enum.StudioStyleGuideModifier.Disabled
			
			for prop, color in pairs(config) do
				desc[prop] = theme:GetColor(color, style)
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

local function setError(e: string)
	errorLbl.Text = e
	warn(e)
end

local function setOption(option: Option)
	if activeOption == option then
		return
	end

	local theme: StudioTheme = Studio.Theme :: any

	if activeOption then
		local oldConfig = buttons[activeOption]
		local oldButton = oldConfig.Button

		local oldProp = {
			BackgroundColor3 = theme:GetColor(
				Enum.StudioStyleGuideColor.DialogMainButton,
				Enum.StudioStyleGuideModifier.Disabled
			)
		}

		local oldTween = TweenService:Create(oldButton, btnTween, oldProp)
		oldButton:SetAttribute("IsActive", false)
		oldTween:Play()
	end

	local newConfig = buttons[option]
	local newButton = newConfig.Button

	local newProp = {
		BackgroundColor3 = theme:GetColor(
			Enum.StudioStyleGuideColor.DialogMainButton,
			Enum.StudioStyleGuideModifier.Default
		)
	}

	local newTween = TweenService:Create(newButton, btnTween, newProp)
	newTween:Play()

	newButton:SetAttribute("IsActive", true)
	input.PlaceholderText = newConfig.Placeholder

	activeOption = option
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

local function processAsset(assetId: number)
	local info = getProductInfo(assetId)
	local assetType = assetMap[info.AssetTypeId]

	local isHead = isHeadAsset(assetType)
	local isAccessory = isAccessoryAsset(assetType)
	local isImage = (assetType == Enum.AssetType.Image)
	local isAudio = (assetType == Enum.AssetType.Audio)
		
	if isHead or isAccessory then
		local hDesc = Instance.new("HumanoidDescription")
		
		if isHead then
			hDesc.Head = assetId
		elseif isAccessory then
			hDesc.HatAccessory = tostring(assetId)
		end

		local dummy = Players:CreateHumanoidModelFromDescription(hDesc, Enum.HumanoidRigType.R15)
		local asset: Instance = Instance.new("Folder")

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
		
		for i, desc in asset:GetDescendants() do
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

		return asset:GetChildren()
	elseif isImage or isAudio then
		local asset = isImage and Instance.new("Decal") or Instance.new("Sound")

		asset.Name = info.Name
		asset[isImage and "Texture" or "SoundId"] = "rbxassetid://"..assetId

		return {asset}
	else
		return game:GetObjects("rbxassetid://"..assetId)
	end
end

local function processBundle(id: number)
	local bundleInfo = AssetService:GetBundleDetailsAsync(id)
	local headDesc: HumanoidDescription?
	local bodyDesc: HumanoidDescription?
	
	for i, info in bundleInfo.Items do
		if info.Type == "UserOutfit" then
			local hDesc = Players:GetHumanoidDescriptionFromOutfitId(info.Id)
			local headId = hDesc.Head
			local limbs = 0
			
			for i, limb in Enum.BodyPart:GetEnumItems() do
				local limbId = hDesc[limb.Name]

				if limbId ~= 0 then
					limbs += 1
				end
			end

			if limbs == 1 and headId ~= 0 then
				headDesc = hDesc
			else
				bodyDesc = hDesc
			end
		end
	end
	
	local hDesc: HumanoidDescription? = bodyDesc or headDesc
	
	if hDesc then
		local camera = assert(workspace.CurrentCamera)

		local dummy = Players:CreateHumanoidModelFromDescription(hDesc, "R15")
		dummy:PivotTo(camera.Focus)

		return { dummy }
	end

	error("Couldn't find a UserOutfit in this bundle!")
end

local function onFocusLost(enterPressed: boolean)
	if enterPressed then
		local success, errorMsg = pcall(function ()
			local id = getIdFromLink(input.Text)
			assert(id, "Invalid id!")
			
			local camera = assert(workspace.CurrentCamera)
			ChangeHistoryService:SetWaypoint("Insert")
			
			local everything: {Instance}
			
			if activeOption == "Asset" then
				everything = processAsset(id)
			elseif activeOption == "Avatar" then
				local dummy = Players:CreateHumanoidModelFromUserId(id)
				dummy:PivotTo(camera.Focus)
				everything = { dummy }
			elseif activeOption == "Bundle" then
				everything = processBundle(id)
			end
			
			if everything then
				for i, inst in everything do
					inst.Parent = workspace
				end

				Selection:Set(everything)
			end
		end)
		
		if not success then
			setError(errorMsg)
		end
		
		if success then
			ChangeHistoryService:SetWaypoint("Inserted")
		else
			setError(errorMsg)
		end
	end
	
	input.Text = ""
end

local function createOption(option: Option, desc: string)
	local button = template:Clone()
	button.Text = HACK_PAD:format(option)
	button.Parent = options

	button.Activated:Connect(function ()
		setOption(option)
	end)

	buttons[option] = {
		Button = button,
		Placeholder = desc,
	}
end

createOption("Asset", "(Paste AssetId)")
createOption("Avatar", "(Paste UserId)")
createOption("Bundle", "(Paste BundleId)")

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
setOption("Asset")

--------------------------------------------------------------------------------------------------------------------------------------------------------------
