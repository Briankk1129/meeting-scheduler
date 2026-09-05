import {cleanCell,compact} from '../utils.js';
export function isNameHeader(value) {
      const s = compact(value);
      return /(班主任|任老师|老師|老师|教师|教師|姓名|班主.*任老|负责人|負責人)/.test(s);
    }

export function isTimeHeader(value) {
      const s = cleanCell(value);
      if (!s) return false;
      const hasDate = /(\d{4}[\/\-.年]\s*\d{1,2}|\d{1,2}\s*[\/\-.月]\s*\d{1,2}|\d{1,2}\s*月\s*\d{1,2}\s*日?)/.test(s);
      const hasTime = /(\d{1,2}\s*[:：.]\s*\d{2}|\d{1,2}\s*[点時时])/.test(s);
      const hasRange = /[~～\-—–至到]/.test(s);
      return hasDate && (hasTime || hasRange);
    }

export function looksLikePersonName(value) {
      const s = cleanCell(value);
      if (!s) return false;
      if (s.length > 12) return false;
      if (isTimeHeader(s) || isNameHeader(s)) return false;
      return /[\u4e00-\u9fa5ぁ-んァ-ンA-Za-z]/.test(s);
    }

export function detectStructure(rows) {
      const maxRows = Math.min(rows.length, 30);
      let best = null;

      for (let r = 0; r < maxRows; r++) {
        const row = rows[r] || [];
        const nameCol = row.findIndex(isNameHeader);
        const timeCols = [];
        for (let c = 0; c < row.length; c++) {
          if (isTimeHeader(row[c])) timeCols.push(c);
        }
        let score = timeCols.length * 10 + (nameCol >= 0 ? 8 : 0);
        if (timeCols.length >= 2 && nameCol < 0) score += 2;
        if (!best || score > best.score) best = { headerRow: r, nameCol, timeCols, score };
      }

      if (!best || best.timeCols.length === 0) {
        throw new Error('没有识别到日期时间字段。请确认表头中包含类似“5/22 19:00~21:00”的字段。');
      }

      if (best.nameCol < 0) {
        const firstTimeCol = Math.min(...best.timeCols);
        let candidate = 0;
        let bestCount = -1;
        for (let c = 0; c < firstTimeCol; c++) {
          let count = 0;
          for (let r = best.headerRow + 1; r < rows.length; r++) {
            if (looksLikePersonName(rows[r]?.[c])) count++;
          }
          if (count > bestCount) {
            bestCount = count;
            candidate = c;
          }
        }
        best.nameCol = candidate;
      }

      return best;
    }

export function normalizeRows(rows) {
      return rows
        .map(row => (row || []).map(cleanCell))
        .filter(row => row.some(cell => cleanCell(cell) !== ''));
    }

export function readWorkbook(file) {
      if (!window.XLSX) {
        throw new Error('XLSX 读取库没有加载成功。请确认电脑可以访问网络，或使用“启动.command”通过本地服务打开页面。');
      }
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = event => {
          try {
            const data = new Uint8Array(event.target.result);
            const workbook = XLSX.read(data, { type: 'array', cellDates: false });
            const firstSheetName = workbook.SheetNames[0];
            const sheet = workbook.Sheets[firstSheetName];
            const rawRows = XLSX.utils.sheet_to_json(sheet, { header: 1, raw: false, defval: '' });
            resolve(normalizeRows(rawRows));
          } catch (error) {
            reject(error);
          }
        };
        reader.onerror = () => reject(new Error('文件读取失败。'));
        reader.readAsArrayBuffer(file);
      });
    }


export async function parseImport(file) {
 const rows=await readWorkbook(file);
 let detection;
 try { detection=detectStructure(rows); } catch { detection=null; }
 if(!detection) {
  const headerIndex=rows.findIndex(r=>r.some(isNameHeader));
  if(headerIndex<0) throw new Error('未找到姓名列。请使用“姓名、班级”表头。');
  const head=rows[headerIndex], ni=head.findIndex(isNameHeader), ci=head.findIndex(x=>/班级|班級/.test(x));
  return {teachers:rows.slice(headerIndex+1).filter(r=>cleanCell(r[ni])).map(r=>({name:cleanCell(r[ni]),class_name:ci>=0?cleanCell(r[ci]):''})), slots:[], availability:[]};
 }
 const head=rows[detection.headerRow], ci=head.findIndex(x=>/班级|班級/.test(x));
 const data=rows.slice(detection.headerRow+1).filter(r=>cleanCell(r[detection.nameCol])&&!isNameHeader(r[detection.nameCol])&&!isTimeHeader(r[detection.nameCol]));
 return {teachers:data.map(r=>({name:cleanCell(r[detection.nameCol]),class_name:ci>=0?cleanCell(r[ci]):''})),slots:detection.timeCols.map(c=>head[c]),availability:data.map(r=>detection.timeCols.map(c=>cleanCell(r[c])!==''))};
}
export function parseSlotLabel(label, year) {
 const m=label.match(/(?:(\d{4})[年/.-])?(\d{1,2})[月/.-](\d{1,2})日?\s*(\d{1,2})[:：.](\d{2})\s*[~～—–至到-]\s*(\d{1,2})[:：.](\d{2})/);
 if(!m) throw new Error('时间无法自动转换，请手动创建：'+label);
 const pad=s=>String(s).padStart(2,'0');
 return {meeting_date:`${m[1]||year}-${pad(m[2])}-${pad(m[3])}`,start_time:`${pad(m[4])}:${m[5]}`,end_time:`${pad(m[6])}:${m[7]}`};
}
