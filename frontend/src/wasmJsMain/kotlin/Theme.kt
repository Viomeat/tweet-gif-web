@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class,
            androidx.compose.ui.ExperimentalComposeUiApi::class)

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import com.tweetgif.tweet_gif_frontend.generated.resources.Res
import com.tweetgif.tweet_gif_frontend.generated.resources.notosanssc
import org.jetbrains.compose.resources.Font

// 配色方案：主色调 #89ABE3，背景色 #F7F4ED
val PrimaryColor = Color(0xFF89ABE3)
val BackgroundColor = Color(0xFFF7F4ED)
val SurfaceColor = Color(0xFFFFFBF5)
val OnPrimaryColor = Color(0xFFFFFFFF)
val OnBackgroundColor = Color(0xFF1C1B1F)

// 内嵌的中文字体（Noto Sans SC 子集），否则 wasm 默认字体渲染中文为方块
private fun appTypography(base: Typography, family: FontFamily): Typography = base.copy(
    displayLarge = base.displayLarge.copy(fontFamily = family),
    displayMedium = base.displayMedium.copy(fontFamily = family),
    displaySmall = base.displaySmall.copy(fontFamily = family),
    headlineLarge = base.headlineLarge.copy(fontFamily = family),
    headlineMedium = base.headlineMedium.copy(fontFamily = family),
    headlineSmall = base.headlineSmall.copy(fontFamily = family),
    titleLarge = base.titleLarge.copy(fontFamily = family),
    titleMedium = base.titleMedium.copy(fontFamily = family),
    titleSmall = base.titleSmall.copy(fontFamily = family),
    bodyLarge = base.bodyLarge.copy(fontFamily = family),
    bodyMedium = base.bodyMedium.copy(fontFamily = family),
    bodySmall = base.bodySmall.copy(fontFamily = family),
    labelLarge = base.labelLarge.copy(fontFamily = family),
    labelMedium = base.labelMedium.copy(fontFamily = family),
    labelSmall = base.labelSmall.copy(fontFamily = family)
)

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    val family = FontFamily(Font(Res.font.notosanssc))
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
        typography = appTypography(Typography(), family),
        content = content
    )
}
