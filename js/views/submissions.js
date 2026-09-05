import {card,h,table,button,bindActions,bindForm,dialog,slotChoices,bindSlotToggles,selectedSlots} from './shared.js';
import {$,timeText,labelSlot} from '../utils.js';
let filter='all';
export function render(ctx){
 const {root,data:d,period:p}=ctx;if(!p)return ctx.needPeriod();
 const done=d.members.filter(m=>m.first_submitted_at).length;
 const rows=d.members.filter(m=>filter==='all'||(filter==='done'?!!m.first_submitted_at:!m.first_submitted_at));
 root.innerHTML=card('本月填写情况',`<p class="muted">可修改老师已填的时间，或删除整份填写。修改后已有排期需重新生成。</p><div class="toolbar"><span class="badge">总人数 ${d.members.length}</span><span class="badge ok">已填写 ${done}</span><span class="badge warn">未填写 ${d.members.length-done}</span><select id="filter" aria-label="填写状态">${[['all','全部'],['done','已填写'],['pending','未填写']].map(([v,n])=>`<option value="${v}" ${filter===v?'selected':''}>${n}</option>`).join('')}</select></div>`+table(['姓名','班级','状态','首次提交','最后修改','可参加时间','操作'],rows.map(m=>[h(m.name_snapshot),h(m.class_snapshot),m.first_submitted_at?'已填写'+(m.submission_source==='import'?'（导入）':''):'未填写',h(timeText(m.first_submitted_at,p.timezone)),h(timeText(m.last_submitted_at,p.timezone)),d.availability.filter(a=>a.teacher_id===m.teacher_id).map(a=>h(labelSlot(d.slots.find(s=>s.id===a.slot_id)))).join('<br>')||(m.first_submitted_at?'已提交，无可用时间':'—'),m.first_submitted_at?button('edit-submission',m.teacher_id,'修改')+button('delete-submission',m.teacher_id,'删除填写','danger'):'—'])));
 bindActions(async(action,id)=>{
  const m=d.members.find(m=>m.teacher_id===id);if(!m)return;
  const payload={period_id:p.id,revision:p.revision,teacher_id:id,submission_revision:m.submission_revision};
  if(action==='delete-submission'){
   if(!confirm(`删除 ${m.name_snapshot} 在 ${p.title} 的全部填写？删除后恢复为“未填写”，并移除相关固定安排；已有排期需重新生成。`))return;
   return ctx.mutate('submission_delete',payload);
  }
  if(action==='edit-submission'){
   dialog(`<h2>修改 ${h(m.name_snapshot)} 的可参加时间</h2><p>${h(p.title)} · ${h(m.class_snapshot)}</p><p class="muted">取消勾选即可删除对应时间。全部取消后保存，表示“已填写，无可用时间”。失效的固定安排会移除，已有排期需重新生成。</p><div id="edit-submission-error" class="notice error" role="alert" hidden></div><form id="edit-submission-form">${slotChoices(d.slots,d.availability.filter(a=>a.teacher_id===id).map(a=>a.slot_id))}<button>保存修改</button></form>`);
   const form=$('#edit-submission-form');bindSlotToggles(form);
   bindForm('#edit-submission-form',async()=>{
    $('#edit-submission-error').hidden=true;
    try{await ctx.mutate('submission_update',{...payload,slot_ids:selectedSlots(form)});$('#details').close();}
    catch(error){$('#edit-submission-error').textContent=error.message;$('#edit-submission-error').hidden=false;}
   });
  }
 });
 $('#filter').onchange=e=>{filter=e.target.value;render(ctx);};
}
