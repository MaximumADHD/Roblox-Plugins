local Tree = {}

function Tree:GetItems()
	local children = rawget(self, "_children")
	return children or {}
end

function Tree:GetItemsOfType(itemType)
	local itemType = itemType:lower()
	local results = {}
	
	for _,item in pairs(self:GetItems()) do
		if tostring(item.type):lower() == itemType then
			table.insert(results, item)
		end
	end
	
	return results
end

function Tree:AddItem(item)
	local items = rawget(self, "_children")
	
	if not items then
		items = {}
		rawset(self, "_children", items)
	end
	
	table.insert(items, item)
end

function Tree:__index(key)
	local func = rawget(Tree, key)
	
	if typeof(func) == "function" then
		return func
	else
		for _,item in pairs(self:GetItems()) do
			if item.type == key then
				return item
			end
		end
	end
end

function Tree:__tostring()
	return self.type
end

function Tree.new(itemType)
	local tree =
	{ 
		type = itemType;
		_children = {};
	}
	
	return setmetatable(tree, Tree)
end

function Tree.fromVmf(contents)
	local vmf = Tree.new("VMF")
	
	local stack = {}
	stack[0] = vmf
	
	for line in contents:gmatch("[^\r\n]+") do
		if #line == 0 then
			continue
		end
		
		-- Remove tabs to determine what level we're on.
		local level = 0
		
		line = line:gsub("^[\t]+", function (stack)
			level = #stack
			return ""
		end)
		
		local base = stack[level]
		local key, value = line:match('"(.+)" "(.+)"')
		
		if key and value then
			base[key] = tonumber(value) or value
		else
			local entryName = line:match("^[A-Za-z0-9_]+")
			
			if entryName then
				local entry = Tree.new(entryName)
				base:AddItem(entry)
				
				stack[level + 1] = entry
			end
		end
	end
	
	return vmf	
end

return Tree

-------------------------------------------------------------------------------------------------------------