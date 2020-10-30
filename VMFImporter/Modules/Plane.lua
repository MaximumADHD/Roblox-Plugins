-------------------------------------------------------------------------------------------------------------

local Plane = {}
Plane.__index = Plane

local function isFinite(num: number)
	return num == num and num ~= -1/0 and num ~= 1/0
end

local function isVector3Finite(v3: Vector3)
	return isFinite(v3.X) and isFinite(v3.Y) and isFinite(v3.Z)
end

function Plane:GetRayIntersection(ray: Ray)
	local dotProd = ray.Direction:Dot(self.Normal)
	local t = -((-self.Distance) + ray.Origin:Dot(self.Normal)) / dotProd
	return ray.Origin + ray.Direction * t
end

function Plane:ProjectPoint(point: Vector3)
	local ray = Ray.new(point, self.Normal)
	return self:GetRayIntersection(ray)
end

function Plane:DistanceFrom(point: Vector3)
	local offset = self.CFrame:PointToObjectSpace(point)
	return -offset.Z
end

function Plane:IsCoplanarWith(otherPlane: any)
    local normal
    
	if typeof(otherPlane) == "Vector3" then
		normal = otherPlane.Unit
	else
		normal = otherPlane.Normal
	end
	
	local result = math.abs(self.Normal:Dot(normal))
	return result >= 0.999
end

-------------------------------------------------------------------------------------------------------------

function Plane.new(a: Vector3, b: Vector3, c: Vector3)
    local origin = (a + b + c) / 3
    local normal = (a - b):Cross(c - b).Unit
    
    local plane = 
    {
        A = a;
        B = b;
        C = c;
        
        Origin = origin;
        Normal = normal;

        Ray = Ray.new(origin, normal);
        CFrame = CFrame.new(origin, origin + normal);
    }
    
	return setmetatable(plane, Plane)
end

function Plane.fromVmf(plane: string, unitsPerStud: number?)
	local unitsPerStud = unitsPerStud or 16
	local samples = {}
	
	for x, y, z in plane:gmatch("%((%S+) (%S+) (%S+)%)") do
		local point = Vector3.new(tonumber(x), tonumber(z), -tonumber(y)) / unitsPerStud
		table.insert(samples, point)
	end
	
	local a, b, c = unpack(samples)
	return Plane.new(a, b, c)
end

return Plane

-------------------------------------------------------------------------------------------------------------