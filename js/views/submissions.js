import {card,h,table} from './shared.js';
import {$,timeText,labelSlot} from '../utils.js';
let filter='all';
export function render(ctx){
 const {root,data:d,period:p}=ctx;if(!p)return ctx.needPeriod();
 const done=d.members.filter(m=>m.first_submitted_at).length;
 const rows=d.members.filter(m=>filter==='all'||(filter==='done'?!!m.first_submitted_at:!m.first_submitted_at));
 root.innerHTML=card('本月填写情况',`<div class="toolbar"><span class="badge">总人数 ${d.members.length}</span><span class="badge ok">已填写 ${done}</span><span class="badge warn">未填写 ${d.members.length-done}</span><select id="filter" aria-label="填写状态">${[['all','全部'],['done','已填写'],['pending','未填写']].map(([v,n])=>`<option value="${v}" ${filter===v?'selected':''}>${n}</option>`).join('')}</select></div>`+table(['姓名','班级','状态','首次提交','最后修改','可参加时间'],rows.map(m=>[h(m.name_snapshot),h(m.class_snapshot),m.first_submitted_at?'已填写'+(m.submission_source==='import'?'（导入）':''):'未填写',h(timeText(m.first_submitted_at,p.timezone)),h(timeText(m.last_submitted_at,p.timezone)),d.availability.filter(a=>a.teacher_id===m.teacher_id).map(a=>h(labelSlot(d.slots.find(s=>s.id===a.slot_id)))).join('<br>')||(m.first_submitted_at?'已提交，无可用时间':'—')])));
 $('#filter').onchange=e=>{filter=e.target.value;render(ctx);};
}
