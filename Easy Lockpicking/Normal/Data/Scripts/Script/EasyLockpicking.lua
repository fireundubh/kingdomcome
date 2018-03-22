--- All the magic that makes Easy Lockpicking possible
--- @module EasyLockpicking

EasyLockpicking = {}

-- change to false to disable the lockpick requirement
enableLockpickRequired = true

-- change to false to prevent lockpicks from breaking
enableLockpickBreaking = false

-- change to false to disable the skill requirement
enableSkillRequired = true

-- change to false to prevent stashes/doors from automatically opening
enableAutoOpen = true


--- Builds the UI prompt name for locked stashes and doors
--- @param lockDifficulty	(integer)	Stash|AnimDoor:GenerateLockDifficulty()
--- @return string						@ui_hud_lockpick..@ui_hud_lockpick_difficulty_1|2|3|4

function EasyLockpicking.BuildLockpickPromptStrName(lockDifficulty)
	local levels = {
		{ minLockDifficulty = 0.75, strName = "ui_hud_lockpick_difficulty_4" },
		{ minLockDifficulty = 0.5, strName = "ui_hud_lockpick_difficulty_3" },
		{ minLockDifficulty = 0.35, strName = "ui_hud_lockpick_difficulty_2" },
		{ minLockDifficulty = 0, strName = "ui_hud_lockpick_difficulty_1" }
	}

	for _, level in ipairs(levels) do
		if lockDifficulty >= level.minLockDifficulty then
			return level.strName
		end
	end

	return "ui_hud_lockpick"
end


--- Determines whether the entity can pick a lock of a certain difficulty
--- @param skillLevel 		(integer) 	Return value of user.soul:GetSkillLevel("lockpicking")
--- @param lockDifficulty	(float)		Return value of entity:GetLockDifficulty()
--- @return true|false					true: 	entity can pick the lock
---										false: 	entity cannot pick the lock

function EasyLockpicking.CanPickLock(skillLevel, lockDifficulty)
	local skillRating = skillLevel / 20.0

	if skillRating >= 0.75 and lockDifficulty <= 1.00
			or skillRating >= 0.50 and lockDifficulty < 0.75
			or skillRating >= 0.35 and lockDifficulty < 0.5
			or skillRating >= 0.00 and lockDifficulty <= 0.30 then
		return true
	end

	return false
end





--- Breaks a lockpick by removing the lockpick from the user inventory
--- @param user				(table)		The entity making the lockpicking attempt
--- @return true|false					true:	Lockpick was broken
---										false:	Lockpick was not broken

function EasyLockpicking.BreakLockpick(user, skillLevel)
	-- generate random seed for dice roll
	math.randomseed(os.time())

	-- min chance to keep lockpick is 10%
	local chanceToKeepLockpick = 0.1
	if skillLevel ~= 0 and skillLevel ~= 1 then
		chanceToKeepLockpick = skillLevel / 20
	end

	-- try to remove lockpick
	if math.random() > chanceToKeepLockpick then
		Utils.RemoveInvItem(user, Utils.itemIDs.lockpick, 1, true)
		CrimeUtils.ProduceAiSoundOnDudePosition(enum_sound.door, 0.03)

		return true
	end

	return false
end


--- Unlocks a door or stash
--- @param entity			(table)		The stash or door to be unlocked
--- @param user				(table)		The entity making the lockpicking attempt
--- @return nil

function EasyLockpicking.Unlock(entity, user)
	-- unlock door/stash
	entity:Unlock()
	BroadcastEvent(entity, "Unlock")
	XGenAIModule.SendMessageToEntity(entity.this.id, "tutorial:lockPicking", "2")

	-- refresh UI
	entity:GetActions(user)

	-- emit sound for ai when the door/stash is unlocked
	CrimeUtils.ProduceAiSoundOnDudePosition(enum_sound.door, 0.03)
end


--- Opens a stash or door
--- @param entity			(table)		The stash or door to be unlocked
--- @param user				(table)		The entity making the lockpicking attempt
--- @return nil

function EasyLockpicking.Open(entity, user)
	entity:OnUsed(user)
	BroadcastEvent(entity, "Open")
end


--- Rewards Lockpicking and Stealth XP based on lock difficulty
--- @param user				(table)		The entity making the lockpicking attempt
--- @param skillLevel		(integer)	Return value of user.soul:GetSkillLevel("lockpicking")
--- @param lockDifficulty	(float)		Return value of entity:GetLockDifficulty()
--- @return nil

function EasyLockpicking.RewardXP(user, skillLevel, lockDifficulty)
	-- vanilla reward xp formula - thanks to Warhorse developer "Bart"
	local rewardXP = RPG.LockPickingSuccessXPMulCoef * (lockDifficulty + 1) / (RPG.LockPickingSuccessXPDivCoef * skillLevel + 1)

	-- if lockpicking skill not maxed, reward xp
	if skillLevel ~= RPG.SkillCap then
		user.soul:AddSkillXP("lockpicking", rewardXP)
		RPG.NotifyLevelXpGain("lockpicking")
	end

	-- if stealth skill not maxed, reward xp
	if user.soul:GetSkillLevel("stealth") ~= RPG.SkillCap then
		user.soul:AddSkillXP("stealth", RPG.LockPickingStealthXP)
	end
end


--- Attempt to unlock a stash or door at user's skill level, but enter minigame if lock is too hard
--- @param entity 			(table)		The stash or door to be unlocked
--- @param user				(table)		The entity making the lockpicking attempt
--- @return nil

function EasyLockpicking.TryToAutoUnlock(entity, user)
	-- get the player's lockpicking skill level
	local skillLevel = user.soul:GetSkillLevel("lockpicking")

	-- get the lock's difficulty score (model2lockDifficulty / 20.0)
	local lockDifficulty = entity:GetLockDifficulty()

	if enableLockpickRequired then
		-- if user does not have lockpick, don't continue
		if not Utils.HasItem(user, Utils.itemIDs.lockpick) then
			Game.SendInfoText("@dlg_lp_cannotStart", true)
			return
		end
	end

	if enableSkillRequired then
		-- if user does not have required skill, start minigame and don't continue
		if not EasyLockpicking.CanPickLock(skillLevel, lockDifficulty) then
			Minigame.StartLockPicking(entity.id)
			return
		end
	end

	if enableLockpickBreaking then
		-- if user breaks lockpick, don't continue
		if EasyLockpicking.BreakLockpick(user, skillLevel) then
			Game.SendInfoText("Lockpick broke! Failed to pick lock.", true)
			return
		end
	end

	-- unlock the stash/door
	EasyLockpicking.Unlock(entity, user)

	if enableAutoOpen then
		-- open the stash/door
		EasyLockpicking.Open(entity, user)
	end

	-- reward lockpicking and stealth xp
	EasyLockpicking.RewardXP(user, skillLevel, lockDifficulty)

	-- show success message
	Game.SendInfoText("@ui_hud_lp_success", true)
end
