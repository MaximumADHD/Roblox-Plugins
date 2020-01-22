local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Modules = script.Parent
local Project = Modules.Parent

local FFlags = require(Modules.FFlags)

local ToolEditor = {}
ToolEditor.__index = ToolEditor

local function createDummy()
    -- CAUTION: This will likely break in the future.
    return game:GetObjects("rbxasset://avatar/characterR15V3.rbxm")[1]
end

function ToolEditor.new()
    local dummy = createDummy()
    
    local humanoid = dummy:WaitForChild("Humanoid")
    humanoid:BuildRigFromAttachments()

    local animator = Instance.new("Animator")
    animator.Parent = humanoid
    
    local editor = 
    {
        Dummy = dummy;
        Humanoid = humanoid;

        Animator = animator;
        RootPart = humanoid.RootPart;
    }

    editor.RootPart.Anchored = true
    setmetatable(editor, ToolEditor)

    if FFlags.AllowWorldModelCreationV2 then
        local worldModel = Instance.new("WorldModel")
        editor.WorldModel = worldModel

        dummy.Parent = worldModel
    else
        local arm = dummy.RightUpperArm
        local armCF = arm.CFrame
        local limbOffsets = {}
        
        for _,part in pairs(dummy:GetChildren()) do
            if part:IsA("BasePart") then
                local limb = humanoid:GetLimb(part)

                if limb.Name == "RightArm" then
                    local partCF = part.CFrame
                    limbOffsets[part] = armCF:ToObjectSpace(partCF)
                end
            end
        end

        arm.CFrame = armCF
                   * CFrame.new(0, 0.15, -0.1)
                   * CFrame.Angles(math.pi / 2, 0, 0)
        
        for part, offset in pairs(limbOffsets) do
            part.CFrame = arm.CFrame * offset
        end
    end

    return editor
end

function ToolEditor:GetContainer()
    local target = self.WorldModel

    if not target then
        target = self.Dummy
    end

    return target
end 

function ToolEditor:SetParent(parent)
    local target = self:GetContainer()
    target.Parent = parent
end

function ToolEditor:FindObject(className, name)
    local child = self.Dummy:FindFirstChild(name, true)

    if child and child:IsA(className) then
        return child
    end
end

function ToolEditor:FindLimb(limbName)
    return self:FindObject("BasePart", limbName)
end

function ToolEditor:FindJoint(jointName)
    return self:FindObject("JointInstance", jointName)
end

function ToolEditor:FindAttachment(attName)
    return self:FindObject("Attachment", attName)
end

function ToolEditor:GetCameraZoom()
    local handle = self.Handle

    if handle then
        local size = handle.Size
        return math.max(4, size.Magnitude * 1.5)
    end

    local cf, size = self.Dummy:GetBoundingBox()
    return size.Magnitude
end

function ToolEditor:StepAnimator(delta)
    local animator = self.Animator
    animator:StepAnimations(delta)
end

function ToolEditor:StartAnimations()
    if not FFlags.AllowWorldModelCreationV2 then
        return
    end

    local anims = Project.Animations
    local animator = self.Animator

    for _,track in pairs(animator:GetPlayingAnimationTracks()) do
        track:Stop()
    end

    for _,anim in pairs(anims:GetChildren()) do
        local track = animator:LoadAnimation(anim)
        track:Play()
    end
end

function ToolEditor:Connect(name, event)
    return event:Connect(function (...)
        self[name](self, ...)
    end)
end

function ToolEditor:BindProperty(object, property, funcName)
    local event = object:GetPropertyChangedSignal(property)
    return self:Connect(funcName, event)
end

function ToolEditor:RefreshGrip()
    local rightGrip = self.RightGrip
    local handle = self.Handle
    local tool = self.Tool

    if rightGrip and handle then
        local grip = tool.Grip
        rightGrip.C1 = grip
        
        if not FFlags.AllowWorldModelCreationV2 then
            local rightHand = rightGrip.Parent
            handle.CFrame = rightHand.CFrame * rightGrip.C0 * grip:Inverse()
        end
    end
end

function ToolEditor:ReflectGrip()
    local tool = self.Tool
    local gripEditor = self.GripEditor

    if tool and gripEditor then
        tool.Grip = gripEditor.CFrame
    end
end

function ToolEditor:ClearTool()
    if self.GripRefresh then
        self.GripRefresh:Disconnect()
        self.GripRefresh = nil
    end

    if self.GripReflect then
        self.GripReflect:Disconnect()
        self.GripReflect = nil
    end

    if self.Handle then
        self.Handle:Destroy()
        self.Handle = nil
    end

    if self.GripEditor then
        self.GripEditor:Destroy()
        self.GripEditor = nil
    end

    if self.RightGrip then
        self.RightGrip.Part1 = nil
    end

    self.Tool = nil
end

function ToolEditor:CreateGhostArm()
    local dummy = createDummy()
    local humanoid = dummy.Humanoid
    
    for _,child in pairs(dummy:GetChildren()) do
        if child:IsA("BasePart") then
            local limb = humanoid:GetLimb(child)

            if limb == Enum.Limb.RightArm then
                child:ClearAllChildren()
                child.Anchored = true
                child.Locked = true
                
                if child.Name == "RightHand" then
                    dummy.PrimaryPart = child
                end
            else
                child:Destroy()
            end
        end
    end

    dummy.Archivable = false
    dummy.Name = "PreviewArm"

    return dummy
end

function ToolEditor:BindTool(tool)
    if tool == nil then
        self:ClearTool()
        return false
    end

    if self.Tool == tool then
        return true
    elseif self.Tool ~= nil then
        self:ClearTool()
    end

    local handle = tool:FindFirstChild("Handle")
    
    if not (handle and handle.Archivable and handle:IsA("BasePart")) then
        return
    end
    
    local rightHand = self:FindLimb("RightHand")
    local rightGrip = self.RightGrip
    
    if not rightGrip then
        local gripAtt = self:FindAttachment("RightGripAttachment")

        rightGrip = Instance.new("Motor6D")
        rightGrip.C0 = gripAtt.CFrame
        rightGrip.Name = "RightGrip"
        rightGrip.Part0 = rightHand
        rightGrip.Parent = rightHand

        self.RightGrip = rightGrip
    end

    local newHandle = handle:Clone()
    newHandle.Parent = self.Dummy
    newHandle.Anchored = false

    rightGrip.Part1 = newHandle

    local gripEditor = Instance.new("Attachment")
    gripEditor.CFrame = tool.Grip
    gripEditor.Archivable = false
    gripEditor.Name = "Grip"

    self.GripRefresh = self:BindProperty(tool, "Grip", "RefreshGrip")
    self.GripReflect = self:BindProperty(gripEditor, "CFrame", "ReflectGrip")
    
    self.GripEditor = gripEditor
    self.DirectHandle = handle
    
    self.Handle = newHandle
    self.Tool = tool

    self:RefreshGrip()

    return (self.Handle ~= nil)
end

function ToolEditor:EditGrip(plugin)
    local tool = self.Tool
    local handle = self.DirectHandle
    local gripEditor = self.GripEditor

    if tool and handle and gripEditor then
        gripEditor.Parent = handle
        self.InUse = true

        if not tool:IsDescendantOf(workspace) then
            handle.Parent = workspace
            Selection:Set{}
        end

        local camera = workspace.CurrentCamera
        local locked = handle.Locked

        if camera then
            local cf = camera.CFrame
            local focus = gripEditor.WorldPosition

            local lookVector = cf.LookVector
            local extents = handle.Size.Magnitude

            camera.CFrame = CFrame.new(focus - (lookVector * extents * 1.5), focus)
            camera.Focus = CFrame.new(focus)
        end

        local ghostArm = self:CreateGhostArm()
        ghostArm.Parent = handle
        self.GhostArm = ghostArm
        
        handle.Locked = true
        Selection:Set{gripEditor}
        
        if plugin:GetSelectedRibbonTool() ~= Enum.RibbonTool.Move then
            plugin:SelectRibbonTool("Move", UDim2.new())
        end

        ChangeHistoryService:SetWaypoint("Begin Grip Edit")
        Selection.SelectionChanged:Wait()

        ghostArm.Parent = nil
        self.GhostArm = nil

        gripEditor.Parent = nil

        handle.Parent = tool
        handle.Locked = locked

        ChangeHistoryService:SetWaypoint("End Grip Edit")
        self.InUse = false
    end
end

-----------------------------------------------------------
-- TODO: If this module is ever constructed multiple times
--       then return the ToolEditor table itself. At the
--       present moment, it acts more like a singleton.
-----------------------------------------------------------

return ToolEditor.new()