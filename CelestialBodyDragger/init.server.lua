---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @ MaximumADHD, 2017 - 2022
--   Celestial Body Dragger
--   A plugin that lets you drag 
--   the sun and moon around
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
--!strict

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local atan2 = math.atan2
local sqrt = math.sqrt
local tau = math.pi * 2

type CelestialBody = {
	Name: string,
	Button: PluginToolbarButton,
	LongitudeFactor: number,
}

type BodyConfig = {
	Name: string,
	IconId: number,
	LongitudeFactor: number,
}

local BASE_TITLE = "Drag %s"
local BASE_ASSET = "rbxassetid://%i"

local BASE_DESC  = "Click and drag to adjust the angle of the %s\n\n" ..
                   "(NOTE: Dragging one celesial body affects the angle of the other one)"

if plugin.Name:find(".rbxm") then
	BASE_TITLE ..= " (LOCAL)"
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Plugin Toggles
---------------------------------------------------------------------------------------------------------------------------------------------------------------------

local toolbar = plugin:CreateToolbar("Celestial Body Dragger")
local bodies = {} :: { CelestialBody }
local currBody: CelestialBody?

local function createBody(config: BodyConfig)
	local name = config.Name
	local desc = BASE_DESC:format(name)
	local title = BASE_TITLE:format(name)

	local lf = config.LongitudeFactor
	local icon = BASE_ASSET:format(config.IconId)
	local button = toolbar:CreateButton(title, desc, icon)

	local body: CelestialBody = {
		Name = name,
		Button = button,
		LongitudeFactor = lf,
	}

	button.Click:Connect(function()
		if currBody ~= body then
			button:SetActive(true)

			if currBody then
				currBody.Button:SetActive(false)
			else
				plugin:Activate(true)
			end

			currBody = body
		else
			button:SetActive(false)
			currBody = nil
			
			plugin:Deactivate()
		end
	end)

	table.insert(bodies, body)
end

createBody({
	Name = "Sun",
	IconId = 1458865781,
	LongitudeFactor = -1,
})

createBody({
	Name = "Moon",
	IconId = 1458866313,
	LongitudeFactor = 1,
})

---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Celestial Body Updater
---------------------------------------------------------------------------------------------------------------------------------------------------------------------

local setHistoryWaypoint = false

local function onDeactivation()
	for name, body in bodies do
		body.Button:SetActive(false)
	end
	
	currBody = nil
end

local function updateCelesialBodies()
	if currBody and plugin:IsActivatedWithExclusiveMouse() then
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			if not setHistoryWaypoint then
				setHistoryWaypoint = true
				ChangeHistoryService:SetWaypoint(currBody.Name .. " Drag Begin")
			end

			local mouse = plugin:GetMouse()
			local dir = mouse.UnitRay.Direction

			local lf = currBody.LongitudeFactor
			local lon = atan2(dir.Y * lf, dir.X * lf)
			local lat = atan2(dir.Z, sqrt(dir.X^2 + dir.Y^2))
			
			Lighting.ClockTime = ((lon / tau) * 24 - 6) % 24
			Lighting.GeographicLatitude = (lat / tau) * 360 + 23.5
		else
			setHistoryWaypoint = false
			ChangeHistoryService:SetWaypoint(currBody.Name .. " Drag End")
		end
	else
		onDeactivation()
	end
end

plugin.Deactivation:Connect(onDeactivation)
RunService:BindToRenderStep("CelesialBodyUpdate", 201, updateCelesialBodies)

---------------------------------------------------------------------------------------------------------------------------------------------------------------------