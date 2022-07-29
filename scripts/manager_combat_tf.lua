--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

local customSortOriginal;
local isActorToSkipTurnOriginal;
local onTurnEndEventOriginal;
local addNPCOriginal;
local rollEntryInitOriginal;

function onInit()
	customSortOriginal = CombatManager.getCustomSort();
	if customSortOriginal then
		-- Perhaps in the future it might be worth creating the logic branches to play
		-- nicely with the simple sort, but right now it cuts out too much else.
		CombatManager.setCustomSort(customSort);
	end
	isActorToSkipTurnOriginal = CombatManager.isActorToSkipTurn;
	CombatManager.isActorToSkipTurn = isActorToSkipTurn;
	onTurnEndEventOriginal = CombatManager.onTurnEndEvent;
	CombatManager.onTurnEndEvent = onTurnEndEvent;

	if "5E" == Session.RulesetName then
		rollEntryInitOriginal = CombatManager2.rollEntryInit;
		CombatManager2.rollEntryInit = rollEntryInit;
	end

	if Session.IsHost then
		DB.addHandler(CombatManager.CT_COMBATANT_PATH .. ".effects", "onChildUpdate", onCombatantEffectUpdated);
		DB.addHandler(CombatManager.CT_COMBATANT_PATH .. ".initresult", "onUpdate", onCombatantInitiativeUpdated);
	end
end

function customSort(node1, node2)
	local bHost = Session.IsHost;
	local sOptCTSI = OptionsManager.getOption("CTSI");
	if (not bHost) or (sOptCTSI ~= "on") then
		-- Not much to do if initiative isn't being shown anyway.
		return customSortOriginal(node1, node2);
	end

	local nodeOverride1, nodeOverride2, bAfter1, bAfter2, nFixed1, nFixed2;
	local rOverride1 = getInitOverride(node1);
	local rOverride2 = getInitOverride(node2);

	if rOverride1 then
		nodeOverride1 = rOverride1.node;
		bAfter1 = rOverride1.bAfter;
		nFixed1 = rOverride1.nInit;
	end
	if rOverride2 then
		nodeOverride2 = rOverride2.node;
		bAfter2 = rOverride2.bAfter;
		nFixed2 = rOverride2.nInit;
	end

	if nodeOverride1 then
		if nodeOverride1 == node2 then
			return not bAfter1;
		elseif nodeOverride2 then
			if nodeOverride1 == nodeOverride2 then
				if bAfter1 == bAfter2 then
					return customSortOriginal(node1, node2);
				else
					return not bAfter1;
				end
			else
				return customSort(nodeOverride1, nodeOverride2);
			end
		else
			return customSort(nodeOverride1, node2);
		end
	elseif nodeOverride2 then
		if node1 == nodeOverride2 then
			return bAfter2;
		else
			return customSort(node1, nodeOverride2);
		end
	elseif nFixed1 then
		if nFixed2 then
			if nFixed1 == nFixed2 then
				return customSortOriginal(node1, node2);
			else
				return nFixed1 < nFixed2;
			end
		else
			local nInit = DB.getValue(node2, "initresult", 0);
			return nFixed1 <= nInit;
		end
	elseif nFixed2 then
		local nInit = DB.getValue(node1, "initresult", 0);
		return nInit < nFixed2;
	end

	return customSortOriginal(node1, node2);
end

function getInitOverride(nodeCombatant)
	local rEffect = getEffect(nodeCombatant, {"AFTERTURN", "BEFORETURN", "SHARETURN"});
	if rEffect then
		return buildLinkedOverride(rEffect);
	end

	rEffect = getEffect(nodeCombatant, {"FIXINIT"})
	if rEffect then
		return buildFixedOverride(rEffect);
	end
end

function getEffect(nodeCombatant, aEffects)
	for _,nodeEffect in pairs(DB.getChildren(nodeCombatant, "effects")) do
		local nActive = DB.getValue(nodeEffect, "isactive", 0);
		if nActive == 1 then
			local sLabel = DB.getValue(nodeEffect, "label", "");
			local aEffectComps = EffectManager.parseEffect(sLabel);
			for _,sEffectComp in ipairs(aEffectComps) do
				local aParts = StringManager.split(sEffectComp, ":", true);
				if #aParts > 0 and StringManager.contains(aEffects, aParts[1]) then
					return {
						node = nodeEffect,
						sName = aParts[1],
						sRemainder = aParts[2],
					};
				end
			end
		end
	end
end

function buildLinkedOverride(rEffect)
	local nodeOverride;
	local aTargets = EffectManager.getEffectTargets(rEffect.node);
	if #aTargets == 1 then
		nodeOverride = DB.findNode(aTargets[1]);
	else
		local sSource = DB.getValue(rEffect.node, "source_name", "");
		if sSource ~= "" then
			nodeOverride = DB.findNode(sSource);
		end
	end

	if nodeOverride then
		return {
			node = nodeOverride,
			bAfter = rEffect.sName == "AFTERTURN",
		};
	end
end

function buildFixedOverride(rEffect)
	local aParts = StringManager.split(rEffect.sRemainder, ",", true);
	if #aParts > 0 then
		return {
			nInit = tonumber(aParts[1]),
		};
	end
end

function isActorToSkipTurn(nodeEntry)
	local result = isActorToSkipTurnOriginal(nodeEntry);
	if not result then
		local rActor = ActorManager.resolveActor(nodeEntry);
		if EffectManager.hasEffect(rActor, "SHARETURN") then
			CombatManager.onTurnStartEvent(nodeEntry);
			result = true;
		end
	end
	return result;
end

function onTurnEndEvent(nodeCT)
	if nodeCT then
		for _,nodeEntry in ipairs(CombatManager.getSortedCombatantList()) do
			local nodeSearch = nodeEntry;
			while nodeSearch do
				local nodeFound;
				local rEffect = getEffect(nodeSearch, {"SHARETURN"});
				if rEffect then
					local rOverride = buildLinkedOverride(rEffect);
					if rOverride then
						nodeFound = rOverride.node;
					end
				end
				if nodeFound == nodeCT then
					onTurnEndEventOriginal(nodeEntry);
					break;
				end
				nodeSearch = nodeFound;
			end
		end
	end
	onTurnEndEventOriginal(nodeCT);
end

function rollEntryInit(nodeEntry)
	local sOptINIT = OptionsManager.getOption("INIT");
	if sOptINIT == "roll" then
		local rActor = ActorManager.resolveActor(nodeEntry);
		local bSecret = CombatManager.isCTHidden(nodeEntry);
		ActionInit.performRoll(nil, rActor, bSecret);
	else
		rollEntryInitOriginal(nodeEntry);
	end
end

function onCombatantEffectUpdated(nodeEffectList)
	local nodeCombatant = nodeEffectList.getParent();
	local rOverride;
	local bHasOverride = false;
	local nodeCurrent = nodeCombatant;
	while nodeCurrent do
		rOverride = getInitOverride(nodeCurrent);
		if rOverride then
			bHasOverride = true;
			nodeCurrent = rOverride.node;
		else
			break;
		end
	end

	local nTargetInit = DB.getValue(nodeCombatant, "initresult", 0);
	if rOverride then
		nTargetInit = rOverride.nInit;
	elseif nodeCurrent then
		nTargetInit = DB.getValue(nodeCurrent, "initresult", 0);
	end

	DB.setValue(nodeCombatant, "initresult", "number", nTargetInit);
	DB.setStatic(DB.getPath(nodeCombatant, "initresult"), bHasOverride);
end

function onCombatantInitiativeUpdated(nodeInit)
	local nodeCombatant = nodeInit.getParent();
	for _,nodeEntry in ipairs(CombatManager.getSortedCombatantList()) do
		if nodeEntry ~= nodeCombatant then
			local rOverride = getInitOverride(nodeEntry);
			if rOverride and (nodeCombatant == rOverride.node) then
				DB.setValue(nodeEntry, "initresult", "number", nodeInit.getValue());
			end
		end
	end
end