----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @ MaximumADHD, 2016-2023
--   Mesh Optimization Tools
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local CoreGui = game:GetService("CoreGui")

local Studio = settings().Studio
local PhysicsSettings = settings().Physics

local PLUGIN_PATCH_TITLE   = "Mesh Patcher"
local PLUGIN_PATCH_SUMMARY = "Allows you to apply certain properties of each MeshPart in the Workspace with a select MeshId."
local PLUGIN_PATCH_ICON    = "rbxassetid://6284437024"

local PLUGIN_TOOLBAR = "Mesh Optimization Tools"

if plugin.Name:find(".rbxm") then
	PLUGIN_TOOLBAR ..= " (LOCAL)"
end

local toolbar = plugin:CreateToolbar(PLUGIN_TOOLBAR)

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Show Decomposition Geometry
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local decompOn = PhysicsSettings.ShowDecompositionGeometry
local updateSignal = PhysicsSettings:GetPropertyChangedSignal("ShowDecompositionGeometry")

local decompButton = toolbar:CreateButton(
	"Show Decomposition Geometry",
	"Toggles the visibility of Decomposition Geometry for TriangleMeshParts.",
	"rbxassetid://414888901"
)

local function onDecompClick()
	PhysicsSettings.ShowDecompositionGeometry = not PhysicsSettings.ShowDecompositionGeometry
end

local function updateGeometry(init: boolean?)
	decompOn = PhysicsSettings.ShowDecompositionGeometry
	decompButton:SetActive(decompOn)
	
	if not init then
		for _, desc in pairs(workspace:GetDescendants()) do
			if desc:IsA("TriangleMeshPart") then
				local t = desc.LocalTransparencyModifier
				desc.LocalTransparencyModifier = t + .01
				desc.LocalTransparencyModifier = t
			end
		end
	end
end

updateGeometry(true)
updateSignal:Connect(updateGeometry)
decompButton.Click:Connect(onDecompClick)

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Transparent Boxes
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local boxButton = toolbar:CreateButton(
	"Transparent Boxes",
	"Renders nearby TriangleMeshParts (which have their CollisionFidelity set to 'Box') as mostly-transparent boxes.", 
	"rbxassetid://5523395476"
)

local boxBin
local boxOn = false

local boxes = {}
local boxThread

-- Capture regardless of CanQuery
local overlap = OverlapParams.new();
(overlap :: any).BruteForceAllSlow = true

local function createBox(part: BasePart)
	if boxes[part] then
		return boxes[part]
	end

	local sizeListener = part:GetPropertyChangedSignal("Size")
	boxBin = boxBin or CoreGui:FindFirstChild("CollisionProxies")

	if not boxBin then
		boxBin = Instance.new("Folder")
		boxBin.Name = "CollisionProxies"
		boxBin.Parent = CoreGui
	end
	
	local box = Instance.new("BoxHandleAdornment")
	box.Color3 = BrickColor.random().Color
	box.Transparency = 0.875
	box.Size = part.Size
	box.Adornee = part
	box.Parent = boxBin
	
	local signal = sizeListener:Connect(function ()
		box.Size = part.Size
	end)

	local data = {
		Adorn = box,
		Signal = signal,
		LastUpdate = 0,
	}
	
	boxes[part] = data
	part.LocalTransparencyModifier = 1
	
	return data
end

local function destroyBox(part)
	local box = boxes[part]
	
	if box then
		box.Adorn:Destroy()
		box.Signal:Disconnect()
	end
	
	boxes[part] = nil
	part.LocalTransparencyModifier = 0
end

local function updateBoxes()
	local now = os.clock()
	local camera = assert(workspace.CurrentCamera)

	local pos = camera.CFrame.Position
	local parts = workspace:GetPartBoundsInRadius(pos, 400, overlap)

	for i, part in pairs(parts) do
		if part:IsA("TriangleMeshPart") then
			local collision = part.CollisionFidelity.Name

			if collision == "Box" then
				local box = createBox(part)
				box.LastUpdate = now
			end
		end
	end
	
	for part, box in boxes do
		if box.LastUpdate ~= now then
			destroyBox(part)
		end
	end
end

local function clearBoxes()
	while true do
		local part = next(boxes)

		if part then
			destroyBox(part)
		else
			break
		end
	end
	
	if boxBin then
		boxBin:Destroy()
		boxBin = nil
	end

	if boxThread then
		task.cancel(boxThread)
	end
end

local function onBoxClick()
	boxOn = not boxOn
	boxButton:SetActive(boxOn)
	
	if boxOn then
		boxThread = task.spawn(function ()
			while boxOn do
				updateBoxes()
				task.wait(1)
			end
		end)
	else
		clearBoxes()
	end
end

boxButton.Click:Connect(onBoxClick)

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Mesh Patcher
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ui = script.UI
local patch = ui.Patch

local meshId = ui.MeshId
local otherTypes = ui.Other

local collisionTypes = ui.Collision
local renderingTypes = ui.Rendering

local input = meshId.Input
local autoCheck = meshId.AutoSet

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Left,
	false,  -- Widget will be initially disabled
	true,   -- Override the previous enabled state
	250,    -- Default width of the floating window
	500     -- Default height of the floating window
)

local guiGuid = "MeshPatcher"
local themes = require(script.Themes)

if plugin.Name:find(".rbxm") then
	guiGuid ..= " (LOCAL)"
end  

local pluginGui = plugin:CreateDockWidgetPluginGui(guiGuid, widgetInfo)
pluginGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pluginGui.Title = "Mesh Patcher"
pluginGui.Name = guiGuid

local patcherButton = toolbar:CreateButton(PLUGIN_PATCH_TITLE, PLUGIN_PATCH_SUMMARY, PLUGIN_PATCH_ICON)
local enabledChanged = pluginGui:GetPropertyChangedSignal("Enabled")
local autoSet = true

local props = {}
local setters = {}

local function onPatcherButtonClick()
	pluginGui.Enabled = not pluginGui.Enabled
end

local function onEnabledChanged()
	patcherButton:SetActive(pluginGui.Enabled)
end

local function applyList(element: GuiObject)
	local list = element:FindFirstChildWhichIsA("UIListLayout")

	if list then
		local size = list.AbsoluteContentSize
		
		if element:IsA("ScrollingFrame") then
			element.CanvasSize = UDim2.new(0, 0, 0, size.Y + 50)
		else
			element.Size = UDim2.new(1, 0, 0, size.Y)
		end
	end
end

local function applyTheme()
	local theme = Studio.Theme

	for _,element in pairs(pluginGui:GetDescendants()) do
		local themeType = element:GetAttribute("Theme")
		local config = themes[themeType]

		if not config then
			continue
		end
		
		for prop, style in pairs(config) do
			local color = theme:GetColor(style);
			(element :: any)[prop] = color
		end
	end
end

local function registerCheckBox(button: TextButton, title: string, init: boolean, callback: (boolean, string, string?) -> (), group: string?)
	local checked

	local function setChecked(value)
		if typeof(value) ~= "boolean" then
			value = (not not value)
		end

		if checked == value then
			return
		end

		checked = value
		button.Text = `{checked and '☑' or '☐'} {title}`
		
		if callback then
			callback(value, title, group)
		end
	end

	local function onActivated()
		setChecked(not checked)
	end
	
	setChecked(init)
	setters[title] = setChecked
	button.Activated:Connect(onActivated)
end

local function registerCheckBoxes(bin, ...)
	for _, check in pairs(bin:GetChildren()) do
		if check:IsA("TextButton") then
			registerCheckBox(check, check.Name, ...)
		end
	end
end

local function onMultiToggle(checked, propName)
	props[propName] = checked
end

local function onSingleToggle(checked, newValue, prop)
	if checked then
		local oldValue = props[prop]
		local setOld = setters[oldValue]
		
		if setOld then
			setOld(false)
		end
		
		props[prop] = newValue
	else
		props[prop] = nil
	end
end

local function onSelectionChanged()
	if not autoSet then
		return
	end

	if not pluginGui.Enabled then
		return
	end

	local selected = Selection:Get()
	local target

	for i = #selected, 1, -1 do
		local object = selected[i]

		if object:IsA("MeshPart") then
			target = object
			break
		end
	end

	if not target then
		return
	end

	local meshId = target.MeshId
	input.Text = meshId

	local rendering = target.RenderFidelity.Name
	setters[rendering](true)
	
	local collision = target.CollisionFidelity.Name
	setters[collision](true)
	
	for prop, set in pairs(props) do
		local value = target[prop]
		local valueType = typeof(value)
		
		if valueType == "boolean" then
			setters[prop](value)
		end
	end
end

local function onPatch()
	local targetId = input.Text

	if targetId:gsub(" ", "") == "" then
		warn("No Target MeshId provided?")
		return
	end

	local targets = {}

	for _,desc in pairs(workspace:GetDescendants()) do
		if desc:IsA("MeshPart") and desc.MeshId == targetId then
			targets[desc] = true
		end
	end
	
	if not next(targets) then
		warn("No MeshParts found with Target MeshId:", targetId)
		return
	end
	
	ChangeHistoryService:SetWaypoint("Before Mesh Patch")

	for meshPart in pairs(targets) do
		for prop, value in pairs(props) do
			meshPart[prop] = value
		end
	end

	ChangeHistoryService:SetWaypoint("After Mesh Patch")
end

ui.Parent = pluginGui

for _,frame in pairs(ui:GetChildren()) do
	if frame:IsA("Frame") then
		applyList(frame)
	end
end

applyTheme()
applyList(ui)

registerCheckBox(autoCheck, "Auto-set from selected MeshPart?", true, function (checked)
	autoSet = checked

	if autoSet then
		onSelectionChanged()
	end
end)

registerCheckBoxes(collisionTypes, false, onSingleToggle, "CollisionFidelity")
registerCheckBoxes(renderingTypes, false, onSingleToggle, "RenderFidelity")
registerCheckBoxes(otherTypes, true,  onMultiToggle, "Other")

patch.Activated:Connect(onPatch)
Studio.ThemeChanged:Connect(applyTheme)
enabledChanged:Connect(onEnabledChanged)
patcherButton.Click:Connect(onPatcherButtonClick)
Selection.SelectionChanged:Connect(onSelectionChanged)

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
