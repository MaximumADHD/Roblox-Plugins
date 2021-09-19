local Winding = {}
Winding.__index = Winding

local Debug3D = require(script.Parent.Debug3D)
local debugMode = false

local MAX_POINTS_ON_WINDING = 128
local SPLIT_EPSILON = 0.01

local ON_PLANE_EPSILON = 0.5
local ROUND_VERTEX_EPSILON = 0.01
local MIN_EDGE_LENGTH_EPSILON = 0.1

local MAX_COORD_INTEGER = 1024
local COORD_EXTENT = 2 * MAX_COORD_INTEGER
local MAX_TRACE_LENGTH = COORD_EXTENT * math.sqrt(3)

local SIDE_FRONT = 1
local SIDE_BACK = 2
local SIDE_ON = 3

local DEFAULT_VECTOR = Vector3.new()
local AXIS_X = Vector3.new(1, 0, 0)
local AXIS_Y = Vector3.new(0, 1, 0)

function Winding.new(maxPoints: number?)
	local maxPoints = maxPoints or 0
	assert(maxPoints <= MAX_POINTS_ON_WINDING)
	
	local winding = 
	{
		NumPoints = 0; -- None are occupied yet, even though allocated.
		Points = table.create(maxPoints, DEFAULT_VECTOR)
	}
	
	return setmetatable(winding, Winding)
end

function Winding:AddPoint(point: Vector3)
	self.NumPoints += 1
	self.Points[self.NumPoints] = point
end

function Winding:RemoveDuplicates(fMinDist: number)
	local points = self.Points
	local i = 1
	
	while i <= self.NumPoints do
		local j = i + 1
		
		while j <= self.NumPoints do
			local edge = points[i] - points[j]
			
			if edge.Magnitude < fMinDist then
				table.remove(points, j)
				self.NumPoints -= 1
			else
				j += 1
			end
		end
		
		i += 1
	end
end

function Winding:Copy()
	local numPoints = self.NumPoints
	local copy = Winding.new(numPoints)
	
	for i = 1, numPoints do
		local point = self.Points[i]
		copy:AddPoint(point)
	end
	
	return copy
end

function Winding:Clip(splitPlane)
	local points = self.Points
	local numPoints = self.NumPoints
	
	local splitNorm = splitPlane.Normal
	local splitDist = splitPlane.Distance
	
	local dists  = table.create(MAX_POINTS_ON_WINDING, 0)
	local sides  = table.create(MAX_POINTS_ON_WINDING, 0)
	local counts = table.create(3, 0)
	
	for i = 1, numPoints do
		local point = points[i]
		local dot = point:Dot(splitNorm)
		
		dot -= splitDist
		dists[i] = dot
		
		if dot > SPLIT_EPSILON then
			sides[i] = SIDE_FRONT
		elseif dot < -SPLIT_EPSILON then
			sides[i] = SIDE_BACK
		else
			sides[i] = SIDE_ON
		end
		
		local side = sides[i]
		counts[side] += 1
		
		if debugMode then
			if side == SIDE_FRONT then
				Debug3D:DrawFlatPoint(point, splitNorm, "Green", 0.2)
			elseif side == SIDE_ON then
				Debug3D:DrawFlatPoint(point, splitNorm, "Blue", 0.2)
			elseif side == SIDE_BACK then
				Debug3D:DrawFlatPoint(point, splitNorm, "Red", 0.2)
			end
		end
	end
	
	local noFronts = (counts[SIDE_FRONT] == 0)
	local noBacks  = (counts[SIDE_BACK]  == 0)
	
	sides[numPoints + 1] = sides[1]
	dists[numPoints + 1] = dists[1]
	
	if (noFronts and noBacks) then
		return self
	elseif noFronts then
		return nil
	elseif noBacks then
		return self
	end
	
	local maxPoints = (numPoints + 4)
	local clip = Winding.new(maxPoints)
	
	for i = 1, numPoints do
		local p1 = points[i]
		
		if sides[i] == SIDE_FRONT or sides[i] == SIDE_ON then
			clip:AddPoint(p1)
			
			if sides[i] == SIDE_ON then
				continue
			end
		end
		
		if sides[i + 1] == SIDE_ON or sides[i + 1] == sides[i] then
			continue
		end
		
		-- generate a split point
		local dot = dists[i] / (dists[i] - dists[i + 1])
		local p2
		
		if i == numPoints then
			p2 = points[1]
		else
			p2 = points[i + 1]
		end
		
		local mid = p1:Lerp(p2, dot)
		clip:AddPoint(mid)
	end
	
	if clip.NumPoints > maxPoints then
		error("ClipWinding: points exceeded estimate")
	end
	
	return clip
end

function Winding:Draw()
	local points = self.Points
	local numPoints = self.NumPoints
	
	for i = 1, numPoints do
		local j = (i % numPoints) + 1
		local p0, p1 = points[i], points[j]		
		Debug3D:DrawLine(p0, p1, "Black")
	end
end

function Winding.fromPlane(plane)
	local normal = plane.Normal
	
	-- find the major axis
	local max = -2^16
	local up
	
	for _,axis in pairs(Enum.Axis:GetEnumItems()) do
		local value = normal[axis.Name]
		value = math.abs(value)
		
		if value > max then
			up = axis
			max = value
		end
	end
	
	if up then
		if up.Name == 'Y' then
			up = AXIS_X
		else
			up = AXIS_Y
		end
	else
		error("BasePolyForPlane: no axis found")
	end
	
	local scale = -up:Dot(normal)
	up = (up + normal * scale).Unit
	
	local origin = normal * plane.Distance
	local right = up:Cross(normal)
	
	up *= MAX_TRACE_LENGTH
	right *= MAX_TRACE_LENGTH
	
	-- project a really big axis aligned box onto the plane
	local winding = Winding.new(4)
	winding.NumPoints = 4;
	
	winding.Points =
	{
		(origin - right) + up;
		(origin + right) + up;
		(origin + right) - up;
		(origin - right) - up;
	}
	
	return winding
end

return Winding