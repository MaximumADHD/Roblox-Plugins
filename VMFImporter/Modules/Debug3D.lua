local Debug3D = 
{
	Colors = 
	{
		Red    = Color3.new(1, 0, 0);
		Yellow = Color3.new(1, 1, 0);
		Green  = Color3.new(0, 1, 0);
		Cyan   = Color3.new(0, 1, 1);
		Blue   = Color3.new(0, 0, 1);
		Pink   = Color3.new(1, 0, 1);
		White  = Color3.new(1, 1, 1);
		Black  = Color3.new(0, 0, 0);
	}
}

local setPlayerGui = Instance.new("BindableEvent")
local adornSet = Instance.new("BindableEvent")
local debugAdorn

spawn(function ()
	while true do
		local playerGui = setPlayerGui.Event:Wait()
		debugAdorn = playerGui and playerGui:FindFirstChild("DebugAdorn")
		
		if debugAdorn then
			debugAdorn:ClearAllChildren()
		else
			debugAdorn = Instance.new("Part")
			debugAdorn.Name = "DebugAdorn"
			debugAdorn.Anchored = true
			debugAdorn.CanCollide = false
			debugAdorn.Transparency  = 1
			debugAdorn.Parent = playerGui
		end
		
		adornSet:Fire()
	end
end)

function Debug3D:DrawPoint(point, color, radius)
	while not debugAdorn do
		adornSet.Event:Wait()
	end
	
	if typeof(color) == "string" then
		color = self.Colors[color]
	end
	
	local dot = Instance.new("SphereHandleAdornment")
	dot.CFrame = CFrame.new(point)
	dot.Radius = radius or 0.4
	dot.Color3 = color or Color3.new(1,0,0)
	dot.ZIndex = 2
	dot.Adornee = debugAdorn
	dot.Parent = debugAdorn
	
	local dot2 = dot:Clone()
	dot2.AlwaysOnTop = true
	dot2.ZIndex = 1
	dot2.Transparency = 0.75
	dot2.Adornee = debugAdorn
	dot2.Parent = dot
	
	return dot
end

function Debug3D:DrawFlatPoint(point, dir, color, radius)
	while not debugAdorn do
		adornSet.Event:Wait()
	end
	
	if typeof(color) == "string" then
		color = self.Colors[color]
	end
	
	local dot = Instance.new("CylinderHandleAdornment")
	dot.CFrame = CFrame.new(point, point + dir)
	dot.Color3 = color or Color3.new(1, 0, 0)
	dot.Radius = radius or 0.4
	dot.Height = 0
	dot.ZIndex = 2
	dot.Adornee = debugAdorn
	dot.Parent = debugAdorn
	
	return dot
end

function Debug3D:DrawRay(ray, color)
	while not debugAdorn do
		adornSet.Event:Wait()
	end
	
	if typeof(color) == "string" then
		color = self.Colors[color]
	end

	local line = Instance.new("LineHandleAdornment")
	line.CFrame = CFrame.new(ray.Origin + (ray.Direction * 5000), ray.Origin)
	line.Length = 10000
	line.Color3 = color or Color3.new(1,1,1)
	line.Thickness = 3
	line.Adornee = debugAdorn
	line.Parent = debugAdorn
	
	local cone = Instance.new("ConeHandleAdornment")
	cone.CFrame = CFrame.new(ray.Origin,ray.Origin + ray.Direction)
	cone.Color3 = line.Color3
	cone.Adornee = debugAdorn
	cone.Parent = line
	
	line.Changed:Connect(function (property)
		if property ~= "CFrame" then
			pcall(function ()
				cone[property] = line[property]
			end)
		end
	end)
	
	return line
end

function Debug3D:DrawLine(a, b, color)
	while not debugAdorn do
		adornSet.Event:Wait()
	end
	
	if typeof(color) == "string" then
		color = self.Colors[color]
	end
		
	local line = Instance.new("LineHandleAdornment")
	line.CFrame = CFrame.new(a, b)
	line.Length = (b - a).Magnitude
	line.Thickness = 1
	line.AlwaysOnTop = false
	line.ZIndex = 2
	line.Color3 = color or Color3.new(0, 1, 1)
	line.Adornee = debugAdorn
	line.Parent = debugAdorn
	
	local line2 = line:Clone()
	line2.Transparency = 0.8
	line2.AlwaysOnTop = true
	line2.Thickness = 2
	line2.ZIndex = 1
	line2.Adornee = debugAdorn
	line2.Parent = line
	
	return line
end

function Debug3D:DrawPlane(plane, color)
	while not debugAdorn do
		adornSet.Event:Wait()
	end
	
	if typeof(color) == "string" then
		color = self.Colors[color]
	end
	
	local origin = plane.Normal * plane.Distance
	
	local box = Instance.new("BoxHandleAdornment")
	box.CFrame = CFrame.new(origin, origin + plane.Normal)
	box.Size = Vector3.new(100, 100, 0)
	box.Color3 = color or Color3.new(1,1,1)
	box.Transparency = 0.9
	box.Adornee = debugAdorn
	box.Parent = debugAdorn
	
	return box
end

function Debug3D:Clear()
	if debugAdorn then
		debugAdorn:ClearAllChildren()
	end
end

function Debug3D:SetPlayerGui(bin)
	playerGui = bin
	setPlayerGui:Fire(bin)
end

return Debug3D