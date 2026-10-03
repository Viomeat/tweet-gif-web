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
    var url by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var resultGifUrl by remember { mutableStateOf<String?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var successMessage by remember { mutableStateOf<String?>(null) }

    val scope = rememberCoroutineScope()

    AppTheme {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            PrimaryColor,
                            BackgroundColor
                        )
                    )
                )
        ) {
            Scaffold(
                containerColor = Color.Transparent,
                topBar = {
                    TopAppBar(
                        title = { Text("推文 GIF 转换器") },
                        colors = TopAppBarDefaults.topAppBarColors(
                            containerColor = Color.Transparent
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
                        colors = CardDefaults.cardColors(
                            containerColor = SurfaceColor.copy(alpha = 0.95f)
                        )
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Text(
                                text = "输入推文链接",
                                style = MaterialTheme.typography.titleLarge,
                                color = OnBackgroundColor
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
                                enabled = url.isNotBlank() && !isLoading,
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = PrimaryColor,
                                    contentColor = OnPrimaryColor
                                )
                            ) {
                                Text(if (isLoading) "转换中..." else "转换为 GIF")
                            }
                        }
                    }

                    // 加载指示器
                    if (isLoading) {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(
                                containerColor = SurfaceColor.copy(alpha = 0.95f)
                            )
                        ) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(24.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                CircularProgressIndicator(color = PrimaryColor)
                                Text(
                                    text = "正在处理中，请稍候...",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = OnBackgroundColor.copy(alpha = 0.7f)
                                )
                            }
                        }
                    }

                    // 错误消息
                    errorMessage?.let { error ->
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(
                                containerColor = Color(0xFFFFDAD6).copy(alpha = 0.95f)
                            )
                        ) {
                            Column(
                                modifier = Modifier.padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(
                                    text = "❌ 错误",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.SemiBold,
                                    color = Color(0xFFBA1A1A)
                                )
                                Text(
                                    text = error,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = Color(0xFF410002)
                                )
                            }
                        }
                    }

                    // 成功消息和结果
                    resultGifUrl?.let { gifUrl ->
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(
                                containerColor = Color(0xFFD4F7DC).copy(alpha = 0.95f)
                            )
                        ) {
                            Column(
                                modifier = Modifier.padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(
                                    text = "✅ ${successMessage ?: "转换成功"}",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.SemiBold,
                                    color = Color(0xFF1B5E20)
                                )
                            }
                        }

                        // GIF 预览卡片
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(
                                containerColor = SurfaceColor.copy(alpha = 0.95f)
                            )
                        ) {
                            Column(
                                modifier = Modifier.padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(12.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = "GIF 预览",
                                    style = MaterialTheme.typography.titleLarge,
                                    color = OnBackgroundColor
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
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = PrimaryColor,
                                        contentColor = OnPrimaryColor
                                    )
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
        text = "🎬 GIF 已生成",
        style = MaterialTheme.typography.bodyMedium,
        color = PrimaryColor
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
