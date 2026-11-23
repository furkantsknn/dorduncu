const GENERIC_BADGE_TITLES = new Set([
  "oyun rozeti",
  "oyun rozet",
]);

export interface PublicMarketBadge {
  badgeId: string;
  productId: string;
  title: string;
  gameId: string;
  gameName: string;
  emoji: string;
  imageUrl: string;
}

export interface OwnedBadgeRecord {
  id: string;
  data: Record<string, unknown>;
}

export type BadgeProductLoader = (
  productId: string,
) => Promise<Record<string, unknown> | undefined>;

/**
 * Builds the public badge list from owned_badges.
 *
 * owned_badges keeps purchase tokens, hashes, prices and operation ids.
 * Those fields stay private. The result only carries the id, name and
 * visual fields needed to draw the badge. A revoked Play entitlement
 * (googlePlayEntitled === false) is not shown.
 * @param {OwnedBadgeRecord[]} owned Owned badge documents.
 * @param {BadgeProductLoader} loadProduct Reads badge_products/{id}.
 * @return {Promise<PublicMarketBadge[]>} Public badge entries.
 */
export async function projectPublicMarketBadges(
  owned: OwnedBadgeRecord[],
  loadProduct: BadgeProductLoader,
): Promise<PublicMarketBadge[]> {
  const marketBadges: PublicMarketBadge[] = [];

  for (const document of owned) {
    const data = document.data;
    if (!badgeIsEntitled(data)) {
      continue;
    }

    const badgeId = readText(data.badgeId) ||
      readText(data.productId) ||
      document.id;
    const productId = readText(data.productId) || badgeId;
    let title = readText(data.title);
    let gameId = readText(data.gameId);
    let gameName = readText(data.gameName);
    let emoji = readText(data.emoji);
    let imageUrl = readText(data.imageUrl);

    if (
      isGenericTitle(title) ||
      emoji.length === 0 ||
      imageUrl.length === 0
    ) {
      const productData = (await loadProduct(productId || badgeId)) ?? {};
      const productTitle = readText(productData.title);
      if (!isGenericTitle(productTitle)) {
        title = productTitle;
      }
      if (gameId.length === 0) {
        gameId = readText(productData.gameId);
      }
      if (gameName.length === 0) {
        gameName = readText(productData.gameName);
      }
      if (emoji.length === 0) {
        emoji = readText(productData.emoji);
      }
      if (imageUrl.length === 0) {
        imageUrl = readText(productData.imageUrl);
      }
    }

    if (isGenericTitle(title) && gameName.length > 0) {
      title = gameName;
    }

    marketBadges.push({
      badgeId,
      productId: productId || badgeId,
      title,
      gameId,
      gameName,
      emoji,
      imageUrl,
    });
  }

  return marketBadges;
}

/**
 * True when a stored public list already matches the projection.
 * @param {unknown} stored public_profiles.marketBadges value.
 * @param {PublicMarketBadge[]} projected Fresh projection.
 * @return {boolean} Whether no write is needed.
 */
export function sameMarketBadges(
  stored: unknown,
  projected: PublicMarketBadge[],
): boolean {
  if (!Array.isArray(stored) || stored.length !== projected.length) {
    return false;
  }
  const keys: (keyof PublicMarketBadge)[] = [
    "badgeId",
    "productId",
    "title",
    "gameId",
    "gameName",
    "emoji",
    "imageUrl",
  ];
  return projected.every((badge, index) => {
    const entry = stored[index];
    if (entry === null || typeof entry !== "object") {
      return false;
    }
    const record = entry as Record<string, unknown>;
    return Object.keys(record).length === keys.length &&
      keys.every((key) => record[key] === badge[key]);
  });
}

/**
 * Reads a trimmed string.
 * @param {unknown} value Raw value.
 * @return {string} Trimmed text.
 */
function readText(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * True for the placeholder badge title.
 * @param {string} value Title.
 * @return {boolean} Whether the title is generic.
 */
function isGenericTitle(value: string): boolean {
  return GENERIC_BADGE_TITLES.has(value.trim().toLowerCase());
}
import {badgeIsEntitled} from "../market/badgeEntitlementPolicy";
