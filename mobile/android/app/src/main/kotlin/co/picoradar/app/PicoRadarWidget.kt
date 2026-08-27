package co.picoradar.app

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider

class PicoRadarWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs = context.getSharedPreferences("picoradar_widget", Context.MODE_PRIVATE)
        val state = WidgetState(
            configured = prefs.getBoolean("configured", false),
            hasVehicle = prefs.getBoolean("hasVehicle", false),
            plate = prefs.getString("plate", "").orEmpty(),
            vehicleLabel = prefs.getString("vehicleLabel", "").orEmpty(),
            jurisdictionName = prefs.getString("jurisdictionName", "").orEmpty(),
        )
        provideContent {
            PicoWidgetContent(context, state)
        }
    }
}

class PicoRadarWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = PicoRadarWidget()
}

private data class WidgetState(
    val configured: Boolean,
    val hasVehicle: Boolean,
    val plate: String,
    val vehicleLabel: String,
    val jurisdictionName: String,
)

@Composable
private fun PicoWidgetContent(context: Context, state: WidgetState) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(Color(0xFFFFFFFF)))
            .clickable(actionStartActivity(MainActivity.picoIntent(context)))
            .padding(14.dp),
        verticalAlignment = Alignment.Vertical.CenterVertically,
    ) {
        Text(
            text = "PicoRadar",
            style = TextStyle(
                color = ColorProvider(Color(0xFF17324D)),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
            ),
        )
        Spacer(GlanceModifier.height(6.dp))
        Text(
            text = when {
                !state.hasVehicle -> "Agrega tu vehículo para comenzar"
                !state.configured -> "Selecciona tu ciudad en la app"
                else -> "${state.plate} · ${state.vehicleLabel}"
            },
            style = TextStyle(color = ColorProvider(Color(0xFF17324D)), fontSize = 14.sp),
        )
        if (state.configured) {
            Text(
                text = state.jurisdictionName,
                style = TextStyle(color = ColorProvider(Color(0xFF52616F)), fontSize = 13.sp),
            )
        }
        Spacer(GlanceModifier.height(8.dp))
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            Text(
                text = "Consulta tu Pico y Placa de hoy",
                style = TextStyle(color = ColorProvider(Color(0xFF2F6FED)), fontSize = 13.sp),
            )
            Spacer(GlanceModifier.size(1.dp))
        }
    }
}
