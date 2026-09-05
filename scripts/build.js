import {cp,mkdir,rm,writeFile,readFile,readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
await rm(root+'dist',{recursive:true,force:true});await mkdir(root+'dist',{recursive:true});
for(const name of ['index.html','admin','css','js','vendor'])await cp(root+name,root+'dist/'+name,{recursive:true});
async function files(dir){let out=[];for(const e of await readdir(dir,{withFileTypes:true})){const p=dir+'/'+e.name;out.push(...(e.isDirectory()?await files(p):[p]));}return out.sort();}
const scripts=await files(root+'dist/js'),hash=createHash('sha256');for(const f of scripts)hash.update(await readFile(f));hash.update(await readFile(root+'dist/css/style.css'));const version=hash.digest('hex').slice(0,12);
for(const f of scripts){let s=await readFile(f,'utf8');s=s.replace(/(from\s*|import\s*\(\s*|import\s*)(['"`])([^'"`]+\.js)\2/g,(_,a,q,path)=>`${a}${q}${path}?v=${version}${q}`);await writeFile(f,s);}
for(const f of [root+'dist/index.html',...(await files(root+'dist/admin')).filter(f=>f.endsWith('.html'))]){let s=await readFile(f,'utf8');s=s.replace(/((?:src|href)="[^"?]+\.(?:js|css))"/g,`$1?v=${version}"`);await writeFile(f,s);}
await writeFile(root+'dist/.nojekyll','');
console.log('Built dist/ with versioned assets: '+version);
