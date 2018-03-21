EasyLockpicking = {}

-- change to false to disable the lockpick requirement
enableLockpickRequired = false

-- change to false to prevent lockpicks from breaking
enableLockpickBreaking = false

-- change to false to disable the skill requirement
enableSkillRequired = false

-- change to false to prevent stashes/doors from automatically opening
enableAutoOpen = true

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

function EasyLockpicking.TryToAutoUnlock(entity, user)
	-- get the player's lockpicking skill level
	local skillLevel = user.soul:GetSkillLevel("lockpicking")

	-- get the lock's difficulty score (model2lockDifficulty / 20.0)
	local lockDifficulty = entity:GetLockDifficulty()

	-- vanilla reward xp formula - thanks to Warhorse developer "Bart"
	local rewardXP = RPG.LockPickingSuccessXPMulCoef * (lockDifficulty + 1) / (RPG.LockPickingSuccessXPDivCoef * skillLevel + 1)

	-- if lockpicks are required, check if the player has a lockpick
	if enableLockpickRequired then
		if not Utils.HasItem(user, Utils.itemIDs.lockpick) then
			Game.SendInfoText("@dlg_lp_cannotStart", true)
			return
		end
	end

	-- if lockpicking skill is required, check if the player has
	-- the skill to pick the lock (skillLevel / 20.0 vs. lockDifficulty)
	if enableSkillRequired then
		local canAutoUnlock = EasyLockpicking.CanPickLock(skillLevel, lockDifficulty)

		if not canAutoUnlock then
			Minigame.StartLockPicking(entity.id)
			return
		end
	end

	-- if lockpick breaking is enabled, roll the dice
	if enableLockpickBreaking then
		-- min chance to keep lockpick is 10%
		local chanceToKeepLockpick = skillLevel / 2
		local diceRoll = math.random(1, 10)

		-- try to remove lockpick
		if diceRoll > chanceToKeepLockpick then
			Utils.RemoveInvItem(user, Utils.itemIDs.lockpick, 1, true)
			CrimeUtils.ProduceAiSoundOnDudePosition(enum_sound.door, 0.03)
		end
	end

	-- unlock door/stash
	entity:Unlock()
	BroadcastEvent(entity, "Unlock")
	XGenAIModule.SendMessageToEntity(entity.this.id, "tutorial:lockPicking", "2")

	-- refresh UI
	entity:GetActions(user)

	-- emit sound for ai when the door/stash is unlocked
	CrimeUtils.ProduceAiSoundOnDudePosition(enum_sound.door, 0.03)

	-- if auto open is enabled, automatically open door/stash when unlocked
	if enableAutoOpen then
		entity:OnUsed(user)
		BroadcastEvent(entity, "Open")
	end

	-- if lockpicking skill not maxed, reward xp
	if skillLevel ~= RPG.SkillCap then
		user.soul:AddSkillXP("lockpicking", rewardXP)
		RPG.NotifyLevelXpGain("lockpicking")
	end

	-- if stealth skill not maxed, reward xp
	if user.soul:GetSkillLevel("stealth") ~= RPG.SkillCap then
		user.soul:AddSkillXP("stealth", RPG.LockPickingStealthXP)
	end

	-- show success message
	Game.SendInfoText("@ui_hud_lp_success", true)
end