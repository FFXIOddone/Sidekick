local fake = require('tests.ashita');

ImGuiPopupFlags_MouseButtonRight = 1;
ImGuiPopupFlags_NoOpenOverItems = 2;
ImGuiStyleVar_WindowPadding = 1;
ImGuiStyleVar_Alpha = 2;
ImGuiTreeNodeFlags_DefaultOpen = 1;
ImGuiCol_Header = 1;
ImGuiCol_HeaderHovered = 2;
ImGuiCol_HeaderActive = 3;
ImGuiCol_Button = 4;
ImGuiCol_ButtonHovered = 5;
ImGuiCol_ButtonActive = 6;
ImGuiCol_Tab = 7;
ImGuiCol_TabHovered = 8;
ImGuiCol_TabActive = 9;
ImGuiCol_TabUnfocused = 10;
ImGuiCol_TabUnfocusedActive = 11;
ImGuiCol_CheckMark = 12;
ImGuiCol_SliderGrab = 13;
ImGuiCol_SliderGrabActive = 14;
ImGuiWindowFlags_AlwaysAutoResize = 1;
ImGuiWindowFlags_NoResize = 2;
ImGuiWindowFlags_NoTitleBar = 4;
ImGuiTableFlags_Borders = 1;
ImGuiTableFlags_RowBg = 2;
ImGuiTableFlags_SizingFixedFit = 4;
ImGuiTableFlags_NoHostExtendX = 8;
ImGuiColorEditFlags_NoInputs = 1;

local common = require('lib.core.common');
local components = require('lib.ui.components');
local ui_config = require('lib.ui.config');

test('no saved accent leaves the current ImGui colors alone', function()
    fake.reset();
    local pushed = 0;
    fake.imgui = { PushStyleColor = function() pushed = pushed + 1; end };
    assert_eq(components.push_ui_accent({}), 0);
    components.pop_ui_accent(0);
    assert_eq(pushed, 0);
end);

test('custom accents are normalized and applied to UI controls', function()
    fake.reset();
    local settings = {};
    assert_eq(components.set_ui_accent_color(settings, { 1.2, -0.1, 0.5, 0.4 }), true);
    assert_eq(settings.ui_accent_color, { 1, 0, 0.5, 0.4 });
    assert_eq(components.get_ui_accent_color(settings), { 1, 0, 0.5, 0.4 });
    assert_eq(components.set_ui_accent_color(settings, { 0.1, 'bad', 0.2, 1 }), false);
    assert_eq(settings.ui_accent_color, { 1, 0, 0.5, 0.4 });

    local pushed, popped = {}, nil;
    fake.imgui = {
        PushStyleColor = function(color_id, color)
            pushed[#pushed + 1] = { color_id, color };
        end,
        PopStyleColor = function(count) popped = count; end,
    };
    local count = components.push_ui_accent({ ui_accent_color = { 0.2, 0.4, 0.8, 0.5 } });
    assert_eq(count, 14);
    assert_eq(#pushed, 14);
    assert_eq(pushed[1], { ImGuiCol_Header, { 0.2, 0.4, 0.8, 0.09 } });
    assert_eq(pushed[12], { ImGuiCol_CheckMark, { 0.2, 0.4, 0.8, 0.5 } });
    components.pop_ui_accent(count);
    assert_eq(popped, 14);

    settings.ui_accent_color = { 0.2, 0.4, 0.8, 0 / 0 };
    assert_eq(components.get_ui_accent_color(settings), nil);
end);

test('section headers retain their original colors until an accent is selected', function()
    fake.reset();
    local pushed = {};
    fake.imgui = {
        PushStyleColor = function(color_id, color)
            pushed[#pushed + 1] = { color_id, color };
        end,
        CollapsingHeader = function() return false; end,
    };

    local ctx = { settings = { display_mode = 'headers' } };
    components.begin_sections(ctx);
    components.begin_section(ctx, 'Auto Follow', 'follow_enabled', true);
    assert_eq(pushed, {
        { ImGuiCol_Header, { 0.2, 0.2, 0.2, 0.31 } },
        { ImGuiCol_HeaderHovered, { 0.2, 0.2, 0.2, 0.45 } },
        { ImGuiCol_HeaderActive, { 0.2, 0.2, 0.2, 0.65 } },
    });

    pushed = {};
    ctx = { settings = { display_mode = 'headers', ui_accent_color = { 0.2, 0.4, 0.8, 0.5 } } };
    components.begin_sections(ctx);
    components.begin_section(ctx, 'Auto Follow', 'follow_enabled', true);
    assert_eq(pushed, {
        { ImGuiCol_Header, { 0.2, 0.4, 0.8, 0.09 } },
        { ImGuiCol_HeaderHovered, { 0.2, 0.4, 0.8, 0.18 } },
        { ImGuiCol_HeaderActive, { 0.2, 0.4, 0.8, 0.27 } },
    });
end);

test('the /sk panel color editor saves a choice and can restore defaults', function()
    fake.reset();
    common.game_state = {
        refreshed_at = os.clock(),
        player = nil,
        party = {},
        tracked = {},
        stratagems = 0,
        ready_charges = 0,
    };
    bit = require('bit');

    local panel = require('lib.ui.panel');
    local settings, saves = {}, 0;
    panel.show();
    fake.imgui = {
        Begin = function() return true; end,
        BeginTable = function() return false; end,
        Checkbox = function() return false; end,
        IsItemHovered = function() return false; end,
        ColorEdit4 = function(label, color)
            if label ~= 'UI Accent Color' then return false; end
            color[1], color[2], color[3], color[4] = 0.2, 0.6, 0.4, 0.8;
            return true;
        end,
    };
    panel.render(settings, function() saves = saves + 1; end);
    assert_eq(settings.ui_accent_color, { 0.2, 0.6, 0.4, 0.8 });
    assert_eq(saves, 1);

    fake.imgui.Button = function(label) return label == 'Default UI Colors'; end;
    fake.imgui.ColorEdit4 = function() return false; end;
    panel.render(settings, function() saves = saves + 1; end);
    panel.hide();
    assert_eq(settings.ui_accent_color, nil);
    assert_eq(saves, 2);
end);

test('configuration and widget windows scope accent colors through guarded render errors', function()
    fake.reset();
    common.game_state = {
        refreshed_at = os.clock(),
        player = nil,
        party = {},
        tracked = {},
        stratagems = 0,
        ready_charges = 0,
    };

    local settings = { ui_accent_color = { 0.2, 0.4, 0.8, 0.5 } };
    local previous_errorf = common.errorf;
    local ok, err = pcall(function()
        common.errorf = function() end;

        local function assert_accent_scope(render)
            local pushed, popped, events = 0, {}, {};
            fake.imgui = {
                PushStyleColor = function() pushed = pushed + 1; end,
                PopStyleColor = function(count)
                    popped[#popped + 1] = count;
                    events[#events + 1] = 'PopStyleColor';
                end,
                PushStyleVar = function() events[#events + 1] = 'PushStyleVar'; end,
                PopStyleVar = function() events[#events + 1] = 'PopStyleVar'; end,
                SetNextWindowCollapsed = function() end,
                SetNextWindowFocus = function() end,
                Begin = function() events[#events + 1] = 'Begin'; return true; end,
                End = function() events[#events + 1] = 'End'; end,
                Button = function()
                    events[#events + 1] = 'BodyError';
                    error('simulated guarded render error');
                end,
            };

            local render_ok, render_err = pcall(render);
            assert(render_ok, tostring(render_err));
            assert_eq(pushed, 14, 'each window should apply all accent style colors');
            assert_eq(popped, { 14 }, 'each window should pop its full accent style scope');
            assert_eq(events, {
                'PushStyleVar', 'Begin', 'BodyError', 'End', 'PopStyleVar', 'PopStyleColor',
            }, 'accent colors should remain scoped until the window body has unwound');
        end;

        if ui_config.is_widget_visible() then ui_config.toggle_widget(); end;
        ui_config.show();
        assert_accent_scope(function() ui_config.render(settings, nil); end);
        ui_config.hide();

        if not ui_config.is_widget_visible() then ui_config.toggle_widget(); end;
        assert_accent_scope(function() ui_config.render_widget(settings, nil); end);
        ui_config.toggle_widget();
    end);

    common.errorf = previous_errorf;
    if ui_config.is_visible() then ui_config.hide(); end
    if ui_config.is_widget_visible() then ui_config.toggle_widget(); end
    assert(ok, tostring(err));
end);

fake.reset();
