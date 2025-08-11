import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MyApp());
}

const platform = MethodChannel('classic_bluetooth');

Future<void> connectToDevice(String macAddress) async {
  try {
    await platform.invokeMethod('connectToDevice', {'macAddress': macAddress});
  } on PlatformException catch (e) {
    print("Connection error: ${e.message}");
  }
}

Future<void> sendCommand(String data) async {
  try {
    await platform.invokeMethod('sendCommand', {'data': data});
  } on PlatformException catch (e) {
    print("Send error: ${e.message}");
  }
}

Future<void> disconnectFromDevice() async {
  try {
    await platform.invokeMethod('disconnect');
  } on PlatformException catch (e) {
    print("Disconnect error: ${e.message}");
  }
}

Future<List<Map<String, String>>> getPairedDevices() async {
  try {
    final List<dynamic> devices = await platform.invokeMethod('getBondedDevices');
    return devices.map<Map<String, String>>((e) => Map<String, String>.from(e)).toList();
  } on PlatformException catch (e) {
    print("Error fetching bonded devices: ${e.message}");
    return [];
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weight App',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  String? _connectedDeviceName;

  void _showDeviceSelectionDialog() async {
    final devices = await getPairedDevices();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Device'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  title: Text(device['name'] ?? 'Unknown'),
                  subtitle: Text(device['address'] ?? ''),
                  onTap: () async {
                    Navigator.pop(context);
                    final address = device['address']!;
                    final name = device['name']!;
                    await connectToDevice(address);
                    setState(() {
                      _connectedDeviceName = name;
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _disconnect() async {
    await disconnectFromDevice();
    setState(() {
      _connectedDeviceName = null;
    });
  }

  void _send(String command) async {
    await sendCommand(command);
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Center(
                    child: Container(
                      width: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _roundButton(Icons.arrow_upward, () => _send("F")),
                            const SizedBox(height: 40),
                            _roundButton(Icons.arrow_downward, () => _send("B")),
                          ],
                        ),
                        const SizedBox(width: 200),
                        Row(
                          children: [
                            _roundButton(Icons.arrow_back, () => _send("L")),
                            const SizedBox(width: 40),
                            _roundButton(Icons.arrow_forward, () => _send("R")),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: _showDeviceSelectionDialog,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(10),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(),
                        ),
                        child: const Icon(Icons.bluetooth, size: 25),
                      ),
                      if (_connectedDeviceName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Connected: $_connectedDeviceName',
                            style: const TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: _connectedDeviceName != null ? _disconnect : null,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return Colors.grey.withAlpha(80);
                    }
                    return Colors.red;
                  }),
                ),
                child: const Text("Disconnect", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
