package com.example.travel_trust_network_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class LocketWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.locket_widget)
            val path = widgetData.getString("locket_image_path", null)
            if (path != null) {
                // Thu nhỏ ~600px để không vượt giới hạn bộ nhớ của RemoteViews
                val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(path, opts)
                var sample = 1
                while (opts.outWidth / sample > 1200) sample *= 2
                val bmp = BitmapFactory.decodeFile(
                    path, BitmapFactory.Options().apply { inSampleSize = sample }
                )
                if (bmp != null) views.setImageViewBitmap(R.id.widget_image, bmp)
            }
            val sender = widgetData.getString("locket_sender", "") ?: ""
            val caption = widgetData.getString("locket_caption", "") ?: ""
            views.setTextViewText(R.id.widget_text, if (caption.isEmpty()) sender else "$sender: $caption")
            views.setViewVisibility(R.id.widget_text, if (sender.isEmpty()) View.GONE else View.VISIBLE)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
