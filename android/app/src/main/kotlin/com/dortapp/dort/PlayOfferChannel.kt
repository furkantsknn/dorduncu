package com.dortapp.dort

import android.app.Activity
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.QueryProductDetailsParams
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Reads official Billing Library one-time offer tokens.
 * The Flutter billing plugin does not expose offerId or offerToken.
 */
object PlayOfferChannel {
    private const val CHANNEL = "com.dortapp.dort/play_offers"

    fun register(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "queryOneTimeOffers") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val productIds = call.argument<List<String>>("productIds")
                ?.map { it.trim() }
                ?.filter { it.isNotEmpty() }
                ?.distinct()
                ?: emptyList()
            if (productIds.isEmpty()) {
                result.success(emptyList<Map<String, Any?>>())
                return@setMethodCallHandler
            }
            val billing = BillingClient.newBuilder(activity)
                .enablePendingPurchases(
                    PendingPurchasesParams.newBuilder()
                        .enableOneTimeProducts()
                        .build(),
                )
                .setListener { _, _ -> }
                .build()
            val completed = AtomicBoolean(false)
            fun finish(block: () -> Unit) {
                if (completed.compareAndSet(false, true)) {
                    billing.endConnection()
                    block()
                }
            }
            billing.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(billingResult: BillingResult) {
                    if (billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
                        finish {
                            result.error("billing_unavailable", "Google Play Billing bağlanamadı.", null)
                        }
                        return
                    }
                    val products = productIds.map { id ->
                        QueryProductDetailsParams.Product.newBuilder()
                            .setProductId(id)
                            .setProductType(BillingClient.ProductType.INAPP)
                            .build()
                    }
                    val params = QueryProductDetailsParams.newBuilder()
                        .setProductList(products)
                        .build()
                    billing.queryProductDetailsAsync(params) { queryResult, details ->
                        if (queryResult.responseCode != BillingClient.BillingResponseCode.OK) {
                            finish {
                                result.error("billing_query_failed", "Play ürün teklifleri okunamadı.", null)
                            }
                            return@queryProductDetailsAsync
                        }
                        val offers = mutableListOf<Map<String, Any?>>()
                        for (product in details.productDetailsList) {
                            for (offer in product.oneTimePurchaseOfferDetailsList.orEmpty()) {
                                offers.add(
                                    mapOf(
                                        "productId" to product.productId,
                                        "offerId" to offer.offerId,
                                        "offerToken" to offer.offerToken,
                                        "purchaseOptionId" to offer.purchaseOptionId,
                                        "formattedPrice" to offer.formattedPrice,
                                        "priceAmountMicros" to offer.priceAmountMicros,
                                        "currencyCode" to offer.priceCurrencyCode,
                                        "fullPriceMicros" to offer.fullPriceMicros,
                                    ),
                                )
                            }
                        }
                        finish { result.success(offers) }
                    }
                }

                override fun onBillingServiceDisconnected() {
                    finish {
                        result.error(
                            "billing_disconnected",
                            "Google Play Billing bağlantısı kesildi.",
                            null,
                        )
                    }
                }
            })
        }
    }
}
