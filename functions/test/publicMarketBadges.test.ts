import assert from "node:assert/strict";
import test from "node:test";

import {
  projectPublicMarketBadges,
  sameMarketBadges,
} from "../src/users/publicMarketBadges";

const products: Record<string, Record<string, unknown>> = {
  okey: {
    title: "Okey Rozeti",
    gameId: "okey",
    gameName: "Okey",
    emoji: "🀄",
    imageUrl: "https://example.test/okey.png",
    priceKurus: 29900,
  },
};

const loadProduct = async (id: string) => products[id];

test("iade/geri alınan Play hakkı herkese açık listeye girmez", async () => {
  const badges = await projectPublicMarketBadges(
    [
      {id: "okey", data: {productId: "okey", googlePlayEntitled: false}},
    ],
    loadProduct,
  );
  assert.deepEqual(badges, []);
});

test("silinen rozet listeden düşer", async () => {
  const before = await projectPublicMarketBadges(
    [{id: "okey", data: {productId: "okey"}}],
    loadProduct,
  );
  const after = await projectPublicMarketBadges([], loadProduct);
  assert.equal(before.length, 1);
  assert.deepEqual(after, []);
  assert.equal(sameMarketBadges(before, after), false);
});

test("yalnızca görsel alanlar taşınır, token ve fiyat taşınmaz", async () => {
  const badges = await projectPublicMarketBadges(
    [
      {
        id: "okey",
        data: {
          productId: "okey",
          title: "Oyun Rozeti",
          googlePlayEntitled: true,
          googlePlayPurchaseTokenHash: "hash",
          googlePlayOperationId: "op",
          priceKurus: 29900,
        },
      },
    ],
    loadProduct,
  );
  assert.deepEqual(badges, [
    {
      badgeId: "okey",
      productId: "okey",
      title: "Okey Rozeti",
      gameId: "okey",
      gameName: "Okey",
      emoji: "🀄",
      imageUrl: "https://example.test/okey.png",
    },
  ]);
});

test("eski eksik kayıt ürün kataloğundan tamamlanır", async () => {
  const badges = await projectPublicMarketBadges(
    [{id: "okey", data: {purchasedAt: "legacy"}}],
    loadProduct,
  );
  assert.equal(badges[0].badgeId, "okey");
  assert.equal(badges[0].title, "Okey Rozeti");
});

test("aynı liste ikinci kez yazılmaz", async () => {
  const badges = await projectPublicMarketBadges(
    [{id: "okey", data: {productId: "okey"}}],
    loadProduct,
  );
  assert.equal(sameMarketBadges(JSON.parse(JSON.stringify(badges)), badges),
    true);
  assert.equal(sameMarketBadges(undefined, badges), false);
  assert.equal(
    sameMarketBadges([{...badges[0], tokenHash: "x"}], badges),
    false,
  );
});

test("admin block suppresses public projection after Play restore", async () => {
  const badges = await projectPublicMarketBadges(
    [{id: "okey", data: {
      productId: "okey",
      googlePlayEntitled: true,
      adminBlocked: true,
    }}],
    loadProduct,
  );
  assert.deepEqual(badges, []);
});

test("independent admin grant remains public after Play refund", async () => {
  const badges = await projectPublicMarketBadges(
    [{id: "okey", data: {
      productId: "okey",
      googlePlayEntitled: false,
      adminGranted: true,
    }}],
    loadProduct,
  );
  assert.equal(badges.length, 1);
});
