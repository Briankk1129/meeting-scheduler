import {labelSlot} from '../utils.js';
export function toScheduler(data,period) {
 const available=(rows,key,id)=>Object.fromEntries(rows.filter(r=>r[key]===id).map(r=>[r.slot_id,true]));
 const leaderIds=new Set(data.periodLeaders.map(x=>x.leader_id));
 const leaders=data.leaders.filter(l=>l.active&&leaderIds.has(l.id)).map(l=>({id:l.id,name:data.periodLeaders.find(p=>p.leader_id===l.id).name_snapshot,availability:available(data.leaderAvailability,'leader_id',l.id)}));
 return {
  teachers:data.members.map(m=>({id:m.teacher_id,name:m.name_snapshot,isLeader:data.leaders.some(l=>l.teacher_id===m.teacher_id&&leaderIds.has(l.id)),availability:available(data.availability,'teacher_id',m.teacher_id)})),
  slots:data.slots.map(s=>({id:s.id,label:labelSlot(s),order:s.sort_order})),
  globalLimit:period.default_capacity,slotLimits:Object.fromEntries(data.slots.map(s=>[s.id,s.capacity_override])),
  excludedTeacherIds:data.members.filter(m=>m.excluded||!data.teachers.find(t=>t.id===m.teacher_id)?.active).map(m=>m.teacher_id),
  fixedAssignments:data.fixed.map(f=>({teacherId:f.teacher_id,teacherName:data.members.find(m=>m.teacher_id===f.teacher_id)?.name_snapshot,slotId:f.slot_id})),leaders
 };
}
export function toSave(result,data) {
 return {assignments:Object.entries(result.assignments).flatMap(([slot_id,ids])=>ids.map(teacher_id=>({slot_id,teacher_id,is_fixed:data.fixed.some(f=>f.teacher_id===teacher_id&&f.slot_id===slot_id)}))),
 issues:{unscheduled:result.unscheduled,noAvailability:result.noAvailability,blockedSlots:result.blockedSlots,scheduledCount:result.scheduledCount,noAvailabilityCount:result.noAvailabilityCount}};
}
