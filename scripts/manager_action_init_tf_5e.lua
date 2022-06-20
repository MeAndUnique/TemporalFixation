--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

local performRollOriginal;

function onInit()
	performRollOriginal = ActionInit.performRoll;
	ActionInit.performRoll = performRoll;
end

function performRoll(draginfo, rActor, bSecretRoll)
	local nodeCombatant = ActorManager.getCTNode(rActor);
	if nodeCombatant and CombatManagerTF.getInitOverride(nodeCombatant) then
		local sFormat = Interface.getString("message_ovderridden_init");
		local sMsg = string.format(sFormat, rActor.sName);
		ChatManager.SystemMessage(sMsg);
	else
		performRollOriginal(draginfo, rActor, bSecretRoll);
	end
end