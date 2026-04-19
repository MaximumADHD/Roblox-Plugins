-- DecalProjector
-- MaximumADHD
-- December 3rd, 2024

--[[
This is a port of the decal system used in Valve's Source Engine.
Implementation boils down to the following steps:

1. Provide a 'position/orientation/size in 3D space' 
   (hereby labeled λ) against the surface of the mesh.

2. Scale λ to the original dimensions of the mesh data to be
   used against the EditableMesh data.

3. Bit-flag each vertex to figure out if it’s facing towards λ
   and if its depth against the plane is close enough to the surface.
   Any vertex facing away will nuke any polygons attached to it.

4. Convert the vertices into decal UV space using a planar projection of 
   the mesh geometry against λ. (I just ended up using PointToObjectSpace
   against λ as a CFrame)

5. Bit-flag each vertex whose UVs are outside of the 0-1 range of values.
   If all vertices are outside, the polygon is culled. If all are inside,
   the polygon does not need to be clipped.

6. Run 4 rounds of the Sutherland-Hodgman algorithm to clip polygons that
   had a mixture of vertices inside and outside of the 0-1 UV range box.
   This is done for all 4 edges of the decal using a double buffer that gets
   swapped back and forth on each edge so all newly added vertices are also
   included in the clipping procedure.

7. The vertices that remain after the clipping are filled using a triangle fan.
   (i.e. verts[1], verts[i], verts[i + 1] )

]]--

--!native
--!strict

local AssetService = game:GetService("AssetService")
local EncodingService = game:GetService("EncodingService")

local Util = script.Parent
local PrimitiveBuilder = require(Util.PrimitiveBuilder)

local DECAL_CLIP_MINUSU = 1
local DECAL_CLIP_MINUSV = 2
local DECAL_CLIP_PLUSU = 4
local DECAL_CLIP_PLUSV = 8

local FRONT_FACING = 1
local VALID_AREA = 2

local CLIP_PLANES = {
	{ Axis = "X", Clips = { [0.0] = DECAL_CLIP_MINUSU, [1.0] = DECAL_CLIP_PLUSU } },
	{ Axis = "Y", Clips = { [0.0] = DECAL_CLIP_MINUSV, [1.0] = DECAL_CLIP_PLUSV } },
}

type IDecal =
	| Decal
    | string
    | Content
    | SurfaceAppearance

export type DecalParams = {
	Size: Vector2,
	CFrame: CFrame,
	Texture: IDecal,
}

type VertInfo = {
	Flags: number,
	UV: number,
}

type Vertex = {
	Position: number,
	Normal: number,
	UV: number,
}

type ClipState = {
	VertCount: number,
	Indices: {{ number }},

	ClipVerts: { Vertex },
	ClipFlags: { number },

	Pass: number,
}

type ApplyDecalResult = {
	Success: true,
	Decal: MeshPart,
} | {
	Success: false,
	Error: string,
}

type Axis =
	| "X"
    | "Y"

local DecalProjector = {}
DecalProjector.__index = DecalProjector

export type Class = setmetatable<{
	_target: BasePart?,
	_targetMesh: EditableMesh?,
	_targetScale: Vector3,

	_decalMesh: EditableMesh,
	_decal: MeshPart?,

	_idRemap: {
		[number]: number
	},

	_vertInfo: { VertInfo },
	_buildThread: thread?,

	_debug: WireframeHandleAdornment?,
}, typeof(DecalProjector)>

local function lazyHashDecal(decal: Decal | SurfaceAppearance)
	local contents = ""
	contents ..= tostring(decal.ColorMapContent)
	contents ..= tostring(decal.NormalMapContent)
	contents ..= tostring(decal.MetalnessMapContent)
	contents ..= tostring(decal.RoughnessMapContent)
	
	return EncodingService:ComputeStringHash(contents, Enum.HashAlgorithm.Blake2b)
end

local function decalify(decal: IDecal)
	if typeof(decal) == "Instance" then
		return decal
	else
		local new = Instance.new("Decal")

		if typeof(decal) == "Content" then
			new.TextureContent = decal
		else
			new.Texture = decal
		end

		return new
	end
end

local function computeClipFlags(mesh: EditableMesh, uvId: number)
	local flags = 0
	local uv = mesh:GetUV(uvId)

	if uv then
		if uv.X < 0 then
			flags += DECAL_CLIP_MINUSU
		elseif uv.X > 1 then
			flags += DECAL_CLIP_PLUSU
		end

		if uv.Y < 0 then
			flags += DECAL_CLIP_MINUSV
		elseif uv.Y > 1 then
			flags += DECAL_CLIP_PLUSV
		end
	end

	return flags
end

local function getRemap(self: Class, value: number, handler: (number) -> number)
	local idRemap = self._idRemap
	local result = idRemap[value]

	if not result then
		result = handler(value)
		idRemap[value] = result
	end

	return result
end

local function intersectPlane(self: Class, state: ClipState, startAt: number, endAt: number, planeAxis: Axis, planeVal: number)
	local mesh = self._decalMesh
	local newIndex = #state.ClipVerts + 1

	local startVert = state.ClipVerts[startAt]
	local endVert = state.ClipVerts[endAt]

	local startPos = mesh:GetPosition(startVert.Position)
	local endPos = mesh:GetPosition(endVert.Position)

	local startNorm = mesh:GetNormal(startVert.Normal) or Vector3.yAxis
	local endNorm = mesh:GetNormal(endVert.Normal) or Vector3.yAxis

	local startUV = mesh:GetUV(startVert.UV) or Vector2.zero
	local endUV = mesh:GetUV(endVert.UV) or Vector2.zero

	local dir = endUV - startUV
	assert(if planeAxis == "X" then dir.X ~= 0 else dir.Y ~= 0)

	local t = if planeAxis == "X"
		then (planeVal - startUV.X) / dir.X
		else (planeVal - startUV.Y) / dir.Y

	local newNorm = startNorm:Lerp(endNorm, t).Unit
	local newPos = startPos:Lerp(endPos, t)
	local newUV = startUV:Lerp(endUV, t)

	local newMesh = self._decalMesh
	local uvId = newMesh:AddUV(newUV)

	state.ClipVerts[newIndex] = {
		Position = newMesh:AddVertex(newPos),
		Normal = newMesh:AddNormal(newNorm),
		UV = uvId,
	}

	state.ClipFlags[newIndex] = computeClipFlags(newMesh, uvId)
	return newIndex
end

local function clipTriangleAgainstPlane(self: Class, state: ClipState, planeAxis: Axis, flag: number, planeVal: number)
	local outVertCount = 0
	local nextPass = state.Pass == 1 and 2 or 1

	local startAt = state.Indices[state.Pass][state.VertCount]
	local startInside = not bit32.btest(state.ClipFlags[startAt], flag)

	for i = 1, state.VertCount do
		local endAt = state.Indices[state.Pass][i]
		local endInside = not bit32.btest(state.ClipFlags[endAt], flag)

		if endInside then
			if not startInside then
				local clipVert = intersectPlane(self, state, startAt, endAt, planeAxis, planeVal)
				state.Indices[nextPass][outVertCount + 1] = clipVert
				outVertCount += 1
			end

			state.Indices[nextPass][outVertCount + 1] = endAt
			outVertCount += 1
		else
			if startInside then
				local clipVert = intersectPlane(self, state, startAt, endAt, planeAxis, planeVal)
				state.Indices[nextPass][outVertCount + 1] = clipVert
				outVertCount += 1
			end
		end

		startAt = endAt
		startInside = endInside
	end

	state.Pass = nextPass
	state.VertCount = outVertCount
end

local function clipDecal(self: Class, clipVerts: { Vertex }, clipFlags: { number })
	local clipState = {
		Indices = { {1, 2, 3}, {} },
		VertCount = 3,
		Pass = 1,

		ClipVerts = clipVerts,
		ClipFlags = clipFlags,
	}

	for i, plane in CLIP_PLANES do
		local axis = plane.Axis :: Axis

		for value, flag in plane.Clips do
			clipTriangleAgainstPlane(self, clipState, axis, flag, value)

			if clipState.VertCount < 3 then
				return
			end
		end
	end

	local wireframe = self._debug

	if wireframe then
		wireframe.Color3 = Color3.new(0, 1, 1)
	end

	local newMesh = self._decalMesh
	local verts = table.create(clipState.VertCount) :: { Vertex }

	for i = 1, clipState.VertCount do
		local vertIndex = clipState.Indices[clipState.Pass][i]
		verts[i] = clipState.ClipVerts[vertIndex]
	end

	for i = 2, clipState.VertCount - 1 do
		local a, b, c = verts[1], verts[i], verts[i + 1]
		local faceId = newMesh:AddTriangle(a.Position, b.Position, c.Position)

		newMesh:SetFaceNormals(faceId, { a.Normal, b.Normal, c.Normal })
		newMesh:SetFaceUVs(faceId, { a.UV, b.UV, c.UV })

		if wireframe then
			local uvA = newMesh:GetUV(a.UV) or Vector2.zero
			local uvB = newMesh:GetUV(b.UV) or Vector2.zero
			local uvC = newMesh:GetUV(c.UV) or Vector2.zero

			wireframe:AddPath({
				Vector3.new(uvA.X - 0.5, 0.5 - uvA.Y),
				Vector3.new(uvB.X - 0.5, 0.5 - uvB.Y),
				Vector3.new(uvC.X - 0.5, 0.5 - uvC.Y),
			}, true)
		end
	end

	if wireframe then
		wireframe.Color3 = Color3.new(1, 0, 0)
	end
end

function DecalProjector.new(): Class
	local decalMesh = AssetService:CreateEditableMesh()

	local self: Class = setmetatable({
		_idRemap = {},
		_vertInfo = {},

		_target = nil :: BasePart?,
		_targetMesh = nil :: EditableMesh?,
		_targetScale = Vector3.one,

		_decalMesh = decalMesh,
		_decal = nil :: MeshPart?,

		_debug = nil :: WireframeHandleAdornment?,
		_buildThread = nil :: thread?,
	}, DecalProjector)

	return self
end

function DecalProjector.SetDebugger(self: Class, adornee: PVInstance?)
	if adornee then
		if not self._debug then
			local new = Instance.new("WireframeHandleAdornment")
			new.CFrame = CFrame.new(0, 0, -5)
			new.AlwaysOnTop = true
			new.Name = "Debugger"

			self._debug = new
		end

		if self._debug then
			self._debug.Adornee = adornee
			self._debug.Parent = adornee
		end
	elseif self._debug then
		self._debug:Destroy()
		self._debug = nil
	end
end

function DecalProjector.GetTarget(self: Class): BasePart?
	return self._target
end

function DecalProjector.SetTargetAsync(self: Class, target: BasePart): (boolean, string?)
	if self._target == target then
		return true, nil
	end

	if self._buildThread then
		pcall(task.cancel, self._buildThread)
	end

	local content: Content, meshSize: Vector3

	if target:IsA("MeshPart") then
		content = target.MeshContent
		meshSize = target.MeshSize
	elseif target:IsA("Part") then
		local shape = target.Shape
		local buildMesh = PrimitiveBuilder.Get(shape)

		if buildMesh then
			local mesh = AssetService:CreateEditableMesh()
			meshSize = target.Size

			buildMesh(mesh, meshSize)
			content = Content.fromObject(mesh)
		else
			return false, "Unsupported part shape!"
		end
	else
		return false, "Unsupported target type!"
	end

	local success, targetMesh = pcall(function ()
		return AssetService:CreateEditableMeshAsync(content)
	end)

	if success then
		self._target = target
		self._targetMesh = targetMesh
		self._targetScale = meshSize
	end

	return success, nil
end

function DecalProjector.Destroy(self: Class)
	if self._targetMesh then
		self._targetMesh:Destroy()
		self._targetMesh = nil
	end

	if self._decal then
		self._decal:Destroy()
		self._decal = nil
	end

	if self._decalMesh then
		self._decalMesh:Destroy()
	end

	self._target = nil
end

function DecalProjector.ProjectDecalAsync(self: Class, params: DecalParams): ApplyDecalResult
	if self._buildThread then
		pcall(task.cancel, self._buildThread)
		self._buildThread = nil
	end

	local targetMeshPart = self._target
	local targetMesh = self._targetMesh

	if not (targetMeshPart and targetMesh) then
		return {
			Success = false,
			Error = "No target set!",
		}
	end

	local size = targetMeshPart.ExtentsSize
	local meshSize = self._targetScale

	local toMeshSpace = meshSize / size
	local toPartSpace = size / meshSize

	local clipCF = params.CFrame
	local clipSize = Vector3.new(params.Size.X, params.Size.Y, 1)

	local newMesh = AssetService:CreateEditableMesh()
	local idRemap = self._idRemap
	local wireframe = self._debug

	if wireframe then
		wireframe:Clear()
	end

	if not newMesh then
		return {
			Success = false,
			Error = "Failed to create new mesh!",
		}
	end

	if wireframe then
		wireframe.Color3 = Color3.new(1, 1, 0)
		wireframe.Scale = Vector3.new(params.Size.X, params.Size.Y, 1)

		wireframe:AddPath({
			Vector3.new(-0.5, -0.5, 0),
			Vector3.new( 0.5, -0.5, 0),
			Vector3.new( 0.5,  0.5, 0),
			Vector3.new(-0.5,  0.5, 0),
		}, true)

		wireframe.Color3 = Color3.new(1, 1, 1)
		wireframe:AddLine(Vector3.new(-0.5, -0.5, 0), Vector3.new(-0.5, -0.5, 1))
		wireframe:AddLine(Vector3.new(0.5, -0.5, 0), Vector3.new(0.5, -0.5, 1))
		wireframe:AddLine(Vector3.new(0.5, 0.5, 0), Vector3.new(0.5, 0.5, 1))
		wireframe:AddLine(Vector3.new(-0.5, 0.5, 0), Vector3.new(-0.5, 0.5, 1))
	end

	table.clear(idRemap)
	targetMesh:Triangulate()

	self._decalMesh = newMesh
	self._buildThread = coroutine.running()

	local clipRelative = targetMeshPart.CFrame:ToObjectSpace(clipCF)
	local clipOrigin = clipRelative.Position * toMeshSpace

	local clipUp = (clipRelative.YVector * toMeshSpace).Unit
	local clipBack = (clipRelative.ZVector * toMeshSpace).Unit
	local clipRight = (clipRelative.XVector * toMeshSpace).Unit
	local clipLocal = CFrame.fromMatrix(clipOrigin, clipRight, clipUp, clipBack)

	local vertInfo = self._vertInfo
	table.clear(vertInfo)

	local halfWidth = clipSize.X / 2
	local halfHeight = clipSize.Y / 2
	local halfDepth = clipSize.Z / 2

	local normalIds = targetMesh:GetNormals()
	local vertIds = targetMesh:GetVertices()

    local uvMin = Vector2.one
    local uvMax = Vector2.zero

	for i, vertId in vertIds do
		if vertInfo[vertId] then
			continue
		end

		local normalId = normalIds[i]
		local vertNormal = targetMesh:GetNormal(normalId)

		local info = {
			Flags = 0,
			UV = 0,
		}

		if vertNormal and clipBack:Dot(vertNormal) >= 1e-6 then
			local pos = targetMesh:GetPosition(vertId)
			info.Flags += FRONT_FACING

			local relative = clipLocal:PointToObjectSpace(pos)
			relative *= toPartSpace

			local uv = Vector2.new(
				0.5 + (relative.X / clipSize.X),
				0.5 - (relative.Y / clipSize.Y)
			)

			info.UV = newMesh:AddUV(uv)

            uvMin = Vector2.min(uvMin, uv)
            uvMin = Vector2.max(uvMin, Vector2.zero)
            
            uvMax = Vector2.max(uvMax, uv)
            uvMax = Vector2.min(uvMax, Vector2.one)

			if math.abs(relative.X) < halfWidth and math.abs(relative.Y) < halfHeight and math.abs(relative.Z) < halfDepth then
				info.Flags += VALID_AREA
			end
		end

		vertInfo[vertId] = info
	end

	for i, faceId in targetMesh:GetFaces() do
		local vertIds = targetMesh:GetFaceVertices(faceId)
		local normIds = targetMesh:GetFaceNormals(faceId)
		local vertA, vertB, vertC = unpack(vertIds)

		local infoA = vertInfo[vertA]
		local infoB = vertInfo[vertB]
		local infoC = vertInfo[vertC]

		if not bit32.btest(FRONT_FACING, infoA.Flags, infoB.Flags, infoC.Flags) then
			continue
		end

		local allNotInValidArea = bit32.bor(infoA.Flags, infoB.Flags, infoC.Flags)

		if not bit32.btest(VALID_AREA, allNotInValidArea) then
			continue
		end

		local clipFlags = {
			computeClipFlags(newMesh, infoA.UV),
			computeClipFlags(newMesh, infoB.UV),
			computeClipFlags(newMesh, infoC.UV),
		}

		if bit32.btest(unpack(clipFlags)) then
			continue
		end

		local clipVerts = table.create(3) :: { Vertex }

		for i = 1, 3 do
			local vertId = vertIds[i]
			local normId = normIds[i]
			local info = vertInfo[vertId]

			clipVerts[i] = {
				Position = getRemap(self, vertIds[i], function ()
					local pos = targetMesh:GetPosition(vertId)
					return newMesh:AddVertex(pos)
				end),

				Normal = getRemap(self, normId, function ()
					local norm = targetMesh:GetNormal(normId)
					return newMesh:AddNormal(norm)
				end),

				UV = info.UV,
			}
		end

		clipDecal(self, clipVerts, clipFlags)
	end

	-- Remove any verts that aren't connected to a face after clipping.
	newMesh:RemoveUnused()

	-- Begin space transformation of the decal.
	local verts = newMesh:GetVertices()
	local normals = newMesh:GetNormals()
	local avgNormal = Vector3.zero

	for i, vertId in verts do
		local pos = newMesh:GetPosition(vertId)
		local rotated = clipLocal:PointToObjectSpace(pos)
		newMesh:SetPosition(vertId, rotated)
	end

	for i, normId in normals do
		local norm = newMesh:GetNormal(normId)

		if norm then
			local rotated = clipLocal:VectorToObjectSpace(norm)

			if rotated.Magnitude > 0 then
				rotated = rotated.Unit
			end

			newMesh:SetNormal(normId, rotated)
			avgNormal += rotated
		end
	end

	-- Inflate the mesh slightly along the vertex normals to prevent z-fighting with the target surface.
	for i, vertId in verts do
		local normals = newMesh:GetVertexNormals(vertId)
		local vertDisp = Vector3.zero

		for i, normId in normals do
			local norm = newMesh:GetNormal(normId)

			if norm then
				vertDisp += norm
			end
		end

		if vertDisp.Magnitude > 0 then
			local vert = newMesh:GetPosition(vertId)
			newMesh:SetPosition(vertId, vert + (vertDisp.Unit / 500))
		end
	end

	if avgNormal.Magnitude > 0 then
		avgNormal = avgNormal.Unit
	end

	-- Recompute the bounding-box center in the final local basis,
	-- then recenter the geometry around that.
	local center = newMesh:GetCenter()

	for _, vertId in newMesh:GetVertices() do
		local pos = newMesh:GetPosition(vertId)
		newMesh:SetPosition(vertId, pos - center)
	end
	
	local meshContent = Content.fromObject(newMesh)

	local gotMeshPart, newMeshPart = pcall(function ()
		return AssetService:CreateMeshPartAsync(meshContent, {
			RenderFidelity = Enum.RenderFidelity.Precise,
			CollisionFidelity = Enum.CollisionFidelity.Box,
			FluidFidelity = Enum.FluidFidelity.UseCollisionGeometry,
		})
	end)

	if not gotMeshPart then
		return {
			Success = false,
			Error = "Failed to create MeshPart from decal mesh content!",
		}
	end

	local decalMeshPart = self._decal or newMeshPart

	if decalMeshPart:IsDescendantOf(game) then
		local newSize = newMeshPart.Size * toPartSpace
		decalMeshPart:ApplyMesh(newMeshPart)
		decalMeshPart.Size = newSize
	else
		decalMeshPart.Name = "Decal"
		decalMeshPart.Size *= toPartSpace
		decalMeshPart.EnableFluidForces = false
		decalMeshPart.AudioCanCollide = false
		decalMeshPart.CastShadow = false
		decalMeshPart.CanCollide = false
		decalMeshPart.CanQuery = false
		decalMeshPart.CanTouch = false
		decalMeshPart.Massless = true
		decalMeshPart.Locked = true
	end

	local oldDecal = 
        decalMeshPart:FindFirstChildWhichIsA("Decal") or 
        decalMeshPart:FindFirstChildWhichIsA("SurfaceAppearance") or
        decalify(decalMeshPart.TextureContent)

	local oldHash = lazyHashDecal(oldDecal)
	local newDecal = decalify(params.Texture)
	local newHash = lazyHashDecal(newDecal)

	if oldHash ~= newHash then
		if typeof(oldDecal) == "Instance" then
			oldDecal:Destroy()
		end

		local copy = newDecal:Clone()

        if copy:IsA("Decal") then
            copy.Face = Enum.NormalId.Back
        end
        
		copy.Parent = decalMeshPart
	end

    local decal = decalMeshPart:FindFirstChildWhichIsA("Decal")
	local weld = decalMeshPart:FindFirstChildOfClass("Weld")

    if decal then
        decal.UVOffset = uvMin
        decal.UVScale = uvMax - uvMin
    end

	-- `center` is in the baked decal-local basis.
	-- Convert it back into target mesh space, then into target part space.
	local centerMeshSpace = clipLocal:PointToWorldSpace(center)
	local centerPartSpace = centerMeshSpace * toPartSpace

	if not weld then
		weld = Instance.new("Weld")
		weld.Parent = decalMeshPart
	end

	assert(weld).C0 = CFrame.new(centerPartSpace) * clipRelative.Rotation
	weld.Part0 = targetMeshPart
	weld.Part1 = decalMeshPart

	self._buildThread = nil
	self._decal = decalMeshPart
	decalMeshPart.Parent = targetMeshPart

	return {
		Success = true,
		Decal = decalMeshPart,
	}
end

function DecalProjector.GetAppliedDecal(self: Class): MeshPart?
	return self._decal
end

return DecalProjector