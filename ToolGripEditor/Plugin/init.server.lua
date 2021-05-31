------------------------------------------------------------------------------------------------------
-- @ CloneTrooper1019, 2019
--   Tool Grip Editor v2.0!
------------------------------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------------------------------

local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local Studio = settings():GetService("Studio")
local Players = game:GetService("Players")

local modules = script.Modules
local editor = require(modules.ToolEditor)

local PLUGIN_NAME = "Tool Grip Editor"
local PLUGIN_ICON = "rbxassetid://4465723148"
local PLUGIN_SUMMARY = "A plugin which makes it much easier to edit the grip of a tool!"

local FOCAL_OFFSET = Vector3.new(1.5, 0.5, -2)
local IS_LOCAL = (plugin.Name:find(".rbxm") ~= nil)

local function getId(str)
	if IS_LOCAL then
		str ..= " (LOCAL)"
	end

	return str
end

------------------------------------------------------------------------------------------------------
-- Preview Window
------------------------------------------------------------------------------------------------------

local ui = script.UI

local preview, button do
	local pluginName = getId(PLUGIN_NAME)
	local widgetName = getId(script.Name)

	local config = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, false)
	preview = plugin:CreateDockWidgetPluginGui(widgetName, config)
	preview.ZIndexBehavior = "Sibling"
	preview.Title = pluginName
	preview.Name = widgetName
	
	if not _G.Toolbar2032622 then
		_G.Toolbar2032622 = plugin:CreateToolbar("CloneTrooper1019")
	end

	local buttonId = getId("ToolGripEditorButton")
	button = _G[buttonId]
	
	if not button then
		button = _G.Toolbar2032622:CreateButton(pluginName, PLUGIN_SUMMARY, PLUGIN_ICON)
		_G[buttonId] = button
	end
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

local inputSink = ui.InputSink
inputSink.Parent = preview

local enterUsername = ui.EnterUsername
enterUsername.Parent = preview

local function updateTheme()
	local theme = Studio.Theme
	local input = enterUsername.Input

	local mainBG = theme:GetColor("MainBackground")
	local mainText = theme:GetColor("MainText")

	enterUsername.BackgroundColor3 = mainBG
	enterUsername.TextColor3 = mainText

	vpFrame.BackgroundColor3 = mainBG
	input.TextColor3 = mainText

	input.BackgroundColor3 = theme:GetColor("InputFieldBackground")
	input.BorderColor3 = theme:GetColor("InputFieldBorder")
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

local function updateWindow(delta)
	if not preview.Enabled then
		return
	end

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
		local ghostArm = editor.GhostArm
		local rightGrip = editor.RightGrip
		local directHandle = editor.DirectHandle
		
		if directHandle and rightGrip and ghostArm then
			local cf = directHandle.CFrame 
				* rightGrip.C1
				* rightGrip.C0:Inverse()
			
			ghostArm:SetPrimaryPartCFrame(cf)
		end
	end
end

updateTheme()

editor:SetParent(vpFrame)
editor:StartAnimations()

Studio.ThemeChanged:Connect(updateTheme)
RunService.Heartbeat:Connect(updateWindow)

------------------------------------------------------------------------------------------------------
-- Plugin Menu
------------------------------------------------------------------------------------------------------

local input = enterUsername.Input

local function newId()
	return HttpService:GenerateGUID()
end

local function onFocusLost(enterPressed)
	enterUsername.Visible = false

	if enterPressed then
		local userName = input.Text

		if userName == "" then
			warn("No username was entered!")
			return
		end

		warn("Fetching UserId...")
		
		local gotUserId, userId = pcall(function ()
			return Players:GetUserIdFromNameAsync(userName)
		end)

		if not gotUserId then
			warn("Could not find an account associated with", userName .. '!')
			return
		end

		warn("Loading appearance...")

		local success, hDesc = pcall(function ()
			return Players:GetHumanoidDescriptionFromUserId(userId)
		end)

		if not success then
			warn("Could not get a HumanoidDescription for", userName, "at this time!")
			return
		end

		editor:ApplyDescription(hDesc)
		Selection:Set{}

		warn("Done!")
	end
end

local function onInputBegan(inputObject)
	local inputType = inputObject.UserInputType
	
	if inputType.Name == "MouseButton2" then
		local menuId = getId("TGE_Menu")
		local menu = plugin:CreatePluginMenu(menuId)

		local fromSelection = menu:AddNewAction(newId(), "Set appearance from selected HumanoidDescription")
		local fromUsername  = menu:AddNewAction(newId(), "Set appearance from entered Username")
		
		local selected = menu:ShowAsync()
		menu:Destroy()
		
		if selected == fromSelection then
			local set = false

			for _,target in pairs(Selection:Get()) do
				if target:IsA("HumanoidDescription") then
					editor:ApplyDescription(target)
					set = true

					break
				end
			end

			if not set then
				warn("Select a HumanoidDescription before using this action!")
			end
		elseif selected == fromUsername then
			enterUsername.Visible = true
			input:CaptureFocus()
			input.Text = ""
		end
	end
end

input.FocusLost:Connect(onFocusLost)
inputSink.InputBegan:Connect(onInputBegan)

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
		elseif object:IsA("BasePart") then
			tool = object:FindFirstAncestorWhichIsA("Tool")
			
			if tool then
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
-- Buttons
------------------------------------------------------------------------------------------------------

local enabledChanged = preview:GetPropertyChangedSignal("Enabled")
local dummyPos = UDim2.new()

local function updateButton()
	button:SetActive(preview.Enabled)
end

local function onButtonClicked()
	preview.Enabled = not preview.Enabled
	
	if preview.Enabled then
		-- Check if we have a tool selected.
		onSelectionChanged()
	end
end

for _,btn in pairs(ribbonTools:GetChildren()) do
	if btn:IsA("TextButton") then
		btn.MouseButton1Down:Connect(function ()
			plugin:SelectRibbonTool(btn.Name, dummyPos)
		end)
	end
end

updateButton()
enabledChanged:Connect(updateButton)
button.Click:Connect(onButtonClicked)

------------------------------------------------------------------------------------------------------