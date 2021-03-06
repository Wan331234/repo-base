-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local RSLootDB = private.NewLib("RareScannerLootDB")


---============================================================================
-- QuestIDs database
---============================================================================

function RSLootDB.GetAssociatedQuestIDs(itemID)
	if (itemID) then
		return private.LOOT_QUEST_IDS[itemID]
	end

	return nil
end

---============================================================================
-- Conduits database
---============================================================================

function RSLootDB.GetConduitInfo(itemID)
	if (itemID) then
		return private.CONDUITS[itemID]
	end

	return nil
end