local Global = require 'utils.global'
local Gui = require 'utils.gui'
local Event = require 'utils.event'
local Command = require 'utils.command'
local set_players = rendering.set_players
local set_visible = rendering.set_visible
local is_valid = rendering.is_valid
local destroy = rendering.destroy
local pairs = pairs

------------------------------------ Data ------------------------------------

local grid_objects = {} -- [overlay_name][surface_index][x][y]
local indexed_objects = {} -- [overlay_name][surface_index][object_index]
local visibility = {}

local display_info = {}

Global.register(
    {
        grid_objects = grid_objects,
        indexed_objects = indexed_objects,
        visibility = visibility,
        display_info = display_info
    },
    function(tbl)
        grid_objects = tbl.grid_objects
        indexed_objects = tbl.indexed_objects
        visibility = tbl.visibility
        display_info = tbl.display_info
    end
)

------------------------------------ Logic ------------------------------------

local function get_grid_object(overlay_name, surface_index, x, y)
    local overlay_objects = grid_objects[overlay_name]
    -- note that other functions rely on this path-creating behaviour
    if not overlay_objects then
        overlay_objects = {}
        grid_objects[overlay_name] = overlay_objects
    end
    local surface_objects = overlay_objects[surface_index]
    if not surface_objects then
        surface_objects = {}
        overlay_objects[surface_index] = surface_objects
    end
    local x_objects = surface_objects[x]
    if not x_objects then
        x_objects = {}
        surface_objects[x] = x_objects
    end
    return x_objects[y]
end

local function get_or_create_grid_object(overlay_name, surface_index, x, y, draw_function, draw_args)
    local object = get_grid_object(overlay_name, surface_index, x, y)
    if object then
        return object, false
    else
        local player_list = visibility[overlay_name] or {}
        draw_args.players = player_list
        draw_args.visible = (#player_list > 0)
        object = draw_function(draw_args)
        grid_objects[overlay_name][surface_index][x][y] = object;
        return object, true
    end
end

local function add_grid_object(overlay_name, surface_index, x, y, object_id, replace)
    if not is_valid(object_id) then
        return false -- maybe cause an error instead
    end
    local old_object = get_grid_object(overlay_name, surface_index, x, y)
    if (not old_object) or replace then
        if old_object then
            destroy(old_object)
        end
        grid_objects[overlay_name][surface_index][x][y] = object_id
        local player_list = visibility[overlay_name] or {}
        local object_visible = (#player_list > 0)
        if object_visible then
            set_players(object_id, player_list)
        end
        set_visible(object_id, object_visible)
        return true
    end
    return false
end

local function destroy_grid_object(overlay_name, surface_index, x, y)
    local object = get_grid_object(overlay_name, surface_index, x, y)
    if object then
        destroy(object)
        grid_objects[overlay_name][surface_index][x][y] = nil
    end
end

local function get_indexed_object(overlay_name, surface_index, object_index)
    local overlay_objects = indexed_objects[overlay_name]
    -- note that other functions rely on this path-creating behaviour
    if not overlay_objects then
        overlay_objects = {}
        indexed_objects[overlay_name] = overlay_objects
    end
    local surface_objects = overlay_objects[surface_index]
    if not surface_objects then
        surface_objects = {}
        overlay_objects[surface_index] = surface_objects
    end
    return surface_objects[object_index]
end

local function get_or_create_indexed_object(overlay_name, surface_index, object_index, draw_function, draw_args)
    local object = get_indexed_object(overlay_name, surface_index, object_index)
    if object then
        return object, false
    else
        local player_list = visibility[overlay_name] or {}
        draw_args.players = player_list
        draw_args.visible = (#player_list > 0)
        object = draw_function(draw_args)
        indexed_objects[overlay_name][surface_index][object_index] = object;
        return object, true
    end
end

local function add_indexed_object(overlay_name, surface_index, object_index, object_id, delete_existing)
    if not is_valid(object_id) then
        return false-- maybe cause an error instead
    end
    local old_object = get_indexed_object(overlay_name, surface_index, object_index)
    if (not old_object) or delete_existing then
        if old_object then
            destroy(old_object)
        end
        indexed_objects[overlay_name][surface_index][object_index] = object_id
        local player_list = visibility[overlay_name] or {}
        local object_visible = (#player_list > 0)
        if object_visible then
            set_players(object_id, player_list)
        end
        set_visible(object_id, object_visible)
        return true
    end
    return false
end

local function destroy_indexed_object(overlay_name, surface_index, object_index)
    local object = get_indexed_object(overlay_name, surface_index, object_index)
    if object then
        destroy(object)
        indexed_objects[overlay_name][surface_index][object_index] = nil
    end
end

local function set_visibility(overlay_name, player_index, visible)
    -- Store visibility setting
    local player_list = visibility[overlay_name]
    if player_list then
        local found = nil
        for i = 1, #player_list do
            if player_list[i] == player_index then
                found = i
                break
            end
        end
        if visible and not found then
            player_list[#player_list + 1] = player_index
        elseif found and not visible then
            player_list[found] = player_list[#player_list]
            player_list[#player_list] = nil
        else -- nothing changed, so no need to update
            return
        end
    elseif visible then
        player_list = {player_index}
        visibility[overlay_name] = player_list
    else -- nothing changed, so no need to update
        return
    end
    -- Update visibility of objects
    local object_visible = (#player_list > 0)
    local overlay_objects = grid_objects[overlay_name]
    if overlay_objects then
        for _, surface_objects in pairs(overlay_objects) do
            for _, x_objects in pairs(surface_objects) do
                for _, object in pairs(x_objects) do
                    if object_visible then
                        set_players(object, player_list)
                    end
                    set_visible(object, object_visible)
                end
            end
        end
    end
    overlay_objects = indexed_objects[overlay_name]
    if overlay_objects then
        for _, surface_objects in pairs(overlay_objects) do
            for _, object in pairs(surface_objects) do
                if object_visible then
                    set_players(object, player_list)
                end
                set_visible(object, object_visible)
            end
        end
    end
end

local function get_visibility(overlay_name, player_index)
    local player_list = visibility[overlay_name]
    if player_list then
        for i = 1, #player_list do
            if player_list[i] == player_index then
                return true
            end
        end
    end
    return false
end

------------------------------------- GUI -------------------------------------

local panel_button_name = Gui.uid_name()
local main_frame_name = Gui.uid_name()
local checkbox_name = Gui.uid_name()

Event.add(defines.events.on_player_created, function(event)
    local player_index = event.player_index
    local gui = game.get_player(player_index).gui
    gui.top.add{
        type = 'sprite-button',
        name = panel_button_name,
        sprite = 'file/graphics/map-overlay-icon.png',
        style = 'icon_button',
        tooltip = {'map_overlay.tooltip'}
    }
    local main_frame = gui.left.add{
        type = 'frame',
        name = main_frame_name,
        caption = {'map_overlay.frame_caption'},
        direction = 'vertical',
        visible = false
    }
    local checkbox
    for overlay_name, caption in pairs(display_info) do
        checkbox = main_frame.add{
            type = 'checkbox',
            name = checkbox_name,
            caption = caption,
            state = get_visibility(overlay_name, player_index)
        }
        Gui.set_data(checkbox, {overlay_name = overlay_name})
    end
    main_frame.add{
        type = 'button',
        name = panel_button_name,
        caption = {'common.close_button'}
    }
end)

Gui.on_click(panel_button_name, function(event)
    local gui = event.player.gui
    local main_frame = gui.left[main_frame_name]
    local visible = not main_frame.visible
    main_frame.visible = visible
    local panel_button = gui.top[panel_button_name]
    if visible then -- button pressed down
        panel_button.style = 'selected_slot_button'
        local style = panel_button.style
        style.height = 38
        style.width = 38
    else -- button unpressed
        panel_button.style = 'icon_button'
    end
end)

Gui.on_click(checkbox_name, function(event)
    local this = event.element
    set_visibility(Gui.get_data(this).overlay_name, event.player_index, this.state)
end)

Gui.allow_player_to_toggle_top_element_visibility(panel_button_name) -- lets the player hide the button with the '<' button

local function set_visibility_update_gui(overlay_name, player_index, visible)
    set_visibility(overlay_name, player_index, visible)
    if display_info[overlay_name] then
        local main_frame = game.get_player(player_index).gui.left[main_frame_name]
        if main_frame then
            local children = main_frame.children
            for i = 1, #children do
                local child = children[i]
                if child.type == 'checkbox' and Gui.get_data(child).overlay_name == overlay_name then
                    child.state = visible
                    break
                end
            end
        end
    end
end

------------------------------------- CLI -------------------------------------

Command.add('redmew-overlay-visibility',
    {
        description = {'command_description.redmew_overlay_visibility'},
        arguments = {'overlay_name', 'value'},
        default_values = {value = 'nil'},
        debug_only = true,
        allowed_by_server = false
    },
    function(args, player)
        local overlay_name, value = args.overlay_name, args.value
        local player_index = player.index
        if value == 'true' then
            value = true
        elseif value == 'false' then
            value = false
        else
            value = not get_visibility(overlay_name, player_index)
        end
        set_visibility_update_gui(overlay_name, player_index, value)
    end
)

---------------------------------- Interface ----------------------------------

local Public = {
    get_grid_object = get_grid_object,
    get_or_create_grid_object = get_or_create_grid_object,
    add_grid_object = add_grid_object,
    destroy_grid_object = destroy_grid_object,

    get_indexed_object = get_indexed_object,
    get_or_create_indexed_object = get_or_create_indexed_object,
    add_indexed_object = add_indexed_object,
    destroy_indexed_object = destroy_indexed_object,

    set_visibility = set_visibility_update_gui,

    register_toggleable_overlay = function(overlay_name, localized_caption)
        if _LIFECYCLE ~= _STAGE.control then
            error('can only be called during the control stage', 2)
        end
        display_info[overlay_name] = localized_caption
    end
}

return Public

