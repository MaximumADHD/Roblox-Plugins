local PrimitiveBuilder = {}

local function getFaceAxes(normalId: Enum.NormalId): (Vector3, Vector3, Vector3)
	if normalId == Enum.NormalId.Front then
		return -Vector3.zAxis, Vector3.xAxis, Vector3.yAxis
	elseif normalId == Enum.NormalId.Back then
		return Vector3.zAxis, -Vector3.xAxis, Vector3.yAxis
	elseif normalId == Enum.NormalId.Left then
		return -Vector3.xAxis, -Vector3.zAxis, Vector3.yAxis
	elseif normalId == Enum.NormalId.Right then
		return Vector3.xAxis, Vector3.zAxis, Vector3.yAxis
	elseif normalId == Enum.NormalId.Top then
		return Vector3.yAxis, Vector3.xAxis, Vector3.zAxis
	elseif normalId == Enum.NormalId.Bottom then
		return -Vector3.yAxis, Vector3.xAxis, -Vector3.zAxis
	else
		local normal = Vector3.fromNormalId(normalId)
		local axis = CFrame.lookAlong(Vector3.zero, normal)
		return normal, axis.RightVector, axis.UpVector
	end
end

function PrimitiveBuilder.Block(mesh: EditableMesh, size: Vector3)
	local halfSize = size / 2

	for i, normalId in Enum.NormalId:GetEnumItems() do
		local normal, uAxis, vAxis = getFaceAxes(normalId)
		local center = normal * halfSize
		uAxis *= halfSize
		vAxis *= halfSize

		local verts = {
			center - uAxis + vAxis,
			center + uAxis + vAxis,
			center + uAxis - vAxis,
			center - uAxis - vAxis,
		}

		local vertIds = {}

		for i, vert in verts do
			local id = mesh:AddVertex(vert)
			table.insert(vertIds, id)
		end

		mesh:AddTriangle(vertIds[1], vertIds[2], vertIds[3])
		mesh:AddTriangle(vertIds[1], vertIds[3], vertIds[4])
	end

	mesh:MergeVertices(0.001)
end

function PrimitiveBuilder.Ball(mesh: EditableMesh, size: Vector3)
	local radius = math.min(size.X, size.Y, size.Z) / 2

	for i, normalId in Enum.NormalId:GetEnumItems() do
		local faceVerts = {}
		local faceNorms = {}

		local normal, uAxis, vAxis = getFaceAxes(normalId)

		for u = -3, 3 do
			faceVerts[u] = {}
			faceNorms[u] = {}

			for v = -3, 3 do
				local vert = normal + (uAxis * u / 3) + (vAxis * v / 3)
				local norm = vert.Unit

				faceVerts[u][v] = mesh:AddVertex(norm * radius)
				faceNorms[u][v] = mesh:AddNormal(norm)
			end
		end

		for u = -3, 2 do
			for v = -3, 2 do
				local a = faceVerts[u][v]
				local b = faceVerts[u + 1][v]
				local c = faceVerts[u][v + 1]
				local d = faceVerts[u + 1][v + 1]

				local aNorm = faceNorms[u][v]
				local bNorm = faceNorms[u + 1][v]
				local cNorm = faceNorms[u][v + 1]
				local dNorm = faceNorms[u + 1][v + 1]

				local f1 = mesh:AddTriangle(a, d, b)
				mesh:SetFaceNormals(f1, { aNorm, dNorm, bNorm })

				local f2 = mesh:AddTriangle(a, c, d)
				mesh:SetFaceNormals(f2, { aNorm, cNorm, dNorm })
			end
		end
	end

	mesh:MergeVertices(0.001)
end

function PrimitiveBuilder.Cylinder(mesh: EditableMesh, size: Vector3)
	local radius = math.min(size.Y, size.Z) / 2
	local height = size.X

	local axle = Vector3.xAxis * height / 2
	local vL0, vR0, vN0 = 0, 0, 0

	local cap0 = mesh:AddVertex(-axle)
	local cap1 = mesh:AddVertex(axle)

	local leftNorm = mesh:AddNormal(-Vector3.xAxis)
	local leftNorms = { leftNorm, leftNorm, leftNorm }

	local rightNorm = mesh:AddNormal(Vector3.xAxis)
	local rightNorms = { rightNorm, rightNorm, rightNorm }

	for i = 0, 32 do
		local theta = (i / 32) * math.pi * 2
		local normal = Vector3.new(0, math.cos(theta), math.sin(theta))

		local vL1 = mesh:AddVertex(-axle + normal * radius)
		local vR1 = mesh:AddVertex(axle + normal * radius)
		local vN1 = mesh:AddNormal(normal)

		if i > 0 then
			local f1 = mesh:AddTriangle(vR1, vR0, vL0)
			mesh:SetFaceNormals(f1, { vN1, vN0, vN0 })

			local f2 = mesh:AddTriangle(vL1, vR1, vL0)
			mesh:SetFaceNormals(f2, { vN1, vN1, vN0 })

			local f3 = mesh:AddTriangle(vL1, vL0, cap0)
			mesh:SetFaceNormals(f3, leftNorms)

			local f4 = mesh:AddTriangle(vR0, vR1, cap1)
			mesh:SetFaceNormals(f4, rightNorms)
		end

		vL0 = vL1
		vR0 = vR1
		vN0 = vN1
	end

	mesh:MergeVertices(0.001)
end

function PrimitiveBuilder.Wedge(mesh: EditableMesh, size: Vector3)
	local hs = size / 2

	local a = mesh:AddVertex(Vector3.new(-hs.X, -hs.Y, -hs.Z))
	local b = mesh:AddVertex(Vector3.new(hs.X, -hs.Y, -hs.Z))
	local c = mesh:AddVertex(Vector3.new(hs.X, -hs.Y, hs.Z))
	local d = mesh:AddVertex(Vector3.new(-hs.X, -hs.Y, hs.Z))
	local e = mesh:AddVertex(Vector3.new(-hs.X, hs.Y, hs.Z))
	local f = mesh:AddVertex(Vector3.new(hs.X, hs.Y, hs.Z))

	local bt1 = mesh:AddTriangle(a, b, c)
	local bt2 = mesh:AddTriangle(a, c, d)
	local btn = mesh:AddNormal(-Vector3.yAxis)
	mesh:SetFaceNormals(bt1, { btn, btn, btn })
	mesh:SetFaceNormals(bt2, { btn, btn, btn })

	local lf = mesh:AddTriangle(b, f, c)
	local lfn = mesh:AddNormal(Vector3.xAxis)
	mesh:SetFaceNormals(lf, { lfn, lfn, lfn })

	local rt = mesh:AddTriangle(a, d, e)
	local rtn = mesh:AddNormal(-Vector3.xAxis)
	mesh:SetFaceNormals(rt, { rtn, rtn, rtn })

	local bk1 = mesh:AddTriangle(d, c, f)
	local bk2 = mesh:AddTriangle(d, f, e)
	local bkn = mesh:AddNormal(Vector3.zAxis)
	mesh:SetFaceNormals(bk1, { bkn, bkn, bkn })
	mesh:SetFaceNormals(bk2, { bkn, bkn, bkn })

	local ft1 = mesh:AddTriangle(a, e, f)
	local ft2 = mesh:AddTriangle(a, f, b)
	local ftn = mesh:AddNormal((Vector3.yAxis * size.Z - Vector3.zAxis * size.Y).Unit)
	mesh:SetFaceNormals(ft1, { ftn, ftn, ftn })
	mesh:SetFaceNormals(ft2, { ftn, ftn, ftn })

	mesh:MergeVertices(0.001)
end

function PrimitiveBuilder.CornerWedge(mesh: EditableMesh, size: Vector3)
	local hs = size / 2

	local a = mesh:AddVertex(Vector3.new(-hs.X, -hs.Y, -hs.Z))
	local b = mesh:AddVertex(Vector3.new(hs.X, -hs.Y, -hs.Z))
	local c = mesh:AddVertex(Vector3.new(hs.X, -hs.Y, hs.Z))
	local d = mesh:AddVertex(Vector3.new(-hs.X, -hs.Y, hs.Z))
	local e = mesh:AddVertex(Vector3.new(hs.X, hs.Y, -hs.Z))

	local bt1 = mesh:AddTriangle(a, b, c)
	local bt2 = mesh:AddTriangle(a, c, d)

	local btn = mesh:AddNormal(-Vector3.yAxis)
	mesh:SetFaceNormals(bt1, { btn, btn, btn })
	mesh:SetFaceNormals(bt2, { btn, btn, btn })

	local lf = mesh:AddTriangle(b, e, c)
	local lfn = mesh:AddNormal(Vector3.xAxis)
	mesh:SetFaceNormals(lf, { lfn, lfn, lfn })

	local bk = mesh:AddTriangle(d, c, e)
	local bkn = mesh:AddNormal((Vector3.yAxis * size.Z + Vector3.zAxis * size.Y).Unit)
	mesh:SetFaceNormals(bk, { bkn, bkn, bkn })

	local rt = mesh:AddTriangle(a, d, e)
	local rtn = mesh:AddNormal((Vector3.yAxis * size.X - Vector3.xAxis * size.Z).Unit)
	mesh:SetFaceNormals(rt, { rtn, rtn, rtn })

	local ft = mesh:AddTriangle(a, e, b)
	local ftn = mesh:AddNormal(-Vector3.zAxis)
	mesh:SetFaceNormals(ft, { ftn, ftn, ftn })

	mesh:MergeVertices(0.001)
end

function PrimitiveBuilder.Get(shape: Enum.PartType): (EditableMesh, Vector3) -> ()
	if shape == Enum.PartType.Block then
		return PrimitiveBuilder.Block
	elseif shape == Enum.PartType.Ball then
		return PrimitiveBuilder.Ball
	elseif shape == Enum.PartType.Cylinder then
		return PrimitiveBuilder.Cylinder
	elseif shape == Enum.PartType.Wedge then
		return PrimitiveBuilder.Wedge
	elseif shape == Enum.PartType.CornerWedge then
		return PrimitiveBuilder.CornerWedge
	else
		error(`Unsupported part type: {shape}`)
	end
end

return table.freeze(PrimitiveBuilder)