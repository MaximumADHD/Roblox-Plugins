------------------------------------------------------------------------------------------------------
-- @ CloneTrooper1019, 2019
--   Tool Grip Editor v2.0!
------------------------------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------------------------------

local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local Studio = settings():GetService("Studio")

local modules = script.Modules
local editor = require(modules.ToolEditor)

local PLUGIN_NAME = "Tool Grip Editor"
local PLUGIN_ICON = "rbxassetid://4465723148"
local PLUGIN_SUMMARY = "A plugin which makes it much easier to edit the grip of a tool!"

local FOCAL_OFFSET = Vector3.new(1.5, 0.5, -2)

if plugin.Name:find(".rbxm") then
	PLUGIN_NAME = PLUGIN_NAME .. " (LOCAL)"
end

------------------------------------------------------------------------------------------------------
-- Preview Window
------------------------------------------------------------------------------------------------------

local ui = project.UI

local preview, button do
	local config = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, false)
	preview = plugin:CreateDockWidgetPluginGui(project.Name, config)
	preview.Title = PLUGIN_NAME
	preview.Name = project.Name
	
	local toolbar = plugin:CreateToolbar("CloneTrooper1019")
	button = toolbar:CreateButton(PLUGIN_NAME, PLUGIN_SUMMARY, PLUGIN_ICON)
end

local camera = Instance.new("Camera")
camera.FieldOfView = 60
camera.Parent = preview

local vpFrame = Instance.new("ViewportFrame")
vpFrame.LightColor = Color3.new(1, 1, 1)
vpFrame.Size = UDim2.new(1, 0, 1, 0)
vpFrame.CurrentCamera = camera
vpFrame.Parent = preview

local editButton = ui.EditButton
editButton.Parent = preview

local selectATool = ui.SelectATool
selectATool.Parent = preview

local ribbonTools = ui.RibbonTools
ribbonTools.Parent = preview

local function updateTheme()
	local theme = Studio.Theme
	vpFrame.BackgroundColor3 = theme:GetColor("MainBackground")
end

local function getCameraLookVector()
	local studioCam = workspace.CurrentCamera
	return studioCam.CFrame.LookVector
end

local function updateRibbonButtons(selectedTool)
	for _,button in pairs(ribbonTools:GetChildren()) do
		if button:IsA("TextButton") then
			if button.Name == selectedTool.Name then
				button.Style = "RobloxRoundDefaultButton"
			else
				button.Style = "RobloxRoundButton"
			end
		end
	end
end

local function updatePreview(delta)
	if preview.Enabled then
		-- Update the animations
		if RunService:IsEdit() then
			editor:StepAnimator(delta)
		end
		
		-- Update the camera
		local rootPart = editor.RootPart
		local extents = editor:GetCameraZoom()

		local lookVector = getCameraLookVector()
		local focus = rootPart.CFrame

		if editor.Tool then
			focus = focus * FOCAL_OFFSET
		else
			focus = focus.Position
		end
		
		local goal = CFrame.new(focus - (lookVector * extents), focus)
		camera.CFrame = camera.CFrame:Lerp(goal, math.min(1, delta * 20))
		vpFrame.LightDirection = lookVector
		
		-- Update the ribbon buttons
		if ribbonTools.Visible then
			local selectedTool = plugin:GetSelectedRibbonTool()
			local currentTool = editor.LastRibbonTool

			if currentTool ~= selectedTool then
				editor.LastRibbonTool = selectedTool
				updateRibbonButtons(selectedTool)
			end
		end

		-- Update the ghost arm
		if editor.InUse then
			local handle = editor.DirectHandle
			local rightGrip = editor.RightGrip
			local ghostArm = editor.GhostArm

			if handle and rightGrip and ghostArm then
				local cf = handle.CFrame * rightGrip.C1 * rightGrip.C0:Inverse()
				ghostArm:SetPrimaryPartCFrame(cf)
			end
		end
	end
end

updateTheme()

editor:SetParent(vpFrame)
editor:StartAnimations()

Studio.ThemeChanged:Connect(updateTheme)
RunService.Heartbeat:Connect(updatePreview)

------------------------------------------------------------------------------------------------------
-- Buttons
------------------------------------------------------------------------------------------------------

local enabledChanged = preview:GetPropertyChangedSignal("Enabled")

local function updateButton()
	button:SetActive(preview.Enabled)
end

local function onButtonClicked()
	preview.Enabled = not preview.Enabled
end

for _,riButton in pairs(ribbonTools:GetChildren()) do
	if riButton:IsA("TextButton") then
		local function onActivated()
			plugin:SelectRibbonTool(riButton.Name, UDim2.new())
		end
		
		riButton.Activated:Connect(onActivated)
	end
end

updateButton()

enabledChanged:Connect(updateButton)
button.Click:Connect(onButtonClicked)

------------------------------------------------------------------------------------------------------
-- Tool Mounting
------------------------------------------------------------------------------------------------------

local function onSelectionChanged()
	if not preview.Enabled or editor.InUse then
		return
	end

	local tool

	for _,object in pairs(Selection:Get()) do
		if object:IsA("Tool") then
			tool = object
			break
		elseif object:IsA("BasePart") and object.Name == "Handle" then
			local parent = object.Parent

			if parent and parent:IsA("Tool") then
				tool = parent
				break
			end
		end
	end
	
	local mounted = editor:BindTool(tool)
	selectATool.Visible = (not mounted)
	editButton.Visible = mounted
end

local function onEditActivated()
	if not editor.InUse then
		editButton.Visible = false
		ribbonTools.Visible = true

		editor:EditGrip(plugin)

		editButton.Visible = true
		ribbonTools.Visible = false
	else
		Selection:Set{editor.Tool}
		editor.InUse = false
	end
end

editButton.Activated:Connect(onEditActivated)
Selection.SelectionChanged:Connect(onSelectionChanged)

------------------------------------------------------------------------------------------------------