import { createHash,createCipheriv,createDecipheriv,randomBytes,timingSafeEqual } from 'node:crypto';
export const token=()=>randomBytes(32).toString('base64url');
export const hash=(value:string)=>createHash('sha256').update(value).digest('hex');
export function equalHash(value:string,expected:string){const actual=hash(value);return /^[a-f0-9]{64}$/.test(expected)&&timingSafeEqual(Buffer.from(actual,'hex'),Buffer.from(expected,'hex'));}
export class Vault {
 private key:Buffer;
 constructor(secret:string){this.key=Buffer.from(secret,'base64');if(this.key.length!==32)throw new Error('SESSION_ENCRYPTION_KEY must be 32 random bytes in base64');}
 seal(value:unknown):string{const iv=randomBytes(12),c=createCipheriv('aes-256-gcm',this.key,iv);c.setAAD(Buffer.from('exam-auth-v1'));const data=Buffer.concat([c.update(JSON.stringify(value),'utf8'),c.final()]);return [iv,c.getAuthTag(),data].map(x=>x.toString('base64url')).join('.');}
 open<T>(value:string):T{const parts=value.split('.');if(parts.length!==3)throw Error('Invalid ciphertext');const [iv,tag,body]=parts.map(x=>Buffer.from(x,'base64url'));const d=createDecipheriv('aes-256-gcm',this.key,iv);d.setAAD(Buffer.from('exam-auth-v1'));d.setAuthTag(tag);return JSON.parse(Buffer.concat([d.update(body),d.final()]).toString('utf8')) as T;}
}
