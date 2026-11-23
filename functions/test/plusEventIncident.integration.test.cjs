const test=require('node:test'),assert=require('node:assert/strict');
if(!/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST??'') || process.env.GCLOUD_PROJECT!=='demo-plus-incident')throw Error('Local demo Firestore required');
process.env.FUNCTIONS_EMULATOR='true';
process.env.ANDROID_PACKAGE_NAME='com.dortapp.dort';
const {getFirestore,Timestamp}=require('firebase-admin/firestore');
const {createEvent}=require('../lib/events/createEvent');
const {getEventCreationQuotaState}=require('../lib/events/getEventCreationQuotaState');
const {isPlusMembershipActive}=require('../lib/users/plusMembership');
const {buildEventQuotaState,eventCountsTowardOpenQuota}=require('../lib/events/eventOpenQuotaPolicy');
const {syncCurrentPublicProfile}=require('../lib/users/syncPublicProfile');
const db=getFirestore();
const now=Date.now();
// Keep the free-account fixture on today's Istanbul calendar day, even at midnight.
const clock=new Date(now),day=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Istanbul',year:'numeric',month:'2-digit',day:'2-digit'}).format(clock);
const endOfDay=Date.parse(day+'T23:59:00+03:00');
const start=Math.min(now+60000,endOfDay-3600000);
const payload={gameId:'okey',playerCount:1,memberPreference:'Herkes',description:'Synthetic incident fixture',city:'Synthetic',district:'Synthetic',neighborhood:'Synthetic',address:'Synthetic',latitude:41,longitude:29,startAt:start,endAt:start+3600000};
const request=(uid,data)=>({auth:{uid,token:{}},data});
const create=(uid,key,extra={})=>createEvent.run(request(uid,{...payload,requestId:key,...extra}));
const profile=(uid,data={})=>db.doc('users/'+uid).set({hesapDurumu:'active',...data});
const count=async uid=>(await db.collection('events').where('olusturanUid','==',uid).get()).size;
test('actual create/quota handlers and independent entitlement sources',async t=>{
 await t.test('free 0→1→2 allowed, 2→3 denied with explicit product code',async()=>{
  await profile('free');
  assert.equal((await getEventCreationQuotaState.run(request('free',{}))).canCreate,true);
  await create('free','free-request-0001');await create('free','free-request-0002');
  await assert.rejects(()=>create('free','free-request-0003'),e=>e.code==='resource-exhausted'&&e.details.code==='free_open_event_quota_reached');
  assert.equal(await count('free'),2);
 });
 await t.test('admin Plus second and third allowed; role alone grants nothing',async()=>{
  await profile('grant',{plusAdminGranted:true});
  for(let i=0;i<3;i++)await create('grant','grant-request-00'+i);
  const q=await getEventCreationQuotaState.run(request('grant',{}));
  assert.equal(q.plusActive,true);assert.equal(q.limit,null);assert.equal(q.openEventCount,3);
  assert.equal(isPlusMembershipActive({role:'admin',admin:true}),false);
 });
 await t.test('removed grant and expired subscription lose access; independent Play survives removal',async()=>{
  const past=Timestamp.fromMillis(now-60000),future=Timestamp.fromMillis(now+3600000);
  assert.equal(isPlusMembershipActive({plusAdminGranted:false,plus:true,plusSubscriptionExpiresAt:past}),false);
  assert.equal(isPlusMembershipActive({plusAdminGranted:false,plus:true,plusSubscriptionExpiresAt:future,plusSubscriptionState:'SUBSCRIPTION_STATE_ACTIVE'}),true);
  assert.equal(isPlusMembershipActive({plusAdminGranted:false,plusGiftExpiresAt:future,plusSubscriptionExpiresAt:past}),true);
  assert.equal(isPlusMembershipActive({plusAdminGranted:false,plusGiftExpiresAt:past,plus:true,plusExpiresAt:future}),false);
  await profile('grant',{plusAdminGranted:false});
  await assert.rejects(()=>create('grant','grant-removed-001'),e=>e.details?.code==='free_open_event_quota_reached');
 });
 await t.test('public projection preserves independent gift/subscription fields and revocation',async()=>{
  const future=Timestamp.fromMillis(now+3600000),past=Timestamp.fromMillis(now-60000);
  await profile('projection',{accountStatus:'active',plus:true,plusAdminGranted:false,plusGiftExpiresAt:future,plusSubscriptionExpiresAt:past,plusSubscriptionState:'SUBSCRIPTION_STATE_EXPIRED'});
  await syncCurrentPublicProfile('projection');
  const visible=await db.doc('public_profiles/projection').get();
  assert.equal(visible.get('plus'),true);
  assert.equal(visible.get('plusGiftExpiresAt').toMillis(),future.toMillis());
  assert.equal(visible.get('plusSubscriptionExpiresAt').toMillis(),past.toMillis());
  await db.doc('users/projection').update({plusGiftExpiresAt:past});
  await syncCurrentPublicProfile('projection');
  assert.equal((await db.doc('public_profiles/projection').get()).get('plus'),false);
 });
 await t.test('past and cancelled events do not consume quota; no manual counter repair',async()=>{
  await profile('past');
  for(const [id,extra] of [['old',{endAt:Timestamp.fromMillis(now-1)}],['cancel',{durum:'cancelled',endAt:Timestamp.fromMillis(now+60000)}]])await db.doc('events/'+id).set({olusturanUid:'past',...extra});
  await create('past','past-request-0001');await create('past','past-request-0002');
  const q=await getEventCreationQuotaState.run(request('past',{}));assert.equal(q.openEventCount,2);assert.equal(q.canCreate,false);
  assert.equal(eventCountsTowardOpenQuota({status:'expired'},now),false);
  assert.equal(buildEventQuotaState(['a','b'],true).canCreate,true);
 });
 await t.test('concurrent double submission and lost response replay create one document',async()=>{
  await profile('duplicate',{plusAdminGranted:true});
  const results=await Promise.all([create('duplicate','duplicate-key-001'),create('duplicate','duplicate-key-001')]);
  assert.equal(results[0].eventId,results[1].eventId);
  assert.equal((await create('duplicate','duplicate-key-001')).eventId,results[0].eventId);
  assert.equal(await count('duplicate'),1);
  await assert.rejects(()=>create('duplicate','duplicate-key-001',{description:'Changed payload'}),e=>e.details?.code==='event_request_conflict');
  assert.equal(await count('duplicate'),1);
 });
});

test('Play verification account binding failure stays separate from capacity and never acknowledges',async()=>{
 const crypto=require('crypto');
 const {fulfillGooglePlayPurchase}=require('../lib/market/fulfillGooglePlayPurchase');
 const token='synthetic-token-no-provider',url='https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.dortapp.dort/purchases/subscriptionsv2/tokens/'+token;
 const key=crypto.createHash('sha256').update('GET:'+url).digest('hex');
 await db.doc('plus_products/monthly').set({active:true,googlePlayProductId:'dort_plus',googlePlayBasePlanId:'monthly',priceKurus:100});
 await db.doc('dev_external_adapters/'+key).set({service:'google_play',response:{subscriptionState:'SUBSCRIPTION_STATE_ACTIVE',acknowledgementState:'ACKNOWLEDGEMENT_STATE_PENDING',externalAccountIdentifiers:{obfuscatedExternalAccountId:'other-account'},lineItems:[{productId:'dort_plus',expiryTime:new Date(now+3600000).toISOString(),offerDetails:{basePlanId:'monthly'}}]}});
 await assert.rejects(()=>fulfillGooglePlayPurchase.run(request('grant',{googlePlayProductId:'dort_plus',purchaseToken:token})),e=>e.code==='permission-denied');
 assert.equal((await db.collection('market_sales').get()).size,0);
 assert.equal((await db.collection('google_play_purchase_tokens').get()).size,0);
});
