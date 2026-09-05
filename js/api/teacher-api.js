import {config} from '../config.js';
export async function portal(token,slots,revision) {
 if(!config.supabaseUrl||!config.publishableKey) throw new Error('填写入口尚未启用，请联系管理员。');
 const response=await fetch(config.supabaseUrl+'/functions/v1/teacher-portal',{
  method:'POST',headers:{'Content-Type':'application/json','apikey':config.publishableKey},cache:'no-store',
  body:JSON.stringify({token,action:slots===undefined?'read':'submit',slots,revision})
 });
 const data=await response.json();if(!response.ok) throw new Error(data.error||'提交失败，请重试');return data;
}
