package com.example.forklift_bluetooth

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val CHANNEL = "classic_bluetooth"
    private val uuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB") // Standard SPP UUID

    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: java.io.OutputStream? = null

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connectToDevice" -> {
                    val macAddress = call.argument<String>("macAddress")
                    if (macAddress != null) {
                        connectToDevice(macAddress, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "MAC address missing", null)
                    }
                }
                "sendCommand" -> {
                    val data = call.argument<String>("data")
                    if (data != null) {
                        sendCommand(data, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Data missing", null)
                    }
                }
                "getBondedDevices" -> {
                    val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
                    if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
                        result.error("BLUETOOTH_DISABLED", "Bluetooth not available or not enabled", null)
                    } else {
                        val devices = bluetoothAdapter.bondedDevices
                        val deviceList = devices.map {
                            mapOf("name" to it.name, "address" to it.address)
                        }
                        result.success(deviceList)
                    }
                }
                "disconnect" -> {
                    disconnect(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun connectToDevice(macAddress: String, result: MethodChannel.Result) {
        val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()

        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is not available or not enabled", null)
            return
        }

        val device: BluetoothDevice
        try {
            device = bluetoothAdapter.getRemoteDevice(macAddress)
        } catch (e: IllegalArgumentException) {
            result.error("INVALID_MAC", "MAC address is invalid", null)
            return
        }

        thread {
            try {
                bluetoothSocket = device.createRfcommSocketToServiceRecord(uuid)
                bluetoothAdapter.cancelDiscovery()
                bluetoothSocket?.connect()
                outputStream = bluetoothSocket?.outputStream
                runOnUiThread { result.success(null) }
            } catch (e: IOException) {
                e.printStackTrace()
                runOnUiThread { result.error("CONNECTION_FAILED", "Could not connect to device", null) }
            }
        }
    }

    private fun sendCommand(data: String, result: MethodChannel.Result) {
        thread {
            try {
                outputStream?.write(data.toByteArray())
                runOnUiThread { result.success(null) }
            } catch (e: IOException) {
                e.printStackTrace()
                runOnUiThread { result.error("SEND_FAILED", "Failed to send data", null) }
            }
        }
    }

    private fun disconnect(result: MethodChannel.Result) {
        thread {
            try {
                outputStream?.close()
                bluetoothSocket?.close()
                runOnUiThread { result.success(null) }
            } catch (e: IOException) {
                e.printStackTrace()
                runOnUiThread { result.error("DISCONNECT_FAILED", "Failed to disconnect", null) }
            }
        }
    }
}
