--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

local handleCombatAddInitDnDOriginal;

function onInit()
	handleCombatAddInitDnDOriginal = CombatRecordManager.handleCombatAddInitDnD;
	CombatRecordManager.handleCombatAddInitDnD = handleCombatAddInitDnD;
end

function handleCombatAddInitDnD(tCustom)
	local nDex = DB.getValue(tCustom.nodeRecord, "abilities.dexterity.score", 10);
	local nDexMod = math.floor((nDex - 10) / 2);
	local tempInit = DB.getValue(tCustom.nodeRecord, "inittemporary", 0);
	DB.setValue(tCustom.nodeCT, "init", "number", nDexMod + tempInit);

	local sOptINIT = OptionsManager.getOption("INIT");
	if sOptINIT == "roll" then
		local rActor = ActorManager.resolveActor(tCustom.nodeCT);
		local bSecret = CombatManager.isCTHidden(tCustom.nodeCT);
		ActionInit.performRoll(nil, rActor, bSecret);
	else
		handleCombatAddInitDnDOriginal(tCustom);
	end
end