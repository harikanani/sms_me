package com.example.sms_me.sms

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.SmsManager
import android.util.Log
import androidx.core.content.ContextCompat
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

class SmsSender(private val context: Context) {

    companion object {
        private const val TAG = "SmsSender"
        private const val ACTION_SMS_SENT = "com.example.sms_me.SMS_SENT"
        private const val ACTION_SMS_DELIVERED = "com.example.sms_me.SMS_DELIVERED"
    }

    suspend fun sendSms(
        destinationNumber: String,
        body: String,
        subscriptionId: Int?
    ): Result<Unit> = suspendCoroutine { continuation ->
        try {
            val smsManager: SmsManager = getSmsManager(subscriptionId)

            val sentIntent = PendingIntent.getBroadcast(
                context,
                0,
                Intent(ACTION_SMS_SENT),
                PendingIntent.FLAG_ONE_SHOT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val sentReceiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context?, intent: Intent?) {
                    try {
                        context.unregisterReceiver(this)
                    } catch (_: Exception) {}

                    if (resultCode == Activity.RESULT_OK) {
                        Log.i(TAG, "Outgoing SMS successfully sent to $destinationNumber")
                        continuation.resume(Result.success(Unit))
                    } else {
                        val errorMsg = "SMS send failed with resultCode: $resultCode"
                        Log.e(TAG, errorMsg)
                        continuation.resume(Result.failure(Exception(errorMsg)))
                    }
                }
            }

            ContextCompat.registerReceiver(
                context,
                sentReceiver,
                IntentFilter(ACTION_SMS_SENT),
                ContextCompat.RECEIVER_NOT_EXPORTED
            )

            // Support multi-part SMS if body is long
            val parts = smsManager.divideMessage(body)
            if (parts.size > 1) {
                val sentIntents = ArrayList<PendingIntent>()
                for (i in parts.indices) {
                    sentIntents.add(sentIntent)
                }
                smsManager.sendMultipartTextMessage(
                    destinationNumber,
                    null,
                    parts,
                    sentIntents,
                    null
                )
            } else {
                smsManager.sendTextMessage(
                    destinationNumber,
                    null,
                    body,
                    sentIntent,
                    null
                )
            }

        } catch (e: Exception) {
            Log.e(TAG, "Exception while attempting to send SMS", e)
            continuation.resume(Result.failure(e))
        }
    }

    private fun getSmsManager(subscriptionId: Int?): SmsManager {
        return if (subscriptionId != null && subscriptionId != -1 && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java).createForSubscriptionId(subscriptionId)
        } else if (subscriptionId != null && subscriptionId != -1 && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            @Suppress("DEPRECATION")
            SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                context.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
        }
    }
}
