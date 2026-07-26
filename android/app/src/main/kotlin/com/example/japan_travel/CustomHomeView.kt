package com.example.japan_travel

import android.appwidget.AppWidgetManager
import android.content.Context
import android.app.PendingIntent
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.graphics.Matrix
import android.net.Uri
import android.os.Bundle
import android.util.DisplayMetrics
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import kotlin.math.roundToInt


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
            val cardTitle = widgetData.getString("title", "Loading...")
            val cardDistance = widgetData.getString("distance", "calculating...")
            val cardImage = widgetData.getString("imageName", null)
            val lat = widgetData.getString("lat", "")
            val lng = widgetData.getString("lng", "")
            println("cardTitle: $cardTitle")
            println("cardDistance: $cardDistance")
            println("cardImage: $cardImage")

            // ? Empty deck: Dart clears lat/lng/imageName, and navigating to (0, 0)
            // ? would be worse than useless, so the tap opens the app instead.
            val hasCard = !lat.isNullOrBlank() && !lng.isNullOrBlank()
            val clickIntent = if (hasCard) {
                Intent("android.intent.action.VIEW",
                        Uri.parse("google.navigation:q=$lat,$lng&mode=d"))
            } else {
                Intent(context, MainActivity::class.java)
            }
            val pendingIntentWithData = PendingIntent.getActivity(
                    context, 0, clickIntent, 67108864) // ? FLAG_IMMUTABLE

            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val metrics = context.resources.displayMetrics
            val portraitSize = targetSize(options, true, metrics)
            val landscapeSize = targetSize(options, false, metrics)

            var portraitBitmap: Bitmap? = null
            var landscapeBitmap: Bitmap? = null
            try {
                val imageFile = if (cardImage.isNullOrBlank()) null else File(cardImage)
                if (imageFile == null) {
                    println("no image for this update, drawing the plain background")
                } else if (!imageFile.exists()) {
                    println("image not found!, looked @: $cardImage")
                } else {
                    // ? Decoded once at the coarsest sampling both boxes can live with,
                    // ? then cropped twice: the file is stored at full resolution and
                    // ? decoding it whole can allocate tens of MB in a broadcast receiver.
                    val decoded = decodeSampled(imageFile,
                            maxOf(portraitSize.first, landscapeSize.first),
                            maxOf(portraitSize.second, landscapeSize.second))
                    if (decoded == null) {
                        println("could not decode image @: $cardImage")
                    } else {
                        portraitBitmap = cropScale(decoded, portraitSize.first, portraitSize.second)
                        landscapeBitmap = cropScale(decoded, landscapeSize.first, landscapeSize.second)
                        if (decoded !== portraitBitmap && decoded !== landscapeBitmap) {
                            decoded.recycle()
                        }
                    }
                }
            } catch (e: Exception) {
                println("error loading image: $e")
            }

            // ? One tree per orientation. The host swaps between them on rotation on its
            // ? own, with no broadcast to re-render in, so a single bitmap sized for the
            // ? current box is the one thing centerCrop cannot fix afterwards.
            val portraitViews = buildViews(context, pendingIntentWithData, cardTitle,
                    cardDistance, portraitBitmap)
            val landscapeViews = buildViews(context, pendingIntentWithData, cardTitle,
                    cardDistance, landscapeBitmap)
            appWidgetManager.updateAppWidget(appWidgetId,
                    RemoteViews(landscapeViews, portraitViews))
        }
    }

    // ? Re-render when the user resizes the widget: the bitmaps above are cut to the
    // ? box reported at update time, and nothing else would ask for new ones before
    // ? the next workmanager pass.
    override fun onAppWidgetOptionsChanged(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    private fun buildViews(
            context: Context,
            clickIntent: PendingIntent,
            title: String?,
            distance: String?,
            image: Bitmap?
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.card_widget_layout)
        views.setOnClickPendingIntent(R.id.widget_image, clickIntent)
        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_distance, distance)
        if (image != null) {
            views.setImageViewBitmap(R.id.widget_image, image)
        } else {
            views.setImageViewResource(R.id.widget_image, R.drawable.widget_background)
        }
        return views
    }

    // ? The host reports both orientations as one range, so MAX x MAX is the landscape
    // ? box and not the widget: the pairing is (MIN_WIDTH, MAX_HEIGHT) in portrait and
    // ? (MAX_WIDTH, MIN_HEIGHT) in landscape.
    private fun targetSize(
            options: Bundle,
            portrait: Boolean,
            metrics: DisplayMetrics
    ): Pair<Int, Int> {
        val widthDp = options.getInt(
                if (portrait) AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH
                else AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH)
        val heightDp = options.getInt(
                if (portrait) AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT
                else AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
        val fallbackWidth = if (portrait) minOf(metrics.widthPixels, metrics.heightPixels)
                            else maxOf(metrics.widthPixels, metrics.heightPixels)
        val width = if (widthDp > 0) (widthDp * metrics.density).toInt() else fallbackWidth
        val height = if (heightDp > 0) (heightDp * metrics.density).toInt() else fallbackWidth / 2
        return Pair(maxOf(width, 1), maxOf(height, 1))
    }

    private fun decodeSampled(file: File, targetWidth: Int, targetHeight: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sample = 1
        while (bounds.outWidth / (sample * 2) >= targetWidth &&
                bounds.outHeight / (sample * 2) >= targetHeight) {
            sample *= 2
        }
        return BitmapFactory.decodeFile(
                file.absolutePath,
                BitmapFactory.Options().apply { inSampleSize = sample }
        )
    }

    // ? widget_image is centerCrop, so cutting the crop here is invisible, but it keeps
    // ? the bitmap at the box's size. Covering a wide box with a tall source by scale
    // ? alone overshoots in height: 1323x1654 (8.8 MB) for a 1323x360 box.
    private fun cropScale(source: Bitmap, targetWidth: Int, targetHeight: Int): Bitmap {
        val aspect = targetWidth.toFloat() / targetHeight
        var cropWidth = source.width
        var cropHeight = (cropWidth / aspect).roundToInt()
        if (cropHeight > source.height) {
            cropHeight = source.height
            cropWidth = (cropHeight * aspect).roundToInt()
        }
        cropWidth = cropWidth.coerceIn(1, source.width)
        cropHeight = cropHeight.coerceIn(1, source.height)

        val matrix = Matrix()
        val scale = minOf(targetWidth.toFloat() / cropWidth, targetHeight.toFloat() / cropHeight)
        if (scale < 1f) matrix.setScale(scale, scale)
        return Bitmap.createBitmap(source, (source.width - cropWidth) / 2,
                (source.height - cropHeight) / 2, cropWidth, cropHeight, matrix, true)
    }
}
