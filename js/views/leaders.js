import {card,h,table,input,select,button,fillForm,bindActions,bindForm} from './shared.js';
import {$,$$} from '../utils.js';
let leader='';
export function render(ctx){
 const {root,data:d,period:p}=ctx;
 if(!d.leaders.some(l=>l.id===leader&&l.active))leader=d.leaders.find(l=>l.active)?.id||'';
 root.innerHTML=card('负责人管理',`<p class="muted">至少一位负责人可参加的时间才能安排会议，负责人不占班主任人数。</p><form id="leader-form" class="form-grid"><input type="hidden" name="id">${input('name','姓名','text','','required')}${select('active','状态',[['true','启用'],['false','停用']])}${select('teacher_id','兼任班主任（可选）',[['','独立负责人'],...d.teachers.map(t=>[t.id,t.name+' '+t.class_name])])}<button>保存负责人</button><button type="reset" class="light">取消编辑</button></form>`)+
 card('负责人档案',table(['姓名','状态','操作'],d.leaders.map(l=>[h(l.name),l.active?'启用':'停用',button('edit',l.id,'编辑')])));
 const dates=[...new Set(d.slots.map(s=>s.meeting_date))].sort();
 const available=new Set(d.leaderAvailability.filter(a=>a.leader_id===leader).map(a=>a.slot_id));
 if(p)root.innerHTML+=card('本月负责人可参加日期',`${select('leader','负责人',d.leaders.filter(l=>l.active).map(l=>[l.id,l.name]),leader)}<form id="leader-slots"><p class="muted">勾选日期表示当天所有已设置的会议时间段都可以参加。</p><div class="toolbar"><button id="leader-all" type="button" class="light">日期全选</button><button id="leader-none" type="button" class="light">清空选择</button><span id="leader-date-count" class="badge"></span></div><div class="leader-dates">${dates.map(date=>`<label class="time-option"><input type="checkbox" name="leader_date" value="${date}" ${d.slots.some(s=>s.meeting_date===date&&available.has(s.id))?'checked':''}><span>${h(date.slice(5).replace('-','月'))}日 <small>${new Date(date+'T12:00:00').toLocaleDateString('zh-CN',{weekday:'short'})}</small></span></label>`).join('')||'<p class="muted">请先到“会议日期与时间”添加会议日期。</p>'}</div><button ${leader&&dates.length?'':'disabled'}>保存本月可参加日期</button></form>`);
 bindForm('#leader-form',f=>ctx.mutate('leader_save',{...f,active:f.active==='true'}));bindActions((a,id)=>fillForm('#leader-form',d.leaders.find(l=>l.id===id)));
 if(p){
  $('[name=leader]').onchange=e=>{leader=e.target.value;render(ctx);};
  const form=$('#leader-slots'),choices=()=>$$('input[name=leader_date]',form),update=()=>{$('#leader-date-count').textContent=`已选 ${choices().filter(c=>c.checked).length} / ${dates.length} 天`;};
  form.onchange=update;update();
  $('#leader-all').onclick=()=>{choices().forEach(c=>c.checked=true);update();};
  $('#leader-none').onclick=()=>{choices().forEach(c=>c.checked=false);update();};
  bindForm('#leader-slots',()=>{const selected=new Set(choices().filter(c=>c.checked).map(c=>c.value));return ctx.mutate('leader_slots',{leader_id:leader,slot_ids:d.slots.filter(s=>selected.has(s.meeting_date)).map(s=>s.id)});});
 }
}
