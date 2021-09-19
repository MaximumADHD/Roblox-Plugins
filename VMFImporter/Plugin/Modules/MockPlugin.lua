local MockPlugin = {}
MockPlugin.__index = MockPlugin

local MockToolbar = {}
MockToolbar.__index = MockToolbar

local MockButton = {}
MockButton.__index = MockButton

local CollectionService = game:GetService("CollectionService")

function MockPlugin.new()
	local deactivator = Instance.new("BindableEvent")
	local unloader = Instance.new("BindableEvent")
	
	local fakePlugin =
	{
		GridSize = 1;
		Name = "MockPlugin.rbxm";
		CollisionEnabled = false;
		
		Deactivation = deactivator.Event;
		Unloading = unloader.Event;
	}
	
	return setmetatable(fakePlugin, MockPlugin)
end

function MockPlugin:CreateToolbar(name)
	return setmetatable({}, MockToolbar)
end

function MockToolbar:CreateButton(buttonId, tooltip, iconName, text)
	local clicker = Instance.new("BindableEvent")
	local click = clicker.Event
	
	local button =
	{
		Event = clicker;
		Click = click;
		
		Icon = "";
		Enabled = true;
		
		ClickableWhenViewportHidden = false;
	}
	
	return setmetatable(button, MockButton)
end

function MockPlugin:Activate()
	-- stub
end

function MockPlugin:Deactivate()
	-- stub
end

function MockPlugin:SelectRibbonTool()
	-- stub
end

function MockPlugin:OpenScript()
	-- stub
end

function MockPlugin:StartDrag()
	-- stub
end

function MockPlugin:StartDecalDrag()
	-- stub
end

function MockPlugin:OpenWikiPage()
	-- stub
end

function MockButton:SetActive(active)
	-- stub
end

function MockPlugin:GetJoinMode()
	return Enum.JointCreationMode.All
end

function MockPlugin:GetSelectedRibbonTool()
	return Enum.RibbonTool.None
end

function MockPlugin:CreateDockWidgetPluginGui()
	return Instance.new("ScreenGui")
end

function MockPlugin:PromptForExistingAssetId()
	return -1
end

function MockPlugin:Union(parts)
	local unions = {}
	local negators = {}
	
	for i, part in ipairs(parts) do
		if CollectionService:HasTag(part, "__negate") then
			table.insert(negators, part)
		else
			table.insert(unions, part)
		end
		
		part.Parent = workspace
	end
	
	if #unions > 0 then
		local union = unions[1]:UnionAsync(unions)
		union.Parent = workspace
		
		for _,part in pairs(unions) do
			part.Parent = nil
		end
		
		if #negators > 0 then
			local negator = negators[1]:UnionAsync(negators)
			negator.Parent = workspace
			
			for _,part in pairs(negators) do
				part.Parent = nil
			end
			
			local endResult = union:SubtractAsync{negator}
			print(endResult)
			endResult.Parent = workspace
			
			union.Parent = nil
			union = endResult
		end
		
		return union
	end
end

function MockPlugin:Negate(parts)
	for _,part in pairs(parts) do
		if CollectionService:HasTag(part, "__negate") then
			CollectionService:RemoveTag(part, "__negate")
		else
			CollectionService:AddTag(part, "__negate")
		end
	end
	
	return parts
end

return MockPlugin