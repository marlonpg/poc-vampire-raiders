package com.vampireraiders.systems;

import com.vampireraiders.database.InventoryRepository;
import com.vampireraiders.database.ItemModRepository;
import com.vampireraiders.database.WorldItemRepository;
import com.vampireraiders.util.Logger;

/**
 * Service for handling item mods and upgrades (e.g., applying jewels, leveling items)
 */
public class ModsService {

    /**
     * Apply Jewel of Strength to a target item, upgrading its LEVEL mod.
     * 
     * @param playerId Player ID
     * @param jewelInventoryId Inventory ID of the jewel to consume
     * @param targetInventoryId Inventory ID of the item to upgrade
     * @return true if upgrade succeeded, false otherwise
     */
    public static boolean applyJewelOfStrength(int playerId, long jewelInventoryId, long targetInventoryId) {
        // Get jewel and target items from inventory
        var jewel = InventoryRepository.getInventoryItemForPlayerById(playerId, jewelInventoryId);
        var target = InventoryRepository.getInventoryItemForPlayerById(playerId, targetInventoryId);
        
        if (jewel == null || target == null) {
            Logger.debug("APPLY_JEWEL: Invalid inventory items - jewel=" + (jewel != null ? "OK" : "NULL") + 
                         ", target=" + (target != null ? "OK" : "NULL"));
            return false;
        }

        // Validate jewel is actually a jewel
        String jewelType = (String) jewel.get("type");
        String jewelName = (String) jewel.get("name");
        if (!"jewel".equalsIgnoreCase(jewelType)) {
            Logger.debug("APPLY_JEWEL: inventory_id=" + jewelInventoryId + " is not a jewel (type=" + jewelType + ")");
            return false;
        }

        // Validate target is weapon, armor, gloves, or boots
        String targetType = (String) target.get("type");
        if (!"weapon".equalsIgnoreCase(targetType) && !"armor".equalsIgnoreCase(targetType) && 
            !"gloves".equalsIgnoreCase(targetType) && !"boots".equalsIgnoreCase(targetType)) {
            Logger.debug("APPLY_JEWEL: target inventory_id=" + targetInventoryId + " invalid type=" + targetType);
            return false;
        }

        // Only Jewel of Strength is supported: upgrades/adds LEVEL mod
        if (!"Jewel of Strength".equalsIgnoreCase(jewelName)) {
            Logger.debug("APPLY_JEWEL: unsupported jewel name=" + jewelName);
            return false;
        }

        // Get current level and max level for target item
        long targetWorldItemId = ((Number) target.get("world_item_id")).longValue();
        int currentLevel = ItemModRepository.getModValueForWorldItem(targetWorldItemId, "LEVEL");
        int maxLevel = ItemModRepository.getMaxModValue("LEVEL");
        
        if (maxLevel <= 0) {
            Logger.warn("APPLY_JEWEL: No LEVEL mods defined in mod_templates");
            return false;
        }

        // Calculate next level
        int nextLevel = currentLevel <= 0 ? 1 : (currentLevel + 1);
        if (nextLevel > maxLevel) {
            Logger.info("APPLY_JEWEL: Target already at max LEVEL (" + currentLevel + ") for world_item_id=" + targetWorldItemId);
            return false;
        }

        // Get mod template for next level
        Integer modTemplateId = ItemModRepository.getModTemplateId("LEVEL", nextLevel);
        if (modTemplateId == null) {
            Logger.warn("APPLY_JEWEL: Missing mod template for LEVEL=" + nextLevel);
            return false;
        }

        // Apply the mod
        boolean modOk = ItemModRepository.upsertWorldItemMod(targetWorldItemId, "LEVEL", modTemplateId);
        if (!modOk) {
            Logger.warn("APPLY_JEWEL: Failed to upsert LEVEL mod for world_item_id=" + targetWorldItemId);
            return false;
        }

        // Consume the jewel (decrement quantity or delete)
        int quantity = ((Number) jewel.get("quantity")).intValue();
        long jewelWorldItemId = ((Number) jewel.get("world_item_id")).longValue();

        if (quantity > 1) {
            InventoryRepository.decrementItemQuantity(jewelInventoryId);
        } else {
            InventoryRepository.deleteInventoryItem(jewelInventoryId);
            WorldItemRepository.deleteWorldItem(jewelWorldItemId);
        }

        Logger.info("APPLY_JEWEL: Player=" + playerId + " applied Jewel of Strength to inventory_id=" + targetInventoryId +
                " (world_item_id=" + targetWorldItemId + ") LEVEL " + currentLevel + " -> " + nextLevel);
        
        return true;
    }
}
