package com.axis.axis

import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * Native Android HTTP updater using OS active network bindings (ConnectivityManager + HttpURLConnection).
 * Avoids Dart HttpClient connection pool / Wi-Fi proxy / stalled stream hangs on Android.
 */
internal object NativeUpdateDownloader {
    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val downloadGeneration = AtomicInteger(0)

    private const val CONNECT_TIMEOUT_MS = 15_000
    private const val CHECK_READ_TIMEOUT_MS = 15_000
    private const val DOWNLOAD_READ_TIMEOUT_MS = 20_000
    private const val MAX_REDIRECTS = 8
    private const val BUFFER_SIZE = 32 * 1024

    fun fetchJson(
        context: Context,
        urlStr: String,
        headers: Map<String, String>?,
        result: MethodChannel.Result,
    ) {
        val appCtx = context.applicationContext
        executor.execute {
            var lastError: Exception? = null
            for (attempt in 1..2) {
                val preferActiveNetwork = attempt == 1
                var conn: HttpURLConnection? = null
                try {
                    conn = openWithRedirects(
                        context = appCtx,
                        initialUrl = urlStr,
                        headers = headers,
                        readTimeoutMs = CHECK_READ_TIMEOUT_MS,
                        isBinaryDownload = false,
                        preferActiveNetwork = preferActiveNetwork,
                    )
                    val code = conn.responseCode
                    val stream = if (code in 200..299) conn.inputStream else (conn.errorStream ?: conn.inputStream)
                    val body = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
                    mainHandler.post {
                        result.success(
                            mapOf(
                                "statusCode" to code,
                                "body" to body,
                            ),
                        )
                    }
                    return@execute
                } catch (e: Exception) {
                    lastError = e
                    if (attempt < 2) {
                        try {
                            Thread.sleep(400)
                        } catch (_: InterruptedException) {}
                    }
                } finally {
                    conn?.disconnect()
                }
            }
            val msg = lastError?.localizedMessage ?: lastError?.javaClass?.simpleName ?: "Network error"
            mainHandler.post {
                result.error("NATIVE_CHECK_ERROR", msg, null)
            }
        }
    }

    fun downloadFile(
        context: Context,
        urlStr: String,
        destinationPath: String,
        expectedSize: Long,
        onProgress: (receivedBytes: Long, totalBytes: Long) -> Unit,
        result: MethodChannel.Result,
    ) {
        val appCtx = context.applicationContext
        val myGen = downloadGeneration.incrementAndGet()

        executor.execute {
            val targetFile = File(destinationPath)
            val partFile = File("$destinationPath.part")
            targetFile.parentFile?.mkdirs()

            var lastError: Exception? = null
            for (attempt in 1..2) {
                val preferActiveNetwork = attempt == 1
                var conn: HttpURLConnection? = null
                try {
                    if (partFile.exists()) {
                        partFile.delete()
                    }
                    conn = openWithRedirects(
                        context = appCtx,
                        initialUrl = urlStr,
                        headers = null,
                        readTimeoutMs = DOWNLOAD_READ_TIMEOUT_MS,
                        isBinaryDownload = true,
                        preferActiveNetwork = preferActiveNetwork,
                    )
                    val code = conn.responseCode
                    if (code !in 200..299) {
                        throw IOException("Server returned HTTP $code")
                    }

                    val headerLen = conn.getHeaderField("Content-Length")?.trim()?.toLongOrNull() ?: -1L
                    val totalBytes = if (headerLen > 0L) headerLen else expectedSize.coerceAtLeast(0L)
                    var receivedBytes = 0L
                    var lastProgressDispatch = 0L

                    BufferedInputStream(conn.inputStream, BUFFER_SIZE).use { input ->
                        FileOutputStream(partFile).use { output ->
                            val buffer = ByteArray(BUFFER_SIZE)
                            while (true) {
                                if (downloadGeneration.get() != myGen) {
                                    throw IOException("Download superseded")
                                }
                                val read = input.read(buffer)
                                if (read == -1) break
                                output.write(buffer, 0, read)
                                receivedBytes += read

                                val now = System.currentTimeMillis()
                                if (now - lastProgressDispatch >= 100L) {
                                    lastProgressDispatch = now
                                    val snapReceived = receivedBytes
                                    mainHandler.post {
                                        if (downloadGeneration.get() == myGen) {
                                            onProgress(snapReceived, totalBytes)
                                        }
                                    }
                                }
                            }
                            output.flush()
                        }
                    }

                    if (receivedBytes <= 0L) {
                        throw IOException("Downloaded package is empty (0 bytes)")
                    }
                    if (headerLen > 0L && receivedBytes < headerLen) {
                        throw IOException("Incomplete download ($receivedBytes / $headerLen bytes)")
                    }

                    if (targetFile.exists()) {
                        targetFile.delete()
                    }
                    if (!partFile.renameTo(targetFile)) {
                        partFile.copyTo(targetFile, overwrite = true)
                        partFile.delete()
                    }

                    val finalTotal = if (totalBytes > 0L) totalBytes else receivedBytes
                    mainHandler.post {
                        onProgress(receivedBytes, finalTotal)
                        result.success(
                            mapOf(
                                "path" to targetFile.absolutePath,
                                "receivedBytes" to receivedBytes,
                                "totalBytes" to finalTotal,
                            ),
                        )
                    }
                    return@execute
                } catch (e: Exception) {
                    lastError = e
                    if (partFile.exists()) {
                        partFile.delete()
                    }
                    if (downloadGeneration.get() != myGen) {
                        break
                    }
                    if (attempt < 2) {
                        try {
                            Thread.sleep(600)
                        } catch (_: InterruptedException) {}
                    }
                } finally {
                    conn?.disconnect()
                }
            }

            val msg = lastError?.localizedMessage ?: lastError?.javaClass?.simpleName ?: "Download failed"
            mainHandler.post {
                result.error("NATIVE_DOWNLOAD_ERROR", msg, null)
            }
        }
    }

    private fun openWithRedirects(
        context: Context,
        initialUrl: String,
        headers: Map<String, String>?,
        readTimeoutMs: Int,
        isBinaryDownload: Boolean,
        preferActiveNetwork: Boolean,
    ): HttpURLConnection {
        var currentUrl = initialUrl
        for (hop in 0..MAX_REDIRECTS) {
            val url = URL(currentUrl)
            if (!url.protocol.equals("https", ignoreCase = true)) {
                throw IOException("Blocked insecure non-HTTPS update URL")
            }
            val conn = openSingleConnection(context, url, preferActiveNetwork).apply {
                instanceFollowRedirects = false
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = readTimeoutMs
                useCaches = false
                requestMethod = "GET"
                setRequestProperty("User-Agent", "Axis-App-Updater")
                setRequestProperty("Connection", "close")
                if (isBinaryDownload) {
                    setRequestProperty("Accept", "*/*")
                    setRequestProperty("Accept-Encoding", "identity")
                } else {
                    setRequestProperty("Accept", "application/vnd.github.v3+json")
                    headers?.forEach { (k, v) -> setRequestProperty(k, v) }
                }
            }

            val status = conn.responseCode
            if (status == HttpURLConnection.HTTP_MOVED_PERM ||
                status == HttpURLConnection.HTTP_MOVED_TEMP ||
                status == HttpURLConnection.HTTP_SEE_OTHER ||
                status == 307 ||
                status == 308
            ) {
                val location = conn.getHeaderField("Location")
                conn.disconnect()
                if (location.isNullOrBlank()) {
                    throw IOException("Redirect HTTP $status without Location header")
                }
                currentUrl = URL(url, location).toString()
                continue
            }
            return conn
        }
        throw IOException("Too many redirects while contacting update server")
    }

    private fun openSingleConnection(
        context: Context,
        url: URL,
        preferActiveNetwork: Boolean,
    ): HttpURLConnection {
        if (preferActiveNetwork && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                val active = cm?.activeNetwork
                if (active != null) {
                    return active.openConnection(url) as HttpURLConnection
                }
            } catch (_: Throwable) {
                // Fall back to default URL socket opening
            }
        }
        return url.openConnection() as HttpURLConnection
    }
}
