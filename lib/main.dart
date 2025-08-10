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

class _WeightScreenState extends State<WeightScreen> {
  final TextEditingController _weightController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
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
                  child: TextField(
                    controller: _weightController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Enter Weight',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          // Increment logic
                        }),
                        const SizedBox(height: 40),
                        _roundButton(Icons.arrow_downward, () {
                          // Decrement logic
                        }),
                      ],
                    ),

                    const SizedBox(width: 200),
                    // Left/Right buttons
                    Row(
                      children: [
                        _roundButton(Icons.arrow_back, () {
                          // Move left
                        }),
                        const SizedBox(width: 40),
                        _roundButton(Icons.arrow_forward, () {
                          // Move right
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
              child: const BluetoothButton()
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

class BluetoothButton extends StatefulWidget{
  const BluetoothButton({super.key});

  @override
  State<BluetoothButton> createState() => _BluetoothButtonState();
}



class _BluetoothButtonState extends State<BluetoothButton> {
  BluetoothDevice? _connectedDevice;
  final List<BluetoothDevice> _devicesList = [];
  bool _isScanning = false;

  void _startScan() {
    _devicesList.clear();
    setState(() {
      _isScanning = true;
    });

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (!_devicesList.any((d) => d.remoteId == result.device.remoteId)) {
          setState(() {
            _devicesList.add(result.device);
          });
        }
      }
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4)).then((_) {
      setState(() {
        _isScanning = false;
      });
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        _connectedDevice = device;
      });
      // In a real app, you would now discover services and characteristics
      // await device.discoverServices();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
  }

  void _showDeviceSelectionDialog(BuildContext context) {
    _startScan();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Available Devices'),
          content: SizedBox(
            width: double.maxFinite,
            child: _isScanning
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              shrinkWrap: true,
              itemCount: _devicesList.length,
              itemBuilder: (BuildContext context, int index) {
                final device = _devicesList[index];
                return ListTile(
                  title: Text(device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'),
                  onTap: () {
                    _connectToDevice(device);
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Connecting to: ${device.platformName}')),
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
            backgroundColor: _connectedDevice != null ? Colors.greenAccent : Colors.redAccent,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
          ),
          child: const Icon(Icons.bluetooth, size: 40),
        ),
        if (_connectedDevice != null)
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
