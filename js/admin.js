import {$,$$,escapeHtml as h,busy,notify,statusText} from './utils.js';
import {requireAdmin} from './auth.js';
import {requireConfig} from './supabase.js';
import {snapshot,command} from './api/admin-api.js';
const views=[['dashboard','管理首页'],['teachers','班主任管理'],['periods','月份管理'],['slots','日期 / 时间段'],['permissions','可选时间权限'],['submissions','填写情况'],['leaders','负责人管理'],['scheduler','自动排期'],['calendar','会议日历'],['export','数据导出'],['settings','系统设置']];
const cloudRevisions=new Map();
let data,periodId=localStorage.getItem('meeting-period-preference')||'',user,renderTicket=0,channel;
const current=()=>data?.periods.find(p=>p.id===periodId);
const ctx={root:$('#view'),get data(){return data},get period(){return current()},get user(){return user},
 needPeriod(){this.root.innerHTML='<div class="empty">请先<a href="#/periods">创建并选择一个月份</a>。</div>';},
 async mutate(action,payload={}){$('#notice').hidden=true;const p=current();const result=await command(action,{period_id:p?.id||null,revision:p?.revision,...payload});if(action==='period_create'){periodId=result.id;localStorage.setItem('meeting-period-preference',periodId);}await refresh();notify('已保存到云端');return result;},
 async selectPeriod(id){periodId=id;localStorage.setItem('meeting-period-preference',id);await refresh();}
};
async function render(){
 const ticket=++renderTicket;const key=location.hash.replace('#/','').split('?')[0]||'dashboard';const route=views.find(v=>v[0]===key)||views[0];
 $('#view-title').textContent=route[1];$$('#navigation a').forEach(a=>a.classList.toggle('active',a.hash==='#/'+route[0]));
 $('#sidebar').classList.remove('open');
 const mod=await import(`./views/${route[0]}.js`);if(ticket===renderTicket)mod.render(ctx);
}
async function refresh(){
 $('#cloud-update').hidden=true;
 data=await snapshot(periodId||null);
 if(!data.periods.some(p=>p.id===periodId)){periodId=data.periods[0]?.id||'';if(periodId)data=await snapshot(periodId);}
 $('#period-select').innerHTML=data.periods.length?data.periods.map(p=>`<option value="${p.id}" ${p.id===periodId?'selected':''}>${h(p.title)} · ${h(statusText(p.status))}</option>`).join(''):'<option value="">尚未创建月份</option>';
 $('#cloud-update').hidden=!current()||current().revision>=(cloudRevisions.get(periodId)||0);
 await render();
}
$('#navigation').innerHTML=views.map(([key,label],i)=>`<a href="#/${key}"><span class="nav-icon">${String(i+1).padStart(2,'0')}</span>${label}</a>`).join('');
$('#period-select').onchange=e=>busy($('#period-select'),()=>ctx.selectPeriod(e.target.value));
$('#refresh').onclick=()=>busy($('#refresh'),refresh);
$('#menu').onclick=()=>$('#sidebar').classList.toggle('open');
$('#logout').onclick=()=>busy($('#logout'),async()=>{await requireConfig().auth.signOut();location.replace('login.html');});
window.addEventListener('hashchange',()=>{if(data)render().catch(e=>notify(e.message,true));});
try {
 user=await requireAdmin();
 if(user){$('#account').textContent=user.email;await refresh();
 const db=requireConfig();
 db.auth.onAuthStateChange(event=>{if(event==='SIGNED_OUT')location.replace('login.html');});
 // Refresh submissions/dashboard automatically. Never erase an administrator's in-progress form.
 const onChange=payload=>{if(payload?.new?.id)cloudRevisions.set(payload.new.id,Math.max(cloudRevisions.get(payload.new.id)||0,payload.new.revision||0));if(payload?.new?.id===periodId && payload.new.revision<=current()?.revision)return;const key=location.hash||'#/dashboard';if(['#/dashboard','#/submissions'].includes(key))refresh().catch(e=>notify(e.message,true));else $('#cloud-update').hidden=false;};
 channel=db.channel('meeting-period-updates').on('postgres_changes',{event:'UPDATE',schema:'public',table:'meeting_periods'},onChange).subscribe();
 const polling=setInterval(()=>{if(!document.hidden&&['#/dashboard','#/submissions'].includes(location.hash||'#/dashboard'))refresh().catch(()=>{});},15000);
 window.addEventListener('pagehide',()=>{clearInterval(polling);db.removeChannel(channel);});
 }
}catch(error){notify(error.message,true);$('#view').innerHTML='<div class="empty">后台暂时无法载入。请检查数据库配置、网络和账号权限。<br><a href="login.html">返回登录</a></div>';}
