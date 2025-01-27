dofile_once("data/scripts/lib/utilities.lua")

dofile_once("mods/noita-together/files/scripts/utils.lua")
dofile_once("mods/noita-together/files/scripts/json.lua")
local entity_id = GetUpdatedEntityID()
local x, y = EntityGetTransform(entity_id)

-- tags -> card_actions | tablet | wand | item_physics
local card_actions = EntityGetWithTag("card_action")
local wands = EntityGetWithTag("wand")
local flasks = EntityGetWithTag("item_physics")
if (#card_actions > 0) then
    local collected = false
    local tx = 0
    local ty = 0
    for i, spell_id in ipairs(card_actions) do
        local in_world = false
        local components = EntityGetComponent(spell_id, "SimplePhysicsComponent")

        if (components ~= nil) then
            in_world = true
        end
        tx, ty = EntityGetTransform(spell_id)

        if in_world then
            local distance = math.abs(x - tx) + math.abs(y - ty)
            if (distance < 24) then
                local item_component = EntityGetFirstComponent(spell_id, "ItemActionComponent")
                local action_id = ComponentGetValue2(item_component, "action_id")
                NT.spell_queue = NT.spell_queue .. action_id .. ","

                EntityLoad("data/entities/particles/poof_pink.xml", tx, ty)
                collected = true
                EntityKill(spell_id)
            end
        end
    end
end
if (#wands > 0 and #NT.wand_queue == 0 and GameHasFlagRun("can_send_wands")) then
    local wand = nil
    local wand_sprite = nil
    for _, wand_id in ipairs(wands) do
        local in_world = false
        local components = EntityGetComponent(wand_id, "SimplePhysicsComponent")
        if (components ~= nil) then
            in_world = true
        end

        tx, ty = EntityGetTransform(wand_id)
        if (in_world and wand == nil) then
            local distance = math.abs(x - tx) + math.abs(y - ty)
            if (distance < 24) then
                local ability_comp = EntityGetFirstComponentIncludingDisabled(wand_id, "AbilityComponent")
                local sprite = ComponentGetValue2(ability_comp, "sprite_file")
                local sprite_id = string.match(sprite, "wand_([0-9]+)")
                if (sprite_id ~= nil) then
                    wand_sprite = tonumber(sprite_id) + 1
                    wand = wand_id
                end
            end
        end
    end

    if wand ~= nil then
        local serialized = {}

        local ability_comp = EntityGetFirstComponentIncludingDisabled(wand, "AbilityComponent")

        serialized.sprite = wand_sprite
        serialized.mana = ComponentGetValue2(ability_comp, "mana")
        serialized.ui_name = ComponentGetValue2(ability_comp, "ui_name")
        serialized.mana_max = ComponentGetValue2(ability_comp, "mana_max")
        serialized.mana_charge_speed = ComponentGetValue2(ability_comp, "mana_charge_speed")

        serialized.reload_time = ComponentObjectGetValue2(ability_comp, "gun_config", "reload_time")
        serialized.actions_per_round = ComponentObjectGetValue2(ability_comp, "gun_config", "actions_per_round")
        serialized.deck_capacity = ComponentObjectGetValue2(ability_comp, "gun_config", "deck_capacity")
        serialized.shuffle_deck_when_empty = ComponentObjectGetValue2(ability_comp, "gun_config", "shuffle_deck_when_empty")

        serialized.spread_degrees = ComponentObjectGetValue2(ability_comp, "gunaction_config", "spread_degrees")
        serialized.speed_multiplier = ComponentObjectGetValue2(ability_comp, "gunaction_config", "speed_multiplier")
        serialized.fire_rate_wait = ComponentObjectGetValue2(ability_comp, "gunaction_config", "fire_rate_wait")

        local childs = EntityGetAllChildren(wand)
        local always_cast = {}
        local deck = {}
        if childs ~= nil then
            for _, child in ipairs(childs) do
                local item_comp = EntityGetFirstComponentIncludingDisabled(child, "ItemComponent")
                local item_component = EntityGetFirstComponentIncludingDisabled(child, "ItemActionComponent")
                local is_always_cast = ComponentGetValue2(item_comp, "permanently_attached")
                local action_id = ComponentGetValue2(item_component, "action_id")
                if (is_always_cast) then
                    table.insert(always_cast, action_id)
                else
                    table.insert(deck, action_id)
                end
            end
        end

        NT.wand_queue = json.encode({serialized, always_cast, deck})
        --[[
        local queue = json.decode(NT.wand_player_queue)
        table.insert(queue, json.decode(NT.wand_queue))
        NT.wand_player_queue = json.encode(queue)
        ]]
        EntityLoad("data/entities/particles/poof_pink.xml", x, y)
        EntityKill(wand)
    end
elseif (#wands > 0 and #NT.wand_queue > 0 and GameHasFlagRun("can_send_wands")) then
    local wand = nil

    for _, wand_id in ipairs(wands) do
        local in_world = false
        local components = EntityGetComponent(wand_id, "SimplePhysicsComponent")
        if (components ~= nil) then
            in_world = true
        end

        tx, ty = EntityGetTransform(wand_id)
        if (in_world and wand == nil) then
            local distance = math.abs(x - tx) + math.abs(y - ty)
            if (distance < 24) then
                wand = wand_id
            end
        end
    end

    if wand ~= nil then
        GamePrint("ONLY ONE WAND")
    end
end

if (#flasks > 0 and #NT.item_queue == 0 and GameHasFlagRun("can_send_items")) then
    local flask = nil
    local flask_inventory = nil
    for _, flask_id in ipairs(flasks) do
        local in_world = false
        local components = EntityGetComponent(flask_id, "PhysicsBodyComponent")
        local inventory = EntityGetFirstComponentIncludingDisabled(flask_id, "MaterialInventoryComponent")
        if (components ~= nil and inventory ~= nil) then
            in_world = true
        end

        tx, ty = EntityGetTransform(flask_id)
        if (in_world and flask == nil) then
            local distance = math.abs(x - tx) + math.abs(y - ty)
            if (distance < 24) then
                flask = flask_id
                flask_inventory = inventory
            end
        end
    end

    if flask ~= nil then
        local count_per_material_type = ComponentGetValue2(flask_inventory, "count_per_material_type")
        local serialized = {}
        for k, v in pairs(count_per_material_type) do
            if v ~= 0 then
                table.insert( serialized, {v, k-1} )
            end
        end

        NT.item_queue = json.encode(serialized)
        --GamePrint(NT.item_queue)
        EntityLoad("data/entities/particles/poof_pink.xml", x, y)
        EntityKill(flask)
    end
elseif (#flasks > 0 and #NT.item_queue > 0 and GameHasFlagRun("can_send_items")) then
    local flask = nil
    local flask_inventory = nil
    for _, flask_id in ipairs(flasks) do
        local in_world = false
        local components = EntityGetComponent(flask_id, "PhysicsBodyComponent")
        local inventory = EntityGetFirstComponentIncludingDisabled(flask_id, "MaterialInventoryComponent")
        if (components ~= nil and inventory ~= nil) then
            in_world = true
        end

        tx, ty = EntityGetTransform(flask_id)
        if (in_world and flask == nil) then
            local distance = math.abs(x - tx) + math.abs(y - ty)
            if (distance < 24) then
                flask = flask_id
                flask_inventory = inventory
            end
        end
    end

    if flask ~= nil then
        GamePrint("ONLY ONE FLASK")
    end
end
