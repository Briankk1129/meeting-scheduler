export function cleanCell(value) {
      if (value === null || value === undefined) return '';
      return String(value).replace(/\u00a0/g, ' ').replace(/\s+/g, ' ').trim();
    }

export function compact(value) {
      return cleanCell(value).replace(/\s+/g, '');
    }

export function escapeHtml(str) {
      return cleanCell(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
    }


export const $ = (selector, root = document) => root.querySelector(selector);
export const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
export const labelSlot = s => `${s.meeting_date} ${s.start_time.slice(0,5)}–${s.end_time.slice(0,5)}`;
export const timeText = (value, timeZone='Asia/Shanghai') => value ? new Date(value).toLocaleString('zh-CN', {hour12:false,timeZone}) : '—';
export const zoneText = zone => ({'Asia/Shanghai':'中国标准时间','Asia/Tokyo':'日本标准时间'}[zone]||zone);
export const statusText = s => ({draft:'草稿',collecting:'收集中',closed:'已关闭',scheduled:'已排期'}[s] || s);
export function notify(message, error=false) {
 const box = $('#notice'); if (!box) return;
 box.textContent = message; box.className = error ? 'notice error' : 'notice success'; box.hidden=false;
}
export async function busy(button, task) {
 if(button?.disabled) return;
 if(button) button.disabled=true;
 try { return await task(); } catch(error) { notify(error.message || '操作失败，请重试',true); }
 finally { if(button) button.disabled=false; }
}
export function downloadText(name, text, type='text/plain') {
 const url=URL.createObjectURL(new Blob([text],{type})); const a=document.createElement('a'); a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
