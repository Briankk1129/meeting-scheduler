import {card,h,select,slotChoices,bindSlotToggles,selectedSlots,bindForm} from './shared.js';
import {$,$$,busy} from '../utils.js';
let selectedTeacher='';
export function render(ctx) {
 const {root,data:d,period:p}=ctx;if(!p)return ctx.needPeriod();
 if(!d.members.some(m=>m.teacher_id===selectedTeacher))selectedTeacher=d.members[0]?.teacher_id||'';
 const opts=d.members.map(m=>[m.teacher_id,`${m.name_snapshot} ${m.class_snapshot}`]);
 root.innerHTML=card('设置班主任可选时间',`<p class="muted">老师只能看到这里开放的时间。取消权限会移除对应选择和固定安排。</p><div class="toolbar">${select('teacher','选择老师',opts,selectedTeacher)}${select('copy','复制另一位老师',[['','选择来源'],...opts])}<button id="copy-permissions" class="light">复制到勾选区</button></div><form id="permissions-form"><div class="row"><button type="button" id="select-all" class="light">全选</button><button type="button" id="select-none" class="light">全部取消</button></div>${slotChoices(d.slots,d.permissions.filter(a=>a.teacher_id===selectedTeacher).map(a=>a.slot_id))}<div class="row"><button ${selectedTeacher?'':'disabled'}>保存该老师权限</button><button type="button" id="open-all" class="light" ${d.members.length?'':'disabled'}>向本月所有老师追加开放勾选时间</button></div></form>`);
 const form=$('#permissions-form');bindSlotToggles(form);
 $('[name=teacher]').onchange=e=>{selectedTeacher=e.target.value;render(ctx);};
 $('#select-all').onclick=()=>$$('input[name=slot]',form).forEach(i=>i.checked=true);$('#select-none').onclick=()=>$$('input[name=slot]',form).forEach(i=>i.checked=false);
 $('#copy-permissions').onclick=()=>{const src=$('[name=copy]').value;if(src)$$('input[name=slot]',form).forEach(i=>i.checked=d.permissions.some(a=>a.teacher_id===src&&a.slot_id===i.value));};
 bindForm('#permissions-form',()=>ctx.mutate('permissions',{teacher_ids:[selectedTeacher],slot_ids:selectedSlots(form),mode:'replace'}));
 $('#open-all').onclick=()=>busy($('#open-all'),()=>ctx.mutate('permissions',{teacher_ids:d.members.map(m=>m.teacher_id),slot_ids:selectedSlots(form),mode:'append'}));
}
