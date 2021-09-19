local Polygon = {}
Polygon.__index = Polygon

local polyTemp = Instance.new("WedgePart")
polyTemp.BottomSurface = 0
polyTemp.Anchored = true
polyTemp.Name = "Poly"

local abs = math.abs
local min = math.min
local pi  = math.pi

local MIN_SIZE = 0.05
local IDENTITY = Vector3.new()

local BASE_ANGLE_1 = CFrame.Angles(pi,  0,  pi / 2)
local BASE_ANGLE_2 = CFrame.Angles(pi, pi, -pi / 2)

function Polygon:__newindex(k, v)
	assert(k ~= "CFrame" and k ~= "Size", k .. " is not a valid member. Use the Set method.")
	
	if self.Part1 then
		self.Part1[k] = v
	end
	
	if self.Part2 then
		self.Part2[k] = v
	end
end

function Polygon:Set(a: Vector3, b: Vector3, c: Vector3, srcNormal: Vector3?)
	--[[       edg1
		A ------|------>B  --.
		'\      |      /      \
		  \part1|part2/       |
		   \   cut   /       / Direction edges point in:
	       edg3 \       / edg2  /        (clockwise)
		     \     /      |/
		      \<- /        `
		       \ /
		        C
	--]]
	
	local ab, bc, ca = b-a, c-b, a-c
	local abm, bcm, cam = ab.Magnitude, bc.Magnitude, ca.Magnitude
	
	local edg1 = abs(.5 + ca:Dot(ab) / (abm^2))
	local edg2 = abs(.5 + ab:Dot(bc) / (bcm^2))
	local edg3 = abs(.5 + bc:Dot(ca) / (cam^2))
	
	-- Idea: Find the edge onto which the vertex opposite that
	-- edge has the projection closest to 1/2 of the way along that 
	-- edge. That is the edge thatwe want to split on in order to 
	-- avoid ending up with small "sliver" triangles with one very
	-- small dimension relative to the other one.
	
	if edg1 < edg2 then
		if edg1 < edg3 then
			-- min is edg1: less than both
			-- nothing to change
		else			
			-- min is edg3: edg3 < edg1 < edg2
			-- "rotate" verts twice counterclockwise
			a, b, c = c, a, b
			ab, bc, ca = ca, ab, bc
			abm = cam
		end
	else
		if edg2 < edg3 then
			-- min is edg2: less than both
			-- "rotate" verts once counterclockwise
			a, b, c = b, c, a
			ab, bc, ca = bc, ca, ab
			abm = bcm
		else
			-- min is edg3: edg3 < edg2 < edg1
			-- "rotate" verts twice counterclockwise
			a, b, c = c, a, b
			ab, bc, ca = ca, ab, bc
			abm = cam
		end
	end
	
	-- calculate lengths
	local len1 = -ca:Dot(ab) / abm
	local len2 = abm - len1
	
	-- calculate "base" CFrame to position parts by
	local back = -ab.Unit
	local top = ab:Cross(bc).Unit
	local right = top:Cross(back)
	
	local maincf = CFrame.fromMatrix(a, right, top, back)
	local width = (ca - back * len1).Magnitude
	
	local normal = (a - b):Cross(c - b).Unit
	local inset = normal * (MIN_SIZE / 2)
	
	-- If the source normal vector of the triangle was already known,
	-- test it against the one we calculated and flip the inset if needed.
	
	if srcNormal then
		local dotProd = normal:Dot(srcNormal)
		
		if dotProd > 0 then
			inset = -inset
		end
	end
	
	-- update parts
	local mPart1 = self.Part1
	mPart1.Size = Vector3.new(MIN_SIZE, width, len1)
	mPart1.CFrame = maincf * BASE_ANGLE_1 * CFrame.new(0, width / 2, len1 / 2) + inset
	
	local mPart2 = self.Part2
	mPart2.Size = Vector3.new(MIN_SIZE, width, len2)
	mPart2.CFrame = maincf * BASE_ANGLE_2 * CFrame.new(0, width / 2, -len1 - len2 / 2) + inset
end

function Polygon.new(a: Vector3, b: Vector3, c: Vector3, srcNormal: Vector3?)
	local poly =
	{
		Part1 = polyTemp:Clone();
		Part2 = polyTemp:Clone();
	}
	
	setmetatable(poly, Polygon)
	poly:Set(a, b, c, srcNormal)
	
	return poly
end

return Polygon
