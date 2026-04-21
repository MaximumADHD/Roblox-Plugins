local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local Components = script.Parent
local Root = Components.Parent
local Packages = Root.Packages

local Guid = require(Packages.Guid)
local React = require(Packages.React)
local Signal = require(Packages.Signal)
local ReactRoblox = require(Packages.ReactRoblox)

local Hooks = Root.Hooks
local useTheme = require(Hooks.useTheme)
local usePlugin = require(Hooks.usePlugin)
local useProperty = require(Hooks.useProperty)
local useSelection = require(Hooks.useSelection)

local Util = Root.Util
local ChangeHistory = require(Util.ChangeHistory)
local DecalProjector = require(Util.DecalProjector)

type Mode = 
    | "Verts"
    | "Edges"
    | "Faces"
    | "Parts"

type Signal<T...> = Signal.Signal<T...>

local function Header(props)
    local theme = useTheme()

    return React.createElement("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        TextColor3 = theme.MainText.Default,
        Font = Enum.Font.SourceSansBold,
        TextSize = 24,
        Text = props.Text,
    }) :: React.Node
end

local function Button(props)
    local theme = useTheme()

    return React.createElement("TextButton", {
        Size = props.Size or UDim2.new(1, 0, 0, 30),

        BackgroundColor3 = 
            if props.Enabled == false then
                theme.Button.Disabled
            elseif props.Active then
                theme.Button.Selected
            else
                theme.Button.Default,
        
        BorderSizePixel = 0,
        Text = "",

        [React.Event.Activated] = props.OnActivated,
    }, {
        Corner = React.createElement("UICorner", {
            CornerRadius = UDim.new(0, 4),
        }),

        Label = React.createElement("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            TextColor3 = theme.MainText.Default,
            Font = Enum.Font.SourceSans,
            TextSize = props.TextSize or 18,
            Text = props.Text,
        }),
    } :: any) :: React.Node
end

local function Divider()
    local theme = useTheme()

    return React.createElement("Frame", {
        Size = UDim2.new(1, 8, 0, 16),
        BackgroundTransparency = 1,
    }, {
        Line = React.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.fromScale(0.5, 2 / 3),
            AnchorPoint = Vector2.new(0.5, 2 / 3),

            BackgroundColor3 = theme.Light.Default,
            BorderSizePixel = 0,
        }),
    } :: any) :: React.Node
end

local function RibbonTool(props: { RibbonTool: Enum.RibbonTool, OnActivated: (rbx: any) -> () })
    local plugin = usePlugin()

    return React.createElement(Button, {
        Text = props.RibbonTool.Name,

        OnActivated = function (rbx)
            if props.OnActivated then
                props.OnActivated(rbx)
            end

            if plugin:GetSelectedRibbonTool() ~= props.RibbonTool then
                plugin:SelectRibbonTool(props.RibbonTool, UDim2.new())
            end
        end,
    })
end

local function Plugin()
    local selection = useSelection()
    local projector = React.useMemo(DecalProjector.new, {})
    local showDebug, setShowDebug = React.useState(true)

    local autoTarget, setAutoTarget = React.useState<<boolean>>(true)
    local followCamera, setFollowCamera = React.useState<<boolean>>(true)

    local rootRef = React.useRef<<GuiObject?>>()
    local projectorRef = React.useRef<<Part?>>()
    local decalRef = React.useRef<<SurfaceAppearance?>>()
    local highlightRef = React.useRef<<Highlight?>>()
    local camera = useProperty.State(workspace, "CurrentCamera")
    local projectorLock = React.useRef(false)

    local function selectProjector()
        local projectorPart = projectorRef.current

        if projectorPart then
            Selection:Set({ projectorPart })
            setFollowCamera(false)
        end
    end
    
    React.useEffect(function ()
        local projectorPart = projectorRef.current
        local projectorDecal = decalRef.current
        
        if projectorPart then
            projectorPart.CFrame = camera.CFrame
        end

        if projectorDecal then
            projectorDecal.ColorMap = "rbxassetid://15658721128"
            projectorDecal.AlphaMode = Enum.AlphaMode.Transparency
        end

        return function ()
            if projectorPart then
                projectorPart:Destroy()
            end
        end
    end, {})

    React.useEffect(function ()
        if autoTarget then
            return nil :: any
        end

        local newTarget

        for i, selected in selection do
            if selected:IsA("MeshPart") or selected:IsA("Part") then
                newTarget = selected
            end
        end

        if newTarget == projector:GetTarget() then
            return nil :: any
        end
        
        local setTarget = task.spawn(function ()
            if newTarget then
                projector:SetTargetAsync(newTarget)
            end
        end)

        return function ()
            task.cancel(setTarget)
        end
    end, { selection })

    React.useEffect(function ()
        projector:SetDebugger(showDebug and projectorRef.current or nil)
    end, { showDebug })

    React.useEffect(function ()
        local projectorPart = projectorRef.current
        local projectorDecal = decalRef.current

        if not (projectorPart and projectorDecal) then
            return nil :: any
        end

        if not projectorPart.Parent then
            local success = pcall(function ()
                projectorPart.Parent = camera
            end)

            if not success then
                local root = rootRef.current
                local gui = root and root:FindFirstAncestorOfClass("DockWidgetPluginGui")
                warn("Projector part was destroyed! Please reopen the plugin.")

                if gui then
                    gui.Enabled = false
                end
                
                return nil :: any
            end
        end

        if not projectorDecal.Parent then
            local success = pcall(function ()
                projectorDecal.Parent = projectorPart
            end)

            if not success then
                local root = rootRef.current
                local gui = root and root:FindFirstAncestorOfClass("DockWidgetPluginGui")
                warn("Projector decal was destroyed! Please reopen the plugin.")

                if gui then
                    gui.Enabled = false
                end

                return nil :: any
            end
        end

        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = { projectorPart }
        rayParams.FilterType = Enum.RaycastFilterType.Exclude

        local dirty = false

        local function markDirty()
            dirty = true
        end

        local partConn = projectorPart.Changed:Connect(markDirty)
        local decalConn = projectorDecal.Changed:Connect(markDirty)

        local guid = Guid.Create()
        local lastCameraCF: CFrame?
        local target: BasePart?
        local projectionCFrame = projectorPart.CFrame

        RunService:BindToRenderStep(guid, 201, function ()
            if followCamera then
				if lastCameraCF and camera.CFrame ~= lastCameraCF then
					local offset = lastCameraCF:ToObjectSpace(projectorPart.CFrame)
                    projectorPart.CFrame = camera.CFrame * offset
                end
            end

            projectionCFrame = projectorPart.CFrame

            if autoTarget then
                local rayResult = workspace:Raycast(projectorPart.Position, projectorPart.CFrame.LookVector * 100, rayParams)

                if rayResult and rayResult.Instance and (rayResult.Instance:IsA("Part") or rayResult.Instance:IsA("MeshPart")) then
                    target = rayResult.Instance

                    projectionCFrame = CFrame.lookAlong(
                        rayResult.Position + rayResult.Normal * 0.01,
                        projectorPart.CFrame.LookVector,
                        projectorPart.CFrame.UpVector
                    )
                end
            end

			lastCameraCF = camera.CFrame
        end)

        local asyncThread = task.spawn(function ()
            while true do
                if not projectorLock.current then
                    if target and target ~= projector:GetTarget() then
                        if projector:SetTargetAsync(target :: any) then
                            dirty = true
                        else
                            target = projector:GetTarget()
                        end
                    end

                    if dirty then
                        local highlight = highlightRef.current

                        if highlight then
                            highlight.Adornee = target
                        end

                        local size = projectorPart.Size
                        dirty = false

                        projector:ProjectDecalAsync({
                            Size = Vector2.new(size.X, size.Y),
                            CFrame = projectionCFrame,
                            Texture = projectorDecal:Clone(),
                        })
                    end
                end

                task.wait()
            end
        end)

        return function ()
            partConn:Disconnect()
            decalConn:Disconnect()
            RunService:UnbindFromRenderStep(guid)

            if asyncThread then
                task.cancel(asyncThread)
            end
        end
    end, {
        camera,
        autoTarget,
        followCamera,
    })

    return React.createElement<<any>>(React.Fragment, {}, {
        Portal = ReactRoblox.createPortal({
            Projector = React.createElement("MeshPart", {
                Size = Vector3.one,
                Transparency = 0.5,
                CanCollide = false,
                CastShadow = false,
                Locked = true,
                Anchored = true,
                ref = projectorRef,
            }, {
                Decal = React.createElement("SurfaceAppearance", {
                    ref = decalRef,
                }),

                Focus = showDebug and React.createElement("Highlight", {
                    DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                    FillTransparency = 1,
                    OutlineColor = Color3.new(1, 1, 0),
                    OutlineTransparency = 0,
                    ref = highlightRef,
                })
            }),
        }, camera),

        Root = React.createElement("ScrollingFrame", {
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            HorizontalScrollBarInset = Enum.ScrollBarInset.None,
            CanvasSize = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ref = rootRef,
        }, {
            React.createElement("UIPadding", {
                PaddingTop = UDim.new(0, 8),
                PaddingBottom = UDim.new(0, 8),
                PaddingLeft = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8),
            }),

            React.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 8),
            }),

            React.createElement(Divider),

            React.createElement(Header, {
                Text = "Projector Options",
            }),

            React.createElement<<any>>(Button, {
                Text = "Modify Texture",

                OnActivated = function ()
                    local decal = decalRef.current

                    if decal then
                        Selection:Set({ decal })
                    end
                end,
            }),


            React.createElement<<any>>(Button, {
                Text = (showDebug and "Hide" or "Show") .. " Wireframe",

                OnActivated = function()
                    setShowDebug(not showDebug)
                end,
            }),

            React.createElement<<any>>(Button, {
                Text = (autoTarget and "Disable" or "Enable") .. " Auto Target",

                OnActivated = function()
                    setAutoTarget(not autoTarget)
                end,
            }),

            React.createElement(Divider),

            React.createElement(Header, {
                Text = "Projector Transform",
            }),

            React.createElement<<any>>(RibbonTool, {
                RibbonTool = Enum.RibbonTool.Move,
                OnActivated = selectProjector,
            }),

            React.createElement<<any>>(RibbonTool, {
                RibbonTool = Enum.RibbonTool.Scale,
                OnActivated = selectProjector,
            }),

            React.createElement<<any>>(RibbonTool, {
                RibbonTool = Enum.RibbonTool.Rotate,
                OnActivated = selectProjector,
            }),

            React.createElement(Divider),

            React.createElement(Header, {
                Text = "Camera Options",
            }),

            React.createElement<<any>>(Button, {
                Text = (if followCamera then "Unpin Projector from" else "Pin Projector to") .. " Camera",

                OnActivated = function()
                    setFollowCamera(not followCamera)
                end,
            }),

            React.createElement<<any>>(Button, {
                Text = "Snap Projector to Camera",

                OnActivated = function()
                    local projector = projectorRef.current

                    if projector then
                        local camera = workspace.CurrentCamera
                        projector.CFrame = camera.CFrame
                    end
                end,
            }),

            React.createElement(Divider),

            React.createElement<<any>>(Button, {
                Text = "Upload Applied Decal as MeshPart",
                Active = true,

                OnActivated = function()
                    local part = projector:GetAppliedDecal()

                    if not part then
                        return
                    end

                    ChangeHistory.Perform("Apply Decal", function ()
                        local extentsCF = part.ExtentsCFrame
                        local extentsSize = part.ExtentsSize
                        
                        local copy = part:Clone()
                        copy.Parent = part.Parent

                        local meshContent = part.MeshContent
                        local mesh = meshContent.Object

                        if mesh and mesh:IsA("EditableMesh") then
                            projectorLock.current = true

                            local success, status, assetId = xpcall(function ()
                                local result = { AssetService:CreateAssetAsync(mesh, Enum.AssetType.Mesh, {
                                    Name = "Decal Projector Mesh",
                                    Description = "Mesh uploaded from the Decal Projector plugin.",
                                }) }

                                return table.unpack(result)
                            end, function (err)
                                warn("Failed to upload mesh:", err)
                            end)

                            projectorLock.current = false

                            if success and status == Enum.CreateAssetResult.Success then
                                local meshId = "rbxassetid://" .. assetId
                                local newContent = Content.fromUri(meshId)

                                local newMeshPart = AssetService:CreateMeshPartAsync(newContent, {
                                    CollisionFidelity = Enum.CollisionFidelity.Box,
                                    RenderFidelity = Enum.RenderFidelity.Precise,
                                })

                                copy:ApplyMesh(newMeshPart)
                                copy.CFrame = extentsCF
                                copy.Size = extentsSize
                            end
                        end
                    end)
                end,
            })
        }),
    }) :: React.Node
end

return Plugin