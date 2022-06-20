--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	if "5E" == Session.RulesetName then
		OptionsManager.addOptionValue("INIT", "option_val_roll_all", "roll", true);
	end
end