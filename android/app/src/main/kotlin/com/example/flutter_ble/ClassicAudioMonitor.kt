package com.example.flutter_ble

import android.Manifest
import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Android's Classic Bluetooth (A2DP) connection state to Flutter.
 *
 * flutter_blue_plus - and every other Flutter BLE plugin - can only see
 * BLE/GATT devices. Audio headphones/earbuds/speakers connect over Classic
 * Bluetooth (A2DP), which has no BLE presence at all, so this native
 * listener is the only way to detect their connect/disconnect state.
 */
class ClassicAudioMonitor(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private var eventSink: EventChannel.EventSink? = null
    private var receiverRegistered = false

    private val bluetoothAdapter: BluetoothAdapter? =
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    private var a2dpProxy: BluetoothProfile? = null

    private val profileListener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
            a2dpProxy = proxy
        }

        override fun onServiceDisconnected(profile: Int) {
            a2dpProxy = null
        }
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            @Suppress("DEPRECATION")
            val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE) ?: return
            if (!isAudioDevice(device)) return

            when (intent.action) {
                BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED -> {
                    when (intent.getIntExtra(BluetoothProfile.EXTRA_STATE, -1)) {
                        BluetoothProfile.STATE_CONNECTED -> emitEvent(device, true)
                        BluetoothProfile.STATE_DISCONNECTED -> emitEvent(device, false)
                    }
                }
                // Fallback signal: the A2DP-specific broadcast above is the
                // precise one, but ACL connect/disconnect is the most
                // fundamental Classic Bluetooth link event and fires
                // reliably even on OEM Bluetooth stacks that are inconsistent
                // about the profile-specific broadcast.
                BluetoothDevice.ACTION_ACL_CONNECTED -> emitEvent(device, true)
                BluetoothDevice.ACTION_ACL_DISCONNECTED -> emitEvent(device, false)
            }
        }
    }

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)

        val filter = IntentFilter().apply {
            addAction(BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED)
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // RECEIVER_NOT_EXPORTED would silently block these broadcasts:
            // per Android's own docs, that flag excludes broadcasts from
            // "highly privileged" system components - which is exactly what
            // the Bluetooth stack is. RECEIVER_EXPORTED is required to
            // actually receive them. This carries no real exposure here
            // since the payload is just a connection-state notification.
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(receiver, filter)
        }
        receiverRegistered = true

        bluetoothAdapter?.getProfileProxy(context, profileListener, BluetoothProfile.A2DP)
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        if (receiverRegistered) {
            try {
                context.unregisterReceiver(receiver)
            } catch (e: IllegalArgumentException) {
                // already unregistered
            }
            receiverRegistered = false
        }
        a2dpProxy?.let { bluetoothAdapter?.closeProfileProxy(BluetoothProfile.A2DP, it) }
    }

    private fun hasPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun deviceName(device: BluetoothDevice): String {
        return try {
            device.name ?: device.address
        } catch (e: SecurityException) {
            device.address
        }
    }

    private fun isAudioDevice(device: BluetoothDevice): Boolean {
        return try {
            device.bluetoothClass?.majorDeviceClass == BluetoothClass.Device.Major.AUDIO_VIDEO
        } catch (e: SecurityException) {
            false
        }
    }

    private fun emitEvent(device: BluetoothDevice, connected: Boolean) {
        if (!hasPermission()) return
        eventSink?.success(
            mapOf(
                "address" to device.address,
                "name" to deviceName(device),
                "connected" to connected
            )
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPairedAudioDevices" -> {
                if (!hasPermission()) {
                    result.success(emptyList<Map<String, Any?>>())
                    return
                }
                try {
                    val connectedAddresses = (a2dpProxy?.connectedDevices ?: emptyList())
                        .map { it.address }
                        .toSet()
                    val bonded = bluetoothAdapter?.bondedDevices ?: emptySet()
                    val devices = bonded.filter { isAudioDevice(it) }.map { d ->
                        mapOf(
                            "address" to d.address,
                            "name" to deviceName(d),
                            "connected" to connectedAddresses.contains(d.address)
                        )
                    }
                    result.success(devices)
                } catch (e: SecurityException) {
                    result.success(emptyList<Map<String, Any?>>())
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    companion object {
        private const val METHOD_CHANNEL = "zalarmee/classic_bt"
        private const val EVENT_CHANNEL = "zalarmee/classic_bt_events"
    }
}
