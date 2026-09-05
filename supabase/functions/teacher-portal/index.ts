// Deliberately no administrator endpoint and no arbitrary table/query forwarding.
Deno.serve(async request => {
 const origin=request.headers.get('origin') || '';
 const allowed=(Deno.env.get('ALLOWED_ORIGINS') || '').split(',').map(x=>x.trim()).filter(Boolean);
 const cors={'Access-Control-Allow-Origin':allowed.length ? (allowed.includes(origin)?origin:allowed[0]) : '*','Access-Control-Allow-Headers':'content-type, apikey','Access-Control-Allow-Methods':'POST, OPTIONS','Vary':'Origin','Cache-Control':'no-store','Content-Type':'application/json'};
 const reply=(status,body)=>new Response(JSON.stringify(body),{status,headers:cors});
 if(allowed.length && origin && !allowed.includes(origin)) return reply(403,{error:'此网站尚未开放'});
 if(request.method==='OPTIONS') return new Response(null,{status:204,headers:cors});
 if(request.method!=='POST') return reply(405,{error:'请求方式不支持'});
 try {
  const text=await request.text();
  if(text.length>50000) return reply(413,{error:'提交内容过大'});
  const body=JSON.parse(text);
  if(typeof body.token!=='string'||! /^[a-f0-9]{64}$/.test(body.token)) return reply(401,{error:'链接无效或已过期'});
  if(body.action!=='read'&&body.action!=='submit') return reply(400,{error:'请求无效'});
  if(body.action==='submit'&&(!Array.isArray(body.slots)||body.slots.length>1000||body.slots.some(s=>typeof s!=='string'||! /^[a-f0-9-]{36}$/i.test(s))||!Number.isInteger(body.revision))) return reply(400,{error:'提交内容无效'});
  const key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const response=await fetch(Deno.env.get('SUPABASE_URL')+'/rest/v1/rpc/teacher_portal',{
   method:'POST',headers:{'Content-Type':'application/json','apikey':key,'Authorization':'Bearer '+key},
   body:JSON.stringify({p_token:body.token,p_slots:body.action==='submit'?body.slots:null,p_revision:body.action==='submit'?body.revision:null})
  });
  const data=await response.json();
  if(!response.ok) {
   const known=['链接无效或已过期','链接无效或尚未开放','该老师已停用','当前已停止填写','包含未开放的时间','填写内容或可选时间已变化，请刷新后重试'];
   return reply(data.code==='40001'?409:400,{error:known.includes(data.message)?data.message:'暂时无法处理，请联系管理员'});
  }
  return reply(200,data);
 } catch { return reply(500,{error:'连接失败，请稍后重试'}); }
});
