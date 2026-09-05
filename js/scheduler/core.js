// Matching order and augmenting-path logic retained from the supplied index.html.
export const ALGORITHM_VERSION = 'legacy-matching-1.0';
export function generateSchedule(input) {
 const state=structuredClone(input);
 const names=new Map(state.teachers.map(t=>[t.id,t.name]));
 const getAvailableSlots=t=>state.slots.filter(s=>t.availability?.[s.id]);
 const getRequiredLeaders=()=>state.leaders.map(l=>({name:l.name,teacher:l}));
 const availableLeaderNamesForSlot=id=>state.leaders.filter(l=>l.availability?.[id]).map(l=>l.id);
 const getSchedulableSlots=()=>state.slots.filter(s=>state.leaders.some(l=>l.availability?.[s.id]));
 const fixedTeacherIds=()=>new Set(state.fixedAssignments.map(f=>f.teacherId));
 const excludedTeacherIds=()=>new Set(state.excludedTeacherIds);
 const getLimit=id=>Math.max(0,Math.floor(Number(state.slotLimits[id]??state.globalLimit)||0));
      const requiredLeaders = getRequiredLeaders();
      const missingLeaders = requiredLeaders.filter(item => !item.teacher).map(item => item.name);
      const schedulableSlotIds = new Set(getSchedulableSlots().map(slot => slot.id));
      const blockedSlots = state.slots.filter(slot => !schedulableSlotIds.has(slot.id)).map(slot => slot.id);
      const fixedIds = fixedTeacherIds();
      const excludedIds = excludedTeacherIds();
      const assignments = Object.fromEntries(state.slots.map(slot => [slot.id, []]));
      const fixedUnscheduled = [];
      const fixedAssignedTeacherIds = new Set();

      (state.fixedAssignments || []).forEach(item => {
        const teacher = state.teachers.find(t => t.id === item.teacherId);
        const slot = state.slots.find(s => s.id === item.slotId);
        if (!teacher || !slot) {
          fixedUnscheduled.push({ name: item.teacherName || '未知老师', reason: '指定安排中的老师或时间不存在' });
          return;
        }
        if (excludedIds.has(teacher.id)) return;
        if (fixedAssignedTeacherIds.has(teacher.id)) {
          fixedUnscheduled.push({ teacherId: teacher.id, name: teacher.name.trim(), reason: '同一老师被指定了多个时间，只能安排一次' });
          return;
        }
        if (!teacher.availability?.[slot.id]) {
          fixedUnscheduled.push({ teacherId: teacher.id, name: teacher.name.trim(), reason: '指定时间未勾选可开会' });
          return;
        }
        if (!schedulableSlotIds.has(slot.id)) {
          fixedUnscheduled.push({ teacherId: teacher.id, name: teacher.name.trim(), reason: '指定时间没有负责人勾选，无法安排会议' });
          return;
        }
        const limit = getLimit(slot.id);
        if (assignments[slot.id].length >= limit) {
          fixedUnscheduled.push({ teacherId: teacher.id, name: teacher.name.trim(), reason: '指定时间人数上限已满' });
          return;
        }
        assignments[slot.id].push(teacher.id);
        fixedAssignedTeacherIds.add(teacher.id);
      });

      const eligible = state.teachers
        .map((teacher, index) => ({ teacher, index, slots: getAvailableSlots(teacher) }))
        .filter(item => item.teacher.name.trim() && !item.teacher.isLeader)
        .filter(item => !excludedIds.has(item.teacher.id))
        .filter(item => !fixedIds.has(item.teacher.id))
        .map(item => ({ ...item, slots: item.slots.filter(slot => schedulableSlotIds.has(slot.id)) }))
        .filter(item => item.slots.length > 0);

      const noAvailability = state.teachers.filter(t => t.name.trim() && !t.isLeader && !excludedIds.has(t.id) && !fixedIds.has(t.id) && getAvailableSlots(t).length === 0);
      const blockedByLeaders = state.teachers
        .filter(t => t.name.trim() && !t.isLeader && !excludedIds.has(t.id) && !fixedIds.has(t.id) && getAvailableSlots(t).length > 0)
        .filter(t => getAvailableSlots(t).every(slot => !schedulableSlotIds.has(slot.id)));
      const seats = [];
      state.slots.forEach(slot => {
        if (!schedulableSlotIds.has(slot.id)) return;
        const limit = getLimit(slot.id);
        const availableSeats = Math.max(0, limit - assignments[slot.id].length);
        for (let i = 0; i < availableSeats; i++) seats.push({ slotId: slot.id, seatNo: i });
      });

      const slotOrder = new Map(state.slots.map((slot, idx) => [slot.id, idx]));
      const teacherOrder = eligible
        .slice()
        .sort((a, b) => a.slots.length - b.slots.length || a.index - b.index);
      const teacherByIndex = new Map(eligible.map(item => [item.index, item]));
      const edges = new Map();
      eligible.forEach(item => {
        const availableSlotIds = new Set(item.slots.map(slot => slot.id));
        const edgeSeats = seats
          .map((seat, seatIndex) => ({ seat, seatIndex }))
          .filter(x => availableSlotIds.has(x.seat.slotId))
          .sort((a, b) => slotOrder.get(a.seat.slotId) - slotOrder.get(b.seat.slotId) || a.seatNo - b.seatNo)
          .map(x => x.seatIndex);
        edges.set(item.index, edgeSeats);
      });

      const matchSeatToTeacher = new Array(seats.length).fill(null);
      function tryAssign(teacherIndex, seen) {
        const edgeSeats = edges.get(teacherIndex) || [];
        for (const seatIndex of edgeSeats) {
          if (seen[seatIndex]) continue;
          seen[seatIndex] = true;
          if (matchSeatToTeacher[seatIndex] === null || tryAssign(matchSeatToTeacher[seatIndex], seen)) {
            matchSeatToTeacher[seatIndex] = teacherIndex;
            return true;
          }
        }
        return false;
      }

      teacherOrder.forEach(item => {
        tryAssign(item.index, new Array(seats.length).fill(false));
      });

      const leaders = Object.fromEntries(state.slots.map(slot => [
        slot.id,
        schedulableSlotIds.has(slot.id) ? availableLeaderNamesForSlot(slot.id) : []
      ]));
      const assignedTeacherIndexes = new Set();
      matchSeatToTeacher.forEach((teacherIndex, seatIndex) => {
        if (teacherIndex === null) return;
        const item = teacherByIndex.get(teacherIndex);
        if (!item) return;
        const slotId = seats[seatIndex].slotId;
        assignments[slotId].push(item.teacher.id);
        assignedTeacherIndexes.add(teacherIndex);
      });

      state.slots.forEach(slot => {
        assignments[slot.id].sort((a, b) => names.get(a).localeCompare(names.get(b), 'zh-Hans-CN'));
      });

      const unscheduled = eligible
        .filter(item => !assignedTeacherIndexes.has(item.index))
        .map(item => ({ teacherId: item.teacher.id, name: item.teacher.name.trim(), reason: '可选日期已满' }));
      fixedUnscheduled.forEach(item => unscheduled.push(item));
      blockedByLeaders.forEach(teacher => {
        unscheduled.push({ teacherId: teacher.id, name: teacher.name.trim(), reason: '负责人均未勾选该老师可选时间，无法安排会议' });
      });
      missingLeaders.forEach(name => {
        unscheduled.push({ name, reason: '负责人不在表格中，无法确认可开会时间' });
      });

      return {
        assignments,
        leaders,
        blockedSlots,
        unscheduled,
        noAvailability: noAvailability.map(t => ({teacherId:t.id,name:t.name.trim()})),
        scheduledCount: assignedTeacherIndexes.size + fixedAssignedTeacherIds.size,
        noAvailabilityCount: noAvailability.length,
        generatedAt: new Date().toISOString()
      };

}
