------------------------------------------------------------------------------------------------------------------------------------------------------------
-- @ CloneTrooper1019, 2019 
-- HeightMapper.lua 
------------------------------------------------------------------------------------------------------------------------------------------------------------
-- This module attempts to recreate the logic behind Roblox's original
-- terrain importer. Its not exactly 1:1, but its pretty close, and the
-- user experience should be a lot more responsive.
--
-- There are a few primary differences at the moment:
--
-- # Terrain is loaded with a scanline like the generator.
-- # The heightmap isn't generated as a sheet, it rises from the ground.
-- # Since it utilizes FillBlock, there isn't much smoothing to the terrain.
-- # Transparency is a considered factor in the height map to avoid random spikes!
--
------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Dependencies
------------------------------------------------------------------------------------------------------------------------------------------------------------

local project = script.Parent.Parent
local PNG = require(project.PNG)

local RunService = game:GetService("RunService")

-- MATERIAL_COLORS stores the default material colors
-- for all of the terrain materials as Vector3 objects
-- Doing this so its easier to measure differences
-- between colors via '(a - b).Magnitude'

local MATERIAL_COLORS = 
{
	Asphalt     = Vector3.new(115, 123, 107);
	Basalt      = Vector3.new( 30,  30,  37);
	Brick       = Vector3.new(138,  86,  62);
	Cobblestone = Vector3.new(132, 123,  90);
	Concrete    = Vector3.new(127, 102,  63);
	CrackedLava = Vector3.new(232, 156,  74);
	Glacier     = Vector3.new(101, 176, 234);
	Grass       = Vector3.new(106, 127,  63);
	Ground      = Vector3.new(102,  92,  59);
	Ice         = Vector3.new(129, 194, 224);
	LeafyGrass  = Vector3.new(115, 132,  74);
	Limestone   = Vector3.new(206, 173, 148);
	Mud         = Vector3.new( 58,  46,  36);
	Pavement    = Vector3.new(148, 148, 140);
	Rock        = Vector3.new(102, 108, 111);
	Salt        = Vector3.new(198, 189, 181);
	Sand        = Vector3.new(143, 126,  95);
	Sandstone   = Vector3.new(137,  90,  71);
	Slate       = Vector3.new( 63, 127, 107);
	Snow        = Vector3.new(195, 199, 218);
	Water       = Vector3.new( 12,  84,  92);
	WoodPlanks  = Vector3.new(139, 109,  79);
}

------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utilities
------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------
-- double getLuminance(Color3 color)
---------------------------------------------------------------------------------
-- Computes the relative luminance of the provided
-- Color3 value as a number in the [0-1] range.
---------------------------------------------------------------------------------

local function getLuminance(color)
	return 0.2126 * color.R
	     + 0.7152 * color.G
	     + 0.0722 * color.B
end

---------------------------------------------------------------------------------
-- Vector3 colorToVector3(Color3 color)
---------------------------------------------------------------------------------
-- Converts a Color3 value into a Vector3 with
-- the RGB coordinates in a [0-255] range.
---------------------------------------------------------------------------------

local function colorToVector3(color)
	local r = color.R * 255
	local g = color.G * 255
	local b = color.B * 255
	
	return Vector3.new(r, g, b)
end

---------------------------------------------------------------------------------
-- Material getClosestMaterial(Color3 targetColor)
---------------------------------------------------------------------------------
-- Takes a Color3 value and returns the terrain material
-- whose color is closest to matching the provided color.
---------------------------------------------------------------------------------

local function getClosestMaterial(targetColor)
	local bestMat, bestDist = nil, math.huge
	local target = colorToVector3(targetColor)
	
	for mat, color in pairs(MATERIAL_COLORS) do
		local dist = (color - target).Magnitude
		
		if dist < bestDist then
			bestMat = mat
			bestDist = dist
			
			if bestDist < 0.01 then
				break
			end
		end
	end
	
	return bestMat
end

---------------------------------------------------------------------------------
-- Tuple<Color3, double> sampleBilinear(PNG image, double x, double y)
---------------------------------------------------------------------------------
-- Takes an image and two floating point XY coordinates,
-- and samples the surrounding pixels to create a blended
-- color/alpha value pair, effectively stretching the image.
---------------------------------------------------------------------------------

local function sampleBilinear(image, x, y)
	local x0 = math.floor(x)
	local y0 = math.floor(y)
	
	local x1 = math.ceil(x)
	local y1 = math.ceil(y)
	
	local c00, a00 = image:GetPixel(x0, y0)
	local c01, a01 = image:GetPixel(x0, y1)
	
	local c10, a10 = image:GetPixel(x1, y0)
	local c11, a11 = image:GetPixel(x1, y1)
	
	local c0 = c00:Lerp(c01, y - y0)
	local c1 = c10:Lerp(c11, y - y0)
	
	local a0 = a00 + ((a01 - a00) * (y - y0))
	local a1 = a10 + ((a11 - a10) * (y - y0))
	
	local color = c0:Lerp(c1, x - x0)
	local alpha = a0 + ((a1 - a0) * (x - x0))
	
	return color, alpha
end

------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Height Mapper
------------------------------------------------------------------------------------------------------------------------------------------------------------

local HeightMapper = {}
HeightMapper.__index = HeightMapper

---------------------------------------------------------------------------------
-- HeightMapper HeightMapper.new(BindableEvent update = nil)
---------------------------------------------------------------------------------
-- Creates a new HeightMapper, with the option to provide a BindableEvent that
-- is fired with a number between 0-1 to indicate the importer's progress.
---------------------------------------------------------------------------------

function HeightMapper.new(update)
	local mapper = {}
	
	if typeof(update) == "Instance" then
		if update:IsA("BindableEvent") then
			mapper.Updated = update
		end
	end
	
	return setmetatable(mapper, HeightMapper)
end

---------------------------------------------------------------------------------
-- void HeightMapper:_UpdateProgress(double percent)
---------------------------------------------------------------------------------
-- Fires the HeightMapper's updated event with the provided percent,
-- if an update event is mounted to the HeightMapper.
---------------------------------------------------------------------------------

function HeightMapper:_UpdateProgress(percent)
	if self.Updated then
		self.Updated:Fire(percent)
	end
end

---------------------------------------------------------------------------------
-- void HeightMapper:Import(Region3 region, PNG heightMap, PNG colorMap = nil)
---------------------------------------------------------------------------------
-- Generates a terrain heightmap using the provided Region3 
-- to position and scale the terrain. 
-- 
-- The height map is based on the luminance of each pixel in the 
-- provided height map file. 
--
-- The color map is optional, and attempts to match each color
-- to the nearest terrain material color.
---------------------------------------------------------------------------------

function HeightMapper:Import(region, heightMap, colorMap)
	if self.Busy then
		warn("Already importing terrain!")
		return
	end
	
	local cf = region.CFrame
	local size = region.Size
	
	local corner0 = cf * (size / -2)
	local corner1 = cf * (size /  2)
	
	local xMin = corner0.X
	local xMax = corner1.X
	
	local yMin = corner0.Y
	local yMax = corner1.Y
	
	local zMin = corner0.Z
	local zMax = corner1.Z
	
	local terrain = workspace.Terrain
	local coolDown = 0
	
	warn("Importing...")
	
	self.Busy = true
	self:_UpdateProgress(0)
	
	for x = xMin, xMax, 4 do
		local sx = (x - xMin) / (xMax - xMin)
		
		local hx = heightMap.Width * sx
		local cx = colorMap and colorMap.Width * sx
		
		for z = zMin, zMax, 4 do
			local sz = (z - zMin) / (zMax - zMin)
			
			local hz = heightMap.Height * sz
			local cz = colorMap and colorMap.Height * sz
			
			-- Sample the height
			local height, alpha = sampleBilinear(heightMap, hx, hz)
			height = getLuminance(height) * (yMax - yMin)
			
			if height >= 4 and alpha > 0 then
				-- Sample the material
				local material = "Concrete"
				local matAlpha = 255
				
				if colorMap then
					local color, alpha = sampleBilinear(colorMap, cx, cz)
					material = getClosestMaterial(color)
					matAlpha = alpha
				end
				
				if matAlpha > 0 then
					-- Generate the block
					local cf = CFrame.new(x, cf.Y + (height / 2), z)
					local size = Vector3.new(4, height, 4)
					
					terrain:FillBlock(cf, size, material)
					coolDown = coolDown + 1
					
					if (coolDown % 1000) == 0 then
						self:_UpdateProgress(sx)
						RunService.Heartbeat:Wait()
					end
				end
			end
		end
	end
	
	self:_UpdateProgress(1)
	self.Busy = false
end

return HeightMapper

------------------------------------------------------------------------------------------------------------------------------------------------------------