import {requireConfig,unwrap} from './supabase.js';
export async function requireAdmin() {
 const db=requireConfig();
 const {data:{user},error}=await db.auth.getUser();
 if(error||!user) { location.replace('login.html');return null; }
 const profile=unwrap(await db.from('profiles').select('role,display_name').eq('id',user.id).maybeSingle());
 if(profile?.role!=='admin') { await db.auth.signOut();throw new Error('此账号尚未获得管理员权限，请联系项目管理员。'); }
 return user;
}
export async function login(email,password) {
 const db=requireConfig();unwrap(await db.auth.signInWithPassword({email,password}));
 const {data:{user}}=await db.auth.getUser();
 const profile=unwrap(await db.from('profiles').select('role').eq('id',user.id).maybeSingle());
 if(profile?.role!=='admin') {await db.auth.signOut();throw new Error('账号没有管理员权限');}
 location.replace('./#/dashboard');
}
