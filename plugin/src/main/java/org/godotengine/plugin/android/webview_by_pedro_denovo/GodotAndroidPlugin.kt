package org.godotengine.plugin.android.webview_by_pedro_denovo

import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.print.PrintAttributes
import android.print.PrintManager
import android.view.MotionEvent
import android.view.View
import android.webkit.*
import android.widget.FrameLayout
import org.godotengine.godot.Godot
import org.godotengine.godot.Dictionary
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class GodotAndroidPlugin(godot: Godot) : GodotPlugin(godot) {

    private var webView: PassthroughWebView? = null
    private var messagePort: WebMessagePort? = null
    private val layout: FrameLayout by lazy {
        activity!!.findViewById<FrameLayout>(android.R.id.content)
    }

    // A classe PassthroughWebView pode ser movida para seu próprio arquivo .kt
    inner class PassthroughWebView(context: Context) : WebView(context) {

    // Constantes para corresponder aos enums MouseFilter do Godot
    private val MOUSE_FILTER_STOP = 0
    private val MOUSE_FILTER_PASS = 1
    private val MOUSE_FILTER_IGNORE = 2

    // Propriedade para armazenar o modo atual, vindo da Godot. Padrão é STOP.
    var mouseFilterMode: Int = MOUSE_FILTER_STOP

    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        // --- NOVA LÓGICA DE DECISÃO ---

        // 1. Verificação Primária: O modo do Godot é STOP?
        if (mouseFilterMode == MOUSE_FILTER_STOP) {
            // Se for STOP, o WebView SEMPRE consome o evento. Fim da história.
            return super.dispatchTouchEvent(ev)
        }

        // 2. Se o modo for PASS ou IGNORE, o toque PODE passar.
        //    Agora verificamos se o toque foi em um elemento interativo do HTML.
        val result = this.hitTestResult
        val isTouchOnNonInteractiveElement = result.type == HitTestResult.UNKNOWN_TYPE
        
        if (isTouchOnNonInteractiveElement) {
            // A área é transparente/não-interativa.
            // Como o modo não é STOP, deixamos o toque passar para a Godot.
            return false 
        } else {
            // A área tem um elemento HTML interativo (botão, link, etc.).
            // O WebView deve processar o toque.
            return super.dispatchTouchEvent(ev)
        }
    }
}

    override fun getPluginName() = "godot_awv"

    override fun getPluginSignals() = mutableSetOf(
        SignalInfo("page_loaded", String::class.java),
        SignalInfo("ipc_message", String::class.java),
        SignalInfo("eval_result", String::class.java)
    )

    @UsedByGodot
    fun initialize(initialSettings: Dictionary) {
        runOnUiThread {
            if (webView == null) {
                webView = PassthroughWebView(activity!!).apply {
                    layoutParams = FrameLayout.LayoutParams(0, 0)
                    
                    settings.javaScriptEnabled = true
                    settings.domStorageEnabled = true

                    val transparent = initialSettings["transparent"] as? Boolean ?: false
                    if (transparent) {
                        setBackgroundColor(Color.TRANSPARENT)
                    } else {
                        val bgColor = initialSettings["background_color"] as? String ?: "#ffffff00"
                        setBackgroundColor(Color.TRANSPARENT)
                    }
                    
                    settings.mediaPlaybackRequiresUserGesture = !(initialSettings["autoplay"] as? Boolean ?: false)
                    (initialSettings["user_agent"] as? String)?.let { settings.userAgentString = it }
                    
                    if (initialSettings["incognito"] as? Boolean ?: false) {
                        settings.cacheMode = WebSettings.LOAD_NO_CACHE
                        settings.databaseEnabled = false
                        settings.domStorageEnabled = false
                        CookieManager.getInstance().setAcceptCookie(false)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                        WebView.setWebContentsDebuggingEnabled(initialSettings["devtools"] as? Boolean ?: false)
                    }

                    webViewClient = object : WebViewClient() {
                        override fun onPageFinished(view: WebView?, url: String?) {
                            super.onPageFinished(view, url)
                            emitSignal("page_loaded", url ?: "")
                            setupCommunicationChannel(this@apply)
                        }
                    }

                    layout.addView(this)
                }
            }
        }
    }
    
    private fun setupCommunicationChannel(wv: WebView) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val channel = wv.createWebMessageChannel()
            messagePort = channel[0]
            messagePort?.setWebMessageCallback(object : WebMessagePort.WebMessageCallback() {
                override fun onMessage(port: WebMessagePort, message: WebMessage) {
                    emitSignal("ipc_message", message.data)
                }
            })
            wv.postWebMessage(WebMessage("init_port", arrayOf(channel[1])), Uri.EMPTY)
        }
    }

    // --- Métodos da API ---

    @UsedByGodot fun setPositionAndSize(x: Int, y: Int, width: Int, height: Int) = runOnUiThread {
        webView?.let {
            val params = it.layoutParams as FrameLayout.LayoutParams
            params.width = width; params.height = height
            params.leftMargin = x; params.topMargin = y
            it.requestLayout()
        }
    }
    
    @UsedByGodot fun setVisible(visible: Boolean) = runOnUiThread { webView?.visibility = if (visible) View.VISIBLE else View.GONE }
    @UsedByGodot fun loadUrl(url: String) = runOnUiThread { webView?.loadUrl(url) }
    @UsedByGodot fun loadHtml(html: String) = runOnUiThread { webView?.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null) }
    @UsedByGodot fun setMouseFilterMode(mode: Int) = runOnUiThread { webView?.mouseFilterMode = mode }
    @UsedByGodot fun postMessage(message: String) = runOnUiThread {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            messagePort?.postMessage(WebMessage(message))
        }
    }
    
    @UsedByGodot fun eval(js: String) = runOnUiThread {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            webView?.evaluateJavascript(js) { result ->
                emitSignal("eval_result", result ?: "")
            }
        }
    }

    @UsedByGodot fun reload() = runOnUiThread { webView?.reload() }
    @UsedByGodot fun focus() = runOnUiThread { webView?.requestFocus() }
    
    @UsedByGodot fun focusParent() = runOnUiThread {
        // CORREÇÃO DEFINITIVA: Foca na View raiz da Activity.
        // Isso é garantido que funcione em qualquer versão.
        activity?.window?.decorView?.rootView?.requestFocus()
    }

    @UsedByGodot fun zoom(factor: Float) = runOnUiThread { webView?.zoomBy(factor) }
    @UsedByGodot fun print() = runOnUiThread {
        webView?.let {
            val printManager = activity?.getSystemService(Context.PRINT_SERVICE) as? PrintManager
            val jobName = "GodotWebView Print"
            val printAdapter = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                it.createPrintDocumentAdapter(jobName)
            } else {
                @Suppress("DEPRECATION")
                it.createPrintDocumentAdapter()
            }
            printManager?.print(jobName, printAdapter, PrintAttributes.Builder().build())
        }
    }

    @UsedByGodot fun clearAllBrowseData() = runOnUiThread {
        webView?.clearCache(true)
        webView?.clearHistory()
        webView?.clearFormData()
        CookieManager.getInstance().removeAllCookies(null)
        WebStorage.getInstance().deleteAllData()
    }

    @UsedByGodot fun destroy() = runOnUiThread {
        webView?.let {
            layout.removeView(it)
            it.destroy()
        }
        webView = null
    }
}