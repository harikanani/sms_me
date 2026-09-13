package com.example.sms_me.flutter

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import com.example.sms_me.sms.SmsSender
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class SmsMethodChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.example.sms_me/sms_channel"
    }

    private val smsSender = SmsSender(context)
    private val scope = CoroutineScope(Dispatchers.Main)

    override onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sendSms" -> {
                val dest = call.argument<String>("destinationNumber") ?: ""
                val body = call.argument<String>("body") ?: ""
                val subId = call.argument<Int?>("subscriptionId")

                if (dest.isEmpty() || body.isEmpty()) {
                    result.success(mapOf("status" to "FAILED", "error" to "Invalid destination or body"))
                    return
                }

                scope.launch {
                    val res = smsSender.sendSms(dest, body, subId)
                    if (res.isSuccess) {
                        result.success(mapOf("status" to "SUCCESS"))
                    } else {
                        result.success(mapOf("status" to "FAILED", "error" to res.exceptionOrNull()?.message))
                    }
                }
            }

            "getSimInfo" -> {
                val simList = ArrayList<Map<String, Any?>>()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                    try {
                        val subManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                        val activeList: List<SubscriptionInfo>? = subManager.activeSubscriptionInfoList
                        if (activeList != null) {
                            for (info in activeList) {
                                val map = HashMap<String, Any?>()
                                map["subscriptionId"] = info.subscriptionId
                                map["simSlotIndex"] = info.simSlotIndex
                                map["displayName"] = info.displayName?.toString() ?: "SIM ${info.simSlotIndex + 1}"
                                map["carrierName"] = info.carrierName?.toString() ?: "Unknown"
                                simList.add(map)
                            }
                        }
                    } catch (_: Exception) {}
                }
                result.success(mapOf("sims" to simList))
            }

            "isBatteryOptimizationIgnored" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(powerManager.isIgnoringBatteryOptimizations(context.packageName))
                } else {
                    result.success(true)
                }
            }

            "requestBatteryOptimizationExemption" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${context.packageName}")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            context.startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                } else {
                    result.success(true)
                }
            }

            else -> result.notImplemented()
        }
    }
}
