// Build an isolated local-test addon. Never edits the source checkout or the live installation.
// Usage: node tools/build-testing.js <output-parent>
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
if (!process.argv[2]) throw new Error('Supply an output parent directory');
const dest = path.join(path.resolve(process.argv[2]), 'FlareUI_Testing');
if (fs.existsSync(dest)) throw new Error(`Destination already exists: ${dest}`);
const exclude = new Set(['.git', '.github', '.agents', 'docs', 'tools', 'AGENTS.md',
  'README.md', 'CHANGELOG.md', 'CHANGELOG-history.md', '.pkgmeta', '.gitignore', '.gitattributes']);
const rename = s => s.replaceAll('FlareUI', 'FlareUI_Testing').replaceAll('FLAREUI', 'FLAREUI_TESTING')
  .replaceAll('FlareEditMode', 'FlareEditMode_Testing');
const guard = 'local _, testingNS = ...\nif testingNS and testingNS.testingBlocked then return end\n';
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
        text = text.replaceAll('/flareui', '/flareuitest').replace(/\/fui\b/g, '/fuitest');
        // Do not shadow the usual /rl alias even in the isolated build.
        text = text.replaceAll('FLARERL', 'FLARERL_TESTING').replaceAll('"/rl"', '"/rltest"');
        if (entry.name.endsWith('.lua')) text = guard + text;
        if (entry.name === 'FlareUI.toc') {
          text = text.replace(/^## Version: (.+)$/m, '## Version: $1-testing');
          text = '## OptionalDeps: FlareUI\n' + text;
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
ns.testingBlocked = C_AddOns.IsAddOnLoaded("FlareUI") and true or false
if ns.testingBlocked then
    local f = CreateFrame("Frame")
    f:SetScript("OnEvent", function()
        print("|cffffd100FlareUI_Testing:|r Disable FlareUI on this character and reload to test. The testing addon did not initialize.")
    end)
    f:RegisterEvent("PLAYER_LOGIN")
end
`);
console.log(`Built ${count + 1} files in ${dest}`);
