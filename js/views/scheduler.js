import {card,h,table,select,button,bindForm,bindActions,nameOf,classOf,leaderName} from './shared.js';
import {$,busy,labelSlot} from '../utils.js';
import {generateSchedule,ALGORITHM_VERSION} from '../scheduler/core.js';
import {toScheduler,toSave} from '../scheduler/adapter.js';
export function render(ctx){
 const {root,data:d,period:p}=ctx;if(!p)return ctx.needPeriod();
 const run=d.runs[0];
 root.innerHTML=card('自动排期',`<p>固定安排优先。每位班主任只安排一次；至少一位负责人可参加的时间才会使用。</p>${run&&run.source_revision!==p.revision?'<div class="warning">基础数据已改变，下面的结果已过期，请重新生成。</div>':''}<div class="row"><button id="generate" ${['closed','scheduled'].includes(p.status)?'':'disabled'}>生成并保存排期</button>${p.status==='collecting'?'<button id="close-period" class="light">关闭填写</button>':''}<a href="#/calendar">查看会议日历 →</a></div><p class="footer-note">先在月份管理中关闭填写。生成后直接保存到数据库；重复生成会建立新批次。固定安排失败不会自动改排其他时间。</p>`)+
 card('固定安排',`<form id="fixed-form" class="form-grid">${select('teacher_id','班主任',d.members.filter(m=>!m.excluded&&!d.leaders.some(l=>l.teacher_id===m.teacher_id)).map(m=>[m.teacher_id,m.name_snapshot+' '+m.class_snapshot]))}${select('slot_id','时间段',d.slots.map(s=>[s.id,labelSlot(s)]))}<button ${d.members.length&&d.slots.length?'':'disabled'}>保存固定安排</button></form><div style="margin-top:16px">${table(['班主任','指定时间','操作'],d.fixed.map(f=>[h(nameOf(d,f.teacher_id)),h(labelSlot(d.slots.find(s=>s.id===f.slot_id))),button('remove-fixed',f.teacher_id,'取消指定')]))}</div>`)+
 card('本月不安排',table(['班主任','班级','是否参与排期','操作'],d.members.map(m=>[h(m.name_snapshot),h(m.class_snapshot),m.excluded?'不安排':'参与',button(m.excluded?'include':'exclude',m.teacher_id,m.excluded?'恢复参与':'本月不安排')])));
 if(run){
 root.innerHTML+=card('已保存的会议安排',table(['日期时间','负责人','班主任','班级','类型'],d.assignments.map(a=>[h(labelSlot(d.slots.find(s=>s.id===a.slot_id))),d.assignmentLeaders.filter(l=>l.slot_id===a.slot_id).map(l=>h(leaderName(d,l.leader_id))).join('、'),h(nameOf(d,a.teacher_id)),h(classOf(d,a.teacher_id)),a.is_fixed?'指定':'自动'])));
 root.innerHTML+=`<div class="grid">${card('没有可用时间',table(['姓名'],(run.issues.noAvailability||[]).map(x=>[h(x.name)])))}${card('未能安排及原因',table(['姓名','原因'],(run.issues.unscheduled||[]).map(x=>[h(x.name),h(x.reason)])))}</div>`;
 }
 $('#generate').onclick=()=>busy($('#generate'),async()=>{if(run&&!confirm('生成新的排期批次并替换当前结果？'))return;const result=generateSchedule(toScheduler(d,p));await ctx.mutate('save_schedule',{...toSave(result,d),algorithm_version:ALGORITHM_VERSION});});
 $('#close-period')?.addEventListener('click',()=>busy($('#close-period'),()=>ctx.mutate('period_update',{status:'closed'})));
 bindForm('#fixed-form',f=>ctx.mutate('fixed_save',f));bindActions((action,id)=>action==='remove-fixed'?ctx.mutate('fixed_delete',{teacher_id:id}):ctx.mutate('member_set',{teacher_id:id,excluded:action==='exclude'}));
}
