--[[
	Author - 24RightAngles
	Modified by CloneTrooper1019
	used to select images for file import in the terrain editor
]]

-- HACK: Using the TeleportService because keys & values set in
--       GetTeleportSetting/SetTeleportSetting persist for the
--       duration of the Roblox Studio session ONLY. Its needed 
--       to work around a bug with File:GetTemporaryId() giving
--       the wrong rbxtemp:// urls half the time.

local StudioService = game:GetService("StudioService")
local TeleportService = game:GetService("TeleportService")

local project = script.Parent.Parent
local PNG = require(project.PNG)

local LIGHT_IMAGE  = "rbxasset://textures/TerrainTools/import_select_image.png"
local DARK_IMAGE   = "rbxasset://textures/TerrainTools/import_selectImg_dark.png"
local DELETE_IMAGE = "rbxasset://textures/TerrainTools/import_delete.png"
local EDIT_IMAGE   = "rbxasset://textures/TerrainTools/import_edit.png"

local IMAGE_BUTTON_SIZE = UDim2.new(0, 60, 0, 60)
local OPTION_IMAGE_SIZE = UDim2.new(0, 16, 0, 16)
local FRAME_SIZE = UDim2.new(0, 108, 0, 60)
local PADDING = 4

local ImageSelector = {}
ImageSelector.__index = ImageSelector

function ImageSelector.new(supportedFormats)
	local self = {}
	setmetatable(self, ImageSelector)

	self._selectedCallback = nil
	self._selectedFile = nil
	self._acceptedFormats = supportedFormats

	self._frame = Instance.new("Frame")
	self._frame.Size = FRAME_SIZE
	self._frame.BackgroundTransparency = 1

	local formatting = Instance.new("UIListLayout")
	formatting.SortOrder = Enum.SortOrder.LayoutOrder
	formatting.FillDirection = Enum.FillDirection.Horizontal
	formatting.VerticalAlignment = Enum.VerticalAlignment.Bottom
	formatting.Padding = UDim.new(0, PADDING)
	formatting.Parent = self._frame

	local initTheme = settings().Studio["UI Theme"]
	self._fallbackImage = initTheme == Enum.UITheme.Dark and DARK_IMAGE or LIGHT_IMAGE;

	self._imageButton = Instance.new("ImageButton")
	self._imageButton.Name = "SelectedImage"
	self._imageButton.Image = self._fallbackImage
	self._imageButton.Size = IMAGE_BUTTON_SIZE
	self._imageButton.BorderSizePixel = 0
	self._imageButton.BackgroundTransparency = 1
	self._imageButton.LayoutOrder = 1
	self._imageButton.Parent = self._frame
	self._imageButton.MouseButton1Click:connect(function()
		self:selectImage();
		self:updateOptionButtonVisibility()
	end)

	self._editButton = Instance.new("ImageButton")
	self._editButton.Name = "ReselectButton"
	self._editButton.Image = EDIT_IMAGE
	self._editButton.Size = OPTION_IMAGE_SIZE
	self._editButton.BorderSizePixel = 0
	self._editButton.BackgroundTransparency = 1
	self._editButton.ImageTransparency = 1
	self._editButton.LayoutOrder = 2
	self._editButton.Parent = self._frame
	self._editButton.MouseButton1Click:connect(function()
		if self._editButton.Active then
			self:selectImage()
		end
	end)

	self._deleteButton = Instance.new("ImageButton")
	self._deleteButton.Name = "ClearButton"
	self._deleteButton.Image = DELETE_IMAGE
	self._deleteButton.Size = OPTION_IMAGE_SIZE
	self._deleteButton.BorderSizePixel = 0
	self._deleteButton.BackgroundTransparency = 1
	self._deleteButton.LayoutOrder = 3
	self._deleteButton.Parent = self._frame
	self._deleteButton.MouseButton1Click:connect(function()
		if self._editButton.Active then
			self:clearImage()
			self:updateOptionButtonVisibility()
		end
	end)

	self:updateOptionButtonVisibility()

	--replace image when darkthemedarktheme
	settings().Studio.ThemeChanged:connect(function()
		if self._imageButton.Image == self._fallbackImage then
			local currTheme = settings().Studio.Theme
			
			if currTheme.Name == "Dark" then
				self._fallbackImage = DARK_IMAGE
			else
				self._fallbackImage = LIGHT_IMAGE
			end
			
			self._imageButton.Image = self._fallbackImage
		end
	end)

	return self
end

function ImageSelector:getFrame()
	return self._frame
end

-- edit and delete buttons should only be visible when
-- the image has been selected
function ImageSelector:updateOptionButtonVisibility()
	if self._selectedFile then
		self._editButton.Active = true
		self._editButton.ImageTransparency = 0
		self._deleteButton.Active = true
		self._deleteButton.ImageTransparency = 0
	else
		self._editButton.Active = false
		self._editButton.ImageTransparency = 1
		self._deleteButton.Active = false
		self._deleteButton.ImageTransparency = 1
	end
end

function ImageSelector:getTemporaryId()
	local file = self._selectedFile
	local img = self._selectedPng
	
	if file and img then
		local hash = string.format("PNG_%x", img.Hash)
		local id = TeleportService:GetTeleportSetting(hash)
		
		if not id then
			id = file:GetTemporaryId()
			TeleportService:SetTeleportSetting(hash, id)
		end
		
		return id
	end
end

function ImageSelector:selectImage()
	local img = StudioService:PromptImportFile(self._acceptedFormats)
	
	if img then
		local success, response = pcall(function ()
			local buffer = img:GetBinaryContents()
			return PNG.new(buffer)
		end)
		
		if success then
			self._selectedFile = img
			self._selectedPng = response
			
			if self._imageButton then
				local id = self:getTemporaryId()
				self._imageButton.Image = id
				
				if self._selectedCallback then
					self._selectedCallback()
				end
			end
		else
			warn("Error: Could not open this PNG file!")
			warn(response)
		end
	end
end

function ImageSelector:clearImage()
	self._imageButton.Image = self._fallbackImage
	self._selectedFile = nil
end

function ImageSelector:imageSelected()
	return self._selectedFile ~= nil
end

function ImageSelector:getBinary()
	if self._selectedFile then
		return self._selectedFile:GetBinaryContents()
	end
end

function ImageSelector:getPngFile()
	if self._selectedPng then
		return self._selectedPng
	end
end

function ImageSelector:setImageSelectedCallback(selectedCallback)
	self._selectedCallback = selectedCallback
end

return ImageSelector
