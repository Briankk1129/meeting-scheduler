import {card,h,table,input,button,bindActions,bindForm,fillForm} from './shared.js';
import {$,$$,notify} from '../utils.js';
export function render(ctx) {
 const {root,data:d,period:p}=ctx;if(!p)return;
 const prefix=`${p.year}-${String(p.month).padStart(2,'0')}`,days=new Date(p.year,p.month,0).getDate(),offset=(new Date(p.year,p.month-1,1).getDay()+6)%7;
 const rangeRow=()=>`<div class="form-grid time-range">${input('start_time','开始时间','time','19:00','required')}${input('end_time','结束时间','time','19:30','required')}<button type="button" class="light remove-range">移除此时间段</button></div>`;
 root.innerHTML=card('批量添加会议日期',`<form id="batch-slots"><p class="muted">点击日历选择多天，再设置这些日期共用的时间段。可一次添加多个时间段，已有的相同时间会自动跳过。</p><div class="toolbar"><button type="button" class="light" data-days="all">全选本月</button><button type="button" class="light" data-days="weekdays">选择工作日</button><button type="button" class="light" data-days="none">清空选择</button><span id="date-count" class="badge">已选 0 天</span></div><div class="date-picker" aria-label="${p.year}年${p.month}月日期多选">${['一','二','三','四','五','六','日'].map(x=>`<span class="weekday">${x}</span>`).join('')}${'<span></span>'.repeat(offset)}${Array.from({length:days},(_,i)=>{const date=prefix+'-'+String(i+1).padStart(2,'0'),exists=d.slots.some(s=>s.meeting_date===date);return `<label class="date-cell"><input type="checkbox" name="dates" value="${date}" aria-label="${date}"><span>${i+1}${exists?'<small>已设置</small>':''}</span></label>`;}).join('')}</div><div id="time-ranges" class="stack">${rangeRow()}</div><div class="toolbar"><button id="add-range" type="button" class="light">＋ 增加时间段</button></div><div class="form-grid">${input('capacity_override','每段人数上限（留空用月份默认）','number','','min="0" max="100"')}<button id="save-batch">添加所选日期的时间段</button></div><p class="footer-note">本月默认每段 ${p.default_capacity} 人；设为 0 可关闭该时间段的班主任名额。负责人不占人数。</p></form>`)+
 `<details id="slot-editor" class="card"><summary>单个时间段编辑</summary><form id="slot-form" class="form-grid"><input type="hidden" name="id">${input('meeting_date','日期','date',prefix+'-01',`required min="${prefix}-01" max="${prefix}-${days}"`)}${input('start_time','开始时间','time','19:00','required')}${input('end_time','结束时间','time','19:30','required')}${input('capacity_override','人数上限（留空默认）','number','','min="0" max="100"')}<button>保存时间段</button><button type="reset" class="light">取消编辑</button></form></details>`+
 (d.slots.length?[...new Set(d.slots.map(s=>s.meeting_date))].sort().map(date=>card(date,`<div class="toolbar">${button('date-delete',date,'删除整日','danger')}</div>`+table(['时间段','容量','操作'],d.slots.filter(s=>s.meeting_date===date).map(s=>[`${h(s.start_time.slice(0,5))}–${h(s.end_time.slice(0,5))}`,s.capacity_override??`默认 ${p.default_capacity}`,button('edit',s.id,'编辑')+button('delete',s.id,'删除','danger')])))).join(''):'<div class="empty">本月还没有会议时间，请在上方多选日期后添加。</div>');
 const update=()=>{$('#date-count').textContent=`已选 ${$$('input[name=dates]:checked',root).length} 天`;};
 $('.date-picker',root).onchange=update;
 $$('[data-days]',root).forEach(b=>b.onclick=()=>{$$('input[name=dates]',root).forEach(c=>{const day=new Date(c.value+'T12:00:00').getDay();c.checked=b.dataset.days==='all'||b.dataset.days==='weekdays'&&day>0&&day<6;});update();});
 $('#add-range').onclick=()=>{if($$('.time-range',root).length>=24)return notify('每批最多添加24个时间段',true);$('#time-ranges').insertAdjacentHTML('beforeend',rangeRow());};
 $('#time-ranges').onclick=e=>{if(e.target.matches('.remove-range')){if($$('.time-range',root).length===1)return notify('请至少保留一个时间段',true);e.target.closest('.time-range').remove();}};
 bindForm('#batch-slots',async f=>{
  const dates=$$('input[name=dates]:checked',root).map(x=>x.value),times=$$('.time-range',root).map(r=>({start_time:$('[name=start_time]',r).value,end_time:$('[name=end_time]',r).value}));
  if(!dates.length)throw new Error('请先在日历中选择至少一天');
  if(times.some(t=>t.start_time>=t.end_time))throw new Error('每段结束时间必须晚于开始时间');
  const result=await ctx.mutate('slot_bulk',{dates,times,capacity_override:f.capacity_override});notify(`已添加 ${result.added} 个时间段，跳过 ${result.skipped} 个重复时间段。`);
 });
 bindForm('#slot-form',f=>ctx.mutate('slot_save',f));bindActions(async(action,id)=>{
 if(action==='edit'){$('#slot-editor').open=true;return fillForm('#slot-form',d.slots.find(s=>s.id===id));}
 if(action==='delete'&&confirm('删除时间段会同时移除相关填写选择和固定安排。继续？'))await ctx.mutate('slot_delete',{id});
 if(action==='date-delete'&&confirm('删除这一天的所有时间段及相关填写选择？已有历史会议的日期不能删除。'))await ctx.mutate('date_delete',{meeting_date:id});
 },root);
}
