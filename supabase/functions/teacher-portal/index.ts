// Shared public entry: month + roster name. No account or personal token required.
// This endpoint intentionally permits selection of any active member in that month.
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
  let body;try{body=JSON.parse(text);}catch{return reply(400,{error:'请求无效'});}
  const uuid=s=>typeof s==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
  if(!body||!Number.isInteger(body.year)||body.year<2000||body.year>2200||!Number.isInteger(body.month)||body.month<1||body.month>12) return reply(400,{error:'月份无效'});
  if(body.teacher_id!=null&&!uuid(body.teacher_id))return reply(400,{error:'班主任无效'});
  if(body.action!=='read'&&body.action!=='submit') return reply(400,{error:'请求无效'});
  const submit=body.action==='submit';
  if(submit&&(!uuid(body.teacher_id)||!Array.isArray(body.slots)||body.slots.length>1000||body.slots.some(s=>!uuid(s))||!Number.isInteger(body.revision)||!Number.isInteger(body.period_revision))) return reply(400,{error:'提交内容无效'});
  const key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const response=await fetch(Deno.env.get('SUPABASE_URL')+'/rest/v1/rpc/shared_teacher_portal',{
   method:'POST',headers:{'Content-Type':'application/json','apikey':key,'Authorization':'Bearer '+key},
   body:JSON.stringify({p_year:body.year,p_month:body.month,p_teacher:body.teacher_id||null,p_slots:submit?body.slots:null,p_revision:submit?body.revision:null,p_period_revision:submit?body.period_revision:null})
  });
  const data=await response.json();
  if(!response.ok) {
   const known=['月份无效','请选择本月名单中的班主任','当前已停止填写','本月会议时间尚未准备好','会议资料或填写内容已变化，请刷新后重试','包含其他月份或无效的时间'];
   return reply(data.code==='40001'?409:400,{error:known.includes(data.message)?data.message:'暂时无法处理，请联系管理员'});
  }
  return reply(200,data);
 } catch { return reply(500,{error:'连接失败，请稍后重试'}); }
});
