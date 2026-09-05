import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
import {generateSchedule} from '../js/scheduler/core.js';
import {parseSlotLabel} from '../js/excel/import.js';
const old=fs.readFileSync(new URL('./fixtures/legacy.html',import.meta.url),'utf8');
const helper=old.slice(old.indexOf('    function getAvailableSlots'),old.indexOf('    function renderStats'));
const algorithm=old.slice(old.indexOf('    function generateSchedule'),old.indexOf('    function splitSlotLabel'));
function oracle(input){
 const s=structuredClone(input);s.teachers=[...s.teachers,...s.leaders];
 const context=vm.createContext({state:s,REQUIRED_LEADERS:s.leaders.map(l=>l.name),cleanCell:x=>String(x??'').trim(),el:{globalLimit:{value:s.globalLimit},generateStatus:{}},saveToLocal(){},renderAll(){}});
 vm.runInContext(helper+algorithm+';generateSchedule()',context);
 return JSON.parse(JSON.stringify(context.state.schedule));
}
const teacher=(id,slots)=>({id,name:id,availability:Object.fromEntries(slots.map(s=>[s,true]))});
const base=()=>({teachers:[teacher('A',['s1','s2']),teacher('B',['s1'])],slots:[{id:'s1'},{id:'s2'}],globalLimit:1,slotLimits:{},fixedAssignments:[],excludedTeacherIds:[],leaders:[teacher('L',['s1','s2'])]});
test('augmenting paths schedule both teachers, not a greedy loss',()=>{const s=generateSchedule(base());assert.equal(s.scheduledCount,2);assert.deepEqual(s.assignments,{s1:['B'],s2:['A']});});
test('failed fixed assignment does not automatically fall back',()=>{const b=base();b.fixedAssignments=[{teacherId:'A',slotId:'missing'}];const s=generateSchedule(b);assert.equal(s.scheduledCount,1);assert.equal(s.unscheduled.length,1);});
test('zero capacity and excluded teachers',()=>{const b=base();b.slotLimits.s1=0;b.excludedTeacherIds=['A'];const s=generateSchedule(b);assert.equal(s.scheduledCount,0);assert.equal(s.unscheduled[0].name,'B');});
test('same names retain different IDs',()=>{const b=base();b.teachers.forEach(t=>t.name='同名');const s=generateSchedule(b);assert.equal(new Set(Object.values(s.assignments).flat()).size,2);});
test('one leader suffices and leaders do not occupy capacity',()=>{const b=base();b.leaders.push(teacher('L2',[]));const s=generateSchedule(b);assert.equal(s.scheduledCount,2);assert.deepEqual(s.leaders.s1,['L']);});
test('input is not mutated',()=>{const b=base(),copy=structuredClone(b);generateSchedule(b);assert.deepEqual(b,copy);});
test('300 seeded cases agree with the original algorithm',()=>{
 let seed=719;const rand=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/4294967296;};
 for(let k=0;k<300;k++){
  const slots=Array.from({length:1+Math.floor(rand()*6)},(_,i)=>({id:'s'+i}));
  const ids=slots.map(s=>s.id);const ts=Array.from({length:1+Math.floor(rand()*12)},(_,i)=>teacher('T'+String(i).padStart(2,'0'),ids.filter(()=>rand()>.45)));
  const b={teachers:ts,slots,globalLimit:1+Math.floor(rand()*3),slotLimits:Object.fromEntries(ids.filter(()=>rand()>.7).map(id=>[id,Math.floor(rand()*3)])),fixedAssignments:ts.filter(()=>rand()>.8).map(t=>({teacherId:t.id,slotId:ids[Math.floor(rand()*ids.length)]})),excludedTeacherIds:ts.filter(()=>rand()>.9).map(t=>t.id),leaders:[teacher('L1',ids.filter(()=>rand()>.3)),teacher('L2',ids.filter(()=>rand()>.6))]};
  const a=generateSchedule(b),o=oracle(b);
  assert.deepEqual(a.assignments,o.assignments,'case '+k);assert.deepEqual(a.leaders,o.leaders);assert.equal(a.scheduledCount,o.scheduledCount);assert.equal(a.noAvailabilityCount,o.noAvailabilityCount);
  const issues=x=>x.map(i=>[i.name,i.reason.replace('两位负责人','负责人')]);assert.deepEqual(issues(a.unscheduled),issues(o.unscheduled));
 }
});
test('legacy labels use explicit year or selected period year',()=>{assert.deepEqual(parseSlotLabel('9/7 19:00~19:30',2026),{meeting_date:'2026-09-07',start_time:'19:00',end_time:'19:30'});assert.throws(()=>parseSlotLabel('未知时间',2026));});
