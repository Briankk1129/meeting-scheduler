import {$,busy,notify} from './utils.js';
import {login} from './auth.js';
import {configured} from './supabase.js';
if(!configured)notify('请先在 js/config.js 配置 Supabase 项目，详见 README。',true);
$('#login-form').addEventListener('submit',event=>{event.preventDefault();const f=new FormData(event.target);busy(event.submitter,()=>login(f.get('email').trim(),f.get('password')));});
