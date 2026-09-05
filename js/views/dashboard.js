import {zoneText} from '../utils.js';
import {card,h} from './shared.js';
export function render(ctx) {
 const {data:d,period:p,root}=ctx;
 if(!p){root.innerHTML=card('欢迎使用班主任会议排期系统','<p>先创建一个排期月份，再添加班主任和会议时间。</p><a class="badge" href="#/periods">创建第一个月份 →</a>');return;}
 const submitted=d.members.filter(m=>m.first_submitted_at).length,run=d.runs[0];
 const items=[['本月班主任',d.members.length],['已填写',submitted],['未填写',d.members.length-submitted],['可开会日期',new Set(d.slots.map(s=>s.meeting_date)).size],['时间段',d.slots.length],['已安排',d.assignments.length],['未能安排',run?.issues?.unscheduled?.length||0],['本月不安排',d.members.filter(m=>m.excluded).length]];
 root.innerHTML=`${run&&run.source_revision!==p.revision?'<div class="warning">资料已更新，现有排期结果已过期，请重新排期。</div>':''}<div class="metrics">${items.map(([name,n])=>`<div class="metric"><span>${name}</span><strong>${n}</strong></div>`).join('')}</div><div class="grid">${card('本月填写进度',`<div class="section-head"><strong>${submitted} / ${d.members.length} 位</strong><span class="badge">${Math.round(100*submitted/(d.members.length||1))}%</span></div><progress value="${submitted}" max="${d.members.length||1}"></progress><p class="footer-note">已提交但没有可用时间，也计入已填写。未填写和排期失败分别统计。</p><a href="#/submissions">查看填写名单 →</a>`)}${card('下一步',`<div class="stack"><a href="#/slots">① 设置会议时间 →</a><a href="#/periods">② 开放本月填写 →</a><a href="#/teachers">③ 复制统一填写链接 →</a><a href="#/scheduler">④ 关闭填写并自动排期 →</a><a href="#/calendar">⑤ 查看会议日历 →</a></div>`)}</div>${card('当前月份',`<p><strong>${h(p.title)}</strong> · 时区 ${h(zoneText(p.timezone))}</p><p class="muted">每个时间段默认最多 ${p.default_capacity} 位班主任，负责人不占人数。</p><a href="#/periods">管理月份与收集状态 →</a>`)}`;
}
