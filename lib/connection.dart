import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:localstorage/localstorage.dart';

TextEditingController _textController = TextEditingController();

class Connection extends StatefulWidget {
  @override
  _ConnectionState createState() => _ConnectionState();
}

class DNDService {
  static const platform = MethodChannel('com.example.lumi_smart/dnd');

  // Enable DND
  Future<void> enableDND() async {
    try {
      final bool result = await platform.invokeMethod('enableDND');
      if (!result) {
        print('Permission not granted for DND');
      }
    } catch (e) {
      print('Failed to enable DND: $e');
    }
  }

  // Disable DND
  Future<void> disableDND() async {
    try {
      final bool result = await platform.invokeMethod('disableDND');
      if (!result) {
        print('Failed to disable DND');
      }
    } catch (e) {
      print('Failed to disable DND: $e');
    }
  }
}

DNDService dndService = DNDService();

class _ConnectionState extends State<Connection> {
  final LocalStorage storage = new LocalStorage('localstorage_app');

  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? connection;

  List<BluetoothDevice> _devicesList = [];
  List<BluetoothDiscoveryResult> _discoveredDevices = [];
  bool _isDiscovering = false;
  BluetoothDevice? _device;
  String _receivedData = '';

  Map<String, List<Map<String, int>>> _pomodoroData = {};

  bool _isButtonUnavailable = false;
  bool _isConnecting = false; // New state for loading indicator
  bool isListening = false; // Flag to check if already listening

  late SharedPreferences prefs;
  bool? isPomodoroActive;
  bool? connected = true;
  bool? isLightOn;

  @override
  void initState() {
    super.initState();
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    prefs = await SharedPreferences.getInstance();
    await _initializePreferences();
    await _checkPermissions();

    storage.setItem('connected', false);
  }

  // Initialize preferences to retrieve the Pomodoro status
  Future<void> _initializePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedData = prefs.getString('pomodoroData');

    if (storedData != null) {
      // Decode the stored JSON string into a map
      _pomodoroData = Map<String, List<Map<String, int>>>.from(
          jsonDecode(storedData).map((key, value) =>
              MapEntry(key, List<Map<String, int>>.from(value))));
    }

    setState(() {
      isPomodoroActive = prefs.getBool('isPomodoroActive') ??
          false; // Default to false if nulllt to false if null
    });
  }

  // void _loadConnectedState() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   bool isConnected = prefs.getBool('isConnected') ?? false;

  //   setState(() {
  //     connected = isConnected; // Ensure UI updates here
  //   });

  //   print("connected: $connected");
  // }

  // void _updateConnectionState(bool newState) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();

  //   setState(() {
  //     connected = newState;
  //     print(
  //         "UI updated: connected is now $connected"); // Ensure UI updates here as well
  //   });

  //   await prefs.setBool('isConnected', connected!);
  // }

  Future<void> _checkPermissions() async {
    if (await _requestPermissions()) {
      _getBTState();
      _stateListener();
      _listBondedDevices();
    } else {
      show("Permissions not granted");
    }
  }

  Future<bool> _requestPermissions() async {
    if (!(await Permission.bluetooth.request().isGranted)) {
      show("Bluetooth permission not granted");
      return false;
    }
    if (!(await Permission.location.request().isGranted)) {
      show("Location permission not granted");
      return false;
    }
    if (!(await Permission.bluetoothConnect.request().isGranted)) {
      show("Bluetooth connect permission not granted");
      return false;
    }
    if (!(await Permission.bluetoothScan.request().isGranted)) {
      show("Bluetooth scan permission not granted");
      return false;
    }
    return true;
  }

  void _getBTState() {
    _bluetooth.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });
  }

  void _stateListener() {
    _bluetooth.onStateChanged().listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
        _listBondedDevices();
      });
    });
  }

  void _listBondedDevices() async {
    try {
      List<BluetoothDevice> bondedDevices = await _bluetooth.getBondedDevices();
      setState(() {
        _devicesList = bondedDevices;
      });
    } catch (e) {
      show('Error listing bonded devices: $e');
    }
  }

  void _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
      _discoveredDevices.clear();
    });

    _bluetooth.startDiscovery().listen((BluetoothDiscoveryResult result) {
      setState(() {
        _discoveredDevices.add(result);
      });
    }).onDone(() {
      setState(() {
        _isDiscovering = false;
      });
    });
  }

  void _printConnectionStatus() {
    print(((storage.getItem('connected')) ?? false));
  }

  void _cancelDiscovery() async {
    await _bluetooth.cancelDiscovery();
    setState(() {
      _isDiscovering = false;
    });
  }

  void _connect() async {
    if (!await _requestPermissions()) {
      return;
    }

    await storage.setItem('connected', true);

    setState(() {
      _isButtonUnavailable = true;
      _isConnecting = true; // Show loading indicator
    });

    await dndService.enableDND();

    // The address of the device you want to connect to
    String targetAddress = "FC:E8:C0:74:50:62";

    try {
      // Check if the target device is in the discovered devices
      BluetoothDevice? targetDevice = _discoveredDevices
          .map((result) => result.device)
          .firstWhere((device) => device.address == targetAddress,
              orElse: () => BluetoothDevice(address: targetAddress));

      // Check if targetDevice is the Unknown device or actually null
      if (targetDevice.name == "Unknown") {
        show("Device not found");
        setState(() {
          _isButtonUnavailable = false;
          _isConnecting = false; // Hide loading indicator
        });
        return;
      }

      connection = await BluetoothConnection.toAddress(targetDevice.address);

      connection?.input?.listen(_onDataReceived).onDone(() {
        print("HEKOOOOOOOO");
      });
    } catch (error) {
      show('Error connecting to device: Make sure the Lamp is turned ON');
    }

    setState(() {
      _isButtonUnavailable = false;
      _isConnecting = false; // Hide loading indicator
    });
  }

  void _disconnect() async {
    await connection?.close();
    await storage.setItem('connected', false);
    if (connection == null || !connection!.isConnected) {
      setState(() {
        connected = false;
        _isButtonUnavailable = false;
      });
    }
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    for (var byte in data) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    }
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);

    print(dataString);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        _receivedData = (dataString.substring(0, index));
      });
    }

    if (dataString.contains("['update',0]")) {
      _startPomorodo("start", false);
    } else if (dataString.contains("['update',1]")) {
      _stopPomorodo("stop", false);
    } else if (dataString.contains("['finish']")) {
      _stopPomorodo("stop", false);
    } else if (dataString.contains("[light]")) {
      if (dataString.contains("[light,1]")) {
        _turnOnLight("lightOn", false);
      } else {
        _turnOffLight("lightOff", false);
      }
    }
  }

  void show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  // Function to initialize Bluetooth connection and set up listener
  void _initializeBluetoothConnection(BluetoothConnection connection) {
    // Set up listener only once
    if (!isListening) {
      connection.input!.listen((Uint8List data) {
        String receivedText = utf8.decode(data);
        show("Received from Arduino: $receivedText");
      }).onDone(() {
        show("Connection closed by the Bluetooth device.");
        isListening = false; // Reset listener flag when connection closes
      });

      isListening = true; // Mark listener as active
    }
  }

// Function to send text to the Arduino device
  void _startPomorodo(String data, bool isMobile) async {
    DateTime startTime = DateTime.now();

    // Update the pomodoro data map
    String date = "${startTime.year}/${startTime.month}/${startTime.day}";

    if (!_pomodoroData.containsKey(date)) {
      _pomodoroData[date] = [];
    }

    // Add a new entry for the session start time, with stop time as null
    _pomodoroData[date]?.add({
      "startTime": startTime.millisecondsSinceEpoch,
      "stopTime": -1, // Stop time will be updated later
    });

    setState(() {
      isPomodoroActive = true; // Update the state
    });
    // Save the updated map to local storage
    await prefs.setString('pomodoroData', jsonEncode(_pomodoroData));

    // Retrieve the existing pomodoro data from local storage
    List<dynamic> existingData = storage.getItem('pomodoroData') ?? [];

    // Add the new data to the existing data
    existingData.add(_pomodoroData);

    // Save the updated list back to local storage
    await storage.setItem('pomodoroData', existingData);

    print("pomorodData: $_pomodoroData");

    print(storage.getItem('pomodoroData'));

    await dndService.enableDND();

    setState(() {
      isPomodoroActive = true; // Update the state
    });
    show("Pomodoro Started");

    // Store Pomodoro status in local storage
    await prefs.setBool('isPomodoroActive', isPomodoroActive ?? false);

    // Turn on Do Not Disturb (DND) mode

    if (connection?.isConnected ?? false) {
      try {
        if (isMobile) {
          connection?.output.add(ascii.encode(data));
          await connection?.output.allSent;
        }
      } catch (e) {
        show("Error sending data: $e");
      }
    } else {
      show("No active Bluetooth connection");
    }
  }

  void _stopPomorodo(String data, bool isMobile) async {
    DateTime stopTime = DateTime.now();

    String date = "${stopTime.year}/${stopTime.month}/${stopTime.day}";

    // Update the last session with stop time
    if (_pomodoroData.containsKey(date) &&
        _pomodoroData[date] != null &&
        _pomodoroData[date]!.isNotEmpty) {
      _pomodoroData[date]?.last["stopTime"] = stopTime.millisecondsSinceEpoch;
    }

    // Save the updated map to local storage
    await prefs.setString('pomodoroData', jsonEncode(_pomodoroData));

    setState(() {
      isPomodoroActive = false; // Update the state
    });
    show("Pomodoro Stopped");

    // Turn on Do Not Disturb (DND) mode
    await dndService.disableDND();

    // Store Pomodoro status in local storage
    await prefs.setBool('isPomodoroActive', isPomodoroActive ?? false);

    if (connection?.isConnected ?? false) {
      try {
        if (isMobile) {
          connection?.output.add(ascii.encode(data));
          await connection?.output.allSent;
        }
      } catch (e) {
        show("Error sending data: $e");
      }
    } else {
      show("No active Bluetooth connection");
    }
  }

  void _turnOffLight(String data, bool isMobile) async {
    setState(() {
      isLightOn = false; // Update the state
    });
    show("Light Turned OFF");

    try {
      if (isMobile) {
        connection?.output.add(ascii.encode(data));

        await connection?.output.allSent;
      }
    } catch (e) {
      show("Error sending data: $e");
    }

    await prefs.setBool('isLightOn', isLightOn ?? false);
  }

  void _turnOnLight(String data, bool isMobile) async {
    setState(() {
      isLightOn = true; // Update the state
    });
    show("Light Turned ON");

    try {
      if (isMobile) {
        connection?.output.add(ascii.encode(data));
        await connection?.output.allSent;
      }
    } catch (e) {
      show("Error sending data: $e");
    }

    await prefs.setBool('isLightOn', isLightOn ?? false);
  }

// Function to connect to the Bluetooth device and set up the listener
  void connectToBluetoothDevice(String deviceAddress) async {
    try {
      connection = await BluetoothConnection.toAddress(deviceAddress);
      show("Connected to the Arduino device.");

      // Initialize the listener once when connected
      _initializeBluetoothConnection(connection!);
    } catch (e) {
      show("Failed to connect: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: (storage.getItem('connected')) ?? false
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    ((storage.getItem('connected')) ?? false)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              // Row for the image
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.asset(
                                      'assets/lamp.jpg',
                                      fit: BoxFit.contain,
                                      height: 80,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 20), // Add gap between children

                              // Row for text
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start, // Align text to the left
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            "Lumi Smart (Smart Lamp)",
                                            style: TextStyle(
                                              fontSize: 15, // Set font size
                                              fontWeight: FontWeight
                                                  .bold, // Set bold text
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            "Connected",
                                            style: TextStyle(
                                              fontSize: 13, // Set font size
                                              color: Colors
                                                  .green, // Text color for "Connected"
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(width: 20), // Add gap between children

                              // Row for the icon
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bluetooth,
                                    size: 30,
                                    color: Colors.black, // Bluetooth icon color
                                  ),
                                ],
                              ),
                            ],
                          )
                        : const Column(
                            children: [
                              Icon(
                                Icons.bluetooth_disabled,
                                size: 40,
                              ),
                              SizedBox(
                                  width:
                                      20), // Add some space between the icon and text
                              Text(
                                'The Lamp is not connected to the app',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isButtonUnavailable
                ? null
                : ((storage.getItem('connected')) ?? false)
                    ? _disconnect
                    : _connect,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black, // background color
              foregroundColor: Colors.white, // text color
            ),
            child: _isConnecting
                ? const CircularProgressIndicator(
                    color: Colors.white,
                  )
                : Text(((storage.getItem('connected')) ?? false)
                    ? 'Disconnect'
                    : 'Connect'),
          ),
          ((storage.getItem('connected')) ?? false)
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: ElevatedButton(
                        onPressed: () => (isPomodoroActive ?? false)
                            ? _stopPomorodo("stop", true)
                            : _startPomorodo("start",
                                true), //second varible to check the call is from device or from app
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: const Size(2 * 16.0,
                              5 * 16.0), // 2rem and 5rem converted to pixels
                          backgroundColor: (isPomodoroActive ?? false)
                              ? Color.fromARGB(255, 139, 0, 0)
                              : Color.fromARGB(
                                  255, 9, 85, 2), // background color
                          foregroundColor: Colors.white, // text color
                        ),
                        child: _isConnecting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text((isPomodoroActive ?? false)
                                ? 'Stop Pomorodo'
                                : 'Start Pomorodo'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: ToggleButtons(
                        isSelected: [(isLightOn ?? false)],
                        onPressed: (int index) {
                          if (index == 0) {
                            (isLightOn ?? false)
                                ? _turnOffLight("lightOff", true)
                                : _turnOnLight("lightOn", true);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        selectedColor: Colors.white,
                        fillColor: (isLightOn ?? false)
                            ? Color.fromARGB(255, 63, 1, 118)
                            : Color.fromARGB(255, 9, 85, 2),
                        color: Colors.black,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: _isConnecting
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text((isLightOn ?? false)
                                    ? 'Turn Off Light'
                                    : 'Turn On Light'),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Container(),
        ],
      ),
      backgroundColor: Colors.white,
    );
  }
}
