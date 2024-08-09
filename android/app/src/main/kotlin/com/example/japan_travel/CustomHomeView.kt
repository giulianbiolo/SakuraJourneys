package com.example.japan_travel

import android.appwidget.AppWidgetManager
import android.content.Context
import android.app.PendingIntent
import android.content.Intent
import android.view.ViewGroup
import android.widget.TextView
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File


/**
 * Implementation of App Widget functionality.
 */
class CustomHomeView : HomeWidgetProvider() {
    override fun onUpdate(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
            widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.card_widget_layout);
            
            val cardTitle = widgetData.getString("title", "Loading...")
            val cardDistance = widgetData.getString("distance", "calculating...")
            val cardImage = widgetData.getString("imageName", null)
            val cardTextColor = widgetData.getString("textColor", "#FFFFFF")
            println("cardTitle: $cardTitle")
            println("cardDistance: $cardDistance")
            println("cardImage: $cardImage")
            println("cardTextColor: $cardTextColor")

            val lat = widgetData.getString("lat", "0.0")
            val lng = widgetData.getString("lng", "0.0")
            val intent = Intent("android.intent.action.VIEW", Uri.parse("google.navigation:q=$lat,$lng&mode=d"))
            val pendingIntentWithData = PendingIntent.getActivity(context, 0, intent, 67108864)
            views.setOnClickPendingIntent(R.id.widget_image, pendingIntentWithData)

            views.setTextViewText(R.id.widget_title, cardTitle)
            views.setTextViewText(R.id.widget_distance, cardDistance)
            views.setTextColor(R.id.widget_title, Color.parseColor(cardTextColor))
            views.setTextColor(R.id.widget_distance, Color.parseColor(cardTextColor))

            try {
                val imageFile = File(cardImage)
                val imageExists = imageFile.exists()
                if (imageExists) {
                    val myBitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
                    views.setImageViewBitmap(R.id.widget_image, Bitmap.createScaledBitmap(myBitmap, 1024, 1024, false))
                } else {
                    println("image not found!, looked @: $cardImage")
                }
            } catch (e: Exception) {
                println("error loading image: $e")
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
