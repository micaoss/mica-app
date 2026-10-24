package dev.micaos.mica_app

import android.content.Intent
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSuggestion
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// `mica/wifi` join {ssid, psk}: the device's hotspot. Android 11+ shows the
// system's add-network dialog; Android 10 adds a network suggestion; older
// versions answer false and the app points at the QR code.
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mica/wifi").setMethodCallHandler { call, result ->
            val ssid = call.argument<String>("ssid")
            val psk = call.argument<String>("psk")
            if (call.method != "join" || ssid == null || psk == null) {
                result.notImplemented()
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                pending?.success(false)
                pending = result
                val suggestion = WifiNetworkSuggestion.Builder().setSsid(ssid).setWpa2Passphrase(psk).build()
                startActivityForResult(
                    Intent(Settings.ACTION_WIFI_ADD_NETWORKS)
                        .putParcelableArrayListExtra(Settings.EXTRA_WIFI_NETWORK_LIST, arrayListOf(suggestion)),
                    ADD_NETWORK,
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val suggestion = WifiNetworkSuggestion.Builder().setSsid(ssid).setWpa2Passphrase(psk).build()
                val wifi = applicationContext.getSystemService(WifiManager::class.java)
                result.success(wifi.addNetworkSuggestions(listOf(suggestion)) == WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS)
            } else {
                result.success(false)
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == ADD_NETWORK) {
            pending?.success(resultCode == RESULT_OK)
            pending = null
        }
    }

    companion object {
        private const val ADD_NETWORK = 7301
    }
}
