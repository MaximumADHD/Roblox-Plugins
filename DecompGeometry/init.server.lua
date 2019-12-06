----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @ CloneTrooper1019, 2016-2019
--   Decomposition Geometry Plugin
--   Allows you to toggle the Decomposition Geometry 
--   of TriangleMeshParts
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PhysicsSettings = settings():GetService("PhysicsSettings")

local PLUGIN_TITLE  = "Show Decomposition Geometry"
local PLUGIN_SUMMARY = "Toggles decomposition geometry for parts with collision fidelity options."
local PLUGIN_ICON    = "rbxassetid://414888901"

local toolbar = plugin:CreateToolbar("Physics")
local button = toolbar:CreateButton(PLUGIN_TITLE, PLUGIN_SUMMARY, PLUGIN_ICON)

local on = PhysicsSettings.ShowDecompositionGeometry
local updateSignal = PhysicsSettings:GetPropertyChangedSignal("ShowDecompositionGeometry")

local function onClick()
	PhysicsSettings.ShowDecompositionGeometry = not PhysicsSettings.ShowDecompositionGeometry
end

local function updateGeometry(init)
	on = PhysicsSettings.ShowDecompositionGeometry
	button:SetActive(on)
	
	if not init then
		for _,desc in pairs(workspace:GetDescendants()) do
			if desc:IsA("TriangleMeshPart") then
				-- Bump the transparency of the part.
				-- This will invalidate its geometry.
				local t = desc.Transparency
				desc.Transparency = 1 - t
				desc.Transparency = t
			end
		end
	end
end

updateSignal:Connect(updateGeometry)
button.Click:Connect(onClick)

updateGeometry(true)

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------