import {$,$$,escapeHtml as h,timeText,zoneText,busy,notify} from './utils.js';
import {portal} from './api/teacher-api.js';
let state,ticket=0,loading=false,dirty=false;
const now=new Date();
$('#month-select').value=`${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}`;
let chosenMonth=$('#month-select').value,teacherId='';
// Old personal links also land at the common portal; identity is always selected explicitly.
if(location.hash||location.search)history.replaceState(null,'',location.pathname);
function render(){
 const member=state.member;
 const editable=state.status==='collecting'&&state.slots.length>0&&member&&!member.excluded;
 $('#period-title').textContent=state.title;
 $('#teacher-select').innerHTML='<option value="">请选择自己的姓名</option>'+state.teachers.map(t=>`<option value="${h(t.id)}" ${t.id===teacherId?'selected':''}>${h(t.name)}${t.class_name?' · '+h(t.class_name):''}</option>`).join('');
 if(!state.teachers.some(t=>t.id===teacherId))teacherId='';
 $('#teacher-meta').textContent='会议时区：'+zoneText(state.timezone);
 $('#submission-state').textContent=member?(member.first_submitted_at?`已提交 · 最后修改 ${timeText(member.last_submitted_at,state.timezone)}`:'尚未提交'):'请选择自己的姓名';
 $('#instructions').textContent=!state.slots.length?'本月会议时间尚未准备好，请稍后再来。':!member?'选择自己的姓名后，勾选所有可以参加会议的时间。':member.excluded?'本月不需要安排会议。':editable?'请勾选你可以参加会议的所有时间。全部没空时也可以提交。':'本月已停止填写，可以查看已提交内容和会议安排。';
 const dates=[...new Set(state.slots.map(s=>s.meeting_date))];
 $('#choices').innerHTML=dates.map(date=>`<fieldset><legend>${h(date)}</legend>${state.slots.filter(s=>s.meeting_date===date).map(s=>`<label class="time-option"><input type="checkbox" value="${h(s.id)}" ${state.selected.includes(s.id)?'checked':''} ${editable?'':'disabled'}><span>${h(s.start_time.slice(0,5))}–${h(s.end_time.slice(0,5))}</span></label>`).join('')}</fieldset>`).join('');
 $('#submit').hidden=!editable;$('#submit').textContent=member?.first_submitted_at?'保存修改':'提交可用时间';
 $('#meeting-list').innerHTML=(state.schedule_stale?'<p class="warning">会议资料已更新，以下安排等待管理员重新确认。</p>':'')+(state.meetings.length?state.meetings.map(m=>`<div class="card"><strong>${h(m.meeting_date)} ${h(m.start_time.slice(0,5))}–${h(m.end_time.slice(0,5))}</strong><p>${m.teachers.map(t=>h(t.name)+(t.class_name?'（'+h(t.class_name)+'）':'')).join('、')}</p><p class="muted">负责人：${m.leaders.map(h).join('、')||'—'}</p></div>`).join(''):'<p class="muted">本月暂无已生成的会议安排。</p>');
}
async function load(){
 const id=++ticket;loading=true;dirty=false;state=null;
 $('#submit').hidden=true;$('#choices').innerHTML='';$('#meeting-list').textContent='正在读取…';$('#submission-state').textContent='正在读取';$('#notice').hidden=true;
 const [year,month]=chosenMonth.split('-').map(Number);
 try{const next=await portal(year,month,teacherId||null);if(id!==ticket)return;state=next;render();}
 catch(error){if(id!==ticket)return;notify(error.message,true);$('#instructions').textContent='读取失败，请点击刷新重试。';$('#submission-state').textContent='读取失败';$('#meeting-list').textContent='暂时无法读取';}
 finally{if(id===ticket)loading=false;}
}
function canLeave(){return !dirty||confirm('当前勾选尚未保存，是否放弃修改并切换？');}
$('#month-select').onchange=e=>{if(!e.target.validity.valid||!e.target.value||!canLeave()){e.target.value=chosenMonth;return;}chosenMonth=e.target.value;load();};
$('#teacher-select').onchange=e=>{if(!canLeave()){e.target.value=teacherId;return;}teacherId=e.target.value;load();};
$('#choices').onchange=()=>{dirty=true;};
$('#reload').onclick=()=>{if(canLeave())return busy($('#reload'),load);};
$('#teacher-form').onsubmit=event=>{event.preventDefault();if(loading||!state?.member)return;busy($('#submit'),async()=>{
 const selected=$$('#choices input:checked').map(i=>i.value),member=state.member;
 if(!confirm(`确认以 ${member.name}${member.class_name?'（'+member.class_name+'）':''} 的身份提交${state.title}的可用时间？${selected.length?'':'\n本次提交表示全部时间都没空。'}`))return;
 const id=++ticket,[year,month]=chosenMonth.split('-').map(Number);loading=true;
 $('#month-select').disabled=true;$('#teacher-select').disabled=true;$('#reload').disabled=true;
 try{const next=await portal(year,month,teacherId,selected,member.revision,state.period_revision);if(id!==ticket)return;state=next;dirty=false;render();notify('已保存，管理员可以看到你的填写结果。');}
 finally{loading=false;$('#month-select').disabled=false;$('#teacher-select').disabled=false;$('#reload').disabled=false;}
});};
window.addEventListener('beforeunload',e=>{if(dirty){e.preventDefault();e.returnValue='';}});
await load();
