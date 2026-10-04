import { createHmac,timingSafeEqual,createHash } from 'node:crypto';
import type { Pool } from 'pg';
export function verifySignature(message:string|Buffer,signature:string,secret:string):boolean {
  if(!secret || !/^[0-9a-f]{64}$/i.test(signature)) return false;
  return timingSafeEqual(createHmac('sha256',secret).update(message).digest(),Buffer.from(signature,'hex'));
}
export interface StoredOrder { id:string; providerOrderId:string; amountMinor:number; currency:'INR'; }
/** order MUST come from server persistence, not a submitted client body.
 * Signature + independently fetched captured payment precede database activation.
 * This is a server adapter, not a public checkout/webhook route.
 */
export async function verifyAndActivate(billing:Pool,order:StoredOrder,paymentId:string,signature:string,keyId:string,secret:string):Promise<string> {
  if(!verifySignature(`${order.providerOrderId}|${paymentId}`,signature,secret)) throw new Error('INVALID_PAYMENT_SIGNATURE');
  const res=await fetch(`https://api.razorpay.com/v1/payments/${encodeURIComponent(paymentId)}`,{
    headers:{Authorization:`Basic ${Buffer.from(`${keyId}:${secret}`).toString('base64')}`},signal:AbortSignal.timeout(10000),cache:'no-store'
  });
  if(!res.ok) throw new Error('PAYMENT_VERIFICATION_UNAVAILABLE');
  const body=await res.text();
  const payment=JSON.parse(body) as {id:string;order_id:string;status:string;captured:boolean;amount:number;currency:string};
  if(payment.id!==paymentId || payment.order_id!==order.providerOrderId || payment.status!=='captured' || payment.captured!==true || payment.amount!==order.amountMinor || payment.currency!==order.currency) throw new Error('PAYMENT_NOT_VERIFIED');
  const evidence=createHash('sha256').update(body).digest('hex');
  return (await billing.query('SELECT exam.activate_verified_payment($1,$2,$3,$4,$5) AS id',[order.id,paymentId,order.amountMinor,order.currency,evidence])).rows[0].id;
}
