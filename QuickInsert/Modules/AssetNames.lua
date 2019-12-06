local AssetNames = {}

for _,assetType in pairs(Enum.AssetType:GetEnumItems()) do
	AssetNames[assetType.Value] = assetType.Name
end

return AssetNames