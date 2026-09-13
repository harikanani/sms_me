package com.example.sms_me

import android.content.Context
import com.example.sms_me.flutter.SmsMethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private var activeMethodChannel: MethodChannel? = null

        fun onSmsReceived(context: Context, smsMap: Map<String, Any?>) {
            val channel = activeMethodChannel
            if (channel != null) {
                channel.invokeMethod("onSmsReceived", smsMap)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SmsMethodChannel.CHANNEL)
        channel.setMethodCallHandler(SmsMethodChannel(this))
        activeMethodChannel = channel
    }

    override fun onDestroy() {
        super.onDestroy()
        activeMethodChannel = null
    }
}
