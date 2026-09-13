package com.example.sms_me.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.telephony.SmsMessage
import android.util.Log
import com.example.sms_me.MainActivity

class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SmsReceiver"
        private const val SMS_RECEIVED_ACTION = "android.provider.Telephony.SMS_RECEIVED"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != SMS_RECEIVED_ACTION) return

        val bundle: Bundle? = intent.extras
        if (bundle == null) return

        try {
            val pdus = bundle.get("pdus") as? Array<*> ?: return
            if (pdus.isEmpty()) return

            val format = bundle.getString("format")
            var sender = ""
            var timestamp: Long = System.currentTimeMillis()
            val fullBodyBuilder = StringBuilder()

            // Extract subscription ID (dual SIM)
            var subscriptionId: Int? = null
            if (bundle.containsKey("subscription")) {
                subscriptionId = bundle.getInt("subscription")
            } else if (bundle.containsKey("sub_id")) {
                subscriptionId = bundle.getInt("sub_id")
            }

            for (pdu in pdus) {
                val sms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    SmsMessage.createFromPdu(pdu as ByteArray, format)
                } else {
                    @Suppress("DEPRECATION")
                    SmsMessage.createFromPdu(pdu as ByteArray)
                }

                if (sms != null) {
                    if (sender.isEmpty()) {
                        sender = sms.displayOriginatingAddress ?: sms.originatingAddress ?: "Unknown"
                        timestamp = sms.timestampMillis
                    }
                    fullBodyBuilder.append(sms.displayMessageBody ?: sms.messageBody ?: "")
                }
            }

            val body = fullBodyBuilder.toString()
            if (body.isEmpty()) return

            val id = "sms_${sender}_${timestamp}"

            // Clean log without printing OTP or full sensitive contents per privacy spec
            Log.i(TAG, "SMS received from sender: $sender, length: ${body.length}, subId: $subscriptionId")

            // Dispatch message to active MainActivity / Flutter gateway
            val smsMap = HashMap<String, Any?>()
            smsMap["id"] = id
            smsMap["sender"] = sender
            smsMap["body"] = body
            smsMap["receivedAt"] = java.time.Instant.ofEpochMilli(timestamp).toString()
            smsMap["subscriptionId"] = subscriptionId

            MainActivity.onSmsReceived(context, smsMap)

        } catch (e: Exception) {
            Log.e(TAG, "Error parsing incoming SMS broadcast", e)
        }
    }
}
