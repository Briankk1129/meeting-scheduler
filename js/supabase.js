import {config} from './config.js';
export const configured=Boolean(config.supabaseUrl && config.publishableKey);
export const db=configured && globalThis.supabase ? globalThis.supabase.createClient(config.supabaseUrl,config.publishableKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:false}}) : null;
export function requireConfig() {
 if(!configured) throw new Error('系统尚未连接数据库，请按 README 配置 js/config.js。');
 if(!db) throw new Error('认证组件加载失败，请刷新页面。');
 return db;
}
export function unwrap({data,error}) {
 if(error) {
  const friendly={'23503':'该记录存在关联数据。请先移除关联，或使用停用保留历史。','23505':'记录已存在，请检查重复月份、时间段或固定安排。','42501':'当前账号没有操作权限。','23514':'输入不符合要求，请检查日期、姓名或人数上限。'};
  throw new Error(friendly[error.code]||error.message);
 }
 return data;
}
