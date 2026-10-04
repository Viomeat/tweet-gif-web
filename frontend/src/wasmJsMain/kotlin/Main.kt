@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class,
            androidx.compose.ui.ExperimentalComposeUiApi::class)

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.ComposeViewport
import kotlinx.coroutines.launch

@Composable
fun App() {
    var themePref by remember { mutableStateOf(readThemePref()) }
    val systemDark by rememberSystemDark()
    val darkTheme = when (themePref) {
        ThemePref.LIGHT -> false
        ThemePref.DARK -> true
        ThemePref.SYSTEM -> systemDark
    }

    var url by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var resultGifUrl by remember { mutableStateOf<String?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var successMessage by remember { mutableStateOf<String?>(null) }

    val scope = rememberCoroutineScope()

    AppTheme(darkTheme = darkTheme) {
        val colors = MaterialTheme.colorScheme

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            colors.primaryContainer,
                            colors.background
                        )
                    )
                )
        ) {
            Scaffold(
                containerColor = Color.Transparent,
                topBar = {
                    TopAppBar(
                        title = { Text("推文 GIF 转换器") },
                        actions = {
                            TextButton(
                                onClick = {
                                    val next = if (darkTheme) ThemePref.LIGHT else ThemePref.DARK
                                    themePref = next
                                    writeThemePref(next)
                                },
                                colors = ButtonDefaults.textButtonColors(
                                    contentColor = colors.onBackground
                                )
                            ) {
                                Text(if (darkTheme) "浅色" else "深色")
                            }
                        },
                        colors = TopAppBarDefaults.topAppBarColors(
                            containerColor = Color.Transparent,
                            titleContentColor = colors.onBackground,
                            actionIconContentColor = colors.onBackground
                        )
                    )
                }
            ) { padding ->
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .padding(horizontal = 16.dp)
                        .verticalScroll(rememberScrollState()),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Spacer(modifier = Modifier.height(8.dp))

                    // 输入卡片
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = colors.surface)
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Text(
                                text = "输入推文链接",
                                style = MaterialTheme.typography.titleLarge,
                                color = colors.onSurface
                            )

                            OutlinedTextField(
                                value = url,
                                onValueChange = { url = it },
                                label = { Text("支持 x.com, twitter.com, vxtwitter.com 等") },
                                modifier = Modifier.fillMaxWidth(),
                                enabled = !isLoading
                            )

                            Button(
                                onClick = {
                                    if (url.isNotBlank() && !isLoading) {
                                        isLoading = true
                                        errorMessage = null
                                        successMessage = null
                                        resultGifUrl = null

                                        scope.launch {
                                            val result = convertTweetToGif(url)
                                            isLoading = false

                                            if (result.success) {
                                                resultGifUrl = result.gif_url
                                                successMessage = result.message ?: "转换成功！"
                                            } else {
                                                errorMessage = result.error ?: "转换失败，请重试"
                                            }
                                        }
                                    }
                                },
                                modifier = Modifier.fillMaxWidth(),
                                enabled = url.isNotBlank() && !isLoading
                            ) {
                                Text(if (isLoading) "转换中..." else "转换为 GIF")
                            }
                        }
                    }

                    // 加载指示器
                    if (isLoading) {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(containerColor = colors.surface)
                        ) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(24.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                CircularProgressIndicator(color = colors.primary)
                                Text(
                                    text = "正在处理中，请稍候...",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = colors.onSurfaceVariant
                                )
                            }
                        }
                    }

                    // 错误消息
                    errorMessage?.let { error ->
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(containerColor = colors.errorContainer)
                        ) {
                            Column(
                                modifier = Modifier.padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(
                                    // 字体子集为 GB2312，❌/✅/🎬 等 emoji 无字形会渲染为空白
                                    text = "错误",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.SemiBold,
                                    color = colors.error
                                )
                                Text(
                                    text = error,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = colors.onErrorContainer
                                )
                            }
                        }
                    }

                    // 成功消息和结果
                    resultGifUrl?.let { gifUrl ->
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(containerColor = colors.tertiaryContainer)
                        ) {
                            Column(
                                modifier = Modifier.padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(
                                    text = successMessage ?: "转换成功",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.SemiBold,
                                    color = colors.onTertiaryContainer
                                )
                            }
                        }

                        // GIF 预览卡片
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(containerColor = colors.surface)
                        ) {
                            Column(
                                modifier = Modifier.padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(12.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = "GIF 预览",
                                    style = MaterialTheme.typography.titleLarge,
                                    color = colors.onSurface
                                )

                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(300.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    GifImage(gifUrl)
                                }

                                Button(
                                    onClick = {
                                        jsOpenNewTab(gifUrl)
                                    },
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Text("下载 GIF")
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))
                }
            }
        }
    }
}

@Composable
fun GifImage(url: String) {
    Text(
        text = "GIF 已生成",
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.primary
    )
}

fun main() {
    ComposeViewport("compose") {
        App()
    }
}

// 自定义 JS 互操作（替代 kotlinx.browser）
@JsFun("(url) => window.open(url, '_blank')")
private external fun jsOpenNewTab(url: String)
