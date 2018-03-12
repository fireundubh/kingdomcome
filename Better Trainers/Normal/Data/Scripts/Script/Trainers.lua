
Trainers = {}

Trainers.__data__ =
{
	tiers = 4,

	skillLevelThresholds =
	{
		1, 6, 11, 16
	},

	skills =
	{
		['alchemy'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['defense'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['herbalism'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['horse_riding'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['hunter'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['lockpicking'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['pickpocketing'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['repairing'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['stealth'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['weapon_axe'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['weapon_bow'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['weapon_large'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['weapon_mace'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['weapon_sword'] =
		{
			price = { 600, 1800, 5400, 16200 }
		},

		['weapon_unarmed'] =
		{
			price = { 600, 1800, 5400, 16200 }
		}
	}
}

function Trainers.setContextSkill(skill)
	Trainers.skill = skill
end

function Trainers.setContextTrainer(trainer)
	Trainers.trainer = trainer
end

function Trainers.getContextSkill()
	return assert(Trainers.skill, "Trainers: Invalid context skill")
end

function Trainers.getContextTrainer()
	return assert(Trainers.trainer, "Trainers: Invalid context trainer")
end

function Trainers.buildGlobalVarName(skill, tier)
	return strFormat('trainers_lessonLearned_%s_%d', skill, tier)
end

function Trainers.exp_hasLessonStillAvailable(tier)
	tier = tonumber(tier)

	local skill = Trainers.getContextSkill()
	local varName = Trainers.buildGlobalVarName(skill, tier)

	local var = Variables.GetGlobal(varName)

	local tierLevel = Trainers.__data__.skillLevelThresholds[tier]
	local playerSkillLevel = player.soul:GetSkillLevel(skill)

	if var == 0 and playerSkillLevel < tierLevel then
		return 1
	else
		return 0
	end
end

function Trainers.exp_hasAnyLessonAvailableForSkill(skill)
	for tier = 1, Trainers.__data__.tiers do
		local varName = Trainers.buildGlobalVarName(skill, tier)
		local var = Variables.GetGlobal(varName)

		local tierLevel = Trainers.__data__.skillLevelThresholds[tier]
		local playerSkillLevel = player.soul:GetSkillLevel(skill)

		if var == 0 and playerSkillLevel < tierLevel then
			return 1
		end
	end

	return 0
end

function Trainers.exp_meetsLevelRequirementToTrainLesson(tier)
	return 1
end

function Trainers.calcLessonPrice(tier)
	local skill = Trainers.getContextSkill()

	local skillData = assert(Trainers.__data__.skills[skill], strFormat("No trainer data for skill '%s'", skill))
  return skillData.price[tier]
end

function Trainers.showLessonPrice(tier)
	local price = Trainers.calcLessonPrice(tier)

	Variables.SetGlobal('dlg_crimeFineAmount', price / 10)
	Variables.SetGlobal('dlg_crimeFineShown', 1)

	Utils.SetLocalVar('price', price)
end

function Trainers.clearShownLessonPrice()
	Variables.SetGlobal('dlg_crimeFineAmount', 0)
	Variables.SetGlobal('dlg_crimeFineShown', 0)
end

function Trainers.setupNegotiationForLesson(tier)
	local price = Trainers.calcLessonPrice(tier)
	NegotiationUtils.SetupNegotiation(NegotiationReason.Trainer, price, 0, 0, 0)
end

function Trainers.trainLesson(tier, price)
	tier = tonumber(tier)

	local skill = Trainers.getContextSkill()
	local trainer = Trainers.getContextTrainer()

	local varName = Trainers.buildGlobalVarName(skill, tier)
	Variables.SetGlobal(varName, 1)

	local tierLevel = Trainers.__data__.skillLevelThresholds[tier]

	player.soul:AdvanceToSkillLevel(skill, tierLevel)

	player.inventory:MoveItemOfClass(trainer.inventory:GetId(), Utils.itemIDs.money, price, true)

	XGenAIModule.SendMessageToEntity(player.this.id, 'trainers:faderRequest', '')

	RPG.NotifyLevelXpGain(skill)
end
