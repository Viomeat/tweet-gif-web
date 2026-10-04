import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import com.tweetgif.tweet_gif_frontend.generated.resources.Res
import com.tweetgif.tweet_gif_frontend.generated.resources.notosanssc
import com.tweetgif.tweet_gif_frontend.generated.resources.pingfangsc_medium
import com.tweetgif.tweet_gif_frontend.generated.resources.pingfangsc_regular
import kotlin.js.Promise
import kotlinx.coroutines.await
import org.jetbrains.compose.resources.Font

// ---------- 主题偏好（localStorage 持久化） ----------
const val LIGHT_BACKGROUND_HEX = "#F7F4ED" // 与 index.html 防闪脚本保持同步
const val DARK_BACKGROUND_HEX = "#121316"

private const val THEME_STORAGE_KEY = "tweetgif-theme"

enum class ThemePref(val storageValue: String) {
    LIGHT("light"), DARK("dark"), SYSTEM("system");

    companion object {
        fun fromStorage(raw: String?): ThemePref = when (raw?.trim()?.lowercase()) {
            "light" -> LIGHT
            "dark" -> DARK
            else -> SYSTEM
        }
    }
}

fun readThemePref(): ThemePref =
    ThemePref.fromStorage(jsReadStorage(THEME_STORAGE_KEY).takeIf { it.isNotBlank() })

fun writeThemePref(pref: ThemePref) {
    jsWriteStorage(THEME_STORAGE_KEY, pref.storageValue)
}

/** 系统深色模式，带 matchMedia 实时监听（用户未手动覆盖时 UI 自动跟随）。 */
@Composable
fun rememberSystemDark(): State<Boolean> {
    val state = remember { mutableStateOf(jsReadPrefersDark()) }
    DisposableEffect(Unit) {
        jsWatchPrefersDark { state.value = it }
        onDispose { jsUnwatchPrefersDark() }
    }
    return state
}

// ---------- 浏览器互操作（项目约定：不依赖 kotlinx-browser，全部手写 @JsFun） ----------

@JsFun("(key) => { try { return localStorage.getItem(key) || ''; } catch (e) { return ''; } }")
private external fun jsReadStorage(key: String): String

@JsFun("(key, value) => { try { localStorage.setItem(key, value); } catch (e) {} }")
private external fun jsWriteStorage(key: String, value: String)

@JsFun("() => window.matchMedia('(prefers-color-scheme: dark)').matches")
private external fun jsReadPrefersDark(): Boolean

@JsFun("(cb) => { var m = window.matchMedia('(prefers-color-scheme: dark)'); var h = function (e) { cb(e.matches); }; window.__tgDarkWatch = h; m.addEventListener('change', h); }")
private external fun jsWatchPrefersDark(cb: (Boolean) -> Unit)

@JsFun("() => { var h = window.__tgDarkWatch; if (h) { window.matchMedia('(prefers-color-scheme: dark)').removeEventListener('change', h); window.__tgDarkWatch = null; } }")
private external fun jsUnwatchPrefersDark()

@JsFun("(dark, hex) => { document.documentElement.style.backgroundColor = hex; document.body.style.backgroundColor = hex; document.documentElement.style.colorScheme = dark ? 'dark' : 'light'; }")
private external fun jsApplyPageBackground(dark: Boolean, hex: String)

// ---------- 色板 ----------
// 所有文字/表面对比度均 >= 4.5:1（边框 >= 3:1），经脚本逐对验证。

private fun lightScheme(): ColorScheme = lightColorScheme(
    primary = Color(0xFF3E5C8C), // 品牌蓝加深，保证 onPrimary 浅字达标
    onPrimary = Color(0xFFFFFBF5),
    primaryContainer = Color(0xFFC9D9F2),
    onPrimaryContainer = Color(0xFF16304F),
    secondary = Color(0xFF89ABE3), // 原品牌蓝，保留品牌观感
    onSecondary = Color(0xFF16304F),
    secondaryContainer = Color(0xFFDEE9F8),
    onSecondaryContainer = Color(0xFF16304F),
    tertiary = Color(0xFF2E6B3E),
    onTertiary = Color(0xFFFFFBF5),
    tertiaryContainer = Color(0xFFC9EFD0),
    onTertiaryContainer = Color(0xFF175A20),
    background = Color(0xFFF7F4ED),
    onBackground = Color(0xFF1C1B1F),
    surface = Color(0xFFFFFBF5),
    onSurface = Color(0xFF1C1B1F),
    surfaceVariant = Color(0xFFEDE8DE),
    onSurfaceVariant = Color(0xFF4A4740),
    outline = Color(0xFF79747E),
    outlineVariant = Color(0xFFCAC4D0),
    error = Color(0xFFBA1A1A),
    onError = Color(0xFFFFFBF5),
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002)
)

private fun darkScheme(): ColorScheme = darkColorScheme(
    primary = Color(0xFFA8C1E3), // 品牌色相 217° 保留，饱和度降 ~18%、明度提高
    onPrimary = Color(0xFF16233B),
    primaryContainer = Color(0xFF2C4266),
    onPrimaryContainer = Color(0xFFD2E0F5),
    secondary = Color(0xFF8FA9CE),
    onSecondary = Color(0xFF16233B),
    secondaryContainer = Color(0xFF333F58),
    onSecondaryContainer = Color(0xFFD2E0F5),
    tertiary = Color(0xFF7FBF8E),
    onTertiary = Color(0xFF0E2A15),
    tertiaryContainer = Color(0xFF1F3D28),
    onTertiaryContainer = Color(0xFFA5D8B0),
    background = Color(0xFF121316),
    onBackground = Color(0xFFE4E4E7),
    surface = Color(0xFF1D1F25), // 高程逐层提亮：background < surface < surfaceVariant
    onSurface = Color(0xFFEAEAEC),
    surfaceVariant = Color(0xFF2A2C34),
    onSurfaceVariant = Color(0xFFA6ABB5),
    outline = Color(0xFF8C93A4),
    outlineVariant = Color(0xFF3A3D46),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF410002),
    errorContainer = Color(0xFF5C1A15),
    onErrorContainer = Color(0xFFFFDAD6)
)

// ---------- 字体 ----------
// 主字体 PingFang SC（GB2312+ASCII 子集，Regular/Medium 两个真实字重）。
//
// 兜底说明：CMP 1.7 没有 TextStyle.fontFamilyFallback（1.8 起才有），且实测
// 同一 FontFamily 内的多个 Font 不做逐字符缺字回退（缺字渲染为空白/tofu）。
// 因此在启动时探测 woff2 文件完整性（HTTP 200 + 'wOF2' 魔数 + 最小体积），
// 异常时整体切换到内嵌的 notosanssc.ttf 字族，保证永不出现方块。
private const val FONT_RESOURCE_DIR =
    "./composeResources/com.tweetgif.tweet_gif_frontend.generated.resources/font/"

// 子集后的 PingFang woff2 约 1.2MB，低于该阈值视为文件损坏/被截断
private const val MIN_FONT_BYTES = 1_000_000

// 返回 "HTTP状态:字节数:魔数"，如 "200:1180336:wOF2"
@JsFun("(path) => fetch(path).then(function (r) { return r.arrayBuffer().then(function (b) { var h = new Uint8Array(b, 0, 4); return r.status + ':' + b.byteLength + ':' + String.fromCharCode(h[0], h[1], h[2], h[3]); }); }).catch(function () { return 'ERR'; })")
private external fun jsProbeFont(path: String): Promise<JsAny?>

private suspend fun probeFont(path: String): Boolean = try {
    val probeResult: JsAny? = jsProbeFont(path).await()
    val parts = probeResult.toString().split(':')
    parts.size == 3 && parts[0] == "200" &&
        (parts[1].toIntOrNull() ?: 0) >= MIN_FONT_BYTES && parts[2] == "wOF2"
} catch (e: Exception) {
    false
}

/** PingFang woff2 是否可用；探测完成前乐观假定可用（preload 已预热缓存）。 */
@Composable
private fun rememberPingFangHealthy(): State<Boolean> {
    val state = remember { mutableStateOf(true) }
    LaunchedEffect(Unit) {
        state.value = probeFont(FONT_RESOURCE_DIR + "pingfangsc_regular.woff2") &&
            probeFont(FONT_RESOURCE_DIR + "pingfangsc_medium.woff2")
    }
    return state
}

// Font() 是 @Composable（无法提升为顶层 val），用 remember 避免重组时重建。
// Noto 字族只在 PingFang 不可用时才构建/加载（2.2MB TTF 按需加载）。
@Composable
private fun rememberPingFangFamily(): FontFamily {
    val regular = Font(Res.font.pingfangsc_regular, FontWeight.Normal)
    val medium = Font(Res.font.pingfangsc_medium, FontWeight.Medium)
    return remember(regular, medium) { FontFamily(regular, medium) }
}

@Composable
private fun rememberNotoFallbackFamily(): FontFamily {
    val noto = Font(Res.font.notosanssc, FontWeight.Normal)
    return remember(noto) { FontFamily(noto) }
}

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
fun AppTheme(
    darkTheme: Boolean,
    content: @Composable () -> Unit
) {
    // wasm 首帧前后都让 html/body 背景与主题一致，避免切换/回弹时露出旧底色
    DisposableEffect(darkTheme) {
        jsApplyPageBackground(darkTheme, if (darkTheme) DARK_BACKGROUND_HEX else LIGHT_BACKGROUND_HEX)
        onDispose { }
    }

    val pingFangHealthy = rememberPingFangHealthy()
    val family = if (pingFangHealthy.value) {
        rememberPingFangFamily()
    } else {
        rememberNotoFallbackFamily()
    }
    val typography = remember(family) { appTypography(Typography(), family) }

    MaterialTheme(
        colorScheme = if (darkTheme) darkScheme() else lightScheme(),
        typography = typography,
        content = content
    )
}
