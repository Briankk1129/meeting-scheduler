import {card,h,table,input,select,button,bindForm,bindActions,fillForm,dialog} from './shared.js';
import {$,busy,notify} from '../utils.js';
import {parseImport} from '../excel/import.js';
let preview=null;
export function render(ctx) {
 const {root,data:d,period:p}=ctx;
 const url=new URL('../',location.href).href;
 root.innerHTML=card('统一填写入口',`<p>把同一个链接发给所有班主任。老师选择月份和自己的姓名即可填写，也可以查看本月会议安排。</p><div class="row"><input id="share-link" aria-label="统一填写链接" readonly value="${h(url)}"><button id="copy-link" type="button">复制链接</button><a href="${h(url)}" target="_blank" rel="noopener">打开填写页面</a></div>`)+card('班主任档案',`<form id="teacher-form" class="form-grid"><input type="hidden" name="id">${input('name','姓名','text','','required maxlength="80"')}${input('class_name','班级')}${select('active','状态',[['true','启用'],['false','停用']])}<button>保存班主任</button><button type="reset" class="light">取消编辑</button></form><p class="footer-note">保存时加入当前月份。停用会阻止填写和后续排期；有历史数据的老师请使用停用。</p>`)+
 card('批量添加',`<form id="bulk-form" class="stack"><label>每行一位：姓名，班级<textarea name="text" placeholder="张三，一年1班&#10;李四，一年2班" required></textarea></label><div class="row"><button>批量添加</button><label>或从 Excel 导入<input id="import-file" class="file-input" type="file" accept=".xlsx,.xls,.csv"></label></div></form><p class="footer-note">导入会先预览。原可用时间表也能读取，时间迁移请在导入预览中选择。</p>`)+
 card('班主任名单',`<div class="toolbar">${p?button('add-all','',`将所有启用老师加入${p.month}月`):'<span class="muted">请先创建排期月份。</span>'}</div>`+table(['姓名','班级','全局状态','当前月份','填写','操作'],d.teachers.map(t=>{const m=d.members.find(x=>x.teacher_id===t.id);return[h(t.name),h(t.class_name),t.active?'启用':'停用',m?(m.excluded?'本月不安排':'已加入'):'未加入',m?.first_submitted_at?'<span class="badge ok">已填写</span>':'未填写',button('edit',t.id,'编辑')+button('delete',t.id,'删除','danger')];})));
 $('#copy-link').onclick=()=>busy($('#copy-link'),async()=>{await navigator.clipboard.writeText(url);notify('统一填写链接已复制');});
 bindForm('#teacher-form',f=>ctx.mutate('teacher_save',{...f,active:f.active==='true'}));
 bindForm('#bulk-form',async f=>{const teachers=f.text.split(/\r?\n/).map(s=>s.trim()).filter(Boolean).map(s=>{const [name,...rest]=s.split(/[,，\t]/);return{name:name.trim(),class_name:rest.join(' ').trim()};});if(!teachers.length)return;if(!confirm(`新增 ${teachers.length} 位班主任？不会合并同名档案。`))return;await ctx.mutate('teacher_bulk',{teachers});});
 bindActions(async(action,id)=>{
 const t=d.teachers.find(t=>t.id===id);
 if(action==='edit')return fillForm('#teacher-form',t);
 if(action==='delete'&&confirm(`删除 ${t.name}？有历史记录时将拒绝删除，请改为停用。`))return ctx.mutate('teacher_delete',{id});
 if(action==='add-all')return ctx.mutate('member_add',{teacher_ids:d.teachers.filter(t=>t.active).map(t=>t.id)});

 });
 $('#import-file').onchange=event=>busy(event.target,async()=>{
 const file=event.target.files[0];if(!file)return;
 preview=await parseImport(file);
 dialog(`<h2>导入预览</h2><p>${preview.teachers.length} 位老师，${preview.slots.length} 个时间段。</p>${table(['姓名','班级'],preview.teachers.slice(0,12).map(t=>[h(t.name),h(t.class_name)]))}<p class="footer-note">仅显示前12行。新增档案，不自动合并同名老师。</p>${preview.slots.length&&p?'<label class="check-row"><input id="import-availability" type="checkbox">同时迁移原表可用时间到当前月份</label><p class="footer-note">非空即有空（包括“否”）。未写年份使用当前月份年份；其他月份日期会拒绝导入。表中的负责人需先在负责人管理中创建同名档案。</p>':''}<button id="confirm-import">确认导入</button>`);
 $('#confirm-import').onclick=()=>busy($('#confirm-import'),async()=>{
 if($('#import-availability')?.checked){const {parseSlotLabel}=await import('../excel/import.js');await ctx.mutate('legacy_import',{...preview,slots:preview.slots.map(s=>parseSlotLabel(s,p.year))});}
 else await ctx.mutate('teacher_bulk',{teachers:preview.teachers});
 $('#details').close();notify('导入完成');
 });
 });
}
