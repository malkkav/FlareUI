// Run from the repository root: node tools/tests/chinese-locales.js
// Check the Chinese strings that are loaded by Locale.lua, including the runtime
// formatting tokens whose loss can break a message rather than just its wording.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const assignment = /^L\["((?:\\.|[^"\\])*)"\]\s*=\s*(true|"((?:\\.|[^"\\])*)")\s*$/gm;
const decode = (value) => JSON.parse('"' + value + '"');
const errors = [];

function entries(locale) {
  const source = fs.readFileSync(path.join(root, 'Locales', `${locale}.lua`), 'utf8');
  const values = new Map();
  assignment.lastIndex = 0;
  for (const match of source.matchAll(assignment)) {
    const key = decode(match[1]);
    if (values.has(key)) errors.push(`${locale}: duplicate key ${JSON.stringify(key)}`);
    values.set(key, match[2] === 'true' ? true : decode(match[3]));
  }
  return values;
}

const english = entries('enUS');
const required = new Set([
  'Welcome to FlareUI!',
  'Everything starts switched off. This short tour shows you what each part does, and you choose the ones you want as you go.',
  'Show Me Around',
  "Skip, I know what I'm doing",
  'Use the Game Language',
  'Match the language selected in World of Warcraft.',
  'When and Where',
  'Consumables',
  'Food and Flask',
]);
// The guided setup is the first screen new users see. Keep every literal
// phrase in it translated when the tour changes, not just its title/buttons.
const tourSource = fs.readFileSync(path.join(root, 'Settings', 'Welcome.lua'), 'utf8');
const tourReferences = /\bL\["((?:\\.|[^"\\])*)"\]/g;
for (const match of tourSource.matchAll(tourReferences)) required.add(decode(match[1]));

const tokens = {
  format: /%(?:[-+0#]*\d*(?:\.\d+)?[cdiouxXeEfgGqs%])/g,
  named: /\{[A-Za-z][A-Za-z0-9_]*\}/g,
  colours: /\|c[0-9a-fA-F]{8}|\|r/g,
  commands: /\/(?:fui(?:\s+(?:cm|errors(?:\s+clear)?|pad|scale(?:\s+reset)?|tour))?|way|oom|reload|rl|cheer|macro)\b/g,
  hotkeys: /\b(?:Ctrl|Alt|Shift|Esc)\b/g,
  product: /\bFlareUI\b/g,
  newline: /\n/g,
};
const properNames = {
  zhCN: { Mankrik: '曼科里克', Garrosh: '加尔鲁什', Deadmines: '死亡矿井', Goldshire: '闪金镇', Deathknell: '丧钟镇', 'Carrot on a Stick': '棍子上的胡萝卜', 'Argent Dawn': '银色黎明', 'Fingers of Frost': '寒冰指', 'Ice Lance': '冰枪术', 'Wild Thornroot': '野生棘根草', 'Arcane Powder': '魔粉', 'Well-Rested': '精神饱满', Sated: '心满意足', Maul: '槌击', Cleave: '顺劈斩', 'Raptor Strike': '猛禽一击', 'Soul Shards': '灵魂碎片' },
  zhTW: { Mankrik: '曼寇里克', Garrosh: '卡爾洛斯', Deadmines: '死亡礦坑', Goldshire: '閃金鎮', Deathknell: '喪鐘鎮', 'Carrot on a Stick': '棍子上的胡蘿蔔', 'Argent Dawn': '銀色黎明', 'Fingers of Frost': '冰霜之指', 'Ice Lance': '冰霜長矛', 'Wild Thornroot': '野生棘根草', 'Arcane Powder': '魔粉', 'Well-Rested': '充分休息', Sated: '精神亢奮', Maul: '槌擊', Cleave: '順劈斬', 'Raptor Strike': '猛禽一擊', 'Soul Shards': '靈魂裂片' },
};

for (const locale of ['zhCN', 'zhTW']) {
  const values = entries(locale);
  for (const key of english.keys()) {
    if (!values.has(key)) errors.push(`${locale}: missing English key ${JSON.stringify(key)}`);
  }
  for (const key of required) {
    if (!values.has(key) || values.get(key) === key) {
      errors.push(`${locale}: missing translation for ${JSON.stringify(key)}`);
    }
  }
  const linkedTip = values.get('Where it shows is set by Consumables on the When and Where tab, as for Food and Flask.');
  for (const label of ['When and Where', 'Consumables', 'Food and Flask']) {
    const translatedLabel = values.get(label);
    if (translatedLabel && linkedTip && !linkedTip.includes(translatedLabel)) {
      errors.push(`${locale}: the consumables tip does not match the displayed ${JSON.stringify(label)} label`);
    }
  }
  // These descriptions direct the player to a named tab, so the translated
  // tab name needs to match the one shown in the UI.
  const namedLabels = [
    ['On a ready check, every reminder glows for a few seconds and the sound plays.', 'Ready Check'],
    ['Shows the Fake CM bars and makes them clickable, so you can place spells.', 'Fake CM'],
    ['Always clears the others; nothing ticked means Always. Fake CM Setup Mode always shows them.', 'Fake CM Setup Mode'],
    ['A sound as Pull Warning starts, so you hear it without watching the meter.', 'Pull Warning'],
    ['Needs Pull Warning. It plays once each time, and never while you hold the mob.', 'Pull Warning'],
    ['A new one hides on every frame. Its Hide On list below picks where.', 'Hide On'],
    ['Behind Bars needs FlareUI\'s action bars on.', 'Behind Bars'],
    ["Items that bind when equipped show BoE in the top left corner, until they're bound.", 'BoE'],
    ["The meter is in the chat's Meter tab: it fades with the chat.", 'Meter'],
    ["The tank's row on the Threat tab shows how far it is ahead of second place, after its own numbers, like \"100% (+25%)\".", 'Threat'],
    ["The tank's row on the Threat tab shows how far it is ahead of second place, like \"+25%\".", 'Threat'],
    ['What the Threat tab shows beside each name.', 'Threat'],
    ["When the Meter tab opens on its own.\n* When Clicked: only when you click it\n* In Combat: during fights, back to the chat after\n* In a Group: while you're in a group\n* At Login: it starts open", 'Meter'],
    ['With the Meter tab in the chat, the meter fades with the chat.', 'Meter'],
    ["A roll you pass on leaves the window. The icon at the top opens Blizzard's loot history. Placed and scaled in Edit Mode as \"FlareUI Loot Rolls\".", 'FlareUI Loot Rolls'],
    ['With Better Player Names, a colon after the name, like "[Aria]: hello".', 'Better Player Names'],
    ["Pick each seal's colour in Bar Colours.", 'Bar Colours'],
    ["Pick each timer's colour in Bar Colours.", 'Bar Colours'],
    ['While Heroic Strike, Cleave, Maul or Raptor Strike waits for the next swing, the bar takes its colour (set in Bar Colours).', 'Bar Colours'],
  ];
  for (const [tip, label] of namedLabels) {
    if (values.has(tip) && values.has(label) && !values.get(tip).includes(values.get(label))) {
      errors.push(`${locale}: ${JSON.stringify(tip)} does not match the displayed ${JSON.stringify(label)} label`);
    }
  }
  const expectedPowerBar = locale === 'zhCN' ? '资源条' : '資源條';
  if (values.has('Power Bar') && !values.get('Power Bar').includes(expectedPowerBar)) {
    errors.push(`${locale}: Power Bar must describe the general resource bar, not a specific class resource`);
  }
  for (const [key, value] of values) {
    if (!english.has(key)) errors.push(`${locale}: unknown English key ${JSON.stringify(key)}`);
    if (typeof value !== 'string' || value.length === 0) {
      errors.push(`${locale}: empty or non-string translation for ${JSON.stringify(key)}`);
      continue;
    }
    for (const [kind, regex] of Object.entries(tokens)) {
      const expected = key.match(regex) || [];
      const actual = value.match(regex) || [];
      if (JSON.stringify(actual) !== JSON.stringify(expected)) {
        errors.push(`${locale}: ${kind} mismatch for ${JSON.stringify(key)}: ${JSON.stringify(expected)} -> ${JSON.stringify(actual)}`);
      }
    }
    for (const [source, localized] of Object.entries(properNames[locale])) {
      if (new RegExp(`\\b${source}\\b`).test(key) && !value.includes(localized)) {
        errors.push(`${locale}: expected ${JSON.stringify(localized)} in ${JSON.stringify(key)}`);
      }
    }
  }
  console.log(`${locale}: checked ${values.size} translations`);
}

assert.deepEqual(errors, [], errors.join('\n'));
