---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @ CloneTrooper1019, 2017 - 2019
--   Celestial Body Dragger
--   A plugin that lets you drag 
--   the sun and moon around
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local abs = math.abs
local atan2 = math.atan2
local modf = math.modf
local sqrt = math.sqrt
local rad = math.rad
local tau = math.pi * 2

---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Plugin Toggles
---------------------------------------------------------------------------------------------------------------------------------------------------------------------

local BASE_TITLE = "Drag %s"
local BASE_DESC  = "Click and drag to adjust the angle of the %s\n\n" ..
                   "(NOTE: Dragging one celesial body affects the angle of the other one)"

if plugin.Name:find(".rbxm") then
	BASE_TITLE = BASE_TITLE .. " (LOCAL)"
end
	
local toolbar = plugin:CreateToolbar("Celestial Body Dragger")
local activeBody = -1

local bodies = 
{
	{
		Name = "Sun";
		LongitudeFactor = -1;
		Icon = "rbxassetid://1458865781";
	},
	
	{
		Name = "Moon";
		LongitudeFactor = 1;
		Icon = "rbxassetid://1458866313";
	}
}

for i, body in ipairs(bodies) do
	local bodyName = body.Name
	local title = BASE_TITLE:format(bodyName)
	
	local desc = BASE_DESC:format(bodyName)
	local button = toolbar:CreateButton(title, desc, body.Icon)
	
	local function onClick()
		if activeBody ~= i then
			local prevBody = bodies[activeBody]
			
			if prevBody then
				prevBody.Button:SetActive(false)
				wait()
			end
			
			button:SetActive(true)
			activeBody = i
			
			plugin:Activate(true)
		else
			button:SetActive(false)
			activeBody = -1
			
			plugin:Deactivate()
		end
	end
	
	body.Button = button
	button.Click:Connect(onClick)
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Celestial Body Updater
---------------------------------------------------------------------------------------------------------------------------------------------------------------------

local setHistoryWaypoint = false

local function onDeactivation()
	for _,body in pairs(bodies) do
		local button = body.Button
		
		if button then
			button:SetActive(false)
		end
	end
	
	activeBody = -1
end

local function updateCelesialBodies()
	if activeBody < 1 then
		return
	end
	
	if plugin:IsActivatedWithExclusiveMouse() then
		local body = bodies[activeBody]
		local mouseDown = UserInputService:IsMouseButtonPressed("MouseButton1")
		
		if mouseDown then
			local pluginMouse = plugin:GetMouse()
			local dir = pluginMouse.UnitRay.Direction
			
			local lf = body.LongitudeFactor
			local lat = atan2(dir.Z, sqrt(dir.X^2 + dir.Y^2))
			local lon = atan2(dir.Y * lf, dir.X * lf)
			
			local geoLatitude = (lat / tau) * 360 + 23.5
			local clockTime = ((lon / tau) * 24 - 6) % 24
			
			if not setHistoryWaypoint then
				setHistoryWaypoint = true
				ChangeHistoryService:SetWaypoint(body.Name .. " Drag Begin")
			end
			
			Lighting.GeographicLatitude = geoLatitude
			Lighting.ClockTime = clockTime
		else
			setHistoryWaypoint = false
			ChangeHistoryService:SetWaypoint(body.Name .. " Drag End")
		end
	else
		onDeactivation()
	end
end

plugin.Deactivation:Connect(onDeactivation)
RunService:BindToRenderStep("CelesialBodyUpdate", 201, updateCelesialBodies)

---------------------------------------------------------------------------------------------------------------------------------------------------------------------