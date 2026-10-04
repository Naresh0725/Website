import { createClient,type Session } from '@supabase/supabase-js';
export interface Identity {id:string;email:string;verified:boolean;mfa:boolean;}
export interface Tokens {access_token:string;refresh_token:string;expires_at:number;}
export interface AuthProvider {
 register(email:string,password:string,redirect:string):Promise<void>;
 login(email:string,password:string):Promise<Tokens>;
 identity(access:string):Promise<Identity>;
 refresh(refresh:string):Promise<Tokens>;
 forgot(email:string,redirect:string):Promise<void>;
 verify(tokenHash:string,type:'signup'|'recovery'):Promise<Tokens>;
 updatePassword(tokens:Tokens,password:string):Promise<void>;
 logout(tokens:Tokens,all:boolean):Promise<void>;
 enrollMfa(tokens:Tokens):Promise<{id:string;secret:string;uri:string}>;
 verifyMfa(tokens:Tokens,factor:string,code:string):Promise<Tokens>;
 google(redirect:string):Promise<{url:string;verifier:Record<string,string>}>;
 exchange(code:string,verifier:Record<string,string>):Promise<Tokens>;
}
export class ProviderError extends Error {constructor(public status=401){super('Authentication provider rejected the request');}}
function tokens(s:(Pick<Session,'access_token'|'refresh_token'>&{expires_at?:number;expires_in?:number})|null):Tokens{const expires=s?.expires_at??(s?.expires_in?Math.floor(Date.now()/1000)+s.expires_in:0);if(!s?.access_token||!s.refresh_token||!Number.isFinite(expires)||expires<=0)throw new ProviderError();return {access_token:s.access_token,refresh_token:s.refresh_token,expires_at:expires};}
export class SupabaseProvider implements AuthProvider {
 constructor(private url:string,private key:string,private transport:typeof fetch=fetch){if(new URL(url).protocol!=='https:')throw Error('HTTPS_AUTH_REQUIRED');}
 private client(snapshot:Record<string,string>={}){
  const storage={getItem:(k:string)=>snapshot[k]??null,setItem:(k:string,v:string)=>{snapshot[k]=v;},removeItem:(k:string)=>{delete snapshot[k];}};
  return createClient(this.url,this.key,{auth:{flowType:'pkce',autoRefreshToken:false,persistSession:true,detectSessionInUrl:false,storage,storageKey:'exam-auth'},global:{fetch:(input,init)=>this.transport(input,{...init,signal:AbortSignal.timeout(10000)})}});
 }
 async register(email:string,password:string,redirect:string){const {error}=await this.client().auth.signUp({email,password,options:{emailRedirectTo:redirect}});if(error)throw new ProviderError(error.status&&error.status>=500?503:400);}
 async login(email:string,password:string){const {data,error}=await this.client().auth.signInWithPassword({email,password});if(error)throw new ProviderError();return tokens(data.session);}
 async identity(access:string){const {data,error}=await this.client().auth.getUser(access);if(error||!data.user)throw new ProviderError();let claims:{sub?:string;aal?:string};try{claims=JSON.parse(Buffer.from(access.split('.')[1],'base64url').toString());}catch{throw new ProviderError();}if(claims.sub!==data.user.id)throw new ProviderError();return {id:data.user.id,email:data.user.email??'',verified:!!data.user.email_confirmed_at,mfa:claims.aal==='aal2'};}
 async refresh(refresh:string){const {data,error}=await this.client().auth.refreshSession({refresh_token:refresh});if(error)throw new ProviderError();return tokens(data.session);}
 async forgot(email:string,redirect:string){const {error}=await this.client().auth.resetPasswordForEmail(email,{redirectTo:redirect});if(error)throw new ProviderError(error.status&&error.status>=500?503:400);}
 async verify(tokenHash:string,type:'signup'|'recovery'){const {data,error}=await this.client().auth.verifyOtp({token_hash:tokenHash,type});if(error)throw new ProviderError();return tokens(data.session);}
 async updatePassword(t:Tokens,password:string){const c=this.client();const set=await c.auth.setSession(t);if(set.error)throw new ProviderError();const {error}=await c.auth.updateUser({password});if(error)throw new ProviderError();}
 async logout(t:Tokens,all:boolean){const c=this.client();const set=await c.auth.setSession(t);if(set.error)return;const {error}=await c.auth.signOut({scope:all?'global':'local'});if(error)throw new ProviderError(503);}

 async enrollMfa(t:Tokens){const c=this.client();if((await c.auth.setSession(t)).error)throw new ProviderError();const {data,error}=await c.auth.mfa.enroll({factorType:'totp',friendlyName:'Government Exam Platform'});if(error||!data)throw new ProviderError();return {id:data.id,secret:data.totp.secret,uri:data.totp.uri};}
 async verifyMfa(t:Tokens,factor:string,code:string){const c=this.client();if((await c.auth.setSession(t)).error)throw new ProviderError();const {data,error}=await c.auth.mfa.challengeAndVerify({factorId:factor,code});if(error||!data)throw new ProviderError();return tokens(data);}
 async google(redirect:string){const verifier:Record<string,string>={};const {data,error}=await this.client(verifier).auth.signInWithOAuth({provider:'google',options:{redirectTo:redirect,skipBrowserRedirect:true,scopes:'openid email profile'}});if(error||!data.url)throw new ProviderError(503);return {url:data.url,verifier};}
 async exchange(code:string,verifier:Record<string,string>){const {data,error}=await this.client(verifier).auth.exchangeCodeForSession(code);if(error)throw new ProviderError();return tokens(data.session);}
}
