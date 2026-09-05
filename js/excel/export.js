import {labelSlot} from '../utils.js';
import {nameOf,classOf,leaderName} from '../views/shared.js';
function write(name,sheets){
 if(!globalThis.XLSX)throw new Error('Excel 组件加载失败，请刷新页面');
 const wb=XLSX.utils.book_new();
 for(const [title,rows] of sheets){const ws=XLSX.utils.aoa_to_sheet(rows);ws['!cols']=rows[0].map((_,i)=>({wch:i>3?24:18}));XLSX.utils.book_append_sheet(wb,ws,title);}
 XLSX.writeFile(wb,name);
}
export function exportSchedule(d,p){
 if(!d.runs.length)throw new Error('请先生成会议安排');
 if(d.runs[0].source_revision!==p.revision)throw new Error('结果已过期，请重新排期后导出');
 const rows=[['日期','时间','负责人','班主任姓名','班级','是否固定安排']];
 for(const s of d.slots){const leaders=d.assignmentLeaders.filter(a=>a.slot_id===s.id).map(a=>leaderName(d,a.leader_id)).join('、');const assignments=d.assignments.filter(a=>a.slot_id===s.id);for(const a of assignments)rows.push([s.meeting_date,s.start_time.slice(0,5)+'–'+s.end_time.slice(0,5),leaders,nameOf(d,a.teacher_id),classOf(d,a.teacher_id),a.is_fixed?'是':'否']);if(!assignments.length&&leaders)rows.push([s.meeting_date,s.start_time.slice(0,5)+'–'+s.end_time.slice(0,5),leaders,'','','']);}
 const issues=[['类型','老师姓名','原因'],...(d.runs[0].issues.noAvailability||[]).map(x=>['没有可用时间',x.name,'未选择任何可用时间']),...(d.runs[0].issues.unscheduled||[]).map(x=>['未能安排',x.name,x.reason]),...d.members.filter(m=>m.excluded).map(m=>['本月不安排',m.name_snapshot,'管理员设置'])];
 const original=[['姓名','班级',...d.slots.map(labelSlot)],...d.members.map(m=>[m.name_snapshot,m.class_snapshot,...d.slots.map(s=>d.availability.some(a=>a.teacher_id===m.teacher_id&&a.slot_id===s.id)?'可开会':'')])];
 write(`${p.title}-会议安排.xlsx`,[['会议安排',rows],['未填写和未安排',issues],['识别数据',original]]);
}
export function exportSubmissions(d,p){
 const rows=[['姓名','班级','是否提交','首次提交时间(UTC)','最后修改时间(UTC)','可参加时间','本月不安排','来源'],...d.members.map(m=>[m.name_snapshot,m.class_snapshot,m.first_submitted_at?'是':'否',m.first_submitted_at||'',m.last_submitted_at||'',d.availability.filter(a=>a.teacher_id===m.teacher_id).map(a=>labelSlot(d.slots.find(s=>s.id===a.slot_id))).join('；'),m.excluded?'是':'否',m.submission_source==='import'?'Excel导入':m.first_submitted_at?'在线填写':''])];
 write(`${p.title}-填写情况.xlsx`,[['填写情况',rows]]);
}
