package com.acefuel.loyalty

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import coil.ImageLoader
import coil.ImageLoaderFactory
import com.acefuel.loyalty.core.di.ServiceContainer

class AceFuelApp : Application(), ImageLoaderFactory {
    lateinit var container: ServiceContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = ServiceContainer(this)
        // Firebase is auto-initialized by the google-services plugin from
        // app/google-services.json (Android app 1:629935221011:android:…).
        createNotificationChannel()
    }

    // Coil's singleton loader reuses the authenticated OkHttp client so KYC
    // thumbnails (behind the admin API host) load with the same bearer token,
    // logging and connection pool as every other call.
    override fun newImageLoader(): ImageLoader =
        ImageLoader.Builder(this)
            .okHttpClient { container.okHttpClient }
            .build()

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            PUSH_CHANNEL_ID,
            "Loyalty Alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = "Broadcast notifications from Ace Fuel Loyalty" }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        const val PUSH_CHANNEL_ID = "fuel_loyalty_broadcast"
    }
}
