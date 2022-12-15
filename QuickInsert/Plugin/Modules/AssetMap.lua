local AssetMap = {} :: {
	[number]: Enum.AssetType
}

for i, assetType in pairs(Enum.AssetType:GetEnumItems()) do
	AssetMap[assetType.Value] = assetType
end

return AssetMap