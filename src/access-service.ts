import type { Pool } from 'pg';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function valid(value:string):string { if(!uuid.test(value)) throw new Error('INVALID_UUID'); return value; }
/** Server-only integration boundary. Never expose DB credentials to a browser.
 * Runtime pool must log in as an exam_runtime member, NOT database owner/service_role.
 */
export class AccessService {
  constructor(private readonly runtime:Pool, private readonly authUrl:string, private readonly publishableKey:string) {
    if(new URL(authUrl).protocol!=='https:') throw new Error('HTTPS_AUTH_REQUIRED');
  }
  private async principal(accessToken:string):Promise<string> {
    if(!accessToken) throw new Error('AUTHENTICATION_REQUIRED');
    const response=await fetch(`${this.authUrl.replace(/\/$/,'')}/auth/v1/user`,{
      headers:{Authorization:`Bearer ${accessToken}`,apikey:this.publishableKey},cache:'no-store',signal:AbortSignal.timeout(10000)
    });
    if(!response.ok) throw new Error('AUTHENTICATION_REQUIRED');
    const user=await response.json() as {id:string;email_confirmed_at?:string};
    if(!user.email_confirmed_at) throw new Error('EMAIL_VERIFICATION_REQUIRED');
    return valid(user.id);
  }
  async start(accessToken:string,testVersionId:string,requestKey:string):Promise<string> {
    const user=await this.principal(accessToken);
    const result=await this.runtime.query('SELECT exam.start_attempt($1,$2,$3) AS id',[user,valid(testVersionId),valid(requestKey)]);
    return result.rows[0].id;
  }
  async resume(accessToken:string,attemptId:string):Promise<unknown> {
    const user=await this.principal(accessToken);
    return (await this.runtime.query('SELECT exam.get_attempt($1,$2) AS attempt',[user,valid(attemptId)])).rows[0].attempt;
  }
  async status(accessToken:string):Promise<unknown> {
    const user=await this.principal(accessToken);
    return (await this.runtime.query('SELECT exam.access_status($1) AS status',[user])).rows[0].status;
  }
}
