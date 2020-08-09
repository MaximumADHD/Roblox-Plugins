----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @ CloneTrooper1019, 2016-2020
--   Decomposition Geometry Plugin
--   Allows you to toggle the Decomposition Geometry 
--   of TriangleMeshParts
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PhysicsSettings = settings():GetService("PhysicsSettings")
local CoreGui = game:GetService("CoreGui")

local PLUGIN_DECOMP_TITLE   = "Show Decomposition Geometry"
local PLUGIN_DECOMP_SUMMARY = "Toggles the visibility of Decomposition Geometry for TriangleMeshParts."
local PLUGIN_DECOMP_ICON    = "rbxassetid://414888901"

local PLUGIN_BOX_TITLE   = "Transparent Boxes"
local PLUGIN_BOX_SUMMARY = "Renders nearby TriangleMeshParts (which have their CollisionFidelity set to 'Box') as mostly-transparent boxes."
local PLUGIN_BOX_ICON    = "rbxassetid://5523395476"

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