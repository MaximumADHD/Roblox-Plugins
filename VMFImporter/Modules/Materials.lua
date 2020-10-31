local Materials = 
{
	Missing = {};
	
	Stub = 
	{ 
		MISSING = true;
		Material = "Plastic";
		Color = Color3.new(.7, .7, .7);
	};
}

local ServerStorage = game:GetService("ServerStorage")
local Linker = {}
local Map = {}

function Linker:__index(key)
	local link = rawget(self, "__link")
	local result
	
	local success, at = pcall(function ()
		return link[key]		
	end)
	
	if success then
		result = at
		
		if typeof(at) == "Instance" then
			if at:IsA("ValueBase") then
				local anyCast: any = at
				result = anyCast.Value
			end
		end
		
		rawset(self, key, result)
	end
	
	return result
end

function Map:__index(key)
	local key = key:lower()
	local value = rawget(self, key)
	local newKey
	
	if not value then
		local bestMatName, bestCut
		
		for matName, data in pairs(self) do
			local matchA, matchB = key:find(matName)
			
			if matchA and matchB then
				local cut = (matchB - matchA) / #key
				
				if bestMatName == nil or cut > bestCut then
					bestMatName = matName
					bestCut = cut
				end
			end
		end
		
		newKey = bestMatName
		value = rawget(self, bestMatName)
	end
	
	if value then
		if value.Parent and value.Parent.Name == "generic" then
			warn("using generic fallback for material", key, "->", newKey)	
		end
		
		rawset(self, key, value)
	end
	
	return value
end


function Linker.new(object)
	local linker = { __link = object }
	return setmetatable(linker, Linker)
end

function Materials:Connect(funcName, event)
	return event:Connect(function (...)
		self[funcName](self, ...)
	end)
end

function Materials:OnDescendantAdded(desc)
	local target
	
	if desc:IsA("Folder") then
		local valueBase = desc:FindFirstChildWhichIsA("ValueBase")
		
		if valueBase then
			target = desc
		end
	elseif desc:IsA("ValueBase") then
		local parent = desc.Parent
		
		if parent and parent:IsA("Folder") then
			target = parent
		end
	end
	
	if not target then
		return
	end
	
	local key = target.Name
	local at = target
	
	while at ~= nil do
		local checkPath
		at = at.Parent
		
		if not at then
			break
		end
		
		if at.Name == "generic" then
			checkPath = at.Parent
		elseif at.Name == "Materials" then
			checkPath = at
		end
		
		if checkPath then
			local path = checkPath:GetFullName()
			
			if path == "ServerStorage.VMF Importer.Materials" then
				break
			end
		end
		
		key = at.Name .. '/' .. key
	end
	
	if not self.Map then
		self.Map = setmetatable({}, Map)
	end
	
	self.Map[key] = Linker.new(target)
end

function Materials:GetMap()
	local vmf = self.VmfFolder
	
	if vmf and vmf.Parent ~= ServerStorage then
		vmf = nil
	end
	
	if not vmf then
		vmf = ServerStorage:FindFirstChild("VMF Importer")
		
		if not vmf then
			vmf = Instance.new("Folder")
			vmf.Name = "VMF Importer"
			vmf.Parent = ServerStorage
		end
		
		self.VmfFolder = vmf
	end
	
	local materials = self.MaterialFolder 
	
	if materials and materials.Parent ~= vmf then
		materials = nil
	end
	
	if not materials then
		local modules = script.Parent
		local root = modules.Parent
		
		materials = vmf:FindFirstChild("Materials")
		self.Map = nil
		
		if not materials then
			materials = root.Materials:Clone()
			materials.Parent = vmf
		end
		
		for _,desc in pairs(materials:GetDescendants()) do
			self:OnDescendantAdded(desc)
		end
		
		self:Connect("OnDescendantAdded", materials.DescendantAdded)
		self.MaterialFolder = materials
	end
	
	return self.Map
end

function Materials:Get(material, alpha)
	local map = self:GetMap()
	
	local material = material:lower()
	local data = map[material]
	
	if data then
		if data.BlendTarget_A and data.BlendTarget_B then
			local alpha = alpha or 255
			alpha = math.clamp(alpha, 0, 255) -- some bad apples come up periodically
			
			if data.Blended then
				data = data.Samples
			end
			
			local pickId = 65 + math.floor(alpha / 255)
			local pick = data["BlendTarget_" .. string.char(pickId)]
			
			if pick then
				local pickData = self.Map[pick.Name]
				return pickData, pick.Name
			end
		else
			return data, material
		end
	else
		if not self.Missing[material] then
			self.Missing[material] = true
			warn("No matching material data was found for material:", material)
		end
		
		return self.Stub, "MISSING_MTL"
	end
end

return Materials