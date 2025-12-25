package com.vampireraiders.systems;

import com.vampireraiders.database.ItemTemplateRepository;
import com.vampireraiders.database.WorldItemRepository;
import com.vampireraiders.game.ItemTemplate;
import com.vampireraiders.game.WorldItem;
import com.vampireraiders.util.Logger;

public class ItemDropService {

    public WorldItem dropAt(float x, float y) {
        ItemTemplate template = ItemTemplateRepository.getRandomTemplate();
        if (template == null) {
            Logger.warn("No item templates loaded; skipping drop");
            return null;
        }
        WorldItem worldItem = WorldItemRepository.createWorldItem(template.getId(), x, y);
        if (worldItem != null) {
            worldItem.setTemplateName(template.getName());
        }
        return worldItem;
    }
}
