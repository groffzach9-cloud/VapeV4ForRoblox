--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
local run = function(func)
    local ok, err = pcall(func)
    if not ok then
        warn('[AEROV4] module failed to load: ' .. tostring(err))
    end
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})
getgenv().vapeEvents = vapeEvents

local cloneref = cloneref or function(obj)
	return obj
end

local function safeGetProto(func, index)
    if not func then return nil end
    local success, proto = pcall(debug.getconstant, func, index)
    if success then
        return proto
    end
end

local inventoryDebounce = false
local function fireInventoryChanged()
    if inventoryDebounce then return end
    inventoryDebounce = true
    task.spawn(function()
        task.wait() 
        vapeEvents.InventoryChanged:Fire()
        inventoryDebounce = false
    end)
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))
local starterPlayer = cloneref(game:GetService('StarterPlayer'))
local debris = cloneref(game:GetService('Debris'))
local materialService = cloneref(game:GetService('MaterialService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local VirtualInputManager = game:GetService("VirtualInputManager")
local lightingService = cloneref(game:GetService('Lighting'))

local isnetworkowner = identifyexecutor and table.find({'Delta', 'Volt'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
if vape and not vape.Clean then
	vape.Clean = function(self, conn)
		if not conn then return end
		
		if not vape.Connections then
			vape.Connections = {}
		end

		if self and self.Enabled then
			vape.Connections[conn] = true
			return conn
		else
			if vape.Connections[conn] then
				if typeof(conn) == "RBXScriptConnection" then
					pcall(conn.Disconnect, conn)
				end
				vape.Connections[conn] = nil
			end
		end
	end
end
if vape and not vape.Remove then
    vape.Remove = function(module) 
		return module 
	end
end
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local store = {
    attackReach = 0,
    attackReachUpdate = tick(),
    damageBlockFail = tick(),
    hand = {},
    inventory = {
        inventory = {
            items = {},
            armor = {}
        },
        hotbar = {}
    },
    inventories = setmetatable({}, { __mode = "k" }), 
    matchState = 0,
    queueType = 'bedwars_test',
    tools = {},
    lastToolUpdate = 0,
	lastKrystalUpdateCheck = 0,
	BedAlarmNotifyTick = 0,
	BedAlarmIsTrigged = false,
	BedAlarmHighlightedEnimes = {},
	BedAlarm = {},
	BedAlarmSoundTick = 0,
	rankedType = 'sqauds'
}
local Reach = {}
local HitBoxes = {}
local TrapDisabler
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing, rakNet = {}, {}, {}, false
local originalKnit
local function getAccountTier(player)
	if getgenv().getAccountTier then
		return getgenv().getAccountTier(player)
	end
	return 0
end  

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('newvape/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local _bowItemMeta = bedwars.ItemMeta[item.itemType]
        local bowMeta = _bowItemMeta and _bowItemMeta.projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end

local function getItem(itemName, inv)
	for slot, item in (inv or store.inventory.inventory.items) do
		if item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end

local function GetItems(item: string): table
	local Items: table = {};
	for _, v in next, Enum[item]:GetEnumItems() do 
		table.insert(Items, v["Name"]) ;
	end;
	return Items;
end;

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local _swordItemMeta = bedwars.ItemMeta[item.itemType]
        local swordMeta = _swordItemMeta and _swordItemMeta.sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local _toolItemMeta = bedwars.ItemMeta[item.itemType]
        local toolMeta = _toolItemMeta and _toolItemMeta.breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end

local function getWool()
	for _, wool in store.inventory.inventory.items do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end

local function getStrength(plr)
	if not plr or not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end

local function getShieldAttribute(char)
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end

local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

	local modifiers2 = bedwars.SprintController:getMovementStatusModifier():getModifiers()
	for v in modifiers do
		local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
		if val and val > math.max(multi, 1) then
			increase = false
			multi = val - (0.06 * math.round(val))
		end
	end

	for v in modifiers2 do
		multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return 20 * (multi + 1)
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function notif(...) return
	vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function roundPos(vec)
    return Vector3.new(
        math.round(vec.X / 3) * 3,
        math.round(vec.Y / 3) * 3,
        math.round(vec.Z / 3) * 3
    )
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if (returned and returned.Name ~= 'UpperTorso') or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local frictionTable, oldfrict = {}, {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local function isEveryoneDead()
	return #bedwars.Store:getState().Party.members <= 0
end
	
local function joinQueue()
	if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
		bedwars.QueueController:joinQueue(store.queueType)
	end
end

local function lobby()
    bedwars.Client:Get(remotes.TeleportToLobby):FireServer()
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local function HasSeed(character)
    if not character then return false end
    return character:FindFirstChild("Seed", true) ~= nil
end

local sortmethods = {
	Damage = function(a, b)
		if not a.Entity or not a.Entity.Character then return false end
		if not b.Entity or not b.Entity.Character then return true end
		return a.Entity.Character:GetAttribute('LastDamageTakenTime') < b.Entity.Character:GetAttribute('LastDamageTakenTime')
	end,
	Threat = function(a, b)
		if not a.Entity then return false end
		if not b.Entity then return true end
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Kit = function(a, b)
		return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKit')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKit')] or 0)
	end,
	Health = function(a, b)
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		if not a.Entity or not a.Entity.RootPart then return false end
		if not b.Entity or not b.Entity.RootPart then return true end
		local selfrootpos = entitylib.character.RootPart.Position
		local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local angle = math.acos(localfacing:Dot(((a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		local angle2 = math.acos(localfacing:Dot(((b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		return angle < angle2
	end,
	Distance = function(a, b)
		if not a.Entity or not a.Entity.RootPart then return false end
		if not b.Entity or not b.Entity.RootPart then return true end
		local selfpos = entitylib.character.RootPart.Position
		local distA = (a.Entity.RootPart.Position - selfpos).Magnitude
		local distB = (b.Entity.RootPart.Position - selfpos).Magnitude
		return distA < distB
	end,
	Cursor = function(a, b)
		if not a.Entity or not a.Entity.RootPart then return false end
		if not b.Entity or not b.Entity.RootPart then return true end
		local camera = gameCamera
		local mousePos = inputService:GetMouseLocation()
		local function screenDist(ent)
			local screenPos, onScreen = camera:WorldToScreenPoint(ent.RootPart.Position)
			if not onScreen then return math.huge end
			return (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
		end
		return screenDist(a.Entity) < screenDist(b.Entity)
	end,
	Forest = function(a, b)
		if not a.Entity then return false end
		if not b.Entity then return true end
		local aHasSeed = HasSeed(a.Entity.Character)
		local bHasSeed = HasSeed(b.Entity.Character)
		if aHasSeed and not bHasSeed then return true end
		if not aHasSeed and bHasSeed then return false end
		if not a.Entity.RootPart then return false end
		if not b.Entity.RootPart then return true end
		local selfpos = entitylib.character.RootPart.Position
		local distA = (a.Entity.RootPart.Position - selfpos).Magnitude
		local distB = (b.Entity.RootPart.Position - selfpos).Magnitude
		return distA < distB
	end
}

run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		if entitylib.Running then entitylib.stop() end

		local function customEntity(ent)
			if playersService:GetPlayerFromCharacter(ent) then return end
			local teamFunc = function(self)
				local npcTeam = self.Character:GetAttribute('Team')
				return lplr:GetAttribute('Team') ~= npcTeam
			end
			entitylib.addEntity(ent, nil, teamFunc)
		end

		table.insert(entitylib.Connections, playersService.PlayerAdded:Connect(function(v)
			entitylib.addPlayer(v)
		end))
		table.insert(entitylib.Connections, playersService.PlayerRemoving:Connect(function(v)
			entitylib.removePlayer(v)
		end))

		for _, v in playersService:GetPlayers() do
			entitylib.addPlayer(v)
		end

		for _, ent in collectionService:GetTagged('entity') do
			customEntity(ent)
		end

		table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
		table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
			entitylib.removeEntity(ent)
		end))

		local function addDesertPot(pot)
			if not pot:IsA('Model') then return end
			entitylib.addEntity(pot, nil, function() return true end)
		end
		for _, v in collectionService:GetTagged('desert_pot') do
			addDesertPot(v)
		end
		table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('desert_pot'):Connect(addDesertPot))
		table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('desert_pot'):Connect(function(v)
			entitylib.removeEntity(v)
		end))

		table.insert(entitylib.Connections, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
		end))

		entitylib.Running = true
	end

	entitylib.addPlayer = function(plr)
		if entitylib.PlayerConnections[plr] then
			for _, conn in ipairs(entitylib.PlayerConnections[plr]) do
				if conn and typeof(conn) == "RBXScriptConnection" then
					conn:Disconnect()
				end
			end
		end

		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				if plr == lplr then
					for _, v in entitylib.List do
						local newTargetable = entitylib.targetCheck(v)
						if v.Targetable ~= newTargetable then
							v.Targetable = newTargetable
							entitylib.Events.EntityUpdated:Fire(v)
						end
					end
				else
					entitylib.refreshEntity(plr.Character, plr)
					for _, v in entitylib.List do
						if v.Player ~= plr and v.Targetable ~= entitylib.targetCheck(v) then
							local newTargetable = entitylib.targetCheck(v)
							v.Targetable = newTargetable
							entitylib.Events.EntityUpdated:Fire(v)
						end
					end
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = {}
			if plr and plr ~= lplr then
				local names = {'ArmorInvItem_0', 'ArmorInvItem_1', 'ArmorInvItem_2', 'HandInvItem'}
				for _, name in names do
					local found = char:FindFirstChild(name)
					if found then
						table.insert(updateobjects, found)
					end
				end
			end

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (function()
						local hp = char:GetAttribute('Health') or 100
						local shield = 0
						for k, v in pairs(char:GetAttributes()) do
							if type(k) == 'string' and k:sub(1, 7) == 'Shield_' and type(v) == 'number' and v > 0 then
								shield = shield + v
							end
						end
						return hp + shield
					end)(),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entity.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)

					if not plr then
						table.insert(entity.Connections, char.AttributeChanged:Connect(function(attr)
							if attr == 'Team' then
								entity.Targetable = entitylib.targetCheck(entity)
								entitylib.Events.EntityUpdated:Fire(entity)
							end
						end))
					end

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					local invUpdatePending = {}

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							if invUpdatePending[entity] then return end
							invUpdatePending[entity] = true
							task.delay(0.1, function()
								invUpdatePending[entity] = nil
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								local jumpAnimId = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.StateChanged:Connect(function(old, new)
									if new == Enum.HumanoidStateType.Jumping then
										entity.JumpTick = tick()
										entity.Jumps += 1
										entity.LandTick = tick() + 1
										entity.Jumping = entity.Jumps > 1
									elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.Freefall then
										entity.Jumping = false
									end
								end))
							end)
						end

						task.delay(0.1, function()
							if bedwars.getInventory then
								store.inventories[plr] = bedwars.getInventory(plr)
							end
						end)
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
		end

		local shieldSignal = {
			Connect = function(_, func)
				local conn = char.AttributeChanged:Connect(function(attr)
					if attr:find('Shield') then
						func()
					end
				end)
				return conn
			end
		}
		table.insert(tab, shieldSignal)

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.Character and ent.Character:HasTag('petrified-player') then return false end
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then
			local npcTeam = ent.Character and ent.Character:GetAttribute('Team')
			return lplr:GetAttribute('Team') ~= npcTeam
		end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()

run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get

	task.spawn(function()
		if typeof(raknet) ~= "function" or typeof(raknet) ~= 'table' or typeof(getgenv().raknet) ~= "function" or typeof(getgenv().raknet) ~= 'table'  then
			rakNet = false
		else
			rakNet = true
		end
	end)

	bedwars = setmetatable({
		RankMeta = require(replicatedStorage.TS.rank['rank-meta']).RankMeta,
        BalanceFile = require(replicatedStorage.TS.balance["balance-file"]).BalanceFile,
        ClientSyncEvents = require(lplr.PlayerScripts.TS['client-sync-events']).ClientSyncEvents,
        SyncEventPriority = require(replicatedStorage.rbxts_include.node_modules['@easy-games']['sync-event'].out),
		AbilityId = require(replicatedStorage.TS.ability['ability-id']).AbilityId,
        IdUtil = require(replicatedStorage.TS.util['id-util']).IdUtil,
		BlockSelector = require(replicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.select["block-selector"]).BlockSelector,
		KnockbackUtilInstance = replicatedStorage.TS.damage['knockback-util'],
		BedwarsKitSkin = require(replicatedStorage.TS.games.bedwars['kit-skin']['bedwars-kit-skin-meta']).BedwarsKitSkinMeta,
		KitController = Knit.Controllers.KitController,
		FishermanUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.fisherman['fisherman-util']).FishermanUtil,
		FishMeta = require(replicatedStorage.TS.games.bedwars.kit.kits.fisherman['fish-meta']),
	 	MatchHistroyApp = require(lplr.PlayerScripts.TS.controllers.global["match-history"].ui["match-history-moderation-app"]).MatchHistoryModerationApp,
	 	MatchHistroyController = Knit.Controllers.MatchHistoryController,
		BlockEngine = require(replicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].out).BlockEngine,
		BlockSelectorMode = require(replicatedStorage.rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.select["block-selector"]).BlockSelectorMode,
		EntityUtil = require(replicatedStorage.TS.entity["entity-util"]).EntityUtil,
		GamePlayer = require(replicatedStorage.TS.player['game-player']),
		OfflinePlayerUtil = require(replicatedStorage.TS.player['offline-player-util']),
		PlayerUtil = require(replicatedStorage.TS.player['player-util']),
		KKKnitController = require(lplr.PlayerScripts.TS.lib.knit['knit-controller']),
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		CooldownController = Flamework.resolveDependency("@easy-games/game-core:client/controllers/cooldown/cooldown-controller@CooldownController"),
		CooldownIDS = require(replicatedStorage.TS.cooldown["cooldown-id"]).CooldownId,		
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BowConstantsTable = (Knit.Controllers.ProjectileController and Knit.Controllers.ProjectileController.enableBeam) and debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8) or {},
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		SharedConstants = require(replicatedStorage.TS['shared-constants']),
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.global.locker['kill-effect'].effects['default-kill-effect']),
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		NotificationController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/notification-controller@NotificationController'),
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		MatchHistoryController = require(lplr.PlayerScripts.TS.controllers.global['match-history']['match-history-controller']),
		PlayerProfileUIController = require(lplr.PlayerScripts.TS.controllers.global['player-profile']['player-profile-ui-controller']),
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency("@easy-games/lobby:client/controllers/party-controller@PartyController"),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.shared.sound['sound-manager']).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 6),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network),
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})
	getgenv().bedwars = bedwars

	local remoteNames = {
		AfkStatus = safeGetProto(Knit.Controllers.AfkController.KnitStart, 1),
		AttackEntity = Knit.Controllers.SwordController.sendServerRequest,
		BeePickup = Knit.Controllers.BeeNetController.trigger,
		CannonAim = safeGetProto(Knit.Controllers.CannonController.startAiming, 5),
		CannonLaunch = Knit.Controllers.CannonHandController.launchSelf,
		ConsumeBattery = safeGetProto(Knit.Controllers.BatteryController.onKitLocalActivated, 1),
		ConsumeItem = safeGetProto(Knit.Controllers.ConsumeController.onEnable, 1),
		ConsumeSoul = Knit.Controllers.GrimReaperController.consumeSoul,
		ConsumeTreeOrb = safeGetProto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1),
		DepositPinata = safeGetProto(safeGetProto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5),
		DragonBreath = safeGetProto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5),
		DragonEndFly = safeGetProto(Knit.Controllers.VoidDragonController.flapWings, 1),
		DragonFly = Knit.Controllers.VoidDragonController.flapWings,
		DropItem = Knit.Controllers.ItemDropController.dropItemInHand,
		EquipItem = safeGetProto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 3),
		FireProjectile = debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2),
		GroundHit = Knit.Controllers.FallDamageController.KnitStart,
		GuitarHeal = Knit.Controllers.GuitarController.performHeal,
		HannahKill = safeGetProto(Knit.Controllers.HannahController.registerExecuteInteractions, 1),
		HarvestCrop = safeGetProto(safeGetProto(Knit.Controllers.CropController.KnitStart, 4), 1),
		KaliyahPunch = safeGetProto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1),
		MageSelect = safeGetProto(Knit.Controllers.MageController.registerTomeInteraction, 1),
		MinerDig = safeGetProto(Knit.Controllers.MinerController.setupMinerPrompts, 1),
		PickupItem = Knit.Controllers.ItemDropController.checkForPickup,
		PickupMetal = safeGetProto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4),
		ReportPlayer = require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer,
		ResetCharacter = safeGetProto(Knit.Controllers.ResetController.createBindable, 1),
		SummonerClawAttack = Knit.Controllers.SummonerClawHandController.attack,
		WarlockTarget = safeGetProto(Knit.Controllers.WarlockStaffController.KnitStart, 2)
	}

	local function dumpRemote(tab)
		local ind
		for i, v in tab do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and tab[ind + 1] or ''
	end

	local preDumped = {
		EquipItem = 'SetInvItem',
		ActivateGravestone = 'ActivateGravestone',
		CollectCollectableEntity = 'CollectCollectableEntity',
		DefenderRequestPlaceBlock = 'DefenderRequestPlaceBlock',
		RequestDragonPunch = 'RequestDragonPunch',
		Harvest = 'CropHarvest',
		DepositCoins = 'DepositCoins',
		BedwarsPurchaseItem = 'BedwarsPurchaseItem',
		BedBreakEffectTriggered = 'BedBreakEffectTriggered',
		BloodAssassinSelectContract = 'BloodAssassinSelectContract',
		Mimic = 'MimicBlock',
		StyxPortal = 'UseStyxPortalFromClient',
		StyxExitPortal = 'StyxOpenExitPortalFromServer',
		TeleportToLobby = 'TeletoLobby',
		FishCaught = 'FishCaught',
		SpawnRaven = 'SpawnRaven',
		PaladinAbilityRequest = 'PaladinAbilityRequest',
		OwlActionAbilities = 'OwlActionAbilities',
		DrillAttack = 'DrillAttack',
		UpgradeFrostyHammer = 'UpgradeFrostyHammer',
		UpgradeFlamethrower = 'UpgradeFlamethrower',
		TryBlockKick = 'TryBlockKick',   
		Ranks = 'FetchRanks',
		ResearchEnchant = 'EnchantTableResearch',
		DropDroneItem = 'DropDroneItem',
		AttemptFireOasisProjectiles = 'AttemptFireOasisProjectiles',
		WinEffectTriggered = 'WinEffectTriggered',
		ExtractFromDrill = 'ExtractFromDrill',
		HannahPromptTrigger = 'HannahPromptTrigger',
		DragonFlap = 'DragonFlap',
		DragonBreath = 'DragonBreath',
		AttemptCardThrow = 'AttemptCardThrow',
		LearnElementTome = 'LearnElementTome',
		RequestMoveSlime = 'RequestMoveSlime',
		SummonOwl = 'SummonOwl',
		RemoveOwl = 'RemoveOwl',
		MimicBlockPickPocketPlayer = 'MimicBlockPickPocketPlayer',
		DestroyPetrifiedPlayer = 'DestroyPetrifiedPlayer',
		UseAbility = 'useAbility',
		FishFound = 'FishFound',
	}

	for k, v in pairs(preDumped) do
		if not remotes[k] then
			remotes[k] = v
		end
	end

	for i, v in remoteNames do
		local remote
		if type(v) == "string" then
			remote = v
		elseif type(v) == "function" then
			local consts = debug.getconstants(v)
			remote = dumpRemote(consts)
		else
			remote = ""
		end

		if remote == '' or remote == nil then
			if not preDumped[i] then
				notif('Vape', 'Failed to grab remote ('..tostring(i)..')', 10, 'alert')
			end
			remote = preDumped[i] or ''
		end
		remotes[i] = remote
	end

	OldBreak = bedwars.BlockController.isBlockBreakable

	Client.Get = function(self, remoteName)
		local call = OldGet(self, remoteName)

		if remoteName == remotes.AttackEntity then
			return {
				instance = call.instance,
				SendToServer = function(_, attackTable, ...)
					local suc, plr = pcall(function()
						return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
					end)

					local selfpos = attackTable.validate.selfPosition.value
					local targetpos = attackTable.validate.targetPosition.value
					store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
					store.attackReachUpdate = tick() + 1

					if Reach.Enabled or HitBoxes.Enabled then
						attackTable.validate.raycast = attackTable.validate.raycast or {}
						attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
					end

					if suc and plr then
						if whitelist.get and not select(2, whitelist:get(plr)) then return end
					end

					return call:SendToServer(attackTable, ...)
				end
			}
		elseif remoteName == 'StepOnSnapTrap' and TrapDisabler.Enabled then
			return {SendToServer = function() end}
		end

		return call
	end

	bedwars.BlockController.isBlockBreakable = function(self, breakTable, plr)
		local obj = bedwars.BlockController:getStore():getBlockAt(breakTable.blockPosition)

		if obj and obj.Name == 'bed' then
			for _, p in playersService:GetPlayers() do
				local hasNoBreak = pcall(function() return obj:GetAttribute('Team'..(p:GetAttribute('Team') or 0)..'NoBreak') end)
				if hasNoBreak and not (whitelist.get and select(2, whitelist:get(p))) then
					return false
				end
			end
		end

		return OldBreak(self, breakTable, plr)
	end

	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	
	local cacheCleanThread = task.spawn(function()
		while vape.Loaded do
			task.wait(60)
			if vape.Loaded then
				table.clear(cache)
			end
		end
	end)
	vape:Clean(function() task.cancel(cacheCleanThread) end)

	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end

	local function getBlockHits(block, blockpos)
		if not block then return 0 end
		local breaktype = bedwars.ItemMeta[block.Name].block.breakType
		local tool = store.tools[breaktype]
		tool = tool and bedwars.ItemMeta[tool.itemType].breakBlock[breaktype] or 2
		return getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) / tool
	end

	local function calculatePath(target, blockpos)
		if cache[blockpos] then
			if tick() - (cache[blockpos].timestamp or 0) < 10 then
				return unpack(cache[blockpos])
			else
				cache[blockpos] = nil
			end
		end
		local visited = {}
		local unvisited = {{0, blockpos}}
		local distances = {[blockpos] = 0}
		local air = {}
		local path = {}
		local unvisitedCount = 1

		for _ = 1, 600 do
			if unvisitedCount == 0 then break end
			local node = unvisited[1]
			unvisited[1] = unvisited[unvisitedCount]
			unvisited[unvisitedCount] = nil
			unvisitedCount = unvisitedCount - 1
			visited[node[2]] = true

			for _, side in sides do
				local neighbor = node[2] + side
				if visited[neighbor] then continue end

				local block = getPlacedBlock(neighbor)
				if not block or block:GetAttribute('NoBreak') or block == target then
					if not block then
						air[node[2]] = true
					end
					continue
				end

				local curdist = getBlockHits(block, neighbor) + node[1]
				if curdist < (distances[neighbor] or math.huge) then
					unvisitedCount = unvisitedCount + 1
					unvisited[unvisitedCount] = {curdist, neighbor}
					distances[neighbor] = curdist
					path[neighbor] = node[2]
				end
			end
		end

		local pos, cost = nil, math.huge
		for node in air do
			local d = distances[node]
			if d and d < cost then
				pos, cost = node, d
			end
		end

		if pos then
			local cacheEntry = {pos, cost, path, timestamp = tick()}
			cache[blockpos] = cacheEntry
			return pos, cost, path
		end
	end

	bedwars.placeBlock = function(pos, item)
		if getItem(item) then
			store.blockPlacer.blockType = item
			local ok, result = pcall(function()
				return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
			end)
			if ok then return result end
		end
	end

	bedwars.breakBlock = function(block, effects, anim, customHealthbar, autotool, wallcheck, nobreak)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive then return end
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge
		local mag = 9e9

		local positions = (handler and handler:getContainedPositions(block) or {block.Position / 3})

		for _, v in positions do
			local dpos, dcost, dpath = calculatePath(block, v * 3)
			local dmag = dpos and (entitylib.character.RootPart.Position - dpos).Magnitude
			if dpos and dcost < cost and dmag < mag then
				cost, pos, target, path, mag = dcost, dpos, v * 3, dpath, dmag
			end
		end

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock then return end

			if not nobreak and (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.2 then
				local breaktype = bedwars.ItemMeta[dblock.Name].block.breakType
				local tool = store.tools[breaktype]
				if tool then
					if autotool then
						for i, v in store.inventory.hotbar do
							if v.item and v.item.tool == tool.tool and i ~= (store.inventory.hotbarSlot + 1) then 
								hotbarSwitch(i - 1)
								break
							end
						end
					else
						switchItem(tool.tool)
					end
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
				blockhealthbar.breakingBlockPosition = dpos
			end

			if not nobreak then
				bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
					blockRef = {blockPosition = dpos},
					hitPosition = pos,
					hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
				}):andThen(function(result)
					if result then
						 if result == 'cancelled' then
							store.damageBlockFail = os.clock() + 1
							table.clear(cache)
							return
						end

						if result == 'destroyed' then
							table.clear(cache)
						end

						if effects then
							local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
							customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
							customHealthbar(bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, dblock:GetAttribute('MaxHealth'), blockdmg, dblock)
							blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)

							pcall(function()
								if blockhealthbar.blockHealth <= 0 then
									bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
									bedwars.BlockBreaker.healthbarMaid:DoCleaning()
									blockhealthbar.breakingBlockPosition = Vector3.zero
								else
									bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
								end
							end)
						end

						if anim then
							local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
							bedwars.ViewmodelController:playAnimation(15)
							task.wait(0.3)
							animation:Stop()
							animation:Destroy()
						end
					end
				end)
			end

			if effects then
				return pos, path, target
			end
		end
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end

		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			if newinv ~= oldinv then
				fireInventoryChanged()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				local now = tick()
				if not store.lastToolUpdate or now - store.lastToolUpdate > 0.5 then
					store.lastToolUpdate = now
					store.tools.sword = getSword()
					for _, v in {'stone', 'wood', 'wool'} do
						store.tools[v] = getTool(v)
					end
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	vape:Clean(function() storeChanged:disconnect() end)
	updateStore(bedwars.Store:getState(), {})

	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end

	local _dmgEventData = {entityInstance=nil,damage=nil,damageType=nil,fromPosition=nil,fromEntity=nil,knockbackMultiplier=nil,knockbackId=nil,disableDamageHighlight=nil}
	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		_dmgEventData.entityInstance = ...
		_dmgEventData.damage = select(2, ...)
		_dmgEventData.damageType = select(3, ...)
		_dmgEventData.fromPosition = select(4, ...)
		_dmgEventData.fromEntity = select(5, ...)
		_dmgEventData.knockbackMultiplier = select(6, ...)
		_dmgEventData.knockbackId = select(7, ...)
		_dmgEventData.disableDamageHighlight = select(13, ...)
		vapeEvents.EntityDamageEvent:Fire(_dmgEventData)
	end))

	vape:Clean(playersService.PlayerRemoving:Connect(function(plr)
		store.inventories[plr] = nil
	end))

	local _blockEventData = {blockRef = {blockPosition = nil}, player = nil}
	for _, event in {'PlaceBlockEvent', 'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			_blockEventData.blockRef.blockPosition = ...
			_blockEventData.player = select(5, ...)
			vapeEvents[event]:Fire(_blockEventData)
		end))
	end

	store.blocks = collection('block', vape)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, vape, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, vape, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			mapname = workspace:WaitForChild('Map', 5):WaitForChild('Worlds', 5):GetChildren()[1].Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	pcall(function()
		bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
		bedwars.ShopItems = bedwars.Shop.ShopItems
		bedwars.Shop.getShopItem('iron_sword', lplr)
		store.shopLoaded = true
	end)

	vape:Clean(function()
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil

		if entitylib.Connections then
			for _, conn in ipairs(entitylib.Connections) do
				if conn and type(conn) == "userdata" and conn.Connected then
					conn:Disconnect()
				end
			end
			table.clear(entitylib.Connections)
		end

		if entitylib.PlayerConnections then
			for _, plrConns in pairs(entitylib.PlayerConnections) do
				if type(plrConns) == "table" then
					for _, conn in ipairs(plrConns) do
						if conn and type(conn) == "userdata" and conn.Connected then
							conn:Disconnect()
						end
					end
				end
			end
			table.clear(entitylib.PlayerConnections)
		end

		if entitylib.EntityThreads then
			for char, thread in pairs(entitylib.EntityThreads) do
				if thread and task.cancel then
					task.cancel(thread)
				end
			end
			table.clear(entitylib.EntityThreads)
		end

		if entitylib.List then
			for _, ent in ipairs(entitylib.List) do
				if ent.Connections then
					for _, conn in ipairs(ent.Connections) do
						if conn and type(conn) == "userdata" and conn.Connected then
							conn:Disconnect()
						end
					end
					table.clear(ent.Connections)
				end
			end
			table.clear(entitylib.List)
		end
		if entitylib.stop then
			entitylib.stop()
		end
		for playerId, data in pairs(lagConnections) do
			if data and data.connection then
				pcall(function() data.connection:Disconnect() end)
			end
		end
		table.clear(lagConnections)
	end)
end)

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery', 'NameTags'} do
	vape:Remove(v)
end


local kitImageIds = {
	['none'] = "rbxassetid://16493320215",
	["random"] = "rbxassetid://79773209697352",
	["cowgirl"] = "rbxassetid://9155462968",
	["davey"] = "rbxassetid://9155464612",
	["warlock"] = "rbxassetid://15186338366",
	["ember"] = "rbxassetid://9630017904",
	["black_market_trader"] = "rbxassetid://18922642482",
	["yeti"] = "rbxassetid://9166205917",
	["scarab"] = "rbxassetid://137137517627492",
	["defender"] = "rbxassetid://131690429591874",
	["cactus"] = "rbxassetid://104436517801089",
	["oasis"] = "rbxassetid://120283205213823",
	["berserker"] = "rbxassetid://90258047545241",
	["sword_shield"] = "rbxassetid://131690429591874",
	["airbender"] = "rbxassetid://74712750354593",
	["gun_blade"] = "rbxassetid://138231219644853",
	["frost_hammer_kit"] = "rbxassetid://11838567073",
	["spider_queen"] = "rbxassetid://95237509752482",
	["archer"] = "rbxassetid://9224796984",
	["axolotl"] = "rbxassetid://9155466713",
	["baker"] = "rbxassetid://9155463919",
	["barbarian"] = "rbxassetid://9166207628",
	["builder"] = "rbxassetid://9155463708",
	["necromancer"] = "rbxassetid://11343458097",
	["cyber"] = "rbxassetid://9507126891",
	["sorcerer"] = "rbxassetid://97940108361528",
	["bigman"] = "rbxassetid://9155467211",
	["spirit_assassin"] = "rbxassetid://10406002412",
	["farmer_cletus"] = "rbxassetid://9155466936",
	["ice_queen"] = "rbxassetid://9155466204",
	["grim_reaper"] = "rbxassetid://9155467410",
	["spirit_gardener"] = "rbxassetid://132108376114488",
	["hannah"] = "rbxassetid://10726577232",
	["shielder"] = "rbxassetid://9155464114",
	["summoner"] = "rbxassetid://18922378956",
	["glacial_skater"] = "rbxassetid://84628060516931",
	["dragon_sword"] = "rbxassetid://16215630104",
	["lumen"] = "rbxassetid://9630018371",
	["flower_bee"] = "rbxassetid://101569742252812",
	["jellyfish"] = "rbxassetid://18129974852",
	["melody"] = "rbxassetid://9155464915",
	["mimic"] = "rbxassetid://14783283296",
	["miner"] = "rbxassetid://9166208461",
	["nazar"] = "rbxassetid://18926951849",
	["seahorse"] = "rbxassetid://11902552560",
	["elk_master"] = "rbxassetid://15714972287",
	["rebellion_leader"] = "rbxassetid://18926409564",
	["void_hunter"] = "rbxassetid://122370766273698",
	["taliyah"] = "rbxassetid://13989437601",
	["angel"] = "rbxassetid://9166208240",
	["harpoon"] = "rbxassetid://18250634847",
	["void_walker"] = "rbxassetid://78915127961078",
	["spirit_summoner"] = "rbxassetid://95760990786863",
	["triple_shot"] = "rbxassetid://9166208149",
	["void_knight"] = "rbxassetid://73636326782144",
	["regent"] = "rbxassetid://9166208904",
	["vulcan"] = "rbxassetid://9155465543",
	["owl"] = "rbxassetid://12509401147",
	["dasher"] = "rbxassetid://9155467645",
	["disruptor"] = "rbxassetid://11596993583",
	["wizard"] = "rbxassetid://13353923546",
	["aery"] = "rbxassetid://9155463221",
	["agni"] = "rbxassetid://17024640133",
	["alchemist"] = "rbxassetid://9155462512",
	["spearman"] = "rbxassetid://9166207341",
	["beekeeper"] = "rbxassetid://9312831285",
	["falconer"] = "rbxassetid://17022941869",
	["bounty_hunter"] = "rbxassetid://9166208649",
	["blood_assassin"] = "rbxassetid://12520290159",
	["battery"] = "rbxassetid://10159166528",
	["steam_engineer"] = "rbxassetid://15380413567",
	["vesta"] = "rbxassetid://9568930198",
	["beast"] = "rbxassetid://9155465124",
	["dino_tamer"] = "rbxassetid://9872357009",
	["drill"] = "rbxassetid://12955100280",
	["elektra"] = "rbxassetid://13841413050",
	["fisherman"] = "rbxassetid://9166208359",
	["queen_bee"] = "rbxassetid://12671498918",
	["card"] = "rbxassetid://13841410580",
	["frosty"] = "rbxassetid://9166208762",
	["gingerbread_man"] = "rbxassetid://9155464364",
	["ghost_catcher"] = "rbxassetid://9224802656",
	["tinker"] = "rbxassetid://17025762404",
	["ignis"] = "rbxassetid://13835258938",
	["oil_man"] = "rbxassetid://9166206259",
	["jade"] = "rbxassetid://9166306816",
	["dragon_slayer"] = "rbxassetid://10982192175",
	["paladin"] = "rbxassetid://11202785737",
	["pinata"] = "rbxassetid://10011261147",
	["merchant"] = "rbxassetid://9872356790",
	["metal_detector"] = "rbxassetid://9378298061",
	["slime_tamer"] = "rbxassetid://15379766168",
	["nyoka"] = "rbxassetid://17022941410",
	["midnight"] = "rbxassetid://9155462763",
	["pyro"] = "rbxassetid://9155464770",
	["raven"] = "rbxassetid://9166206554",
	["santa"] = "rbxassetid://9166206101",
	["sheep_herder"] = "rbxassetid://9155465730",
	["smoke"] = "rbxassetid://9155462247",
	["spirit_catcher"] = "rbxassetid://9166207943",
	["star_collector"] = "rbxassetid://9872356516",
	["styx"] = "rbxassetid://17014536631",
	["block_kicker"] = "rbxassetid://15382536098",
	["trapper"] = "rbxassetid://9166206875",
	["hatter"] = "rbxassetid://12509388633",
	["ninja"] = "rbxassetid://15517037848",
	["jailor"] = "rbxassetid://11664116980",
	["warrior"] = "rbxassetid://9166207008",
	["mage"] = "rbxassetid://10982191792",
	["void_dragon"] = "rbxassetid://10982192753",
	["cat"] = "rbxassetid://15350740470",
	["wind_walker"] = "rbxassetid://9872355499",
	['skeleton'] = "rbxassetid://120123419412119",
	['winter_lady'] = "rbxassetid://83274578564074",
	['soul_broker'] = 'rbxassetid://130409166262430'
}

local function isFirstPerson()
    if not (lplr.Character and lplr.Character:FindFirstChild("Head")) then
        return false
    end
    return (lplr.Character.Head.Position - gameCamera.CFrame.Position).Magnitude < 2
end

local function isFrozen(entity, threshold)
    threshold = threshold or 10
    local char
    if type(entity) == "table" and entity.Character then
        char = entity.Character
    elseif type(entity) == "Instance" and entity:IsA("Model") then
        char = entity
    elseif entity == nil then
        if not entitylib.isAlive then return false end
        char = entitylib.character.Character
    else
        return false
    end

    local stacks = char:GetAttribute("ColdStacks") or char:GetAttribute("FrostStacks")
               or char:GetAttribute("FreezeStacks") or char:GetAttribute("FROZEN_STACKS")
    if stacks and stacks >= threshold then return true end

    local statusEffects = char:GetAttribute("StatusEffects")
    if type(statusEffects) == "table" then
        for effectName, stackCount in pairs(statusEffects) do
            local nameLower = tostring(effectName):lower()
            if nameLower:match("cold") or nameLower:match("frost") or nameLower:match("freeze") then
                if type(stackCount) == "number" then
                    if stackCount >= threshold then return true end
                elseif stackCount then
                    return true
                end
            end
        end
    end

    if char:FindFirstChild("IceBlock") or char:FindFirstChild("FrozenBlock") or char:FindFirstChild("IceShell") then
        return true
    end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.WalkSpeed <= 2 then
        return true
    end

    return false
end

local sharedRaycast = RaycastParams.new()
sharedRaycast.FilterType = Enum.RaycastFilterType.Include
sharedRaycast.FilterDescendantsInstances = {workspace:FindFirstChild('Map') or workspace}

local function cloneRaycast()
    local r = RaycastParams.new()
    r.FilterType = sharedRaycast.FilterType
    r.FilterDescendantsInstances = sharedRaycast.FilterDescendantsInstances
    r.RespectCanCollide = sharedRaycast.RespectCanCollide
    return r
end

local function isSword()
    return store.hand and store.hand.toolType == 'sword'
end

local function hasValidWeapon()
    if not store.hand or not store.hand.tool then return false end
    local toolType = store.hand.toolType
    local toolName = store.hand.tool.Name:lower()
    if toolName:find('headhunter') then return true end
    return toolType == 'sword' or toolType == 'bow' or toolType == 'crossbow'
end

local function fixPosition(pos)
    if bedwars and bedwars.BlockController and bedwars.BlockController.getBlockPosition then
        return bedwars.BlockController:getBlockPosition(pos) * 3
    end
    return pos * 3
end

local function getAmmoForProjectile(check)
    for _, item in store.inventory.inventory.items do
        if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
            return item.itemType
        end
    end
end

local function getProjectileItems(ammoFilter)
    local items = {}
    for _, item in store.inventory.inventory.items do
        local _itemMeta = bedwars.ItemMeta[item.itemType]
        local proj = _itemMeta and _itemMeta.projectileSource
        local ammo = proj and getAmmoForProjectile(proj)
        if ammo and table.find(ammoFilter, ammo) then
            table.insert(items, {item, ammo, proj.projectileType(ammo), proj})
        end
    end
    return items
end

local function isHoldingItem(keywords, includeProjectileSource)
    if not store.hand or not store.hand.tool then return false end
    local toolName = store.hand.tool.Name:lower()
    for _, kw in ipairs(keywords) do
        if toolName:find(kw) then return true end
    end
    if includeProjectileSource then
        return bedwars.ItemMeta[toolName] and bedwars.ItemMeta[toolName].projectileSource and true or false
    end
    return false
end

local function isHoldingBowCrossbow(includeProjectileSource)
    return isHoldingItem({'bow', 'crossbow', 'headhunter'}, includeProjectileSource)
end

local function isHoldingPickaxe()
    return isHoldingItem({'pickaxe'})
end

local function isEnemy(ent)
    if not ent then return false end
    if ent.Character and ent.Character:HasTag('petrified-player') then return false end
    if ent.Player then
        local myTeam = lplr:GetAttribute('Team')
        local theirTeam = ent.Player:GetAttribute('Team')
        if not myTeam or not theirTeam or myTeam == theirTeam then return false end
        return select(2, whitelist:get(ent.Player))
    elseif ent.NPC then
        local npcTeam = ent.Character:GetAttribute('Team')
        if npcTeam then return lplr:GetAttribute('Team') ~= npcTeam end
        return true
    end
    return false
end

local function getShopNPC()
    local shop, items, upgrades, newid = nil, false, false, nil
    if entitylib.isAlive then
        local localPosition = entitylib.character.RootPart.Position
        for _, v in store.shop do
            if (v.RootPart.Position - localPosition).Magnitude <= 20 then
                shop = v.Upgrades or v.Shop or nil
                upgrades = upgrades or v.Upgrades
                items = items or v.Shop
                newid = v.Shop and v.Id or newid
            end
        end
    end
    return shop, items, upgrades, newid
end

local function isTeammate(player)
    if not lplr or not player then return false end
    local myTeam = lplr:GetAttribute('Team')
    local theirTeam = player:GetAttribute('Team')
    return myTeam and theirTeam and myTeam == theirTeam
end

local function getPlayerName(player, useDisplayName)
    if not player then return '' end
    return (useDisplayName and player.DisplayName ~= "" and player.DisplayName) or player.Name
end

local armorTiers = {'none','leather_chestplate','iron_chestplate','diamond_chestplate','emerald_chestplate'}
local function getArmorTier(player)
    if not player or not store.inventories[player] then return 0 end
    local chest = store.inventories[player].armor and store.inventories[player].armor[5]
    if not chest or chest == 'empty' then return 1 end
    return table.find(armorTiers, chest.itemType) or 1
end

local function checkFaceAdjacent(pos, faces)
    faces = faces or {
        Vector3.new(3,0,0), Vector3.new(-3,0,0), Vector3.new(0,3,0),
        Vector3.new(0,-3,0), Vector3.new(0,0,3), Vector3.new(0,0,-3)
    }
    for _, v in ipairs(faces) do
        if getPlacedBlock(pos + v) then return true end
    end
    return false
end

local _isAboveVoidParams = RaycastParams.new()
_isAboveVoidParams.FilterType = Enum.RaycastFilterType.Exclude
local function isAboveVoid(position)
    _isAboveVoidParams.FilterDescendantsInstances = {entitylib.character.Character}
    local result = workspace:Raycast(position, Vector3.new(0, -500, 0), _isAboveVoidParams)
    return result == nil
end

local function hasFaceBelowOrSide(pos)
    if getPlacedBlock(pos - Vector3.new(0,3,0)) then return true end
    local sides = {Vector3.new(3,0,0), Vector3.new(-3,0,0), Vector3.new(0,0,3), Vector3.new(0,0,-3)}
    for _, v in ipairs(sides) do
        if getPlacedBlock(pos + v) then return true end
    end
    return false
end

local function nearCorner(poscheck, pos)
    local start = poscheck - Vector3.new(3,3,3)
    local fin = poscheck + Vector3.new(3,3,3)
    local dir = (pos - poscheck).Unit * 100
    local check = poscheck + dir
    return Vector3.new(
        math.clamp(check.X, start.X, fin.X),
        math.clamp(check.Y, start.Y, fin.Y),
        math.clamp(check.Z, start.Z, fin.Z)
    )
end

local function blockProximity(pos, rangeBlocks)
    rangeBlocks = rangeBlocks or 21
    local mag, best = 60, nil
    local blocks = getBlocksInPoints(
        bedwars.BlockController:getBlockPosition(pos - Vector3.new(rangeBlocks,rangeBlocks,rangeBlocks)),
        bedwars.BlockController:getBlockPosition(pos + Vector3.new(rangeBlocks,rangeBlocks,rangeBlocks))
    )
    for _, v in ipairs(blocks) do
        local bp = nearCorner(v, pos)
        local d = (pos - bp).Magnitude
        if hasFaceBelowOrSide(bp) and d < mag then
            mag, best = d, bp
        end
    end
    return best
end

local function isGUIOpen()
    return bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN)
        or bedwars.AppController:isLayerOpen(bedwars.UILayers.DIALOG)
        or bedwars.AppController:isLayerOpen(bedwars.UILayers.POPUP)
        or bedwars.AppController:isAppOpen('BedwarsItemShopApp')
        or (bedwars.Store:getState().Inventory and bedwars.Store:getState().Inventory.open)
end

local function isTargetValid(ent, maxDist, checkWalls)
    if not ent or not ent.RootPart or not ent.Character then return false end
    if not entitylib.isAlive then return false end
    local dist = (ent.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
    if dist > maxDist then return false end
    if checkWalls then
        local ray = workspace:Raycast(
            entitylib.character.RootPart.Position,
            (ent.RootPart.Position - entitylib.character.RootPart.Position),
            sharedRaycast
        )
        if ray then return false end
    end
    local hum = ent.Character:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local function getTargetByPriority(originPos, range, opts)
    opts = opts or {}
    local players = opts.players == nil and true or opts.players
    local npcs = opts.npcs or false
    local walls = opts.walls or false
    local sort = opts.sort or 'distance' -- 'health','armor','damage'
    local damageTracker = opts.damageTracker 

    local valid = {}
    for _, ent in ipairs(entitylib.List) do
        if (players and ent.Player) or (npcs and ent.NPC) then
            if isEnemy(ent) and ent.RootPart then
                local dist = (ent.RootPart.Position - originPos).Magnitude
                if dist <= range then
                    if walls then
                        local ray = workspace:Raycast(originPos, (ent.RootPart.Position - originPos), sharedRaycast)
                        if not ray then
                            table.insert(valid, ent)
                        end
                    else
                        table.insert(valid, ent)
                    end
                end
            end
        end
    end
    if #valid == 0 then return nil end

    if sort == 'distance' then
        table.sort(valid, function(a,b)
            return (a.RootPart.Position - originPos).Magnitude < (b.RootPart.Position - originPos).Magnitude
        end)
    elseif sort == 'damage' and damageTracker then
        table.sort(valid, function(a,b)
            local keyA = a.Player and a.Player.UserId or tostring(a)
            local keyB = b.Player and b.Player.UserId or tostring(b)
            return (damageTracker[keyA] or 0) > (damageTracker[keyB] or 0)
        end)
    end
    return valid[1]
end

local isMobile = inputService.TouchEnabled and not inputService.KeyboardEnabled and not inputService.MouseEnabled

local function getTeammates(namesOnly)
    local result = {}
    local myTeam = lplr:GetAttribute('Team')
    if not myTeam then return result end
    for _, player in playersService:GetPlayers() do
        if player ~= lplr and player:GetAttribute('Team') == myTeam then
            if namesOnly then
                table.insert(result, player.Name)
            elseif player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                table.insert(result, player)
            end
        end
    end
    if namesOnly then
        table.sort(result)
    end
    return result
end

local function getNearestTeammateInRange(range, condition)
    if not entitylib.isAlive then return nil end
    local myPos = entitylib.character.RootPart.Position
    local nearest = nil
    local nearestDist = math.huge
    for _, player in ipairs(getTeammates()) do
        if player.Character and player.Character.PrimaryPart then
            local dist = (player.Character.PrimaryPart.Position - myPos).Magnitude
            if dist <= range then
                if condition and not condition(player) then continue end
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest
end

local function getPlayerHealth(player)
    if not player or not player.Character then return 0, 100 end
    local health = player.Character:GetAttribute('Health') or (player.Character:FindFirstChildOfClass('Humanoid') and player.Character.Humanoid.Health) or 0
    local maxHealth = player.Character:GetAttribute('MaxHealth') or (player.Character:FindFirstChildOfClass('Humanoid') and player.Character.Humanoid.MaxHealth) or 100
    return health, maxHealth
end

local function getPlayerHealthPercent(player)
    local health, maxHealth = getPlayerHealth(player)
    if maxHealth == 0 then return 0 end
    return (health / maxHealth) * 100
end

local function leftClick()
	pcall(function()
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
		task.wait(0.05)
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
	end)
end

local function getWorldFolder()
    local Map = workspace:FindFirstChild("Map")
    if not Map then return nil end
    local Worlds = Map:FindFirstChild("Worlds")
    if not Worlds then return nil end
    for _, world in Worlds:GetChildren() do
        return world
    end
    return nil
end

local function getPickaxeSlot()
	for i, v in store.inventory.hotbar do
		if v.item and bedwars.ItemMeta[v.item.itemType] then
			local meta = bedwars.ItemMeta[v.item.itemType]
			if meta.breakBlock then
				return i - 1
			end
		end
	end
	return nil
end

local _losRayParams = RaycastParams.new()
_losRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function hasLineOfSight(from, to, targetCharacter)
    _losRayParams.FilterDescendantsInstances = {entitylib.character and entitylib.character.Character or workspace, targetCharacter}
    local direction = to - from
    local result = workspace:Raycast(from, direction, _losRayParams)
    return result == nil
end	

local function getScaffoldBlockForModule(limitItem)
	if limitItem.Enabled then
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name
		end
		return nil
	else
		local wool = getWool()
		if wool then
			return wool
		else
			for _, item in store.inventory.inventory.items do
				if bedwars.ItemMeta[item.itemType].block then
					return item.itemType
				end
			end
		end
	end
	return nil
end

run(function()
	local AimAssist
	local Targets
	local Sort
	local AimSpeed
	local Distance
	local AngleSlider
	local StrafeIncrease
	local KillauraTarget
	local ClickAim
	local AimPart
	local ViewMode
	local Mode
	local AimSpeed
	local SmoothnessToggle
	local Smoothness
	local AccelerationToggle
	local Acceleration
	local PriorityMode
	local ShakeToggle
	local ShakeAmount
	local ShakeValue
	local ShopCheck
	local WorkWithProjectiles
	local BlockCheck
	local Limit

	local target = nil
	local started = tick()

    local function getAttackData()
        if not entitylib.isAlive then return false end
        if ClickAim.Enabled and not inputService:IsMouseButtonPressed(0) and (tick() - bedwars.SwordController.lastSwing) > 0.3 then return false end
        if BlockCheck.Enabled and (tick() - store.lastHit) < 0.3 then return false end
        if Limit.Enabled and store.hand.toolType ~= 'sword' then return false end
		if ShopCheck.Enabled and (lplr.PlayerGui and lplr.PlayerGui:FindFirstChild("ItemShop")) then return false end
		if ViewMode.Value == 'First Person' then 
			if (lplr.Character.Head.Position - gameCamera.CFrame.Position).Magnitude > 2 then
				return false
			end
		elseif ViewMode.Value == 'Third Person' then
			if (lplr.Character.Head.Position - gameCamera.CFrame.Position).Magnitude < 2 then
				return false
			end
		end

        if (tick() - started) > 1 or not target or not target.Parent or not target.Humanoid or target.Humanoid.Health <= 0 then
			local p = AimPart.Value
			if p == 'Closest' then p = 'RootPart' end
            local ent = KillauraTarget.Enabled and store.KillauraTarget or entitylib.EntityPosition({
                Range = Distance.Value,
                Part = p,
                Wallcheck = Targets.Walls.Enabled,
                Players = Targets.Players.Enabled,
                NPCs = Targets.NPCs.Enabled,
                Sort = sortmethods[Sort.Value]
            })
            if ent then
                started = tick()
            end
            target = ent
        end
        return target
    end

	local function ease(t)
		return t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2
	end

	local function east(t)
		return t < 1 and 8 * t * t * t or 2 - math.pow(-4 * t + 2, 6) / 4
	end

	local cache = {}
	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService:GetMouseLocation()
	end

	local function getAim(ent)
		if AimPart.Value == 'Closest' then
			if not cache[ent.Character] then
				cache[ent.Character] = ent.Character:GetChildren()
			end
			local localPosition = getMousePosition()
			local magnitude, part = 9e9, nil

			for _, v in cache[ent.Character] do
				if v and v.Parent and v:IsA('BasePart') then
					local position, visible = gameCamera:WorldToViewportPoint(v.Position)
					if visible then
						local mag = (localPosition - Vector2.new(position.X, position.Y)).Magnitude
						if mag < magnitude then
							magnitude = mag
							part = v
						end
					end
				end
			end
			if part then return part.Position end
		end
		return ent[AimPart.Value].Position
	end

	local aimfuncs = {
		Simple = function(camFrame, ent, speed)
			local alpha = AimSpeed.Value * 0.035

			if AccelerationToggle.Enabled then
				alpha = alpha * Acceleration.Value
			end

			if SmoothnessToggle.Enabled then
				local smoothFactor = 1 - (Smoothness.Value - 1) * 0.085
				alpha = alpha * math.clamp(smoothFactor, 0.1, 1)
			end

			if StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) then
				alpha = alpha * 1.18   
			end

			local shake = Vector3.new(0, 0, 0)
			if ShakeToggle.Enabled then
				local rng = Random.new()
				shake = Vector3.new(
					(rng:NextNumber() - 0.5) * ShakeAmount.Value * 0.8,
					(rng:NextNumber() - 0.5) * ShakeAmount.Value * 0.8,
					(rng:NextNumber() - 0.5) * ShakeAmount.Value * 0.8
				)
			end

			local target = CFrame.lookAt(camFrame.Position, getAim(ent) + shake)
			return camFrame:Lerp(target, math.clamp(alpha * speed, 0, 0.92))
		end,

		Dynamic = function(camFrame, ent, speed)
			local progress = ease(math.min(tick() - started, 1))
			local alpha = (AimSpeed.Value * 0.028 * progress) + (0.6 * (1 - progress))

			if AccelerationToggle.Enabled then
				alpha = alpha * Acceleration.Value
			end

			if SmoothnessToggle.Enabled then
				local smoothFactor = 1 - (Smoothness.Value - 1) * 0.065
				alpha = alpha * math.clamp(smoothFactor, 0.15, 1)
			end

			if StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) then
				alpha = alpha * 1.12
			end

			local shake = Vector3.new(0, 0, 0)
			if ShakeToggle.Enabled then
				local rng = Random.new()
				shake = Vector3.new(
					(rng:NextNumber() - 0.5 - ShakeValue.Value * 0.1) * ShakeAmount.Value,
					(rng:NextNumber() - 0.5 - ShakeValue.Value * 0.1) * ShakeAmount.Value,
					(rng:NextNumber() - 0.5 - ShakeValue.Value * 0.1) * ShakeAmount.Value
				)
			end

			local target = CFrame.lookAt(camFrame.Position, getAim(ent) + shake)
			return camFrame:Lerp(target, math.clamp(alpha * speed, 0, 0.89))
		end,

		Adaptive = function(camFrame, ent, speed)
			local progress = ease(math.min(tick() - started, 1))
			local alpha = (AimSpeed.Value * 0.032 * progress) + (0.55 * (1 - progress))

			if AccelerationToggle.Enabled then
				alpha = alpha * Acceleration.Value
			end

			if SmoothnessToggle.Enabled then
				local smoothFactor = 1 - (Smoothness.Value - 1) * 0.055
				alpha = alpha * math.clamp(smoothFactor, 0.2, 1)
			end

			if StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) then
				alpha = alpha * 0.85  
			end

			local shake = Vector3.new(0, 0, 0)
			if ShakeToggle.Enabled then
				local rng = Random.new()
				shake = Vector3.new(
					(rng:NextNumber() - 0.5 - ShakeValue.Value * 0.08) * ShakeAmount.Value * 0.9,
					(rng:NextNumber() - 0.5 - ShakeValue.Value * 0.08) * ShakeAmount.Value * 0.9,
					(rng:NextNumber() - 0.5 - ShakeValue.Value * 0.08) * ShakeAmount.Value * 0.9
				)
			end

			local target = CFrame.lookAt(camFrame.Position, getAim(ent) + shake)
			return camFrame:Lerp(target, math.clamp(alpha * speed, 0, 0.87))
		end,
	}
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Disabled = canEngine,
		Function = function(callback)
			if callback then
				AimAssist:Clean(runService.Heartbeat:Connect(function(dt)
					local ent = getAttackData()
					if ent then
                        local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
                        local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
                        local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                        if angle >= (math.rad(AngleSlider.Value) / 2) then return end
                        targetinfo.Targets[ent] = tick() + 1
                        gameCamera.CFrame = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
					end
				end))
			end
		end,
		Tooltip = 'Smoothly aims to closest valid target'
	})
	Targets = AimAssist:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = AimAssist:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	AimPart = AimAssist:CreateDropdown({
		Name = 'Aim Part',
		List = {'RootPart', 'Head','Closest'},
		Default = 'RootPart'
	})
	ViewMode = AimAssist:CreateDropdown({
		Name = 'View Mode',
		List = {'First Person', 'Third Person', 'Both'},
		Default = 'Both',
		Tooltip = 'Only aim in first person, third person, or always'
	})
	Mode = AimAssist:CreateDropdown({
		Name = "Mode",
		Tooltip = 'Simple - Smooth aiming and normal aiming\nAdaptive - Advanced tracking with adaptive behavior\nDynamic - Just smooth and advance tracking with normal behavior',
		List = {'Simple','Adaptive','Dynamic'},
	})
	AimSpeed = AimAssist:CreateSlider({
		Name = 'Aim Speed',
		Min = 1,
		Max = 20,
		Default = 6
	})
	Distance = AimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffx = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 70
	})
	SmoothnessToggle = AimAssist:CreateToggle({
		Name = 'Smoothness',
		Default = false,
		Tooltip = 'Makes aim assist feel more legit',
		Function = function(callback)
			if Smoothness then Smoothness.Object.Visible = callback end
		end
	})
	Smoothness = AimAssist:CreateSlider({
		Name = 'Smoothness Amount',
		Min = 1,
		Max = 10,
		Default = 5,
		Tooltip = 'Higher = smoother and more legit.',
		Visible = false
	})
	AccelerationToggle = AimAssist:CreateToggle({
		Name = 'Acceleration Toggle',
		Default = false,
		Tooltip = 'Makes aim assist speed be sped up or slowed down',
		Function = function(callback)
			if Acceleration then Acceleration.Object.Visible = callback end
		end
	})
	Acceleration = AimAssist:CreateSlider({
		Name = "Acceleration",
		Min = 0,
		Max = 12,
		Default = 1,
		Decimal = 100,
		Visible = false
	})
	PriorityMode = AimAssist:CreateToggle({
		Name = 'Priority Mode',
		Default = false,
		Tooltip = 'Locks onto one target until they leave range or angle. Ignores new targets.'
	})
	ClickAim = AimAssist:CreateToggle({
		Name = 'Click Aim',
		Default = true
	})
	KillauraTarget = AimAssist:CreateToggle({
		Name = 'Use killaura target'
	})
	StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
	BlockCheck = AimAssist:CreateToggle({Name = 'Block Check'})
	Limit = AimAssist:CreateToggle({Name = 'Limit to swords'})
	ShakeToggle = AimAssist:CreateToggle({
		Name = 'Shake',
		Default = false,
		Tooltip = 'Adds slight jitter to aim to look more human',
		Function = function(callback)
			if ShakeAmount then ShakeAmount.Object.Visible = callback end
			if ShakeValue then ShakeValue.Object.Visible = callback end
		end
	})
	ShakeAmount = AimAssist:CreateSlider({
		Name = 'Shake Amount',
		Min = 1,
		Max = 10,
		Default = 3,
		Visible = false
	})
	ShakeValue = AimAssist:CreateSlider({
		Name = "Shake Value",
		Min = 0,
		Max = 2,
		Decimal = 100,
		Default = 0.5,
		Visible = false
	})
	ShopCheck = AimAssist:CreateToggle({
		Name = 'Shop Check',
		Default = false,
		Tooltip = 'Disables aim assist when the shop is open'
	})

	task.defer(function()
		if Smoothness and Smoothness.Object then
			Smoothness.Object.Visible = SmoothnessToggle and SmoothnessToggle.Enabled or false
		end
		if ShakeAmount and ShakeAmount.Object then
			ShakeAmount.Object.Visible = false
		end
		if ShakeValue and ShakeValue.Object then
			ShakeValue.Object.Visible = false
		end
		if Acceleration and Acceleration.Object then
			Acceleration.Object.Visible = false
		end
	end)
end)

run(function()
	local ProjectileAimAssist
	local Targets
	local PAMode
	local AimSpeed
	local ReactionTime
	local Distance
	local AngleSlider
	local AimPart
	local PriorityMode
	local ClickAim
	local VerticalAim
	local VerticalOffset
	local ShakeToggle
	local ShakeAmount
	local ShopCheck
	local FirstPersonCheck
	local StrafeMultiplier
	
	local rayCheck = cloneRaycast()
	
	local lockedTarget = nil
	local rng = Random.new()
	local lastAimCFrame = nil
	local aimingAtTarget = false
	local reactionStartTime = 0
	local hasReacted = false
	local currentTarget = nil
	
	local function getTravelTime(origin, targetPos, speed, gravity)
		if speed < 10 then return 0.1 end
			
		local dir = targetPos - origin
		local dist2D = Vector2.new(dir.X, dir.Z).Magnitude
		local heightDiff = dir.Y
			
		local t = dist2D / speed 
		for i = 1, 8 do
			local drop = 0.5 * gravity * t * t
			local effectiveDist = math.sqrt(dist2D * dist2D + (heightDiff + drop) * (heightDiff + drop))
			t = effectiveDist / speed
		end
		
		return t
	end

	local aerov4bad = {
		predictStrafingMovement = function(prt, speed, gravity, origin, ping, dest)
			local pos = prt.Position
			local vel = prt.Velocity
			local distance = (pos - origin).Magnitude

			local travelTime = getTravelTime(origin, pos, speed, math.abs(gravity)) + ping * 1.08

			local horizVel = Vector3.new(vel.X, 0, vel.Z)
			local horizMag = horizVel.Magnitude

			local hMult = 0.96
			if horizMag > 7 then
				if distance > 130 then      
					hMult = 0.97
				elseif distance > 90 then   
					hMult = 0.94
				elseif distance > 55 then   
					hMult = 0.88
				elseif distance > 30 then   
					hMult = 0.79
				else                        
					hMult = 0.64 + math.random() * 0.16
				end
			end

			local horizPred = horizVel * travelTime * hMult

			local vy = vel.Y
			local vMult = 0.91
			if vy < -42 then        vMult = 0.98
			elseif vy < -14 then    vMult = 0.95
			elseif vy > 20 then     vMult = 0.78
			elseif math.abs(vy) < 5 then vMult = 0.67
			end

			local vertPred = vy * travelTime * vMult

			local gravDrop = 0
			if gravity ~= 0 then
				gravDrop = 0.5 * gravity * (travelTime ^ 2)

				if speed >= 420 then      gravDrop *= 0.65
				elseif speed >= 280 then  gravDrop *= 0.76
				elseif speed >= 140 then  gravDrop *= 0.85
				end
			end

			local predictedPos = pos + horizPred + Vector3.new(0, vertPred + gravDrop, 0)

			if travelTime > 4 then
				local cap = 4
				predictedPos = pos + (horizVel * cap * hMult) + Vector3.new(0, vy * cap * vMult + 0.5 * gravity * (cap^2) * 0.72, 0)
			end

			return predictedPos
		end,
		predictFinishedPos = function(prt, speed, gravity, origin, ping)
			local pos = prt.Position
			local vel = prt.Velocity
			local travelTime = getTravelTime(origin, pos, speed, math.abs(gravity)) + ping * 0.95

			local horizVel = Vector3.new(vel.X, 0, vel.Z)
			local vertVel = vel.Y

			local horizPred = horizVel * travelTime * 0.94
			local vertPred = vertVel * travelTime * 0.89
			local gravDrop = 0.5 * gravity * (travelTime * travelTime) * 0.76

			local finalPos = pos + horizPred + Vector3.new(0, vertPred + gravDrop, 0)

			if travelTime > 3.7 then
				local cap = 3.7
				finalPos = pos + (horizVel * cap * 0.94) + Vector3.new(0, vertVel * cap * 0.89 + 0.5 * gravity * (cap^2) * 0.76, 0)
			end

			return finalPos
		end
	}
	
	local function getAimSpeed(sliderValue)
		local baseSpeed = 0.008
		local multiplier = 1.35
		local speed = baseSpeed * (multiplier ^ sliderValue)
		return math.min(speed, 0.95)
	end
	
	local function getTargetPart(ent)
		if not ent or not ent.Character then return nil end
		
		if AimPart.Value == "Head" then
			return ent.Character:FindFirstChild("Head") or ent.Head or ent.RootPart
		elseif AimPart.Value == "Torso" then
			return ent.Character:FindFirstChild("Torso") or ent.Character:FindFirstChild("UpperTorso") or ent.RootPart
		else
			return ent.RootPart
		end
	end
	
	local function getPredictedPosition(ent, origin)
		if not ent or not ent.RootPart then return nil end
		
		local targetBodyPart = getTargetPart(ent)
		if not targetBodyPart then return nil end
		
		if PAMode.Value == 'Aero' then
			local projSpeed = 100
			local gravity = 196.2
			
			if store.hand and store.hand.tool then
				local toolName = store.hand.tool.Name
				local itemMeta = bedwars.ItemMeta[toolName]
				if itemMeta and itemMeta.projectileSource then
					local projectileSource = itemMeta.projectileSource
					local projectileType = projectileSource.projectileType
					
					if type(projectileType) == "function" then
						local success, result = pcall(projectileType, nil)
						if success then
							projectileType = result
						end
					end
					
					if projectileType then
						local projectileMeta = bedwars.ProjectileMeta[projectileType]
						if projectileMeta then
							projSpeed = projectileMeta.launchVelocity or 100
							gravity = (projectileMeta.gravitationalAcceleration or 196.2)
						end
					end
				end
			end
			local ping = lplr:GetNetworkPing()

			local finalPos = aerov4bad.predictFinishedPos(
				targetBodyPart,
				projSpeed,
				gravity,
				origin,
				ping
			)

			local predictedPos = aerov4bad.predictStrafingMovement(
				targetBodyPart,
				projSpeed,
				gravity,
				origin,
				ping,
				finalPo
			)
			
			return predictedPos
		else
			local playerGravity = workspace.Gravity
			local balloons = ent.Character:GetAttribute('InflatedBalloons')
			
			if balloons and balloons > 0 then
				playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
			end
			
			if ent.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
				playerGravity = 6
			end
			
			if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
				for _, owl in collectionService:GetTagged('Owl') do
					if owl:GetAttribute('Target') == ent.Player.UserId and owl:GetAttribute('Status') == 2 then
						playerGravity = 0
						break
					end
				end
			end
			
			local projSpeed = 100
			local gravity = 196.2
			
			if store.hand and store.hand.tool then
				local toolName = store.hand.tool.Name
				local itemMeta = bedwars.ItemMeta[toolName]
				if itemMeta and itemMeta.projectileSource then
					local projectileSource = itemMeta.projectileSource
					local projectileType = projectileSource.projectileType
					
					if type(projectileType) == "function" then
						local success, result = pcall(projectileType, nil)
						if success then
							projectileType = result
						end
					end
					
					if projectileType then
						local projectileMeta = bedwars.ProjectileMeta[projectileType]
						if projectileMeta then
							projSpeed = projectileMeta.launchVelocity or 100
							gravity = (projectileMeta.gravitationalAcceleration or 196.2)
						end
					end
				end
			end
			
			local calc = prediction.SolveTrajectory(
				origin,
				projSpeed,
				gravity,
				targetBodyPart.Position,
				targetBodyPart.Velocity,
				playerGravity,
				ent.HipHeight,
				ent.Jumping and 42.6 or nil,
				rayCheck
			)
			
			return calc
		end
	end
	
	ProjectileAimAssist = vape.Categories.Combat:CreateModule({
		Name = 'ProjectileAimAssist',
		Disabled = canEngine,
		Function = function(callback)
			if callback then
				ProjectileAimAssist:Clean(runService.RenderStepped:Connect(function(dt)
					if not (entitylib.isAlive and isHoldingBowCrossbow() and ((not ClickAim.Enabled) or (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) < 0.4)) then
						lockedTarget = nil
						currentTarget = nil
						hasReacted = false
						return
					end
					
					if ShopCheck.Enabled then
						local isShop = lplr:FindFirstChild("PlayerGui") and lplr.PlayerGui:FindFirstChild("ItemShop")
						if isShop then return end
					end
					
					if FirstPersonCheck.Enabled and not isFirstPerson() then return end
					
					local ent = nil
					
					if PriorityMode.Enabled then
						if lockedTarget and isTargetValid(lockedTarget, Distance.Value, Targets.Walls.Enabled) then
							local delta = (lockedTarget.RootPart.Position - entitylib.character.RootPart.Position)
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
							local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
							
							if angle < (math.rad(AngleSlider.Value) / 2) then
								ent = lockedTarget
							else
								lockedTarget = nil
								currentTarget = nil
								hasReacted = false
							end
						else
							lockedTarget = nil
						end
						
						if not ent then
							ent = entitylib.EntityPosition({
								Range = Distance.Value,
								Part = 'RootPart',
								Wallcheck = Targets.Walls.Enabled,
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Sort = sortmethods.Distance
							})
							
							if ent then
								lockedTarget = ent
							end
						end
					else
						lockedTarget = nil
						ent = entitylib.EntityPosition({
							Range = Distance.Value,
							Part = 'RootPart',
							Wallcheck = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods.Distance
						})
					end
					
					if ent then
						if getAccountTier(ent.Player) >= 1 and getAccountTier(lplr) == 0 then return end
						if currentTarget ~= ent then
							currentTarget = ent
							hasReacted = false
							reactionStartTime = tick()
						end
						
						if not hasReacted then
							local reactionDelay = ReactionTime.Value / 1000
							local randomVariance = (rng:NextNumber() - 0.5) * 0.3 * reactionDelay
							local actualDelay = reactionDelay + randomVariance
							
							if (tick() - reactionStartTime) < actualDelay then
								return
							else
								hasReacted = true
							end
						end
						
						pcall(function()
							local plr = ent
							vapeTargetInfo.Targets.ProjectileAimAssist = {
								Humanoid = {
									Health = (plr.Character:GetAttribute("Health") or plr.Humanoid.Health) + getShieldAttribute(plr.Character),
									MaxHealth = plr.Character:GetAttribute("MaxHealth") or plr.Humanoid.MaxHealth
								},
								Player = plr.Player
							}
						end)
						
						local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
						local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
						local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
						if angle >= (math.rad(AngleSlider.Value) / 2) then return end
						
						targetinfo.Targets[ent] = tick() + 1
						
						local origin = entitylib.character.RootPart.Position
						local predictedPosition = getPredictedPosition(ent, origin)
						
						if not predictedPosition then return end
						
						local aimPosition = predictedPosition
						
						if VerticalAim.Enabled then
							aimPosition = aimPosition + Vector3.new(0, VerticalOffset.Value, 0)
						end
						
						local finalAimSpeed = getAimSpeed(AimSpeed.Value)
						
						if StrafeMultiplier.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) then
							finalAimSpeed = finalAimSpeed * 1.15
						end
						
						if ShakeToggle.Enabled and ShakeAmount.Value > 0 then
							local shakeIntensity = ShakeAmount.Value / 10
							local speedVariation = 1 + ((rng:NextNumber() - 0.5) * shakeIntensity * 0.3)
							finalAimSpeed = finalAimSpeed * speedVariation
							
							local jitterAmount = ShakeAmount.Value * 0.1
							local microJitter = Vector3.new(
								(rng:NextNumber() - 0.5) * jitterAmount,
								(rng:NextNumber() - 0.5) * jitterAmount,
								(rng:NextNumber() - 0.5) * jitterAmount
							)
							aimPosition = aimPosition + microJitter
						end
						
						local targetCFrame = CFrame.lookAt(gameCamera.CFrame.p, aimPosition)
						gameCamera.CFrame = gameCamera.CFrame:Lerp(targetCFrame, finalAimSpeed)
						lastAimCFrame = targetCFrame
						aimingAtTarget = true
					else
						currentTarget = nil
						hasReacted = false
						
						if aimingAtTarget and lastAimCFrame then
							local retractSpeed = 0.05
							if (gameCamera.CFrame.Position - lastAimCFrame.Position).Magnitude > 0.1 then
								gameCamera.CFrame = gameCamera.CFrame:Lerp(
									CFrame.new(gameCamera.CFrame.Position, gameCamera.CFrame.Position + gameCamera.CFrame.LookVector),
									retractSpeed
								)
							else
								aimingAtTarget = false
								lastAimCFrame = nil
							end
						end
						
						if PriorityMode.Enabled then
							lockedTarget = nil
						end
					end
				end))
			else
				lockedTarget = nil
				aimingAtTarget = false
				lastAimCFrame = nil
				currentTarget = nil
				hasReacted = false
			end
		end,
		Tooltip = 'Projectile aim assist with prediction'
	})
	
	Targets = ProjectileAimAssist:CreateTargets({
		Players = true,
		Walls = true
	})
	
	PAMode = ProjectileAimAssist:CreateDropdown({
		Name = 'Prediction Mode',
		List = {'Vape', 'Aero'},
		Default = 'Aero',
		Tooltip = 'Vape = Built-in | Aero = Custom'
	})
	
	AimSpeed = ProjectileAimAssist:CreateSlider({
		Name = 'Aim Speed',
		Min = 1,
		Max = 20,
		Default = 6,
		Tooltip = 'How fast the aim assistant tracks'
	})
	
	ReactionTime = ProjectileAimAssist:CreateSlider({
		Name = 'Reaction Time',
		Min = 0,
		Max = 300,
		Default = 80,
		Suffix = 'ms',
		Tooltip = 'Delay before aim assist activates'
	})
	
	Distance = ProjectileAimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 25,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	AngleSlider = ProjectileAimAssist:CreateSlider({
		Name = 'Max Angle',
		Min = 1,
		Max = 360,
		Default = 60,
		Tooltip = 'FOV angle for target acquisition'
	})
	
	AimPart = ProjectileAimAssist:CreateDropdown({
		Name = 'Aim Part',
		List = {'Root', 'Torso', 'Head'},
		Default = 'Root'
	})
	
	PriorityMode = ProjectileAimAssist:CreateToggle({
		Name = 'Priority Mode',
		Default = false,
		Tooltip = 'Lock onto one target'
	})
	
	ClickAim = ProjectileAimAssist:CreateToggle({
		Name = 'Click Aim',
		Default = true,
		Tooltip = 'Only aim when attacking'
	})
	
	VerticalAim = ProjectileAimAssist:CreateToggle({
		Name = 'Vertical Offset',
		Default = false,
		Function = function(callback)
			VerticalOffset.Object.Visible = callback
		end
	})
	
	VerticalOffset = ProjectileAimAssist:CreateSlider({
		Name = 'Offset',
		Min = -3,
		Max = 3,
		Default = 0,
		Decimal = 10,
		Visible = false
	})
	
	ShakeToggle = ProjectileAimAssist:CreateToggle({
		Name = 'Shake',
		Default = false,
		Function = function(callback)
			ShakeAmount.Object.Visible = callback
		end,
		Tooltip = 'Add jitter to aim'
	})
	
	ShakeAmount = ProjectileAimAssist:CreateSlider({
		Name = 'Shake Amount',
		Min = 1,
		Max = 10,
		Default = 3,
		Visible = false
	})
	
	ShopCheck = ProjectileAimAssist:CreateToggle({
		Name = "Shop Check",
		Default = false,
		Tooltip = 'Disable when shop is open'
	})
	
	FirstPersonCheck = ProjectileAimAssist:CreateToggle({
		Name = "First Person Only",
		Default = false,
		Tooltip = 'Only work in first person'
	})
	
    StrafeMultiplier = ProjectileAimAssist:CreateToggle({
        Name = 'Strafe Boost',
        Tooltip = 'Faster aim when strafing'
    })

    task.defer(function()
        if VerticalOffset and VerticalOffset.Object then
            VerticalOffset.Object.Visible = false
        end
        if ShakeAmount and ShakeAmount.Object then
            ShakeAmount.Object.Visible = false
        end
    end)
end)

run(function()
    local AutoClicker
    local CPS
    local BlockCPS = {}
    local SwordCPS = {}
    local PlaceBlocksToggle
    local SwingSwordToggle
    local Thread
    local task_wait = task.wait
    local task_spawn = task.spawn
    local workspace_GetServerTimeNow = function() return workspace:GetServerTimeNow() end

     local function getSafeCPS()
        local toolType = store.hand and store.hand.toolType or nil
        if toolType == 'block' and PlaceBlocksToggle and PlaceBlocksToggle.Enabled and BlockCPS and BlockCPS.GetRandomValue then
            return BlockCPS
        elseif toolType == 'sword' and SwingSwordToggle and SwingSwordToggle.Enabled and SwordCPS and SwordCPS.GetRandomValue then
            return SwordCPS
        elseif CPS and CPS.GetRandomValue then
            return CPS
        end
        return nil
    end

    local function AutoClickAero()
        if Thread then task.cancel(Thread) end
        Thread = task_spawn(function()
            repeat
                if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                    local toolType = store.hand and store.hand.toolType
                    if PlaceBlocksToggle.Enabled and toolType == 'block' then
                        local blockPlacer = bedwars.BlockPlacementController and bedwars.BlockPlacementController.blockPlacer
                        if blockPlacer then
							if inputService.TouchEnabled then
								task.spawn(function()
									blockPlacer:autoBridge(workspace_GetServerTimeNow - bedwars.KnockbackController:getLastKnockbackTime() >= 0.2)
								end)
							else
								local blockRate = BlockCPS and BlockCPS.GetRandomValue and BlockCPS.GetRandomValue() or 12
								if (workspace_GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / blockRate) * 0.5) then
									local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
									if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
										task_spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
									end
								end
							end
                        end
                    elseif SwingSwordToggle.Enabled and toolType == 'sword' then
                        bedwars.SwordController:swingSwordAtMouse(0.39)
                        end
                    end

                local currentCPS = getSafeCPS()
                task_wait(1 / (currentCPS and currentCPS.GetRandomValue() or 7))
            until not AutoClicker.Enabled
        end)
    end

    local function StopAutoClick()
        if Thread then
            task.cancel(Thread)
            Thread = nil
        end
    end

    local MIN_HOLD_TIME = 0.12
    local ActivationScheduled = nil

    AutoClicker = vape.Categories.Combat:CreateModule({
        Name = 'AutoClicker',
        Function = function(callback)
            if callback then
                AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        ActivationScheduled = task.delay(MIN_HOLD_TIME, function()
                            ActivationScheduled = nil
							AutoClickAero()
                        end)
                    end
                end))
                AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        if ActivationScheduled then
                            task.cancel(ActivationScheduled)
                            ActivationScheduled = nil
                        end
                        if Thread then
                            task.cancel(Thread)
                            Thread = nil
                        end
                    end
                end))
            else
                if ActivationScheduled then
                    task.cancel(ActivationScheduled)
                    ActivationScheduled = nil
                end
                StopAutoClick()
            end
        end,
        Tooltip = 'Clicks for you'
    })

    PlaceBlocksToggle = AutoClicker:CreateToggle({
        Name = 'Place Blocks',
        Default = false,
        Function = function(callback)
            task.defer(function()
                if BlockCPS and BlockCPS.Object then BlockCPS.Object.Visible = callback end
            end)
        end
    })

    BlockCPS = AutoClicker:CreateTwoSlider({
        Name = 'Block CPS',
        Min = 1,
        Max = 20,
        DefaultMin = 12,
        DefaultMax = 12,
        Darker = true
    })

    SwingSwordToggle = AutoClicker:CreateToggle({
        Name = 'Swing Sword',
        Default = false,
        Function = function(callback)
            if SwordCPS.Object then SwordCPS.Object.Visible = callback end
        end
    })

    SwordCPS = AutoClicker:CreateTwoSlider({
        Name = 'Sword CPS',
        Min = 1,
		Max = 9,
        DefaultMin = 7,
        DefaultMax = 7,
        Darker = true
    })

    task.defer(function()
        if BlockCPS and BlockCPS.Object then
            BlockCPS.Object.Visible = PlaceBlocksToggle and PlaceBlocksToggle.Enabled
        end
        if SwordCPS and SwordCPS.Object then
            SwordCPS.Object.Visible = SwingSwordToggle and SwingSwordToggle.Enabled
        end
    end)
end)  

run(function()
	local KitRender

	local waitForChild = function(s, ...)
		local parent = s
		for _, childName in {...} do
			parent = parent:WaitForChild(childName, math.huge)
			if not parent then break end
		end
		return parent
	end

    local function getPlayerFromDraft(render, name,gm)
		if gm == '5v5' then
			for i, v in playersService:GetPlayers() do
				if v:GetAttribute("DisguiseDisplayName") == name or bedwars.StreamerModeController:getDisplayName(v) == name then
					return v
				end
			end
		else
            local userId = string.match(render, "id=(%d+)")
            if userId then
                return playersService:GetPlayerByUserId(tonumber(userId))
            end
		end
		return
    end

	local function callback5v5(v)
		local render = v:FindFirstChild('PlayerRender')
		local plr = getPlayerFromDraft(render,v.TextBackgroundBar.PlayerName.Text or '','5v5')
		if plr then
			local currentKit = plr:GetAttribute("PlayingAsKits") or plr:GetAttribute("PlayingAsKit") or 'none'
			local kitImage = bedwars.BedwarsKitMeta[currentKit].renderImage
			local aeroroact = v:FindFirstChild("AeroV4KitRender")

			if not aeroroact then
   				aeroroact = Instance.new('ImageLabel')
				aeroroact.Parent = v
                aeroroact.BackgroundTransparency = 1
                aeroroact.AnchorPoint = Vector2.new(1, 0.5)
                aeroroact.Position = UDim2.fromScale(1.05, 0.5)
                aeroroact.Name = 'AeroV4KitRender'
                aeroroact.Size = UDim2.fromScale(1.5, 1.5)
                aeroroact.ZIndex = 1
                aeroroact.ImageTransparency = 0.4
                aeroroact.SliceCenter = Rect.new(0, 0, 0, 0)
                aeroroact.SliceScale = 1
                aeroroact.ScaleType = 'Crop'
                KitRender:Clean(aeroroact)
                local ratio = Instance.new('UIAspectRatioConstraint', aeroroact)
                ratio.Name = '1'
                ratio.AspectRatio = 1
                ratio.AspectType = Enum.AspectType.FitWithinMaxSize
                ratio.DominantAxis = Enum.DominantAxis.Width
			end
            aeroroact.Image = kitImage
            aeroroact.Position = UDim2.fromScale(1.05, 0)
            tweenService:Create(aeroroact, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                Position = UDim2.fromScale(1.05, 0.4)
            }):Play()

            KitRender:Clean(player:GetAttributeChangedSignal('PlayingAsKits'):Connect(function()
				task.delay(lplr:GetNetworkPing() * 10, function()
					currentKit = plr:GetAttribute("PlayingAsKits") or plr:GetAttribute("PlayingAsKit") or 'none'
					kitImage = bedwars.BedwarsKitMeta[currentKit].renderImage
					aeroroact.Image = kitImage
				end)
            end))
		end
	end

	local function callbacksquad(v)
        local render = v:FindFirstChild('PlayerRender')
        local plr = render and getPlayerFromDraft(render.Image, '') or nil

        if plr then 
			local currentKit = plr:GetAttribute("PlayingAsKits") or plr:GetAttribute("PlayingAsKit") or 'none'
			local kitImage = bedwars.BedwarsKitMeta[currentKit].renderImage
            local aeroroact = v:FindFirstChild('AeroV4KitRender') or v:WaitForChild('3', 9e9)
            aeroroact = aeroroact:Clone()
            aeroroact.Parent = v
            aeroroact.Name = 'AeroV4KitRender'
            aeroroact.Image = kitImage

            KitRender:Clean(render:GetPropertyChangedSignal('Image'):Connect(function()
                KitRender:Toggle()
                KitRender:Toggle()
            end))
            KitRender:Clean(aeroroact)
            KitRender:Clean(plr:GetAttributeChangedSignal('PlayingAsKits'):Connect(function()
				task.delay(lplr:GetNetworkPing() * 10, function()
					currentKit = plr:GetAttribute("PlayingAsKits") or plr:GetAttribute("PlayingAsKit") or 'none'
					kitImage = bedwars.BedwarsKitMeta[currentKit].renderImage
					aeroroact.Image = kitImage
				end)
            end))
        end
	end

	KitRender = vape.Categories.Render:CreateModule({
        Name = 'KitRender',
        Tooltip = "Allows you to see everyone's kit during kit phase",
        Function = function(callback)
            if callback then
                local DraftApp = lplr.PlayerGui:WaitForChild('MatchDraftApp', 9e9)
                if store.rankedType == '5v5' then
                    KitRender:Clean(DraftApp.DraftAppBackground['1'].BodyContainer.TeamsColumn.ChildAdded:Connect(function()
                        task.wait(2)

                        if KitRender.Enabled then
                            KitRender:Toggle()
                            KitRender:Toggle()
                        end
                    end))

                    for _, v: Instance in DraftApp.DraftAppBackground['1'].BodyContainer.TeamsColumn:GetChildren() do
                        if v:IsA('Frame') then
                            v = waitForChild(v, '1'):FindFirstChild('MatchDraftPlayerCard', true)
							task.delay(lplr:GetNetworkPing() * 4.5, callback5v5, plr)
                        end
                    end
                elseif store.rankedType == 'sqauds' then
                    local TeamsColumn = DraftApp:WaitForChild('DraftAppBackground', 9e9):WaitForChild('1', 9e9):WaitForChild('BodyContainer', 9e9):WaitForChild('TeamsColumn', 9e9)

                    for _, v: Instance in TeamsColumn:GetChildren() do
                        if v:IsA('Frame') then
                            local plrframe = waitForChild(v, '1', '2', '4')

                            for _, plr in plrframe:GetChildren() do
                                callbacksquad(plr)
                            end

                            KitRender:Clean(plrframe.ChildAdded:Connect(function(plr)
                                task.delay(lplr:GetNetworkPing() * 4.5, callbacksquad, plr)
                            end))
                        end
                    end
                end
            else
				for _, v in lplr.PlayerGui:GetDescendants() do
					if v:IsA("ImageLabel") and v.Name == 'AeroV4KitRender' then
						v:Destroy()
					end
				end
			end
        end
    })
end)
	
run(function()
	local Attack
	local Mine
	local Place
	local oldAttackReach, oldMineReach, oldPlaceReach
	local SwordReach, MineReach

	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				if SwordReach.Enabled then
					oldAttackReach = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
				end
				
				task.spawn(function()
					repeat task.wait(0.1) until bedwars.BlockBreakController or not Reach.Enabled
					if not Reach.Enabled or not MineReach.Enabled then return end
					
					pcall(function()
						local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
						if blockBreaker then
							oldMineReach = oldMineReach or blockBreaker:getRange()
							blockBreaker:setRange(Mine.Value)
						end
					end)
				end)
				
				task.spawn(function()
					while Reach.Enabled do
						task.wait(5)
						if not Reach.Enabled then break end
						if SwordReach.Enabled and bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE ~= Attack.Value + 2 then
							bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
						end
						if MineReach.Enabled then
							pcall(function()
								local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
								if blockBreaker and blockBreaker:getRange() ~= Mine.Value then
									blockBreaker:setRange(Mine.Value)
								end
							end)
						end
						if PlaceReach.Enabled then
							pcall(function()
								local blockPlacer = bedwars.BlockPlacementController:getBlockPlacer()
								if blockPlacer and blockPlacer.blockHighlighter then
									if blockPlacer.blockHighlighter.range ~= Place.Value then
										blockPlacer.blockHighlighter:setRange(Place.Value)
										blockPlacer.blockHighlighter.range = Place.Value
									end
								end
							end)
						end
					end
				end)
			else
				if oldAttackReach then
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = oldAttackReach
				end
				
				if oldMineReach then
					pcall(function()
						local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
						if blockBreaker then
							blockBreaker:setRange(oldMineReach)
						end
					end)
				end

				oldAttackReach, oldMineReach = nil, nil
			end
		end,
		Tooltip = 'Extends reach for attacking, mining, and placing blocks'
	})
	
	SwordReach = Reach:CreateToggle({
		Name = 'Sword Reach',
		Default = true,
		Function = function(v)
			if Attack then Attack.Object.Visible = v end
			if Reach.Enabled then
				if v then
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
				else
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = oldAttackReach or 14.4
				end
			end
		end
	})

	Attack = Reach:CreateSlider({
		Name = 'Attack Range',
		Darker = true,
		Visible = true,
		Min = 0,
		Max = 20,
		Default = 18,
		Function = function(val)
			if Reach.Enabled then
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = val + 2
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	MineReach = Reach:CreateToggle({
		Name = 'Mine Reach',
		Default = false,
		Function = function(v)
			if Mine then Mine.Object.Visible = v end
		end
	})

	Mine = Reach:CreateSlider({
		Name = 'Mine Range',
		Darker = true,
		Visible = false,
		Min = 0,
		Max = 30,
		Default = 18,
		Function = function(val)
			if Reach.Enabled then
				pcall(function()
					local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
					if blockBreaker then
						blockBreaker:setRange(val)
					end
				end)
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then 
					pcall(function() 
						lplr.PlayerGui.MobileUI['4'].Visible = false 
					end) 
				end
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() 
					task.delay(0.1, function() 
						bedwars.SprintController:stopSprinting() 
					end) 
				end))
				bedwars.SprintController:stopSprinting()
			else
				if inputService.TouchEnabled then 
					pcall(function() 
						lplr.PlayerGui.MobileUI['4'].Visible = true 
					end) 
				end
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
end)
	
run(function()
	local TriggerBot
	local CPS
	local ProjectileMode
	local ProjectileFireRate
	local ProjectileWaitDelay
	local ProjectileFirstPerson
	local rayParams = cloneRaycast()
	local lastProjectileShot = 0
	local wasHoldingProjectile = false
	local tick = tick
	local task_wait = task.wait
	local pcall = pcall
	local lastClickTime = 0
	local clickCooldown = 0.015	
	local lastProjectileCheck = 0
	local triggerFilterConnection = nil
	local cachedProjectileResult = false
	local lastHotbarSlot = -1
	local cachedSwordRange = nil
	local lastSwordTool = nil
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				local frameCounter = 0
				local lastToolType = nil
				
				local triggerFilterTable = {lplr.Character}
				triggerFilterConnection = lplr.CharacterAdded:Connect(function(char)
					triggerFilterTable[1] = char
				end)
			
				repeat
					frameCounter = frameCounter + 1
					local doAttack = false
					local holdingProjectile = isHoldingBowCrossbow(true)
					
					if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) and entitylib.isAlive then
						if ProjectileMode.Enabled and holdingProjectile then
							if ProjectileFirstPerson.Enabled and not isFirstPerson() then
								wasHoldingProjectile = false
							else
								if holdingProjectile and not wasHoldingProjectile then
									task_wait(ProjectileWaitDelay.Value)
									leftClick()
									lastProjectileShot = tick()
									wasHoldingProjectile = true
								elseif holdingProjectile then
									local currentTime = tick()
									if (currentTime - lastProjectileShot) >= ProjectileFireRate.Value then
										leftClick()
										lastProjectileShot = currentTime
									end
								else
									wasHoldingProjectile = false
								end
							end
						elseif store.hand.toolType == 'sword' and bedwars.DaoController.chargingMaid == nil then
							local currentTool = store.hand.tool
							if currentTool ~= lastSwordTool then
								lastSwordTool = currentTool
								local itemMeta = bedwars.ItemMeta[currentTool.Name]
								cachedSwordRange = itemMeta and itemMeta.sword and itemMeta.sword.attackRange or 14.4
							end
							
							local attackRange = cachedSwordRange or 14.4
							
							if frameCounter % 2 == 0 then
								rayParams.FilterDescendantsInstances = triggerFilterTable

								local unit = lplr:GetMouse().UnitRay
								local localPos = entitylib.character.RootPart.Position
								local rayRange = attackRange
								local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)

								if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
									local entityList = entitylib.List
									for i = 1, #entityList do
										local ent = entityList[i]
										doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
										if doAttack then
											break
										end
									end
								end
							end
							
							if not doAttack then
								doAttack = bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
							end
							
							if doAttack then
								bedwars.SwordController:swingSwordAtMouse()
							end
						else
							wasHoldingProjectile = false
						end
					end
					
					if doAttack and not holdingProjectile then
						task_wait(1 / CPS.GetRandomValue())
					else
						task_wait(holdingProjectile and 0.033 or 0.05)
					end
				until not TriggerBot.Enabled
			else
				if triggerFilterConnection then
					triggerFilterConnection:Disconnect()
					triggerFilterConnection = nil
				end
				triggerFilterTable = nil
				cachedSwordRange = nil
				lastSwordTool = nil
				lastHotbarSlot = -1
				wasHoldingProjectile = false
			end
		end,
		Tooltip = 'Automatically swings when hovering over a entity'
	})
	
	CPS = TriggerBot:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
	
	ProjectileMode = TriggerBot:CreateToggle({
		Name = 'Projectile Mode',
		Tooltip = 'Auto-shoots crossbow/bow when holding projectile weapon'
	})
	
	ProjectileFireRate = TriggerBot:CreateSlider({
		Name = 'Projectile Fire Rate',
		Min = 0.1,
		Max = 3,
		Default = 1.2,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'How fast to auto-fire (1.2 = every 1.2 seconds)',
		Visible = function()
			return ProjectileMode.Enabled
		end
	})
	
	ProjectileWaitDelay = TriggerBot:CreateSlider({
		Name = 'Projectile Wait Delay',
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay before shooting (helps prevent ghosting)',
		Visible = function()
			return ProjectileMode.Enabled
		end
	})
	
    ProjectileFirstPerson = TriggerBot:CreateToggle({
        Name = 'Projectile First Person Only',
        Default = false,
        Tooltip = 'Only works in first person mode',
        Visible = function()
            return ProjectileMode.Enabled
        end
    })
end)
	
run(function()
	local Velocity
	local Vertical
	local VerticalChance
	local Horizontal
	local HorizontalChance
	local Mode
	local DelayGround
	local DelayAir
	local Targetting
	local Chance

	local old = nil
	local rand = Random.new()

	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Tooltip = 'allows you to edit ur velocity',
		Function = function(callback)
			if callback then
				old = bedwars.KnockbackUtil.applyKnockback
				Velocity:Clean(vapeEvents.TakeKnockback.Event:Connect(function(root, mass, dir, knockback, ...)
					local args = {...}
					local clone = table.clone(knockback)

					local air, ground = false, false
					task.delay(DelayAir.Value / 1000, function()
						clone.horizontal = knockback.horizontal or 1
						air = true
					end)
					task.delay(DelayGround.Value / 1000, function()
						clone.vertical = knockback.vertical or 1
						ground = true
					end)
					repeat task.wait(0.1) until air
					repeat task.wait(0.05) until ground
					old(root, mass, dir, clone, unpack(args))
				end))

				bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
					local chance = rand:NextNumber(0, 100)
					chance = math.floor(chance)
					if Mode.Value == 'Normal' then
						if chance >= Chance.Value then return old(root, mass, dir, knockback, ...) end
					end
						
					local check = (not Targetting.Enabled) or entitylib.EntityPosition({
						Range = 20,
						Part = 'RootPart',
						Players = true
					})
		
					if check then
						knockback = knockback or {}
						if Mode.Value == 'Lag' then
							if chance < Chance.Value then
								return vapeEvents.TakeKnockback:Fire(root, mass, dir, knockback, ...)
							end
						else
							local horiz = (knockback.horizontal or 1) * (Horizontal.Value / 100)
							local vert = (knockback.vertical or 1) * (Vertical.Value / 100)
							chance = rand:NextNumber(0, 100)
							chance = math.floor(chance)
							if Horizontal.Value == 0 and Vertical.Value == 0 and HorizontalChance.Value == 100 and VerticalChance.Value then return end
							if chance >= HorizontalChance.Value then  
								chance = rand:NextNumber(0, 100)
								chance = math.floor(chance)
								horiz = knockback.horizontal 
							end
							if chance >= VerticalChance.Value then  
								chance = rand:NextNumber(0, 100)
								chance = math.floor(chance)
								vert = knockback.vertical 
							end
							knockback.horizontal = horiz
							knockback.vertical = vert
						end
					end
						
					return old(root, mass, dir, knockback, ...)
				end
			else
				bedwars.KnockbackUtil.applyKnockback = old
				old = nil
			end
		end
	})
	Mode = Velocity:CreateDropdown({
		Name = "Mode",
		List = {'Lag','Default'},
		Function = function(val)
			if val == 'Default' then
				if HorizontalChance then HorizontalChance.Object.Visible = true end
				if Horizontal then Horizontal.Object.Visible = true end
				if VerticalChance then VerticalChance.Object.Visible = true end
				if Vertical then Vertical.Object.Visible = true end
				if DelayGround then DelayGround.Object.Visible = false end
				if DelayAir then DelayAir.Object.Visible = false end
			elseif val == 'Lag' then
				if HorizontalChance then HorizontalChance.Object.Visible = false end
				if Horizontal then Horizontal.Object.Visible = false end
				if VerticalChance then VerticalChance.Object.Visible = false end
				if Vertical then Vertical.Object.Visible = false end
				if DelayGround then DelayGround.Object.Visible = true end
				if DelayAir then DelayAir.Object.Visible = true end
			else
				if HorizontalChance then HorizontalChance.Object.Visible = false end
				if Horizontal then Horizontal.Object.Visible = false end
				if VerticalChance then VerticalChance.Object.Visible = false end
				if Vertical then Vertical.Object.Visible = false end
				if DelayGround then DelayGround.Object.Visible = false end
				if DelayAir then DelayAir.Object.Visible = false end
				vape:CreateNotification('Velocity',`Storing packets... returned {val or Mode.Value} report ASAP`,16)
			end
		end
	})
	Vertical = Velocity:CreateSlider({
		Name = "Vertical",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 10,
		Visible = (Mode.Value == 'Default')
	})
	VerticalChance = Velocity:CreateSlider({
		Name = "Vertical Chance",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 100,
		Suffix = '%',
		Visible = (Mode.Value == 'Default')
	})
	Horizontal = Velocity:CreateSlider({
		Name = "Horizontal",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 10,
		Visible = (Mode.Value == 'Default')
	})
	HorizontalChance = Velocity:CreateSlider({
		Name = "Horizontal Chance",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 100,
		Suffix = '%',
		Visible = (Mode.Value == 'Default')
	})
	DelayGround = Velocity:CreateSlider({
		Name = "Delay Ground",
		Min = 0,
		Max = 3000,
		Default = 1000,
		Suffix = 'ms',
		Decimal = 100,
		Visible = (Mode.Value == 'Lag')
	})
	DelayAir = Velocity:CreateSlider({
		Name = "Air Ground",
		Min = 0,
		Max = 3000,
		Default = 1000,
		Suffix = 'ms',
		Decimal = 100,
		Visible = (Mode.Value == 'Lag')
	})
	Targetting = Velocity:CreateToggle({
		Name = 'Only when targetting',
		Default = false
	})
	Chance = Velocity:CreateSlider({
		Name = "Chance",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 100,
		Suffix = '%',
	})
end)
	
local AntiFallDirection
run(function()
    local AntiFall
    local Mode
    local Material
    local Color
	local rayCheck = cloneRaycast()
    rayCheck.RespectCanCollide = true

    local math_huge = math.huge
    local tick = tick
    local task_wait = task.wait
    local vector3new = Vector3.new
    local vector3zero = Vector3.zero
    
    local cachedLowGround = math_huge
    local lastGroundScan = 0
    local groundScanInterval = 2 
    
    local function getLowGround()
        local now = tick()
        if now - lastGroundScan < groundScanInterval and cachedLowGround ~= math_huge then
            return cachedLowGround
        end
        
        lastGroundScan = now
        local mag = math_huge
        local blockStore = bedwars.BlockController:getStore()
        local allPositions = blockStore:getAllBlockPositions()
        
        for i = 1, #allPositions do
            local pos = allPositions[i] * 3
            if pos.Y < mag and not getPlacedBlock(pos + vector3new(0, 3, 0)) then
                mag = pos.Y
            end
        end
        
        cachedLowGround = mag
        return mag
    end

    AntiFall = vape.Categories.Blatant:CreateModule({
        Name = 'AntiFall',
        Function = function(callback)
            if callback then
                repeat task_wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
                if not AntiFall.Enabled then return end

                local pos, debounce = getLowGround(), tick()
                if pos ~= math_huge then
                    AntiFallPart = Instance.new('Part')
                    AntiFallPart.Size = vector3new(10000, 1, 10000)
                    AntiFallPart.Transparency = 1 - Color.Opacity
                    AntiFallPart.Material = Enum.Material[Material.Value]
                    AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                    AntiFallPart.Position = vector3new(0, pos - 2, 0)
                    AntiFallPart.CanCollide = Mode.Value == 'Collide'
                    AntiFallPart.Anchored = true
                    AntiFallPart.CanQuery = false
                    AntiFallPart.Parent = workspace
                    AntiFall:Clean(AntiFallPart)
                    
                    AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
                        if touched.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
                            debounce = tick() + 0.1
                            
                            if Mode.Value == 'Normal' then
                                local top = getNearGround()
                                if top then
                                    local lastTeleport = lplr:GetAttribute('LastTeleported')
                                    local connection
                                    local frameCounter = 0
                                    
                                    local vapeModules = vape.Modules
                                    local flyEnabled = vapeModules.Fly
                                    local infFlyEnabled = vapeModules.InfiniteFly
                                    local longJumpEnabled = vapeModules.LongJump
                                    
                                    local yMask = vector3new(1, 0, 1)
                                    local yOnly = vector3new(0, 1, 0)
                                    
                                    connection = runService.PreSimulation:Connect(function()
                                        frameCounter = frameCounter + 1
                                        
                                        if frameCounter % 5 == 0 then
                                            if flyEnabled.Enabled or infFlyEnabled.Enabled or longJumpEnabled.Enabled then
                                                connection:Disconnect()
                                                AntiFallDirection = nil
                                                return
                                            end
                                        end

                                        if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
                                            local root = entitylib.character.RootPart
                                            local rootPos = root.Position
                                            local delta = (top - rootPos) * yMask
                                            
                                            AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or vector3zero
                                            root.Velocity *= yMask
                                            
                                            if frameCounter % 3 == 0 then
                                                rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
                                                rayCheck.CollisionGroup = root.CollisionGroup

                                                local ray = workspace:Raycast(rootPos, AntiFallDirection, rayCheck)
                                                if ray then
                                                    for i = 1, 5 do
                                                        local dpos = roundPos(ray.Position + ray.Normal * 1.5) + vector3new(0, 3, 0)
                                                        if not getPlacedBlock(dpos) then
                                                            top = vector3new(top.X, pos.Y, top.Z)
                                                            break
                                                        end
                                                    end
                                                end
                                            end

                                            local yDiff = top.Y - rootPos.Y
                                            root.CFrame += vector3new(0, yDiff, 0)
                                            
                                            if not frictionTable.Speed then
                                                local speed = getSpeed()
                                                local newVelocity = (AntiFallDirection * speed) + vector3new(0, root.AssemblyLinearVelocity.Y, 0)
                                                root.AssemblyLinearVelocity = newVelocity
                                            end

                                            if delta.Magnitude < 1 then
                                                connection:Disconnect()
                                                AntiFallDirection = nil
                                            end
                                        else
                                            connection:Disconnect()
                                            AntiFallDirection = nil
                                        end
                                    end)
                                    AntiFall:Clean(connection)
                                end
                            elseif Mode.Value == 'Velocity' then
                                local rootVel = entitylib.character.RootPart.Velocity
                                entitylib.character.RootPart.Velocity = vector3new(rootVel.X, 100, rootVel.Z)
                            end
                        end
                    end))
                end
            else
                AntiFallDirection = nil
                cachedLowGround = math_huge
                lastGroundScan = 0
            end
        end,
        Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
    })
    
    Mode = AntiFall:CreateDropdown({
        Name = 'Move Mode',
        List = {'Normal', 'Collide', 'Velocity'},
        Function = function(val)
            if AntiFallPart then
                AntiFallPart.CanCollide = val == 'Collide'
            end
        end,
        Tooltip = 'Normal - Smoothly moves you towards the nearest safe point\nVelocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
    })
    
    local materials = {'ForceField'}
    for _, v in Enum.Material:GetEnumItems() do
        if v.Name ~= 'ForceField' then
            table.insert(materials, v.Name)
        end
    end
    
    Material = AntiFall:CreateDropdown({
        Name = 'Material',
        List = materials,
        Function = function(val)
            if AntiFallPart then
                AntiFallPart.Material = Enum.Material[val]
            end
        end
    })
    
    Color = AntiFall:CreateColorSlider({
        Name = 'Color',
        DefaultOpacity = 0.5,
        Function = function(h, s, v, o)
            if AntiFallPart then
                AntiFallPart.Color = Color3.fromHSV(h, s, v)
                AntiFallPart.Transparency = 1 - o
            end
        end
    })
end)
	
run(function()
    local FastBreak
    local Time
    local BedCheck
    local Blacklist
    local blocks
    local string_lower = string.lower
    local string_find = string.find
    local task_wait = task.wait
    local collectionService = collectionService
    local currentBlock = nil
    local oldHitBlock = nil
    local lastHotbarSlot = nil
    local bedCache = {}
    local blacklistCache = {}
    local lastCacheClean = 0
    local cacheCleanInterval = 5 
    
    local function isBed(block)
        if not block then return false end
        local cached = bedCache[block]
        if cached ~= nil then return cached end
        
        local result = false
        pcall(function()
            if collectionService:HasTag(block, 'bed') or (block.Parent and collectionService:HasTag(block.Parent, 'bed')) then
                result = true
            elseif string_find(string_lower(block.Name), 'bed', 1, true) then
                result = true
            end
        end)
        
        bedCache[block] = result
        return result
    end
    
    local cachedBlacklistLower = {}
    local function updateBlacklistCache()
        if not blocks or not blocks.ListEnabled then return end
        
        cachedBlacklistLower = {}
        for _, v in pairs(blocks.ListEnabled) do
            table.insert(cachedBlacklistLower, string_lower(v))
        end
    end
    
    local function isBlacklisted(block)
        if not block or #cachedBlacklistLower == 0 then return false end
        local cached = blacklistCache[block]
        if cached ~= nil then return cached end
        
        local name = string_lower(block.Name)
        local result = false
        for i = 1, #cachedBlacklistLower do
            if string_find(name, cachedBlacklistLower[i], 1, true) then
                result = true
                break
            end
        end
        
        blacklistCache[block] = result
        return result
    end
    
    local function shouldSkip(block)
        if not block then return false end
        if BedCheck and BedCheck.Enabled and isBed(block) then return true end
        if Blacklist and Blacklist.Enabled and isBlacklisted(block) then return true end
        return false
    end
    
    local lastBreakUpdate = 0
    local breakUpdateCooldown = 0.05
    local pendingUpdate = false
    
    local function updateBreakSpeed()
        if not FastBreak or not FastBreak.Enabled then return end
        local now = tick()
        if now - lastBreakUpdate < breakUpdateCooldown then
            pendingUpdate = true
            return
        end
        lastBreakUpdate = now
        pendingUpdate = false
        
        pcall(function()
            local cooldown = (shouldSkip(currentBlock)) and 0.3 or Time.Value
            bedwars.BlockBreakController.blockBreaker:setCooldown(cooldown)
        end)
    end
    
    FastBreak = vape.Categories.Blatant:CreateModule({
        Name = 'FastBreak',
        Function = function(callback)
            if callback then
                oldHitBlock = bedwars.BlockBreaker.hitBlock

				local fastBreakHook = function(self, maid, raycastparams, ...)
					local block = nil
					pcall(function()
						local blockInfo = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
						if blockInfo and blockInfo.target and blockInfo.target.blockInstance then
							block = blockInfo.target.blockInstance
						end
					end)
					
					local currentSlot = store.inventory and store.inventory.hotbarSlot
					local slotChanged = currentSlot ~= lastHotbarSlot
					if slotChanged then
						lastHotbarSlot = currentSlot
					end

					if block ~= currentBlock or slotChanged then
						currentBlock = block
						updateBreakSpeed()
					end
					return oldHitBlock and oldHitBlock(self, maid, raycastparams, ...)
				end
				bedwars.BlockBreaker.hitBlock = fastBreakHook
				bedwars.BlockBreaker.hitBlock = fastBreakHook
                
                updateBlacklistCache()
                
                task.spawn(function()
                    while FastBreak.Enabled do
                        if tick() - lastCacheClean > cacheCleanInterval then
                            lastCacheClean = tick()
                            bedCache = {}
                            blacklistCache = {}
                        end
                        if pendingUpdate then updateBreakSpeed() end
                        task_wait(0.5) 
                    end
                end)
			else
				pcall(function()
					local bb = bedwars.BlockBreakController:getBlockBreaker()
					if bb then bb:setCooldown(0.3) end
				end)
				if oldHitBlock then
					if bedwars.BlockBreaker.hitBlock == fastBreakHook then
						bedwars.BlockBreaker.hitBlock = oldHitBlock
					end
					oldHitBlock = nil
				end
				fastBreakHook = nil
				currentBlock = nil
				lastHotbarSlot = nil
				bedCache, blacklistCache, cachedBlacklistLower = {}, {}, {}
			end
        end,
        Tooltip = 'Decreases block hit cooldown'
    })
    
    Time = FastBreak:CreateSlider({
        Name = 'Break speed',
        Min = 0, Max = 0.3, Default = 0.25, Decimal = 100, Suffix = 'seconds',
        Function = function() updateBreakSpeed() end
    })
    
    BedCheck = FastBreak:CreateToggle({
        Name = 'Bed Check',
        Default = false,
        Tooltip = 'Use normal break speed when breaking beds',
        Function = function() bedCache = {}; updateBreakSpeed() end
    })
    
    Blacklist = FastBreak:CreateToggle({
        Name = 'Blacklist Blocks',
        Default = false,
        Tooltip = 'Use normal break speed on blacklisted blocks',
        Function = function(v)
            if blocks then blocks.Object.Visible = v end
            blacklistCache = {}
            if v then updateBlacklistCache() end
            updateBreakSpeed()
        end
    })
    
    blocks = FastBreak:CreateTextList({
        Name = 'Blacklisted Blocks',
        Placeholder = 'bed',
        Visible = false,
        Function = function()
            updateBlacklistCache()
            blacklistCache = {}
            updateBreakSpeed()
        end
    })

    task.defer(function()
        if blocks and blocks.Object then
            blocks.Object.Visible = false  
        end
    end)
end)
	
local Fly
local LongJump
run(function()
    local Value
    local VerticalValue
    local WallCheck
    local PopBalloons
    local TP
    local lastonground = false
    local MobileButtons
    local FlyAnywayProgressBar = {Enabled = false}
    local FlyAnywayProgressBarFrame
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local up, down, old = 0, 0
    local mobileControls = {}
    local groundtime = nil
    local onground = false
    local flyCooldownActive = false
    local lastGroundTouchTime = 0
    local MAX_FLY_TIME = 2.5
    local tick = tick
    local task_wait = task.wait
    local math_max = math.max
    local math_floor = math.floor
    local string_format = string.format
    local vector3new = Vector3.new
    local vector3zero = Vector3.zero
    local udim2new = UDim2.new
    local cframeLookAlong = CFrame.lookAlong
    local cachedBalloonCount = 0
    local lastBalloonCheck = 0
    local balloonCheckInterval = 0.2 
    local cachedMatchState = 0
    local lastMatchStateCheck = 0
    local lastGroundTime = tick()
    local airTime = 0
    
    local function createMobileButton(name, position, icon)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = udim2new(0, 60, 0, 60)
        button.Position = position
        button.BackgroundTransparency = 0.2
        button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        button.BorderSizePixel = 0
        button.Text = icon
        button.TextScaled = true
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Font = Enum.Font.SourceSansBold
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = button
        return button
    end

    local function cleanupMobileControls()
        for _, control in pairs(mobileControls) do
            if control then
                control:Destroy()
            end
        end
        mobileControls = {}
    end

    local progressBarFrameCounter = 0
    local function updateProgressBar()
        if not FlyAnywayProgressBarFrame then return end
        
        if not entitylib.isAlive then
            FlyAnywayProgressBarFrame.Visible = false
            return
        end
        
        local now = tick()
        if now - lastBalloonCheck > balloonCheckInterval then
            lastBalloonCheck = now
            cachedBalloonCount = lplr.Character:GetAttribute('InflatedBalloons') or 0
            cachedMatchState = store.matchState
        end
        
        local flyAllowed = cachedBalloonCount > 0 or cachedMatchState == 2
        
        if flyAllowed then
            FlyAnywayProgressBarFrame.Frame.Size = udim2new(1, 0, 0, 20)
            FlyAnywayProgressBarFrame.TextLabel.Text = "∞"
            FlyAnywayProgressBarFrame.Visible = FlyAnywayProgressBar.Enabled
            return
        end
        
        progressBarFrameCounter = progressBarFrameCounter + 1
        if progressBarFrameCounter % 3 == 0 then
            local hipHeight = entitylib.character.Humanoid.HipHeight
            local checkPos = entitylib.character.HumanoidRootPart.Position + vector3new(0, (hipHeight * -2) - 1, 0)
            local newray = getPlacedBlock(checkPos)
            onground = newray ~= nil
        end
        
        if onground then
            groundtime = nil
            flyCooldownActive = false
            lastGroundTouchTime = now
            
            FlyAnywayProgressBarFrame.Frame.Size = udim2new(1, 0, 0, 20)
            FlyAnywayProgressBarFrame.TextLabel.Text = string_format("%.1fs", MAX_FLY_TIME)
            FlyAnywayProgressBarFrame.Visible = FlyAnywayProgressBar.Enabled and Fly.Enabled
            
            local tween = FlyAnywayProgressBarFrame.Frame:FindFirstChild("Tween")
            if tween then
                tween:Destroy()
            end
        else
            if not groundtime then
                groundtime = now + MAX_FLY_TIME
                flyCooldownActive = false
            end
            
            local timeLeft = math_max(0, groundtime - now)
            local progress = timeLeft / MAX_FLY_TIME
            
            FlyAnywayProgressBarFrame.Frame.Size = udim2new(progress, 0, 0, 20)
            FlyAnywayProgressBarFrame.TextLabel.Text = string_format("%.1fs", timeLeft)
            FlyAnywayProgressBarFrame.Visible = FlyAnywayProgressBar.Enabled and Fly.Enabled
            
            if timeLeft <= 0 and not flyCooldownActive then
                flyCooldownActive = true
            end
        end
        
        lastonground = onground
    end

    Fly = vape.Categories.Blatant:CreateModule({
        Name = 'Fly',
        Function = function(callback)
            frictionTable.Fly = callback or nil
            updateVelocity()
            if callback then
                up, down, old = 0, 0, bedwars.BalloonController.deflateBalloon
                bedwars.BalloonController.deflateBalloon = function() end
                local tpTick, tpToggle, oldy = tick(), true

                if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
                    bedwars.BalloonController:inflateBalloon()
                end

                Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
                    if changed == 'InflatedBalloons' then
                        cachedBalloonCount = lplr.Character:GetAttribute('InflatedBalloons') or 0
                        if cachedBalloonCount == 0 and getItem('balloon') then
                            bedwars.BalloonController:inflateBalloon()
                        end
                    end
                end))

                local renderFrameCounter = 0
                Fly:Clean(runService.RenderStepped:Connect(function(delta)
                    if FlyAnywayProgressBar.Enabled and Fly.Enabled then
                        renderFrameCounter = renderFrameCounter + 1
                        if renderFrameCounter % 2 == 0 then
                            updateProgressBar()
                        end
                    end
                end))

                local preSimFrameCounter = 0
                local lastWallRaycast = 0
                local wallRaycastInterval = 0.05
                
                Fly:Clean(runService.PreSimulation:Connect(function(dt)
                    if entitylib.isAlive and isnetworkowner(entitylib.character.RootPart) then
                        preSimFrameCounter = preSimFrameCounter + 1
                        local now = tick()
                        
                        if preSimFrameCounter % 12 == 0 then
                            cachedBalloonCount = lplr.Character:GetAttribute('InflatedBalloons') or 0
                            cachedMatchState = store.matchState
                        end

                        local humanoid = entitylib.character.Humanoid
                        if humanoid.FloorMaterial ~= Enum.Material.Air then
                            lastGroundTime = now
                        end
                        airTime = now - lastGroundTime
                        
                        local flyAllowed = cachedBalloonCount > 0 or cachedMatchState == 2
                        
                        local oscillation = (now % 0.4 < 0.2) and -1 or 1
                        local mass = (1.95 + (flyAllowed and 6 or 0) * oscillation) + ((up + down) * VerticalValue.Value)
                        
                        local root = entitylib.character.RootPart
                        local moveDirection = entitylib.character.Humanoid.MoveDirection
                        local velo = getSpeed()
                        local destination = (moveDirection * math_max(Value.Value - velo, 0) * dt)
                        
                        if WallCheck.Enabled and (now - lastWallRaycast) > wallRaycastInterval then
                            lastWallRaycast = now
                            rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiVoidPart}
                            rayCheck.CollisionGroup = root.CollisionGroup
                            
                            local ray = workspace:Raycast(root.Position, destination, rayCheck)
                            if ray then
                                destination = ((ray.Position + ray.Normal) - root.Position)
                            end
                        end

                        if not flyAllowed then
                            if tpToggle then
                                if airTime > 2 then  
                                    if not oldy then
                                        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiVoidPart}
                                        rayCheck.CollisionGroup = root.CollisionGroup
                                        local ray = workspace:Raycast(root.Position, vector3new(0, -1000, 0), rayCheck)
                                        if ray and TP.Enabled then
                                            tpToggle = false
                                            oldy = root.Position.Y
                                            tpTick = now + 0.11
                                            root.CFrame = cframeLookAlong(vector3new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
                                        end
                                    end
                                end
                            else
                                if oldy then
                                    if tpTick < now then
                                        local newpos = vector3new(root.Position.X, oldy, root.Position.Z)
                                        root.CFrame = cframeLookAlong(newpos, root.CFrame.LookVector)
                                        tpToggle = true
                                        oldy = nil
                                    else
                                        mass = 0
                                    end
                                end
                            end
                        end

                        root.CFrame += destination
                        root.AssemblyLinearVelocity = (moveDirection * velo) + vector3new(0, mass, 0)
                    end
                end))

                local isMobile = inputService.TouchEnabled and not inputService.KeyboardEnabled and not inputService.MouseEnabled
                local MobileEnabled = MobileButtons.Enabled or isMobile
                if MobileEnabled then
                    local gui = Instance.new("ScreenGui")
                    gui.Name = "FlyControls"
                    gui.ResetOnSpawn = false
                    gui.Parent = lplr.PlayerGui

                    local upButton = createMobileButton("UpButton", udim2new(0.9, -70, 0.7, -140), "↑")
                    local downButton = createMobileButton("DownButton", udim2new(0.9, -70, 0.7, -70), "↓")

                    mobileControls.UpButton = upButton
                    mobileControls.DownButton = downButton
                    mobileControls.ScreenGui = gui

                    upButton.Parent = gui
                    downButton.Parent = gui

                    Fly:Clean(upButton.MouseButton1Down:Connect(function()
                        up = 1
                    end))
                    Fly:Clean(upButton.MouseButton1Up:Connect(function()
                        up = 0
                    end))
                    Fly:Clean(downButton.MouseButton1Down:Connect(function()
                        down = -1
                    end))
                    Fly:Clean(downButton.MouseButton1Up:Connect(function()
                        down = 0
                    end))
                end

                Fly:Clean(inputService.InputBegan:Connect(function(input)
                    if not inputService:GetFocusedTextBox() then
                        if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
                            up = 1
                        elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
                            down = -1
                        end
                    end
                end))
                Fly:Clean(inputService.InputEnded:Connect(function(input)
                    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
                        up = 0
                    elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
                        down = 0
                    end
                end))
                if inputService.TouchEnabled then
                    pcall(function()
                        local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
                        Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
                            if not mobileControls.UpButton then
                                up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
                            end
                        end))
                    end)
                end
            else
                if FlyAnywayProgressBarFrame then
                    FlyAnywayProgressBarFrame.Visible = false
                end
                lastonground = nil
                groundtime = nil
                flyCooldownActive = false
                bedwars.BalloonController.deflateBalloon = old
                if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
                    for _ = 1, 3 do
                        bedwars.BalloonController:deflateBalloon()
                    end
                end
                cleanupMobileControls()
                cachedBalloonCount = 0
                lastBalloonCheck = 0
                cachedMatchState = 0
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end,
        Tooltip = 'Makes you go zoom.'
    })
    Value = Fly:CreateSlider({
        Name = 'Speed',
        Min = 1,
        Max = 23,
        Default = 23,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    VerticalValue = Fly:CreateSlider({
        Name = 'Vertical Speed',
        Min = 1,
        Max = 150,
        Default = 50,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    WallCheck = Fly:CreateToggle({
        Name = 'Wall Check',
        Default = true
    })
    PopBalloons = Fly:CreateToggle({
        Name = 'Pop Balloons',
        Default = true
    })
	FlyAnywayProgressBar = Fly:CreateToggle({
		Name = "Progress Bar",
		Function = function(callback)
			if callback then
				FlyAnywayProgressBarFrame = Instance.new("Frame")
				FlyAnywayProgressBarFrame.AnchorPoint = Vector2.new(0.5, 0)
				FlyAnywayProgressBarFrame.Position = udim2new(0.5, 0, 1, -200)
				FlyAnywayProgressBarFrame.Size = udim2new(0.2, 0, 0, 20)
				FlyAnywayProgressBarFrame.BackgroundTransparency = 0.5
				FlyAnywayProgressBarFrame.BorderSizePixel = 0
				FlyAnywayProgressBarFrame.BackgroundColor3 = Color3.new(0, 0, 0)
				FlyAnywayProgressBarFrame.Visible = false
				FlyAnywayProgressBarFrame.Parent = vape.gui
				
				local FlyAnywayProgressBarFrame2 = Instance.new("Frame")
				FlyAnywayProgressBarFrame2.Name = "Frame"
				FlyAnywayProgressBarFrame2.AnchorPoint = Vector2.new(0, 0)
				FlyAnywayProgressBarFrame2.Position = udim2new(0, 0, 0, 0)
				FlyAnywayProgressBarFrame2.Size = udim2new(1, 0, 0, 20)
				FlyAnywayProgressBarFrame2.BackgroundTransparency = 0
				FlyAnywayProgressBarFrame2.BorderSizePixel = 0
				FlyAnywayProgressBarFrame2.BackgroundColor3 = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
				FlyAnywayProgressBarFrame2.Visible = false
				FlyAnywayProgressBarFrame2.Parent = FlyAnywayProgressBarFrame
                
                local FlyAnywayProgressBartext = Instance.new("TextLabel")
                FlyAnywayProgressBartext.Name = "TextLabel"
                FlyAnywayProgressBartext.Text = "2.5s"
                FlyAnywayProgressBartext.Font = Enum.Font.Gotham
                FlyAnywayProgressBartext.TextStrokeTransparency = 0
                FlyAnywayProgressBartext.TextColor3 = Color3.new(0.9, 0.9, 0.9)
                FlyAnywayProgressBartext.TextSize = 20
                FlyAnywayProgressBartext.Size = udim2new(1, 0, 1, 0)
                FlyAnywayProgressBartext.BackgroundTransparency = 1
                FlyAnywayProgressBartext.Position = udim2new(0, 0, 0, 0)
                FlyAnywayProgressBartext.Parent = FlyAnywayProgressBarFrame
            else
                if FlyAnywayProgressBarFrame then 
                    FlyAnywayProgressBarFrame:Destroy() 
                    FlyAnywayProgressBarFrame = nil 
                end
            end
        end,
        Tooltip = "show amount of Fly time",
        Default = true
    })
    TP = Fly:CreateToggle({
        Name = 'TP Down',
        Default = true
    })
    MobileButtons = Fly:CreateToggle({
        Name = "Mobile Buttons",
        Function = function() 
            if Fly.Enabled then
                Fly:Toggle()
                Fly:Toggle()
            end
        end
    })
end)

run(function()
    local InfiniteJump
    local inputConnections = {}
    local mobileJumpButtonConnection
    local mobileJumpButton
    local mobileJumpHeld = false
    local mobileJumpThread

    local function cleanupInfiniteJump()
        for _, conn in pairs(inputConnections) do
            if conn and typeof(conn) == 'RBXScriptConnection' then
                pcall(conn.Disconnect, conn)
            end
        end
        inputConnections = {}

        if mobileJumpButtonConnection then
            pcall(mobileJumpButtonConnection.Disconnect, mobileJumpButtonConnection)
            mobileJumpButtonConnection = nil
        end

        mobileJumpButton = nil
        mobileJumpHeld = false
        mobileJumpThread = nil
    end

    local function performJump()
        if entitylib.isAlive and entitylib.character and entitylib.character.Humanoid then
            entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end

    local function mobileJumpLoop()
        if mobileJumpThread then
            return
        end

        mobileJumpThread = task.spawn(function()
            while mobileJumpHeld do
                performJump()
                task.wait(0.05)
            end
            mobileJumpThread = nil
        end)
    end

    local function onMobileJumpButtonChanged()
        if not mobileJumpButton then
            return
        end

        local pressed = mobileJumpButton.ImageRectOffset.X == 146
        if pressed then
            mobileJumpHeld = true
            mobileJumpLoop()
        else
            mobileJumpHeld = false
        end
    end

    InfiniteJump = vape.Categories.Blatant:CreateModule({
        Name = 'Inf Jump',
        Function = function(callback)
            if callback then
                table.insert(inputConnections, inputService.InputBegan:Connect(function(input, gameProcessed)
                    if gameProcessed or inputService:GetFocusedTextBox() then
                        return
                    end
                    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
                        performJump()
                    elseif input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonA then
                        performJump()
                    end
                end))

                if inputService.TouchEnabled then
                    pcall(function()
                        mobileJumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
                        if mobileJumpButton then
                            mobileJumpButtonConnection = mobileJumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(onMobileJumpButtonChanged)
                            onMobileJumpButtonChanged()
                        end
                    end)
                end
            else
                cleanupInfiniteJump()
            end
        end,
        Tooltip = 'Allows infinite jumping on PC and mobile'
    })

    local Mode
    local Expand
    local AutoToggle
    local Visible
    local VisibleColor
    local Targets
    local objects, set = {}, {}
    local lastHoldingSword = false
    local autoToggleConnection = nil
    local manuallyDisabled = false

    local tick = tick
    local task_wait = task.wait
    local vector3new = Vector3.new
    local vector3one = Vector3.one

    local colorList = {
        Red = Color3.fromRGB(255, 0, 0),
        Blue = Color3.fromRGB(0, 100, 255),
        Green = Color3.fromRGB(0, 255, 0),
        Yellow = Color3.fromRGB(255, 255, 0),
        Orange = Color3.fromRGB(255, 140, 0),
        Purple = Color3.fromRGB(180, 0, 255),
        White = Color3.fromRGB(255, 255, 255),
        Cyan = Color3.fromRGB(0, 255, 255),
        Pink = Color3.fromRGB(255, 50, 150),
        Black = Color3.fromRGB(0, 0, 0)
    }

    local function shouldCreateHitbox(ent)
        if not ent.Targetable then return false end
        if ent.Player and Targets and Targets.Players and Targets.Players.Enabled then return true end
        if not ent.Player and Targets and Targets.NPCs and Targets.NPCs.Enabled then return true end
        return false
    end

    local _wallRayParams = RaycastParams.new()
    _wallRayParams.FilterType = Enum.RaycastFilterType.Exclude
    local function isTargetBehindWall(ent)
        if not Targets or not Targets.Walls or not Targets.Walls.Enabled then return false end
        if not ent.RootPart then return false end
        local origin = entitylib.character.RootPart.Position
        local target = ent.RootPart.Position
        local direction = target - origin
        _wallRayParams.FilterDescendantsInstances = {entitylib.character, ent.Character}
        local result = workspace:Raycast(origin, direction, _wallRayParams)
        if result then
            local hitDist = (result.Position - origin).Magnitude
            local targetDist = direction.Magnitude
            if hitDist < targetDist - 0.5 then
                return true
            end
        end
        return false
    end

    local cachedExpandSize = vector3new(3, 6, 3)
    local lastExpandValue = 0
    local function updateExpandSize(val)
        if val ~= lastExpandValue then
            lastExpandValue = val
            cachedExpandSize = vector3new(3, 6, 3) + vector3one * (val / 5)
        end
    end

    local function createHitbox(ent)
        if not shouldCreateHitbox(ent) then return end
        if isTargetBehindWall(ent) then return end
        if objects[ent] then return end
        local hitbox = Instance.new('Part')
        hitbox.Size = cachedExpandSize
        hitbox.Position = ent.RootPart.Position
        hitbox.CanCollide = false
        hitbox.Massless = true
        hitbox.Transparency = Visible and Visible.Enabled and 0.5 or 1
        if Visible and Visible.Enabled and VisibleColor then
            hitbox.Color = colorList[VisibleColor.Value] or colorList.Red
        end
        hitbox.Parent = ent.Character
        local weld = Instance.new('Motor6D')
        weld.Part0 = hitbox
        weld.Part1 = ent.RootPart
        weld.Parent = hitbox
        objects[ent] = hitbox
    end

    local lastAutoToggleTime = 0
    local autoToggleCooldown = 0.1
    local function handleAutoToggle()
        if not AutoToggle.Enabled or Mode.Value ~= 'Player' then return end
        local now = tick()
        if now - lastAutoToggleTime < autoToggleCooldown then return end
        local holdingSword = isSword()
        if holdingSword ~= lastHoldingSword then
            lastHoldingSword = holdingSword
            lastAutoToggleTime = now
            if holdingSword then
                if not HitBoxes.Enabled and not manuallyDisabled then
                    HitBoxes:Toggle()
                end
            else
                if HitBoxes.Enabled then
                    manuallyDisabled = false
                    HitBoxes:Toggle()
                end
            end
        end
    end

    local function refreshAllHitboxes()
        for ent, part in pairs(objects) do
            part:Destroy()
        end
        table.clear(objects)
        local entityList = entitylib.List
        for i = 1, #entityList do
            createHitbox(entityList[i])
        end
    end

    HitBoxes = vape.Categories.Blatant:CreateModule({
        Name = 'HitBoxes',
        Function = function(callback)
            if callback then
                manuallyDisabled = false
                updateExpandSize(Expand.Value)
                if Mode.Value == 'Sword' then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
                    set = true
                else
                    HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
                        createHitbox(ent)
                    end))
                    HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
                        local obj = objects[ent]
                        if obj then
                            obj:Destroy()
                            objects[ent] = nil
                        end
                    end))
                    refreshAllHitboxes()
					local hitboxThrottleCounter = 0
					HitBoxes:Clean(runService.Heartbeat:Connect(function()
						if not Targets or not Targets.Walls or not Targets.Walls.Enabled then return end
						hitboxThrottleCounter = hitboxThrottleCounter + 1
						if hitboxThrottleCounter % 20 ~= 0 then return end
						for ent, part in pairs(objects) do
							if isTargetBehindWall(ent) then
								part:Destroy()
								objects[ent] = nil
							end
						end
						local entityList = entitylib.List
						for i = 1, #entityList do
							local ent = entityList[i]
							if not objects[ent] then
								createHitbox(ent)
							end
						end
					end))
                end
            else
                if AutoToggle.Enabled and isSword() then
                    manuallyDisabled = true
                end
                if set then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
                    set = nil
                end
                for _, part in pairs(objects) do
                    part:Destroy()
                end
                table.clear(objects)
                if not AutoToggle.Enabled then
                    lastHoldingSword = false
                end
            end
        end,
        Tooltip = 'Expands attack hitbox'
    })

	Targets = HitBoxes:CreateTargets({
		Players = true,
		Walls = false,
		NPCs = false,
		Function = function()
			if HitBoxes.Enabled and Mode.Value == 'Player' then
				refreshAllHitboxes()
			end
		end
	})

    Mode = HitBoxes:CreateDropdown({
        Name = 'Mode',
        List = {'Sword', 'Player'},
        Function = function(val)
            local isPlayer = val == 'Player'
            if AutoToggle then AutoToggle.Object.Visible = isPlayer end
            if Visible then Visible.Object.Visible = isPlayer end
            if VisibleColor then VisibleColor.Object.Visible = isPlayer and Visible.Enabled end
            if HitBoxes.Enabled then
                HitBoxes:Toggle()
                HitBoxes:Toggle()
            end
        end,
        Tooltip = 'Sword - Increases the range around you to hit entities\nPlayer - Increases the players hitbox'
    })

    Expand = HitBoxes:CreateSlider({
        Name = 'Expand amount',
        Min = 0,
        Max = 50,
        Default = 14.4,
        Decimal = 10,
        Function = function(val)
            updateExpandSize(val)
            if HitBoxes.Enabled then
                if Mode.Value == 'Sword' then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3))
                else
                    for _, part in pairs(objects) do
                        part.Size = cachedExpandSize
                    end
                end
            end
        end,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })

    local autoToggleFrameCounter = 0
    AutoToggle = HitBoxes:CreateToggle({
        Name = 'Auto Toggle',
        Default = false,
        Tooltip = 'Automatically enables hitbox when holding a sword',
        Function = function(callback)
            if callback then
                if autoToggleConnection then autoToggleConnection:Disconnect() end
                lastHoldingSword = false
                autoToggleFrameCounter = 0
			autoToggleConnection = runService.Heartbeat:Connect(function()
				autoToggleFrameCounter = autoToggleFrameCounter + 1
				if autoToggleFrameCounter % 5 == 0 then
					handleAutoToggle()
				end
			end)
			HitBoxes:Clean(autoToggleConnection)
                handleAutoToggle()
            else
                if autoToggleConnection then
                    autoToggleConnection:Disconnect()
                    autoToggleConnection = nil
                end
                lastHoldingSword = false
            end
        end
    })

    Visible = HitBoxes:CreateToggle({
        Name = 'Visible',
        Default = false,
        Tooltip = 'Makes the hitbox visible on screen',
        Function = function(callback)
            if VisibleColor then VisibleColor.Object.Visible = callback end
            if HitBoxes.Enabled and Mode.Value == 'Player' then
                local transparency = callback and 0.5 or 1
                local col = callback and VisibleColor and (colorList[VisibleColor.Value] or colorList.Red) or nil
                for _, part in pairs(objects) do
                    part.Transparency = transparency
                    if col then part.Color = col end
                end
            end
        end
    })

    VisibleColor = HitBoxes:CreateDropdown({
        Name = 'Hitbox Color',
        List = {'Red', 'Blue', 'Green', 'Yellow', 'Orange', 'Purple', 'White', 'Cyan', 'Pink', 'Black'},
        Default = 'Red',
        Visible = false,
        Tooltip = 'Color of the visible hitbox',
        Function = function(val)
            if HitBoxes.Enabled and Mode.Value == 'Player' and Visible.Enabled then
                local col = colorList[val] or colorList.Red
                for _, part in pairs(objects) do
                    part.Color = col
                end
            end
        end
    })

    task.spawn(function()
        repeat task_wait() until Mode and Mode.Value
        local isPlayer = Mode.Value == 'Player'
        AutoToggle.Object.Visible = isPlayer
        Visible.Object.Visible = isPlayer
    end)

    task.defer(function()
        if VisibleColor and VisibleColor.Object then
            VisibleColor.Object.Visible = false
        end
    end)
end)
	
run(function()
	vape.Categories.Blatant:CreateModule({
		Name = 'KeepSprint',
		Function = function(callback)
			debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
			bedwars.SprintController:stopSprinting()
		end,
		Tooltip = 'Lets you sprint with a speed potion.'
	})
end)

-- aero killaura
local Attacking
run(function()
    local Killaura
    local Targets
    local Sort
    local SwingRange
    local AttackRange
    local RangeCircle
    local RangeCirclePart
    local UpdateRate
    local AngleSlider
    local MaxTargets
    local Mouse
    local Swing
    local GUI
    local BoxSwingColor
    local BoxAttackColor
    local ParticleTexture
    local ParticleColor1
    local ParticleColor2
    local ParticleSize
    local Face
    local FaceSpeed
    local Animation
    local AnimationMode
    local AnimationSpeed
    local AnimationTween
    local Limit
    local LegitAura
    local SyncHits
    local lastAttackTime = 0
    local lastManualSwing = 0
    local lastSwingServerTime = 0
    local lastSwingServerTimeDelta = 0
    local KitCheck
    local SwingTime
    local SwingTimeSlider
    local swingCooldown = 0
    local ContinueSwinging
    local ContinueSwingTime
    local lastTargetTime = 0
    local continueSwingCount = 0
    local Particles, Boxes = {}, {}
    local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
    local AttackRemote
    local TargetPriority
    local CustomHitReg
    local CustomHitRegSlider
    local lastCustomHitTime = 0
    local AirHit
    local AirHitsChance
    local FROZEN_THRESHOLD = 10
    local FastHits
    local FastHitsMode
    local LegitSwitch
    local OldShootInterval
    local OldSwitchDelay
    local OldWaitDelay
    local OldFirstPersonCheck
    local lastOldShootTime = 0
    local FireRate
    local AutoFireball
    local autoFireballLoop = nil
    local projectileRemote = {InvokeServer = function() end}
    local ProjectileDelay = {}
    local lastShot = tick()
    local Usage = 1
    local _losRayParams = RaycastParams.new()
    _losRayParams.FilterType = Enum.RaycastFilterType.Exclude
    local _losFilterTable = {nil, nil}
    local FreeHitRegToggle
    local FreeHitRegSlider
    local lastFreeHitTime = 0
    local AutoFireballFireRate
    local AutoFireballLegitSwitch
	local AutoFireballShootDelay
    local lastAutoFireballTime = 0
    local autoFireballLoop = nil

    local function hasLineOfSightKA(from, to, targetCharacter)
        _losFilterTable[1] = entitylib.character and entitylib.character.Character or workspace
        _losFilterTable[2] = targetCharacter
        _losRayParams.FilterDescendantsInstances = _losFilterTable
        local direction = to - from
        local result = workspace:Raycast(from, direction, _losRayParams)
        return result == nil
    end

    task.spawn(function()
        AttackRemote = bedwars.Client:Get(remotes.AttackEntity)
        projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)

    local function canHitWithCustomReg(isTier4Target)
        if isTier4Target and FreeHitRegToggle and FreeHitRegToggle.Enabled then
            local currentTime = tick()
            local delayBetweenHits = 10 / FreeHitRegSlider.Value
            if currentTime - lastFreeHitTime >= delayBetweenHits then
                lastFreeHitTime = currentTime
                return true
            end
            return false
        end

        if not CustomHitReg or not CustomHitReg.Enabled then return true end
        local currentTime = tick()
        local delayBetweenHits = 10 / CustomHitRegSlider.Value
        if currentTime - lastCustomHitTime >= delayBetweenHits then
            lastCustomHitTime = currentTime
            return true
        end
        return false
    end

    local _t4HitCount = {}
    local _t4HitTick = {}

    local function FireAttackRemote(attackTable, ...)
        if not AttackRemote then return end

        local _atkPlr = playersService:GetPlayerFromCharacter(attackTable.entityInstance)
        local isTier4Target = false

        if _atkPlr then
            local targetTier = getAccountTier(_atkPlr)
            if targetTier >= 99 then return end
            if targetTier >= 4 and getAccountTier(lplr) == 0 then
                isTier4Target = true
                local uid = _atkPlr.UserId
                local now = tick()
                if not _t4HitTick[uid] or now - _t4HitTick[uid] >= 10 then
                    _t4HitTick[uid] = now
                    _t4HitCount[uid] = 0
                end
                _t4HitCount[uid] = (_t4HitCount[uid] or 0) + 1
                if _t4HitCount[uid] > 32 then return end
            end
        end

        if not canHitWithCustomReg(isTier4Target) then return end

        local selfpos = attackTable.validate.selfPosition.value
        local targetpos = attackTable.validate.targetPosition.value
        local actualDistance = (selfpos - targetpos).Magnitude

        store.attackReach = (actualDistance * 100) // 1 / 100
        store.attackReachUpdate = tick() + 1

        if actualDistance > 14.4 and actualDistance <= 30 then
            local direction = (targetpos - selfpos).Unit
            local moveDistance = math.min(actualDistance - 14.4, 8)
            attackTable.validate.selfPosition.value = selfpos + (direction * moveDistance)
            local pullDistance = math.min(actualDistance - 12.8, 4)
            attackTable.validate.targetPosition.value = targetpos - (direction * pullDistance)

            attackTable.validate.raycast = attackTable.validate.raycast or {}
            attackTable.validate.raycast.cameraPosition = attackTable.validate.raycast.cameraPosition or {}
            attackTable.validate.raycast.cursorDirection = attackTable.validate.raycast.cursorDirection or {}

            local extendedOrigin = selfpos + (direction * math.min(actualDistance - 12, 15))
            attackTable.validate.raycast.cameraPosition.value = extendedOrigin
            attackTable.validate.raycast.cursorDirection.value = direction
        end

        local suc = _atkPlr ~= nil
        local plr = _atkPlr
        if suc and plr then
            if not select(2, whitelist:get(plr)) then return end
        end

        return AttackRemote:SendToServer(attackTable, ...)
    end

    local function createRangeCircle()
        local suc, err = pcall(function()
            if (not shared.CheatEngineMode) then
                if RangeCirclePart then RangeCirclePart:Destroy() end
                RangeCirclePart = Instance.new("MeshPart")
                RangeCirclePart.MeshId = "rbxassetid://3726303797"
                if shared.RiseMode and GuiLibrary.GUICoreColor and GuiLibrary.GUICoreColorChanged then
                    RangeCirclePart.Color = GuiLibrary.GUICoreColor
                    GuiLibrary.GUICoreColorChanged.Event:Connect(function()
                        RangeCirclePart.Color = GuiLibrary.GUICoreColor
                    end)
                else
                    RangeCirclePart.Color = Color3.fromHSV(BoxSwingColor["Hue"], BoxSwingColor["Sat"], BoxSwingColor.Value)
                end
                RangeCirclePart.CanCollide = false
                RangeCirclePart.Anchored = true
                RangeCirclePart.Material = Enum.Material.Neon
                RangeCirclePart.Size = Vector3.new(SwingRange.Value * 0.7, 0.01, SwingRange.Value * 0.7)
                if Killaura.Enabled then
                    RangeCirclePart.Parent = gameCamera
                end
                RangeCirclePart:SetAttribute("gamecore_GameQueryIgnore", true)
            end
        end)
        if (not suc) then
            pcall(function()
                if RangeCirclePart then
                    RangeCirclePart:Destroy()
                    RangeCirclePart = nil
                end
                notif("Killaura - Range Visualiser Circle", "There was an error creating the circle. Disabling...", 2)
            end)
        end
    end

    local function getAttackData()
        if Mouse.Enabled then
            local recentSwing = LegitAura.Enabled and (tick() - bedwars.SwordController.lastSwing) <= 0.2
            if not recentSwing then
                local mousePressed = inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                if not mousePressed then 
                    return false 
                end
            end
        end

        if GUI.Enabled then
            if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
        end

        local sword = Limit.Enabled and store.hand or store.tools.sword
        if not sword or not sword.tool then return false end

        local meta = bedwars.ItemMeta[sword.tool.Name]
        if Limit.Enabled then
            if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
        end

        if KitCheck.Enabled then
            if bedwars.SwordController.disableSwingState then return false end
        end

        if LegitAura.Enabled then
            if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
        end

        if SwingTime.Enabled then
            local swingSpeed = SwingTimeSlider.Value
            return sword, meta, (tick() - lastAttackTime) >= swingSpeed
        else
            return sword, meta, true
        end
    end
    
    local function resetSwordCooldown()
        if bedwars.SwordController then
            bedwars.SwordController.lastAttack = 0
            bedwars.SwordController.lastSwing = 0

            if bedwars.SwordController.lastChargedAttackTimeMap then
                for weaponName, _ in pairs(bedwars.SwordController.lastChargedAttackTimeMap) do
                    bedwars.SwordController.lastChargedAttackTimeMap[weaponName] = 0
                end
            end
        end
    end

    local function shouldContinueSwinging()
        if not ContinueSwinging.Enabled then return false end
        if lastTargetTime == 0 then return false end
        local timeSinceLastTarget = tick() - lastTargetTime
        local swingDuration = ContinueSwingTime.Value
        if timeSinceLastTarget <= swingDuration then
            return true
        end
        return false
    end

    local function getAmmo(check)
        for _, item in store.inventory.inventory.items do
            if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
                return item.itemType
            end
        end
        return
    end

	local _projectilesCache = {}

	local function getProjectiles()
		table.clear(_projectilesCache)
		for _, item in store.inventory.inventory.items do
			local proj = bedwars.ItemMeta[item.itemType].projectileSource
			local ammo = proj and getAmmo(proj)
			if ammo and table.find({'arrow'}, ammo) then
				table.insert(_projectilesCache, {
					item,
					ammo,
					proj.projectileType(ammo),
					proj
				})
			end
		end
		return _projectilesCache
	end

    local function canShoot(proj)
        return tick() > (ProjectileDelay[proj[1].itemType] or 0)
    end

	local function shootFunc(item, ammo, projectile, itemMeta, pos, ent, ign)
		local meta = bedwars.ProjectileMeta[projectile]
		local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
		local switched
		switched = switchItem(item.tool, 0.05)
		local targetBodyPart = ent.RootPart
		local selfVelocity = entitylib.character.RootPart and entitylib.character.RootPart.Velocity or Vector3.zero
		local targetVelocity = targetBodyPart.Velocity
		local playerGravity = workspace.Gravity
		local balloons = ent.Character and ent.Character:GetAttribute('InflatedBalloons')
		if balloons and balloons > 0 then
			playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end
		if ent.Character and ent.Character.PrimaryPart and ent.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
			playerGravity = 6
		end
		if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
			for _, owl in ipairs(collectionService:GetTagged('Owl')) do
				if owl:GetAttribute('Target') == ent.Player.UserId and owl:GetAttribute('Status') == 2 then
					playerGravity = 0
					break
				end
			end
		end
		local bowRelX = bedwars.BowConstantsTable.RelX or 0
		local bowRelY = bedwars.BowConstantsTable.RelY or 0
		local bowRelZ = bedwars.BowConstantsTable.RelZ or 0
		local newlook = CFrame.new(pos, targetBodyPart.Position) * CFrame.new(Vector3.new(bowRelX, bowRelY, bowRelZ))
		local calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, targetBodyPart.Position, targetVelocity, playerGravity, ent.HipHeight, nil, sharedFastHitsRayParams)
		if calc then
			targetinfo.Targets[ent] = tick() + 1
			task.spawn(function()
				local dir, id = CFrame.lookAt(newlook.Position, calc).LookVector, httpService:GenerateGUID(true)
				local shootPosition = (CFrame.new(newlook.Position, calc) * CFrame.new(Vector3.new(-bowRelX, -bowRelY, -bowRelZ))).Position
				bedwars.ProjectileController:createLocalProjectile(meta, ammo, projectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
				local res = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPosition, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.065)
				if not res then
					ProjectileDelay[item.itemType] = tick() + 0.15
				else
					res.Parent = replicatedStorage
					local shoot = itemMeta.launchSound
					shoot = shoot and shoot[math.random(1, #shoot)] or nil
					if shoot then bedwars.SoundManager:playSound(shoot) end
				end
			end)
			ProjectileDelay[item.itemType] = tick() + itemMeta.fireDelaySec
			if switched and not ign then task.wait(0.05) end
		end
	end

    local function doFastHitsLegitSwitch(ent)
        if not ent or not ent.RootPart then return end
        local pos = entitylib.character.RootPart.Position

        local bowItem, bowAmmo, bowProjectile, bowMeta = nil, nil, nil, nil
        for _, item in store.inventory.inventory.items do
            local _itemMeta = bedwars.ItemMeta[item.itemType]
            local proj = _itemMeta and _itemMeta.projectileSource
            if not proj then continue end
            for _, inv in store.inventory.inventory.items do
                if proj.ammoItemTypes and table.find(proj.ammoItemTypes, inv.itemType) then
                    bowItem = item
                    bowAmmo = inv.itemType
                    bowProjectile = proj.projectileType(inv.itemType)
                    bowMeta = bedwars.ProjectileMeta[bowProjectile]
                    break
                end
            end
            if bowItem then break end
        end

        if not bowItem or not bowMeta then return end
        if (FastHitsFireDelays[bowItem.itemType] or 0) >= tick() then return end

        local bowSlot = nil
        local hotbar = store.inventory.hotbar
        for i = 1, #hotbar do
            local v = hotbar[i]
            if v and v.item and v.item == bowItem then
                bowSlot = i - 1
                break
            end
        end
        if not bowSlot then return end

        local originalSlot = store.inventory.hotbarSlot
        if hotbarSwitch(bowSlot) then task.wait(0.05) end

        local holdingCrossbow = bowItem.itemType:find('crossbow')
        local holdingBow = bowItem.itemType:find('bow') and not holdingCrossbow
        if holdingCrossbow then
            pcall(function() bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE) end)
            bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.CROSSBOW_FIRE)
        elseif holdingBow then
            pcall(function() bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE) end)
            bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.BOW_FIRE)
        else
            local shootAnim = bedwars.ItemMeta[bowItem.tool.Name].thirdPerson and bedwars.ItemMeta[bowItem.tool.Name].thirdPerson.shootAnimation
            if shootAnim then
                bedwars.GameAnimationUtil:playAnimation(lplr, shootAnim)
            end
        end

        local meta = bowMeta
        local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
        local bowRelX = bedwars.BowConstantsTable.RelX or 0
        local bowRelY = bedwars.BowConstantsTable.RelY or 0
        local bowRelZ = bedwars.BowConstantsTable.RelZ or 0
        local newlook = CFrame.new(pos, ent.RootPart.Position) * CFrame.new(Vector3.new(bowRelX, bowRelY, bowRelZ))
        local playerGravityLS = workspace.Gravity
        local balloonsLS = ent.Character and ent.Character:GetAttribute('InflatedBalloons')
        if balloonsLS and balloonsLS > 0 then
            playerGravityLS = workspace.Gravity * (1 - (balloonsLS >= 4 and 1.2 or balloonsLS >= 3 and 1 or 0.975))
        end
        if ent.Character and ent.Character.PrimaryPart and ent.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
            playerGravityLS = 6
        end
        if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
            for _, owl in ipairs(collectionService:GetTagged('Owl')) do
                if owl:GetAttribute('Target') == ent.Player.UserId and owl:GetAttribute('Status') == 2 then
                    playerGravityLS = 0
                    break
                end
            end
        end

        local calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.Velocity, playerGravityLS, ent.HipHeight, ent.Jumping and 42.6 or nil, sharedFastHitsRayParams)

        if calc then
            targetinfo.Targets[ent] = tick() + 1
            task.spawn(function()
                local dir = CFrame.lookAt(newlook.Position, calc).LookVector
                local id = httpService:GenerateGUID(true)
                local shootPosition = (CFrame.new(newlook.Position, calc) * CFrame.new(Vector3.new(-bowRelX, -bowRelY, -bowRelZ))).Position
                bedwars.ProjectileController:createLocalProjectile(meta, bowAmmo, bowProjectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
                local res = projectileRemote:InvokeServer(bowItem.tool, bowAmmo, bowProjectile, shootPosition, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
                if not res then
                    FastHitsFireDelays[bowItem.itemType] = tick()
                else
                    local shoot = bowMeta.launchSound
                    shoot = shoot and shoot[math.random(1, #shoot)] or nil
                    if shoot then bedwars.SoundManager:playSound(shoot) end
                end
            end)
            FastHitsFireDelays[bowItem.itemType] = tick() + AutoShootInterval.Value
        end

        task.wait(0.05)
        hotbarSwitch(originalSlot)
    end

    local function doFastHitsNEW(ent)
        if not ent or not ent.RootPart then return end
        local pos = entitylib.character.RootPart.Position
        local projectiles = getProjectiles()
        NEWFastHitsUsage += 1
        if not projectiles[NEWFastHitsUsage] then NEWFastHitsUsage = 1 end
        if projectiles and projectiles[NEWFastHitsUsage] and canShoot(projectiles[NEWFastHitsUsage]) then
            local item, ammo, projectile, itemMeta = unpack(projectiles[NEWFastHitsUsage])
            shootFunc(item, ammo, projectile, itemMeta, pos, ent)
        end
    end

    local function shootAutoFireballProjectile(ammoType, targetEnt)
        if not targetEnt or not targetEnt.RootPart then return false end

        local items = getProjectileItems and getProjectileItems({ammoType}) or getProjectiles()
        local projData = nil

        for _, p in ipairs(items) do
            if p[2] == ammoType or (ammoType == 'fireball' and p[1].itemType:find('fireball')) then
                projData = p
                break
            end
        end

        if not projData then return false end

        local item, ammo, projectile, itemMeta = unpack(projData)
        if not item or not item.tool then return false end

        local pos = entitylib.character.RootPart.Position
        local targetPos = targetEnt.RootPart.Position

        local originalSlot = store.inventory.hotbarSlot
        local switched = false

        if AutoFireballLegitSwitch and AutoFireballLegitSwitch.Enabled then
            local slot = nil
            for i, v in ipairs(store.inventory.hotbar) do
                if v and v.item and v.item.tool == item.tool then
                    slot = i - 1
                    break
                end
            end
            if slot then
                switched = hotbarSwitch(slot)
                if switched then task.wait(0.06) end
            end
        else
            switched = switchItem(item.tool, 0.05)
        end

        local meta = bedwars.ProjectileMeta[projectile]
        if not meta then 
            if switched then hotbarSwitch(originalSlot) end
            return false 
        end

        local projSpeed = meta.launchVelocity
        local gravity = meta.gravitationalAcceleration or 196.2

        local bowRelX = bedwars.BowConstantsTable.RelX or 0
        local bowRelY = bedwars.BowConstantsTable.RelY or 0
        local bowRelZ = bedwars.BowConstantsTable.RelZ or 0

        local newlook = CFrame.new(pos, targetPos) * CFrame.new(bowRelX, bowRelY, bowRelZ)
        local calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, targetPos, targetEnt.RootPart.Velocity, workspace.Gravity, targetEnt.HipHeight, nil, _afbRayParams or sharedFastHitsRayParams)

        if calc then
            targetinfo.Targets[targetEnt] = tick() + 1

            task.spawn(function()
				task.wait(AutoFireballShootDelay.Value - (lplr:GetNetworkPing()))
                local dir = CFrame.lookAt(newlook.Position, calc).LookVector
                local id = httpService:GenerateGUID(true)
                local shootPos = (CFrame.new(newlook.Position, calc) * CFrame.new(-bowRelX, -bowRelY, -bowRelZ)).Position
				pcall(function() bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM) end)
                bedwars.ProjectileController:createLocalProjectile(meta, ammo, projectile, shootPos, id, dir * projSpeed, {drawDurationSeconds = 1})

                local res = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPos, pos, dir * projSpeed, id, {
                    drawDurationSeconds = 1,
                    shotId = httpService:GenerateGUID(false)
                }, workspace:GetServerTimeNow() - 0.06)

                if res then
                    res.Parent = replicatedStorage
                    local sound = itemMeta.launchSound
                    if sound and #sound > 0 then
                        bedwars.SoundManager:playSound(sound[math.random(1, #sound)])
                    end
                end
            end)

            lastAutoFireballTime = tick()
            if switched then
                task.wait(0.06)
                hotbarSwitch(originalSlot)
            end
            return true
        else
            if switched then hotbarSwitch(originalSlot) end
            return false
        end
    end

    local function startAutoFireballLoop()
        if autoFireballLoop then return end

        autoFireballLoop = task.spawn(function()
            while AutoFireball and AutoFireball.Enabled do
                if entitylib.isAlive and store.KillauraTarget and Killaura.Enabled then
                    local target = store.KillauraTarget
                    local fireRate = AutoFireballFireRate and AutoFireballFireRate.Value or 0.8

                    if tick() - lastAutoFireballTime >= fireRate then
                        local success = shootAutoFireballProjectile('fireball', target)
                        if success then
                            task.wait(0.25)
                            shootAutoFireballProjectile('arrow', target)
                        end
                    end
                end
                task.wait(0.1)
            end
            autoFireballLoop = nil
        end)
    end

    local function stopAutoFireballLoop()
        if autoFireballLoop then
            task.cancel(autoFireballLoop)
            autoFireballLoop = nil
        end
        lastAutoFireballTime = 0
    end

    local rayCheckFastHits = cloneRaycast()
	local sharedFastHitsRayParams = RaycastParams.new()
    local function doFastHitsProjectileAura(ent)
        if not ent or not ent.RootPart then return end
        local pos = entitylib.character.RootPart.Position

        local bowItem, bowAmmo, bowProjectile, bowMeta = nil, nil, nil, nil
        for _, item in store.inventory.inventory.items do
            local _itemMeta = bedwars.ItemMeta[item.itemType]
            local proj = _itemMeta and _itemMeta.projectileSource
            if not proj then continue end
            for _, inv in store.inventory.inventory.items do
                if proj.ammoItemTypes and table.find(proj.ammoItemTypes, inv.itemType) then
                    bowItem = item
                    bowAmmo = inv.itemType
                    bowProjectile = proj.projectileType(inv.itemType)
                    bowMeta = bedwars.ProjectileMeta[bowProjectile]
                    break
                end
            end
            if bowItem then break end
        end

        if not bowItem or not bowMeta then return end
        if (FastHitsFireDelays[bowItem.itemType] or 0) >= tick() then return end

        local originalSlot = store.inventory.hotbarSlot
        local switched = switchItem(bowItem.tool)
        if switched then task.wait(0.05) end

        local meta = bowMeta
        local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
        local bowRelX = bedwars.BowConstantsTable.RelX or 0
        local bowRelY = bedwars.BowConstantsTable.RelY or 0
        local bowRelZ = bedwars.BowConstantsTable.RelZ or 0
        local newlook = CFrame.new(pos, ent.RootPart.Position) * CFrame.new(Vector3.new(bowRelX, bowRelY, bowRelZ))
        local playerGravityPA = workspace.Gravity
        local balloonsPA = ent.Character and ent.Character:GetAttribute('InflatedBalloons')
        if balloonsPA and balloonsPA > 0 then
            playerGravityPA = workspace.Gravity * (1 - (balloonsPA >= 4 and 1.2 or balloonsPA >= 3 and 1 or 0.975))
        end
        if ent.Character and ent.Character.PrimaryPart and ent.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
            playerGravityPA = 6
        end
        if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
            for _, owl in ipairs(collectionService:GetTagged('Owl')) do
                if owl:GetAttribute('Target') == ent.Player.UserId and owl:GetAttribute('Status') == 2 then
                    playerGravityPA = 0
                    break
                end
            end
        end
        local calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.Velocity, playerGravityPA, ent.HipHeight, ent.Jumping and 42.6 or nil, sharedFastHitsRayParams)

        if calc then
            targetinfo.Targets[ent] = tick() + 1

            task.spawn(function()
                local dir = CFrame.lookAt(newlook.Position, calc).LookVector
                local id = httpService:GenerateGUID(true)
                local shootPosition = (CFrame.new(newlook.Position, calc) * CFrame.new(Vector3.new(-bowRelX, -bowRelY, -bowRelZ))).Position

                local holdingCrossbow = bowItem.itemType:find('crossbow')
                local holdingBow = bowItem.itemType:find('bow') and not holdingCrossbow
                if holdingCrossbow then
                    pcall(function() bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE) end)
                    bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.CROSSBOW_FIRE)
                elseif holdingBow then
                    pcall(function() bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE) end)
                    bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.BOW_FIRE)
                else
                    local shootAnim = bedwars.ItemMeta[bowItem.tool.Name].thirdPerson and bedwars.ItemMeta[bowItem.tool.Name].thirdPerson.shootAnimation
                    if shootAnim then
                        bedwars.GameAnimationUtil:playAnimation(lplr, shootAnim)
                    end
                end

                bedwars.ProjectileController:createLocalProjectile(meta, bowAmmo, bowProjectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
                local res = projectileRemote:InvokeServer(bowItem.tool, bowAmmo, bowProjectile, shootPosition, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
                if not res then
                    FastHitsFireDelays[bowItem.itemType] = tick()
                else
                    local shoot = bowItem.launchSound
                    shoot = shoot and shoot[math.random(1, #shoot)] or nil
                    if shoot then bedwars.SoundManager:playSound(shoot) end
                end
            end)

            FastHitsFireDelays[bowItem.itemType] = tick() + AutoShootInterval.Value
            if switched then
                task.wait(0.05)
                hotbarSwitch(originalSlot)
            end
        end
    end

    local function doFastHitsVirtualInput(ent)
        if not ent or not ent.RootPart then return end
        if not hasArrows() then return end
        if FirstPersonCheck.Enabled and not isFirstPerson() then return end

        local currentTime = tick()
        if (currentTime - lastAutoShootTime) < AutoShootInterval.Value then return end

        local bows = getBows()
        if #bows == 0 then return end
        local bowSlot = bows[1]
        local originalSlot = store.inventory.hotbarSlot

        if hotbarSwitch(bowSlot) then
            task.wait(AutoShootSwitchSpeed.Value)
            local hotbarItem = store.inventory.hotbar[bowSlot + 1]
            if hotbarItem and hotbarItem.item then
                local itemMeta = bedwars.ItemMeta[hotbarItem.item.itemType]
                if itemMeta and itemMeta.projectileSource then
                    local projSource = itemMeta.projectileSource
                    if projSource.ammoItemTypes and #projSource.ammoItemTypes > 0 then
                        local ammo = projSource.ammoItemTypes[1]
                        local projectile = nil
                        if type(projSource.projectileType) == "function" then
                            local success, result = pcall(function() return projSource.projectileType(ammo) end)
                            if success then projectile = result end
                        else
                            projectile = projSource.projectileType
                        end
                        if projectile then
                            local pos = entitylib.character.RootPart.Position
                            if AutoShootWaitDelay.Value > 0 then task.wait(AutoShootWaitDelay.Value) end

                            local meta = bedwars.ProjectileMeta[projectile]
                            local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
                            local calc = prediction.SolveTrajectory(pos, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.Velocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheckFastHits)

                            if calc then
                                local dir = CFrame.lookAt(pos, calc).LookVector
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                                task.wait(0.05)
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                            else
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                                task.wait(0.05)
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                            end
                        end
                    end
                end
            end
            task.wait(0.05)
        end

        local swordSlot = getSwordSlot()
        if swordSlot then
            hotbarSwitch(swordSlot)
        else
            hotbarSwitch(originalSlot)
        end

        lastAutoShootTime = currentTime  
    end

    local function getEntityFromCharacterFH(char)
        for _, ent in ipairs(entitylib.List) do
            if ent.Character == char then return ent end
        end
        return nil
    end

    local function doOldFastHits()
        if not store.KillauraTarget then return end

        local currentTime = tick()
        if (currentTime - lastOldShootTime) < OldShootInterval.Value then return end

        if OldFirstPersonCheck and OldFirstPersonCheck.Enabled then
            local cf = gameCamera.CFrame
            local char = entitylib.character
            if char and char.RootPart then
                local dist = (cf.Position - char.RootPart.Position).Magnitude
                if dist > 1 then return end
            end
        end

        local arrowItem = getItem('arrow')
        if not arrowItem or arrowItem.amount <= 0 then return end

        local bows = {}
        local swordSlot = nil
        local hotbar = store.inventory.hotbar
        for i = 1, #hotbar do
            local v = hotbar[i]
            if v and v.item and v.item.itemType then
                local itemMeta = bedwars.ItemMeta[v.item.itemType]
                if itemMeta then
                    if itemMeta.projectileSource then
                        local ps = itemMeta.projectileSource
                        if ps.ammoItemTypes and table.find(ps.ammoItemTypes, 'arrow') then
                            table.insert(bows, i - 1)
                        end
                    end
                    if itemMeta.sword and not swordSlot then
                        swordSlot = i - 1
                    end
                end
            end
        end

        if #bows == 0 then return end

        lastOldShootTime = currentTime
        local originalSlot = store.inventory.hotbarSlot

        for i = 1, #bows do
            local bowSlot = bows[i]
            if hotbarSwitch(bowSlot) then
                task.wait(OldSwitchDelay.Value)
                leftClick()
                task.wait(0.05)
            end
        end

        if swordSlot then
            hotbarSwitch(swordSlot)
        else
            hotbarSwitch(originalSlot)
        end
    end

    local function doFastHits()
        if not FastHits.Enabled then return end
        if not Attacking then return end
        if not store.KillauraTarget then return end

        if FastHitsHitsRequiredToggle and FastHitsHitsRequiredToggle.Enabled then
            if not fastHitsActivationReady then return end
            if fastHitsTrackedEntity and fastHitsTrackedEntity ~= store.KillauraTarget then
                fastHitsActivationReady = false
                return
            end
        end

        local ent = store.KillauraTarget
        if not ent or not ent.RootPart then return end

        local selfpos = entitylib.character.RootPart.Position
        local dist = (ent.RootPart.Position - selfpos).Magnitude
        if dist > (AttackRange.Value + 1) then return end

        if FastHitsMode.Value == 'OGFastHits' then
            doFastHitsVirtualInput(ent)
        elseif FastHitsMode.Value == 'NEWFastHits' then
            if LegitSwitch and LegitSwitch.Enabled then
                doFastHitsLegitSwitch(ent)
            else
                doFastHitsNEW(ent)
            end
        end
    end

    local function startAutoShootLoop()
        if autoShootLoop then return end

        fastHitsHitTarget = nil
        fastHitsTrackedEntity = nil
        fastHitsHitCount = 0
        fastHitsActivationReady = false
        fastHitsLastHitTime = 0

        if FastHitsHitsRequiredToggle and FastHitsHitsRequiredToggle.Enabled then
            local hitsRequiredConn
            hitsRequiredConn = vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                if not FastHits.Enabled or not FastHitsHitsRequiredToggle.Enabled then return end
                local attackerChar = damageTable.fromEntity
                local victimChar = damageTable.entityInstance
                if not attackerChar or not victimChar then return end
                local isLocalAttacker = lplr.Character and attackerChar == lplr.Character
                if not isLocalAttacker then
                    local ap = playersService:GetPlayerFromCharacter(attackerChar)
                    if ap == lplr then isLocalAttacker = true end
                end
                if not isLocalAttacker then return end
                local now = tick()
                if now - fastHitsLastHitTime < FASTHITS_HIT_DEBOUNCE then return end
                fastHitsLastHitTime = now
                local victimEnt = getEntityFromCharacterFH(victimChar)
                if not victimEnt then return end
                if fastHitsHitTarget == victimChar then
                    fastHitsHitCount = fastHitsHitCount + 1
                else
                    fastHitsHitTarget = victimChar
                    fastHitsTrackedEntity = victimEnt
                    fastHitsHitCount = 1
                    fastHitsActivationReady = false
                end
                if fastHitsHitCount >= (FastHitsHitsRequiredSlider and FastHitsHitsRequiredSlider.Value or 2) then
                    fastHitsActivationReady = true
                end
			end)
            FastHits:Clean(hitsRequiredConn)
        end

        autoShootLoop = task.spawn(function()
            while Killaura.Enabled and FastHits.Enabled do
                doFastHits()
                task.wait(0.05)  
            end
            autoShootLoop = nil
        end)
    end

    local function stopAutoShootLoop()
        if autoShootLoop then
            task.cancel(autoShootLoop)
            autoShootLoop = nil
        end
        table.clear(FastHitsFireDelays)
        table.clear(NEWFastHitsProjectileDelay)
        NEWFastHitsLastShot = 0
        NEWFastHitsUsage = 1
        fastHitsHitTarget = nil
        fastHitsTrackedEntity = nil
        fastHitsHitCount = 0
        fastHitsActivationReady = false
        fastHitsLastHitTime = 0
    end
    
    Killaura = vape.Categories.Blatant:CreateModule({
        Name = 'Killaura',
        Function = function(callback)
            if callback then 
				local attacked = {}   
                lastSwingServerTime = Workspace:GetServerTimeNow()
                lastSwingServerTimeDelta = 0
                lastAttackTime = 0
                swingCooldown = 0
                resetSwordCooldown() 
                lastTargetTime = 0 
                continueSwingCount = 0
                if Mouse and LegitAura and Mouse.Enabled and LegitAura.Enabled then
                    Mouse:Toggle(false)
                    LegitAura:Toggle(false)
                    notif("Killaura", "yo u cant have require mouse down AND swing only both on at da same time turned both off 4 u", 5)
                end

                if RangeCircle.Enabled then
                    createRangeCircle()
                end
                if inputService.TouchEnabled and not preserveSwordIcon then
                    pcall(function()
                        lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
                    end)
                end

                if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
                    local fake = {
                        Controllers = {
                            ViewmodelController = {
                                isVisible = function()
                                    return not Attacking
                                end,
                                playAnimation = function(...)
                                    local args = {...}
                                    if not Attacking then
                                        pcall(function()
                                            bedwars.ViewmodelController:playAnimation(select(2, unpack(args)))
                                        end)
                                    end
                                end
                            }
                        }
                    }

                    task.spawn(function()
                        local started = false
                        repeat
                            if Attacking then
                                if not armC0 then
                                    armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
                                end
                                local first = not started
                                started = true

                                if AnimationMode.Value == 'Random' then
                                    anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
                                end

                                for _, v in anims[AnimationMode.Value] do
                                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
                                        C0 = armC0 * v.CFrame
                                    })
                                    AnimTween:Play()
                                    AnimTween.Completed:Wait()
                                    first = false
                                    if (not Killaura.Enabled) or (not Attacking) then break end
                                end
                            elseif started then
                                started = false
                                AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                                    C0 = armC0
                                })
                                AnimTween:Play()
                            end

                            if not started then
                                task.wait(1 / UpdateRate.Value)
                            end
                        until (not Killaura.Enabled) or (not Animation.Enabled)
                    end)
                end

				local _gatherSwing = {}
				local _gatherAttack = {}
				local _sortWrapA = {Entity = nil}
				local _sortWrapB = {Entity = nil}

				local function gatherTargets(selfpos)
					table.clear(_gatherSwing)
					table.clear(_gatherAttack)
					local swingRange = SwingRange.Value
					local attackRange = AttackRange.Value
					local wallcheck = Targets.Walls.Enabled or nil
					local maxTargets = MaxTargets.Value
					local priority = TargetPriority.Value
					local sortFunc = sortmethods[Sort.Value]
					local playersEnabled = Targets.Players.Enabled
					local npcsEnabled = Targets.NPCs.Enabled

					local allEnts = entitylib.List
					for i = 1, #allEnts do
						local ent = allEnts[i]
						if not ent.RootPart then continue end
						if not ent.Targetable then continue end
						if ent.Player and not playersEnabled then continue end
						if ent.NPC and not npcsEnabled then continue end
						local dist = (ent.RootPart.Position - selfpos).Magnitude
						if wallcheck and not hasLineOfSightKA(selfpos, ent.RootPart.Position, ent.Character) then continue end
						if dist <= swingRange then
							if #_gatherSwing < maxTargets then
								table.insert(_gatherSwing, ent)
							end
						end
						if dist <= attackRange then
							if #_gatherAttack < maxTargets then
								table.insert(_gatherAttack, ent)
							end
						end
					end

					if sortFunc then
						table.sort(_gatherSwing, function(a, b)
							_sortWrapA.Entity = a
							_sortWrapB.Entity = b
							return sortFunc(_sortWrapA, _sortWrapB)
						end)
						table.sort(_gatherAttack, function(a, b)
							_sortWrapA.Entity = a
							_sortWrapB.Entity = b
							return sortFunc(_sortWrapA, _sortWrapB)
						end)
					end

					return _gatherSwing, _gatherAttack
				end

                local _cachedSwordType = nil
                local _cachedIsClaw = false

                repeat
                    pcall(function()
                        if entitylib.isAlive and entitylib.character.HumanoidRootPart then
                            RangeCirclePart.Position = entitylib.character.HumanoidRootPart.Position - Vector3.new(0, entitylib.character.Humanoid.HipHeight, 0)
                        end
                    end)
					table.clear(attacked)
					local sword, meta, canAttack = getAttackData()
                    Attacking = false
                    store.KillauraTarget = nil

                    if vapeTargetInfo and vapeTargetInfo.Targets then
                        vapeTargetInfo.Targets.Killaura = nil
                    end

                    if sword and canAttack then
                        if sword.itemType ~= _cachedSwordType then
                            _cachedSwordType = sword.itemType
                            _cachedIsClaw = sword.itemType and sword.itemType:find("summoner_claw") ~= nil
                        end
                        local isClaw = _cachedIsClaw
                        
                        local selfpos = entitylib.character.RootPart.Position
                        local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
                        local maxAngle = math.rad(AngleSlider.Value) / 2
                        local swingPlrs, attackPlrs = gatherTargets(selfpos)
                        
                        local hasValidSwingTargets = false
                        local hasValidAttackTargets = false
                        
                        for _, v in swingPlrs do
                            local delta = (v.RootPart.Position - selfpos)
                            local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                            if angle <= maxAngle then
                                hasValidSwingTargets = true
                                break
                            end
                        end
                        
                        for _, v in attackPlrs do
                            local delta = (v.RootPart.Position - selfpos)
                            local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                            if angle <= maxAngle then  
                                hasValidAttackTargets = true
                                break
                            end
                        end
                        
                        if hasValidSwingTargets or hasValidAttackTargets then
                            lastTargetTime = tick()
                        end
                        
                        local shouldSwing = hasValidSwingTargets or hasValidAttackTargets or shouldContinueSwinging()
                        
                        if shouldSwing then
                            switchItem(sword.tool, 0)
                            
                            if hasValidAttackTargets then
                                for _, v in attackPlrs do
                                    local delta = (v.RootPart.Position - selfpos)
                                    local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                                    local swingAngle = math.rad(AngleSlider.Value)
                                    if angle > (swingAngle / 2) then continue end

                                    table.insert(attacked, {
                                        Entity = v,
                                        Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
                                    })
                                    targetinfo.Targets[v] = tick() + 1

                                    if vapeTargetInfo and vapeTargetInfo.Targets then
                                        local _vapeKillauraInfo = {
                                            Humanoid = {Health = 0, MaxHealth = 0},
                                            Player = nil
                                        }
                                        _vapeKillauraInfo.Humanoid.Health = v.Health
                                        _vapeKillauraInfo.Humanoid.MaxHealth = v.MaxHealth
                                        _vapeKillauraInfo.Player = v.Player
                                        vapeTargetInfo.Targets.Killaura = _vapeKillauraInfo
                                    end

                                    if not Attacking then
                                        Attacking = true
                                        store.KillauraTarget = v
                                        if not isClaw then
                                            local inLegitRange = delta.Magnitude < 14.4
                                            local allowSwingAnim = not Swing.Enabled and AnimDelay <= tick() and (not LegitAura.Enabled or (not LegitAura.Enabled and not Mouse.Enabled) or (inLegitRange and (tick() - swingCooldown) >= math.max(SwingTime.Enabled and SwingTimeSlider.Value or 0.25, 0.11)))
                                            if allowSwingAnim then
                                                local swingSpeed = 0.25
                                                if SwingTime.Enabled then
                                                    swingSpeed = math.max(SwingTimeSlider.Value, 0.11)
                                                elseif meta.sword.respectAttackSpeedForEffects then
                                                    swingSpeed = meta.sword.attackSpeed
                                                end
                                                AnimDelay = tick() + swingSpeed
                                                pcall(function()
                                                    bedwars.SwordController:playSwordEffect(meta, false)
                                                    if meta.displayName:find(' Scythe') then
                                                        bedwars.ScytheController:playLocalAnimation()
                                                    end
                                                end)
                                                if vape.ThreadFix and setthreadidentity then
                                                    pcall(setthreadidentity, 8)
                                                end
                                            end
                                        end
                                    end

                                    local canHit = delta.Magnitude <= AttackRange.Value
                                    local fastHitsRange = delta.Magnitude <= (AttackRange.Value + 1)

                                    if not canHit and not fastHitsRange then continue end

                                    if AirHit and AirHit.Enabled then
                                        local humanoid = v.Character:FindFirstChildOfClass("Humanoid")
                                        if humanoid then
                                            local state = humanoid:GetState()
                                            if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Physics then
                                                if math.random(1, 100) > AirHitsChance.Value then
                                                    continue
                                                end
                                            end
                                        end
                                    end

                                    if SyncHits.Enabled then
                                        local swingSpeed = SwingTime.Enabled and SwingTimeSlider.Value or (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0.42)
                                        local timeSinceLastSwing = tick() - swingCooldown
                                        local requiredDelay = math.max(swingSpeed * 0.4, 0.03)
                                        
                                        if timeSinceLastSwing < requiredDelay then 
                                            continue 
                                        end
                                    end

                                    local actualRoot = v.Character.PrimaryPart
                                    if actualRoot then
                                        local pos = selfpos
                                        local targetPos = actualRoot.Position
                                        local camPos = gameCamera.CFrame.Position
                                        local dir = (targetPos - camPos).Unit

                                        if not SyncHits.Enabled or (tick() - swingCooldown) >= 0.1 then
                                            swingCooldown = tick()
                                        end
                                        lastSwingServerTimeDelta = workspace:GetServerTimeNow() - lastSwingServerTime
                                        lastSwingServerTime = workspace:GetServerTimeNow()

                                        store.attackReach = (delta.Magnitude * 100) // 1 / 100
                                        store.attackReachUpdate = tick() + 1

                                        if SwingTime.Enabled then
                                            lastAttackTime = tick()

                                            if delta.Magnitude < 14.4 and SwingTimeSlider.Value > 0.11 then
                                                AnimDelay = tick()
                                            end
                                        else
                                            lastAttackTime = tick()
                                        end

                                        if isClaw then
                                            KaidaController:request(v.Character)
                                        else
                                            local attackData = {
                                                weapon = sword.tool,
                                                entityInstance = v.Character,
                                                chargedAttack = {chargeRatio = 0},
                                                validate = {
                                                    raycast = {
                                                        cameraPosition = {value = camPos},
                                                        cursorDirection = {value = dir}
                                                    },
                                                    targetPosition = {value = targetPos},
                                                    selfPosition = {value = pos}
                                                }
                                            }
                                            
											if canHit then
                                                FireAttackRemote(attackData)
                                            end

											if FastHits.Enabled and not (AutoFireball and AutoFireball.Enabled) and not autoShootLoop then
												if FastHitsMode.Value == 'NEWFastHits' then
													if (tick() - lastShot) >= (0.2 + lplr:GetNetworkPing() + FireRate.Value) then
														local projectiles = getProjectiles()
														Usage += 1
														if not projectiles[Usage] then Usage = 1 end
														if projectiles and projectiles[Usage] and canShoot(projectiles[Usage]) then
															local item, ammo, projectile, itemMeta = unpack(projectiles[Usage])
															if LegitSwitch and LegitSwitch.Enabled then
																local bowSlot = nil
																local swordSlot = nil
																local originalSlot = store.inventory.hotbarSlot
																local hotbar = store.inventory.hotbar
																for i = 1, #hotbar do
																	local hv = hotbar[i]
																	if hv and hv.item and hv.item.itemType then
																		if hv.item.itemType == item.itemType and not bowSlot then
																			bowSlot = i - 1
																		end
																		local hm = bedwars.ItemMeta[hv.item.itemType]
																		if hm and hm.sword and not swordSlot then
																			swordSlot = i - 1
																		end
																	end
																end
																if bowSlot then
																	bedwars.Store:dispatch({type = 'InventorySelectHotbarSlot', slot = bowSlot})
																	shootFunc(item, ammo, projectile, itemMeta, selfpos, v, false)
																	bedwars.Store:dispatch({type = 'InventorySelectHotbarSlot', slot = swordSlot or originalSlot})
																end
															else
																shootFunc(item, ammo, projectile, itemMeta, selfpos, v, true)
															end
															lastShot = tick()
														end
													end
												elseif FastHitsMode.Value == 'OLDFastHits' then
													doOldFastHits()
												end
											end
                                        end
                                    end
                                end
                            else
                                Attacking = true
                                if not isClaw then
                                    if not Swing.Enabled and AnimDelay <= tick() and not LegitAura.Enabled then
                                        local swingSpeed = 0.25
                                        if SwingTime.Enabled then
                                            swingSpeed = math.max(SwingTimeSlider.Value, 0.11)
                                        elseif meta.sword.respectAttackSpeedForEffects then
                                            swingSpeed = meta.sword.attackSpeed
                                        end
                                        AnimDelay = tick() + swingSpeed
                                        pcall(function()
                                            bedwars.SwordController:playSwordEffect(meta, false)
                                            if meta.displayName:find(' Scythe') then
                                                bedwars.ScytheController:playLocalAnimation()
                                            end
                                        end)
                                        if vape.ThreadFix and setthreadidentity then
                                            pcall(setthreadidentity, 8)
                                        end
                                    end
                                end

                                local currentSwingSpeed = SwingTime.Enabled and SwingTimeSlider.Value or (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0.42)
                                local minSwingDelay = math.max(currentSwingSpeed, 0.05)
                                
                                if not SyncHits.Enabled or (tick() - swingCooldown) >= minSwingDelay then
                                    swingCooldown = tick()
                                end
                            end
                        end
                    end

                    pcall(function()
                        for i, v in Boxes do
                            v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
                            if v.Adornee then
                                v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
                                v.Transparency = 1 - attacked[i].Check.Opacity
                            end
                        end

                        for i, v in Particles do
                            v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
                            v.Parent = attacked[i] and gameCamera or nil
                        end
                    end)

                    if Face.Enabled and attacked[1] then
                        if true then
                            local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
                            local targetCFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
                            local speed = FaceSpeed and FaceSpeed.Value or 15
                            local alpha = math.clamp(speed / 100, 0.01, 1)
                            entitylib.character.RootPart.CFrame = entitylib.character.RootPart.CFrame:Lerp(targetCFrame, alpha)
                        end
                    end
                    pcall(function() if RangeCirclePart ~= nil then RangeCirclePart.Parent = gameCamera end end)

                    task.wait(1 / UpdateRate.Value)
                until not Killaura.Enabled
            else
                table.clear(ProjectileDelay)
                store.KillauraTarget = nil
                for _, v in Boxes do
                    v.Adornee = nil
                end
                for _, v in Particles do
                    v.Parent = nil
                end
                if inputService.TouchEnabled then
                    pcall(function()
                        lplr.PlayerGui.MobileUI['2'].Visible = true
                    end)
                end
                Attacking = false
                if armC0 then
                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                        C0 = armC0
                    })
                    AnimTween:Play()
                end
                if RangeCirclePart ~= nil then RangeCirclePart:Destroy() end
            end
        end,
        Tooltip = 'Attack players around you\nwithout aiming at them.'
    })

    pcall(function()
        local PSI = Killaura:CreateToggle({
            Name = 'Preserve Sword Icon',
            Function = function(callback)
                preserveSwordIcon = callback
            end,
            Default = true
        })
        PSI.Object.Visible = inputService.TouchEnabled
    end)

    Targets = Killaura:CreateTargets({
        Players = true,
        NPCs = true
    })
    
    TargetPriority = Killaura:CreateDropdown({
        Name = 'Target Priority',
        List = {'Players First', 'NPCs First', 'Distance'},
        Default = 'Players First',
        Tooltip = 'Choose which targets to prioritize'
    })
    
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do
        if not table.find(methods, i) then
            table.insert(methods, i)
        end
    end
    SwingRange = Killaura:CreateSlider({
        Name = 'Swing range',
        Min = 1,
        Max = 40, 
        Default = 22, 
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    AttackRange = Killaura:CreateSlider({
        Name = 'Attack range',
        Min = 1,
        Max = 22,
        Default = 22, 
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    RangeCircle = Killaura:CreateToggle({
        Name = "Range Visualiser",
        Function = function(call)
            if call then
                createRangeCircle()
            else
                if RangeCirclePart then
                    RangeCirclePart:Destroy()
                    RangeCirclePart = nil
                end
            end
        end
    })
    AngleSlider = Killaura:CreateSlider({
        Name = 'Max angle',
        Min = 1,
        Max = 360,
        Default = 360
    })
    UpdateRate = Killaura:CreateSlider({
        Name = 'Update rate',
        Min = 1,
        Max = 120,
        Default = 60,
        Suffix = 'hz'
    })
    MaxTargets = Killaura:CreateSlider({
        Name = 'Max targets',
        Min = 1,
        Max = 5,
        Default = 5
    })
    Sort = Killaura:CreateDropdown({
        Name = 'Target Mode',
        List = methods
    })
    Mouse = Killaura:CreateToggle({
        Name = 'Require mouse down',
        Function = function(callback)
            if callback and LegitAura and LegitAura.Enabled then
                Mouse:Toggle(false)
                LegitAura:Toggle(false)
                notif("Killaura", "yo u cant have require mouse down AND swing only on at da same time turned both off 4 u ", 5)
            end
        end
    })
    Swing = Killaura:CreateToggle({Name = 'No Swing'})
    GUI = Killaura:CreateToggle({Name = 'GUI check'})
    SwingTime = Killaura:CreateToggle({
        Name = 'Custom Swing Time',
        Function = function(callback)
            SwingTimeSlider.Object.Visible = callback
        end
    })
    SwingTimeSlider = Killaura:CreateSlider({
        Name = 'Swing Time',
        Min = 0,
        Max = 1,
        Default = 0.42,
        Decimal = 100,
        Visible = false
    })
    ContinueSwinging = Killaura:CreateToggle({
        Name = 'Continue Swinging',
        Tooltip = 'Swing X times after losing target (based on swing speed)',
        Function = function(callback)
            if ContinueSwingTime then
                ContinueSwingTime.Object.Visible = callback
            end
        end
    })
    ContinueSwingTime = Killaura:CreateSlider({
        Name = 'Swing Duration',
        Min = 0,  
        Max = 5,  
        Default = 1,
        Decimal = 10,
        Suffix = 's',
        Visible = false
    })
    CustomHitReg = Killaura:CreateToggle({
        Name = 'Custom Hit Reg',
        Tooltip = 'Limit how many hits per second',
        Function = function(callback)
            if CustomHitRegSlider then
                CustomHitRegSlider.Object.Visible = callback
            end
            if callback then
                lastCustomHitTime = 0
            end
        end
    })
    CustomHitRegSlider = Killaura:CreateSlider({
        Name = 'Hits Per Second',
        Min = 1,
        Max = 36,
        Default = 30,
        Tooltip = 'Maximum hits per second',
        Visible = false
    })
	FreeHitRegToggle = Killaura:CreateToggle({
        Name = 'Free Hit Reg Toggle',
        Tooltip = 'Changes the free player limit against you.',
        Function = function(callback)
            if FreeHitRegSlider then FreeHitRegSlider.Object.Visible = callback end
        end,
		Visible = (getAccountTier(lplr) == 4) or false
    })

    FreeHitRegSlider = Killaura:CreateSlider({
        Name = 'Free Hit Reg',
        Min = 0,
        Max = 36,
        Default = 32,
        Visible = false
    })
    SyncHits = Killaura:CreateToggle({
        Name = 'Sync Hits',
        Tooltip = 'Waits for sword animation before attacking'
    })
    Killaura:CreateToggle({
        Name = 'Show target',
        Function = function(callback)
            BoxSwingColor.Object.Visible = callback
            BoxAttackColor.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local box = Instance.new('BoxHandleAdornment')
                    box.Adornee = nil
                    box.AlwaysOnTop = true
                    box.Size = Vector3.new(3, 5, 3)
                    box.CFrame = CFrame.new(0, -0.5, 0)
                    box.ZIndex = 0
                    box.Parent = vape.gui
                    Boxes[i] = box
                end
            else
                for _, v in Boxes do
                    v:Destroy()
                end
                table.clear(Boxes)
            end
        end
    })
    BoxSwingColor = Killaura:CreateColorSlider({
        Name = 'Target Color',
        Darker = true,
        DefaultHue = 0.6,
        DefaultOpacity = 0.5,
        Visible = false,
        Function = function(hue, sat, val)
            if Killaura.Enabled and RangeCirclePart ~= nil then
                RangeCirclePart.Color = Color3.fromHSV(hue, sat, val)
            end
        end
    })
    BoxAttackColor = Killaura:CreateColorSlider({
        Name = 'Attack Color',
        Darker = true,
        DefaultOpacity = 0.5,
        Visible = false
    })
    Killaura:CreateToggle({
        Name = 'Target particles',
        Function = function(callback)
            ParticleTexture.Object.Visible = callback
            ParticleColor1.Object.Visible = callback
            ParticleColor2.Object.Visible = callback
            ParticleSize.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local part = Instance.new('Part')
                    part.Size = Vector3.new(2, 4, 2)
                    part.Anchored = true
                    part.CanCollide = false
                    part.Transparency = 1
                    part.CanQuery = false
                    part.Parent = Killaura.Enabled and gameCamera or nil
                    local particles = Instance.new('ParticleEmitter')
                    particles.Brightness = 1.5
                    particles.Size = NumberSequence.new(ParticleSize.Value)
                    particles.Shape = Enum.ParticleEmitterShape.Sphere
                    particles.Texture = ParticleTexture.Value
                    particles.Transparency = NumberSequence.new(0)
                    particles.Lifetime = NumberRange.new(0.4)
                    particles.Speed = NumberRange.new(16)
                    particles.Rate = 128
                    particles.Drag = 16
                    particles.ShapePartial = 1
                    particles.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
                    })
                    particles.Parent = part
                    Particles[i] = part
                end
            else
                for _, v in Particles do
                    v:Destroy()
                end
                table.clear(Particles)
            end
        end
    })
    ParticleTexture = Killaura:CreateTextBox({
        Name = 'Texture',
        Default = 'rbxassetid://14736249347',
        Function = function()
            for _, v in Particles do
                v.ParticleEmitter.Texture = ParticleTexture.Value
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleColor1 = Killaura:CreateColorSlider({
        Name = 'Color Begin',
        Function = function(hue, sat, val)
            for _, v in Particles do
                v.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
                })
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleColor2 = Killaura:CreateColorSlider({
        Name = 'Color End',
        Function = function(hue, sat, val)
            for _, v in Particles do
                v.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
                })
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleSize = Killaura:CreateSlider({
        Name = 'Size',
        Min = 0,
        Max = 1,
        Default = 0.2,
        Decimal = 100,
        Function = function(val)
            for _, v in Particles do
                v.ParticleEmitter.Size = NumberSequence.new(val)
            end
        end,
        Darker = true,
        Visible = false
    })
    Face = Killaura:CreateToggle({
        Name = 'Face target',
        Function = function(callback)
            if FaceSpeed then FaceSpeed.Object.Visible = callback end
        end
    })

    FaceSpeed = Killaura:CreateSlider({
        Name = 'Face Speed',
        Min = 1,
        Max = 100,
        Default = 15,
        Decimal = 10,
        Darker = true,
        Visible = false,
        Tooltip = 'How fast to snap towards target (lower = slower/smoother)'
    })
    Animation = Killaura:CreateToggle({
        Name = 'Custom Animation',
        Function = function(callback)
            AnimationMode.Object.Visible = callback
            AnimationTween.Object.Visible = callback
            AnimationSpeed.Object.Visible = callback
            if Killaura.Enabled then
                Killaura:Toggle()
                Killaura:Toggle()
            end
        end
    })
    local animnames = {}
    for i in anims do
        table.insert(animnames, i)
    end
    AnimationMode = Killaura:CreateDropdown({
        Name = 'Animation Mode',
        List = animnames,
        Darker = true,
        Visible = false
    })
    AnimationSpeed = Killaura:CreateSlider({
        Name = 'Animation Speed',
        Min = 0,
        Max = 2,
        Default = 1,
        Decimal = 10,
        Darker = true,
        Visible = false
    })
    AnimationTween = Killaura:CreateToggle({
        Name = 'No Tween',
        Darker = true,
        Visible = false
    })
    Limit = Killaura:CreateToggle({
        Name = 'Limit to items',
        Function = function(callback)
            if inputService.TouchEnabled and Killaura.Enabled then
                pcall(function()
                    lplr.PlayerGui.MobileUI['2'].Visible = callback
                end)
            end
        end,
        Tooltip = 'Only attacks when the sword is held'
    })
    LegitAura = Killaura:CreateToggle({
        Name = 'Swing only',
        Tooltip = 'Only attacks while swinging manually',
        Function = function(callback)
            if callback and Mouse and Mouse.Enabled then
                LegitAura:Toggle(false)
                Mouse:Toggle(false)
                notif("Killaura", "yo u cant have swing only AND require mouse down on at da same time lol turned both off 4 u ", 5)
            end
        end
    })
    AirHit = Killaura:CreateToggle({
        Name = 'Air Hits',
        Default = true,
        Tooltip = 'Control hit chance when target is airborne',
        Function = function(callback)
            if AirHitsChance then
                AirHitsChance.Object.Visible = callback
            end
            if Killaura.Enabled and callback and AirHitsChance and AirHitsChance.Object then
                AirHitsChance.Object.Visible = true
            end
        end
    })
    AirHitsChance = Killaura:CreateSlider({
        Name = 'Air Hits Chance',
        Min = 0,
        Max = 100,
        Default = 100,
        Suffix = '%',
        Decimal = 5,
        Darker = true,
        Visible = false
    })
    KitCheck = Killaura:CreateToggle({
        Name = 'Attackable Check',
        Tooltip = 'Stops Killaura ONLY whenever you cannot swing your sword.',
        Function = function(callback)
        end,
        Default = false
    })

	FastHits = Killaura:CreateToggle({
        Name = 'Fast Hits',
        Tooltip = 'Deals more damage quicker using projectiles',
        Default = false,
        Function = function(call)
            FastHitsMode.Object.Visible = call
            FireRate.Object.Visible = call and FastHitsMode.Value == 'NEWFastHits'
            if LegitSwitch then LegitSwitch.Object.Visible = call and FastHitsMode.Value == 'NEWFastHits' end
            if OldShootInterval then OldShootInterval.Object.Visible = call and FastHitsMode.Value == 'OLDFastHits' end
            if OldSwitchDelay then OldSwitchDelay.Object.Visible = call and FastHitsMode.Value == 'OLDFastHits' end
            if OldWaitDelay then OldWaitDelay.Object.Visible = call and FastHitsMode.Value == 'OLDFastHits' end
            if OldFirstPersonCheck then OldFirstPersonCheck.Object.Visible = call and FastHitsMode.Value == 'OLDFastHits' end
        end
    })
    FastHitsMode = Killaura:CreateDropdown({
        Name = 'Fast Hits Mode',
        List = {'NEWFastHits', 'OLDFastHits'},
        Default = 'NEWFastHits',
        Darker = true,
        Visible = false,
        Function = function(val)
            FireRate.Object.Visible = val == 'NEWFastHits'
            LegitSwitch.Object.Visible = val == 'NEWFastHits'
            OldShootInterval.Object.Visible = val == 'OLDFastHits'
            OldSwitchDelay.Object.Visible = val == 'OLDFastHits'
            OldWaitDelay.Object.Visible = val == 'OLDFastHits'
            OldFirstPersonCheck.Object.Visible = val == 'OLDFastHits'
        end
    })
    LegitSwitch = Killaura:CreateToggle({
        Name = 'Legit Switch',
        Default = false,
        Darker = true,
        Visible = false,
        Tooltip = 'Uses hotbarSwitch to switch to crossbow before shooting instead of silent switch'
    })
    OldShootInterval = Killaura:CreateSlider({
        Name = 'Shoot Interval',
        Min = 0.1,
        Max = 3,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Darker = true,
        Visible = false,
        Tooltip = 'How often to shoot bows'
    })
    OldSwitchDelay = Killaura:CreateSlider({
        Name = 'Switch Delay',
        Min = 0,
        Max = 0.2,
        Default = 0.05,
        Decimal = 100,
        Suffix = 's',
        Darker = true,
        Visible = false,
        Tooltip = 'Delay between switching and shooting'
    })
    OldWaitDelay = Killaura:CreateSlider({
        Name = 'Wait Delay',
        Min = 0,
        Max = 1,
        Default = 0,
        Decimal = 100,
        Suffix = 's',
        Darker = true,
        Visible = false,
        Tooltip = 'Delay before shooting'
    })
    OldFirstPersonCheck = Killaura:CreateToggle({
        Name = 'First Person Only',
        Default = false,
        Darker = true,
        Visible = false,
        Tooltip = 'Only works in first person mode'
    })

	AutoFireball = Killaura:CreateToggle({
        Name = 'Auto Fireball',
        Default = false,
        Tooltip = 'Shoots crossbow then fireball at target. Falls back to whichever you have.',
        Function = function(enabled)
			if AutoFireballFireRate then AutoFireballFireRate.Object.Visible = enabled end
			if AutoFireballLegitSwitch then AutoFireballLegitSwitch.Object.Visible = enabled end
			if AutoFireballShootDelay then AutoFireballShootDelay.Object.Visible = enabled end
            if enabled then
                startAutoFireballLoop()
            else
                stopAutoFireballLoop()
            end
        end
    })
	AutoFireballLegitSwitch = Killaura:CreateToggle({
		Name = 'Fireball Legit Switch',
		Default = false,
        Decimal = 100,
        Darker = true,
        Visible = false,
	})
	AutoFireballFireRate = Killaura:CreateSlider({
        Name = 'Fireball Fire rate',
        Suffix = 's',
        Min = 0,
        Max = 2,
        Decimal = 100,
        Darker = true,
        Visible = false,
        Default = 0
    })
	AutoFireballShootDelay = Killaura:CreateSlider({
        Name = 'Fireball Shoot Delay',
        Min = 0,
        Max = 0.2,
        Default = 0.05,
        Decimal = 100,
        Suffix = 's',
        Darker = true,
        Visible = false,
        Tooltip = 'Delay in shooting the fireballs'
    })
    FireRate = Killaura:CreateSlider({
        Name = 'Fire rate',
        Suffix = 's',
        Min = 0,
        Max = 2,
        Decimal = 100,
        Darker = true,
        Visible = false,
        Default = 0
    })

    task.defer(function()
        if AirHit and AirHit.Enabled and AirHitsChance and AirHitsChance.Object then
            AirHitsChance.Object.Visible = true
        end
    end)

end)

-- granddad killaura
local Attacking
run(function()
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local ChargeTime
	local UpdateRate
	local AngleSlider
	local MaxTargets
	local Mouse
	local Swing
	local GUI
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local SophiaCheck
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local LegitAura = {}
	local Particles, Boxes = {}, {}
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local AttackRemote = {FireServer = function() end}
	task.spawn(function()
		AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
	end)

	local function flatAngle(selfpos, targetpos, facing)
		local flat = (targetpos - selfpos) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 0.001 then return 0 end
		return math.acos(math.clamp(facing:Dot(flat.Unit), -1, 1))
	end

	local function flatFacing(rootCFrame)
		local lv = rootCFrame.LookVector * Vector3.new(1, 0, 1)
		if lv.Magnitude < 0.001 then return rootCFrame.RightVector * Vector3.new(1, 0, 1) end
		return lv.Unit
	end

	local lastFiredSwing = 0

	local function getAttackData()
		if SophiaCheck and SophiaCheck.Enabled then
			if isFrozen(nil, 10) then return false end
		end
		if Mouse and Mouse.Enabled then
			local mousePressed = inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
			if not mousePressed then return false end
		end
		if GUI and GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end
		local sword = (Limit and Limit.Enabled) and store.hand or store.tools.sword
		if not sword or not sword.tool then return false end
		local meta = bedwars.ItemMeta[sword.tool.Name]
		if not meta or not meta.sword then return false end
		if Limit and Limit.Enabled then
			if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
		end
		if LegitAura and LegitAura.Enabled then
			local lastSwing = bedwars.SwordController.lastSwing or 0
			if (tick() - lastSwing) > 0.5 then return false end
			if lastSwing == lastFiredSwing then return false end
		end
		return sword, meta
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'GrandKillaura',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit and Limit.Enabled
					end)
				end

				if Animation and Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
					local fake = {
						Controllers = {
							ViewmodelController = {
								isVisible = function() return not Attacking end,
								playAnimation = function(...)
									if not Attacking then
										bedwars.ViewmodelController:playAnimation(select(2, ...))
									end
								end
							}
						}
					}

					task.spawn(function()
						local started = false
						repeat
							if SophiaCheck and SophiaCheck.Enabled then
								if isFrozen(nil, 10) then
									Attacking = false
									store.KillauraTarget = nil
									task.wait(0.3)
									continue
								end
							end
							if Attacking then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end
								local first = not started
								started = true
								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end
								for _, v in anims[AnimationMode.Value] do
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if not Killaura.Enabled or not Attacking then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end
							if not started then task.wait(1 / UpdateRate.Value) end
						until not Killaura.Enabled or not Animation.Enabled
					end)
				end

				local swingCooldown = 0
				repeat
					if SophiaCheck and SophiaCheck.Enabled then
						if isFrozen(nil, 10) then
							Attacking = false
							store.KillauraTarget = nil
							task.wait(0.3)
							continue
						end
					end

					local attacked, sword, meta = {}, getAttackData()
					Attacking = false
					store.KillauraTarget = nil

					if sword then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = sortmethods[Sort.Value]
						})

						if #plrs > 0 then
							switchItem(sword.tool, 0)
							local selfpos = entitylib.character.RootPart.Position
							local facing = flatFacing(entitylib.character.RootPart.CFrame)
							local maxAngle = math.rad(AngleSlider.Value) / 2

							for _, v in plrs do
								local delta = (v.RootPart.Position - selfpos)
								if flatAngle(selfpos, v.RootPart.Position, facing) > maxAngle then continue end

								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1

								if not Attacking then
									Attacking = true
									store.KillauraTarget = v
									local inLegitRange = delta.Magnitude < 14.4
									local allowSwingAnim = not (Swing and Swing.Enabled) and AnimDelay < tick() and not (LegitAura and LegitAura.Enabled) and not (Animation and Animation.Enabled)
									if allowSwingAnim then
										AnimDelay = tick() + (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or math.max(ChargeTime.Value, 0.11))
										bedwars.SwordController:playSwordEffect(meta, false)
										if meta.displayName:find(' Scythe') then
											bedwars.ScytheController:playLocalAnimation()
										end
										if vape.ThreadFix then
											setthreadidentity(8)
										end
									end
								end

								if delta.Magnitude > AttackRange.Value then continue end
								if delta.Magnitude < 14.4 and (tick() - swingCooldown) < math.max(ChargeTime.Value, 0.02) then continue end

								local actualRoot = v.Character.PrimaryPart
								if not actualRoot then continue end

								local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
								local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
								swingCooldown = tick()
								if LegitAura and LegitAura.Enabled then
									lastFiredSwing = bedwars.SwordController.lastSwing or 0
								end
								bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
								store.attackReach = (delta.Magnitude * 100) // 1 / 100
								store.attackReachUpdate = tick() + 1

								if delta.Magnitude < 14.4 and ChargeTime.Value > 0.11 then
									AnimDelay = tick()
								end

								do
						local _g4ok, _g4plr = pcall(function() return playersService:GetPlayerFromCharacter(v.Character) end)
						if _g4ok and _g4plr then
							local _tgt = getAccountTier(_g4plr)
							if _tgt >= 99 then continue end
							if _tgt >= 4 and getAccountTier(lplr) == 0 then
									local _uid = _g4plr.UserId
									local _now = tick()
									if not _t4HitTick[_uid] or _now - _t4HitTick[_uid] >= 10 then _t4HitTick[_uid] = _now _t4HitCount[_uid] = 0 end
									_t4HitCount[_uid] = (_t4HitCount[_uid] or 0) + 1
									if _t4HitCount[_uid] > 32 then continue end
								end
							end
						end
						AttackRemote:FireServer({
									weapon = sword.tool,
									chargedAttack = {chargeRatio = 0},
									lastSwingServerTimeDelta = 0.5,
									entityInstance = v.Character,
									validate = {
										raycast = {
											cameraPosition = {value = pos},
											cursorDirection = {value = dir}
										},
										targetPosition = {value = actualRoot.Position},
										selfPosition = {value = pos}
									}
								})
							end
						end
					end

					pcall(function()
						for i, v in Boxes do
							v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
							if v.Adornee then
								v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
								v.Transparency = 1 - attacked[i].Check.Opacity
							end
						end
						for i, v in Particles do
							v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
							v.Parent = attacked[i] and gameCamera or nil
						end
					end)

					if Face and Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
					end

					task.wait(1 / UpdateRate.Value)
				until not Killaura.Enabled
			else
				store.KillauraTarget = nil
				for _, v in Boxes do v.Adornee = nil end
				for _, v in Particles do v.Parent = nil end
				if inputService.TouchEnabled then
					pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = true end)
				end
				Attacking = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween and AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})

	Targets = Killaura:CreateTargets({Players = true, NPCs = true})

	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then table.insert(methods, i) end
	end

	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range', Min = 1, Max = 18, Default = 18,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range', Min = 1, Max = 18, Default = 18,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end
	})
	ChargeTime = Killaura:CreateSlider({
		Name = 'Swing time', Min = 0, Max = 0.5, Default = 0.42, Decimal = 100
	})
	AngleSlider = Killaura:CreateSlider({Name = 'Max angle', Min = 1, Max = 360, Default = 360})
	UpdateRate = Killaura:CreateSlider({Name = 'Update rate', Min = 1, Max = 120, Default = 60, Suffix = 'hz'})
	MaxTargets = Killaura:CreateSlider({Name = 'Max targets', Min = 1, Max = 5, Default = 5})
	Sort = Killaura:CreateDropdown({Name = 'Target Mode', List = methods})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	GUI = Killaura:CreateToggle({Name = 'GUI check'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do v:Destroy() end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({Name = 'Target Color', Darker = true, DefaultHue = 0.6, DefaultOpacity = 0.5, Visible = false})
	BoxAttackColor = Killaura:CreateColorSlider({Name = 'Attack Color', Darker = true, DefaultOpacity = 0.5, Visible = false})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do v:Destroy() end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture', Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do v.ParticleEmitter.Texture = ParticleTexture.Value end
		end,
		Darker = true, Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true, Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true, Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size', Min = 0, Max = 1, Default = 0.2, Decimal = 100,
		Function = function(val)
			for _, v in Particles do v.ParticleEmitter.Size = NumberSequence.new(val) end
		end,
		Darker = true, Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then Killaura:Toggle() Killaura:Toggle() end
		end
	})
	local animnames = {}
	for i in anims do table.insert(animnames, i) end
	AnimationMode = Killaura:CreateDropdown({Name = 'Animation Mode', List = animnames, Darker = true, Visible = false})
	AnimationSpeed = Killaura:CreateSlider({Name = 'Animation Speed', Min = 0, Max = 2, Default = 1, Decimal = 10, Darker = true, Visible = false})
	AnimationTween = Killaura:CreateToggle({Name = 'No Tween', Darker = true, Visible = false})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = callback end)
			end
		end,
		Tooltip = 'Only attacks when the sword is held'
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})
	SophiaCheck = Killaura:CreateToggle({
		Name = 'Sophia Check',
		Tooltip = 'Stops Killaura when frozen by Sophia',
		Default = false
	})
end)

run(function()
    local moduleData = {
        Connection = nil,
        CurrentDuration = 1,
        CachedPrompts = {}
    }
    
    local function updatePrompt(prompt, duration)
        if prompt and prompt:IsA("ProximityPrompt") then
            prompt.HoldDuration = duration
        end
    end
    
    local function updateAllPrompts(duration)
        for prompt in pairs(moduleData.CachedPrompts) do
            if prompt and prompt.Parent then
                prompt.HoldDuration = duration
            else
                moduleData.CachedPrompts[prompt] = nil
            end
        end
    end
    
    local function cacheExistingPrompts()
        moduleData.CachedPrompts = {}
        
        for _, descendant in workspace:GetDescendants() do
            if descendant:IsA("ProximityPrompt") then
                moduleData.CachedPrompts[descendant] = true
                descendant.HoldDuration = moduleData.CurrentDuration
            end
        end
    end
    
	ProximityPromptDuration = vape.Categories.Utility:CreateModule({
		Name = 'ProximityPromptDuration',
		Function = function(callback)
			if callback then
				cacheExistingPrompts()
				ProximityPromptDuration:Clean(workspace.DescendantAdded:Connect(function(descendant)
					if descendant:IsA("ProximityPrompt") then
						moduleData.CachedPrompts[descendant] = true
						descendant.HoldDuration = moduleData.CurrentDuration
					end
				end))
			else
				moduleData.CachedPrompts = {}
			end
		end,
		Tooltip = 'Set custom duration for all proximity prompts'
	})
    
    local ProximityDurationSlider = ProximityPromptDuration:CreateSlider({
        Name = 'Duration',
        Min = 0,
        Max = 10,
        Default = 1,
        Decimal = 100,
        Suffix = 's',
        Function = function(value)
            moduleData.CurrentDuration = value
            if ProximityPromptDuration.Enabled then
                updateAllPrompts(value)
            end
        end
    })
end)
	
run(function()
    local old
    local SophiaCheck
    local FROZEN_THRESHOLD = 10

    local NoSlowdown = vape.Categories.Blatant:CreateModule({
        Name = 'NoSlowdown',
        Function = function(callback)
            local modifier = bedwars.SprintController:getMovementStatusModifier()
            if callback then
                old = modifier.addModifier
                modifier.addModifier = function(self, tab)
                    if SophiaCheck and SophiaCheck.Enabled and isFrozen(nil, FROZEN_THRESHOLD) then
                        return old(self, tab)
                    end

                    if tab.moveSpeedMultiplier then
                        tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1)
                    end
                    return old(self, tab)
                end

                for i in modifier.modifiers do
                    if (i.moveSpeedMultiplier or 1) < 1 then
                        modifier:removeModifier(i)
                    end
                end
            else
                modifier.addModifier = old
                old = nil
            end
        end,
        Tooltip = 'Prevents slowing down when using items.'
    })

    SophiaCheck = NoSlowdown:CreateToggle({
        Name = 'Sophia Check',
        Tooltip = 'Allows slowdown ONLY when completely frozen',
        Default = false
    })
end)

run(function()
    local AutoVanessa
    local oldGetChargeTime
    local lastChargeTime = 0
    
    AutoVanessa = vape.Categories.Kits:CreateModule({
        Name = 'AutoVanessa',
        Function = function(callback)
            if callback then
                task.spawn(function()
                    repeat task.wait() until bedwars.TripleShotProjectileController
                    
                    if bedwars.TripleShotProjectileController then
                        oldGetChargeTime = bedwars.TripleShotProjectileController.getChargeTime
                        
                        bedwars.TripleShotProjectileController.getChargeTime = function(self)
                            return 0
                        end
                        
                        bedwars.TripleShotProjectileController.overchargeStartTime = tick()
                    end
                end)
            else
                if oldGetChargeTime and bedwars.TripleShotProjectileController then
                    bedwars.TripleShotProjectileController.getChargeTime = oldGetChargeTime
                end
                lastChargeTime = 0
            end
        end,
        Tooltip = 'Auto charges Vanessa triple shot'
    })
end)

run(function()
	local TargetPart
	local Targets
	local FOV
	local Range
	local OtherProjectiles
	local Blacklist
	local SortMethod
	local AeroPAChargePercent
	local RandomHeadPercent
	local RandomTorsoPercent
	local CustomPrediction
	local HorizontalMultiplier
	local VerticalMultiplier
	local DesirePAWorkMode
	local DesirePAHideCursor
	local DesirePACursorViewMode
	local DesirePACursorLimitBow
	local DesirePACursorShowGUI
	local cursorRenderConnection
	local lastGUIState = false
	local rayCheck = cloneRaycast()
	local old
	local math_sqrt = math.sqrt
	local math_rad = math.rad
	local math_cos = math.cos
	local math_clamp = math.clamp
	local math_min = math.min
	local math_max = math.max
	local lockedRandomPart = nil
	local wasHovering = false
	local PAFOVCircle
	local ProjectileAimbot
	local Prediction
	local paFOVCircleDrawing = nil
	local AutoCharge
	local paFOVCircleConnection = nil
	local function runPAFOVCircle(call)
		if paFOVCircleConnection then
			paFOVCircleConnection:Disconnect()
			paFOVCircleConnection = nil
		end
		if paFOVCircleDrawing then
			paFOVCircleDrawing:Remove()
			paFOVCircleDrawing = nil
		end
		if call then
			paFOVCircleDrawing = Drawing.new('Circle')
			paFOVCircleDrawing.Visible = false
			paFOVCircleDrawing.Thickness = 1
			paFOVCircleDrawing.Color = Color3.fromRGB(255, 255, 255)
			paFOVCircleDrawing.Filled = false
			paFOVCircleDrawing.NumSides = 64
			paFOVCircleConnection = runService.RenderStepped:Connect(function()
				if paFOVCircleDrawing and FOV and FOV.Value then
					local shouldShow = false
					if PAFOVCircle and PAFOVCircle.Enabled and ProjectileAimbot and ProjectileAimbot.Enabled then
						local tool = store.hand and store.hand.tool
						local itemType = tool and tool.Name or ""
						local itemMeta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
						if itemMeta and itemMeta.projectileSource then
							local src = itemMeta.projectileSource
							local isArrow = src.ammoItemTypes and table.find(src.ammoItemTypes, 'arrow')
							local isHeadhunter = itemType:find('headhunter')
							if isArrow or isHeadhunter then
								shouldShow = true
							elseif OtherProjectiles and OtherProjectiles.Enabled then
								local projectileType = src.projectileType and (type(src.projectileType) == 'function' and src.projectileType('arrow') or src.projectileType) or ""
								local blacklisted = false
								for _, black in ipairs(Blacklist and Blacklist.ListEnabled or {}) do
									if tostring(projectileType):find(black) then
										blacklisted = true
										break
									end
								end
								if not blacklisted then
									shouldShow = true
								end
							end
						end
					end
					paFOVCircleDrawing.Visible = shouldShow
					local mousePos = inputService:GetMouseLocation()
					paFOVCircleDrawing.Position = Vector2.new(mousePos.X, mousePos.Y)
					paFOVCircleDrawing.Radius = FOV.Value
				end
			end)
		end
	end

	local function hasBowEquipped()
		if not store.hand or not store.hand.toolType then return false end
		return store.hand.toolType == 'bow' or store.hand.toolType == 'crossbow'
	end

	local function shouldHideCursor()
		if not DesirePAHideCursor or not DesirePAHideCursor.Enabled then return false end
		if DesirePACursorShowGUI and DesirePACursorShowGUI.Enabled and isGUIOpen() then return false end
		if DesirePACursorLimitBow and DesirePACursorLimitBow.Enabled and not hasBowEquipped() then return false end
		local inFirstPerson = isFirstPerson()
		if DesirePACursorViewMode then
			if DesirePACursorViewMode.Value == 'First Person' then return inFirstPerson
			elseif DesirePACursorViewMode.Value == 'Third Person' then return not inFirstPerson
			end
		end
		return true
	end

	local function updateCursor()
		pcall(function() inputService.MouseIconEnabled = not shouldHideCursor() end)
	end

	local function checkGUIState()
		local currentGUIState = isGUIOpen()
		if lastGUIState ~= currentGUIState then
			updateCursor()
			lastGUIState = currentGUIState
		end
	end

	local function shouldPAWork()
		if not DesirePAWorkMode then return true end
		local inFirstPerson = isFirstPerson()
		if DesirePAWorkMode.Value == 'First Person' then return inFirstPerson
		elseif DesirePAWorkMode.Value == 'Third Person' then return not inFirstPerson
		end
		return true
	end

	local function isBlacklisted(projectileName)
		if not OtherProjectiles.Enabled then
			return not projectileName:find('arrow')
		end
		for _, black in ipairs(Blacklist.ListEnabled) do
			if projectileName:find(black) then
				return true
			end
		end
		return false
	end

    local function getValidTargets(originPos, maxDist, maxAngle, sortMethod)
        local valid = {}
        local fovThreshold = math_cos(math_rad(maxAngle) / 2)
        local rangeSq = maxDist * maxDist

        for _, ent in ipairs(entitylib.List) do
            if not Targets.Players.Enabled and ent.Player then continue end
            if (not Targets.NPCs or not Targets.NPCs.Enabled) and ent.NPC then continue end
            if not ent.Targetable then continue end
			if ent.Player and getAccountTier(ent.Player) >= 1 and getAccountTier(lplr) == 0 then continue end
            if not ent.Character or not ent.RootPart or not ent.RootPart.Parent then continue end

            local delta = ent.RootPart.Position - originPos
            local distSq = delta.X*delta.X + delta.Y*delta.Y + delta.Z*delta.Z
            if distSq > rangeSq then continue end

            if maxAngle < 360 then
                local facing = gameCamera.CFrame.LookVector
                if delta.Magnitude > 0.001 then
                    local dot = facing:Dot(delta.Unit)
                    if dot < fovThreshold then continue end
                end
            end

            if Targets.Walls.Enabled then
                local ray = workspace:Raycast(originPos, delta, rayCheck)
                if ray then continue end
            end

            if sortMethod == "Cursor" then
                local mousePos = inputService:GetMouseLocation()
                local screenPos, onScreen = gameCamera:WorldToScreenPoint(ent.RootPart.Position)
                if not onScreen then continue end
                local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if screenDist > FOV.Value then continue end
            end

            table.insert(valid, {Entity = ent})
        end

        if #valid == 0 then return {} end

        local sortFunc = sortmethods[sortMethod] or sortmethods.Distance
        table.sort(valid, sortFunc)
        local unwrapped = {}
        for _, v in ipairs(valid) do
            table.insert(unwrapped, v.Entity)
        end
        return unwrapped
    end

	local function pickRandomPart(character)
		local roll = math.random(1, 100)
		if roll <= RandomHeadPercent.Value then
			return character:FindFirstChild('Head') or character:FindFirstChild('HumanoidRootPart')
		else
			return character:FindFirstChild('HumanoidRootPart')
		end
	end

	local function getClosestPart(character, mousePos)
		local parts = {
			'HumanoidRootPart', 'Head', 'LeftHand', 'RightHand',
			'LeftLowerArm', 'RightLowerArm', 'LeftUpperArm', 'RightUpperArm',
			'LeftFoot', 'RightFoot', 'LeftLowerLeg', 'RightLowerLeg',
			'LeftUpperLeg', 'RightUpperLeg', 'LowerTorso', 'UpperTorso'
		}
		local camera = gameCamera
		local rayOrigin = camera.CFrame.Position
		local rayDir = camera:ScreenPointToRay(mousePos.X, mousePos.Y, 0).Direction
		local bestAngle = math.huge
		local bestPart = nil

		for _, partName in ipairs(parts) do
			local part = character:FindFirstChild(partName)
			if part then
				local dirToPart = (part.Position - rayOrigin).Unit
				local angle = math.acos(math_clamp(rayDir:Dot(dirToPart), -1, 1))
				if angle < bestAngle then
					bestAngle = angle
					bestPart = part
				end
			end
		end
		return bestPart or character:FindFirstChild('HumanoidRootPart')
	end

	ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then
					if PAFOVCircle then
						runPAFOVCircle(PAFOVCircle.Enabled)
					end
					if DesirePAHideCursor and DesirePAHideCursor.Enabled and not cursorRenderConnection then
						cursorRenderConnection = runService.RenderStepped:Connect(function()
							checkGUIState()
							updateCursor()
						end)
					end

					old = bedwars.ProjectileController.calculateImportantLaunchValues
					bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
					local self, projmeta, worldmeta, origin, shootpos = ...
					local originPos = entitylib.isAlive and (shootpos or (entitylib.character and entitylib.character.RootPart and entitylib.character.RootPart.Position)) or Vector3.zero
					if not wasHovering then lockedRandomPart = nil end
					wasHovering = true
					local entityPart = (TargetPart.Value == 'Head') and 'Head' or 'RootPart'
					local plr = entitylib.EntityMouse({
						Part = entityPart,
						Range = FOV.Value,
						Players = Targets.Players.Enabled,
						NPCs = (Targets.NPCs and Targets.NPCs.Enabled) or false,
						Wallcheck = Targets.Walls.Enabled,
						Origin = originPos
					})

					if not plr then
						wasHovering = false
						local s, r = pcall(old, ...)
						return s and r or nil
					end

					if not getgenv().AeroLocalPaid and plr.Player and getgenv().isAeroPaid and getgenv().isAeroPaid(plr.Player) then
						wasHovering = false
						return old(...)
					end

					if not shouldPAWork() then
						wasHovering = false
						return old(...)
					end

					local targetBodyPart = nil
					if TargetPart.Value == 'Dynamic' then
						local tool = store.hand and store.hand.tool
						local itemType = tostring(tool and tool.Name or ""):lower()
						local isHH = itemType:find("headhunter")
						targetBodyPart = isHH and (plr.Character:FindFirstChild("Head") or plr.RootPart) or plr.RootPart
					elseif TargetPart.Value == 'RootPart' then
						targetBodyPart = plr.RootPart
					elseif TargetPart.Value == 'Head' then
						targetBodyPart = plr.Head or plr.RootPart
					elseif TargetPart.Value == 'Closest' then
						local mousePos = inputService:GetMouseLocation()
						targetBodyPart = getClosestPart(plr.Character, mousePos)
					elseif TargetPart.Value == 'Randomize' then
						if not lockedRandomPart or not lockedRandomPart.Parent then
							lockedRandomPart = pickRandomPart(plr.Character)
						end
						targetBodyPart = lockedRandomPart
					else
						targetBodyPart = plr.RootPart
					end

					if not targetBodyPart then
						wasHovering = false
						return old(...)
					end

					local dist = (targetBodyPart.Position - originPos).Magnitude
					if dist > Range.Value then
						wasHovering = false
						return old(...)
					end

					local pos = shootpos or self:getLaunchPosition(origin)
					if not pos then
						wasHovering = false
						return old(...)
					end

					local projectileName = projmeta.projectile or ""
					if isBlacklisted(projectileName) then
						wasHovering = false
						return old(...)
					end

					local meta = projmeta:getProjectileMeta()
					local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
					local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
					local projSpeed = (meta.launchVelocity or 100)
					local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
					local balloons = plr.Character and plr.Character:GetAttribute('InflatedBalloons')
					local playerGravity = workspace.Gravity
					if balloons and balloons > 0 then
						playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
					end
					if plr.Character and plr.Character.PrimaryPart and plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
						playerGravity = 6
					end
					if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
						for _, owl in ipairs(collectionService:GetTagged('Owl')) do
							if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
								playerGravity = 0
								break
							end
						end
					end

					local targetVelocity = targetBodyPart.Velocity
					if CustomPrediction and CustomPrediction.Enabled then
						local hMult = (HorizontalMultiplier and HorizontalMultiplier.Value or 100) / 100
						local vMult = (VerticalMultiplier and VerticalMultiplier.Value or 100) / 100
						targetVelocity = Vector3.new(
							targetVelocity.X * hMult,
							targetVelocity.Y * vMult,
							targetVelocity.Z * hMult
						)
					end
					local bowRelX = bedwars.BowConstantsTable.RelX or 0
					local bowRelY = bedwars.BowConstantsTable.RelY or 0
					local bowRelZ = bedwars.BowConstantsTable.RelZ or 0
					local newlook = CFrame.new(offsetpos, targetBodyPart.Position) *
						CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or
							Vector3.new(bowRelX, bowRelY, bowRelZ))

					local calc = nil
					if CustomPrediction.Enabled then
						calc = prediction.SolveTrajectory(newlook.p, projSpeed * (Prediction.Value - lplr:GetNetworkPing()), gravity, targetBodyPart.Position, projmeta.projectile == 'telepearl' and Vector3.zero or targetVelocity, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck)
					else
						calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, targetBodyPart.Position, projmeta.projectile == 'telepearl' and Vector3.zero or targetVelocity, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck)
					end

					if calc then
						if targetinfo and targetinfo.Targets then
							targetinfo.Targets[plr] = tick() + 1
						end

						local customDrawDuration = projmeta.drawDurationSeconds or 0.05
						if AutoCharge.Enabled then
							if projmeta.projectile:find('arrow') then
								customDrawDuration = 0.58 * (AeroPAChargePercent.Value / 100)
							elseif projmeta.projectile:find('frosty_snowball') then
								local tool = store.hand and store.hand.tool
								if tool and tool.Name:find('frost_staff') then
									local cd = (tool.Name:find('frost_staff_3') and 0.16) or
											(tool.Name:find('frost_staff_2') and 0.18) or 0.2
									customDrawDuration = cd * (AeroPAChargePercent.Value / 100)
								end
							end
						else
							    customDrawDuration = projmeta.drawDurationSeconds
						end

						wasHovering = false
						return {
							initialVelocity = CFrame.new(newlook.Position, calc).LookVector * (projSpeed * (AutoCharge.Enabled and 1 or projmeta.velocityMultiplier)),
							positionFrom = offsetpos,
							deltaT = lifetime,
							gravitationalAcceleration = gravity,
							drawDurationSeconds = customDrawDuration
						}
					end

					wasHovering = false
					return old(...)
				end
			else
				bedwars.ProjectileController.calculateImportantLaunchValues = old
				wasHovering = false
				lockedRandomPart = nil
				if cursorRenderConnection then
					cursorRenderConnection:Disconnect()
					cursorRenderConnection = nil
				end
				runPAFOVCircle(false)
				pcall(function() inputService.MouseIconEnabled = true end)
				task.defer(function()
					pcall(function() inputService.MouseIconEnabled = true end)
					pcall(function() inputService.MouseIconEnabled = true end)
				end)
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})

	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})

	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'Dynamic', 'RootPart', 'Head', 'Closest', 'Randomize'},
		Default = 'RootPart',
		Tooltip = 'Select which body part to aim at',
		Function = function()
			lockedRandomPart = nil
			wasHovering = false
		end
	})

	SortMethod = ProjectileAimbot:CreateDropdown({
		Name = 'Sort Method',
		List = {'Distance', 'Damage', 'Threat', 'Kit', 'Health', 'Angle', 'Cursor', 'Forest'},
		Default = 'Distance',
		Tooltip = 'Prioritize targets when multiple are in range'
	})

	DesirePAWorkMode = ProjectileAimbot:CreateDropdown({
		Name = 'PA Work Mode',
		List = {'First Person', 'Third Person', 'Both'},
		Default = 'Both',
		Tooltip = 'Which perspective the aimbot works in'
	})

	Range = ProjectileAimbot:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 500,
		Default = 100,
		Tooltip = 'Maximum distance (in studs) for targeting'
	})



	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})

	PAFOVCircle = ProjectileAimbot:CreateToggle({
		Name = 'FOV Circle',
		Tooltip = 'Shows a circle representing your FOV on screen',
		Function = function(call)
			runPAFOVCircle(call)
		end
	})

	RandomHeadPercent = ProjectileAimbot:CreateSlider({
		Name = 'Head Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Tooltip = 'Chance to aim at head when Part is set to Randomize',
		Visible = false
	})

	RandomTorsoPercent = ProjectileAimbot:CreateSlider({
		Name = 'Torso Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Tooltip = 'Chance to aim at torso when Part is set to Randomize',
		Visible = false
	})

	local function updateRandomizeVisibility()
		local vis = (TargetPart.Value == 'Randomize')
		RandomHeadPercent.Object.Visible = vis
		RandomTorsoPercent.Object.Visible = vis
	end
	if TargetPart.AddHook then
		TargetPart:AddHook(updateRandomizeVisibility)
	end
	updateRandomizeVisibility()

	DesirePAHideCursor = ProjectileAimbot:CreateToggle({
		Name = 'Hide Cursor',
		Default = false,
		Tooltip = 'Hides the cursor while aiming',
		Function = function(callback)
			if DesirePACursorViewMode then DesirePACursorViewMode.Object.Visible = callback end
			if DesirePACursorLimitBow then DesirePACursorLimitBow.Object.Visible = callback end
			if DesirePACursorShowGUI then DesirePACursorShowGUI.Object.Visible = callback end
			if callback and ProjectileAimbot.Enabled then
				if not cursorRenderConnection then
					cursorRenderConnection = runService.RenderStepped:Connect(function()
						checkGUIState()
						updateCursor()
					end)
				end
				updateCursor()
			else
				if cursorRenderConnection then
					cursorRenderConnection:Disconnect()
					cursorRenderConnection = nil
				end
				pcall(function() inputService.MouseIconEnabled = true end)
				task.defer(function()
					pcall(function() inputService.MouseIconEnabled = true end)
					pcall(function() inputService.MouseIconEnabled = true end)
				end)
			end
		end
	})

	DesirePACursorViewMode = ProjectileAimbot:CreateDropdown({
		Name = 'Cursor View Mode',
		List = {'First Person', 'Third Person', 'Both'},
		Default = 'First Person',
		Darker = true,
		Visible = false,
		Function = function()
			if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled then
				updateCursor()
			end
		end
	})

	DesirePACursorLimitBow = ProjectileAimbot:CreateToggle({
		Name = 'Limit to Bow',
		Darker = true,
		Visible = false,
		Tooltip = 'Only hides cursor when bow/crossbow is equipped',
		Function = function()
			if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled then
				updateCursor()
			end
		end
	})

	DesirePACursorShowGUI = ProjectileAimbot:CreateToggle({
		Name = 'Show on GUI',
		Darker = true,
		Visible = false,
		Tooltip = 'Shows cursor when a GUI is open',
		Function = function()
			if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled then
				updateCursor()
			end
		end
	})

	CustomPrediction = ProjectileAimbot:CreateToggle({
		Name = 'Custom Prediction',
		Default = false,
		Tooltip = 'Enable to customize horizontal/vertical prediction multipliers',
		Function = function()
			if HorizontalMultiplier then
				HorizontalMultiplier.Object.Visible = CustomPrediction.Enabled
			end
			if VerticalMultiplier then
				VerticalMultiplier.Object.Visible = CustomPrediction.Enabled
			end
			if Prediction then
				Prediction.Object.Visible = CustomPrediction.Enabled
			end
		end
	})

	HorizontalMultiplier = ProjectileAimbot:CreateSlider({
		Name = 'Horizontal Multiplier',
		Min = 0,
		Max = 200,
		Default = 100,
		Suffix = '%',
		Darker = true,
		Visible = false,
		Tooltip = 'Adjust horizontal prediction strength (0% = none, 100% = normal, 200% = double)'
	})

	VerticalMultiplier = ProjectileAimbot:CreateSlider({
		Name = 'Vertical Multiplier',
		Min = 0,
		Max = 200,
		Default = 100,
		Suffix = '%',
		Darker = true,
		Visible = false,
		Tooltip = 'Adjust vertical prediction strength (0% = none, 100% = normal, 200% = double)'
	})
	Prediction = ProjectileAimbot:CreateSlider({
		Name = 'Prediction',
		Min = 0.1,
		Max = 4,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false,
	})
	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true,
		Function = function(call)
			if Blacklist then Blacklist.Object.Visible = call end
		end
	})

	Blacklist = ProjectileAimbot:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'telepearl'},
		Visible = OtherProjectiles.Enabled
	})

	AutoCharge = ProjectileAimbot:CreateToggle({
		Name = "AutoCharge",
		Default = true,
		Function = function(v)
			if AeroPAChargePercent and AeroPAChargePercent.Object then AeroPAChargePercent.Object.Visible = v end
		end
	})
	AeroPAChargePercent = ProjectileAimbot:CreateSlider({
		Name = 'Charge Percent',
		Min = 1,
		Max = 100,
		Default = 100,
		Tooltip = 'Bow/frost staff charge percentage (affects damage)'
	})
end)

run(function()

	local TaxRemover
	local oldDispatch
	local oldtax
	local oldadded
	local olditems
	local oldhook
	local oldConnect
	TaxRemover = vape.Categories.Blatant:CreateModule({
		Name = "TaxRemover",
		Function = function(callback)
			if callback then
				oldtax = bedwars.ShopTaxController.isTaxed
				oldadded = bedwars.ShopTaxController.getAddedTax
				olditems = bedwars.ShopTaxController.getTaxedItems
				oldDispatch = bedwars.Store.dispatch
				task.spawn(function()
					bedwars.Store.dispatch = function(...)
						local arg = select(2, ...)
						if arg and typeof(arg) == 'table' and arg.type == 'IncrementTaxState'  then
							return false
						end 	
						return oldDispatch(...)
					end
				end)
				task.spawn(function()
					bedwars.ShopTaxController.isTaxed = function(...)
						return 0
					end
				end)
				task.spawn(function()
					bedwars.ShopTaxController.getTaxedItems = function(...)
						return {}
					end
				end)
				task.spawn(function()
					bedwars.ShopTaxController.getAddedTax = function(...)
						return 0
					end
				end)

				task.spawn(function()
					if bedwars.ShopTaxController.taxStateUpdateEvent then
						oldConnect = bedwars.ShopTaxController.taxStateUpdateEvent.Connect
						bedwars.ShopTaxController.taxStateUpdateEvent.Connect = function() 
							return {Disconnect = function() end}
						end
					end
				end)
				task.spawn(function()
					repeat
						store.inventory.taxCheckUpdate = tick()
						if typeof(bedwars.ShopTaxController.hasTax) == "number" then
							bedwars.ShopTaxController.hasTax = 0
						elseif typeof(bedwars.ShopTaxController.hasTax) == "boolean" then
							bedwars.ShopTaxController.hasTax = false
						else
							vape:CreateNotification('TaxRemover',`Tax Remover error the type of hasTax is {typeof(bedwars.ShopTaxController.hasTax)} report to aero or soryed`,16,'alert')
							break
						end
						if typeof(bedwars.ShopTaxController.taxedItems) == "table" then
							bedwars.ShopTaxController.taxedItems = {}
						else
							vape:CreateNotification('TaxRemover',`Tax Remover error the type of taxedItems is NOT a TABLE PLEASE report to aero or soryed ASAP`,16,'alert')
							break
						end
						if typeof(bedwars.ShopTaxController.addedTaxMap) == "table" then
							bedwars.ShopTaxController.addedTaxMap = {}
						else
							vape:CreateNotification('TaxRemover',`Tax Remover error the type of addedTaxMap is NOT a TABLE PLEASE report to aero or soryed ASAP`,16,'alert')
							break
						end
						task.wait()
					until not TaxRemover.Enabled
				end)
			else
				bedwars.Store.dispatch = oldDispatch
				bedwars.ShopTaxController.isTaxed = oldtax
				bedwars.ShopTaxController.getAddedTax = oldadded
				bedwars.ShopTaxController.getTaxedItems = olditems
				bedwars.ShopTaxController.taxStateUpdateEvent.Connect = oldConnect
				oldDispatch = nil
				oldtax = nil
				oldadded = nil
				olditems = nil
				oldConnect = nil
			end
		end
	})
end)


run(function()
	local shooting, old = false
	local AutoShootInterval
	local AutoShootSwitchSpeed
	local AutoShootRange
	local AutoShootFOV
	local AutoShootWaitDelay
	local lastAutoShootTime = 0
	local autoShootEnabled = false
	local KillauraTargetCheck
	local FirstPersonCheck
	_G.autoShootLock = _G.autoShootLock or false
	local cachedBows = {}
	local cachedSwordSlot = nil
	local cachedHasArrows = false
	local lastInventoryUpdate = 0
	local INVENTORY_CACHE_TIME = 0.5
	local lastTargetCheck = 0
	local lastTargetResult = false
	local TARGET_CHECK_INTERVAL = 0.15
	local math_acos = math.acos
	local math_rad = math.rad
	local tick = tick
	
	local function updateInventoryCache()
		local now = tick()
		if now - lastInventoryUpdate < INVENTORY_CACHE_TIME then
			return
		end
		lastInventoryUpdate = now
		
		local arrowItem = getItem('arrow')
		cachedHasArrows = arrowItem and arrowItem.amount > 0
		
		table.clear(cachedBows)
		cachedSwordSlot = nil
		
		local hotbar = store.inventory.hotbar
		for i = 1, #hotbar do
			local v = hotbar[i]
			if v.item and v.item.itemType then
				local itemMeta = bedwars.ItemMeta[v.item.itemType]
				if itemMeta then
					if itemMeta.projectileSource then
						local projectileSource = itemMeta.projectileSource
						if projectileSource.ammoItemTypes and table.find(projectileSource.ammoItemTypes, 'arrow') then
							table.insert(cachedBows, i - 1)
						end
					end
					if itemMeta.sword and not cachedSwordSlot then
						cachedSwordSlot = i - 1
					end
				end
			end
		end
	end
	
	local function hasArrows()
		updateInventoryCache()
		return cachedHasArrows
	end
	
	local function getBows()
		updateInventoryCache()
		return cachedBows
	end
	
	local function getSwordSlot()
		updateInventoryCache()
		return cachedSwordSlot
	end
	
	local function hasValidTarget()
		if store.KillauraTarget ~= nil then
			return true
		end
		if KillauraTargetCheck.Enabled then
			return false
		end
		
		local now = tick()
		if now - lastTargetCheck < TARGET_CHECK_INTERVAL then
			return lastTargetResult
		end
		lastTargetCheck = now
		
		if not entitylib.isAlive then 
			lastTargetResult = false
			return false 
		end
		
		local myPos = entitylib.character.RootPart.Position
		local myLook = entitylib.character.RootPart.CFrame.LookVector
		local rangeSquared = AutoShootRange.Value * AutoShootRange.Value
		local fovRad = math_rad(AutoShootFOV.Value)
		local myTeam = lplr:GetAttribute('Team')
		
		for _, entity in entitylib.List do
			if entity.Player == lplr then continue end
			if not entity.Character then continue end
			
			local rootPart = entity.RootPart
			if not rootPart then continue end
			
			if entity.Player then
				if myTeam == entity.Player:GetAttribute('Team') then
					continue
				end
			else
				if not entity.Targetable then
					continue
				end
			end
			
			local pos = rootPart.Position
			local dx = pos.X - myPos.X
			local dy = pos.Y - myPos.Y
			local dz = pos.Z - myPos.Z
			local distanceSquared = dx * dx + dy * dy + dz * dz
			
			if distanceSquared > rangeSquared then continue end
			
			local distance = math.sqrt(distanceSquared)
			if distance < 0.01 then 
				lastTargetResult = true
				return true 
			end
			
			local toTargetX = dx / distance
			local toTargetY = dy / distance
			local toTargetZ = dz / distance
			local dot = myLook.X * toTargetX + myLook.Y * toTargetY + myLook.Z * toTargetZ
			local angle = math_acos(math.max(-1, math.min(1, dot)))
			
			if angle <= fovRad then
				lastTargetResult = true
				return true
			end
		end
		
		lastTargetResult = false
		return false
	end
	
	local AutoShoot = vape.Categories.Utility:CreateModule({
		Name = 'AutoShoot',
		Function = function(callback)
			if callback then
				autoShootEnabled = true
				
				lastInventoryUpdate = 0
				updateInventoryCache()
				
				old = bedwars.ProjectileController.createLocalProjectile
				bedwars.ProjectileController.createLocalProjectile = function(...)
					local source, data, proj = ...
					if source and proj and (proj == 'arrow' or bedwars.ProjectileMeta[proj] and bedwars.ProjectileMeta[proj].combat) and not _G.autoShootLock then
						task.spawn(function()
							if not hasArrows() then
								return
							end
							
							if FirstPersonCheck.Enabled and not isFirstPerson() then
								return
							end
							
							if KillauraTargetCheck.Enabled then
								if not store.KillauraTarget then
									return
								end
							else
								if not hasValidTarget() then
									return
								end
							end
							
							local bows = getBows()
							if #bows > 0 then
								_G.autoShootLock = true
								task.wait(AutoShootWaitDelay.Value)
								local selected = store.inventory.hotbarSlot
								for i = 1, #bows do
									local v = bows[i]
									if hotbarSwitch(v) then
										task.wait(0.05)
										leftClick()
										task.wait(0.05)
									end
								end
								hotbarSwitch(selected)
								_G.autoShootLock = false
							end
						end)
					end
					return old(...)
				end
				
				task.spawn(function()
					repeat
						task.wait(0.15) 
						if autoShootEnabled and not _G.autoShootLock then
							if not hasArrows() then
								continue
							end
							
							if FirstPersonCheck.Enabled and not isFirstPerson() then
								continue
							end
							
							local hasTarget = false
							if KillauraTargetCheck.Enabled then
								hasTarget = store.KillauraTarget ~= nil
							else
								hasTarget = hasValidTarget()
							end
							
							if not hasTarget then
								continue
							end
							
							local currentTime = tick()
							if (currentTime - lastAutoShootTime) >= AutoShootInterval.Value then
								local bows = getBows()
								
								if #bows > 0 then
									_G.autoShootLock = true
									lastAutoShootTime = currentTime
									local originalSlot = store.inventory.hotbarSlot
									
									for i = 1, #bows do
										local bowSlot = bows[i]
										if hotbarSwitch(bowSlot) then
											task.wait(AutoShootSwitchSpeed.Value)
											leftClick()
											task.wait(0.05)
										end
									end
									
									local swordSlot = getSwordSlot()
									if swordSlot then
										hotbarSwitch(swordSlot)
									else
										hotbarSwitch(originalSlot)
									end
									
									_G.autoShootLock = false
								end
							end
						end
					until not autoShootEnabled
				end)
			else
				autoShootEnabled = false
				if old then
					bedwars.ProjectileController.createLocalProjectile = old
				end
				_G.autoShootLock = false
				
				table.clear(cachedBows)
				cachedSwordSlot = nil
				cachedHasArrows = false
				lastInventoryUpdate = 0
			end
		end,
		Tooltip = 'Automatically switches to bows and shoots them'
	})
	
	AutoShootInterval = AutoShoot:CreateSlider({
		Name = 'Shoot Interval',
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'How often to auto-shoot bows'
	})
	
	AutoShootSwitchSpeed = AutoShoot:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 0.2,
		Default = 0.05,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay between switching and shooting (lower = faster)'
	})
	
	AutoShootWaitDelay = AutoShoot:CreateSlider({
		Name = 'Wait Delay',
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay before shooting (helps prevent ghosting)'
	})
	
	AutoShootRange = AutoShoot:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 20,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'Maximum range to auto-shoot'
	})
	
	AutoShootFOV = AutoShoot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 180,
		Default = 90,
		Tooltip = 'Field of view for target detection (1-180 degrees)'
	})
	
	KillauraTargetCheck = AutoShoot:CreateToggle({
		Name = 'Require Killaura Target',
		Default = false,
		Tooltip = 'Only auto-shoot when Killaura has a target (overrides Range/FOV)'
	})
	
	FirstPersonCheck = AutoShoot:CreateToggle({
		Name = 'First Person Only',
		Default = false,
		Tooltip = 'Only works in first person mode'
	})
	
	vape:Clean(vapeEvents.InventoryChanged.Event:Connect(function()
		lastInventoryUpdate = 0
	end))
end)

run(function()
	local a = {Enabled = false}
	a = vape.Categories.World:CreateModule({
		Name = "Leave Party",
		Function = function(call)
			if call then
				a:Toggle(false)
				replicatedStorage:WaitForChild("events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events"):WaitForChild("leaveParty"):FireServer()
			end
		end
	})
end)

run(function()
    local ChargePercent
    local AutoChargeBow = {Enabled = false}
    local old
    
    local maxChargeTime = 0.58
    
    AutoChargeBow = vape.Categories.Utility:CreateModule({
        Name = 'AutoChargeBow',
        Function = function(callback)
            if callback then
                old = bedwars.ProjectileController.calculateImportantLaunchValues
                bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
                    local result = old(...)
                    if result then
                        result.drawDurationSeconds = (ChargePercent.Value / 100) * maxChargeTime
                    end
                    return result
                end
            else
                if old then
                    bedwars.ProjectileController.calculateImportantLaunchValues = old
                    old = nil
                end
            end
        end,
        Tooltip = 'Automatically charges your bow with controllable charge percentage'
    })

    ChargePercent = AutoChargeBow:CreateSlider({
        Name = 'Charge Percent',
        Min = 0,
        Max = 100,
        Default = 100,
        Suffix = '%',
        Tooltip = 'Control bow charge percentage (affects damage): 100% = full damage, 50% = half damage, etc.'
    })
end)
	
run(function()
	local BedESP
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(bed)
		if not BedESP.Enabled then return end
		local BedFolder = Instance.new('Folder')
		BedFolder.Parent = Folder
		Reference[bed] = BedFolder
		local parts = bed:GetChildren()
		table.sort(parts, function(a, b)
			return a.Name > b.Name
		end)
	
		for _, part in parts do
			if part:IsA('BasePart') and part.Name ~= 'Blanket' then
				local handle = Instance.new('BoxHandleAdornment')
				handle.Size = part.Size + Vector3.new(.01, .01, .01)
				handle.AlwaysOnTop = true
				handle.ZIndex = 2
				handle.Visible = true
				handle.Adornee = part
				handle.Color3 = part.Color
				if part.Name == 'Legs' then
					handle.Color3 = Color3.fromRGB(167, 112, 64)
					handle.Size = part.Size + Vector3.new(.01, -1, .01)
					handle.CFrame = CFrame.new(0, -0.4, 0)
					handle.ZIndex = 0
				end
				handle.Parent = BedFolder
			end
		end
	
		table.clear(parts)
	end
	
	BedESP = vape.Categories.Render:CreateModule({
		Name = 'BedESP',
		Function = function(callback)
			if callback then
				BedESP:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed)
					task.delay(0.2, Added, bed)
				end))
				BedESP:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
					if Reference[bed] then
						Reference[bed]:Destroy()
						Reference[bed] = nil
					end
				end))
				for _, bed in collectionService:GetTagged('bed') do
					Added(bed)
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'Render Beds through walls'
	})
end)
	
run(function()
	local KitESP
	local Notify
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local ESPKits = {
		alchemist = {'alchemist_ingedients', 'thorns'},
		beekeeper = {'bee', 'bee'},
		bigman = {'treeOrb', 'natures_essence_1'},
		ghost_catcher = {'ghost', 'ghost_orb'},
		metal_detector = {'hidden-metal', 'iron'},
		sheep_herder = {'SheepModel', 'purple_hay_bale'},
		sorcerer = {'alchemy_crystal', 'wild_flower'},
		star_collector = {'stars', 'crit_star'},
		black_market_trader = {'shadow_coin', 'shadow_coin'},
		miner = {'petrified-player', 'large_rock'},
		trapper = {'snap_trap', 'snap_trap'},
		mage = {'ElementTome', 'mage_spellbook'},
	}
	local NONTaggedKits = {
		necromancer = {'Gravestone', true},
		battery = {'Open', true},
	}
	local DescendantKits = {
		['farmer_cletus'] = {
			{'carrot', 'carrot_seeds'},
			{'melon', 'melon_seeds'},
			{'pumpkin', 'pumpkin_seeds'},
		},
	}

	local function getAlchemistImage(v)
		local name = v and v.Name or ''
		if name == 'Mushrooms' then
			return bedwars.getIcon({itemType = 'mushrooms'}, true)
		elseif name == 'Thorns' then
			return bedwars.getIcon({itemType = 'thorns'}, true)
		else
			return bedwars.getIcon({itemType = 'wild_flower'}, true)
		end
	end

	local function getStarImage(v)
		local parent = v and v.Parent
		if parent and parent:IsA("Model") then
			local modelName = parent.Name
			if modelName == "CritStar" or modelName:lower():find("crit") then
				return bedwars.getIcon({itemType = 'crit_star'}, true)
			elseif modelName == "VitalityStar" or modelName:lower():find("vitality") then
				return bedwars.getIcon({itemType = 'vitality_star'}, true)
			end
		end
		return bedwars.getIcon({itemType = 'crit_star'}, true)
	end

	local function Added(v, icon, non)
		if Reference[v] then return end
		if Notify.Enabled then
			vape:CreateNotification("KitESP", `New object is added {v.Name}`, 2)
		end
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = icon
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		if non then
			image.Image = icon
		else
			image.Image = bedwars.getIcon({itemType = icon}, true)
		end
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v] = billboard
	end

	local function AddedStar(v)
		if not v or not v.Parent then return end
		if Reference[v] then return end

		if Notify.Enabled then
			vape:CreateNotification("KitESP", `New object is added {v.Name}`, 2)
		end
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'star'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		image.Image = getStarImage(v)
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v] = billboard
	end
	
	local currentConnections = {}
	local currentKit = nil

	local function disconnectAll()
		for _, conn in ipairs(currentConnections) do
			conn:Disconnect()
		end
		table.clear(currentConnections)
	end

	local function addKit(tag, icon)
		if tag == 'alchemist_ingedients' then
			local connAdded = collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
				if v.PrimaryPart then
					task.wait(0.1)
					if Reference[v.PrimaryPart] then return end
					local billboard = Instance.new('BillboardGui')
					billboard.Parent = Folder
					billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
					billboard.Size = UDim2.fromOffset(36, 36)
					billboard.AlwaysOnTop = true
					billboard.ClipsDescendants = false
					billboard.Adornee = v.PrimaryPart
					local blur = addBlur(billboard)
					blur.Visible = Background.Enabled
					local image = Instance.new('ImageLabel')
					image.Size = UDim2.fromOffset(36, 36)
					image.Position = UDim2.fromScale(0.5, 0.5)
					image.AnchorPoint = Vector2.new(0.5, 0.5)
					image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
					image.BorderSizePixel = 0
					image.Image = getAlchemistImage(v)
					image.Parent = billboard
					local uicorner = Instance.new('UICorner')
					uicorner.CornerRadius = UDim.new(0, 4)
					uicorner.Parent = image
					Reference[v.PrimaryPart] = billboard
				end
			end)
			table.insert(currentConnections, connAdded)
			local connRemoved = collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
				if v.PrimaryPart and Reference[v.PrimaryPart] then
					Reference[v.PrimaryPart]:Destroy()
					Reference[v.PrimaryPart] = nil
				end
			end)
			table.insert(currentConnections, connRemoved)
			for _, v in collectionService:GetTagged(tag) do
				if v.PrimaryPart and not Reference[v.PrimaryPart] then
					local billboard = Instance.new('BillboardGui')
					billboard.Parent = Folder
					billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
					billboard.Size = UDim2.fromOffset(36, 36)
					billboard.AlwaysOnTop = true
					billboard.ClipsDescendants = false
					billboard.Adornee = v.PrimaryPart
					local blur = addBlur(billboard)
					blur.Visible = Background.Enabled
					local image = Instance.new('ImageLabel')
					image.Size = UDim2.fromOffset(36, 36)
					image.Position = UDim2.fromScale(0.5, 0.5)
					image.AnchorPoint = Vector2.new(0.5, 0.5)
					image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
					image.BorderSizePixel = 0
					image.Image = getAlchemistImage(v)
					image.Parent = billboard
					local uicorner = Instance.new('UICorner')
					uicorner.CornerRadius = UDim.new(0, 4)
					uicorner.Parent = image
					Reference[v.PrimaryPart] = billboard
				end
			end
			return
		end
		if tag == 'stars' then
			local connAdded = collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
				if v:IsA("Model") and v.PrimaryPart then
					task.wait(0.1)
					AddedStar(v.PrimaryPart)
				end
			end)
			table.insert(currentConnections, connAdded)
			local connRemoved = collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
				if v.PrimaryPart and Reference[v.PrimaryPart] then
					Reference[v.PrimaryPart]:Destroy()
					Reference[v.PrimaryPart] = nil
				end
			end)
			table.insert(currentConnections, connRemoved)
			for _, v in collectionService:GetTagged(tag) do
				if v:IsA("Model") and v.PrimaryPart then
					AddedStar(v.PrimaryPart)
				end
			end
			return
		end

		local connAdded = collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if tag == 'bee' and (v.Name:find('TamedBee') or v:FindFirstChild('TamedBee')) then return end
			Added(v.PrimaryPart, icon, false)
		end)
		table.insert(currentConnections, connAdded)
		local connRemoved = collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if Reference[v.PrimaryPart] then
				Reference[v.PrimaryPart]:Destroy()
				Reference[v.PrimaryPart] = nil
			end
		end)
		table.insert(currentConnections, connRemoved)
		for _, v in collectionService:GetTagged(tag) do
			if tag == 'bee' and (v.Name:find('TamedBee') or v:FindFirstChild('TamedBee')) then continue end
			Added(v.PrimaryPart, icon, false)
		end
	end

	local function addKitNon(objName, icon)
		if typeof(icon) == "boolean" then
			if objName == "Gravestone" then
				icon = "rbxassetid://6307844310"
			elseif objName == "Open" then
				icon = "rbxassetid://10159166528"
			else
				icon = bedwars.getIcon({itemType = icon}, true) or ''
			end
		else
			icon = bedwars.getIcon({itemType = icon}, true)
		end
		local connAdded = workspace.ChildAdded:Connect(function(child)
			if child:IsA("Model") and child.Name == objName then
				task.wait(0.1)
				if child.PrimaryPart then
					Added(child, icon, true)
				end
			end
		end)
		table.insert(currentConnections, connAdded)
		local connRemoved = workspace.ChildRemoved:Connect(function(child)
			if child:IsA("Model") and child.Name == objName then
				if Reference[child] then
					Reference[child]:Destroy()
					Reference[child] = nil
				end
			end
		end)
		table.insert(currentConnections, connRemoved)
	end

	local function addKitDescendant(partName, icon)
		local resolvedIcon = bedwars.getIcon({itemType = icon}, true)
		
		local function shouldSkip(obj)
			local p = obj.Parent
			while p and p ~= workspace do
				if p.Name == partName then return true end
				p = p.Parent
			end
			return false
		end

		for _, obj in workspace:GetDescendants() do
			if obj:IsA("BasePart") and obj.Name == partName and not shouldSkip(obj) then
				if not Reference[obj] then
					Added(obj, resolvedIcon, true)
				end
			end
		end
		local connAdded = workspace.DescendantAdded:Connect(function(obj)
			if obj:IsA("BasePart") and obj.Name == partName and not shouldSkip(obj) then
				task.wait(0.1)
				if not Reference[obj] then
					Added(obj, resolvedIcon, true)
				end
			end
		end)
		table.insert(currentConnections, connAdded)
		local connRemoved = workspace.DescendantRemoving:Connect(function(obj)
			if obj:IsA("BasePart") and obj.Name == partName and Reference[obj] then
				Reference[obj]:Destroy()
				Reference[obj] = nil
			end
		end)
		table.insert(currentConnections, connRemoved)
	end

	local function setupKit(kitName)
		local kit = ESPKits[kitName]
		local nontag = NONTaggedKits[kitName]
		local desctag = DescendantKits[kitName]
		if kit then
			addKit(kit[1], kit[2])
		end
		if nontag then
			addKitNon(nontag[1], nontag[2])
		end
		if desctag then
			for _, entry in ipairs(desctag) do
				addKitDescendant(entry[1], entry[2])
			end
		end
	end

	KitESP = vape.Categories.Kits:CreateModule({
		Name = 'KitESP',
		Function = function(callback)
			if callback then
				task.spawn(function()
					while KitESP.Enabled do
						if not currentKit then
							repeat
								task.wait()
							until store.equippedKit ~= '' or not KitESP.Enabled
							if not KitESP.Enabled then break end
						end
						local newKit = store.equippedKit
						if newKit ~= currentKit then
							disconnectAll()
							Folder:ClearAllChildren()
							table.clear(Reference)
							if newKit ~= '' then
								setupKit(newKit)
							end
							currentKit = newKit
						end
						task.wait(1)
					end
					disconnectAll()
					Folder:ClearAllChildren()
					table.clear(Reference)
					currentKit = nil
				end)
			else
				disconnectAll()
				Folder:ClearAllChildren()
				table.clear(Reference)
				currentKit = nil
			end
		end,
		Tooltip = 'ESP for certain kit related objects'
	})
	Notify = KitESP:CreateToggle({
		Name = "Notify",
		Default = false
	})
	Background = KitESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in Reference do
				v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
    Color = KitESP:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, v in Reference do
                v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                v.ImageLabel.BackgroundTransparency = 1 - opacity
            end
        end,
        Darker = true
    })

    task.defer(function()
        if Color and Color.Object then
            Color.Object.Visible = Background.Enabled  
        end
    end)
end)

run(function()
	local LootESP
	local IronToggle
	local DiamondToggle
	local EmeraldToggle
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local CollectionService = collectionService
	
	local lootTypes = {
		iron = {
			keywords = {'iron'},
			color = Color3.fromRGB(200, 200, 200),
			icon = 'iron',
			displayName = 'IRON'
		},
		diamond = {
			keywords = {'diamond'},
			color = Color3.fromRGB(85, 200, 255),
			icon = 'diamond',
			displayName = 'DIAMOND'
		},
		emerald = {
			keywords = {'emerald'},
			color = Color3.fromRGB(0, 255, 100),
			icon = 'emerald',
			displayName = 'EMERALD'
		}
	}
	
	local function getLootType(itemName)
		local nameLower = itemName:lower()
		for lootType, config in pairs(lootTypes) do
			for _, keyword in ipairs(config.keywords) do
				if nameLower:find(keyword, 1, true) then 
					return lootType, config
				end
			end
		end
		return nil
	end
	
	local function isLootEnabled(lootType)
		if lootType == 'iron' then
			return IronToggle.Enabled
		elseif lootType == 'diamond' then
			return DiamondToggle.Enabled
		elseif lootType == 'emerald' then
			return EmeraldToggle.Enabled
		end
		return false
	end
	
	local function getProperIcon(lootType)
		local icon = bedwars.getIcon({itemType = lootType}, true)
		
		if not icon or icon == "" then
			return nil
		end
		
		return icon
	end
	
	local function Added(lootHandle, lootType, config)
		if not isLootEnabled(lootType) then return end
		if Reference[lootHandle] then return end 
		
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = lootType
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(40, 40)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = lootHandle
		
		local blur = addBlur(billboard)
		blur.Visible = true 
		
		local iconImage = getProperIcon(config.icon)
		
		if iconImage then
			local image = Instance.new('ImageLabel')
			image.Size = UDim2.fromOffset(40, 40)
			image.Position = UDim2.fromScale(0.5, 0.5)
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.BackgroundColor3 = Color3.new(0, 0, 0) 
			image.BackgroundTransparency = 0.3 
			image.BorderSizePixel = 0
			image.Image = iconImage
			image.Parent = billboard
			
			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = image
		else
			local frame = Instance.new('Frame')
			frame.Size = UDim2.fromScale(1, 1)
			frame.BackgroundColor3 = Color3.new(0, 0, 0) 
			frame.BackgroundTransparency = 0.3 
			frame.BorderSizePixel = 0
			frame.Parent = billboard
			
			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = frame
			
			local textLabel = Instance.new('TextLabel')
			textLabel.Size = UDim2.fromScale(1, 1)
			textLabel.Position = UDim2.fromScale(0.5, 0.5)
			textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = config.displayName
			textLabel.TextColor3 = config.color
			textLabel.TextScaled = true
			textLabel.Font = Enum.Font.GothamBold
			textLabel.TextStrokeTransparency = 0.5
			textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			textLabel.Parent = frame
		end
		
		Reference[lootHandle] = billboard
	end
	
	local function Removed(lootHandle)
		if Reference[lootH