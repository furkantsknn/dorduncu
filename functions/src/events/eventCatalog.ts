export interface EventGameDefinition {
  id: string;
  name: string;
  emoji: string;
  categoryId: string;
}

export interface EventCategoryDefinition {
  id: string;
  name: string;
  emoji: string;
  basePricePerPlayer: number;
  games: readonly EventGameDefinition[];
}

export interface EventPricingResult {
  category: EventCategoryDefinition;
  game: EventGameDefinition;
  durationMinutes: number;
  durationFactor: number;
  basePricePerPlayer: number;
  customerTotal: number;
  pricingVersion: string;
}

export const MINIMUM_DURATION_MINUTES = 60;
export const MAXIMUM_DURATION_MINUTES = 360;
export const DURATION_STEP_MINUTES = 30;
export const EVENT_PRICING_VERSION = "v2";

const durationFactors: Readonly<Record<number, number>> = {
  1: 1.0,
  2: 1.7,
  3: 2.3,
  4: 2.8,
  5: 3.2,
  6: 3.5,
};

export const eventCategories:
readonly EventCategoryDefinition[] = [
  {
    id: "masa_oyunlari",
    name: "Masa Oyunları",
    emoji: "🎲",
    basePricePerPlayer: 800,
    games: [
      {
        id: "okey",
        name: "Okey",
        emoji: "🎴",
        categoryId: "masa_oyunlari",
      },
      {
        id: "okey_101",
        name: "101",
        emoji: "🀄",
        categoryId: "masa_oyunlari",
      },
      {
        id: "batak",
        name: "Batak",
        emoji: "♠️",
        categoryId: "masa_oyunlari",
      },
      {
        id: "tavla",
        name: "Tavla",
        emoji: "🎲",
        categoryId: "masa_oyunlari",
      },
      {
        id: "satranc",
        name: "Satranç",
        emoji: "♟️",
        categoryId: "masa_oyunlari",
      },
      {
        id: "bric",
        name: "Briç",
        emoji: "🃏",
        categoryId: "masa_oyunlari",
      },
      {
        id: "king",
        name: "King",
        emoji: "👑",
        categoryId: "masa_oyunlari",
      },
      {
        id: "monopoly",
        name: "Monopoly",
        emoji: "🏠",
        categoryId: "masa_oyunlari",
      },
      {
        id: "uno",
        name: "Uno",
        emoji: "🟥",
        categoryId: "masa_oyunlari",
      },
      {
        id: "jenga",
        name: "Jenga",
        emoji: "🧱",
        categoryId: "masa_oyunlari",
      },
      {
        id: "scrabble",
        name: "Scrabble",
        emoji: "🔤",
        categoryId: "masa_oyunlari",
      },
      {
        id: "tombala",
        name: "Tombala",
        emoji: "🔢",
        categoryId: "masa_oyunlari",
      },
    ],
  },
  {
    id: "konsol_oyunlari",
    name: "Konsol Oyunları",
    emoji: "🎮",
    basePricePerPlayer: 1000,
    games: [
      {
        id: "ea_fc",
        name: "EA FC",
        emoji: "⚽",
        categoryId: "konsol_oyunlari",
      },
      {
        id: "efootball",
        name: "eFootball",
        emoji: "🎮",
        categoryId: "konsol_oyunlari",
      },
      {
        id: "tekken",
        name: "Tekken",
        emoji: "🥊",
        categoryId: "konsol_oyunlari",
      },
    ],
  },
  {
    id: "raket_sporlari",
    name: "Raket Sporları",
    emoji: "🎾",
    basePricePerPlayer: 1300,
    games: [
      {
        id: "tenis",
        name: "Tenis",
        emoji: "🎾",
        categoryId: "raket_sporlari",
      },
      {
        id: "masa_tenisi",
        name: "Masa Tenisi",
        emoji: "🏓",
        categoryId: "raket_sporlari",
      },
      {
        id: "badminton",
        name: "Badminton",
        emoji: "🏸",
        categoryId: "raket_sporlari",
      },
      {
        id: "squash",
        name: "Squash",
        emoji: "🎾",
        categoryId: "raket_sporlari",
      },
      {
        id: "pickleball",
        name: "Pickleball",
        emoji: "🏓",
        categoryId: "raket_sporlari",
      },
    ],
  },
  {
    id: "takim_sporlari",
    name: "Takım Sporları",
    emoji: "🏆",
    basePricePerPlayer: 1600,
    games: [
      {
        id: "futbol",
        name: "Futbol",
        emoji: "⚽",
        categoryId: "takim_sporlari",
      },
      {
        id: "basketbol",
        name: "Basketbol",
        emoji: "🏀",
        categoryId: "takim_sporlari",
      },
      {
        id: "voleybol",
        name: "Voleybol",
        emoji: "🏐",
        categoryId: "takim_sporlari",
      },
      {
        id: "hentbol",
        name: "Hentbol",
        emoji: "🤾",
        categoryId: "takim_sporlari",
      },
    ],
  },
  {
    id: "premium_sporlar",
    name: "Premium Sporlar",
    emoji: "⛳",
    basePricePerPlayer: 2500,
    games: [
      {
        id: "golf",
        name: "Golf",
        emoji: "⛳",
        categoryId: "premium_sporlar",
      },
      {
        id: "yelken",
        name: "Yelken",
        emoji: "⛵",
        categoryId: "premium_sporlar",
      },
      {
        id: "kurek",
        name: "Kürek",
        emoji: "🚣",
        categoryId: "premium_sporlar",
      },
      {
        id: "binicilik",
        name: "Binicilik",
        emoji: "🏇",
        categoryId: "premium_sporlar",
      },
      {
        id: "kayak",
        name: "Kayak",
        emoji: "⛷️",
        categoryId: "premium_sporlar",
      },
      {
        id: "snowboard",
        name: "Snowboard",
        emoji: "🏂",
        categoryId: "premium_sporlar",
      },
      {
        id: "paintball",
        name: "Paintball",
        emoji: "🎯",
        categoryId: "premium_sporlar",
      },
    ],
  },
];

/**
 * Returns a category by its permanent identifier.
 * @param {string} categoryId Category identifier.
 * @return {EventCategoryDefinition | undefined} Category definition.
 */
export function getEventCategory(
  categoryId: string
): EventCategoryDefinition | undefined {
  const normalizedCategoryId = categoryId.trim();

  return eventCategories.find(
    (category) => category.id === normalizedCategoryId
  );
}

/**
 * Returns a game by its permanent identifier.
 * @param {string} gameId Game identifier.
 * @return {EventGameDefinition | undefined} Game definition.
 */
export function getEventGame(
  gameId: string
): EventGameDefinition | undefined {
  const normalizedGameId = gameId.trim();

  for (const category of eventCategories) {
    const game = category.games.find(
      (item) => item.id === normalizedGameId
    );

    if (game) {
      return game;
    }
  }

  return undefined;
}

/**
 * Calculates the duration factor used by event pricing.
 * @param {number} durationMinutes Event duration in minutes.
 * @return {number} Duration pricing factor.
 */
export function calculateDurationFactor(
  durationMinutes: number
): number {
  if (durationMinutes <= 0) {
    return 0;
  }

  const clampedMinutes = Math.min(
    Math.max(durationMinutes, MINIMUM_DURATION_MINUTES),
    MAXIMUM_DURATION_MINUTES
  );

  const exactHours = clampedMinutes / 60;
  const lowerHour = Math.min(
    Math.max(Math.floor(exactHours), 1),
    6
  );
  const upperHour = Math.min(
    Math.max(Math.ceil(exactHours), 1),
    6
  );

  const lowerFactor = durationFactors[lowerHour] ?? 1;
  const upperFactor =
    durationFactors[upperHour] ?? lowerFactor;

  if (lowerHour === upperHour) {
    return lowerFactor;
  }

  const progress = exactHours - lowerHour;

  return lowerFactor +
    ((upperFactor - lowerFactor) * progress);
}

/**
 * Calculates trusted event pricing on the server.
 * @param {string} gameId Game identifier.
 * @param {number} playerCount Requested player count.
 * @param {number} durationMinutes Event duration in minutes.
 * @return {EventPricingResult | null} Trusted pricing result.
 */
export function calculateEventPricing(
  gameId: string,
  playerCount: number,
  durationMinutes: number
): EventPricingResult | null {
  const game = getEventGame(gameId);

  if (!game || playerCount <= 0 || durationMinutes <= 0) {
    return null;
  }

  const category = getEventCategory(game.categoryId);

  if (!category) {
    return null;
  }

  const durationFactor =
    calculateDurationFactor(durationMinutes);

  const rawTotal =
    category.basePricePerPlayer *
    playerCount *
    durationFactor;

  const customerTotal = Math.round(rawTotal / 10) * 10;

  return {
    category,
    game,
    durationMinutes,
    durationFactor,
    basePricePerPlayer: category.basePricePerPlayer,
    customerTotal,
    pricingVersion: EVENT_PRICING_VERSION,
  };
}
