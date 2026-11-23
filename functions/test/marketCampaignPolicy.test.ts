import assert from "node:assert/strict";
import test from "node:test";

import {
  discountedKurus,
  playPaidFraction,
} from "../src/commercial/marketCatalog.ts";
import {
  campaignOfferId,
  findCampaignConflict,
  previewCampaign,
  statusAfterSync,
} from "../src/commercial/marketCampaignPolicy.ts";
import {
  oneTimeDiscountBatchBody,
  subscriptionDiscountOfferBody,
} from "../src/commercial/playOfferPayloads.ts";
import {
  hasAdminPermission,
} from "../src/security/adminAuthorization.ts";
import type {CallableRequest} from "firebase-functions/https";

test("indirim kanonik fiyattan hesaplanır ve katlanmaz", () => {
  const once = discountedKurus(49900, 20);
  const twice = discountedKurus(49900, 20);

  assert.equal(once, 39920);
  assert.equal(twice, once);
  assert.equal(playPaidFraction(20), 0.8);
  assert.notEqual(discountedKurus(49900, 20), discountedKurus(once, 20));
});

test("çakışan kampanya reddedilir, bitmiş kampanya engellemez", () => {
  const conflict = findCampaignConflict({
    campaignId: "new",
    startsAtMs: 10,
    endsAtMs: 20,
    productKeys: ["badge:okey"],
    existing: [
      {
        campaignId: "open",
        status: "active",
        startsAtMs: 15,
        endsAtMs: 30,
        productKeys: ["badge:okey"],
      },
    ],
  });
  const ended = findCampaignConflict({
    campaignId: "new",
    startsAtMs: 10,
    endsAtMs: 20,
    productKeys: ["badge:okey"],
    existing: [
      {
        campaignId: "old",
        status: "ended",
        startsAtMs: 10,
        endsAtMs: 20,
        productKeys: ["badge:okey"],
      },
    ],
  });

  assert.equal(conflict, "open");
  assert.equal(ended, null);
});

test("seçili kapsam boş ürün listesini reddeder", () => {
  assert.throws(
    () =>
      previewCampaign(
        {
          campaignId: "c1",
          scope: "selected",
          percent: 20,
          startsAtMs: 1,
          endsAtMs: 2,
          plusDiscountedPeriods: null,
          selectedProductKeys: [],
        },
        [],
      ),
    /selected_products_required/,
  );
});

test("önizleme normal fiyatı ve Plus yenilemesini gösterir", () => {
  const [plus] = previewCampaign(
    {
      campaignId: "c1",
      scope: "plus",
      percent: 50,
      startsAtMs: 1,
      endsAtMs: 2,
      plusDiscountedPeriods: 2,
      selectedProductKeys: [],
    },
    [
      {
        productKey: "plus:monthly",
        kind: "plus",
        internalProductId: "monthly",
        googlePlayProductId: "dort_plus",
        purchaseOptionId: "",
        basePlanId: "monthly",
      },
    ],
  );

  assert.equal(plus.normalPriceKurus, 79900);
  assert.equal(plus.discountedPriceKurus, 39950);
  assert.equal(plus.renewalPriceKurus, 79900);
  assert.equal(plus.plusDiscountedPeriods, 2);
  assert.match(plus.eligibility, /Mevcut abonelerin fiyatı değişmez/);
});

test("kısmi Play hatası kampanyayı aktif saymaz", () => {
  assert.equal(statusAfterSync({
    nowMs: 20,
    startsAtMs: 10,
    endsAtMs: 30,
    results: [{ok: true}, {ok: false}],
  }), "partial_error");
  assert.equal(statusAfterSync({
    nowMs: 40,
    startsAtMs: 10,
    endsAtMs: 30,
    results: [{ok: true}],
  }), "ended");
});

test("Play teklif gövdesi yalnızca TR indirimini ve yeni aboneyi hedefler", () => {
  const oneTime = oneTimeDiscountBatchBody({
    packageName: "com.dortapp.dort",
    productId: "badge_okey",
    purchaseOptionId: "buy",
    offerId: campaignOfferId("c1", "badge:okey"),
    paidFraction: 0.8,
    startsAtIso: "2026-10-08T00:00:00.000Z",
    endsAtIso: "2026-10-15T00:00:00.000Z",
    regionsVersion: "2025/03",
    active: true,
  });
  const offer = (
    oneTime.requests as Array<Record<string, unknown>>
  )[0].oneTimeProductOffer as Record<string, unknown>;
  const regions = offer.regionalPricingAndAvailabilityConfigs as unknown[];
  const subscription = subscriptionDiscountOfferBody({
    packageName: "com.dortapp.dort",
    productId: "dort_plus",
    basePlanId: "monthly",
    offerId: "cplus",
    paidFraction: 0.8,
    discountedPeriods: 2,
    regionsVersion: "2025/03",
  });
  const targeting = subscription.targeting as {
    acquisitionRule: {scope: {thisSubscription: object}};
  };

  assert.equal(regions.length, 1);
  assert.equal(subscription.phases instanceof Array, true);
  assert.equal(
    (subscription.phases as Array<{recurrenceCount: number}>)[0]
      .recurrenceCount,
    2,
  );
  assert.deepEqual(targeting.acquisitionRule.scope.thisSubscription, {});
  assert.equal(
    (subscription.regionalConfigs as Array<{regionCode: string}>)[0]
      .regionCode,
    "TR",
  );
});

test("finans yetkisi olmayan admin kampanya açamaz", () => {
  const request = {
    auth: {
      uid: "content-admin",
      token: {role: "content_manager"},
    },
  } as CallableRequest<unknown>;

  assert.equal(hasAdminPermission(request, "finance.manage"), false);
  assert.equal(hasAdminPermission(request, "content.manage"), true);
});
