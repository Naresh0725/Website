import { authPage } from './pages.js';
import { randomUUID } from 'node:crypto';
import { hash,token,equalHash,Vault } from './crypto.js';
import { ProviderError,type AuthProvider,type Identity,type Tokens } from './provider.js';
import type { Store,SessionRow,Profile } from './store.js';
export class HttpError extends Error{constructor(public status:number,public code:string){super(code);}}
function fail(status:number,code:string):never{throw new HttpError(status,code);}
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const SESSION='__Host-exam_session',CSRF='__Host-exam_csrf',FLOW='__Host-exam_flow';
function cookies(req:Request){const out:Record<string,string>={};for(const pair of (req.headers.get('cookie')??'').split(';')){const i=pair.indexOf('=');if(i>0)out[pair.slice(0,i).trim()]=pair.slice(i+1).trim();}return out;}
function cookie(name:string,value:string,maxAge:number,httpOnly=true){return `${name}=${value}; Path=/; Secure; SameSite=Lax; Max-Age=${maxAge}${httpOnly?'; HttpOnly':''}`;}
function response(data:unknown,status=200,cs:string[]=[]){const h=new Headers({'Content-Type':'application/json','Cache-Control':'no-store','Pragma':'no-cache','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','Content-Security-Policy':"default-src 'none'; frame-ancestors 'none'"});for(const c of cs)h.append('Set-Cookie',c);return new Response(JSON.stringify(data),{status,headers:h});}
function keys(body:Record<string,unknown>,allowed:string[]){if(Object.keys(body).some(k=>!allowed.includes(k)))fail(400,'UNEXPECTED_FIELD');}
function field(body:Record<string,unknown>,name:string,max=500){const v=body[name];if(typeof v!=='string'||!v||v.length>max)fail(400,'INVALID_INPUT');return v as string;}
function email(body:Record<string,unknown>){const e=field(body,'email',254).trim().toLowerCase();if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e))fail(400,'INVALID_EMAIL');return e;}
function password(body:Record<string,unknown>){const p=field(body,'password',128);if(p.length<12)fail(400,'PASSWORD_TOO_SHORT');return p;}
export interface AuthConfig {origin:string;encryptionKey:string;onError?:(id:string)=>void;}
export class AuthApi {
 private vault:Vault;private origin:string;
 constructor(private store:Store,private provider:AuthProvider,private config:AuthConfig){const url=new URL(config.origin);if(url.protocol!=='https:'||url.origin!==config.origin)throw Error('APP_ORIGIN must be an HTTPS origin');this.origin=url.origin;this.vault=new Vault(config.encryptionKey);}
 async handle(req:Request,peerIp:string):Promise<Response>{
  try{return await this.route(req,peerIp);}catch(e){
   if(e instanceof HttpError)return response({error:e.code},e.status,e.status===401?[cookie(SESSION,'',0),cookie(CSRF,'',0,false)]:[]);
   if(e instanceof ProviderError)return response({error:e.status===503?'AUTH_SERVICE_UNAVAILABLE':'AUTHENTICATION_FAILED'},e.status===503?503:401);
   const text=e instanceof Error?e.message:'';
   if(/ACCOUNT_NOT_ACTIVE/.test(text))return response({error:'ACCOUNT_NOT_ACTIVE'},403);
   if(/ROLE_CHANGE_FORBIDDEN|MFA_REQUIRED/.test(text))return response({error:'FORBIDDEN'},403);
   if(/INVALID_PROFILE|INVALID_ROLE_CHANGE/.test(text))return response({error:'INVALID_INPUT'},400);
   const id=randomUUID();this.config.onError?.(id);return response({error:'AUTH_SERVICE_UNAVAILABLE',request_id:id},503);
  }
 }
 private async body(req:Request){if(!req.headers.get('content-type')?.startsWith('application/json'))fail(415,'JSON_REQUIRED');const text=await req.text();if(Buffer.byteLength(text)>8192)fail(413,'BODY_TOO_LARGE');let b:unknown;try{b=JSON.parse(text);}catch{fail(400,'INVALID_JSON');}if(!b||typeof b!=='object'||Array.isArray(b))fail(400,'INVALID_JSON');return b as Record<string,unknown>;}
 private async limited(ip:string,path:string,e?:string){if(!await this.store.rate(hash(`ip:${ip}:${path}`),30,900))fail(429,'RATE_LIMITED');if(e&&!await this.store.rate(hash(`account:${e}:${path}`),10,900))fail(429,'RATE_LIMITED');}
 private async establish(req:Request,t:Tokens,scope:'account'|'recovery'){
  const id=await this.provider.identity(t.access_token);if(!id.verified)fail(403,'EMAIL_VERIFICATION_REQUIRED');
  const sid=token(),csrf=token();const profile=await this.store.transaction(async s=>{await s.provision(id.id);const p=await s.profile(id.id);const old=cookies(req)[SESSION];if(old)await s.deleteSession(hash(old));await s.createSession(hash(sid),id.id,this.vault.seal(t),scope,hash(csrf));return p;});
  return response({scope,profile:scope==='account'?profile:undefined,csrf},200,[cookie(SESSION,sid,scope==='recovery'?600:86400),cookie(CSRF,csrf,scope==='recovery'?600:86400,false)]);
 }
 private async session<T>(req:Request,scope:'account'|'recovery',mutate:boolean,fn:(s:Store,row:SessionRow,t:Tokens,id:Identity)=>Promise<T>){
  const raw=cookies(req)[SESSION];if(!raw||!/^[A-Za-z0-9_-]{43}$/.test(raw))fail(401,'AUTHENTICATION_REQUIRED');
  return this.store.transaction(async s=>{
   const row=await s.lockSession(hash(raw));if(!row)fail(401,'AUTHENTICATION_REQUIRED');
   if(row.scope!==scope)fail(403,'SESSION_SCOPE_FORBIDDEN');
   if(mutate&&!equalHash(req.headers.get('x-csrf-token')??'',row.csrf_hash))fail(403,'CSRF_REQUIRED');
   let t=this.vault.open<Tokens>(row.encrypted_tokens);
   if(t.expires_at<=Date.now()/1000+30)t=await this.provider.refresh(t.refresh_token);
   const id=await this.provider.identity(t.access_token);if(id.id!==row.user_id||!id.verified)fail(401,'AUTHENTICATION_REQUIRED');
   await s.touchSession(row.token_hash,this.vault.seal(t));return fn(s,row,t,id);
  });
 }
 private async route(req:Request,ip:string):Promise<Response>{
  const url=new URL(req.url),path=url.pathname;
  if(url.origin!==this.origin)fail(400,'INVALID_ORIGIN');
  if(!['GET','POST','PATCH'].includes(req.method))fail(405,'METHOD_NOT_ALLOWED');
  if(req.method!=='GET'&&req.headers.get('origin')!==this.origin)fail(403,'ORIGIN_REQUIRED');
  if(req.method==='GET'&&(path==='/auth'||path==='/auth/confirm'))return authPage(path==='/auth/confirm');
  if(req.method==='GET'&&path==='/health')return response({status:'ok',phase:'authentication'});
  if(req.method==='GET'&&path==='/auth/google/callback'){
   await this.limited(ip,path);const state=url.searchParams.get('state'),bound=cookies(req)[FLOW],code=url.searchParams.get('code');
   if(!state||!bound||state!==bound||!/^[A-Za-z0-9_-]{43}$/.test(state)||!code||code.length>2048)fail(400,'INVALID_OAUTH_CALLBACK');
   const sealed=await this.store.consumeFlow(hash(state));if(!sealed)fail(400,'OAUTH_EXPIRED_OR_REPLAYED');
   const out=await this.establish(req,await this.provider.exchange(code,this.vault.open<Record<string,string>>(sealed)),'account');out.headers.append('Set-Cookie',cookie(FLOW,'',0));out.headers.set('Location','/auth');return new Response(null,{status:303,headers:out.headers});
  }
  if(req.method==='GET'&&path==='/auth/session')return this.session(req,'account',false,async(s,row)=>response({profile:await s.profile(row.user_id)}));
  if(req.method==='GET'&&path==='/account/profile')return this.session(req,'account',false,async(s,row)=>response(await s.profile(row.user_id)));
  if(req.method==='GET')fail(404,'NOT_FOUND');
  if(!['/auth/register','/auth/login','/auth/forgot-password','/auth/verify','/auth/reset-password','/auth/google','/auth/logout','/auth/mfa/enroll','/auth/mfa/verify','/account/profile','/account/roles'].includes(path))fail(404,'NOT_FOUND');
  const b=await this.body(req);await this.limited(ip,path);
  if(req.method==='POST'&&path==='/auth/register'){
   keys(b,['email','password']);const e=email(b),p=password(b);await this.limited(ip,'email-register',e);
   try{await this.provider.register(e,p,`${this.origin}/auth/confirm`);}catch(err){if(!(err instanceof ProviderError)||err.status===503)throw err;}
   return response({message:'If registration can proceed, check your email to confirm your account.'},202);
  }
  if(req.method==='POST'&&path==='/auth/login'){
   keys(b,['email','password']);const e=email(b),p=field(b,'password',128);await this.limited(ip,'email-login',e);return this.establish(req,await this.provider.login(e,p),'account');
  }
  if(req.method==='POST'&&path==='/auth/forgot-password'){
   keys(b,['email']);const e=email(b);await this.limited(ip,'email-recovery',e);
   try{await this.provider.forgot(e,`${this.origin}/auth/confirm`);}catch(err){if(!(err instanceof ProviderError)||err.status===503)throw err;}
   return response({message:'If the account exists, password-reset instructions will be emailed.'},202);
  }
  if(req.method==='POST'&&path==='/auth/verify'){
   keys(b,['token_hash','type']);const type=field(b,'type',10);if(type!=='signup'&&type!=='recovery')fail(400,'INVALID_VERIFICATION_TYPE');return this.establish(req,await this.provider.verify(field(b,'token_hash',1024),type as 'signup'|'recovery'),type==='recovery'?'recovery':'account');
  }
  if(req.method==='POST'&&path==='/auth/reset-password'){
   keys(b,['password']);const p=password(b);
   return this.session(req,'recovery',true,async(s,row,t)=>{await this.provider.updatePassword(t,p);await s.revokeSessions(row.user_id);try{await this.provider.logout(t,true);}catch{/* Local account sessions remain revoked; provider revocation can be retried operationally. */}return response({message:'Password updated. Log in again.'},200,[cookie(SESSION,'',0),cookie(CSRF,'',0,false)]);});
  }
  if(req.method==='POST'&&path==='/auth/google'){
   keys(b,[]);const state=token();const result=await this.provider.google(`${this.origin}/auth/google/callback?state=${state}`);await this.store.createFlow(hash(state),this.vault.seal(result.verifier));return response({url:result.url},200,[cookie(FLOW,state,600)]);
  }

  if(req.method==='POST'&&path==='/auth/mfa/enroll'){
   keys(b,[]);return this.session(req,'account',true,async(s,row,t)=>response(await this.provider.enrollMfa(t)));
  }
  if(req.method==='POST'&&path==='/auth/mfa/verify'){
   keys(b,['factor_id','code']);const factor=field(b,'factor_id',36),code=field(b,'code',6);if(!uuid.test(factor)||!/^\d{6}$/.test(code))fail(400,'INVALID_INPUT');
   return this.session(req,'account',true,async(s,row,t)=>{const upgraded=await this.provider.verifyMfa(t,factor,code);const identity=await this.provider.identity(upgraded.access_token);if(identity.id!==row.user_id||!identity.mfa)fail(403,'MFA_REQUIRED');const sid=token(),csrf=token();await s.deleteSession(row.token_hash);await s.createSession(hash(sid),row.user_id,this.vault.seal(upgraded),'account',hash(csrf));return response({mfa:true,csrf},200,[cookie(SESSION,sid,86400),cookie(CSRF,csrf,86400,false)]);});
  }
  if(req.method==='POST'&&path==='/auth/logout'){
   keys(b,['all']);if(b.all!==undefined&&typeof b.all!=='boolean')fail(400,'INVALID_INPUT');
   // Local revocation must succeed even if the remote provider is temporarily unavailable.
   const raw=cookies(req)[SESSION];if(!raw)return response({message:'Logged out'},200,[cookie(SESSION,'',0),cookie(CSRF,'',0,false)]);
   let t:Tokens|undefined;
   await this.store.transaction(async s=>{const row=await s.lockSession(hash(raw));if(!row){await s.deleteSession(hash(raw));return;}if(!equalHash(req.headers.get('x-csrf-token')??'',row.csrf_hash))fail(403,'CSRF_REQUIRED');t=this.vault.open<Tokens>(row.encrypted_tokens);if(b.all===true)await s.revokeSessions(row.user_id);else await s.deleteSession(row.token_hash);});
   if(t)try{await this.provider.logout(t,b.all===true);}catch{/* Local opaque session is already revoked. */}
   return response({message:'Logged out'},200,[cookie(SESSION,'',0),cookie(CSRF,'',0,false)]);
  }
  if(req.method==='PATCH'&&path==='/account/profile'){
   keys(b,['display_name','preferred_language','timezone']);return this.session(req,'account',true,async(s,row)=>response(await s.updateProfile(row.user_id,field(b,'display_name',100),field(b,'preferred_language',10),field(b,'timezone',100))));
  }
  if(req.method==='POST'&&path==='/account/roles'){
   keys(b,['user_id','role','grant','reason']);const target=field(b,'user_id',36);if(!uuid.test(target)||typeof b.grant!=='boolean')fail(400,'INVALID_INPUT');return this.session(req,'account',true,async(s,row,t,id)=>{await s.changeRole(row.user_id,target,field(b,'role',50),b.grant as boolean,field(b,'reason',500),id.mfa);return response({updated:true});});
  }
  fail(404,'NOT_FOUND');
 }
}
