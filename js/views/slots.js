import {card,h,table,input,button,bindActions,bindForm,fillForm} from './shared.js';
export function render(ctx) {
 const {root,data:d,period:p}=ctx;if(!p)return ctx.needPeriod();
 root.innerHTML=card('新增或修改时间段',`<form id="slot-form" class="form-grid"><input type="hidden" name="id">${input('meeting_date','日期','date',`${p.year}-${String(p.month).padStart(2,'0')}-01`,'required')}${input('start_time','开始时间','time','19:00','required')}${input('end_time','结束时间','time','19:30','required')}${input('capacity_override','人数上限（留空默认）','number','','min="0" max="100"')}<button>保存时间段</button><button type="reset" class="light">取消编辑</button></form><p class="footer-note">默认每段 ${p.default_capacity} 人。单独设置为 0 可关闭该时间段的班主任名额。负责人不占人数。</p>`)+
 [...new Set(d.slots.map(s=>s.meeting_date))].sort().map(date=>card(date,`<div class="toolbar">${button('date-delete',date,'删除整日','danger')}</div>`+table(['时间段','容量','操作'],d.slots.filter(s=>s.meeting_date===date).map(s=>[`${h(s.start_time.slice(0,5))}–${h(s.end_time.slice(0,5))}`,s.capacity_override??`默认 ${p.default_capacity}`,button('edit',s.id,'编辑')+button('delete',s.id,'删除','danger')])))).join('');
 bindForm('#slot-form',f=>ctx.mutate('slot_save',f));bindActions(async(action,id)=>{
 if(action==='edit')return fillForm('#slot-form',d.slots.find(s=>s.id===id));
 if(action==='delete'&&confirm('删除时间段会同时移除相关可选权限、填写选择和固定安排。继续？'))await ctx.mutate('slot_delete',{id});
 if(action==='date-delete'&&confirm('删除这一天的所有时间段及相关填写选择？已有历史会议的日期不能删除。'))await ctx.mutate('date_delete',{meeting_date:id});
 });
}
