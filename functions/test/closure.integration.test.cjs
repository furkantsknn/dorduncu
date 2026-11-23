const assert = require('node:assert/strict');
const test = require('node:test');
const crypto = require('crypto');
for (const key of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST','FIREBASE_STORAGE_EMULATOR_HOST']) {
  if (!/^127\.0\.0\.1:\d+$/.test(process.env[key] || '')) throw Error('Local emulator required: '+key);
}
process.env.FUNCTIONS_EMULATOR='true';
process.env.GCLOUD_PROJECT='dorduncu-8e599';
process.env.ANDROID_PACKAGE_NAME='com.dortapp.dort';
const {initializeApp}=require('firebase-admin/app');
initializeApp({projectId:'dorduncu-8e599',storageBucket:'dorduncu-8e599.firebasestorage.app'});
const {getFirestore,Timestamp}=require('firebase-admin/firestore');
const {getAuth}=require('firebase-admin/auth');
const db=getFirestore(),auth=getAuth(),f=require('../lib/index.js');
const {processAdminNotificationPage,reconcileAdminNotification,recordAdminNotificationResult}=require('../lib/notifications/processAdminNotifications.js');
const {completeEventIfDue}=require('../lib/events/completeEvent.js');
const {fulfillGiftPurchase}=require('../lib/market/fulfillGiftPurchase.js');
const prefix='closure_', roles=['super_admin','admin','moderator','content_manager','finance_officer','verification_officer','support_officer','analyst','user'];
const req=(role,data={})=>({data,auth:role?{uid:prefix+role,token:{role,admin:['super_admin','admin'].includes(role),auth_time:Math.floor(Date.now()/1000)+5}}:undefined});
const run=(name,role,data)=>f[name].run(req(role,data));
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
const wait=async(read,predicate)=>{for(let i=0;i<600;i++){const x=await read();if(predicate(x))return x;await new Promise(r=>setTimeout(r,100));}assert.fail('Projection timed out');};
const ref=(collection,id)=>db.collection(collection).doc(id);
const buyer=prefix+'user',recipient=prefix+'recipient';
async function fixture(method,url,response){await ref('dev_external_adapters',hash(method+':'+url)).set({service:'google_play',response});}
const base='https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.dortapp.dort';
const future=()=>Timestamp.fromMillis(Date.now()+3600000),past=()=>Timestamp.fromMillis(Date.now()-3600000);
const event=(extra={})=>({olusturanUid:buyer,selectedPlayerIds:[recipient],katilanlar:[recipient],status:'active',durum:'aktif',startAt:past(),endAt:past(),accessModel:'free',paymentRequired:false,paymentStatus:'not_required',...extra});

test('integrated closure uses only local emulators and actual production handlers',async(t)=>{
 await db.recursiveDelete(ref('users',recipient));
 await db.recursiveDelete(ref('support_requests','closure_support'));
 await ref('system_settings','supportPrivateNotesMigrationV1').delete();
 for(const oldEvent of (await db.collection('events').where('olusturanUid','==',buyer).get()).docs)await db.recursiveDelete(oldEvent.ref);
 for(const campaign of (await db.collection('market_campaigns').get()).docs)if(campaign.id.startsWith('closure_campaign_'))await campaign.ref.delete();
 for(const id of ['closure_manual_job','closure_resume','closure_legacy_pending'])await db.recursiveDelete(ref('admin_notifications',id));
 for(const role of roles){const uid=prefix+role;try{await auth.getUser(uid);}catch{await auth.createUser({uid,email:uid+'@dev.dort.invalid',password:'Closure-Dev-2026',emailVerified:true});}await auth.setCustomUserClaims(uid,{role,admin:['super_admin','admin'].includes(role)});await ref('users',uid).set({role,accountStatus:'active',displayName:'Synthetic '+role,profilAdi:'Synthetic '+role,createdAt:Timestamp.now()});}
 await ref('users',recipient).set({role:'user',accountStatus:'active',displayName:'Synthetic Recipient',profilAdi:'Synthetic Recipient'});
 await ref('users',buyer).collection('friends').doc(recipient).set({createdAt:Timestamp.now()});
 await ref('users',recipient).collection('friends').doc(buyer).set({createdAt:Timestamp.now()});

 const protectedActions={adminUpdateMembership:{userId:recipient,action:'plus',enabled:true,reason:'denial test'},adminManageUserBadge:{targetUid:recipient,badgeId:'okey',action:'grant',reason:'denial test'},adminCreateNotification:{title:'Synthetic',message:'Synthetic only',targetType:'all',requestId:'deny'},adminRetryNotification:{notificationId:'missing'},adminResolveGiftReview:{reviewId:'missing',action:'note',reason:'Synthetic'},adminUpdateEventStatus:{eventId:'missing',status:'cancelled',reason:'Synthetic'},adminUpdateSystemSettings:{},adminManageVersionPolicy:{},adminSaveMarketProduct:{},adminDeleteMarketProduct:{productId:'missing'},adminSetGooglePlayProductId:{collection:'badge_products',productId:'okey',googlePlayProductId:'test'},adminAdjustWallet:{},processAccountStatus:{uid:recipient,status:'suspended',reason:'Synthetic'},processVerification:{requestId:'missing'},getVerificationDocumentContent:{requestId:'missing',documentType:'selfie'},claimVerificationRequest:{requestId:'missing'},setUserRole:{uid:buyer,role:'super_admin',reason:'escalation'},seedBadgeProducts:{},adminReplySupportRequest:{requestId:'missing',response:'Synthetic'},adminUpdateSupportRequest:{requestId:'missing',status:'closed'},adminGetReportOverview:{},adminSaveMarketCampaign:{},adminPublishMarketCampaign:{campaignId:'missing'},adminStopMarketCampaign:{campaignId:'missing'},adminRetryMarketCampaignProduct:{campaignId:'missing',productKey:'badge:okey'}};
 await t.test('every admin entry rejects anonymous, ordinary user and unrelated admin',async()=>{
  for(const [name,data] of Object.entries(protectedActions))for(const role of [null,'user',name==='adminGetReportOverview'?'support_officer':'analyst'])await assert.rejects(()=>run(name,role,data),e=>['permission-denied','unauthenticated'].includes(e.code),name+':'+role);
 });
 await t.test('admin grant/removal preserves Play and projects private/public source',async()=>{
  await ref('users',recipient).set({plus:true,plusExpiresAt:future()},{merge:true});
  for(const enabled of [true,false]){await run('adminUpdateMembership','finance_officer',{userId:recipient,action:'plus',enabled,reason:'Synthetic policy check'});assert.equal((await ref('users',recipient).get()).get('plusAdminGranted'),enabled);assert.equal((await ref('users',recipient).get()).get('plus'),true);await wait(()=>ref('public_profiles',recipient).get(),s=>s.exists&&s.get('plusAdminGranted')===enabled&&s.get('plus')===true);}
 });
 await t.test('canonical seed, badge grant/remove and public projection',async()=>{
  await run('seedBadgeProducts','content_manager',{});assert.equal((await db.collection('badge_products').where('active','==',true).get()).size>=31,true);
  for(const action of ['grant','remove']){await run('adminManageUserBadge','content_manager',{targetUid:recipient,badgeId:'okey',action,reason:'Synthetic entitlement test'});assert.equal((await ref('users',recipient).collection('owned_badges').doc('okey').get()).get('adminBlocked'),action==='remove');await wait(()=>ref('public_profiles',recipient).get(),s=>(s.get('marketBadges')??[]).some(b=>b.productId==='okey')===(action==='grant'));}
  await ref('users',recipient).collection('owned_badges').doc('okey').delete();
 });
 await t.test('market save, mapping readback and delete use actual collections',async()=>{
  const saved=await run('adminSaveMarketProduct','content_manager',{title:'Synthetic product',code:'closure_product',productType:'badge',active:true,allowTlPayment:true,allowWalletPayment:false,allowPointPayment:false,priceKurus:49900,pointPrice:0,durationDays:0});
  assert.equal((await ref('marketProducts',saved.productId).get()).get('title'),'Synthetic product');
  await run('adminSetGooglePlayProductId','content_manager',{collection:'badge_products',productId:'okey',googlePlayProductId:'dort_badge_okey',googlePlayPurchaseOptionId:'buy',giftGooglePlayProductId:'dort_gift_badge_okey',giftGooglePlayPurchaseOptionId:'buy'});
  assert.equal((await ref('badge_products','okey').get()).get('giftGooglePlayPurchaseOptionId'),'buy');
  await run('adminDeleteMarketProduct','content_manager',{productId:saved.productId});assert.equal((await ref('marketProducts',saved.productId).get()).exists,false);
 });
 await t.test('settings, version policy and history/public projection',async()=>{
  await run('adminUpdateSystemSettings','super_admin',{maintenanceMode:false,forceUpdateEnabled:false,registrationEnabled:true,eventCreationEnabled:true,eventApplicationsEnabled:true,supportEnabled:true,paymentsEnabled:false,marketEnabled:true});
  assert.equal((await ref('system_settings','global').get()).get('paymentsEnabled'),false);
  const data={platform:'android',target:'test',active:false,latestBuild:35,minimumBuild:0,latestVersion:'1.0.0',minimumVersion:'',storeVersionAvailable:false,storeUrl:''};
  await run('adminManageVersionPolicy','super_admin',data);assert.equal((await ref('public_app_versions','android_test').get()).get('active'),false);
  await run('adminManageVersionPolicy','super_admin',{...data,latestBuild:34});const history=await db.collection('app_version_policy_history').where('policyId','==','android_test').get();assert(history.size>=2);
  const revision=history.docs.find(d=>d.get('previous')?.latestBuild===35);await run('adminManageVersionPolicy','super_admin',{action:'rollback',platform:'android',target:'test',revisionId:revision.id});assert.equal((await ref('public_app_versions','android_test').get()).get('latestBuild'),35);
 });
 await t.test('account status writes and auth state are read back',async()=>{
  await run('processAccountStatus','moderator',{uid:recipient,status:'suspended',reason:'Synthetic suspension',suspensionDays:3});assert.equal((await ref('users',recipient).get()).get('accountStatus'),'suspended');
  await run('processAccountStatus','moderator',{uid:recipient,status:'active',reason:'Synthetic restore'});assert.equal((await ref('users',recipient).get()).get('accountStatus'),'active');
 });
 await t.test('support response, status and in-app notification',async()=>{
  await ref('support_requests','closure_support').set({uid:recipient,userId:recipient,ticketId:'DST-CLOSURE',category:'general',status:'new'});
  await run('adminReplySupportRequest','support_officer',{requestId:'closure_support',response:'Synthetic answer only'});assert.equal((await ref('support_requests','closure_support').get()).get('status'),'answered');
  assert.equal((await ref('support_requests','closure_support').collection('messages').get()).size,1);
  await run('adminUpdateSupportRequest','support_officer',{requestId:'closure_support',status:'closed'});assert.equal((await ref('support_requests','closure_support').get()).get('status'),'closed');
  await ref('support_requests','closure_support').update({adminNotes:'Synthetic private note'});await run('adminMigrateSupportPrivateNotes','super_admin',{});assert.equal((await ref('support_requests','closure_support').get()).get('adminNotes'),undefined);assert((await ref('support_requests','closure_support').collection('private').doc('admin').get()).exists);
 });
 await t.test('verification claim/decision and no external analysis',async()=>{
  await ref('verification_requests','closure_verification').set({uid:recipient,status:'pending',createdAt:Timestamp.now()});
  await run('claimVerificationRequest','verification_officer',{requestId:'closure_verification'});
  await run('processVerification','verification_officer',{requestId:'closure_verification',status:'revision',decisionReason:'Synthetic document revision'});
  assert.equal((await ref('verification_requests','closure_verification').get()).get('status'),'revision');assert.equal((await ref('users',recipient).get()).get('verificationStatus'),'revision');
 });
 await t.test('private verification document is read only by the assigned officer',async()=>{
  const path=`verification_documents/${recipient}/closure-selfie.jpg`;
  await require('firebase-admin/storage').getStorage().bucket().file(path).save(Buffer.from('synthetic-image-only'),{metadata:{contentType:'image/jpeg'}});
  await ref('verification_requests','closure_verification').set({selfiePath:path},{merge:true});
  const content=await run('getVerificationDocumentContent','verification_officer',{requestId:'closure_verification',documentType:'selfie'});assert.equal(typeof content.content,'string');
  await assert.rejects(()=>run('getVerificationDocumentContent','verification_officer',{requestId:'closure_support',documentType:'selfie'}));
  assert((await db.collection('verification_document_access_logs').where('requestId','==','closure_verification').get()).size>=1);
 });
 await t.test('report moderation preserves evidence and removes only the referenced message',async()=>{
  await ref('events','closure_moderation').set(event());
  await ref('events','closure_moderation').collection('messages').doc('reported').set({senderId:buyer,senderUid:buyer,text:'Synthetic message'});
  await ref('events','closure_moderation').collection('messages').doc('unrelated').set({senderId:buyer,text:'Keep synthetic message'});
  await ref('support_requests','closure_message_report').set({uid:recipient,category:'message_report',status:'new',relatedEventId:'closure_moderation',relatedMessageId:'reported'});
  await assert.rejects(()=>run('adminRemoveReportedContent','support_officer',{requestId:'closure_message_report'}),e=>e.code==='permission-denied');
  await run('adminRemoveReportedContent','super_admin',{requestId:'closure_message_report'});
  assert.equal((await ref('events','closure_moderation').collection('messages').doc('reported').get()).get('moderationStatus'),'removed');assert.equal((await ref('events','closure_moderation').collection('messages').doc('unrelated').get()).get('text'),'Keep synthetic message');
 });
 await t.test('campaign draft/schedule/stop use local state and controlled provider failure',async()=>{
  const id='closure_campaign_'+Date.now();
  await run('adminSaveMarketCampaign','finance_officer',{campaignId:id,scope:'selected',selectedProductKeys:['badge:okey'],percent:10,startsAt:new Date(Date.now()+3600000).toISOString(),endsAt:new Date(Date.now()+7200000).toISOString(),idempotencyKey:id});
  assert.equal((await ref('market_campaigns',id).get()).get('status'),'draft');
  await run('adminPublishMarketCampaign','finance_officer',{campaignId:id});assert.equal((await ref('market_campaigns',id).get()).get('status'),'scheduled');
  // No fixture means a safe local adapter failure, never a real Play write.
  await run('adminStopMarketCampaign','finance_officer',{campaignId:id});const stopped=await ref('market_campaigns',id).get();assert.notEqual(stopped.get('status'),'active');
 });
 await t.test('notification distribution is paginated and idempotent, zero devices terminates',async()=>{
  const body={title:'Synthetic broadcast',message:'Local only, never real FCM',targetType:'user',targetValue:recipient,requestId:'closure_broadcast_'+Date.now()};
  const a=await run('adminCreateNotification','content_manager',body),b=await run('adminCreateNotification','content_manager',body);assert.equal(a.notificationId,b.notificationId);
  await Promise.all([processAdminNotificationPage(a.notificationId),processAdminNotificationPage(a.notificationId)]);
  await wait(()=>ref('admin_notifications',a.notificationId).get(),s=>s.get('distributionComplete')===true);
  await wait(()=>ref('admin_notifications',a.notificationId).get(),s=>s.get('status')==='completed');
  const job=await ref('admin_notifications',a.notificationId).get();assert.equal(job.get('inAppCount'),1);assert.equal(job.get('skippedCount'),1);assert.equal(job.get('fcmAcceptedCount'),0);
  assert.equal((await ref('users',recipient).collection('notifications').where('data.adminNotificationId','==',a.notificationId).get()).size,1);
  await ref('admin_notifications','closure_legacy_pending').set({status:'pending',title:'old',targetType:'all'});await processAdminNotificationPage('closure_legacy_pending');assert.equal((await ref('admin_notifications','closure_legacy_pending').get()).get('status'),'pending');
 });
 await t.test('notification partial failure, interruption and retry never duplicate in-app',async()=>{
  const id='closure_manual_job';await ref('admin_notifications',id).set({dispatchVersion:1,status:'pending',title:'Synthetic',message:'Local only',targetType:'user',targetValue:recipient,recipientCount:0,inAppCount:0,resultCount:0});
  await processAdminNotificationPage(id);await wait(()=>ref('admin_notifications',id).collection('recipients').doc(recipient).get(),s=>s.exists);
  await recordAdminNotificationResult(recipient,{data:{adminNotificationId:id},pushDeliveryStatus:'failed',pushDeliveredCount:0});await recordAdminNotificationResult(recipient,{data:{adminNotificationId:id},pushDeliveryStatus:'failed',pushDeliveredCount:0});assert.equal((await ref('admin_notifications',id).get()).get('resultCount'),1);
   const resume='closure_resume';await ref('admin_notifications',resume).set({dispatchVersion:1,status:'failed',title:'Synthetic retry',message:'Local only',targetType:'user',targetValue:recipient,distributionComplete:false,recipientCount:0,inAppCount:0,resultCount:0});await run('adminRetryNotification','content_manager',{notificationId:resume});await wait(()=>ref('admin_notifications',resume).collection('recipients').get(),s=>s.size===1);
  await reconcileAdminNotification(resume);
 });
 await t.test('bounded audience traversal and real simulated adapter outcomes',async()=>{
  const suffix=String(Date.now()),batch=db.batch();
  for(let i=0;i<53;i++)batch.set(ref('users','closure_page_'+suffix+'_'+String(i).padStart(2,'0')),{accountStatus:'active',sehir:'Other'});
  for(const name of ['good','bad','zero'])batch.set(ref('users','closure_device_'+suffix+'_'+name),{accountStatus:'active',sehir:'ClosureMixed'+suffix});
  await batch.commit();
  for(const [name,token] of [['good','dev-ok:one'],['bad','dev-fail:one']])await ref('users','closure_device_'+suffix+'_'+name).collection('notification_devices').doc(name).set({enabled:true,token,tokenHash:name});
  const result=await run('adminCreateNotification','content_manager',{title:'Synthetic mixed',message:'Controlled adapter only',targetType:'city',targetValue:'ClosureMixed'+suffix,requestId:'mixed-'+suffix});
  for(let i=0;i<10;i++){await processAdminNotificationPage(result.notificationId);const job=await ref('admin_notifications',result.notificationId).get();if(job.get('distributionComplete'))break;await new Promise(r=>setTimeout(r,100));}
  const job=await wait(()=>ref('admin_notifications',result.notificationId).get(),s=>s.get('status')==='partial');assert.equal(job.get('recipientCount'),3);assert.equal(job.get('inAppCount'),3);assert.equal(job.get('successCount'),1);assert.equal(job.get('failureCount'),1);assert.equal(job.get('skippedCount'),1);assert.equal(job.get('fcmAcceptedCount'),0);assert.equal(job.get('simulatedCount'),1);
 });
 await t.test('retry queue isolates recipients, resumes known failures and closes uncertain interruption',async()=>{
  const {queuePushDelivery}=require('../lib/notifications/notificationDelivery.js'),suffix=String(Date.now()),notificationId='closure_shared_'+suffix;
  const users=['closure_queue_a_'+suffix,'closure_queue_b_'+suffix];
  for(const uid of users){await ref('users',uid).set({accountStatus:'active'});await ref('users',uid).collection('notifications').doc(notificationId).set({title:'Synthetic queued'});await ref('users',uid).collection('notification_devices').doc('device').set({enabled:true,token:'dev-retry:one',tokenHash:'device'});await queuePushDelivery(db,{notificationId,userId:uid,type:'system',title:'Synthetic',message:'Local only'},new Date(Date.now()-1000));}
  const jobs=await db.collection('notification_delivery_queue').where('notificationId','==',notificationId).get();assert.equal(jobs.size,2);
  await f.processNotificationDeliveryQueue.run({jobName:'local-test',scheduleTime:new Date().toISOString()});
  for(const uid of users)await ref('users',uid).collection('notification_devices').doc('device').update({token:'dev-ok:one'});
  for(const job of jobs.docs)await job.ref.update({deliverAfter:past()});
  await f.processNotificationDeliveryQueue.run({jobName:'local-test',scheduleTime:new Date().toISOString()});
  for(const uid of users){const data=await ref('users',uid).collection('notifications').doc(notificationId).get();assert.equal(data.get('pushDeliveryStatus'),'delivered');assert.equal(data.get('pushMode'),'simulation');}
  const interrupted='closure_interrupted_'+suffix;await ref('users',users[0]).collection('notifications').doc(interrupted).set({title:'Synthetic uncertain'});await queuePushDelivery(db,{notificationId:interrupted,userId:users[0],type:'system',title:'Synthetic',message:'Local only'},new Date(Date.now()-1000));const queue=(await db.collection('notification_delivery_queue').where('notificationId','==',interrupted).get()).docs[0];await queue.ref.update({attemptStartedAt:Timestamp.fromMillis(Date.now()-700000)});await f.processNotificationDeliveryQueue.run({jobName:'local-test',scheduleTime:new Date().toISOString()});assert.equal((await queue.ref.get()).get('status'),'delivery_uncertain');
 });
 await t.test('scheduler expiration does not increment completion count; explicit completion does once',async()=>{
  await ref('users',buyer).set({completedEventCount:0},{merge:true});
  await ref('events','closure_expire').set(event());await completeEventIfDue({eventId:'closure_expire',actorUid:null});assert.equal((await ref('events','closure_expire').get()).get('status'),'expired');assert.equal((await ref('users',buyer).get()).get('completedEventCount'),0);
  const rating=await run('getEventRatingState','user',{eventId:'closure_expire'});assert.equal(rating.completed,false);
  await assert.rejects(()=>run('markEventCompleted','user',{eventId:'closure_expire'}),e=>e.code==='failed-precondition');
  await Promise.all([run('markEventCompleted','user',{eventId:'closure_expire',confirmedOccurred:true}),run('markEventCompleted','user',{eventId:'closure_expire',confirmedOccurred:true})]);assert.equal((await ref('users',buyer).get()).get('completedEventCount'),1);assert.equal((await ref('events','closure_expire').get()).get('closureReason'),'occurred_confirmed');
  await ref('events','closure_cancelled').set(event({status:'cancelled',durum:'iptal'}));assert.equal(await completeEventIfDue({eventId:'closure_cancelled',actorUid:null}),'not_active');
  await ref('events','closure_legacy').set(event({status:'completed',durum:'tamamlandi'}));assert.equal((await run('getEventRatingState','user',{eventId:'closure_legacy'})).completed,false);
  await assert.rejects(()=>run('adminUpdateEventStatus','moderator',{eventId:'closure_expire',status:'active',reason:'No time travel'}),e=>e.code==='failed-precondition');
 });
 await t.test('gift sender ownership allowed; v2 option binding and delivery replay stay safe',async()=>{
  await ref('users',buyer).collection('owned_badges').doc('okey').set({googlePlayEntitled:true});
  const intent=await run('createGiftPurchaseIntent','user',{recipientUid:recipient,productId:'okey',kind:'badge_gift'}),token='dev-closure-gift-token-'+Date.now(),play='dort_gift_badge_okey';
  await fixture('GET',`${base}/purchases/products/${play}/tokens/${token}`,{purchaseState:0,orderId:'GPA.DEV.CLOSURE',obfuscatedExternalAccountId:intent.giftIntentId,consumptionState:1});
  await fixture('GET',`${base}/purchases/productsv2/tokens/${token}`,{purchaseStateContext:{purchaseState:'PURCHASED'},orderId:'GPA.DEV.CLOSURE',obfuscatedExternalAccountId:intent.giftIntentId,productLineItem:[{productId:play,productOfferDetails:{purchaseOptionId:'buy',quantity:1,consumptionState:'CONSUMPTION_STATE_CONSUMED'}}]});
  const input={buyerUid:buyer,googlePlayProductId:play,purchaseToken:token,giftIntentId:intent.giftIntentId,clientRecipientUid:recipient,internalProductId:'okey',kind:'badge_gift'};
  const delivered=await fulfillGiftPurchase(input);assert.equal(delivered.success,true);assert.equal((await fulfillGiftPurchase(input)).idempotentReplay,true);assert.equal((await db.collection('gift_deliveries').where('giftIntentId','==',intent.giftIntentId).get()).size,1);
  await assert.rejects(()=>fulfillGiftPurchase({...input,clientRecipientUid:buyer}));
  await assert.rejects(()=>run('createGiftPurchaseIntent','user',{recipientUid:buyer,productId:'okey',kind:'badge_gift'}));
  await ref('badge_products','paintball').set({giftGooglePlayProductId:''},{merge:true});
  await assert.rejects(()=>run('createGiftPurchaseIntent','user',{recipientUid:recipient,productId:'paintball',kind:'badge_gift'}),e=>e.code==='failed-precondition');
 });
 await t.test('refund note cannot resolve; only bound provider full refund resolves idempotently',async()=>{
  const id='closure_refund',token='dev-refund-token',orderId='GPA.DEV.REFUND',play='dort_gift_badge_okey';
  await ref('gift_purchase_intents','closure_refund_intent').set({buyerUid:buyer,recipientUid:recipient,productId:'okey',status:'review'});
  await ref('gift_reviews',id).set({status:'refund_review',providerVerified:true,providerOrderId:orderId,purchaseTokenHash:hash(token),googlePlayProductId:play,buyerUid:buyer,recipientUid:recipient,productId:'okey',giftIntentId:'closure_refund_intent'});
  await run('adminResolveGiftReview','finance_officer',{reviewId:id,action:'note',reason:'Synthetic note only'});assert.equal((await ref('gift_reviews',id).get()).get('status'),'refund_review');
  const url=base+'/orders/'+orderId;
  await fixture('GET',url,{orderId,purchaseToken:token,state:'PROCESSED',lineItems:[{productId:play}]});await assert.rejects(()=>run('adminResolveGiftReview','finance_officer',{reviewId:id,action:'verify_refund',reason:'Synthetic verify'}),e=>e.code==='failed-precondition');assert.equal((await ref('gift_reviews',id).get()).get('status'),'refund_review');
  await fixture('GET',url,{orderId,purchaseToken:token,state:'REFUNDED',lineItems:[{productId:play}],orderHistory:{refundEvent:{eventTime:new Date().toISOString()}}});
  await run('adminResolveGiftReview','finance_officer',{reviewId:id,action:'verify_refund',reason:'Synthetic verified result'});assert.equal((await ref('gift_reviews',id).get()).get('status'),'refunded_verified');assert.equal((await run('adminResolveGiftReview','finance_officer',{reviewId:id,action:'verify_refund',reason:'Synthetic replay'})).idempotentReplay,true);
  await ref('gift_reviews','closure_refund_legacy').set({status:'refund_review',purchaseTokenHash:hash(token),buyerUid:buyer,recipientUid:recipient,productId:'okey',giftIntentId:'closure_refund_legacy'});await ref('gift_purchase_intents','closure_refund_legacy').set({status:'review',buyerUid:buyer,recipientUid:recipient,productId:'okey',googlePlayProductId:play});
  await run('adminResolveGiftReview','finance_officer',{reviewId:'closure_refund_legacy',action:'verify_refund',reason:'Synthetic provider-bound legacy lookup',orderId});assert.equal((await ref('gift_reviews','closure_refund_legacy').get()).get('providerVerified'),true);
 });
 await t.test('role assignment, stale claims, revocation and self-escalation',async()=>{
  await assert.rejects(()=>run('setUserRole','admin',{uid:prefix+'admin',role:'super_admin',reason:'Escalate self'}),e=>e.code==='permission-denied');
  await run('setUserRole','super_admin',{uid:prefix+'analyst',role:'content_manager',reason:'Synthetic scope assignment'});assert.equal((await auth.getUser(prefix+'analyst')).customClaims.role,'content_manager');
  await assert.rejects(()=>run('adminGetReportOverview','analyst',{}),e=>e.code==='permission-denied');
  await auth.setCustomUserClaims(prefix+'analyst',{role:'analyst'});await ref('users',prefix+'analyst').set({role:'analyst'},{merge:true});
 });
 await t.test('V1 payment and wallet stay fail closed; report uses shared Plus and expiry',async()=>{
  await assert.rejects(()=>run('startPayment','user',{eventId:'closure_expire'}),e=>e.code==='failed-precondition');await assert.rejects(()=>run('adminAdjustWallet','finance_officer',{}),e=>e.code==='failed-precondition');
  await ref('users',recipient).set({plus:false,plusAdminGranted:true},{merge:true});const report=await run('adminGetReportOverview','analyst',{});assert(report.users.plus>=1);assert.equal('pendingPayments' in report.operations,false);assert(report.events.legacyClosed>=1);
 });
 await t.test('actual emulator HTTP authenticates, rejects bypass and immediately rejects stale role JWT',async()=>{
  const endpoint='http://127.0.0.1:5001/dorduncu-8e599/europe-west1/adminUpdateMembership';
  const login=async(role)=>{const response=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:prefix+role+'@dev.dort.invalid',password:'Closure-Dev-2026',returnSecureToken:true})});const data=await response.json();assert(response.ok);return data.idToken;};
  const appCheck=Buffer.from(JSON.stringify({alg:'none'})).toString('base64url')+'.'+Buffer.from(JSON.stringify({app_id:'closure-emulator'})).toString('base64url')+'.';
  const call=async(token)=>fetch(endpoint,{method:'POST',headers:{'content-type':'application/json','x-firebase-appcheck':appCheck,...(token?{authorization:'Bearer '+token}:{})},body:JSON.stringify({data:{userId:recipient,action:'plus',enabled:true,reason:'Synthetic HTTP permission test',auth:{role:'super_admin'}}})});
  assert.equal((await call(null)).status,401);assert.equal((await call(await login('user'))).status,403);
  const financeToken=await login('finance_officer');assert.equal((await call(financeToken)).status,200);assert.equal((await ref('users',recipient).get()).get('plusAdminGranted'),true);
  await run('setUserRole','super_admin',{uid:prefix+'finance_officer',role:'user',reason:'Synthetic immediate revocation'});assert.equal((await call(financeToken)).status,403);
  await run('setUserRole','super_admin',{uid:prefix+'finance_officer',role:'finance_officer',reason:'Synthetic role restore'});
 });
 await t.test('create/edit/apply/accept/expire/confirm/rate share quota and chat meaning',async()=>{
  const player=prefix+'finance_officer';
  await ref('users',player).set({gameSkills:{okey:{level:60}},accountStatus:'active'},{merge:true});
  const before=await run('getEventCreationQuotaState','user',{});
  const start=new Date(Date.now()+3600000),end=new Date(start.getTime()+3600000);
  const created=await run('createEvent','user',{gameId:'okey',playerCount:1,memberPreference:'Herkes',description:'Synthetic event',city:'İstanbul',district:'Kadıköy',neighborhood:'Synthetic',address:'Synthetic local address',latitude:40.99,longitude:29.02,startAt:start.toISOString(),endAt:end.toISOString()});
  const eventId=created.eventId,eventRef=ref('events',eventId);assert.equal((await eventRef.get()).get('paymentRequired'),false);assert.equal((await eventRef.get()).get('customerTotal'),0);
  assert.equal((await run('getEventCreationQuotaState','user',{})).openEventCount,before.openEventCount+1);
  await assert.rejects(()=>run('getEventCreationQuotaState','user',{uid:recipient}),e=>e.code==='permission-denied');
  await run('updateEvent','user',{eventId,description:'Synthetic edited'});assert.equal((await eventRef.get()).get('aciklama'),'Synthetic edited');
  await assert.rejects(()=>run('applyToEvent','finance_officer',{eventId,note:'Role is not a badge'}),e=>e.code==='failed-precondition');
  await run('adminUpdateMembership','super_admin',{userId:player,action:'playerBadge',enabled:true,reason:'Synthetic verified player fixture'});
  await run('applyToEvent','finance_officer',{eventId,note:'Synthetic participation'});assert.equal((await eventRef.collection('applications').doc(player).get()).exists,true);
  await run('acceptApplication','user',{eventId,playerId:player});assert((await eventRef.get()).get('selectedPlayerIds').includes(player));
  const {hasEventChatAccess}=require('../lib/chat/eventChatAccessPolicy.js');assert(await hasEventChatAccess(db,player,eventId));
  await eventRef.update({endAt:past(),startAt:Timestamp.fromMillis(Date.now()-7200000)});
  const count=(await ref('users',buyer).get()).get('completedEventCount');await f.completePastEvents.run({jobName:'local-test-only',scheduleTime:new Date().toISOString()});
  assert.equal((await eventRef.get()).get('status'),'expired');assert.equal((await ref('users',buyer).get()).get('completedEventCount'),count);assert.equal((await run('getEventRatingState','user',{eventId})).completed,false);
  assert(await hasEventChatAccess(db,player,eventId)); // Existing roster chat access is retained.
  await assert.rejects(()=>run('updateEvent','user',{eventId,description:'Too late'}),e=>e.code==='failed-precondition');
  await run('markEventCompleted','user',{eventId,confirmedOccurred:true});assert.equal((await run('getEventRatingState','user',{eventId})).completed,true);
  await run('submitEventRating','user',{eventId,targetUid:player,rating:5,comment:'Synthetic rating'});await run('submitEventRating','user',{eventId,targetUid:player,rating:5,comment:'Synthetic rating'});assert.equal((await eventRef.collection('ratings').get()).size,1);
  assert.equal((await run('getEventCreationQuotaState','user',{})).openEventCount,before.openEventCount);
 });
});
