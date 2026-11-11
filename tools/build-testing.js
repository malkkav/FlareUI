// Build an isolated local-test addon. Never edits the source checkout or the live installation.
// Usage: node tools/build-testing.js <output-parent> [FlareUI_Testing|FlareUI_Chat]
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
if (!process.argv[2]) throw new Error('Supply an output parent directory');
const addonName = process.argv[3] || 'FlareUI_Testing';
if (!['FlareUI_Testing', 'FlareUI_Chat'].includes(addonName)) throw new Error('Use FlareUI_Testing or FlareUI_Chat');
const chatBuild = addonName === 'FlareUI_Chat';
const suffix = chatBuild ? 'Chat' : 'Testing';
const command = chatBuild ? 'chat' : 'test';
const conflicts = chatBuild ? ['FlareUI', 'FlareUI_Testing'] : ['FlareUI'];
const dest = path.join(path.resolve(process.argv[2]), addonName);
if (fs.existsSync(dest)) throw new Error(`Destination already exists: ${dest}`);
const exclude = new Set(['.git', '.github', '.agents', 'docs', 'tools', 'AGENTS.md',
  'README.md', 'CHANGELOG.md', 'CHANGELOG-history.md', '.pkgmeta', '.gitignore', '.gitattributes']);
const rename = s => s.replaceAll('FlareUI', addonName).replaceAll('FLAREUI', addonName.toUpperCase())
  .replaceAll('FlareEditMode', `FlareEditMode_${suffix}`);
// Keep guard locals out of the module's scope: some production chunks are at Lua's 200-local limit.
const guard = 'do\nlocal _, testingNS = ...\nif testingNS and testingNS.testingBlocked then return end\nend\n';
let count = 0;
function copy(dir, relative = '') {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (!relative && exclude.has(entry.name)) continue;
    const rel = path.join(relative, entry.name);
    if (rel.replaceAll('\\', '/') === 'Locales/enUS.lua') continue;
    const target = path.join(dest, rename(rel));
    if (entry.isDirectory()) { fs.mkdirSync(target, { recursive: true }); copy(path.join(dir, entry.name), rel); }
    else if (entry.isFile()) {
      fs.mkdirSync(path.dirname(target), { recursive: true });
      if (/\.(lua|xml|toc)$/i.test(entry.name)) {
        let text = rename(fs.readFileSync(path.join(dir, entry.name), 'utf8'));
        text = text.replaceAll('/flareui', `/flareui${command}`).replace(/\/fui\b/g, `/fui${command}`);
        // Do not shadow the usual /rl alias even in the isolated build.
        text = text.replaceAll('FLARERL', `FLARERL_${suffix.toUpperCase()}`).replaceAll('"/rl"', `"/rl${command}"`);
        if (entry.name.endsWith('.lua')) text = guard + text;
        if (entry.name === 'FlareUI.toc') {
          text = text.replace(/^## Version: (.+)$/m, `## Version: $1-${chatBuild ? 'chat-' : ''}testing`);
          text = `## OptionalDeps: ${conflicts.join(', ')}\n` + text;
          text = text.replace(/^LoadCheck.lua$/m, 'TestingBootstrap.lua\nLoadCheck.lua');
          // Separate development addon: no update-manager association with the production addon.
          text = text.replace(/^## X-(?:Curse-Project-ID|Wago-ID):.*\r?\n/gm, '');
        }
        fs.writeFileSync(target, text);
      } else fs.copyFileSync(path.join(dir, entry.name), target);
      count++;
    }
  }
}
copy(root);
fs.writeFileSync(path.join(dest, 'TestingBootstrap.lua'), `local _, ns = ...
-- OptionalDeps loads the production addon first when it is enabled. All subsequent Lua chunks
-- (including libraries) return before installing any hooks if production FlareUI is active.
ns.testingBlocked = (${conflicts.map(name => `C_AddOns.IsAddOnLoaded("${name}")`).join(' or ')}) and true or false
if ns.testingBlocked then
    local f = CreateFrame("Frame")
    f:SetScript("OnEvent", function()
        print("|cffffd100${addonName}:|r Disable ${conflicts.join(' and ')} on this character and reload to test. The testing addon did not initialize.")
    end)
    f:RegisterEvent("PLAYER_LOGIN")
end
`);
if (chatBuild) {
  fs.writeFileSync(path.join(dest, 'README-CHAT-TESTING.txt'), `FlareUI_Chat - isolated Chat Builder test build\n\n` +
    `Install this FlareUI_Chat folder in _forever_/Interface/AddOns.\n` +
    `Fully restart WoW after installing. Disable FlareUI and FlareUI_Testing for the test character, then enable FlareUI_Chat.\n` +
    `Open /flareuichat (or /fuichat), then Chat > Builder.\n` +
    `Chat filter changes apply immediately and are saved; no reload is needed.\n\n` +
    `Addon preferences use FlareUI_Chat2_DB and FlareUI_Chat_DB, separately from production FlareUI.\n` +
    `Blizzard's chat windows and filters remain the character's normal chat settings, shared when switching addons.\n` +
    `No presets are applied automatically. Existing windows are read when the builder opens.\n` +
    `To return to production, disable FlareUI_Chat and enable FlareUI.\n`);
  count++;
}
console.log(`Built ${count + 1} files in ${dest}`);
