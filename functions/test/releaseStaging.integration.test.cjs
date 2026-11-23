// Tests import the actual production-only staging packages; mocks remain here.
const test=require('node:test'),assert=require('node:assert/strict'),p=require('path'),fs=require('fs'),crypto=require('crypto');
for(const k of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST'])if(!/^127\.0\.0\.1:\d+$/.test(process.env[k]??''))throw Error('Local emulator required');
require('firebase-admin/app').initializeApp({projectId:'dorduncu-8e599'});
const {getFirestore,Timestamp}=require('firebase-admin/firestore'),{getAuth}=require('firebase-admin/auth'),db=getFirestore(),auth=getAuth();
const root=p.resolve('docs/release-package'),manifest=require(p.join(root,'manifest.json'));
const mod=(name,file='index')=>require(p.join(root,'staging',name,'functions/lib',file+'.js'));
const uid='release_staging_owner',other='release_staging_recipient',admin='release_staging_admin';
const request=(data,who=uid,role='user')=>({data,auth:{uid:who,token:{role,auth_time:Math.ceil(Date.now()/1000)+5}},app:{appId:'emulator-only'}});
const run=(name,data,who,role)=>mod(name)[name].run(request(data,who,role));
test('production staging regressions against local Auth/Firestore only',async t=>{
 for(const [id,role]of [[uid,'user'],[other,'user'],[admin,'super_admin']]){try{await auth.deleteUser(id);}catch{}await auth.createUser({uid:id});await auth.setCustomUserClaims(id,{role});await db.doc('users/'+id).set({role,accountStatus:'active',completedEventCount:0,plusAdminGranted:false});}
 await t.test('19 exact exports; live personal purchase wrapper and provider code unchanged; no Dev code',()=>{
  assert.equal(manifest.functions.length,19);
  for(const f of manifest.functions){assert.deepEqual(Object.keys(mod(f.name)),[f.name]);for(const file of f.files){const text=fs.readFileSync(p.join(root,'staging',f.name,'functions/src',file.file),'utf8');assert.doesNotMatch(text,/dev_external_adapters|dev_store_products|dev-retry:|dev-fail:|FUNCTIONS_EMULATOR|FIRESTORE_EMULATOR_HOST/);}}
  for(const file of ['market/fulfillGooglePlayPurchase.ts','commercial/googlePlayVerification.ts'])assert.equal(fs.readFileSync(p.join(root,'staging/fulfillGooglePlayPurchase/functions/src',file),'utf8').replace(/\r\n/g,'\n'),fs.readFileSync(p.join(root,'live/fulfillGooglePlayPurchase/src',file),'utf8').replace(/\r\n/g,'\n'));
 });
 await t.test('producer dedup, legacy skip and blocked recipient use real transactions',async()=>{
  const data={title:'Staging controlled check',message:'Local only',targetType:'user',targetValue:other,requestId:'release-fixed-request'};
  await assert.rejects(()=>run('adminCreateNotification',data,uid),e=>e.code==='permission-denied');
  const a=await run('adminCreateNotification',data,admin,'super_admin'),b=await run('adminCreateNotification',data,admin,'super_admin');assert.equal(a.notificationId,b.notificationId);
  await assert.rejects(()=>run('adminCreateNotification',{...data,title:'changed'},admin,'super_admin'),e=>e.code==='already-exists');
  const helper=mod('dispatchAdminNotification','notifications/processAdminNotifications');
  await helper.processAdminNotificationPage(a.notificationId);
  const job=await db.doc('admin_notifications/'+a.notificationId).get();assert.equal(job.get('dispatchVersion'),1);assert.equal(job.get('inAppCount'),1);assert.equal(job.get('pushMode'),'fcm');
  const legacy=db.doc('admin_notifications/release_legacy');await legacy.set({status:'pending',targetType:'all',recipientCount:0});assert.equal(await helper.processAdminNotificationPage(legacy.id),false);assert.equal((await legacy.get()).get('recipientCount'),0);
  await assert.rejects(()=>run('adminRetryNotification',{notificationId:legacy.id},admin,'super_admin'),e=>['invalid-argument','failed-precondition'].includes(e.code));
  const failed=db.doc('admin_notifications/release_blocked');await db.doc('users/'+other).update({accountStatus:'blocked'});await failed.set({dispatchVersion:1,status:'pending',targetType:'user',targetValue:other,recipientCount:0,resultCount:0,inAppCount:0});await helper.processAdminNotificationPage(failed.id);assert.equal((await failed.get()).get('recipientCount'),0);await db.doc('users/'+other).update({accountStatus:'active'});
 });
 await t.test('per-user retry keys and FCM acceptance counters remain separate from device receipt',async()=>{
  const helper=mod('deliverUserNotification','notifications/notificationDelivery');
  for(const userId of [uid,other])await helper.queuePushDelivery(db,{notificationId:'release_broadcast',userId,type:'system',title:'local',message:'local'},new Date(Date.now()+3600000),0,['hash']);
  const rows=await db.collection('notification_delivery_queue').where('notificationId','==','release_broadcast').get();assert.equal(rows.size,2);assert.notEqual(rows.docs[0].id,rows.docs[1].id);
  const parent=db.doc('admin_notifications/release_counters');await parent.set({dispatchVersion:1,status:'processing',distributionComplete:true,recipientCount:1,inAppCount:1,resultCount:0});await parent.collection('recipients').doc(other).set({outcome:'pending'});
  await mod('syncAdminNotificationResult','notifications/processAdminNotifications').recordAdminNotificationResult(other,{data:{adminNotificationId:parent.id},pushDeliveryStatus:'delivered',pushDeliveredCount:2,pushMode:'fcm'});
  const result=await parent.get();assert.equal(result.get('status'),'completed');assert.equal(result.get('fcmAcceptedCount'),2);assert.equal(result.get('readCount'),undefined);
 });
 await t.test('automatic expiration closes applications without completion count; explicit confirmation is idempotent',async()=>{
  const eventId='release_event',event=db.doc('events/'+eventId);await event.set({olusturanUid:uid,selectedPlayerIds:[other],katilanlar:[other],durum:'aktif',status:'active',endAt:Timestamp.fromMillis(Date.now()-60000),paymentStatus:'not_required'});
  const complete=mod('completePastEvents','events/completeEvent').completeEventIfDue;
  await complete({eventId,actorUid:null});const ended=await event.get();assert.equal(ended.get('status'),'expired');assert.equal(ended.get('closureReason'),'time_elapsed');assert.equal((await db.doc('users/'+uid).get()).get('completedEventCount'),0);const application=await event.collection('applications').doc(other).get();assert.equal(application.get('completedAt'),undefined);assert(application.get('closedAt'));
  assert.equal((await run('getEventRatingState',{eventId},uid)).completed,false);
  await assert.rejects(()=>run('markEventCompleted',{eventId},uid),e=>e.code==='failed-precondition');
  await run('markEventCompleted',{eventId,confirmedOccurred:true},uid);await run('markEventCompleted',{eventId,confirmedOccurred:true},uid);assert.equal((await db.doc('users/'+uid).get()).get('completedEventCount'),1);assert.equal((await event.get()).get('closureReason'),'occurred_confirmed');assert.equal((await run('getEventRatingState',{eventId},uid)).completed,true);
  await event.update({closureReason:null});assert.equal((await run('getEventRatingState',{eventId},uid)).completed,false);await assert.rejects(()=>run('submitEventRating',{eventId,targetUid:other,rating:5},uid),e=>e.code==='failed-precondition');
 });
 await t.test('quota create/cancel/read agree that explicit expired is closed; old event cannot reopen',async()=>{
  for(const name of ['createEvent','cancelUnpaidEvent','getEventCreationQuotaState'])assert.equal(mod(name,'events/eventOpenQuotaPolicy').eventCountsTowardOpenQuota({status:'expired',endAt:Timestamp.fromMillis(Date.now()+3600000)}),false);
  await assert.rejects(()=>run('adminUpdateEventStatus',{eventId:'release_event',status:'active',reason:'Local check'},admin,'super_admin'),e=>e.code==='failed-precondition');
 });
 await t.test('gift canonical/personal-product gates and immutable binding policy',async()=>{
  await db.doc('badge_products/release_noncanonical').set({active:true,giftGooglePlayProductId:'dort_gift_badge_release'});
  await assert.rejects(()=>run('createGiftPurchaseIntent',{kind:'badge_gift',productId:'release_noncanonical',recipientUid:other},uid),e=>e.code==='failed-precondition');
  const policy=mod('fulfillGooglePlayPurchase','commercial/giftPurchasePolicy');assert.equal(policy.giftRecipientIsAvailable({accountStatus:'blocked'}),false);
  assert.equal(policy.giftIntentBindingMatches({requestedProductId:'okey',requestedKind:'badge_gift',requestedGooglePlayProductId:'gift',verifiedPurchaseOptionId:'wrong',intentProductId:'okey',intentKind:'badge_gift',intentGooglePlayProductId:'gift',intentPurchaseOptionId:'buy'}),false);
 });
 await t.test('refund review requires provider proof; note cannot resolve; verified resolution is idempotent',async()=>{
  const id='release_review',intentId='release_intent',token='local-fake-token',hash=crypto.createHash('sha256').update(token).digest('hex');await db.doc('gift_purchase_intents/'+intentId).set({buyerUid:uid,recipientUid:other,productId:'okey',googlePlayProductId:'dort_gift_badge_okey',status:'review'});await db.doc('gift_reviews/'+id).set({buyerUid:uid,recipientUid:other,productId:'okey',giftIntentId:intentId,purchaseTokenHash:hash,status:'refund_review',providerOrderId:'GPA.release.123',googlePlayProductId:'dort_gift_badge_okey'});
  const data={reviewId:id,reason:'Controlled provider evidence',action:'note'};await run('adminResolveGiftReview',data,admin,'super_admin');assert.equal((await db.doc('gift_reviews/'+id).get()).get('status'),'refund_review');
  const provider=mod('adminResolveGiftReview','commercial/googlePlayVerification');provider.callAndroidPublisher=async(_path,method)=>{assert.equal(method,'GET');return {orderId:'GPA.release.123',purchaseToken:token,state:'REFUNDED',lineItems:[{productId:'dort_gift_badge_okey'}],orderHistory:{refundEvent:{eventTime:new Date().toISOString()}}};};
  await assert.rejects(()=>run('adminResolveGiftReview',{...data,action:'verify_refund'},uid),e=>e.code==='permission-denied');await run('adminResolveGiftReview',{...data,action:'verify_refund'},admin,'super_admin');assert.equal((await db.doc('gift_reviews/'+id).get()).get('status'),'refunded_verified');assert.equal((await run('adminResolveGiftReview',{...data,action:'verify_refund'},admin,'super_admin')).idempotentReplay,true);
 });
 await t.test('revoked role cannot use stale request claims',async()=>{await auth.setCustomUserClaims(admin,{role:'user'});await assert.rejects(()=>run('adminCreateNotification',{title:'local',message:'local',targetType:'user',targetValue:other,requestId:'revoked'},admin,'super_admin'),e=>e.code==='permission-denied');});
});
test('gift delivery staging: provider adapter stays outside package; token/intent binding survives replay',async()=>{
 const buyer='release_delivery_buyer',recipient='release_delivery_recipient',id='release_delivery_intent',product='dort_gift_badge_okey',token='release-delivery-fake-token',hash=crypto.createHash('sha256').update(token).digest('hex');
 await db.doc('users/'+buyer).set({accountStatus:'active'});await db.doc('users/'+recipient).set({accountStatus:'active'});await db.doc('users/'+buyer+'/friends/'+recipient).set({});
 await db.doc('gift_purchase_intents/'+id).set({buyerUid:buyer,recipientUid:recipient,kind:'badge_gift',productId:'okey',googlePlayProductId:product,purchaseOptionId:'buy',normalPriceKurus:49900,status:'pending'});
 const provider=mod('fulfillGooglePlayPurchase','commercial/googlePlayVerification'),verified={googlePlayProductId:product,purchaseTokenHash:hash,orderId:'GPA.release.delivery',purchaseOptionId:'buy',purchaseState:0,obfuscatedExternalAccountId:id,consumed:true,testPurchase:true};
 provider.inspectGooglePlayProduct=async()=>({...verified});provider.verifyGooglePlayProduct=async()=>({...verified});provider.consumeGooglePlayProduct=async()=>{throw Error('No provider mutation allowed');};
 const deliver=mod('fulfillGooglePlayPurchase','market/fulfillGiftPurchase').fulfillGiftPurchase,input={buyerUid:buyer,googlePlayProductId:product,purchaseToken:token,giftIntentId:id,clientRecipientUid:recipient,internalProductId:'okey',kind:'badge_gift'};
 await assert.rejects(()=>deliver({...input,clientRecipientUid:'wrong-recipient'}),e=>e.code==='permission-denied');
 assert.equal((await deliver(input)).success,true);assert.equal((await deliver(input)).success,true);assert.deepEqual((await db.doc('users/'+recipient+'/owned_badges/okey').get()).get('giftTokenHashes'),[hash]);assert.equal((await db.doc('google_play_purchase_tokens/'+hash).get()).get('giftIntentId'),id);
 await db.doc('gift_purchase_intents/release_delivery_other_intent').set({buyerUid:buyer,recipientUid:recipient,kind:'badge_gift',productId:'okey',googlePlayProductId:product,purchaseOptionId:'buy',normalPriceKurus:49900,status:'delivered',purchaseTokenHash:hash});provider.inspectGooglePlayProduct=async()=>({...verified,obfuscatedExternalAccountId:'release_delivery_other_intent'});provider.verifyGooglePlayProduct=provider.inspectGooglePlayProduct;
 await assert.rejects(()=>deliver({...input,giftIntentId:'release_delivery_other_intent'}),e=>e.code==='failed-precondition');
});
