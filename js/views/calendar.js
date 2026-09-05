import {card,h,dialog,nameOf,classOf,leaderName} from './shared.js';
import {labelSlot} from '../utils.js';
let instance;
export function render(ctx){
 instance?.destroy();instance=null;
 const {root,data:d,period:p}=ctx;if(!p)return ctx.needPeriod();
 root.innerHTML=(d.runs[0]&&d.runs[0].source_revision!==p.revision?'<div class="warning">当前排期已过期，日历展示的是上次保存的结果。</div>':'')+card('会议月历','<p class="muted">老师姓名直接显示在各时间段内，点击可查看班级和负责人详情。切换月份会同步后台当前月份。</p><div id="calendar"></div>');
 if(!globalThis.FullCalendar){root.innerHTML=card('日历加载失败','<p>请刷新页面。</p>');return;}
 const show=slots=>dialog(`<h2>会议详情</h2>${slots.length?slots.map(s=>`<section class="calendar-details"><h3>${h(labelSlot(s))}</h3><p>负责人：${d.assignmentLeaders.filter(a=>a.slot_id===s.id).map(a=>h(leaderName(d,a.leader_id))).join('、')||'—'}</p><ul class="list">${d.assignments.filter(a=>a.slot_id===s.id).map(a=>`<li>${h(nameOf(d,a.teacher_id))} · ${h(classOf(d,a.teacher_id))}${a.is_fixed?'（指定）':''}</li>`).join('')||'<li>暂无班主任安排</li>'}</ul></section>`).join(''):'<p>这一天没有会议。</p>'}`);
 const booked=d.slots.filter(s=>d.assignments.some(a=>a.slot_id===s.id)||d.assignmentLeaders.some(a=>a.slot_id===s.id));
 const change=async date=>{const year=date.getFullYear(),month=date.getMonth()+1;const target=d.periods.find(x=>x.year===year&&x.month===month);if(target)await ctx.selectPeriod(target.id);else dialog(`<h2>${year}年${month}月</h2><p>尚未创建这个月份。</p><a href="#/periods" id="calendar-create">前往月份管理</a>`);};
 instance=new FullCalendar.Calendar(document.getElementById('calendar'),{
 initialView:'dayGridMonth',initialDate:`${p.year}-${String(p.month).padStart(2,'0')}-01`,locale:'zh-cn',firstDay:0,height:'auto',dayMaxEvents:false,
 headerToolbar:{left:'previous,nextMonth,todayMonth',center:'title',right:''},
 customButtons:{previous:{text:'上一月',click:()=>change(new Date(p.year,p.month-2,1))},nextMonth:{text:'下一月',click:()=>change(new Date(p.year,p.month,1))},todayMonth:{text:'今天',click:()=>change(new Date())}},
 events:booked.map(s=>({id:s.id,start:`${s.meeting_date}T${s.start_time}`,end:`${s.meeting_date}T${s.end_time}`,title:`${s.start_time.slice(0,5)}–${s.end_time.slice(0,5)}\n${d.assignments.filter(a=>a.slot_id===s.id).map(a=>nameOf(d,a.teacher_id)).join('、')||'暂无班主任安排'}`,display:'block'})),
 eventTimeFormat:{hour:'2-digit',minute:'2-digit',hour12:false},displayEventTime:false,
 eventClick:info=>show(booked.filter(s=>s.id===info.event.id)),dateClick:info=>show(booked.filter(s=>s.meeting_date===info.dateStr))
 });instance.render();
}
