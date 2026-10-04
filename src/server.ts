import { createServer } from 'node:http';
import { Pool } from 'pg';
import { AuthApi } from './auth/api.js';
import { PgAuthStore } from './auth/store.js';
import { SupabaseProvider } from './auth/provider.js';
const required=(name:string)=>{const v=process.env[name];if(!v)throw Error(`${name} required`);return v;};
const origin=required('APP_ORIGIN');
const pool=new Pool({connectionString:required('AUTH_DATABASE_URL'),max:10,connectionTimeoutMillis:5000,statement_timeout:15000});
const api=new AuthApi(new PgAuthStore(pool),new SupabaseProvider(required('SUPABASE_URL'),required('SUPABASE_PUBLISHABLE_KEY')),{origin,encryptionKey:required('SESSION_ENCRYPTION_KEY'),onError:id=>console.error('Authentication operation failed',id)});
const server=createServer(async(req,res)=>{
 try{
  let length=0;const chunks:Buffer[]=[];
  for await(const chunk of req){length+=chunk.length;if(length>8192){res.writeHead(413,{'Content-Type':'application/json'});res.end('{"error":"BODY_TOO_LARGE"}');return;}chunks.push(Buffer.from(chunk));}
  // Origin is deployment-configured; Host/X-Forwarded-* are never trusted.
  const headers=new Headers();for(const [k,v] of Object.entries(req.headers))if(v!==undefined)headers.set(k,Array.isArray(v)?v.join(','):v);
  const request=new Request(new URL(req.url??'/',origin),{method:req.method,headers,...(!['GET','HEAD'].includes(req.method??'GET')?{body:Buffer.concat(chunks)}:{})});
  const response=await api.handle(request,req.socket.remoteAddress??'unknown');
  res.statusCode=response.status;for(const [k,v] of response.headers)if(k!=='set-cookie')res.setHeader(k,v);const cs=response.headers.getSetCookie();if(cs.length)res.setHeader('Set-Cookie',cs);res.end(await response.text());
 }catch{res.writeHead(400,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end('{"error":"INVALID_REQUEST"}');}
});
server.requestTimeout=15000;server.headersTimeout=10000;
server.listen(Number(process.env.PORT??3000),process.env.HOST??'127.0.0.1');
for(const signal of ['SIGTERM','SIGINT'])process.on(signal,()=>{server.close(()=>{void pool.end();});});
