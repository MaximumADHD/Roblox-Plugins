----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @ CloneTrooper1019, 2016-2020
--   Decomposition Geometry Plugin
--   Allows you to toggle the Decomposition Geometry 
--   of TriangleMeshParts
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local PhysicsSettings = settings():GetService("PhysicsSettings")
local Selection = game:GetService("Selection")
local CoreGui = game:GetService("CoreGui")

local PLUGIN_DECOMP_TITLE   = "Show Decomposition Geometry"
local PLUGIN_DECOMP_SUMMARY = "Toggles the visibility of Decomposition Geometry for TriangleMeshParts."
local PLUGIN_DECOMP_ICON    = "rbxassetid://414888901"

local PLUGIN_BOX_TITLE   = "Transparent Boxes"
local PLUGIN_BOX_SUMMARY = "Renders nearby TriangleMeshParts (which have their CollisionFidelity set to 'Box') as mostly-transparent boxes."
local PLUGIN_BOX_ICON    = "rbxassetid://5523395476"

local PLUGIN_PATCH_TITLE   = "Mesh Patcher"
local PLUGIN_PATCH_SUMMARY = "Allows you to apply certain properties of each MeshPart in the Workspace with a select MeshId."
local PLUGIN_PATCH_ICON    = "rbxassetid://6284437024"

local PLUGIN_TOOLBAR = "Physics"

if plugin.Name:find(".rbxm") then
	PLUGIN_TOOLBAR ..= " (LOCAL)"
end

local toolbar = plugin:CreateToolbar(PLUGIN_TOOLBAR)

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Show Decomposition Geometry
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local decompOn = PhysicsSettings.ShowDecompositionGeometry

local updateSignal = PhysicsSettings:GetPropertyChangedSignal("ShowDecompositionGeometry")
local decompButton = toolbar:CreateButton(PLUGIN_DECOMP_TITLE, PLUGIN_DECOMP_SUMMARY, PLUGIN_DECOMP_ICON)

local function onDecompClick()
	PhysicsSettings.ShowDecompositionGeometry = not PhysicsSettings.ShowDecompositionGeometry
end

local function updateGeometry(init)
	decompOn = PhysicsSettings.ShowDecompositionGeometry
	decompButton:SetActive(decompOn)
	
	if not init then
		for _,desc in pairs(workspace:GetDescendants()) do
			if desc:IsA("TriangleMeshPart") then
				local t = desc.Transparency
				desc.Transparency = t + .01
				desc.Transparency = t
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

local boxButton = toolbar:CreateButton(PLUGIN_BOX_TITLE, PLUGIN_BOX_SUMMARY, PLUGIN_BOX_ICON)
local boxArea = Vector3.new(200, 200, 200)
local boxBin

local boxOn = false
local boxes = {}

local function createBox(part)
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
	box.Color = BrickColor.random()
	box.Transparency = 0.875
	box.Size = part.Size
	box.Adornee = part
	box.Parent = boxBin
	
	local signal = sizeListener:Connect(function ()
		box.Size = part.Size
	end)

	local data =
	{
		Adorn = box;
		Signal = signal;
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
	local now = tick()
	
	local camera = workspace.CurrentCamera
	local pos = camera.CFrame.Position

	local a0 = pos - boxArea
	local a1 = pos + boxArea
	
	local region = Region3.new(a0, a1)
	local parts = workspace:FindPartsInRegion3(region, nil, math.huge)

	for _,part in pairs(parts) do
		if part:IsA("TriangleMeshPart") then
			local collision = part.CollisionFidelity.Name

			if collision == "Box" then
				local box = createBox(part)
				box.LastUpdate = now
			end
		end
	end
	
	for part, box in pairs(boxes) do
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
end

local function onBoxClick()
	boxOn = not boxOn
	boxButton:SetActive(boxOn)
	
	if boxOn then
		while boxOn do
			updateBoxes()
			wait(1)
		end
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

local other = ui.Other
local meshId = ui.MeshId
local collisonTypes = ui.Collision

local input = meshId.Input
local autoCheck = meshId.AutoSet

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Left,
	false,  -- Widget will be initially disabled
	true,   -- Override the previous enabled state
	250,    -- Default width of the floating window
	500     -- Default height of the floating window
)

local pluginGui = plugin:CreateDockWidgetPluginGui("MeshPatcher", widgetInfo)
pluginGui.ZIndexBehavior = "Sibling"
pluginGui.Title = "Mesh Patcher"

local patcherButton = toolbar:CreateButton(PLUGIN_PATCH_TITLE, PLUGIN_PATCH_SUMMARY, PLUGIN_PATCH_ICON)
local enabledChanged = pluginGui:GetPropertyChangedSignal("Enabled")

local collision = nil
local autoSet = false

local otherProps = {}
local setters = {}

local function onPatcherButtonClick()
	pluginGui.Enabled = not pluginGui.Enabled
end

local function onEnabledChanged()
	patcherButton:SetActive(pluginGui.Enabled)
end

local function registerCheckBox(button, title, init, callback)
	local checked

	local function setChecked(value)
		if typeof(value) ~= "boolean" then
			value = (not not value)
		end
		
		if checked == value then
			return
		else
			checked = value
		end

		if checked then
			button.Text = "☑ " .. title
		else
			button.Text = "☐ " .. title
		end

		if callback then
			callback(value, title)
		end
	end

	local function onActivated()
		setChecked(not checked)
	end
	
	setChecked(init)
	setters[title] = setChecked
	button.Activated:Connect(onActivated)
end

local function onCollisionChecked(checked, target)
	if checked then
		local setOld = setters[collision]
		
		if setOld then
			setOld(false)
		end

		collision = target
	elseif collision == target then
		collision = nil
	end
end

local function onOtherChecked(value, title)
	otherProps[title] = value
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

	if collision == nil then
		local setCollision = target.CollisionFidelity.Name
		onCollisionChecked(true, setCollision)
	end

	for prop in pairs(otherProps) do
		local value = target[prop]
		onOtherChecked(value, prop)
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
		if collision then
			meshPart.CollisionFidelity = collision
		end

		for prop, value in pairs(otherProps) do
			meshPart[prop] = value
		end
	end

	ChangeHistoryService:SetWaypoint("After Mesh Patch")
end

for _,check in pairs(collisonTypes:GetChildren()) do
	if check:IsA("TextButton") then
		registerCheckBox(check, check.Name, false, onCollisionChecked)
	end
end

for _,check in pairs(other:GetChildren()) do
	if check:IsA("TextButton") then
		registerCheckBox(check, check.Name, true, onOtherChecked)
	end
end

registerCheckBox(autoCheck, "Auto-set from selected MeshPart?", false, function (checked)
	autoSet = checked

	if autoSet then
		onSelectionChanged()
	end
end)

ui.Parent = pluginGui
patch.Activated:Connect(onPatch)
enabledChanged:Connect(onEnabledChanged)
patcherButton.Click:Connect(onPatcherButtonClick)
Selection.SelectionChanged:Connect(onSelectionChanged)

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------