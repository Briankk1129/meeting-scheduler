import {$,$$,escapeHtml as h,timeText,zoneText,busy,notify} from './utils.js';
import {portal} from './api/teacher-api.js';
let token=new URLSearchParams(location.hash.slice(1)).get('token')||new URLSearchParams(location.search).get('token')||history.state?.portalToken;
if(token) history.replaceState({portalToken:token},'',location.pathname);
let state;
function render() {
 const editable=state.status==='collecting'&&!state.excluded;
 $('#teacher-title').textContent=state.name+'老师';
 $('#period-title').textContent=state.title;
 $('#teacher-meta').textContent=[state.class_name,'会议时区：'+zoneText(state.timezone)].filter(Boolean).join(' · ');
 $('#submission-state').textContent=state.first_submitted_at?`已提交 · 最后修改 ${timeText(state.last_submitted_at,state.timezone)}`:'尚未提交';
 $('#instructions').textContent=editable?'请勾选你可以参加会议的所有时间。全部没空时也可以提交。':(state.excluded?'本月不需要安排会议。':'本月已停止填写，以下是你最后提交的内容。');
 const dates=[...new Set(state.slots.map(s=>s.meeting_date))];
 $('#choices').innerHTML=dates.length?dates.map(date=>`<fieldset><legend>${h(date)} <span class="muted">${new Date(date+'T12:00:00').toLocaleDateString('zh-CN',{weekday:'long'})}</span></legend>${state.slots.filter(s=>s.meeting_date===date).map(s=>`<label class="time-option"><input type="checkbox" value="${h(s.id)}" ${state.selected.includes(s.id)?'checked':''} ${editable?'':'disabled'}><span>${h(s.start_time.slice(0,5))}–${h(s.end_time.slice(0,5))}</span></label>`).join('')}</fieldset>`).join(''):'<div class="empty">管理员尚未为你开放可选时间。</div>';
 $('#submit').hidden=!editable;$('#submit').textContent=state.first_submitted_at?'保存修改':'提交可用时间';
}
$('#teacher-form').addEventListener('submit',event=>{event.preventDefault();busy($('#submit'),async()=>{
 const selected=$$('#choices input:checked').map(i=>i.value);
 if(!selected.length&&!confirm('确认本月没有可参加的时间？'))return;
 const requested=token;const updated=await portal(requested,selected,state.revision);if(requested!==token)return;state=updated;render();notify('已保存，管理员可以看到你的填写结果。');
});});
$('#reload').addEventListener('click',()=>busy($('#reload'),async()=>{const requested=token;const updated=await portal(requested);if(requested!==token)return;state=updated;render();notify('已刷新');}));
async function load(newToken){
 token=newToken;const requested=token;
 history.replaceState({portalToken:token},'',location.pathname);
 $('#submit').hidden=true;$('#choices').innerHTML='';$('#teacher-title').textContent='正在读取';$('#submission-state').textContent='正在读取';$('#notice').hidden=true;
 try{const data=await portal(requested);if(requested!==token)return;state=data;render();}
 catch(error){if(requested!==token)return;notify(error.message,true);$('#submit').hidden=true;$('#teacher-title').textContent='无法打开填写页面';$('#instructions').textContent='请确认链接是否有效，或联系管理员重新生成。';}
}
window.addEventListener('hashchange',()=>{const next=new URLSearchParams(location.hash.slice(1)).get('token');if(next)load(next);});
if(!token){$('#instructions').textContent='请通过管理员发给你的专属链接打开填写页面。';$('#submit').hidden=true;$('#reload').hidden=true;$('#submission-state').textContent='需要专属链接';}
else await load(token);
