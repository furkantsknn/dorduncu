import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,updateDoc,getDocs,collection,query,where} from 'firebase/firestore';
const [host,port]=String(process.env.FIRESTORE_EMULATOR_HOST??'').split(':');
if(host!=='127.0.0.1')throw Error('Local emulator required');
test('admin and gift rules matrix; direct bypass and stale claims rejected',async(t)=>{
 const env=await initializeTestEnvironment({projectId:'demo-closure-security',firestore:{host,port:Number(port),rules:readFileSync(process.env.CLOSURE_RULES_SOURCE??'firestore.rules','utf8')}});
 const roles=['super_admin','admin','moderator','content_manager','finance_officer','verification_officer','support_officer','analyst','user'];
 try {
  await env.withSecurityRulesDisabled(async(ctx)=>{
   const db=ctx.firestore();
   for(const role of roles)await setDoc(doc(db,'users/'+role),{role,accountStatus:'active',disabled:false});
   for(const [path,data]of Object.entries({'gift_reviews/review':{status:'refund_review'},'gift_reviews/review/history/entry':{action:'note'},'gift_deliveries/delivery':{buyerUid:'user',recipientUid:'friend'},'admin_notifications/job':{status:'pending'},'audit_logs/entry':{action:'synthetic'},'system_settings/global':{maintenanceMode:false},'badge_products/okey':{active:true},'google_play_purchase_tokens/hash':{secret:'synthetic'},'dev_external_adapters/test':{service:'google_play'}}))await setDoc(doc(db,path),data);
  });
  for(const role of roles)await t.test(role+' read/write permissions',async()=>{
   const db=env.authenticatedContext(role,{role,admin:['admin','super_admin'].includes(role)}).firestore();
   const finance=['super_admin','admin','finance_officer'].includes(role),notifications=['super_admin','admin','content_manager'].includes(role),audit=['super_admin','admin'].includes(role);
   for(const path of ['gift_reviews/review','gift_reviews/review/history/entry'])await(finance?assertSucceeds:assertFails)(getDoc(doc(db,path)));
   await(notifications?assertSucceeds:assertFails)(getDoc(doc(db,'admin_notifications/job')));
   await(audit?assertSucceeds:assertFails)(getDoc(doc(db,'audit_logs/entry')));
   await(audit?assertSucceeds:assertFails)(getDoc(doc(db,'system_settings/global')));
   await(finance||role==='user'?assertSucceeds:assertFails)(getDoc(doc(db,'gift_deliveries/delivery')));
   for(const path of ['gift_reviews/review','admin_notifications/job','badge_products/okey','dev_external_adapters/test'])await assertFails(setDoc(doc(db,path),{status:'forged'}));
   for(const path of ['google_play_purchase_tokens/hash','dev_external_adapters/test'])await assertFails(getDoc(doc(db,path)));
   await assertFails(updateDoc(doc(db,'users/'+role),{role:'super_admin',plusAdminGranted:true}));
  });
  await t.test('gift history owner query and unrelated recipient are isolated',async()=>{
   await assertSucceeds(getDocs(query(collection(env.authenticatedContext('user',{role:'user'}).firestore(),'gift_deliveries'),where('buyerUid','==','user'))));
   await assertFails(getDoc(doc(env.authenticatedContext('stranger',{role:'user'}).firestore(),'gift_deliveries/delivery')));
  });
  await t.test('revoked mirrored role and inconsistent legacy flags cannot bypass',async()=>{
   await env.withSecurityRulesDisabled(ctx=>updateDoc(doc(ctx.firestore(),'users/finance_officer'),{role:'user'}));
   await assertFails(getDoc(doc(env.authenticatedContext('finance_officer',{role:'finance_officer'}).firestore(),'gift_reviews/review')));
   await assertFails(getDoc(doc(env.authenticatedContext('user',{role:'user',admin:true,moderator:true}).firestore(),'gift_reviews/review')));
   await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'admin_notifications/job')));
  });
 for(const [name,profile]of [['missing profile',null],['disabled profile',{role:'admin',disabled:true}],['deletion requested',{role:'admin',accountStatus:'deletionRequested'}],['deletion processing',{role:'admin',deletionRequestStatus:'processing'}],['demoted role',{role:'user'}],['blocked account',{role:'admin',accountStatus:'blocked'}]])await t.test('old admin token denied: '+name,async()=>{
   const adminDb=env.authenticatedContext('session_admin',{role:'admin'}).firestore();
   await env.withSecurityRulesDisabled(async ctx=>{const ref=doc(ctx.firestore(),'users/session_admin');if(profile)await setDoc(ref,profile);else {const {deleteDoc}=await import('firebase/firestore');await deleteDoc(ref);}});
   await assertFails(getDoc(doc(adminDb,'admin_notifications/job')));
 });
 await t.test('valid role admin and legacy flag admin remain eligible with an existing profile',async()=>{
   await env.withSecurityRulesDisabled(ctx=>setDoc(doc(ctx.firestore(),'users/session_admin'),{role:'admin',accountStatus:'active'}));
   await assertSucceeds(getDoc(doc(env.authenticatedContext('session_admin',{role:'admin'}).firestore(),'admin_notifications/job')));
   await assertSucceeds(getDoc(doc(env.authenticatedContext('session_admin',{admin:true}).firestore(),'admin_notifications/job')));
   await env.withSecurityRulesDisabled(ctx=>setDoc(doc(ctx.firestore(),'users/session_admin'),{accountStatus:'active'}));
   await assertSucceeds(getDoc(doc(env.authenticatedContext('session_admin',{admin:true}).firestore(),'admin_notifications/job')));
 });
 }finally{await env.cleanup();}
 assert.ok(true);
});
