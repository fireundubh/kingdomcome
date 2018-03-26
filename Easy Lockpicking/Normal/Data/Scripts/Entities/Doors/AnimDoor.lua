Script.ReloadScript("Scripts/Entities/AI/Shared/AIBase.lua")
Script.ReloadScript("Scripts/Script/EasyLockpicking.lua")

AnimDoor = {
	Server = {},
	Client = {},
	Properties = {
		sWH_AI_EntityCategory = "Door",
		guidSmartObjectType = "",
		soclasses_SmartObjectHelpers = "",
		soclasses_SmartObjectClass = "",
		bInteractiveCollisionClass = 1,
		fKeepOpenFrom = 7.5,
		fKeepOpenUntil = 19.5,
		esInteriorType = "undefined",
		Lock = {
			bLocked = 0,
			fLockDifficulty = 0.5,
			bLockDifficultyOverride = 0,
			bCanLockPick = 1,
			bSendMessage = 0,
			esLockTypes = "none/none",
			bLockReversed = 0,
			guidItemClassId = "",
			bLockpickIsLegal = 0,
			bLockInside = 0,
			bLockOutside = 0,
			bNeverLock = 0,
		},
		object_Model = "objects/characters/assets/doors/wooden_door_02_left.cdf",
		Sounds = {
			snd_Open = "Sounds/environment:doors:door_wood_1_open",
			snd_Close = "Sounds/environment:doors:door_wood_1_close",
		},
		Animation = {
			anim_Open = "Open",
			anim_Close = "Close",
		},
		Physics = {
			bPhysicalize = 1,
			bRigidBody = 0,
			bPushableByPlayers = 0,
			Density = -1,
			Mass = -1,
		},
		fUseDistance = 2.5,
		bActivatePortal = 0,
		bNoFriendlyFire = 0,
	},
	Editor = {
		Icon = "Door.bmp",
		ShowBounds = 1,
	},
	nDirection = -1,
	bOpenAfterUnlock = 0,
	bUseSameAnim = 0,
	bNoAnims = 0,
	nSoundId = 0,
	bLocked = 0,
	bNeedUpdate = 0,
	bUseableMsgChanged = 0;
	nUserId = 0;
	LockType = "door";
	lastAnim = "";
}

function AnimDoor:OnLoad(table)
	self.bLocked = table.bLocked
	self.bNeedUpdate = 0
	self:ResetAnimation(0, -1)
	self:DoStopSound()
	self.curAnim = ""
	self.nDirection = 0
	self.fTargetTime = 0

	self.interactive = table.interactive
	self.unlockedDueExpected = false
	self.lockedDueToPrivate = table.lockedDueToPrivate
	self.shouldLockOverride_onEnter = table.shouldLockOverride_onEnter
	self.shouldLockOverride_onExit = table.shouldLockOverride_onExit
	self.lockpickable = table.lockpickable

	self.neverLock = pick(table.neverLock == nil, self.Properties.Lock.bNeverLock == 1, table.neverLock)

	if AI then
		AI.SetSmartObjectState(self.id, "Closed")
	end

	if self.bLocked == 1 and AI then
		self:Lock()
	end

	if self:HasNeverLock() and self:IsLocked() then
		self:Unlock()
	end

	if self.portal then
		System.ActivatePortal(self:GetWorldPos(), 0, self.id)
	end

	local newDirection = table.nDirection
	self.lastAnim = table.lastAnim

	if newDirection == 1 then
		self:DoPlayAnimation(newDirection, 1.0, false, self.lastAnim)
		self.curAnim = ""

		if AI then
			AI.ModifySmartObjectStates(self.id, "Open-Closed")
		end
	else
		self.nDirection = newDirection
	end

	self.inUse = 0
end

function AnimDoor:OnSave(table)
	table.bLocked = self.bLocked
	table.interactive = self.interactive
	table.lockedDueToPrivate = self.lockedDueToPrivate
	table.shouldLockOverride_onEnter = self.shouldLockOverride_onEnter
	table.shouldLockOverride_onExit = self.shouldLockOverride_onExit
	table.lockpickable = self.lockpickable
	table.neverLock = self.neverLock

	table.nDirection = self.nDirection
	table.lastAnim = self.lastAnim
end

function AnimDoor:OnPropertyChange()
	self:Reset()
end

function AnimDoor:OnReset()
	self:Reset()
end

function AnimDoor:OnSpawn()
	self:Reset()
end

function AnimDoor:IsAccessedFromFront()
	local playerPos = player:GetWorldPos()
	local doorPos = self:GetWorldPos()
	local doorDir = self:GetWorldDir()

	local dot = ((doorPos.x - playerPos.x) * doorDir.x) + ((doorPos.y - playerPos.y) * doorDir.y)

	return dot >= 0
end

function AnimDoor:IsRightDoor()
	return string.match(self.Properties.object_Model, "right") ~= nil
end

function AnimDoor:Reset()
	if self.portal then
		System.ActivatePortal(self:GetWorldPos(), 0, self.id)
	end

	self.bLocked = 0
	self.portal = self.Properties.bActivatePortal ~= 0
	self.bUseSameAnim = self.Properties.Animation.anim_Close == ""

	if self.Properties.object_Model ~= "" then
		self:LoadObject(0, self.Properties.object_Model)
	end

	self.bNoAnims = self.Properties.Animation.anim_Open == "" and self.Properties.Animation.anim_Close == ""

	self:PhysicalizeThis()
	self:DoStopSound()
	self.nDirection = -1
	self.curAnim = ""
	self.inUse = 0

	self.lockpickIsLegal = self.Properties.Lock.bLockpickIsLegal > 0
	self.suspiciousCrimeVolume = nil
	self.interactive = true
	self.unlockedDueExpected = false
	self.lockedDueToPrivate = false
	self.shouldLockOverride_onEnter = self.Properties.Lock.bLockInside == 1
	self.shouldLockOverride_onExit = self.Properties.Lock.bLockOutside == 1

	self.lockpickable = self.Properties.Lock.bCanLockPick == 1
	self.neverLock = self.Properties.Lock.bNeverLock == 1

	if self.Properties.Lock.bLockDifficultyOverride == 0 then
		self.Properties.Lock.fLockDifficulty = self:GenerateLockDifficulty()
	end

	if AI then
		AI.SetSmartObjectState(self.id, "Closed")
	end

	if self.Properties.Lock.bLocked ~= 0 or self:ShouldBeLocked(false) then
		self:Lock()
	end

	self:SetInteractiveCollisionType()
end

function AnimDoor:SetInteractiveCollisionType()
	local filtering = {}

	if self.Properties.bInteractiveCollisionClass == 1 then
		filtering.collisionClass = 262144
	else
		filtering.collisionClassUNSET = 262144
	end

	self:SetPhysicParams(PHYSICPARAM_COLLISION_CLASS, filtering)
end

function AnimDoor.Client:OnLevelLoaded()
	self:SetInteractiveCollisionType()
end

function AnimDoor:OnEnablePhysics()
	self:SetInteractiveCollisionType()
end

function AnimDoor:PhysicalizeThis()
	local Physics = self.Properties.Physics
	Physics.bRigidBody = 0

	EntityCommon.PhysicalizeRigid(self, 0, Physics, 1)
end

function AnimDoor:IsUsable(user)
	if not user then
		return 0
	end

	if user.id ~= player.id then
		return 1
	end

	if self.inUse == 1 then
		return 0
	end

	if self.bLocked == 1 and self.nDirection == -1 then
		if self:IsOnKeySide() == 1 and self.Properties.Lock.guidItemClassId ~= "" then
			local id = player.inventory:FindItem(self.Properties.Lock.guidItemClassId)

			if id and id ~= 0 then
				return 1
			end
		end

		if self.Properties.Lock.esLockTypes == "manual/none" then
			return pick(self.Properties.Lock.bLockReversed == 1, 0, 0)
		end
	end

	local useDistance = self.Properties.fUseDistance

	if useDistance <= 0.0 then
		return 0
	end

	local delta = g_Vectors.temp_v1
	local mypos, bbmax = self:GetWorldBBox()

	FastSumVectors(mypos, mypos, bbmax)
	ScaleVectorInPlace(mypos, 0.5)
	user:GetWorldPos(delta)

	SubVectors(delta, delta, mypos)

	useDistance = self.Properties.fUseDistance

	return pick(LengthSqVector(delta) < useDistance * useDistance, 1, 0)
end

function AnimDoor:IsUsableMsgChanged()
	return self.bUseableMsgChanged
end

function AnimDoor:IsOnKeySide()
	local frontSide = self:IsAccessedFromFront()

	if self.Properties.Lock.esLockTypes == "manual/key" then
		return pick(self.Properties.Lock.bLockReversed == 1 and frontSide, 1, 1)
	elseif self.Properties.Lock.esLockTypes == "key/key" then
		return 1
	else
		return 0
	end
end

function AnimDoor:GetActions(user, firstFast)
	if user == nil then
		return {}
	end

	if not self.interactive then
		return {}
	end

	output = {}

	if self:IsUsable(user) == 1 then
		if self.bLocked == 1 and self:IsOnKeySide() == 1 then
			if self.nUserId == 0 and self.Properties.Lock.guidItemClassId ~= "" then
				local id = player.inventory:FindItem(self.Properties.Lock.guidItemClassId)

				if id and id ~= 0 then
					if AddInteractorAction(output, firstFast, Action():hint("@ui_hud_unlock"):action("use"):func(AnimDoor.OnUsed):interaction(inr_doorUnlock)) then
						return output
					end
				end
			end
		else
			local hint = pick(self.nDirection == -1, "@ui_door_open", "@ui_door_close")
			local interaction = pick(self.nDirection == -1, inr_doorOpen, inr_doorClose)

			if AddInteractorAction(output, firstFast, Action():hint(hint):action("use"):func(AnimDoor.OnUsed):interaction(interaction)) then
				return output
			end
		end
	end

	if not self.lockpickable or self.bLocked ~= 1 or self:IsOnKeySide() ~= 1 or self.nUserId ~= 0 then
		return output
	end

	local hint = "@" .. EasyLockpicking.BuildLockpickPromptStrName(self.Properties.Lock.fLockDifficulty)
	AddInteractorAction(output, firstFast, Action():hint(hint):action("use"):hintType(AHT_HOLD):func(AnimDoor.Lockpick):interaction(inr_doorLockpick))

	return output
end

function AnimDoor:Lockpick(user, slot)
	if not self.lockpickable or self.bLocked ~= 1 or self:IsOnKeySide() ~= 1 or self.nUserId ~= 0 then
		return
	end

	EasyLockpicking.TryToAutoUnlock(self, user)
end

function AnimDoor:OnUsed(user, slot)
	if self.nDirection == 0 then
		return 0
	end

	local direction = -self.nDirection

	if self.bLocked == 1 then
		if self:IsOnKeySide() == 1 then
			if self.Properties.Lock.guidItemClassId ~= "" then
				local id = player.inventory:FindItem(self.Properties.Lock.guidItemClassId)

				if id and id ~= 0 then
					if user.id == player.id then
						self:Unlock()
						XGenAIModule.SendMessageToEntity(self.this.id, "tutorial:onOpenedWithKey", "Item('" .. self.Properties.Lock.guidItemClassId .. "')")
						self:DoPlayAnimation(direction, nil, nil, nil, true)
						self:ProduceAiSound()
					end
				end
			end
		else
			if user.id == player.id then
				self:Unlock()
				self:DoPlayAnimation(direction, nil, nil, nil, true)
				self:ProduceAiSound()
			end
		end
	else
		if user.id == player.id then
			self:DoPlayAnimation(direction, nil, nil, nil, true)
			self:ProduceAiSound()
		end
	end

	if self.suspiciousCrimeVolume ~= nil then
		XGenAIModule.DespawnPerceptibleVolume(self.suspiciousCrimeVolume)
		self.suspiciousCrimeVolume = nil
	else
		if user.id ~= player.id then
			return
		end

		--local playerPos = player:GetPos()
		--local doorPos = self:GetPos()

		--local volumePos = { x = (playerPos.x + doorPos.x) / 2, y = (playerPos.y + doorPos.y) / 2, z = (playerPos.z + doorPos.z) / 2 }
	end
end

function AnimDoor:EnableLockpick()
	self.lockpickable = true
end

function AnimDoor:DisableLockpick()
	self.lockpickable = false
end

function AnimDoor:Lock(dontClose)
	if not dontClose and self:IsOpen() then
		self:Close()
	end

	if self:HasNeverLock() then
		return
	end

	if AI then
		AI.ModifySmartObjectStates(self.id, "Locked")
	end
	self.bLocked = 1
end

function AnimDoor:Unlock()
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

function AnimDoor:Open()
	if self.nDirection == -1 then
		self:DoPlayAnimation(1)
	end
end

function AnimDoor:Close()
	if self.nDirection == 1 then
		self:DoPlayAnimation(-1)
	end
end

function AnimDoor:SetShouldBeLockedOverride(doLock)
	if doLock then
		self.shouldLockOverride_onEnter = true
		self.shouldLockOverride_onExit = true
	else
		self.shouldLockOverride_onEnter = self.Properties.Lock.bLockInside == 1
		self.shouldLockOverride_onExit = self.Properties.Lock.bLockOutside == 1
	end
end

function AnimDoor.Server:OnUpdate(dt)
	if self.bNeedUpdate == 0 then
		return
	end

	if self.bNoAnims == 0 and (self.curAnim == "" or self.nDirection == 0) then
		return
	end

	local curTime = self:GetAnimationTime(0, 0)

	if self:IsAnimationRunning(0, 0) and math.abs(curTime - 1) > 0.0001 then
		return
	end

	self.curAnim = ""

	local nDirection = self.nDirection

	if AI then
		local aiObjectState = pick(nDirection == -1, "Closed-Open", "Open-Closed")
		AI.ModifySmartObjectStates(self.id, aiObjectState)
	end

	if nDirection == -1 and self.portal then
		System.ActivatePortal(self:GetWorldPos(), 0, self.id)
	end

	self:Activate(0)
	self.bNeedUpdate = 0
	self.inUse = 0

	if nDirection == -1 then
		BroadcastEvent(self, "Close")
	else
		BroadcastEvent(self, "Open")
	end
end

function AnimDoor:DoPlaySound(sndName)
end

function AnimDoor:DoStopSound()
end

function AnimDoor:BuildNPCAnimationName(usedByPlayer, customAnim)
	local anim_construct
	local animName

	if usedByPlayer then
		if string.match(self.Properties.object_Model, "cabinet") then
			animName = pick(self.nDirection == 1, "cabinet_c", "cabinet_o")
		else
			anim_construct = pick(self:IsRightDoor(), "door_r_", "door_l_")
			anim_construct = anim_construct .. pick(self:IsAccessedFromFront(), "f_", "b_")
			anim_construct = anim_construct .. pick(self.nDirection == 1, "c", "o")
			animName = anim_construct
		end
	elseif customAnim == nil then
		anim_construct = pick(self:IsRightDoor(), "door_r_", "door_l_")
		anim_construct = anim_construct .. pick(self.nDirection == 1, "f_c", "f_o")
		animName = anim_construct
	else
		animName = ""
	end

	return animName
end

function AnimDoor:BuildObjectAnimationName(usedByPlayer, customAnim)
	local anim_construct
	local animName

	if usedByPlayer then
		if string.match(self.Properties.object_Model, "cabinet") then
			animName = pick(self.nDirection == 1, "cabinet_close", "cabinet_open")
		else
			anim_construct = pick(self:IsRightDoor(), "door_r_", "door_l_")
			anim_construct = anim_construct .. pick(self:IsAccessedFromFront(), "f_", "b_")
			anim_construct = anim_construct .. pick(self.nDirection == 1, "c", "o")
			animName = anim_construct .. "_player"
		end
	elseif customAnim == nil then
		anim_construct = pick(self:IsRightDoor(), "door_r_", "door_l_")
		anim_construct = anim_construct .. pick(self.nDirection == 1, "f_c_player", "f_o_player")
		animName = anim_construct
	else
		animName = customAnim
	end

	return animName
end

function AnimDoor:DoPlayAnimation(direction, forceTime, useSound, customAnim, usePlayerAnim)
	self.inUse = 1
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

		animName = self:BuildObjectAnimationName(usePlayerAnim, customAnim)

		if usePlayerAnim then
			local npcAnim = self:BuildNPCAnimationName(usePlayerAnim, customAnim)

			player.actor:StartInteractiveActionByName(npcAnim, self.id, true, 1)

			local link = self:GetLink(0)

			if self.Properties.Lock.bSendMessage == 1 then
				if self.nDirection == 1 then
					XGenAIModule.SendMessageToEntity(link.this.id, "door:onOpenOnClose", "action('onClose')")
				else
					XGenAIModule.SendMessageToEntity(link.this.id, "door:onOpenOnClose", "action('onOpen')")
				end
			end
		end

		animDirection = 1
		self.lastAnim = animName

		if not self.bNoAnims then
			self:StopAnimation(0, 0)
			self:StartAnimation(0, animName)
			self:SetAnimationSpeed(0, 0, animDirection)

			if forceTime then
				self:SetAnimationTime(0, 0, forceTime)
			else
				local relativeTime = pick(animDirection == 1, curTime, 1.0 - curTime)
				self:SetAnimationTime(0, 0, relativeTime)
			end
		end

		self.curAnim = animName
		self.fTargetTime = self:GetAnimationLength(0, self.curAnim)
	else
		self:SetAnimationSpeed(0, 0, direction)
	end

	self.nDirection = direction
	self:ForceCharacterUpdate(0, true)
	self:Activate(1)
	self.bNeedUpdate = 1

	if self.portal then
		System.ActivatePortal(self:GetWorldPos(), 1, self.id)
	end

	local sndName = self.Properties.Sounds.snd_Open

	if direction ~= -1 then
		return
	end

	sndName = self.Properties.Sounds.snd_Close
end

function AnimDoor:IsInUse()
	return self.inUse == 1
end

function AnimDoor:IsLocked()
	return self.bLocked == 1
end

function AnimDoor:HasNeverLock()
	return self.neverLock
end

function AnimDoor:SetNeverLock(value)
	self.neverLock = value
end

function AnimDoor:GetLockDifficulty()
	return self.Properties.Lock.fLockDifficulty
end

function AnimDoor:IsOpen()
	return self.nDirection > 0
end

function AnimDoor:ShouldBeClosed(isEntering)
	if self:ShouldBeLocked(isEntering) then
		return true
	end

	if self.Properties.esInteriorType == "stash" then
		return true
	elseif self.Properties.esInteriorType == "shop" then
		return false
	end

	local timeToClose = not self:IsDaytime()

	return timeToClose
end

function AnimDoor:IsDaytime(isEntering)
	local timeOfDay = Calendar.GetWorldHourOfDay()
	return self.Properties.fKeepOpenFrom < timeOfDay and timeOfDay < self.Properties.fKeepOpenUntil
end

function AnimDoor:ShouldBeLocked(isEntering)
	if self:HasNeverLock() then
		return false
	end

	local perInstanceDoLock = (isEntering and self.shouldLockOverride_onEnter) or (not isEntering and self.shouldLockOverride_onExit)

	if self.Properties.esInteriorType == "home" then
		local timeToLock = not self:IsDaytime()
		return (perInstanceDoLock or (timeToLock and isEntering)) and not self.unlockedDueExpected
	elseif self.Properties.esInteriorType == "stash" then
		return not isEntering
	elseif self.Properties.esInteriorType == "shop" then
		return self.lockedDueToPrivate
	end

	return perInstanceDoLock
end

function AnimDoor:SetUnlockedDueExpected(isExpected)
	self.unlockedDueExpected = isExpected
end

function AnimDoor:SetLockedDueToPrivate(isPrivate)
	if isPrivate then
		self:Lock()
	else
		self:Unlock()
	end

	self.lockedDueToPrivate = isPrivate
end

function AnimDoor:GenerateLockDifficulty()

	local model2lockDifficulty = {
		["doors/lvl1_door_01"] = 0,
		["doors/lvl1_door_02"] = 0,
		["doors/lvl1_door_03"] = 0,
		["doors/lvl1_door_04"] = 1,
		["doors/lvl1_door_07"] = 1,
		["doors/lvl1_door_06"] = 2,
		["doors/lvl1_door_05"] = 3,
		["doors/lvl2_door_01"] = 6,
		["doors/lvl2_door_03"] = 7,
		["doors/lvl2_door_02"] = 8,
		["doors/lvl3_door_01"] = 11,
		["doors/lvl3_door_02"] = 12,
		["doors/lvl3_door_03"] = 14,
		["doors/lvl3_door_jail"] = 15,
		["doors/lvl4_door_03"] = 15,
		["doors/lvl4_door_01"] = 15,
		["doors/lvl4_door_04"] = 15,
		["doors/lvl4_door_09"] = 15,
		["doors/lvl4_door_02"] = 16,
		["doors/lvl4_door_08"] = 16,
		["doors/lvl4_door_06"] = 16,
		["doors/lvl4_door_07"] = 16,
		["doors/lvl4_door_05"] = 16,
		["doors/lvl4_door_10"] = 20,
	}

	for nameSnippet, difficulty in pairs(model2lockDifficulty) do
		if string.match(self.Properties.object_Model, nameSnippet) ~= nil then
			return difficulty / 20.0
		end
	end

	return 0
end

function AnimDoor:GetInteriorType()
	if self.Properties.esInteriorType == "home" then
		return enum_interiorType.home
	elseif self.Properties.esInteriorType == "stash" then
		return enum_interiorType.stash
	elseif self.Properties.esInteriorType == "shop" then
		return enum_interiorType.shop
	else
		return enum_interiorType.undefined
	end
end

function AnimDoor:ProduceAiSound()
	CrimeUtils.ProduceAiSoundOnDudePosition(enum_sound.door, 0.03)
end

function AnimDoor:Event_Unlock()
	self:Unlock()
	BroadcastEvent(self, "Unlock")
end

function AnimDoor:Event_Lock()
	self:Lock()
	BroadcastEvent(self, "Lock")
end

function AnimDoor:Event_Open()
	self:DoPlayAnimation(1)
end

function AnimDoor:Event_Close()
	self:DoPlayAnimation(-1)
end

function AnimDoor:Event_Hide()
	self:Hide(1)
	self:ActivateOutput("Hide", true)
end

function AnimDoor:Event_UnHide()
	self:Hide(0)
	self:ActivateOutput("UnHide", true)
end

AnimDoor.FlowEvents = {
	Inputs = {
		Close = { AnimDoor.Event_Close, "bool" },
		Open = { AnimDoor.Event_Open, "bool" },
		Lock = { AnimDoor.Event_Lock, "bool" },
		Unlock = { AnimDoor.Event_Unlock, "bool" },
		Hide = { AnimDoor.Event_Hide, "bool" },
		UnHide = { AnimDoor.Event_UnHide, "bool" },
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

function AnimDoor:SetLockpickLegal(value)
	self.lockpickIsLegal = value
end

function AnimDoor:IsLockpickLegal()
	return self.lockpickIsLegal
end

function AnimDoor:SetInteractive(value)
	self.interactive = value
end
