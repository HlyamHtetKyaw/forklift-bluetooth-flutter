import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weight App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WeightScreen(),
    );
  }
}

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}
BluetoothCharacteristic? _writeCharacteristic;
class _WeightScreenState extends State<WeightScreen> {
  final TextEditingController _weightController = TextEditingController();
  BluetoothDevice? _connectedDevice;

  // Function to find the correct characteristic for writing
  Future<void> _findWriteCharacteristic(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            _writeCharacteristic = characteristic;
            break;
          }
        }
        if (_writeCharacteristic != null) break;
      }
    } catch (e) {
      print('Error finding characteristic: $e');
    }
  }

  // Function to send data via Bluetooth
  Future<void> _sendData(String data) async {
    if (_writeCharacteristic == null) {
      print('No characteristic found for writing.');
      return;
    }
    try {
      List<int> bytes;
      switch (data) {
        case "F":
          bytes = [0x46]; // ASCII F
          break;
        case "B":
          bytes = [0x42];
          break;
        case "L":
          bytes = [0x4C];
          break;
        case "R":
          bytes = [0x52];
          break;
        default:
          bytes = [0x00];
      }

      if (_writeCharacteristic!.properties.writeWithoutResponse) {
        await _writeCharacteristic!.write(data.codeUnits, withoutResponse: true);
      } else {
        await _writeCharacteristic!.write(data.codeUnits);
      }
      // await _writeCharacteristic!.write(data.codeUnits);
      print('Sent: $data');
    } catch (e) {
      print('Error sending data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 🔝 Top: Weight input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Center(
                    child: Container(
                      width: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      // child: TextField(
                      //   controller: _weightController,
                      //   textAlign: TextAlign.center,
                      //   keyboardType: TextInputType.number,
                      //   decoration: const InputDecoration(
                      //     hintText: 'Enter Weight',
                      //     border: InputBorder.none,
                      //     contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      //   ),
                      // ),
                      child: const Padding(
                        padding: EdgeInsets.only(top: 10, bottom: 10),
                        child: Text(
                          'Weight Here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 🎮 Middle: Arrow Buttons
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Up/Down buttons
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _roundButton(Icons.arrow_upward, () {
                              _sendData("F"); // Send "F" on up arrow press
                            }),
                            const SizedBox(height: 40),
                            _roundButton(Icons.arrow_downward, () {
                              _sendData("B");
                            }),
                          ],
                        ),

                        const SizedBox(width: 200),
                        // Left/Right buttons
                        Row(
                          children: [
                            _roundButton(Icons.arrow_back, () {
                              // Move left
                              _sendData("L");
                            }),
                            const SizedBox(width: 40),
                            _roundButton(Icons.arrow_forward, () {
                              // Move right
                              _sendData("R");
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 📶 Bottom: Bluetooth button
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: BluetoothButton(
                    onDeviceConnected: (device) {
                      setState(() {
                        _connectedDevice = device;
                      });
                      _findWriteCharacteristic(device);
                    },
                    onDeviceDisconnected: () {
                      setState(() {
                        _connectedDevice = null;
                      });
                      _writeCharacteristic = null;
                    },
                  ),
                ),
              ],
            ),

            // 🚪 Disconnect button in the bottom right corner
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: _connectedDevice != null ? () async {
                  await _connectedDevice?.disconnect();
                  setState(() {
                    _connectedDevice = null;
                    _writeCharacteristic = null;
                  });
                } : null,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return Colors.grey.withValues(alpha: 0.3); // 30% opacity when disabled
                    }
                    return Colors.red; // Red when enabled
                  }),
                ),
                child: const Text("Disconnect",style: TextStyle(color: Colors.white),),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        iconSize: 48,
        color: Colors.black,
      ),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }
}

class BluetoothButton extends StatefulWidget {
  final Function(BluetoothDevice) onDeviceConnected;
  final VoidCallback onDeviceDisconnected;

  const BluetoothButton({
    super.key,
    required this.onDeviceConnected,
    required this.onDeviceDisconnected,
  });

  @override
  State<BluetoothButton> createState() => _BluetoothButtonState();
}

class _BluetoothButtonState extends State<BluetoothButton> {
  BluetoothDevice? _connectedDevice;
  final List<BluetoothDevice> _devicesList = [];
  bool _isScanning = false;

  StreamSubscription? _scanSubscription;

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  void _startScan() async {
    _devicesList.clear();
    _scanSubscription?.cancel();
    await FlutterBluePlus.stopScan();
    print("Connected device: "+_connectedDevice.toString());
    setState(() {
      _isScanning = true;
    });

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      for (ScanResult result in results) {
        print("Scanned device: "+result.toString());
        if (!_devicesList.any((d) => d.remoteId == result.device.remoteId)) {
          setState(() {
            _devicesList.add(result.device);
          });
        }
      }
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4)).then((_) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        print("Scanned stopped with state: "+_isScanning.toString());
      });

      _scanSubscription?.cancel(); // Cleanup after scan
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        _connectedDevice = device;
      });
      widget.onDeviceConnected(device);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
    device.connectionState.listen((BluetoothConnectionState state) {
      if (state == BluetoothConnectionState.disconnected) {
        setState(() {
          _connectedDevice = null;
          _writeCharacteristic = null;
        });
      }
    });
  }

  void _showDeviceSelectionDialog(BuildContext context) {
    _startScan();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Available Devices'),
              content: SizedBox(
                width: double.maxFinite,
                child:
                // _isScanning
                //     ? const Center(child: CircularProgressIndicator())
                //     :
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: _devicesList.length,
                  itemBuilder: (BuildContext context, int index) {
                    final device = _devicesList[index];
                    return ListTile(
                      title: Text(device.platformName.isNotEmpty
                          ? device.platformName
                          : 'Unknown Device'),
                      onTap: () {
                        _connectToDevice(device);
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Connecting to: ${device.platformName}'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    FlutterBluePlus.stopScan();
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () => _showDeviceSelectionDialog(context),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(10),
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
          ),
          child: const Icon(Icons.bluetooth, size: 25),
        ),
        if(_connectedDevice != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Connected: ${_connectedDevice!.platformName}',
              style: const TextStyle(fontSize: 12, color: Colors.blue),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}