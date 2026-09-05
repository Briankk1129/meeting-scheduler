import {card,input,select,bindForm} from './shared.js';
import {render as renderSlots} from './slots.js';
import {$,busy} from '../utils.js';
export function render(ctx,chosenMonth) {
 const {root,data:d,period:p}=ctx,now=new Date();
 const month=chosenMonth||(p?`${p.year}-${String(p.month).padStart(2,'0')}`:`${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}`);
 const [year,number]=month.split('-').map(Number);
 const existing=d.periods.find(x=>x.year===year&&x.month===number);
 const current=existing||{year,month:number,title:`${year}年${number}月会议`,timezone:'Asia/Tokyo',default_capacity:3,status:'draft'};
 root.innerHTML=card('会议日期与时间',`<form id="meeting-settings" class="form-grid">${input('month','会议月份','month',month,'required min="2000-01" max="2200-12"')}${input('title','会议名称','text',current.title,'required')}${select('timezone','会议时区',[['Asia/Tokyo','日本标准时间'],['Asia/Shanghai','中国标准时间']],current.timezone)}${input('default_capacity','每段默认人数','number',current.default_capacity,'min="1" max="100" required')}${select('status','填写状态',[['draft','准备中'],['collecting','开放填写'],['closed','关闭填写']],current.status==='scheduled'?'closed':current.status)}<button>保存会议设置</button></form><p class="footer-note">先在下方选择开会日期，再填写这些日期的开始和结束时间。可多选日期批量设置，也可分别为不同日期添加时间段。</p>`)+'<div id="meeting-times"></div>';
 const settings=()=>Object.fromEntries(new FormData($('#meeting-settings')));
 async function ensureMonth(){
  if(existing)return;
  const f=settings();
  if(!$('#meeting-settings').reportValidity())throw new Error('请填写完整的会议设置');
  await ctx.mutate('period_create',{year,month:number,title:f.title,timezone:f.timezone,default_capacity:f.default_capacity});
  if(f.status!=='draft')await ctx.mutate('period_update',{status:f.status});
 }
 bindForm('#meeting-settings',async f=>{if(existing)await ctx.mutate('period_update',{title:f.title,timezone:f.timezone,default_capacity:f.default_capacity,status:f.status});else await ensureMonth();});
 $('#meeting-settings [name=month]').onchange=e=>{if(!e.target.validity.valid||!e.target.value)return;const [y,m]=e.target.value.split('-').map(Number),found=d.periods.find(x=>x.year===y&&x.month===m);if(found)busy(e.target,()=>ctx.selectPeriod(found.id));else render(ctx,e.target.value);};
 renderSlots({...ctx,period:current,data:{...d,slots:existing?d.slots:[]},root:root.querySelector('#meeting-times'),async mutate(action,payload){await ensureMonth();return ctx.mutate(action,payload);}});
}
