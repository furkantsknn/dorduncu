import {onRequest} from "firebase-functions/v2/https";
import {readCanonicalGiftCatalog} from "./canonicalGiftReadback";

import {
  diagnosePlayAccess,
  diagnoseBadgeCatalog,
  diagnoseOkeyGiftPrice,
  diagnoseOkey101Price,
  diagnosePlayVoidedAccess,
} from "./googlePlayVerification";

/**
 * Private, read-only Play access check for project owners.
 *
 * Cloud Run IAM rejects callers without run.invoker, so the endpoint is not
 * public. It runs as the same runtime account as fulfillGooglePlayPurchase.
 */
export const diagnoseGooglePlayAccess = onRequest(
  {
    region: "europe-west1",
    invoker: "private",
    maxInstances: 1,
    timeoutSeconds: 120,
  },
  async (request, response) => {
    if (process.env.FUNCTIONS_EMULATOR === "true" ||
        process.env.FIRESTORE_EMULATOR_HOST) {
      response.status(501).json({error: "Dev uses controlled Play fixtures"});
      return;
    }
    if (request.method !== "GET") {
      response.status(405).end();
      return;
    }
    try {
      if (request.query.probe === "canonical-gifts") {
        if (Object.keys(request.query).some((key) => key !== "probe")) {
          response.status(400).json({
            error: "Only the fixed canonical gift probe is accepted",
          });
          return;
        }
        response.status(200).json({products: await readCanonicalGiftCatalog()});
        return;
      }
      if (request.query.probe === "badge-catalog") {
        const catalog = await diagnoseBadgeCatalog();
        response.status(200).json({products: catalog});
        return;
      }
      if (request.query.probe === "badge-price") {
        const price = await diagnoseOkey101Price();
        console.log("Google Play badge price diagnosis", {
          product: price.product,
          option: price.option,
          region: price.region,
          active: price.active,
          amount: price.amount,
        });
        response.status(200).json(price);
        return;
      }
      if (request.query.probe === "okey-gift-price") {
        const price = await diagnoseOkeyGiftPrice();
        console.log("Google Play Okey gift price diagnosis", {
          product: price.product,
          option: price.option,
          region: price.region,
          active: price.active,
          amount: price.amount,
        });
        response.status(200).json(price);
        return;
      }
      const diagnosis = request.query.probe === "voided" ?
        await diagnosePlayVoidedAccess() : await diagnosePlayAccess();
      console.log(
        "Google Play access diagnosis",
        diagnosis.probes
          .map((probe) => `${probe.label}=${probe.manualStatus}`)
          .join("; "),
      );
      response.status(200).json(diagnosis);
    } catch {
      console.error("Google Play access diagnosis failed.");
      response.status(500).json({error: "diagnosis failed"});
    }
  },
);
