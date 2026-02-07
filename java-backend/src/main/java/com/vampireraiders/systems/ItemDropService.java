package com.vampireraiders.systems;

import com.vampireraiders.database.EnemyItemRepository;
import com.vampireraiders.database.ItemTemplateRepository;
import com.vampireraiders.database.WorldItemRepository;
import com.vampireraiders.game.EnemyItem;
import com.vampireraiders.game.ItemTemplate;
import com.vampireraiders.game.WorldItem;
import com.vampireraiders.util.Logger;

import java.util.List;
import java.util.Random;

public class ItemDropService {
    private static final Random RANDOM = new Random();

    public WorldItem dropFromEnemy(int enemyTemplateId, float x, float y, String mapId) {
        List<EnemyItem> possibleDrops = EnemyItemRepository.getDropsForEnemy(enemyTemplateId);
        if (possibleDrops.isEmpty()) {
            Logger.warn("No drops configured for enemy template " + enemyTemplateId);
            return null;
        }

        // Roll for each possible drop based on drop rate
        double roll = RANDOM.nextDouble() * 100.0; // 0.0 to 100.0
        Logger.debug("DROP: enemyTemplate=" + enemyTemplateId + ", roll=" + roll + ", options=" + possibleDrops.size());
        double cumulative = 0.0;
        
        for (EnemyItem drop : possibleDrops) {
            cumulative += drop.getDropRate();
            Logger.debug("  - checking itemTemplate=" + drop.getItemTemplateId() + ", rate=" + drop.getDropRate() + ", cumulative=" + cumulative);
            if (roll <= cumulative) {
                // This item dropped!
                List<ItemTemplate> templates = ItemTemplateRepository.getCache();
                ItemTemplate template = templates.stream()
                    .filter(t -> t.getId() == drop.getItemTemplateId())
                    .findFirst()
                    .orElse(null);
                    
                if (template == null) {
                    Logger.warn("Item template " + drop.getItemTemplateId() + " not found");
                    return null;
                }
                
                WorldItem worldItem = WorldItemRepository.createWorldItem(template.getId(), x, y);
                if (worldItem != null) {
                    worldItem.setTemplateName(template.getName());
                    worldItem.setItemType(template.getType());
                    worldItem.setMapId(mapId);
                }
                return worldItem;
            }
        }
        
        // No drop (roll exceeded total drop rates)
        Logger.debug("DROP: no item rolled (roll=" + roll + ", total=" + cumulative + ")");
        return null;
    }
}
