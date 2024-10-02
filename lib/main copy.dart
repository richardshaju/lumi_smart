import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'dart:convert';

TextEditingController _textController = TextEditingController();  // Initialize text controller


void requestBluetoothPermission() async {
  await Permission.bluetoothScan.request();
  await Permission.location.request();
}


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumi Smart',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: BluetoothApp(),
    );
  }
}

class BluetoothApp extends StatefulWidget {
  @override
  _BluetoothAppState createState() => _BluetoothAppState();
}

class _BluetoothAppState extends State<BluetoothApp> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? connection;

  List<BluetoothDevice> _devicesList = [];
   List<BluetoothDiscoveryResult> _discoveredDevices = [];
   bool _isDiscovering = false;
  BluetoothDevice? _device;
  bool _connected = false;
  bool _isButtonUnavailable = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

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
    if (!(await Permission.bluetoothConnect.request().isGranted)){
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
      print('Bonded devices: $bondedDevices');
      setState(() {
        _devicesList = bondedDevices;
      });
    } catch (e) {
      print('Error listing bonded devices: $e');
      show('Error listing bonded devices:');
    }
  }

    // Function to start scanning for new devices
  void _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
      _discoveredDevices.clear();  // Clear previous scan results
    });

    _bluetooth.startDiscovery().listen((BluetoothDiscoveryResult result) {
      print('Found device: ${result.device.name}');
      setState(() {
        _discoveredDevices.add(result);
      });
    }).onDone(() {
      setState(() {
        _isDiscovering = false;  // Discovery completed
      });
    });
  }

    // Function to stop scanning for new devices
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

    setState(() {
      _isButtonUnavailable = true;
    });
    if (_device == null) {
      show('Please select a device');
      setState(() {
        _isButtonUnavailable = false;
      });
      return;
    }

    try {
      BluetoothConnection connection = await BluetoothConnection.toAddress(_device!.address);
      print('Connected to the device');
      setState(() {
        this.connection = connection;
        _connected = true;
      });

      connection.input!.listen(null).onDone(() {
        if (this.mounted) {
          setState(() {
            _connected = false;
          });
        }
      });
    } catch (error) {
      print('Cannot connect, exception occurred');
      print(error);
      show('Error connecting to device');
    }

    setState(() {
      _isButtonUnavailable = false;
    });
  }

  void _disconnect() async {
    setState(() {
      _isButtonUnavailable = true;
    });

    await connection?.close();
    show('Device disconnected');
    if (connection == null || !connection!.isConnected) {
      setState(() {
        _connected = false;
        _isButtonUnavailable = false;
      });
    }
  }

  void show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
    ));
  }


  void _sendText() async {
    String textToSend = _textController.text;

    if (connection != null && connection!.isConnected) {
      try {
        // Send the text as bytes to the connected Bluetooth device
        connection!.output.add(Uint8List.fromList(utf8.encode(textToSend + "\r\n")));
        await connection!.output.allSent;
        print("Text sent: $textToSend");

        // Listen for the response from the Bluetooth device
        connection!.input!.listen((Uint8List data) {
          String receivedText = utf8.decode(data);
          print("Received: $receivedText");
          show("Received: $receivedText");
        }).onDone(() {
          print("Disconnected from device");
        });
      } catch (e) {
        print("Failed to send text: $e");
        show("Failed to send text: $e");
      }
    } else {
      print("No connection to Bluetooth device.");
      show("No connection to Bluetooth device.");
    }

    // Optionally, clear the text field after sending
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lumi Smart'),
         actions: [
          _isDiscovering
              ? IconButton(
                  icon: Icon(Icons.stop),
                  onPressed: _cancelDiscovery,
                )
              : IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _startDiscovery,
                )
        ],
      ),
      body: Container(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
            'Device:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
              ),
              DropdownButton(
            items: _devicesList
                .map((device) => DropdownMenuItem(
                  child: Text(device.name ?? ""),
                  value: device,
                ))
                .toList(),
            onChanged: (value) =>
                setState(() => _device = value as BluetoothDevice?),
            value: _devicesList.isNotEmpty ? _device : null,
              ),
            ],
          ),
          SizedBox(height: 16.0),
          ElevatedButton(
            onPressed: _isButtonUnavailable
            ? null
            : _connected ? _disconnect : _connect,
            child: Text(_connected ? 'Disconnect' : 'Connect'),
          ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Bluetooth is ${_bluetoothState.isEnabled ? "ON" : "OFF"}",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
            ),
          ),
        ),
         const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Discovered Devices', style: TextStyle(fontSize: 20)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _discoveredDevices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_discoveredDevices[index].device.name ?? 'Unknown'),
                  subtitle: Text(_discoveredDevices[index].device.address.toString()),
                  onTap: () {
                    // Handle discovered device tap (e.g., connect)
                    _device = _discoveredDevices[index].device;
                    _connect();
                  },
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _textController,
            decoration: InputDecoration(
          labelText: 'Enter text to send',
          border: OutlineInputBorder(),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _connected ? _sendText : null,
          child: Text('Send'),
        ),
          ],
        ),
      ),
    );
  }
}