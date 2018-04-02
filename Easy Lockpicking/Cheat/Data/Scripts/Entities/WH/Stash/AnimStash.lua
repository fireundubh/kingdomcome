Script.ReloadScript("Scripts/Script/EasyLockpicking.lua")

Stash = {
	Server = {},
	Client = {},

	Properties = {
		guidSmartObjectType = "",
		soclasses_SmartObjectHelpers = "",
		sWH_AI_EntityCategory = "",

		object_Model = "objects/props/wooden_bins/chests/chest_01/chest01.cga",

		Lock = {
			bLocked = 0,
			bCanLockPick = 1,
			fLockDifficulty = 1,
			bLockDifficultyOverride = 0,
			bSendMessage = 0,
			guidItemClassId = "",
			bLockpickIsLegal = 0,
		},

		Sounds = {
			snd_Open = "",
			snd_Close = "",
		},
		Animation = {
			anim_Open = "open",
			anim_Close = "close",
			bOpenOnly = 0,
		},

		Physics = {
			bPhysicalize = 1,
			bRigidBody = 1,
			bPushableByPlayers = 0,
			Density = -1,
			Mass = -1,
		},

		Phase = {
			bChangeAfterPlayerInteract = 0,
			object_ModelAfterInteract = "",
		},

		fUseDistance = 2.5,
		bSkipAngleCheck = 0,
		fUseAngle = 0.7,
		fUseZOffset = 0,

		Database = {
			guidInventoryDBId = "0",
			iMinimalShopItemPrice = 0,
		},

		Script = {
			bTutorial = 0,
			bLootIsLegal = 0,
			Misc = "",
		},

		bInteractableThroughCollision = 0,
	},


	Editor = {
		Icon = "stash.bmp",
		ShowBounds = 1,
		IconOnTop = 1,
	},

	nDirection = -1,
	bOpenAfterUnlock = 0,
	bUseSameAnim = 0,
	bNoAnims = 0,
	nSoundId = 0,
	bLocked = 0,
	bOpened = 0,
	bSearched = 0,
	bNeedUpdate = 0,
	bUseableMsgChanged = 0,
	inventoryId = 0,
	nUserId = 0,
	LockType = "chest",

	OriginalModel = "",
}

function Stash:OnLoad(table)
	self.bLocked = table.bLocked
	self.bOpened = table.bOpened
	self.bSearched = table.bSearched
	self.bNeedUpdate = 0
	self:ResetAnimation(0, -1)
	self:DoStopSound()
	self.curAnim = ""
	self.nDirection = -1
	self.fTargetTime = 0

	self.lockpickIsLegal = table.lockpickIsLegal
	self.lootIsLegal = table.lootIsLegal
	self.interactive = table.interactive

	if AI then
		AI.SetSmartObjectState(self.id, "Closed")
	end

	if self.bLocked == 1 and AI then
		self:Lock()
	end

	local nDirection = table.nDirection

	if table.doPlay == 1 then
		self:DoPlayAnimation(nDirection, table.animTime)
		return
	end

	if nDirection ~= 1 then
		return
	end

	local wantedTime = self:GetAnimationLength(0, self.Properties.Animation.anim_Open)
	self:DoPlayAnimation(nDirection, wantedTime, false)
	self.curAnim = ""

	if AI then
		AI.ModifySmartObjectStates(self.id, "Open-Closed")
	end
end

function Stash:OnSave(table)
	table.bLocked = self.bLocked
	table.bOpened = self.bOpened
	table.bSearched = self.bSearched

	table.lockpickIsLegal = self.lockpickIsLegal
	table.lootIsLegal = self.lootIsLegal
	table.interactive = self.interactive

	if self.nDirection ~= 0 and self.curAnim ~= "" and self:IsAnimationRunning(0, 0) then
		table.doPlay = 1
		table.nDirection = self.nDirection
		table.animTime = self:GetAnimationTime(0, 0)
		return
	end

	table.doPlay = 0
	table.nDirection = self.nDirection
end

function Stash:OnPropertyChange()
	if Shops.GetShopDBIdByLinkedEntityId(self.id) < 0 then
		EntityModule.LoadInventoryFromDB(self.Properties.Database.guidInventoryDBId, self.id)
	end

	self:Reset()
end

function Stash:OnReset(toGame)
	if Shops.GetShopDBIdByLinkedEntityId(self.id) < 0 then
		if toGame then
			EntityModule.LoadInventoryFromDB(self.Properties.Database.guidInventoryDBId, self.id)
		end
	end

	self.OriginalModel = self.Properties.object_Model

	self:Reset()
end

function Stash:OnSpawn()
	self.inventoryId = EntityModule.AcquireInventory(self.Properties.Database.guidInventoryDBId, self.id)
	self:Reset()
end

function Stash:OnDestroy()
	EntityModule.ReleaseInventory(self.id)
	self.inventoryId = -1
end

function Stash:Reset()
	self.bLocked = 0
	self.bOpened = 0
	self.bSearched = 0
	self.bUseSameAnim = self.Properties.Animation.anim_Close == "" or self.Properties.Animation.anim_Close == self.Properties.Animation.anim_Open

	if self.Properties.object_Model ~= "" then
		self:LoadObject(0, self.Properties.object_Model)
	end

	self.bNoAnims = self.Properties.Animation.anim_Open == "" and self.Properties.Animation.anim_Close == ""

	self:PhysicalizeThis()
	self:DoStopSound()

	self.nDirection = -1
	self.curAnim = ""
	self.fTargetTime = 0

	if AI then
		AI.SetSmartObjectState(self.id, "Closed")
	end

	if self.Properties.Lock.bLockDifficultyOverride == 0 then
		self.Properties.Lock.fLockDifficulty = self:GenerateLockDifficulty()
	end

	if self.Properties.Lock.bLocked ~= 0 then
		self:Lock()
	end

	self.lockpickIsLegal = (self.Properties.Lock.bLockpickIsLegal > 0)
	self.lootIsLegal = (self.Properties.Script.bLootIsLegal > 0)
	self.interactive = true
end

function Stash:PhysicalizeThis()
	local Physics = self.Properties.Physics
	EntityCommon.PhysicalizeRigid(self, 0, Physics, 1)
end

function Stash:IsUsable(user)
	if not user then
		return 0
	end

	local vecToPlayer = g_Vectors.temp_v2
	local myPos = g_Vectors.temp_v3

	user:GetWorldPos(vecToPlayer)
	self:GetWorldPos(myPos)

	vecToPlayer.x = myPos.x - vecToPlayer.x
	vecToPlayer.y = myPos.y - vecToPlayer.y
	vecToPlayer.z = myPos.z - (vecToPlayer.z + self.Properties.fUseZOffset)

	local lengthsq = LengthSqVector(vecToPlayer)
	local usedistsq = self.Properties.fUseDistance * self.Properties.fUseDistance

	if lengthsq > usedistsq then
		return 0
	end

	if self.Properties.bSkipAngleCheck == 1 then
		return 1
	end

	local useAngle = self.Properties.fUseAngle
	local myDirection = g_Vectors.temp_v1

	myDirection = self:GetDirectionVector(0)

	NormalizeVector(vecToPlayer)
	VecRotate90_Z(vecToPlayer)

	local dp = dotproduct2d(myDirection, vecToPlayer)

	if dp < useAngle then
		return 0
	end

	return 1
end

function Stash:SetDefaultModel()
	if self.Properties.Phase.bChangeAfterPlayerInteract == 1 then
		self:LoadObject(0, self.OriginalModel)
	end
end

function Stash:IsUsableMsgChanged()
	local ret = self.bUseableMsgChanged
	self.bUseableMsgChanged = 0

	return ret
end

function Stash:GetUsableControl()
	local action = pick(self.nUserId == 0, "use", "use_stop")
	return Game.GetActionControl("player", action)
end

function Stash:IsUsableHold(user)
	if self.nUserId == 0 and self.Properties.Lock.bCanLockPick == 1 and self.bLocked == 1 then
		return user.soul:IsInCombatDanger()
	end

	return 0
end

function Stash:GetActions(user, firstFast)
	if user == nil then
		return {}
	end

	local isUsable = self:IsUsable(user)

	if firstFast and isUsable == 0 then
		return {}
	end

	if self.inventoryId == 0 then
		return {}
	end

	output = {}

	local shopWUID = Shops.IsLinkedWithShop(self.id)
	local actionEnabled = not user.soul:IsInCombatDanger()

	local usesStealUiPrompt = self:UsesStealUiPrompt()

	if Framework.IsValidWUID(shopWUID) and self.nUserId == 0 then
		if self.bLocked == 0 then
			local hint = pick(self.bOpened == 1, "@ui_close_stash", pick(usesStealUiPrompt, "@ui_open_stash_crime", "@ui_open_stash"))

			if self.bSearched == 1 then
				hint = pick(self.bOpened == 1, "@ui_close_stash", pick(usesStealUiPrompt, "@ui_open_stash_crime_searched", "@ui_open_stash_searched"))
			end

			local interaction = pick(self.bOpened == 1, inr_stashClose, inr_stashOpen)

			if self.bOpened == 1 then
				if AddInteractorAction(output, firstFast, Action():hint(hint):action("use"):enabled(actionEnabled):func(Stash.OnUsed):interaction(interaction)) then
					return output
				end
			else
				local hintType = pick(usesStealUiPrompt and self.bLocked == 1, AHT_HOLD, AHT_PRESS)
				if AddInteractorAction(output, firstFast, Action():hint(hint):hintType(hintType):action("use"):enabled(actionEnabled):func(Stash.OnUsed):interaction(interaction)) then
					return output
				end
			end
		end
	else
		if self.bOpened == 1 then
			if AddInteractorAction(output, firstFast, Action():hint("@ui_close_stash"):action("use"):enabled(actionEnabled):func(Stash.OnUsed):interaction(inr_stashClose)) then
				return output
			end
		else
			if self.bLocked == 1 then
				local hint = pick(self.Properties.Lock.bCanLockPick == 1 and self.nUserId ~= 0, "@ui_hud_stop_use", "@ui_hud_unlock")

				if self.Properties.Lock.bCanLockPick == 1 and self.nUserId ~= 0 then
					if AddInteractorAction(output, firstFast, Action():hint(hint):action("back"):actionMap("lockpicking"):func(Stash.OnUsed)) then
						return output
					end
				elseif self.Properties.Lock.guidItemClassId ~= "" then
					local id = player.inventory:FindItem(self.Properties.Lock.guidItemClassId)

					if id and id ~= 0 then
						if AddInteractorAction(output, firstFast, Action():hint(hint):enabled(actionEnabled):action("use"):func(Stash.OnUsed):interaction(inr_stashUnlock)) then
							return output
						end
					end
				end
			else
				if EntityModule.CanUseInventory(self.inventoryId) and self.interactive then
					local hint = pick(usesStealUiPrompt, "@ui_open_stash_crime", "@ui_open_stash")

					if self.bSearched == 1 then
						hint = pick(usesStealUiPrompt, "@ui_open_stash_crime_searched", "@ui_open_stash_searched")
					end

					local hintType = pick(usesStealUiPrompt and self.bLocked == 1, AHT_HOLD, AHT_PRESS)

					if AddInteractorAction(output, firstFast, Action():hint(hint):hintType(hintType):enabled(actionEnabled):action("use"):func(Stash.OnUsed):interaction(inr_stashOpen)) then
						return output
					end
				end
			end
		end
	end

	if self.nUserId ~= 0 or self.Properties.Lock.bCanLockPick ~= 1 or self.bLocked ~= 1 then
		return output
	end

	local hint = "@" .. EasyLockpicking.BuildLockpickPromptStrName(self.Properties.Lock.fLockDifficulty)
	AddInteractorAction(output, firstFast, Action():hint(hint):action("use"):hintType(AHT_HOLD):enabled(actionEnabled):func(Stash.OnUsedHold):interaction(inr_stashLockpick))

	return output
end

function Stash:GetUsableEvent()
	if self.bOpened ~= 1 and self.bLocked == 1 and self.Properties.Lock.bCanLockPick == 1 and self.nUserId ~= 0 then
		return "use_stop"
	end
	return "use"
end

function Stash:Open(user)
	if (self.Properties.Phase.bChangeAfterPlayerInteract == 1) then
		self:LoadObject(0, self.Properties.Phase.object_ModelAfterInteract)
	end

	XGenAIModule.LootInventoryBegin(self.inventoryId)

	if (EntityModule.IsInventoryReadOnly(self.inventoryId)) then
		user.actor:OpenInventory(self.id, E_IM_StoreReadOnly, self.inventoryId, "")
	else
		user.actor:OpenInventory(self.id, E_IM_Store, self.inventoryId, "")
	end

	if self.this ~= nil then
		XGenAIModule.SendMessageToEntity(self.this.id, "tutorial:onOpenedUnlocked", "Item('" .. self.Properties.Lock.guidItemClassId .. "')")
	end

	self:Event_Open()

	if user == player then
		CrimeUtils.ProduceAiSoundOnDudePosition(enum_sound.door, 0.03)
	end
end

function Stash:Close()
	self:Event_Close()
end

function Stash:OnInventoryClosed()
	self:Close()
end

function Stash:OnUsed(user, slot)
	if self.nDirection == 0 or self.bNeedUpdate == 1 then
		return
	end

	if user.soul:IsInCombatDanger() then
		return
	end

	local nNewDirection = -self.nDirection

	if nNewDirection ~= 1 then
		self:Close()
	end

	local shopInvId = Shops.IsLinkedWithShop(self.id)
	local shopID = Shops.GetShopDBIdByLinkedEntityId(self.id)

	if Framework.IsValidWUID(shopInvId) and Shops.IsShopOpened(shopID) and self.bLocked == 1 then
		Shops.OpenInventory(self.id, false)
		return
	end

	if not user.player then
		return
	end

	if self.bLocked == false or self.bLocked == 0 then
		self:Open(user)
		return
	end

	if self.Properties.Lock.guidItemClassId == "" then
		return
	end

	local id = player.inventory:FindItem(self.Properties.Lock.guidItemClassId)

	if not id or id == 0 then
		return
	end

	self.bLocked = 0

	if self.this ~= nil then
		XGenAIModule.SendMessageToEntity(self.this.id, "tutorial:onOpenedWithKey", "Item('" .. self.Properties.Lock.guidItemClassId .. "')")
	end

	self:Open(user)
end

function Stash:OnUsedHold(user, slot)
	if self.nDirection == 0 or self.bNeedUpdate == 1 then
		return
	end

	local nNewDirection = -self.nDirection

	if nNewDirection ~= 1 then
		return
	end

	if self.Properties.Lock.bCanLockPick == 1 and (self.bLocked or (self.bLocked == 1 or Framework.IsValidWUID(Shops.IsLinkedWithShop(self.id)))) then
		EasyLockpicking.TryToAutoUnlock(self, user)
	end
end

function Stash:GenerateLockDifficulty()
	local model2lockDifficulty = {
		["chest_small_01"] = 4,
		["chest_02"] = 6,
		["chest_05"] = 8,
		["chest_04"] = 12,
		["chest_03"] = 16,
		["chest_01"] = 20,
	}

	for nameSnippet, difficulty in pairs(model2lockDifficulty) do
		if string.match(self.Properties.object_Model, nameSnippet) ~= nil then
			return difficulty / 20.0
		end
	end

	return 0
end

function Stash:GetLockDifficulty()
	return self.Properties.Lock.fLockDifficulty
end

function Stash:Lock()
	if AI then
		AI.ModifySmartObjectStates(self.id, "Locked")
	end

	self.bLocked = 1
end

function Stash:Unlock()
	if AI then
		AI.ModifySmartObjectStates(self.id, "-Locked")
	end

	self.bLocked = 0

	if self.bOpenAfterUnlock ~= 1 then
		return
	end

	self.bOpenAfterUnlock = 0
	self:Open()
end

function Stash:OnOpen()
	self.bOpened = 1
	self.bSearched = 1
	self.bUseableMsgChanged = 1

	if self.Properties.Animation.bOpenOnly ~= 1 then
		return
	end

	self.bOpened = 0
	self.nDirection = -1
end

function Stash:OnClose()
	self.bOpened = 0
	self.bUseableMsgChanged = 1

	if self.this == nil then
		return
	end

	local selfId = Framework.WUIDToMsg(XGenAIModule.GetMyWUID(self))
	XGenAIModule.SendMessageToEntity(self.this.id, "stashInfo:onClosedByPlayer", "id(" .. selfId .. ")")
end

function Stash.Server:OnUpdate(dt)
	if self.bNeedUpdate == 0 then
		return
	end

	if self.bNoAnims == 0 and (self.curAnim == "" or self.nDirection == 0) then
		return
	end

	local curTime = self:GetAnimationTime(0, 0)

	if self:IsAnimationRunning(0, 0) and curTime <= 0.9999 then
		return
	end

	self.curAnim = ""

	if self.nDirection == -1 then
		self:OnClose()
	else
		self:OnOpen()
	end

	if AI then
		local aiObjectState = pick(self.nDirection == -1, "Closed-Open", "Open-Closed")
		AI.ModifySmartObjectStates(self.id, aiObjectState)
	end

	self:Activate(0)
	self.bNeedUpdate = 0

	if self.nDirection == -1 then
		BroadcastEvent(self, "Close")
	else
		BroadcastEvent(self, "Open")
	end
end

function Stash:DoPlaySound(sndName)
	self:DoStopSound()

	if not sndName or sndName == "" then
		return
	end

	local sndFlags = bor(SOUND_DEFAULT_3D, 0)
	g_Vectors.temp = self:GetDirectionVector(1)
	self.nSoundId = self:PlaySoundEvent(sndName, g_Vectors.v000, g_Vectors.temp, sndFlags, SOUND_SEMANTIC_MECHANIC_ENTITY)
end

function Stash:DoStopSound()
	if self.nSoundId ~= 0 and Sound.IsPlaying(self.nSoundId) then
		self:StopSound(self.nSoundId)
	end

	self.nSoundId = 0
end

function Stash:DoPlayAnimation(direction, forceTime, useSound)
	if self.nDirection == direction then
		return
	end

	local curTime = 0

	local len = 0
	local bNeedAnimStart = 1

	if self.curAnim ~= "" and self:IsAnimationRunning(0, 0) then
		curTime = self:GetAnimationTime(0, 0)
		len = self:GetAnimationLength(0, self.curAnim)
		bNeedAnimStart = not self.bUseSameAnim
	end

	if bNeedAnimStart then
		local animDirection = direction
		local animName = self.Properties.Animation.anim_Open

		if direction == -1 and not self.bUseSameAnim then
			animName = self.Properties.Animation.anim_Close
			animDirection = -animDirection
		end

		if direction == -2 or direction == 2 then
			direction = -1
			animDirection = 1
		end

		if direction == -2 then
			animName = "take_item"
		end

		if direction == 2 then
			animName = "insert_item"
		end

		if not self.bNoAnims then
			self:StopAnimation(0, 0)
			self:StartAnimation(0, animName)

			if forceTime then
				self:SetAnimationTime(0, 0, forceTime)
			else
				local percentage = 0.0

				if len > 0.0 then
					percentage = 1.0 - curTime / len

					if (percentage > 1.0) then
						percentage = 1.0
					end
				end

				if animDirection == -1 then
					percentage = 1.0 - percentage
				end

				self:SetAnimationTime(0, 0, percentage)
			end
		end

		self.curAnim = animName
		self.fTargetTime = self:GetAnimationLength(0, self.curAnim)

		if direction == -1 and self.bUseSameAnim then
			self.fTargetTime = 0
		end
	end

	self.nDirection = direction
	self:ForceCharacterUpdate(0, true)
	self:Activate(1)
	self.bNeedUpdate = 1

	if useSound ~= nil and not useSound then
		return
	end

	local sndName = pick(direction ~= 1, self.Properties.Sounds.snd_Close, self.Properties.Sounds.snd_Open)
	self:DoPlaySound(sndName)
end

function Stash:GetInventory()
	return self.inventoryId
end

function Stash:SetInventory(inventory)
	self.inventoryId = inventory
end

function Stash:Event_Unlock()
	self:Unlock()
	BroadcastEvent(self, "Unlock")
end

function Stash:Event_Lock()
	self:Lock()
	BroadcastEvent(self, "Lock")
end

function Stash:Event_Open()
	self:DoPlayAnimation(1)
end

function Stash:Event_Close()
	self:DoPlayAnimation(-1)
end

function Stash:Event_Hide()
	self:Hide(1)
	self:ActivateOutput("Hide", true)
end

function Stash:Event_UnHide()
	self:Hide(0)
	self:ActivateOutput("UnHide", true)
end

Stash.FlowEvents = {
	Inputs = {
		Close = { Stash.Event_Close, "bool" },
		Open = { Stash.Event_Open, "bool" },
		Lock = { Stash.Event_Lock, "bool" },
		Unlock = { Stash.Event_Unlock, "bool" },
		Hide = { Stash.Event_Hide, "bool" },
		UnHide = { Stash.Event_UnHide, "bool" },
	},
	Outputs = {
		Close = "bool",
		Open = "bool",
		Lock = "bool",
		Unlock = "bool",
		Hide = "bool",
		UnHide = "bool",
	},
}

function Stash:SetLockpickLegal(value)
	self.lockpickIsLegal = value
end

function Stash:IsLockpickLegal()
	return self.lockpickIsLegal
end

function Stash:SetLootLegal(value)
	self.lootIsLegal = value
end

function Stash:IsLootLegal()
	return self.lootIsLegal
end

function Stash:SetInteractive(value)
	self.interactive = value
end

function Stash:UsesStealUiPrompt()
	if self:IsLootLegal() then
		return false
	end

	local ownerWuid = EntityModule.GetInventoryOwner(self.inventoryId)
	if ownerWuid == nil then
		return false
	end

	if ownerWuid == player.this.id then
		return false
	end

	return not RPG:IsPublicEnemy(ownerWuid)
end