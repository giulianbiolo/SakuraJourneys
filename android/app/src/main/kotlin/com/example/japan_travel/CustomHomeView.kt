package com.example.japan_travel

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Bitmap
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
            val views = RemoteViews(context.packageName, R.layout.card_widget_layout).apply {
                val cardTitle = widgetData.getString("title", null)
                val cardDistance = widgetData.getString("distance", null)
                val cardImage = widgetData.getString("imageName", null)
                println("cardTitle: $cardTitle")
                println("cardDistance: $cardDistance")
                println("cardImage: $cardImage")

                setTextViewText(R.id.widget_title, cardTitle)
                setTextViewText(R.id.widget_distance, cardDistance)

                val imageFile = File(cardImage)
                val imageExists = imageFile.exists()
                if (imageExists) {
                    val myBitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
                    setImageViewBitmap(R.id.widget_image, Bitmap.createScaledBitmap(myBitmap, 1024, 1024, false))
                } else {
                    println("image not found!, looked @: $cardImage")
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
