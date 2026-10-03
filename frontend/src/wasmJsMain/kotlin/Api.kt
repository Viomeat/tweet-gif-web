import kotlinx.coroutines.await
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlin.js.Promise

// 自定义 JS 互操作：不依赖 kotlinx-browser（其 external class 绑定在
// webpack 生产包中缺失，会导致 LinkError），全部用 @JsFun 显式声明。

@Serializable
data class ConvertRequest(val url: String)

@Serializable
data class ConvertResponse(
    val success: Boolean = false,
    val gif_url: String? = null,
    val message: String? = null,
    val error: String? = null
)

private val jsonCodec = Json { ignoreUnknownKeys = true }

@JsFun("(url, body) => window.fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: body })")
private external fun jsPostJson(url: String, body: String): Promise<JsAny?>

@JsFun("(r) => r.status")
private external fun jsRespStatus(r: JsAny?): Int

@JsFun("(r) => r.statusText")
private external fun jsRespStatusText(r: JsAny?): String

@JsFun("(r) => r.text()")
private external fun jsRespText(r: JsAny?): Promise<JsAny?>

suspend fun convertTweetToGif(tweetUrl: String): ConvertResponse {
    return try {
        val response: JsAny? = jsPostJson(
            "/api/convert",
            jsonCodec.encodeToString(ConvertRequest(url = tweetUrl))
        ).await()

        if (jsRespStatus(response).toInt() !in 200..299) {
            return ConvertResponse(
                success = false,
                error = "网络请求失败: ${jsRespStatus(response)} ${jsRespStatusText(response)}"
            )
        }

        val body: JsAny? = jsRespText(response).await()
        jsonCodec.decodeFromString<ConvertResponse>(body.toString())
    } catch (e: Exception) {
        ConvertResponse(
            success = false,
            error = "请求失败: ${e.message ?: "未知错误"}"
        )
    }
}
