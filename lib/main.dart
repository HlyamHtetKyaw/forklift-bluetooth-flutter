import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';

// for Timer

const EventChannel _eventChannel = EventChannel('classic_bluetooth/stream');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestBluetoothPermissions();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MyApp());
}

Future<void> _requestBluetoothPermissions() async {
  if (await Permission.bluetoothConnect.isDenied ||
      await Permission.bluetoothScan.isDenied) {
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse, // Optional: For older Androids
    ].request();
  }

  // Optionally, check if denied forever and show rationale
  if (await Permission.bluetoothConnect.isPermanentlyDenied) {
    openAppSettings(); // or show dialog
  }
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
  bool _isForwardPressed = false;
  bool _isLeftPressed = false;
  bool _isBackwardPressed = false;
  bool _isRightPressed = false;
  bool _isMiddleUpPressed = false;
  bool _isMiddleDownPressed = false;
  String _weightText = "0.0";

  Timer? _sendTimer;

  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _startListeningToWeight();
  }

  void _startListeningToWeight() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is String && event.startsWith("W:")) {
        final value = double.tryParse(event.substring(2));
        if (value != null) {
          setState(() {
            _weightText = value.toStringAsFixed(1);
          });
        }
      }
    }, onError: (error) {
      print("Bluetooth stream error: $error");
    });
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 1.2;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
    });
  }

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
                    Navigator.pop(context); // Close the device selection dialog
                    final address = device['address']!;
                    final name = device['name']!;
                    BuildContext? dialogContext;

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext ctx) {
                        dialogContext = ctx;
                        return AlertDialog(
                          content: Row(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(width: 20),
                              Expanded(child: Text('Connecting to $name...')),
                            ],
                          ),
                        );
                      },
                    );

                    try {
                      await connectToDevice(address);
                      setState(() {
                        _connectedDeviceName = name;
                      });
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to connect to $name')),
                      );
                    } finally {
                      // CORRECTED: Use dialogContext to pop the connecting dialog
                      if (dialogContext != null) {
                        print("it is closed");
                        Navigator.of(dialogContext!).pop();
                      }
                    }
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

  void _startSending() {
    _sendSignal(); // send immediately

    _sendTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _sendSignal();
    });
  }

  void _stopSending() {
    _sendTimer?.cancel();
    _sendTimer = null;
  }

  void _sendSignal() {
    if (_isForwardPressed && _isLeftPressed) {
      _send("J"); // forward-left
    }else if(_isForwardPressed && _isRightPressed){
      _send("I"); // forward-right
    }else if(_isBackwardPressed && _isLeftPressed){
      _send("M"); // backward-left
    }else if(_isBackwardPressed && _isRightPressed){
      _send("K"); // backward-right
    }else if (_isForwardPressed) {
      _send("F"); // forward
    }else if (_isBackwardPressed) {
      _send("B"); // backward
    }else if (_isLeftPressed) {
      _send("L"); // left
    }else if (_isRightPressed) {
      _send("R"); // right
    }else if(_isMiddleUpPressed){
      _send("A");
    }
    else if(_isMiddleDownPressed){
      _send("C");
    }
  }

  Color _getWeightColor(String weightText) {
    try {
      final double weight = double.parse(weightText);
      return weight >= 500 ? Colors.red : Colors.green;
    } catch (e) {
      return Colors.black; // fallback if parsing fails
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Center(
                      child: Container(
                        width: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return ScaleTransition(scale: animation, child: child);
                            },
                            child: Text(
                              '$_weightText g',
                              key: ValueKey<String>(_weightText),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: _getWeightColor(_weightText),
                              ),
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
                        // Existing up/down buttons (forward/backward)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RoundButton(
                              icon: Icons.keyboard_double_arrow_up_sharp,
                              onPressStart: () {
                                _isForwardPressed = true;
                                _startSending();
                              },
                              onPressEnd: () {
                                _isForwardPressed = false;
                                _stopSending();
                              },
                            ),
                            const SizedBox(height: 40),
                            RoundButton(
                              icon: Icons.keyboard_double_arrow_down_sharp,
                              onPressStart: () {
                                _isBackwardPressed = true;
                                _startSending();
                              },
                              onPressEnd: () {
                                _isBackwardPressed = false;
                                _stopSending();
                              },
                            ),
                          ],
                        ),

                        const SizedBox(width: 100),

                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RoundButton(
                              svgAsset: 'assets/icons/lift_up.svg',
                              onPressStart: () {
                                _isMiddleUpPressed = true;
                                _startSending();
                              },
                              onPressEnd: () {
                                _isMiddleUpPressed = false;
                                _stopSending();
                              },
                            ),

                            const SizedBox(height: 5),

                            Row(
                              children: [
                                RoundButton(
                                  icon: Icons.keyboard_double_arrow_left_sharp,
                                  onPressStart: () {
                                    _isLeftPressed = true;
                                    _startSending();
                                  },
                                  onPressEnd: () {
                                    _isLeftPressed = false;
                                    _stopSending();
                                  },
                                ),
                                const SizedBox(width: 40),
                                RoundButton(
                                  icon: Icons.keyboard_double_arrow_right_sharp,
                                  onPressStart: () {
                                    _isRightPressed = true;
                                    _startSending();
                                  },
                                  onPressEnd: () {
                                    _isRightPressed = false;
                                    _stopSending();
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 5),

                            // Down (centered below left-right)
                            RoundButton(
                              svgAsset: 'assets/icons/lift_down.svg',
                              onPressStart: () {
                                _isMiddleDownPressed = true;
                                _startSending();
                              },
                              onPressEnd: () {
                                _isMiddleDownPressed = false;
                                _stopSending();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                ,
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
              child: GestureDetector(
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: () => setState(() => _scale = 1.0),
                child: AnimatedScale(
                  scale: _scale,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
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
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: Image.asset(
                'assets/tu_tgi.png',
                width: 50,
                height: 50,
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: Image.asset(
                'assets/ec_logo.png',
                width: 50,
                height: 50,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoundButton extends StatefulWidget {
  final IconData? icon; // optional now
  final String? svgAsset; // <-- NEW
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  const RoundButton({
    super.key,
    this.icon,
    this.svgAsset, // <-- NEW
    required this.onPressStart,
    required this.onPressEnd,
  });

  @override
  State<RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<RoundButton> {
  bool _isPressed = false;

  void _handleTapDown(_) {
    setState(() {
      _isPressed = true;
    });
    widget.onPressStart();
  }

  void _handleTapUp(_) {
    setState(() {
      _isPressed = false;
    });
    widget.onPressEnd();
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
    widget.onPressEnd();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 1 : 0.9,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          customBorder: const CircleBorder(),
          splashColor: Colors.black26,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
              boxShadow: _isPressed
                  ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 5,
                )
              ]
                  : [],
            ),
            child: Center(
              child: widget.svgAsset != null
                  ? SvgPicture.asset(
                widget.svgAsset!,
                width: 30,
                height: 30,
              )
                  : Icon(
                widget.icon,
                size: 48,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


