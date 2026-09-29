--[[
    Command language
    Rewrites the spell/ability/item name inside a game command into the client's
    language, so a Japanese client runs /ja "Troubadour" <me> as
    /ja "トルバドゥール" <me>. Names come from Ashita's resource manager (the client
    DATs), already in the game's own encoding, so no name tables are kept here.
    Job files keep writing English commands; automation.execute_command translates
    right before QueueCommand.
]]--

local common = require('lib.core.common')

local lang = {}

-- Language code -> Name[] slot of an Ashita resource (Default, Japanese, English).
lang.NAME_INDEX = { ja = 2 }

local ENGLISH = 2  -- Ashita langId for English (0 Default, 1 Japanese, 2 English)

-- Command verb -> resource manager lookup for its quoted name.
local LOOKUP = {
    ma = 'GetSpellByName',
    ja = 'GetAbilityByName', pet = 'GetAbilityByName',
    item = 'GetItemByName', equip = 'GetItemByName',
}

-- Translate the first quoted name in a command into language `code`.
-- Args: command (string) - '/ma "Cure" <p1>', '/equip ammo "X" 0', ...
--       code (string|nil) - settings.command_language ('en', 'ja')
-- Returns: string - the translated command, or the original when there is nothing
--          to translate or no native name is known (unknown/custom name, language
--          without a resource slot).
function lang.translate(command, code)
    if not code or code == 'en' then return command end

    local method = LOOKUP[command:match('^/(%a+)') or '']
    local open = command:find('"', 1, true)
    local close = open and command:find('"', open + 1, true)
    if not method or not close then return command end

    local name = command:sub(open + 1, close - 1)
    local index = lang.NAME_INDEX[code]
    local native
    -- Ashita resources carry only English and Japanese names.
    if index then
        local ok, res = pcall(function()
            local rm = AshitaCore:GetResourceManager()
            return rm[method](rm, name, ENGLISH)
        end)
        native = ok and res and res.Name and res.Name[index]
    end

    if not native or native == '' then
        common.debugf('[LANG] No %s name for "%s"; sending English', code, name)
        return command
    end
    return command:sub(1, open) .. native .. command:sub(close)
end

return lang
