import kotlinx.browser.window
import kotlinx.coroutines.await
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.w3c.fetch.Headers
import org.w3c.fetch.RequestInit
import org.w3c.fetch.Response
import kotlin.js.JsString
import kotlin.js.toJsString

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

suspend fun convertTweetToGif(tweetUrl: String): ConvertResponse {
    return try {
        val headers = Headers()
        headers.append("Content-Type", "application/json")
        val init = RequestInit(
            method = "POST",
            headers = headers,
            body = jsonCodec.encodeToString(ConvertRequest(url = tweetUrl)).toJsString()
        )

        val response: Response = window.fetch("/api/convert", init).await()

        if (response.status.toInt() !in 200..299) {
            return ConvertResponse(
                success = false,
                error = "网络请求失败: ${response.status} ${response.statusText}"
            )
        }

        val bodyText: JsString = response.text().await()
        jsonCodec.decodeFromString<ConvertResponse>(bodyText.toString())
    } catch (e: Exception) {
        ConvertResponse(
            success = false,
            error = "请求失败: ${e.message ?: "未知错误"}"
        )
    }
}
