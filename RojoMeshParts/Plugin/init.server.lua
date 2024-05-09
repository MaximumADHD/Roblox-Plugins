--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local StudioService = game:GetService("StudioService")
local Selection = game:GetService("Selection")

local modelIcon = StudioService:GetClassIcon("Model") :: {
    Image: string,
    ImageRectSize: Vector2,
    ImageRectOffset: Vector2,
}

local toolbar = plugin:CreateToolbar("Rojo MeshParts")
local saveModel = toolbar:CreateButton("Save Model", "Save the selected model as an rbxm that supports MeshParts in Rojo.", modelIcon.Image)

local lazyMaids = {} :: {
    [MeshPart]: { RBXScriptConnection }
}

local function onSaveModel()
    local model: Instance?

    for i, object in Selection:Get() do
        if object:IsA("MeshPart") or object:FindFirstChildWhichIsA("MeshPart", true) then
            model = object
            break
        end
    end

    if not model then
        return
    end

    local scan = model:GetDescendants()

    if model:IsA("MeshPart") then
        table.insert(scan, model)
    end

    local recording = ChangeHistoryService:TryBeginRecording("SaveRojoMeshParts", "Save Rojo MeshParts")

    if not recording then
        warn("Failed to begin ChangeHistoryService recording!")
        return
    end

    for i, object in ipairs(scan) do
        if object:IsA("MeshPart") then
            object:SetAttribute("RojoMeshId", object.MeshId)
            object:AddTag("RojoMeshPart")
        end
    end

    Selection:Set({model})
    ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)

    plugin:PromptSaveSelection()
end

local function updateMeshPart(mesh: MeshPart)
    local meshId = mesh:GetAttribute("RojoMeshId")

    if mesh.MeshId == meshId then
        return
    end

    local renderFidelity = mesh.RenderFidelity
    local collisionFidelity = mesh.CollisionFidelity

    local success, applyMesh = pcall(function ()
        return InsertService:CreateMeshPartAsync(meshId, collisionFidelity, renderFidelity)
    end)

    if not success then
        return
    end

    -- Make sure the mesh params didn't change while we were loading the mesh.
    local newMeshId = mesh:GetAttribute("RojoMeshId")

    if newMeshId ~= meshId then
        return
    end

    if mesh.RenderFidelity ~= renderFidelity then
        return
    end

    if mesh.CollisionFidelity ~= collisionFidelity then
        return
    end

    if fork then
        fork:ApplyMesh(applyMesh)
        applyMesh = fork
    end

    applyMesh.DoubleSided = mesh.DoubleSided
    applyMesh.TextureID = mesh.TextureID

    mesh:ApplyMesh(applyMesh)
end

local function onMeshPartAdded(mesh: Instance)
    if not mesh:IsA("MeshPart") then
        return
    end

    local updateDefer: thread?

    local function updateMesh()
        if updateDefer then
            return
        end

        updateDefer = task.defer(function ()
            updateDefer = nil
            updateMeshPart(mesh)
        end)
    end

    local function writeMesh()
        if mesh.MeshId ~= "" then
            mesh:SetAttribute("RojoMeshId", mesh.MeshId)
        end
    end

    local attributeListener = mesh:GetAttributeChangedSignal("RojoMeshId")
    local propListener = mesh:GetPropertyChangedSignal("MeshId")

    lazyMaids[mesh] = {
        attributeListener:Connect(updateMesh),
        propListener:Connect(writeMesh),
    }

    writeMesh()
    task.spawn(updateMeshPart, mesh)
end

local function onMeshPartRemoved(mesh: Instance)
    if not mesh:IsA("MeshPart") then
        return
    end

    local maid = lazyMaids[mesh]

    if maid then
        for i, conn in maid do
            conn:Disconnect()
        end

        lazyMaids[mesh] = nil
    end
end

local meshPartAdded = CollectionService:GetInstanceAddedSignal("RojoMeshPart")
local meshPartRemoved = CollectionService:GetInstanceRemovedSignal("RojoMeshPart")

meshPartAdded:Connect(onMeshPartAdded)
meshPartRemoved:Connect(onMeshPartRemoved)

for i, mesh in CollectionService:GetTagged("RojoMeshPart") do
    task.spawn(onMeshPartAdded, mesh)
end

saveModel.Click:Connect(onSaveModel)
