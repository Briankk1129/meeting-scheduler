import {requireConfig,unwrap} from '../supabase.js';
export const snapshot=async period=>unwrap(await requireConfig().rpc('admin_snapshot',{p_period:period||null}));
export const command=async(action,data)=>unwrap(await requireConfig().rpc('admin_command',{p_action:action,p_data:data}));
