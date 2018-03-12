CrimeUtils = {}

function CrimeUtils.DetectDudeWeaponBeforeConfrontation()
	CrimeUtils.dudeWeaponBeforeConfrontation = player.human:GetItemInHand(0)
end

function CrimeUtils.SendConfrontationResult (dc, action)
	local entity = dc['KONFRONTACE_ZLOCINCE_(MUZ)'].this.id
	local type = 'combat:confrontationFeedback'
	local content = { action = action }

	if action == 'fine' or action == 'jail' or action == 'skillCheck' then
		local weapon = CrimeUtils.dudeWeaponBeforeConfrontation

		if weapon ~= __null then
			local isOversized = ItemManager.IsItemOversized(weapon)

			if isOversized and action == 'jail' then
				player.inventory:DeleteItem(weapon, 1)
			elseif (not isOversized) then
				player.actor:UnequipInventoryItem(weapon)
				player.actor:EquipInventoryItem(weapon)
			end
		end
	end

	XGenAIModule.SendMessageToEntityData(entity, type, content)
	CrimeUtils.dudeWeaponBeforeConfrontation = nil
end

function CrimeUtils.SendFriskResult (dc, action)
	local entity = dc['SACOVANI_JINDRY_NA_BRANE_(MUZ)'].this.id
	local type = 'combat:friskFeedback'
	local content = { action = action }

	XGenAIModule.SendMessageToEntityData(entity, type, content)
end

function CrimeUtils.CalculateConfrontationSkillCheckDifficulty()
	local jailDays = Variables.GetGlobal('crimeConfrontationDialog_jail')
	local impossibleSkillChecks = Variables.GetGlobal('crimeConfrontationDialog_impossibleCrimeSkillChecks')

	if impossibleSkillChecks > 0 then
		return 4
	end

	if jailDays > 9 then
		return 4
	end

	if jailDays > 5 then
		return 3
	end

	if jailDays > 3 then
		return 2
	end

	return 1
end

CrimeUtils.crimeDetectionParams = {
	['lockpick'] = {
		additionalSkillName = 'lockpicking',
		additionalSkillWeight = 1,
		autoUnseenDistanceOnSkillZero = 30,
		autoUnseenDistanceOnSkillCap = 10
	},

	['loot'] = {
		autoUnseenDistanceOnSkillZero = 30,
		autoUnseenDistanceOnSkillCap = 10
	},

	['pickpocket'] = {
		additionalSkillName = 'pickpocketing',
		additionalSkillWeight = 3,
		autoUnseenDistanceOnSkillZero = 20,
		autoUnseenDistanceOnSkillCap = 2
	},

	['pickUpSteal'] = {
		autoUnseenDistanceOnSkillZero = 25,
		autoUnseenDistanceOnSkillCap = 5
	}
}

function CrimeUtils.CanDetectCrime (observer, crime, options)
	options = options or {}
	options.thresholdRangeMod = options.thresholdRangeMod or 1

	local params = assert(CrimeUtils.crimeDetectionParams[crime], strFormat("Unknown crime param value '%s'", crime))

	local skillLevel = player.soul:GetSkillLevel('stealth')

	if params.additionalSkillName ~= nil then
		local additionalSkillLevel = player.soul:GetSkillLevel(params.additionalSkillName)
		skillLevel = (skillLevel + additionalSkillLevel * params.additionalSkillWeight) / (1 + params.additionalSkillWeight)
	end

	local thresholdRange = math.lerp(params.autoUnseenDistanceOnSkillZero, params.autoUnseenDistanceOnSkillCap, skillLevel / 20) * options.thresholdRangeMod

	return observer:GetDistance(player.id) < thresholdRange
end

function CrimeUtils.InitInformationData()
	local result = {}

	local function addLabel (label, values)
		values.isCrime = values.isCrime or false
		values.isUnattributedCrime = values.isUnattributedCrime or false
		values.produceInformationStimulus = values.produceInformationStimulus or false
		values.soldiersAlwaysRespondWithinDistance = values.soldiersAlwaysRespondWithinDistance or 12
		values.soldiersMaxResponderCount = values.soldiersMaxResponderCount or 3
		values.civiliansAutoReactWithinDistance = values.civiliansAutoReactWithinDistance or -1
		values.civiliansCanReactWithinDistance = values.civiliansCanReactWithinDistance or -1
		values.reactorsAutoSuccessCount = values.reactorsAutoSuccessCount or 1
		values.reactorsChanceDecreasePerEachExtra = values.reactorsChanceDecreasePerEachExtra or 0.65
		values.reputationHitName = values.reputationHitName or ''
		values.resolvedByCircators = values.resolvedByCircators or false
		values.isOnlyMonasteryCrime = values.isOnlyMonasteryCrime or false
		values.importance = values.importance or 0
		values.reportMoveSpeed = values.reportMoveSpeed or 1
		values.reportMetaroleFirstBark = values.reportMetaroleFirstBark or ''
		values.reportMetarole = values.reportMetarole or 'VOLANI_STRAZE'
		values.reportAlwaysMove = values.reportAlwaysMove or false
		values.fine = values.fine or 0
		values.jail = values.jail or 0
		values.confiscation = values.confiscation or false
		values.expiration = values.expiration or 0
		values.useGenericLineInConfrontationDialog = values.useGenericLineInConfrontationDialog or false
		values.gracePeriod = values.gracePeriod or 0
		values.maxConfronters = values.maxConfronters or 2

		result[label] = values
	end

	addLabel('alert',
			 {
				 isCrime = false,
				 expiration = 60
			 })

	addLabel('assault',
			 {
				 isCrime = true,
				 produceInformationStimulus = true,
				 civiliansAutoReactWithinDistance = 2,
				 civiliansCanReactWithinDistance = 8,
				 reputationHitName = 'assault',
				 resolvedByCircators = true,
				 importance = 50,
				 reportMetarole = 'NASILI_POPLACH',
				 reportMetaroleFirstBark = 'NASILI_UTEK',
				 reportAlwaysMove = true,
				 reportMoveSpeed = 2,
				 fine = 800,
				 jail = 5,
				 expiration = 3 * 3600,
			 })

	addLabel('assist',
			 {
				 isCrime = false
			 })

	addLabel('combat',
			 {
				 isCrime = false,
				 expiration = 60
			 })

	addLabel('corpse',
			 {
				 isCrime = false,
				 produceInformationStimulus = true,
				 civiliansAutoReactWithinDistance = 2,
				 civiliansCanReactWithinDistance = 8,
				 reportMetarole = 'VOLANI_STRAZE_MRTVOLA',
				 reportMetaroleFirstBark = 'UVIDI_MRTVOLU',
			 })

	addLabel('carriedCorpse',
			 {
				 isCrime = true,
				 produceInformationStimulus = true,
				 civiliansAutoReactWithinDistance = 2,
				 reputationHitName = 'carriedCorpse',
				 importance = 80,
				 reportMoveSpeed = 2,
				 jail = 7,
				 expiration = 4 * 3600
			 })

	addLabel('hafhaf',
			 {
				 isCrime = false
			 })

	addLabel('lockpick',
			 {
				 isCrime = true,
				 produceInformationStimulus = true,
				 reputationHitName = 'lockpick',
				 resolvedByCircators = true,
				 reportMetarole = 'VOLANI_STRAZE_KRADEZ',
				 reportMetaroleFirstBark = 'REAKCE_NA_KRADEZ',
				 importance = 30,
				 fine = 600,
				 jail = 3,
				 confiscation = true,
				 expiration = 2 * 3600
			 })

	addLabel('mon_assault',
			 {
				 resolvedByCircators = true,
				 isOnlyMonasteryCrime = true
			 })

	addLabel('mon_equipWeapon',
			 {
				 resolvedByCircators = true,
				 isOnlyMonasteryCrime = true
			 })

	addLabel('mon_goToChurch',
			 {
				 resolvedByCircators = true,
				 isOnlyMonasteryCrime = true
			 })

	addLabel('mon_outsideMonastery',
			 {
				 resolvedByCircators = true,
				 isOnlyMonasteryCrime = true
			 })

	addLabel('mon_robe',
			 {
				 resolvedByCircators = true,
				 isOnlyMonasteryCrime = true
			 })

	addLabel('mon_slacking',
			 {
				 resolvedByCircators = true,
				 isOnlyMonasteryCrime = true
			 })

	addLabel('mon_trespass',
			 {
				 resolvedByCircators = true,
				 isOnlyMonasteryCrime = true
			 })

	addLabel('mon_workInFrateria',
			 {
				 resolvedByCircators = true,
				 isOnlyMonasteryCrime = true
			 })

	addLabel('mon_workInLibrary',
			 {
				 resolvedByCircators = true,
				 isOnlyMonasteryCrime = true
			 })

	addLabel('murder',
			 {
				 isCrime = true,
				 produceInformationStimulus = true,
				 civiliansAutoReactWithinDistance = 3,
				 civiliansCanReactWithinDistance = 12,
				 reactorsAutoSuccessCount = 2,
				 reactorsChanceDecreasePerEachExtra = 0.4,
				 reputationHitName = 'murder',
				 reportMetarole = 'VOLANI_STRAZE_VRAZDA',
				 reportMetaroleFirstBark = 'REAKCE_NA_VRAZDU',
				 reportAlwaysMove = true,
				 importance = 100,
				 reportMoveSpeed = 2,
				 jail = 7,
				 maxConfronters = 3
			 })

	addLabel('refuseFrisk',
			 {
				 isCrime = true,
				 produceInformationStimulus = true,
				 reputationHitName = 'refuseFrisk',
				 importance = 20,
				 fine = 300,
				 jail = 1,
				 expiration = 2 * 3600,
				 useGenericLineInConfrontationDialog = true
			 })

	addLabel('shotAt',
			 {
				 isUnattributedCrime = true,
				 produceInformationStimulus = true,
				 civiliansAutoReactWithinDistance = 2,
				 expiration = 360
			 })

	addLabel('sneak',
			 {
				 isCrime = true,
				 produceInformationStimulus = true,
				 reputationHitName = 'sneak',
				 importance = 10,
				 fine = 100,
				 jail = 1,
				 expiration = 1 * 3600,
				 gracePeriod = 300,
				 maxConfronters = 1
			 })

	addLabel('theft',
			 {
				 isCrime = true,
				 produceInformationStimulus = true,
				 civiliansCanReactWithinDistance = 5,
				 reputationHitName = 'theft',
				 resolvedByCircators = true,
				 reportMetarole = 'VOLANI_STRAZE_KRADEZ',
				 reportMetaroleFirstBark = 'REAKCE_NA_KRADEZ',
				 importance = 40,
				 fine = 600,
				 jail = 3,
				 confiscation = true,
				 expiration = 3 * 3600
			 })

	addLabel('theftExPost',
			 {
				 isUnattributedCrime = true,
				 produceInformationStimulus = true,
				 soldiersMaxResponderCount = 1,
				 reportMetarole = 'VOLANI_STRAZE_KE_KRADEZI_POZDE'
			 })

	addLabel('threat',
			 {
				 produceInformationStimulus = true,
				 expiration = 600
			 })

	addLabel('trespass',
			 {
				 isCrime = true,
				 produceInformationStimulus = true,
				 reputationHitName = 'theft',
				 importance = 40,
				 fine = 150,
				 jail = 1,
				 expiration = 1 * 3600,
				 gracePeriod = 12
			 })

	addLabel('unattributedAssault',
			 {
				 isUnattributedCrime = true,
				 produceInformationStimulus = true,
				 soldiersMaxResponderCount = 2
			 })

	addLabel('weapon',
			 {
				 isCrime = true,
				 produceInformationStimulus = true,
				 importance = 20,
				 fine = 200,
				 jail = 1,
				 expiration = 1 * 3600,
				 maxConfronters = 1
			 })

	return result
end

function CrimeUtils.SendMercyDialogResult (entity, enumValueName)
	local type = 'combat:mercy:dialogResult'
	local content = strFormat('outcome($enum:combatMercyOutcome.%s)', enumValueName)
	entity.soul:RestrictDialog(true)

	XGenAIModule.SendMessageToEntity(entity.this.id, type, content)
end

function CrimeUtils.ProduceAiSoundOnDudePosition (soundKind, bonusPerStealthSkill)
	local stealth = player.soul:GetSkillLevel('stealth')
	local multiplier = 1 - stealth * bonusPerStealthSkill

	XGenAIModule.ProduceSoundWUID(soundKind, player.this.id, multiplier)
end

function CrimeUtils.CalcPayToTalkPrice (entity)
	local socialClassData = SocialClass.GetEntitySocialClassData(entity)
	local socialClassPriceMod = socialClassData.persuadeToTalkWithLowReputationPriceMultiplier
	local price = 700 * socialClassPriceMod
	price = math.max(math.round(price / 10) * 10, 10)

	return price
end

function CrimeUtils.IncreasePayToTalkReputation (entity)
	local soul = assert(entity.soul, 'Provided entity does not have a soul')
	for _ = 1, 4 do
		soul:ModifyPlayerReputation('payToTalk')
		if soul:GetRelationship(player.this.id, 'Current') >= 0.2 then
			return
		end
	end

	TError('Pay-to-talk: unable to increase reputation above the required level.')
end

function CrimeUtils.DetermineSuspiciousDealReaction (entity)
	local reaction = Variables.GetGlobal('haggle_suspiciousness_reaction')

	local socialClassData = SocialClass.GetEntitySocialClassData(entity)
	local dealsWithStolenItems = socialClassData.dealsWithStolenItems

	if reaction <= 0 then
		return
	end

	Variables.SetGlobal('haggle_suspiciousness_reaction', pick(dealsWithStolenItems, 1, 2))
end

function CrimeUtils.BuildLockpickPromptStrName (lockDifficulty)
	local levels = {
		{ minLockDifficulty = 0.75, strName = 'ui_hud_lockpick_difficulty_4' },
		{ minLockDifficulty = 0.5, strName = 'ui_hud_lockpick_difficulty_3' },
		{ minLockDifficulty = 0.35, strName = 'ui_hud_lockpick_difficulty_2' },
		{ minLockDifficulty = 0, strName = 'ui_hud_lockpick_difficulty_1' }
	}

	for _, level in ipairs(levels) do
		if lockDifficulty >= level.minLockDifficulty then
			return level.strName
		end
	end

	return 'ui_hud_lockpick'
end

function CrimeUtils.CanPickLock(skillLevel, lockDifficulty)
	local skillRating = skillLevel / 20.0

	if skillRating >= 0.75 and lockDifficulty <= 1.00
			or skillRating >= 0.50 and lockDifficulty < 0.75
			or skillRating >= 0.35 and lockDifficulty < 0.5
			or skillRating >= 0.00 and lockDifficulty <= 0.30 then
		return true
	end

	return false
end

function CrimeUtils.TryToAutoUnlock(entity, user)
	local enableLockpickRequired = true
	local enableLockpickBreaking = true
	local enableSkillRequired = true
	local enableAutoOpen = true

	-- TODO: check for location or quest to avoid running code needlessly
	-- bug fix: require minigame for Dance with the Devil
	local q_devilplay_animals = {'4727b250-e2a5-8142-8801-a12efa52f2a9', '4a982c9a-f084-10f6-8bcb-892b575d6f93', '4d14c21e-cb5d-2466-9303-66c50a3e6691', '4d6a13d7-8ff1-f2fe-c6ce-14d84ba6db9c'}
	for _, value in next, q_devilplay_animals do
		if value == entity.id then
			Minigame.StartLockPicking(entity.id)
			return
		end
	end

	local skillLevel = user.soul:GetSkillLevel('lockpicking')
	local lockDifficulty = entity:GetLockDifficulty()

	-- vanilla reward xp formula - thanks to Warhorse developer "Bart"
	local rewardXP = RPG.LockPickingSuccessXPMulCoef * (lockDifficulty + 1) / (RPG.LockPickingSuccessXPDivCoef * skillLevel + 1)

	-- bug fix: circumvent miller peshek lockpicking tutorial
	QuestSystem.CompleteObjective('q_package', 'lockpickTutorial')
	Tutorial.Complete('lockpicking')

	if enableLockpickRequired then
		if not Utils.HasItem(user, Utils.itemIDs.lockpick) then
			Game.SendInfoText('@dlg_lp_cannotStart', true)
			return
		end
	end

	if enableSkillRequired then
		local canAutoUnlock = CrimeUtils.CanPickLock(skillLevel, lockDifficulty)

		if not canAutoUnlock then
			Minigame.StartLockPicking(entity.id)
			return
		end
	end

	if enableLockpickBreaking then
		-- roll for chance to keep lockpick
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
	CrimeUtils.ProduceAiSoundOnDudePosition(enum_sound.door, 0.03)
	BroadcastEvent(entity, 'Unlock')

	if enableAutoOpen then
		entity:OnUsed(user)
		BroadcastEvent(entity, 'Open')
	end

	-- at max skill, show success message but don't reward xp
	if skillLevel ~= RPG.SkillCap then
		user.soul:AddSkillXP('lockpicking', rewardXP)
	end

	if user.soul:GetSkillLevel('stealth') ~= RPG.SkillCap then
		user.soul:AddSkillXP('stealth', RPG.LockPickingStealthXP)
	end

	Game.SendInfoText('@ui_hud_lp_success', true)
end
