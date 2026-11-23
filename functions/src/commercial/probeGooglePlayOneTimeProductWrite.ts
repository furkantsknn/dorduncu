import {GoogleAuth} from "google-auth-library";
import {onRequest} from "firebase-functions/v2/https";

const PLAY_BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3";
const PLAY_SCOPE = "https://www.googleapis.com/auth/androidpublisher";
const PACKAGE_NAME = "com.dortapp.dort";
const PRODUCT_ID = "dort_badge_okey_101";
const auth = new GoogleAuth({scopes: [PLAY_SCOPE]});

interface PlayProduct {
  productId?: string;
  listings?: Array<Record<string, unknown>>;
  regionsVersion?: {version?: string};
  purchaseOptions?: Array<{purchaseOptionId?: string; state?: string}>;
}

/**
 * Performs one controlled no-op write against an existing badge listing.
 * Price, purchase option, region, and state are never included in the patch.
 */
export const probeGooglePlayOneTimeProductWrite = onRequest(
  {
    region: "europe-west1",
    invoker: "private",
    maxInstances: 1,
    timeoutSeconds: 120,
  },
  async (request, response) => {
    if (process.env.FUNCTIONS_EMULATOR === "true" ||
        process.env.FIRESTORE_EMULATOR_HOST) {
      response.status(501).json({error: "Dev provider writes disabled"});
      return;
    }
    if (request.method !== "POST") {
      response.status(405).json({error: "method_not_allowed"});
      return;
    }

    const client = await auth.getClient();
    const appPath = `${PLAY_BASE}/applications/${PACKAGE_NAME}`;

    try {
      const current = await client.request<PlayProduct>({
        url: `${appPath}/oneTimeProducts/${PRODUCT_ID}`,
        method: "GET",
      });
      const listings = current.data.listings ?? [];
      const regionsVersion = String(
        current.data.regionsVersion?.version ?? "",
      ).trim();
      if (listings.length === 0) {
        response.status(409).json({error: "listings_unavailable"});
        return;
      }
      if (!regionsVersion) {
        response.status(409).json({error: "regions_version_unavailable"});
        return;
      }

      const query = new URLSearchParams();
      query.set("updateMask", "listings");
      query.set("regionsVersion.version", regionsVersion);
      query.set(
        "latencyTolerance",
        "PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_TOLERANT",
      );
      const patchResult = await client.request<PlayProduct>({
        url: `${appPath}/onetimeproducts/${PRODUCT_ID}?${query}`,
        method: "PATCH",
        data: {
          packageName: PACKAGE_NAME,
          productId: PRODUCT_ID,
          listings,
        },
        validateStatus: () => true,
      });

      const requestId = String(
        patchResult.headers.get("x-guploader-uploadid") ??
        patchResult.headers.get("x-request-id") ??
        patchResult.headers.get("x-google-request-id") ??
        "",
      ).slice(0, 200);
      if (patchResult.status < 200 || patchResult.status >= 300) {
        const playError = patchResult.data as unknown as {
          error?: {status?: unknown; message?: unknown};
        };
        response.status(502).json({
          outcome: "play_write_rejected",
          method: "monetization.onetimeproducts.patch",
          httpStatus: patchResult.status,
          status: String(playError.error?.status ?? "").slice(0, 80),
          message: String(playError.error?.message ?? "").slice(0, 240),
          requestId,
          productId: PRODUCT_ID,
        });
        return;
      }

      const readBack = await client.request<PlayProduct>({
        url: `${appPath}/oneTimeProducts/${PRODUCT_ID}`,
        method: "GET",
      });
      response.status(200).json({
        outcome: "noop_listing_patch_succeeded",
        productId: readBack.data.productId ?? PRODUCT_ID,
        purchaseOptionId:
          readBack.data.purchaseOptions?.[0]?.purchaseOptionId ?? "",
        state: readBack.data.purchaseOptions?.[0]?.state ?? "",
        requestId,
      });
    } catch (error) {
      const candidate = error as {
        response?: {status?: number; data?: unknown; headers?: unknown};
        message?: string;
      };
      console.error("Controlled Play write probe failed.", {
        status: candidate.response?.status ?? 0,
        message: String(candidate.message ?? "unknown").slice(0, 240),
      });
      response.status(500).json({
        outcome: "probe_failed_before_write_result",
        httpStatus: candidate.response?.status ?? 0,
        message: String(candidate.message ?? "unknown").slice(0, 240),
      });
    }
  },
);
