import {card,h,table,input,select,button,fillForm,bindActions,bindForm,slotChoices,bindSlotToggles,selectedSlots} from './shared.js';
import {$} from '../utils.js';
let leader='';
export function render(ctx){
 const {root,data:d,period:p}=ctx;
 if(!d.leaders.some(l=>l.id===leader))leader=d.leaders[0]?.id||'';
 root.innerHTML=card('负责人管理',`<p class="muted">至少一位负责人可参加的时间才能安排会议，负责人不占班主任人数。</p><form id="leader-form" class="form-grid"><input type="hidden" name="id">${input('name','姓名','text','','required')}${select('active','状态',[['true','启用'],['false','停用']])}${select('teacher_id','兼任班主任（可选）',[['','独立负责人'],...d.teachers.map(t=>[t.id,t.name+' '+t.class_name])])}<button>保存负责人</button><button type="reset" class="light">取消编辑</button></form>`)+
 card('负责人档案',table(['姓名','状态','操作'],d.leaders.map(l=>[h(l.name),l.active?'启用':'停用',button('edit',l.id,'编辑')])));
 if(p)root.innerHTML+=card('本月负责人可参加时间',`${select('leader','负责人',d.leaders.filter(l=>l.active).map(l=>[l.id,l.name]),leader)}<form id="leader-slots">${slotChoices(d.slots,d.leaderAvailability.filter(a=>a.leader_id===leader).map(a=>a.slot_id))}<button ${leader?'':'disabled'}>保存本月可用时间</button></form>`);
 bindForm('#leader-form',f=>ctx.mutate('leader_save',{...f,active:f.active==='true'}));bindActions((a,id)=>fillForm('#leader-form',d.leaders.find(l=>l.id===id)));
 if(p){$('[name=leader]').onchange=e=>{leader=e.target.value;render(ctx);};bindSlotToggles($('#leader-slots'));bindForm('#leader-slots',()=>ctx.mutate('leader_slots',{leader_id:leader,slot_ids:selectedSlots($('#leader-slots'))}));}
}
