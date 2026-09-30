local fake = require('tests.ashita');
local lang = require('lib.core.lang');

-- A resource as Ashita's Lua binding returns it: Name[] slots 0 Default, 1 English, 2 Japanese.
local function res(en, ja)
    return { Name = { [0] = en, en, ja } };
end

-- Fresh fake with a few named resources, on a Japanese client.
local function reset()
    fake.reset();
    lang.japanese = true;
    local r = fake.state.resources;
    r.spells['Cure'] = res('Cure', 'ケアル');
    r.spells["Knight's Minne"] = res("Knight's Minne", '騎士のミンネ');
    r.abilities['Troubadour'] = res('Troubadour', 'トルバドゥール');
    r.abilities['Foot Kick'] = res('Foot Kick', 'フットキック');
    r.abilities['Blank'] = res('Blank', '');
    r.items['Echo Drops'] = res('Echo Drops', 'やまびこ薬');
    r.items['Pet Food Alpha'] = res('Pet Food Alpha', 'ペットフードα');
end

test('an English client passes the command through untouched', function()
    reset();
    lang.japanese = false;
    assert_eq(lang.translate('/ja "Troubadour" <me>'), '/ja "Troubadour" <me>');
end);

test('a spell name is swapped for its Japanese name, target kept', function()
    reset();
    assert_eq(lang.translate('/ma "Cure" <p1>'), '/ma "ケアル" <p1>');
end);

test('job and pet abilities resolve against the ability table', function()
    reset();
    assert_eq(lang.translate('/ja "Troubadour" <me>'), '/ja "トルバドゥール" <me>');
    assert_eq(lang.translate('/pet "Foot Kick" <t>'), '/pet "フットキック" <t>');
end);

test('items resolve for /item and /equip, keeping the slot and bag number', function()
    reset();
    assert_eq(lang.translate('/item "Echo Drops" <me>'), '/item "やまびこ薬" <me>');
    assert_eq(lang.translate('/equip ammo "Pet Food Alpha" 0'), '/equip ammo "ペットフードα" 0');
end);

test('a name with pattern characters translates', function()
    reset();
    assert_eq(lang.translate('/ma "Knight\'s Minne" <me>'), '/ma "騎士のミンネ" <me>');
end);

test('the verb picks the table: a spell name sent as /ja is not translated', function()
    reset();
    assert_eq(lang.translate('/ja "Cure" <me>'), '/ja "Cure" <me>');
end);

test('unknown names, empty resource names and unquoted commands fall back to English', function()
    reset();
    assert_eq(lang.translate('/ma "Custom Spell" <me>'), '/ma "Custom Spell" <me>');
    assert_eq(lang.translate('/ja "Blank" <me>'), '/ja "Blank" <me>');
    assert_eq(lang.translate('/follow Tester'), '/follow Tester');
    assert_eq(lang.translate('/debuff 409'), '/debuff 409');
end);

test('gather alert phrase follows the client language', function()
    reset();
    -- 集まってください。 in Shift-JIS, the game's chat encoding.
    local ja = '\x8f\x57\x82\xdc\x82\xc1\x82\xc4\x82\xad\x82\xbe\x82\xb3\x82\xa2\x81\x42  ';
    -- A bare name tries spells, then abilities, and stays English when unknown.
    assert_eq(lang.gather('Cure'), ja .. 'ケアル');
    assert_eq(lang.gather('Troubadour'), ja .. 'トルバドゥール');
    assert_eq(lang.gather('Custom Spell'), ja .. 'Custom Spell');
    lang.japanese = false;
    assert_eq(lang.gather('Cure'), 'Gather together for Cure');
end);
