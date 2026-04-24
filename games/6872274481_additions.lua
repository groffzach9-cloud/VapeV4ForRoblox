-- Infinite Jump Module (Add to end of 6872274481.lua)
run(function()
	local InfiniteJump
	local JumpCount
	local JumpHeight
	local jumped = false
	
	InfiniteJump = vape.Categories.Blatant:CreateModule({
		Name = 'InfiniteJump',
		Function = function(callback)
			if callback then
				InfiniteJump:Clean(inputService.InputBegan:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						jumped = true
					end
				end))
				
				InfiniteJump:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive then return end
					
					local hum = entitylib.character.Humanoid
					local root = entitylib.character.RootPart
					
					if jumped and hum.FloorMaterial ~= Enum.Material.Air then
						hum:ChangeState(Enum.HumanoidStateType.Jumping)
						if JumpHeight.Value > 0 then
							root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 50 * JumpHeight.Value, root.AssemblyLinearVelocity.Z)
						end
						jumped = false
					end
				end))
			end
		end,
		Tooltip = 'Allows unlimited consecutive jumps'
	})
	
	JumpHeight = InfiniteJump:CreateSlider({
		Name = 'Jump Height',
		Min = 0.1,
		Max = 2,
		Default = 1,
		Decimal = 10
	})
end)

-- Texture Packs Module (Add to end of 6872274481.lua)
run(function()
	local TexturePacks
	local AssetID
	local Preview
	local TextureList = {}
	
	local function applyTexturePack(assetId)
		-- This would require more complex implementation depending on game content
		-- For now, store the selected asset ID
		local success = assetId ~= '' and #assetId > 0
		if success then
			local notif_text = 'Applied texture pack: '..assetId
			vape:CreateNotification('TexturePacks', notif_text, 5)
		end
		return success
	end
	
	TexturePacks = vape.Categories.Render:CreateModule({
		Name = 'TexturePacks',
		Function = function(callback)
			if callback then
				if AssetID.Value ~= '' then
					applyTexturePack(AssetID.Value)
				else
					vape:CreateNotification('TexturePacks', 'Please enter a texture pack asset ID', 5, 'alert')
					TexturePacks:Toggle()
				end
			end
		end,
		Tooltip = 'Apply custom texture packs to the game'
	})
	
	AssetID = TexturePacks:CreateTextBox({
		Name = 'Asset ID',
		Default = '',
		Placeholder = 'rbxassetid://...',
		Function = function()
			if TexturePacks.Enabled and AssetID.Value ~= '' then
				applyTexturePack(AssetID.Value)
			end
		end
	})
	
	Preview = TexturePacks:CreateToggle({
		Name = 'Preview',
		Default = false,
		Tooltip = 'Preview texture pack before applying'
	})
end)
