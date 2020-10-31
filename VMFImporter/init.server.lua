-------------------------------------------------------------------------------------------------------------------------------
-- @ CloneTrooper1019, 2017-2020 <3
-- VMF Importer
-- Attempts to import Valve Map Files 
-------------------------------------------------------------------------------------------------------------------------------
-- Setup
-------------------------------------------------------------------------------------------------------------------------------

local modules = script.Modules
local mockPlugin = (plugin == nil)

local Tree = require(modules.Tree)
local Plane = require(modules.Plane)
local Debug3D = require(modules.Debug3D)
local Polygon = require(modules.Polygon)
local Winding = require(modules.Winding)
local Materials = require(modules.Materials)
local MockPlugin = require(modules.MockPlugin)

local guiName = "VMF_ImporterGui"
local toolbarName = "Source"

if mockPlugin then
	plugin = MockPlugin.new()
end

if plugin.Name:find(".rbxm") then
	toolbarName ..= " [DEV]"	
end

local toolbar = plugin:CreateToolbar(toolbarName)

local importVmf = toolbar:CreateButton(
	"VMF_PLUGIN_" .. os.time(), 
	"Import the brush geometry of a Valve Map File.", 
	"rbxassetid://15384541", 
	"Import VMF [BETA]"
)

local VMF_UNITS_PER_STUD = 10
local ROUND_VERTEX_EPSILON = 0.01 -- Edges shorter than this are considered degenerate.
local MIN_EDGE_LENGTH_EPSILON = 0.1 -- Vertices within this many units of an integer value will be rounded to an integer value.

local GlobalSettings = mockPlugin and {} or settings()
local Physics = GlobalSettings.Physics

local Terrain = workspace.Terrain
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local StudioService = game:GetService("StudioService")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local abs   = math.abs
local atan2 = math.atan2
local ceil  = math.ceil
local deg   = math.deg
local inf   = math.huge
local floor = math.floor
local rad   = math.rad
local sign  = math.sign
local sin   = math.sin

local sort = table.sort
local push = table.insert
local pop  = table.remove

local blankVec = Vector3.new()
local blankUDim2 = UDim2.new()

local debugMode = false

if mockPlugin then
	debugMode = true
	CoreGui = game:GetService("StarterGui")
end

if debugMode then
	guiName = "VMF_ImporterGui_DEBUG"
end

if CoreGui:FindFirstChild(guiName) then
	CoreGui[guiName].Parent = nil -- Destroy doesn't work for some reason.
end

Debug3D:SetPlayerGui(CoreGui)

-------------------------------------------------------------------------------------------------------------------------------
-- Progress GUI
-------------------------------------------------------------------------------------------------------------------------------

local startedAt = 0
local sidesDone = 0
local totalSides = 0
local solidsDone = 0
local totalSolids = 0

local building = false
local status = "Loading..."

local fracFormat = "Solids: %d/%d\tSides: %d/%d"
local etaFormat = "(Estimated Time Left - %02d:%02d)"

local importingGui = script.ImporterGui:Clone()
local importFrame = importingGui.ImportFrame

local progressBar = importFrame.ProgressBar
local completedBar = progressBar.Completed

local compFrac = progressBar.CompFraction
local spinner = importFrame.Spinner

local eta = importFrame.ETA
local title = importFrame.Title

local gradient = spinner.Gradient
local lastEtaUpdate = 0

importingGui.Name = guiName
importingGui.Parent = CoreGui

local function updateGui()
	local now = os.clock()
	importFrame.Visible = building
	
	if not building then
		return
	end
	
	local elapsed = now - startedAt
	local compRatio = 0
	
	if totalSides > 0 then
		compRatio = sidesDone / totalSides
	end
	
	if compRatio > 0 then
		if (now - lastEtaUpdate) > 1 then
			local est = elapsed / compRatio
			
			local timeLeft = est  - elapsed
			local sec = floor(timeLeft % 60)
			local min = floor(timeLeft / 60)
			
			eta.Text = etaFormat:format(min, sec)
			lastEtaUpdate = now
		end
		
		compFrac.Text = fracFormat:format(solidsDone, totalSolids, sidesDone, totalSides)
		completedBar.Size = UDim2.new(compRatio, 0, 1, 0)
		completedBar.Visible = true
	else
		eta.Text = ""
		compFrac.Text = "Loading..."
		completedBar.Visible = false
	end
	
	local wave = (now * 180) % 360
	local rad = math.rad(wave)
	
	local x = math.sin(rad)
	local y = -math.cos(rad)
	
	title.Text = status
	gradient.Rotation = wave - 5
	gradient.Offset = Vector2.new(x, y) * 2
end

RunService.Heartbeat:Connect(updateGui)

-------------------------------------------------------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------------------------------------------------------

local function readNumber(input)
	local read = input:gmatch("[^ ]+")
	
	return function ()
		local nextNum = read()
		return tonumber(nextNum)
	end
end

local function readVector3(input)
	local read = readNumber(input)
	
	return function ()
		local x, y, z = read(), read(), read()
		
		if x and y and z then
			return Vector3.new(x, z, -y)
		end
	end
end

local function parseVector3(v3str)
	local coords = {}
	
	for num in v3str:gmatch("[^ ,;]+") do
		coords[#coords + 1] = tonumber(num)
	end
	
	return Vector3.new(unpack(coords))
end

local function tupleGroupCall(obj, methodName, ...)
	local input = {...}
	local result = obj[methodName](obj, input)
	
	if typeof(result) == "table" then
		return unpack(result)
	else
		return result
	end
end

local function create(ty)
	return function (data)
		local obj = Instance.new(ty)
		
		for k, v in pairs(data) do
			if type(k) == 'number' then
				v.Parent = obj
			else
				obj[k] = v
			end
		end
		
		return obj
	end
end

local function debugWarn(...)
	if debugMode then
		warn(...)
	end
end

local function debugWait(n)
	if debugMode then
		wait(n)
	end
end

local function checkFlag(flagName)
	local flag = workspace:FindFirstChild(flagName)
	
	if flag and flag:IsA("ValueBase") then
		return flag.Value
	end
end

local function roundCoord(value)
	local round = math.round(value)
	
	if value ~= round and math.abs(value - round) < ROUND_VERTEX_EPSILON then
		return round
	end
	
	return value
end

-------------------------------------------------------------------------------------------------------------------------------
-- Entity Functions
-------------------------------------------------------------------------------------------------------------------------------

local models
local missing
local nameLookUp
local reportFormat = "\t* %s (x%d)"

local ropeColors = 
{
	red   = BrickColor.Red();
	blue  = BrickColor.Blue();
	green = BrickColor.Green();
	rope  = BrickColor.new("Fawn brown");
	cable = BrickColor.new("Really black");
}

local function findModel(modelPath, searchIn)
	if modelPath:lower() == "skip" then
		return 
	end
	
	local modelPath = modelPath
		:gsub("models/", "")
		:gsub(".mdl", "")
		:lower()
	
	
	local result = searchIn or models
	
	for traversal in modelPath:gmatch("[^/]+") do
		result = result:FindFirstChild(traversal)
		
		if result and result:IsA("StringValue") then		
			break
		elseif not result then
			if missing.Counts[modelPath] then
				missing.Counts[modelPath] += 1
			else
				missing.Counts[modelPath] = 1
				push(missing.Models, modelPath)
			end
			
			missing.Total += 1
			
			if missing.Total <= 256 then
				if missing.Counts[modelPath] <= 32 then
					if missing.Counts[modelPath] == 32 then
						warn("Usage count for missing model", modelPath, "exceeded 32, not placing any more error models.")
					end
					
					local errorMdl = findModel("error", searchIn)
					errorMdl = errorMdl:Clone()
					
					local missingGui = script.MissingGui:Clone()
					missingGui.MissingLbl.Text = "Missing: " .. modelPath
					missingGui.Adornee = errorMdl
					missingGui.Parent = errorMdl
					
					return errorMdl
				end
			elseif missing.Total == 256 + 1 then
				warn("Total missing models has exceeded 256, not placing any more error models.")
			end
			
			return
		end
	end
	
	if result:IsA("StringValue") then
		return findModel(result.Value, searchIn)
	elseif result == nil then
		local base = script:FindFirstChild("Models")
		
		if searchIn ~= base then
			return findModel(result, base)
		end
	end
		
	return result
end

local function getAttachmentNode(mdl)
	if not mdl then 
		return
	end
	
	local node = mdl:FindFirstChild("PointNodes")
	
	if not node then
		node = Instance.new("Part")
		node.Name = "PointNodes"
		node.Size = Vector3.new()
		node.Anchored = true
		node.CanCollide = false
		node.Transparency = 1
		node.Locked = true
		node.Parent = mdl
	end
	
	return node
end

local function resetModelState()
	local vmfImporter = ServerStorage:FindFirstChild("VMF Importer")
	
	if not vmfImporter then
		vmfImporter = Instance.new("Folder")
		vmfImporter.Name = "VMF Importer"
		vmfImporter.Parent = ServerStorage
	end
	
	models = vmfImporter:FindFirstChild("Models")
	
	if not models then
		models = script:FindFirstChild("Models")
		
		if models then
			models = models:Clone()
		else
			models = Instance.new("Folder")
			models.Name = "Models"
		end
		
		models.Parent = vmfImporter
	end
	
	missing = 
	{
		Counts = {};
		Models = {};
		Total = 0;
	}
	
	nameLookUp = {}
end

local function printMissingModels(label, sortFunc)
	print(label)
	sort(missing.Models, sortFunc)
	
	for i, name in ipairs(missing.Models) do
		local counts = missing.Counts[name]
		print(reportFormat:format(name, counts))
		
		if (i % 250) == 0 then
			wait()
		end
	end
end

local function sortByUsage(a, b)
	local countA = missing.Counts[a] or 0
	local countB = missing.Counts[b] or 0
	
	return countA > countB
end

local function reportMissingModels()
	if missing.Total == 0 then 
		return
	end
	
	warn("~ Missing Model Report ~")
	
	printMissingModels("Alphabetical")
	printMissingModels("Highest Usage Counts", sortByUsage)	
end

-------------------------------------------------------------------------------------------------------------------------------
-- Brushes
-------------------------------------------------------------------------------------------------------------------------------

local upVector = Vector3.new(0, 1, 0)

local function lerpImpl(obj0, obj1, a)
	return obj0:Lerp(obj1, a)
end

local function lerpNum(a, b, t)
	return a + (b - a) * t
end

local function computeAABB(points)
	local abs = math.abs
	local inf = math.huge
	
	local min_X, min_Y, min_Z =  inf,  inf,  inf
	local max_X, max_Y, max_Z = -inf, -inf, -inf
	
	for _,point in pairs(points) do
		local x = point.X
		min_X = math.min(x, min_X)
		max_X = math.max(x, max_X)
		
		local y = point.Y
		min_Y = math.min(y, min_Y)
		max_Y = math.max(y, max_Y)
		
		local z = point.Z
		min_Z = math.min(z, min_Z)
		max_Z = math.max(z, max_Z)
	end
	
	local min = Vector3.new(min_X, min_Y, min_Z)
	local max = Vector3.new(max_X, max_Y, max_Z)
	
	return Region3.new(min, max)
end

local function solveFaces(planes)
	local usePlane = table.create(#planes, false)
	
	-- For every face that is not set to be ignored, check the plane and make sure
	-- it is unique. We mark each plane that we intend to keep with `true` in the
	-- 'usePlane' array.
	
	for i = 1, #planes do
		local plane = planes[i]
		
		-- Don't use this plane if it has a zero-length normal.
		if plane.Normal == blankVec then
			usePlane[i] = false
			continue
		end
		
		-- If the plane duplicates another plane, don't use it
		usePlane[i] = true
		
		for j = 1, i - 1 do
			local planeCheck = planes[j]
			
			local f1 = plane.Normal
			local f2 = planeCheck.Normal
			
			-- Check for duplicate plane within some tolerance.
			if f1:Dot(f2) > 0.99 then
				local d1 = plane.Distance
				local d2 = planeCheck.Distance
				
				if math.abs(d1 - d2) < 0.01 then
					usePlane[j] = false
					break
				end
			end
		end
	end
	
	-- Now we have a set of planes, indicated by `true` values in the 'usePlanes' array,
	-- from which we will build a solid.
	
	local faces = {}
	
	for i = 1, #planes do
		local plane = planes[i]
		
		if not usePlane[i] then
			continue
		end
		
		-- Create a huge winding from this plane, 
		-- then clip it by all other planes.
		
		local j = 1
		local winding = Winding.fromPlane(plane)
		
		while (winding and j <= #planes) do
			local clip = planes[j]
			
			if i ~= j then
				-- Flip the plane, because we want to keep the back side.
				winding = winding:Clip
				{
					Distance = -clip.Distance;
					Normal = -clip.Normal;
				}
			end
			
			j += 1
		end
		
		-- If we still have a winding after all that clipping,
		-- build a face from the winding.
		
		if winding ~= nil then
			-- Round all points in the winding that are within
			-- ROUND_VERTEX_EPSILON of integer values.
			
			local numPoints = winding.NumPoints
			local points = winding.Points
			
			for j = 1, numPoints do
				local point = points[j]
				
				local x = roundCoord(point.X)
				local y = roundCoord(point.Y)
				local z = roundCoord(point.Z)
				
				points[j] = Vector3.new(x, y, z)
			end
			
			-- The above rounding process may have created duplicate points. Eliminate them.
			winding:RemoveDuplicates(MIN_EDGE_LENGTH_EPSILON)
			winding.Plane = plane
			
			push(faces, winding)
		end
	end
	
	-- Remove faces that don't contribute to this solid.
	for i = #faces, 1, -1 do
		local face = faces[i]
		
		if face.NumPoints == 0 then
			table.remove(faces, i)
		else
			while #face.Points > face.NumPoints do
				table.remove(face.Points)
			end
		end
	end
	
	return faces
end

local function solveBrush(solidPart, cuts, area)
	local subtract = {}
	local useWater = false
	local materials = {}
	
	for side, cut in pairs(cuts) do
		local baseCF = cut.CFrame
		cut.Parent = nil
		cut.Size = cut.Size * (area * 2)
		cut.CFrame = cut.CFrame + (cut.CFrame.LookVector * area)
		
		local myMatInfo = Materials:Get(side.material)
		
		if myMatInfo and not (myMatInfo.Skip and not side.material:lower():sub(-9) == "toolsclip") then
			if not materials[side.material] then
				materials[side.material] = true
			end
			
			if myMatInfo.UseWater then
				useWater = true
			end
			
			if cut:IsA("PartOperation") then
				cut.UsePartColor = true
			end
			
			if myMatInfo.Material then
				cut.Material = myMatInfo.Material
			end
			
			if myMatInfo.Color then
				cut.Color = myMatInfo.Color
			end
			
			cut.Reflectance = myMatInfo.Reflectance or 0
			cut.Transparency = myMatInfo.Transparency or 0
		end
		
		table.insert(subtract, cut)
		sidesDone += 1
	end
	
	local result = solidPart:SubtractAsync(subtract, "Hull", "Precise")
	solidPart.Parent = nil
	
	for material in pairs(materials) do
		CollectionService:AddTag(result, material)
	end
	
	if useWater then
		Terrain:FillBlock(result.CFrame, result.Size - Vector3.new(2, 2, 2), Enum.Material.Water)
		return
	end
	
	return result
end

local function solveCube(planes, bbox)
	local marked = {}
	local coplanar = {}
	
	local numPlanes = #planes
	
	for i = 1, numPlanes do
		for j = i + 1, numPlanes do
			local planeA = planes[i]
			local planeB = planes[j]
			
			if not (marked[planeA] or marked[planeB]) then
				if planeA:IsCoplanarWith(planeB) then
					local set = { planeA, planeB }
					push(coplanar, set)
					
					marked[planeA] = true
					marked[planeB] = true
				end
			end
		end
	end
	
	if #coplanar == 3 then
		local vectors = {}
		
		for a = 1, 3 do
			local b = (a % 3) + 1
			local c = (b % 3) + 1
			
			local planeA = coplanar[a][1]
			local planeB = coplanar[b][1]
			local planeC = coplanar[c][1]
			
			local normA = planeA.Normal
			local normB = planeB.Normal
			local normC = planeC.Normal
			
			local computed = normB:Cross(normC)
			local dotProd = normA:Dot(computed)
			
			if abs(dotProd) > 0.999 then
				push(vectors, computed)
			end
		end
		
		if #vectors == 3 then
			local center = bbox.CFrame.Position
			local size = {}
			
			for i = 1,3 do
				local pair = coplanar[i]
				
				local planeA = pair[1]
				local planeB = pair[2]
				
				local originA = planeA.Origin
				local originB = planeB:GetRayIntersection(planeA.Ray)
				
				size[i] = (originB - originA).Magnitude
			end
			
			-- Compute best match for the up-axis of the cube.
			local bestUp = 2
			local bestProd = 0
			
			for i = 1,3 do
				local vector = vectors[i]
				local prod = abs(vector:Dot(upVector))
				
				if prod > bestProd then
					bestProd = prod
					bestUp = i
				end
			end
			
			if bestUp ~= 2 then
				local oldUpVector = vectors[2]
				vectors[2] = vectors[bestUp]
				vectors[bestUp] = -oldUpVector
				
				local oldUpSize = size[2]
				size[2] = size[bestUp]
				size[bestUp] = oldUpSize
			end
			
			-- Return CFrame and Size for the cube.
			local cf = CFrame.fromMatrix(center, unpack(vectors))
			return true, Vector3.new(unpack(size)), cf
		end
	end
	
	return false
end

-------------------------------------------------------------------------------------------------------------------------------
-- Displacements
-------------------------------------------------------------------------------------------------------------------------------

local polyBuffer = 0
local defaultColor = Color3.new(0.7, 0.7, 0.7)

local function readGridData(data, buffer)
	if data then
		local matrix = {}
		
		for k, v in pairs(data) do
			local x = tonumber(k:match("row(%d+)"))
			
			if x then
				local y = 0
				matrix[x] = {}
				
				for chunk in buffer(v) do
					matrix[x][y] = chunk
					y += 1
				end
			end
		end
		
		return matrix
	end
end

local function sampleBilinear(grid, x, y, lerp, scale)
	if not grid then
		return
	end
	
	local x0, y0 = floor(x), floor(y)
	local x1, y1 =  ceil(x),  ceil(y)
	
	local upLeft = grid[x0][y0]
	local upRight = grid[x1][y0]
	
	local downLeft = grid[x0][y1]
	local downRight = grid[x1][y1]
	
	local up = lerp(upLeft, upRight, x - x0)
	local down = lerp(downLeft, downRight, x - x0)
	
	local final = lerp(up, down, y - y0)
	final *= (scale or 1)
	
	return final
end

local function readDispMap(dispInfo)
	return
	{
		Elevation = dispInfo.elevation or 0;
		
		Height  = readGridData(dispInfo.distances, readNumber );
		Alpha   = readGridData(dispInfo.alphas,    readNumber );
		Normal  = readGridData(dispInfo.normals,   readVector3);
		Offset  = readGridData(dispInfo.offsets,   readVector3);
	}
end

local function sampleDispMap(dispMap, x, y, plane)
	return
	{
		Offset = sampleBilinear(dispMap.Offset, x, y, lerpImpl, 1 / VMF_UNITS_PER_STUD) or blankVec;
		Height = sampleBilinear(dispMap.Height, x, y, lerpNum,  1 / VMF_UNITS_PER_STUD) or 0;
		
		Normal = sampleBilinear(dispMap.Normal, x, y, lerpImpl, 1) or blankVec;
		Alpha  = sampleBilinear(dispMap.Alpha,  x, y, lerpNum,  1) or 0;
	}
end

local function buildDispPolygon(chunk, a, b, c, srcNormal)
	local polygon = Polygon.new(a.Vertex, b.Vertex, c.Vertex, srcNormal)

	if a.Material then
		local avgAlpha = (a.Alpha + b.Alpha + c.Alpha) / 3
		
		local mat0 = Materials:Get(a.Material, 0)
		local color0 = mat0.Color
		
		local mat1 = Materials:Get(a.Material, 255)
		local color1 = mat1.Color
		
		if avgAlpha > 127 then
			polygon.Material = mat1.Material or "Plastic"
			polygon.Reflectance = mat1.Reflectance or 0
			polygon.Transparency = mat1.Transparency or 0
		else
			polygon.Material = mat0.Material or "Plastic"
			polygon.Reflectance = mat0.Reflectance or 0
			polygon.Transparency = mat0.Transparency or 0
		end
		
		if not color0 then
			color0 = defaultColor
		end
		
		if not color1 then
			color1 = defaultColor
		end
		
		polygon.Color = color0:Lerp(color1, avgAlpha / 255)
	else
		warn("Missing Displacement Material for ", chunk)
	end

	polygon.Parent = chunk
end

local function processDisp(solid, bin, power)
	local sides = solid:GetItemsOfType("side")
	local planes = {}
	
	for i, side in ipairs(sides) do
		planes[i] = Plane.fromVmf(side.plane, VMF_UNITS_PER_STUD)
	end
	
	local faces = solveFaces(planes)
	local faceMap = {}
	
	for _,face in pairs(faces) do
		faceMap[face.Plane] = face
	end
	
	for pIndex, side in ipairs(sides) do
		local dispInfo = side.dispinfo
		local myPlane = planes[pIndex]
		
		if dispInfo then
			if dispInfo.power ~= power then
				continue
			end
		else
			if not side.Checked then
				side.Checked = true
				sidesDone += 1
			end
			
			continue
		end
		
		local myFace = faceMap[myPlane]
		local verts = myFace.Points
		
		if #verts ~= 4 then
			if not dispInfo and not side.Checked then
				side.Checked = true
				sidesDone += 1
			end
			
			warn("Error: Displacement expects 4 vertices, but got", #verts, "- cannot process correctly!!")
			continue
		end
			
		-- Parse the startposition
		local x, y, z = dispInfo.startposition:match("%[(%S+) (%S+) (%S+)%]")
		local startPos = Vector3.new(x, z, -tonumber(y)) / VMF_UNITS_PER_STUD
		
		local minDistance = math.huge
		local startIndex = -1
		
		for i = 0, 3 do
			local pos = verts[i + 1]
			local dist = (pos - startPos).Magnitude
			
			if dist < minDistance then
				minDistance = dist
				startIndex = i
			end
		end
		
		-- Rotate the winding so the startPos
		-- is first in line in the loop.
		
		local corners = {}
		
		for i = 0, 3 do
			local j = (i + startIndex) % 4
			corners[i + 1] = verts[j + 1]
		end
		
		local scale = dispInfo.scale or 1
		local res = 2 ^ power
		
		local dispMap = readDispMap(dispInfo)
		local elevation = dispMap.Elevation
		
		-- Compute the vertex positions and materials
		local elev = elevation * myPlane.Normal
		local polyGrid = {}
		
		---------------------------------
		-- Generating the displacement --
		--  using the 'corners' array  --
		--                             --
		--          [2]---[3]          --
		--           |     |           --
		--           |     |           --
		--          [1]---[4]          --
		--                             --
		---------------------------------
		
		for i = 0, res do
			local rowStart = corners[3]:Lerp(corners[4], i / res)
			local rowEnd   = corners[2]:Lerp(corners[1], i / res)
			
			polyGrid[i] = {}
			
			for j = 0, res do
				local sample = sampleDispMap(dispMap, res - i, res - j)	
				local initPos = rowStart:Lerp(rowEnd, j / res)
				
				local offset = sample.Offset + elev + (sample.Normal * sample.Height)
				local vertex = initPos + offset
				
				local data = 
				{
					Vertex = vertex;
					Material = side.material;
					Alpha = sample.Alpha;
				}
				
				polyGrid[i][j] = data
			end
		end
		
		-- Generate Displacement Geometry
		local norm = myPlane.Normal
		
		for x = 0, res - 1 do
			for y = 0, res - 1 do
				local a = polyGrid[  x  ][  y  ]
				local b = polyGrid[x + 1][  y  ]
				local c = polyGrid[  x  ][y + 1]
				local d = polyGrid[x + 1][y + 1]

				local chunk = Instance.new("Model")
				chunk.Name = string.format("chunk[%02d][%02d]", x, y)
				
				----------------------------------------------------
				if (x + y) % 2 == 0 then				   -- a-b --
					buildDispPolygon(chunk, a, b, c, norm) -- |/| --
					buildDispPolygon(chunk, d, c, b, norm) -- c-d --
				else                                       ---------					
					buildDispPolygon(chunk, b, a, d, norm) -- a-b --
					buildDispPolygon(chunk, c, d, a, norm) -- |\| --
				end                                        -- c-d --
				----------------------------------------------------
				
				chunk.Parent = bin
				polyBuffer += 1
				
				if (polyBuffer % 60) == 0 then
					RunService.Heartbeat:Wait()
				end
			end
		end
		
		sidesDone += 1
	end
end

-------------------------------------------------------------------------------------------------------------------------------
-- Main Importer
-------------------------------------------------------------------------------------------------------------------------------

local VMF_FILTER = {"vmf"}
local errorLabel = "FATAL ERROR: %s\nStack Begin\n%sStack End"

local function handleError(err)
	warn(errorLabel:format(err, debug.traceback()))
	status = "FATAL ERROR:\n" .. err
end

local function promptOpenVmf()
	local success, vmf = pcall(function ()
		if mockPlugin then
			local bin = script.Parent
			local mockFile = bin and bin:FindFirstChild("MockFile")
			
			if mockFile and mockFile:IsA("ModuleScript") then
				local result = require(mockFile:Clone())
				return tostring(result)
			end
		else
			local result = StudioService:PromptImportFile(VMF_FILTER)
			
			if result then
				return result:GetBinaryContents()
			end
		end
	end)
	
	if success and vmf then
		return vmf
	end
	
	return ""
end

local function buildWorld(vmf)
	if not Terrain then
		Terrain = workspace.Terrain
	end
	
	if workspace:FindFirstChild("world") then
		workspace.world:Destroy()
		Terrain:Clear()
	end
	
	local world = vmf.world
	local worldMdl = workspace:FindFirstChild("world")
	
	if not worldMdl then
		worldMdl = Instance.new("Model")
		worldMdl.Name = "world"
		worldMdl.Parent = workspace
	end
	
	if game.PlaceId == 95206881 and workspace:FindFirstChild("Baseplate") then
		workspace.Baseplate:Remove()
	end
	
	resetModelState()
	
	if checkFlag("SkipGeometry") then
		return
	end
	
	if not mockPlugin then
		ChangeHistoryService:SetEnabled(false)
	end
	
	-- To-do: Remove this bit here when CSGv2 is phased in completely.
	pcall(function ()
		Physics.DisableCSGv2 = false
	end)
	
	local solids = {}
	local disps = {}
	
	local function addSolid(solid)
		local sides = solid:GetItemsOfType("side")
		push(solids, solid)
		
		totalSolids += 1
		totalSides += #sides
	end
	
	status = "Getting Solids..."
	
	if world then
		for _,solid in ipairs(world:GetItemsOfType("solid")) do
			addSolid(solid)
		end
	end
	
	for _,entity in ipairs(vmf:GetItemsOfType("entity")) do
		local entSolids = entity:GetItemsOfType("solid")
		
		if #entSolids > 0 then
			entity.HasSolids = true
			entity.Solids = {}
			
			if entity.targetname then
				nameLookUp[entity.targetname] = entity
			end
			
			for _,solid in ipairs(entSolids) do
				solid.entity = entity
				addSolid(solid)
			end
		end
	end
	
	status = "Generating Brushes..."
	
	for i, solid in ipairs(solids) do
		local sides = solid:GetItemsOfType("side")
		local hasDisps = false
		local maxPower = 2
		
		-- If any side is a displacement, then don't bother doing CSG.
		for _, side in ipairs(sides) do
			local dispInfo = side.dispinfo
			if dispInfo then
				hasDisps = true
				maxPower = math.max(maxPower, dispInfo.power)
			end
		end
		
		if hasDisps then
			local dispBin = Instance.new("Model")
			dispBin.Name = "disp_" .. i
			dispBin.Parent = worldMdl
			
			disps[solid] = dispBin
			solid.MaxPower = maxPower
		else
			local binName = "solid_work_" .. i
			
			if worldMdl:FindFirstChild(binName) then
				worldMdl[binName]:Destroy()
			end
			
			local bin = Instance.new("Model")
			bin.Name = binName
			
			local matInfo, matName
			local planes = {}
			local cuts = {}
			
			for _, side in ipairs(sides) do
				local myMatInfo, myMatName = Materials:Get(side.material)
				
				if myMatInfo and not myMatInfo.Skip then
					if matInfo == nil then
						matInfo = myMatInfo
						matName = myMatName
					end
				end
				
				local plane = Plane.fromVmf(side.plane, VMF_UNITS_PER_STUD)
				push(planes, plane)
				
				local cut = Instance.new("Part")
				cut.Size = Vector3.new(1, 1, 1)
				cut.Anchored = true
				cut.Transparency = 1
				cut.CFrame = plane.CFrame
				
				cuts[side] = cut
			end
			
			if matInfo then
				-- Compute the intersection points
				local faces = solveFaces(planes)
				local points = {}
				
				for _,face in pairs(faces) do
					for _,point in pairs(face.Points) do
						push(points, point)
					end
				end
				
				-- Compute the extents of these points
				local aabb = computeAABB(points)
				local isCube, size, cf = solveCube(planes, aabb)
				
				local solidPart = create "Part"
				{
					Size = isCube and size or aabb.Size;
					CFrame = isCube and cf or aabb.CFrame;
					
					Anchored = true;
					Locked = true;
					
					Color = matInfo.Color;
					Material = matInfo.Material;
					
					Reflectance = matInfo.Reflectance or 0;
					Transparency = matInfo.Transparency or 0;
					
					TopSurface = 0;
					BottomSurface = 0;
				}
				
				if isCube then
					if matInfo.UseWater then
						Terrain:FillBlock(solidPart.CFrame, solidPart.Size, Enum.Material.Water)
						solidPart:Destroy()
					else
						solidPart.Name = "solid_" .. i
						solidPart.Parent = worldMdl
					end
					
					sidesDone += 6
				else
					local size = aabb.Size
					local area = math.max(size.X, size.Y, size.Z)
					
					solidPart.Parent = bin
					bin.Parent = worldMdl
					
					local success, solidPart = xpcall(solveBrush, handleError, solidPart, cuts, area)
					
					if success and solidPart then
						local entity = solid.entity
						
						if entity then
							push(entity.Solids, solidPart)
							
							if entity.targetname then
								solidPart.Name = entity.targetname
							end
						end
						
						solidPart.Name = "solid_" .. i
						solidPart.Parent = worldMdl
					elseif solidPart then
						solidPart:Destroy()
					end
				end
			else
				sidesDone += #sides
			end
			
			bin:Destroy()
			solidsDone += 1
		end
	end
	
	status = "Generating Displacements..."
	
	for power = 2, 4 do
		for solid, dispBin in pairs(disps) do
			processDisp(solid, dispBin, power)
			
			if power == solid.MaxPower then
				solidsDone += 1
			end
		end
	end
	
	return worldMdl
end

local function generateEntities(vmf, worldMdl)
	local entsOfClass = {}
	local nameLookUp = {}
	local entLookUp = {}
	
	local entityBin = Instance.new("Model")
	entityBin.Name = "entities"
	entityBin.Parent = worldMdl
	
	status = "Generating Entities..."
	
	for i, entity in pairs(vmf:GetItemsOfType("entity")) do
		-- Compute the entity CFrame
		local entityCF = CFrame.new()
		
		if entity.origin then
			local root = parseVector3(entity.origin)
			entityCF = entityCF + Vector3.new(root.X, root.Z, -root.Y) / VMF_UNITS_PER_STUD
		end
		
		if entity.angles then
			local root = parseVector3(entity.angles)
			entityCF = entityCF	* CFrame.Angles(0, -rad(90), 0) 
				* CFrame.Angles(0, rad(root.Y), 0)
				* CFrame.Angles(rad(-root.X), 0, rad(-root.Z))
		end
		
		-- Get the name and class of the entity
		local classname = entity.classname
		
		if classname then
			local name = entity.targetname
			
			if name then
				nameLookUp[name] = entity
			else
				name = classname
			end
			
			-- Get the storage bin for this entity
			local classBin = entityBin:FindFirstChild(classname)
			
			if not classBin then
				classBin = Instance.new("Model")
				classBin.Name = classname
				classBin.Parent = entityBin
			end
			
			-- Create the entity depending on its classname.
			if classname == "info_player_start" then
				local start = Instance.new("SpawnLocation")
				start.Anchored = true
				start.CanCollide = false
				start.Duration = 0
				start.Name = name
				start.CFrame = entityCF
				
				local startMesh = Instance.new("SpecialMesh")
				startMesh.MeshId = "rbxassetid://1200018118"
				startMesh.TextureId = "rbxassetid://1200018139"
				startMesh.Offset = Vector3.new(0, 1.8, 0)
				startMesh.Parent = start
				
				if not mockPlugin then
					local startScript = Instance.new("Script")
					startScript.Name = "HideSpawn"
					startScript.Source = "script.Parent.Transparency = 1\nscript:Destroy()"
					startScript.Parent = start
				end
				
				start.Parent = classBin
				entity.object = start
			elseif classname:sub(1, 5) == "prop_" then
				local modelName = entity.model
				
				if modelName and #modelName > 0 then
					local model = findModel(modelName)
					
					if model then
						local propType = classname:sub(6)
						model = model:Clone()
						
						if entity.targetname then
							model.Name = entity.targetname
						end
						
						local offset = CFrame.new()
						local primary = model
						
						if model:IsA("Model") then
							primary = model.PrimaryPart
						end
						
						if primary:FindFirstChild("Origin") and primary.Origin:IsA("Attachment") then
							offset = primary.Origin.CFrame:inverse()
							primary.Origin:Destroy()
						end
						
						if primary:IsA("MeshPart") and entity.skin then
							local skinId = primary:FindFirstChild("Skin" .. entity.skin)
							
							if skinId then
								primary.TextureID = "rbxassetid://" .. skinId.Value
							end
						end
						
						for _, v in pairs(primary:GetChildren()) do
							if v:IsA("IntValue") and v.Name:sub(1, 4) == "Skin" then
								v:Destroy()
							end
						end
						
						primary.Anchored = (propType ~= "physics")
						
						if model:IsA("Model") then
							model:SetPrimaryPartCFrame(entityCF * offset)
						else
							model.CFrame = entityCF * offset
						end
						
						for _,desc in pairs(model:GetDescendants()) do
							if desc:IsA("BasePart") then
								desc.Locked = true
							end
						end
						
						model.Parent = classBin
						entity.object = model
					end
				end
			elseif classname:sub(-5) == "_rope" then
				local ropeNodes = getAttachmentNode(classBin)
				
				local ropeNode = Instance.new("Attachment")
				ropeNode.Name = name
				ropeNode.CFrame = entityCF
				ropeNode.Parent = ropeNodes
				
				entity.object = ropeNode
			elseif classname == "light_spot" then
				local lightNodes = getAttachmentNode(classBin)
				
				local lightNode = Instance.new("Attachment")
				lightNode.CFrame = entityCF
				lightNode.Name = name
				lightNode.Parent = lightNodes
				
				local dist = tonumber(entity._distance)
				
				if dist and dist > 0 then
					dist /= VMF_UNITS_PER_STUD
				else
					dist = 999
				end
				
				local light = Instance.new("SpotLight")
				light.Range = dist
				light.Angle = tonumber(entity._cone) or 45
				light.Face = Enum.NormalId.Back
				
				local color = entity._light
				
				if color then
					color = parseVector3(color)
					light.Color = Color3.fromRGB(color.X, color.Y, color.Z)
				end
				
				light.Parent = lightNode
				entity.object = light
			else
				-- Unhandled entity, delete the model
				classBin:Destroy()
			end
		else
			warn("Got bad entity with no classname")
		end
		
		if (i % 20) == 0 then
			RunService.Heartbeat:Wait()
		end
	end
	
	-- Link entities that refer to eachother.
	status = "Linking Entities..."
	
	for name, entity in pairs(nameLookUp) do
		local obj = entity.object
		local class = entity.classname
		
		if obj and class then
			entLookUp[entity.object] = entity
			
			if not entsOfClass[class] then
				entsOfClass[class] = {}
			end
			
			push(entsOfClass[class], obj)
		end
	end
	
	-- Process Ropes
	local moveRopes = entsOfClass.move_rope
	
	if moveRopes then
		for _, moveRope in pairs(moveRopes) do
			local at = moveRope
			local marked = {}
			
			while true do
				local start = at
				local ent = entLookUp[at]
				local nextKey = ent.NextKey
				
				local ent_nextAt = nextKey and nameLookUp[nextKey]
				local nextAt = ent_nextAt and ent_nextAt.object
				
				if not nextAt then
					break
				end
				
				if marked[at] and marked[at][nextAt] then
					break
				end
				
				local rope = Instance.new("RopeConstraint")
				rope.Name = at.Name .. "->" .. nextAt.Name
				rope.Attachment0 = at
				rope.Attachment1 = nextAt
				rope.Length = (nextAt.WorldPosition - at.WorldPosition).Magnitude + 2
				rope.Visible = true
				
				local ropeMat = ent.RopeMaterial or "cable/cable.vmt"
				
				-- Chain is supposed to be ignored according to the source sdk, not sure why.
				if ropeMat ~= "cable/chain.vmt" then 
					local ropeType = ropeMat:gsub("cable/", ""):gsub(".vmt", "")
					local color = ropeColors[ropeType] or ropeColors.cable
					rope.Thickness = (tonumber(ent.Thickness) or 3) / VMF_UNITS_PER_STUD
					rope.Color = color
					rope.Parent = at.Parent
				end
				
				if not marked[at] then
					marked[at] = {}
				end
				
				marked[at][nextAt] = true
				at = nextAt
			end
		end
	end
end

local function doImport()
	if building then
		return
	end
	
	if not mockPlugin then
		debugMode = checkFlag("VMF_DEBUG")
	end
	
	local contents = promptOpenVmf()
	Debug3D:Clear()
	
	if #contents == 0 then
		return
	end
	
	totalSides = 0
	sidesDone = 0
	totalSolids = 0
	solidsDone = 0
	building = true
	
	status = "Reading VMF File..."
	startedAt = os.clock()
	
	local success, vmf = xpcall(Tree.fromVmf, handleError, contents)
	
	if not success then
		status = "Failed to read VMF file!"
		print(vmf)
		wait(1)
		
		building = false
		status = "Loading..."
		
		return
	end
	
	local built, worldMdl = xpcall(buildWorld, handleError, vmf)
	
	if built then
		local generated = xpcall(generateEntities, handleError, vmf, worldMdl)
		
		if generated then
			status = "Done!"
			reportMissingModels()
		end
		
		for _,desc in pairs(worldMdl:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Locked = true
			end
		end
	end
	
	wait(1)
	
	if not debugMode then
		Debug3D:Clear()
	end
	
	building = false
	status = "Loading..."
	
	if not mockPlugin then
		ChangeHistoryService:SetEnabled(true)
	end
end

if mockPlugin then
	doImport()
end

importVmf.Click:Connect(doImport)

-------------------------------------------------------------------------------------------------------------------------------