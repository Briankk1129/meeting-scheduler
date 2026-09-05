import {card,h,table,input,select,bindForm,bindActions,button,fillForm} from './shared.js';
import {statusText} from '../utils.js';
export function render(ctx) {
 const {root,data:d,period:p}=ctx;const today=new Date();
 root.innerHTML=card('创建排期月份',`<form id="period-create" class="form-grid">${input('year','年份','number',today.getFullYear(),'min="2000" max="2200" required')}${input('month','月份','number',today.getMonth()+1,'min="1" max="12" required')}${input('title','标题（留空自动生成）')}${select('timezone','会议时区',[['Asia/Shanghai','中国标准时间'],['Asia/Tokyo','日本标准时间']])}${input('default_capacity','默认每段人数','number',3,'min="1" max="100" required')}<button>创建月份</button></form><p class="footer-note">自动加入当前启用的班主任和负责人。其他月份的数据保持独立。</p>`)+
 (p?card('当前月份设置',`<form id="period-edit" class="form-grid">${input('title','月份名称','text',p.title,'required')}${select('status','填写状态',[['draft','草稿'],['collecting','开放填写'],['closed','关闭填写']],p.status==='scheduled'?'closed':p.status)}${select('timezone','会议时区',[['Asia/Shanghai','中国标准时间'],['Asia/Tokyo','日本标准时间']],p.timezone)}${input('default_capacity','默认每段人数','number',p.default_capacity,'min="1" max="100" required')}<button>保存设置</button></form><p class="footer-note">已排期状态由保存排期结果自动设置。更改设置会使已有结果过期。</p>`):'')+
 card('月份列表',table(['月份','状态','默认容量','操作'],d.periods.map(x=>[h(x.title),h(statusText(x.status)),x.default_capacity,button('switch',x.id,'切换到此月')])));
 bindForm('#period-create',async f=>{f.title=f.title.trim()||`${f.year}年${f.month}月会议`;await ctx.mutate('period_create',f);});
 bindForm('#period-edit',f=>ctx.mutate('period_update',f));bindActions((action,id)=>ctx.selectPeriod(id));
}
