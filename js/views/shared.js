import {$,$$,escapeHtml as h,busy} from '../utils.js';
export {h};
export const card=(title,body)=>`<section class="card"><h2>${h(title)}</h2>${body}</section>`;
export const table=(headers,rows)=>rows.length?`<div class="table-wrap"><table><thead><tr>${headers.map(x=>`<th>${h(x)}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${r.map(c=>`<td>${c}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`:'<div class="empty">暂无数据</div>';
export const input=(name,label,type='text',value='',extra='')=>`<label>${h(label)}<input name="${name}" type="${type}" value="${h(value)}" ${extra}></label>`;
export const select=(name,label,options,value='')=>`<label>${h(label)}<select name="${name}">${options.map(([v,t])=>`<option value="${h(v)}" ${String(v)===String(value)?'selected':''}>${h(t)}</option>`).join('')}</select></label>`;
export const button=(action,id,label,style='light')=>`<button class="${style}" type="button" data-action="${action}" data-id="${h(id)}">${h(label)}</button>`;
export function bindForm(id,handler) {const form=$(id);form?.addEventListener('submit',event=>{event.preventDefault();busy(event.submitter,()=>handler(Object.fromEntries(new FormData(form)),form));});}
export function bindActions(handler,root=$('#view')) {$$('[data-action]',root).forEach(b=>b.addEventListener('click',()=>busy(b,()=>handler(b.dataset.action,b.dataset.id,b))));}
export function dialog(html){$('#dialog-content').innerHTML=html;$('#details').showModal();}
export function fillForm(id,data) {const form=$(id);for(const [k,v] of Object.entries(data)){const field=form.elements.namedItem(k);if(field)field.value=v??'';}form.scrollIntoView({behavior:'smooth',block:'center'});}
export function slotChoices(slots,selected=[],prefix='slot') {
 return [...new Set(slots.map(s=>s.meeting_date))].sort().map(date=>`<fieldset><legend>${h(date)}</legend><button type="button" class="light" data-date="${date}">本日全选／取消</button><div>${slots.filter(s=>s.meeting_date===date).map(s=>`<label class="time-option"><input type="checkbox" name="${prefix}" value="${s.id}" ${selected.includes(s.id)?'checked':''}><span>${h(s.start_time.slice(0,5))}–${h(s.end_time.slice(0,5))}</span></label>`).join('')}</div></fieldset>`).join('')||'<div class="empty">请先创建时间段</div>';
}
export function bindSlotToggles(root) {
 $$('[data-date]',root).forEach(b=>b.addEventListener('click',()=>{const inputs=$$('input[type=checkbox]',b.parentElement);const all=inputs.every(i=>i.checked);inputs.forEach(i=>i.checked=!all);}));
}
export const selectedSlots=root=>$$('input[name=slot]:checked',root).map(i=>i.value);
export const nameOf=(data,id)=>data.members.find(m=>m.teacher_id===id)?.name_snapshot||'未知老师';
export const classOf=(data,id)=>data.members.find(m=>m.teacher_id===id)?.class_snapshot||'';
export const leaderName=(data,id)=>data.periodLeaders.find(m=>m.leader_id===id)?.name_snapshot||data.leaders.find(l=>l.id===id)?.name||'负责人';
