local fake = require('tests.ashita');
local lang = require('lib.core.lang');

-- A resource as Ashita returns it: Name[] slots Default / Japanese / English.
local function res(en, ja)
    return { Name = { en, ja, en } };
end

local function reset()
    fake.reset();
    local r = fake.state.resources;
    r.spells['Cure'] = res('Cure', 'ケアル');
    r.spells["Knight's Minne"] = res("Knight's Minne", '騎士のミンネ');
    r.abilities['Troubadour'] = res('Troubadour', 'トルバドゥール');
    r.abilities['Foot Kick'] = res('Foot Kick', 'フットキック');
    r.abilities['Blank'] = res('Blank', '');
    r.items['Echo Drops'] = res('Echo Drops', 'やまびこ薬');
    r.items['Pet Food Alpha'] = res('Pet Food Alpha', 'ペットフードα');
end

test('English and unset language pass the command through untouched', function()
    reset();
    assert_eq(lang.translate('/ja "Troubadour" <me>', 'en'), '/ja "Troubadour" <me>');
    assert_eq(lang.translate('/ja "Troubadour" <me>', nil), '/ja "Troubadour" <me>');
end);

test('a spell name is swapped for its Japanese name, target kept', function()
    reset();
    assert_eq(lang.translate('/ma "Cure" <p1>', 'ja'), '/ma "ケアル" <p1>');
end);

test('job and pet abilities resolve against the ability table', function()
    reset();
    assert_eq(lang.translate('/ja "Troubadour" <me>', 'ja'), '/ja "トルバドゥール" <me>');
    assert_eq(lang.translate('/pet "Foot Kick" <t>', 'ja'), '/pet "フットキック" <t>');
end);

test('items resolve for /item and /equip, keeping the slot and bag number', function()
    reset();
    assert_eq(lang.translate('/item "Echo Drops" <me>', 'ja'), '/item "やまびこ薬" <me>');
    assert_eq(lang.translate('/equip ammo "Pet Food Alpha" 0', 'ja'), '/equip ammo "ペットフードα" 0');
end);

test('a name with pattern characters translates', function()
    reset();
    assert_eq(lang.translate('/ma "Knight\'s Minne" <me>', 'ja'), '/ma "騎士のミンネ" <me>');
end);

test('the verb picks the table: a spell name sent as /ja is not translated', function()
    reset();
    assert_eq(lang.translate('/ja "Cure" <me>', 'ja'), '/ja "Cure" <me>');
end);

test('unknown names, empty resource names and unquoted commands fall back to English', function()
    reset();
    assert_eq(lang.translate('/ma "Custom Spell" <me>', 'ja'), '/ma "Custom Spell" <me>');
    assert_eq(lang.translate('/ja "Blank" <me>', 'ja'), '/ja "Blank" <me>');
    assert_eq(lang.translate('/follow Tester', 'ja'), '/follow Tester');
    assert_eq(lang.translate('/debuff 409', 'ja'), '/debuff 409');
end);

test('a language with no resource slot falls back to English', function()
    reset();
    assert_eq(lang.translate('/ma "Cure" <me>', 'fr'), '/ma "Cure" <me>');
end);
