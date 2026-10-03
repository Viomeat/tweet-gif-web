import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// 配色方案：主色调 #89ABE3，背景色 #F7F4ED
val PrimaryColor = Color(0xFF89ABE3)
val BackgroundColor = Color(0xFFF7F4ED)
val SurfaceColor = Color(0xFFFFFBF5)
val OnPrimaryColor = Color(0xFFFFFFFF)
val OnBackgroundColor = Color(0xFF1C1B1F)

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    val colorScheme = lightColorScheme(
        primary = PrimaryColor,
        onPrimary = OnPrimaryColor,
        primaryContainer = PrimaryColor.copy(alpha = 0.2f),
        onPrimaryContainer = PrimaryColor,
        secondary = PrimaryColor.copy(alpha = 0.7f),
        onSecondary = OnPrimaryColor,
        secondaryContainer = PrimaryColor.copy(alpha = 0.15f),
        onSecondaryContainer = PrimaryColor,
        background = BackgroundColor,
        onBackground = OnBackgroundColor,
        surface = SurfaceColor,
        onSurface = OnBackgroundColor,
        surfaceVariant = BackgroundColor.copy(alpha = 0.9f),
        onSurfaceVariant = OnBackgroundColor.copy(alpha = 0.7f),
        error = Color(0xFFBA1A1A),
        onError = Color(0xFFFFFFFF),
        errorContainer = Color(0xFFFFDAD6),
        onErrorContainer = Color(0xFF410002),
        outline = Color(0xFF79747E),
        outlineVariant = Color(0xFFCAC4D0)
    )

    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}
