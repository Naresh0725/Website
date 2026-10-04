import type { Pool,PoolClient } from 'pg';
export interface SessionRow {token_hash:string;user_id:string;encrypted_tokens:string;scope:'account'|'recovery';csrf_hash:string;expires_at:string;idle_expires_at:string;}
export interface Profile {id:string;display_name:string;preferred_language:string;timezone:string;roles:string[];permissions:string[];}
export interface Store {
 transaction<T>(fn:(store:Store)=>Promise<T>):Promise<T>;
 provision(user:string):Promise<void>; profile(user:string):Promise<Profile>;
 updateProfile(user:string,name:string,language:string,timezone:string):Promise<Profile>;
 changeRole(actor:string,target:string,role:string,grant:boolean,reason:string,mfa:boolean):Promise<void>;
 createSession(hash:string,user:string,tokens:string,scope:string,csrf:string):Promise<void>;
 lockSession(hash:string):Promise<SessionRow|undefined>;touchSession(hash:string,tokens:string):Promise<void>;
 deleteSession(hash:string):Promise<void>;revokeSessions(user:string):Promise<void>;
 createFlow(hash:string,verifier:string):Promise<void>;consumeFlow(hash:string):Promise<string|null>;
 rate(bucket:string,limit:number,seconds:number):Promise<boolean>;
}
export class PgAuthStore implements Store {
 constructor(private pool:Pool,private client?:PoolClient){}
 private async call<T>(fn:string,args:unknown[]):Promise<T>{const db=this.client??this.pool;return (await db.query(`SELECT exam.${fn}(${args.map((_,i)=>'$'+(i+1)).join(',')}) AS value`,args)).rows[0].value as T;}
 async transaction<T>(fn:(store:Store)=>Promise<T>):Promise<T>{if(this.client)return fn(this);const c=await this.pool.connect();try{await c.query('BEGIN');await c.query("SET LOCAL lock_timeout='5s'");const result=await fn(new PgAuthStore(this.pool,c));await c.query('COMMIT');return result;}catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();}}
 provision(u:string){return this.call<void>('provision_user',[u]);}
 profile(u:string){return this.call<Profile>('account_profile',[u]);}
 updateProfile(u:string,n:string,l:string,t:string){return this.call<Profile>('update_account_profile',[u,n,l,t]);}
 changeRole(a:string,u:string,r:string,g:boolean,reason:string,m:boolean){return this.call<void>('change_account_role',[a,u,r,g,reason,m]);}
 createSession(h:string,u:string,t:string,s:string,c:string){return this.call<void>('create_auth_session',[h,u,t,s,c]);}
 async lockSession(h:string){return (await (this.client??this.pool).query('SELECT * FROM exam.lock_auth_session($1)',[h])).rows[0] as SessionRow|undefined;}
 touchSession(h:string,t:string){return this.call<void>('touch_auth_session',[h,t]);}
 deleteSession(h:string){return this.call<void>('delete_auth_session',[h]);}
 revokeSessions(u:string){return this.call<void>('revoke_account_sessions',[u]);}
 createFlow(h:string,v:string){return this.call<void>('create_auth_flow',[h,v]);}
 consumeFlow(h:string){return this.call<string|null>('consume_auth_flow',[h]);}
 rate(b:string,l:number,s:number){return this.call<boolean>('auth_rate_limit',[b,l,s]);}
}
