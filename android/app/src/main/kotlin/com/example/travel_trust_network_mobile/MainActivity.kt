package com.example.travel_trust_network_mobile

import io.flutter.embedding.android.FlutterActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "ttn_social", "Bạn bè và tin nhắn", NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Lời mời kết bạn và tin nhắn mới"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
