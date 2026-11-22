// Replaces the bundled Custom Perks snapshot with an installed copy, then refreshes the manifest.
// Usage: node tests/refresh-baselines.cjs "<path to kronos/mods/custom_perks>"
// Copies mod.json, README.txt, scripts/*.gsc, lua/*.lua and images/*.png. Compiled caches (.gscc) are never copied.
const fs=require('fs'),path=require('path'),{execFileSync}=require('child_process');
const source=process.argv[2];
if(!source||!fs.existsSync(path.join(source,'mod.json')))throw Error('Pass the custom_perks folder (the one holding mod.json).');
const root=path.resolve(__dirname,'..'),target=path.join(root,'baselines','kronos','mods','custom_perks');
if(path.basename(target)!=='custom_perks')throw Error('Unexpected baseline folder');
fs.rmSync(target,{recursive:true,force:true});
const copy=(sub,ext)=>{const from=path.join(source,sub);if(!fs.existsSync(from))return 0;fs.mkdirSync(path.join(target,sub),{recursive:true});let n=0;for(const entry of fs.readdirSync(from,{withFileTypes:true}))if(entry.isFile()&&entry.name.toLowerCase().endsWith(ext)){fs.copyFileSync(path.join(from,entry.name),path.join(target,sub,entry.name));n++;}return n;};
fs.mkdirSync(target,{recursive:true});
for(const name of ['mod.json','README.txt'])if(fs.existsSync(path.join(source,name)))fs.copyFileSync(path.join(source,name),path.join(target,name));
console.log('Copied '+copy('scripts','.gsc')+' scripts, '+copy('lua','.lua')+' Lua files, '+copy('images','.png')+' images.');
execFileSync(process.execPath,[path.join(__dirname,'refresh-manifest.cjs')],{stdio:'inherit'});
console.log('Now run: node tests/generator.test.mjs');
