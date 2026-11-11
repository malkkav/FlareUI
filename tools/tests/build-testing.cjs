// Exercise the generated addon artifact, including its name, load paths and isolation boundary.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'flare-chat-build-'));
try {
  execFileSync(process.execPath, [path.join(root, 'tools/build-testing.js'), temp, 'FlareUI_Chat'], {stdio:'pipe'});
  const addon = path.join(temp, 'FlareUI_Chat');
  assert(fs.existsSync(addon), 'custom addon folder must use requested name');
  const toc = fs.readFileSync(path.join(addon, 'FlareUI_Chat.toc'), 'utf8');
  assert.match(toc, /^## Title: FlareUI_Chat$/m);
  assert.match(toc, /^## SavedVariables: FlareUI_Chat2_DB, FlareUI_Chat_DB$/m);
  assert.match(toc, /^## OptionalDeps: FlareUI, FlareUI_Testing$/m);
  assert(!/^## X-(Curse|Wago)/m.test(toc), 'test addon must not be associated with production updater');
  for (const line of toc.split(/\r?\n/).map(l=>l.trim())) {
    if (line && !line.startsWith('#')) assert(fs.existsSync(path.join(addon,line.replaceAll('\\','/'))), `missing TOC file ${line}`);
  }
  for (const file of ['Modules/ChatBuilder.lua','Settings/ChatBuilder.lua','Media/Borders/FlareUI_Chat-Thin.tga']) assert(fs.existsSync(path.join(addon,file)),file);
  assert(!fs.existsSync(path.join(addon,'docs')));
  assert(!fs.existsSync(path.join(addon,'tools')));
  const core = fs.readFileSync(path.join(addon,'Core.lua'),'utf8');
  assert(core.includes('FlareUI_Chat2_DB'));
  const launcher = fs.readFileSync(path.join(addon,'Launcher.lua'),'utf8');
  assert(launcher.includes('"/flareuichat"') && launcher.includes('"/fuichat"'), 'chat test commands must be distinct');
  assert(!launcher.includes('"/fui"') && !launcher.includes('"/rl"'));
  const bootstrap = path.join(addon,'TestingBootstrap.lua');
  const probe = path.join(temp,'check-bootstrap.lua');
  fs.writeFileSync(probe, `
local loaded = arg[2]
C_AddOns = {IsAddOnLoaded=function(name) return name==loaded end}
CreateFrame=function() return {SetScript=function() end,RegisterEvent=function() end} end
local ns={}
assert(loadfile(arg[1]))('FlareUI_Chat',ns)
assert(ns.testingBlocked == (loaded~='none'))
if ns.testingBlocked then
  -- The guarded module must return before it touches any uninitialized game globals.
  assert(loadfile(arg[3]))('FlareUI_Chat',ns)
  assert(ns.ChatBuilder==nil)
end
`);
  for (const loaded of ['none','FlareUI','FlareUI_Testing']) {
    execFileSync('luajit',[probe,bootstrap,loaded,path.join(addon,'Modules/ChatBuilder.lua')],{stdio:'pipe'});
  }
  const parser = path.join(temp,'parse-artifact.lua');
  fs.writeFileSync(parser,'for _,file in ipairs(arg) do assert(loadfile(file)) end\n');
  const luaFiles=[];
  function collect(dir) {
    for (const entry of fs.readdirSync(dir,{withFileTypes:true})) {
      const file=path.join(dir,entry.name);
      if (entry.isDirectory()) collect(file);
      else if (file.endsWith('.lua')) luaFiles.push(file);
    }
  }
  collect(addon);
  execFileSync('luajit',[parser,...luaFiles],{stdio:'pipe'});
  execFileSync(process.execPath,[path.join(root,'tools/build-testing.js'),path.join(temp,'default')],{stdio:'pipe'});
  const defaultToc=fs.readFileSync(path.join(temp,'default/FlareUI_Testing/FlareUI_Testing.toc'),'utf8');
  assert.match(defaultToc,/^## SavedVariables: FlareUI_Testing2_DB, FlareUI_Testing_DB$/m);
  assert.throws(()=>execFileSync(process.execPath,[path.join(root,'tools/build-testing.js'),temp,'FlareUI'],{stdio:'pipe'}));
  console.log('PASS: FlareUI_Chat package identity, TOC paths, commands, saved variables, and runtime isolation');
} finally {
  const resolved=path.resolve(temp);
  assert.equal(path.dirname(resolved),path.resolve(os.tmpdir()));
  assert(path.basename(resolved).startsWith('flare-chat-build-'));
  fs.rmSync(resolved,{recursive:true,force:true});
}
