import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothManager {
  BluetoothConnection? connection;

  Future<List<BluetoothDevice>> getBondedDevices() async {
    return await FlutterBluetoothSerial.instance.getBondedDevices();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    connection = await BluetoothConnection.toAddress(device.address);
  }

  void sendData(String message) {
    if (connection != null) {
      connection!.output.add(Uint8List.fromList(utf8.encode(message + '\r\n')));
    }
  }

  Stream<Uint8List>? get onDataReceived => connection?.input;

  void dispose() {
    connection?.close();
  }
}

class SeraKontrolPage extends StatefulWidget {
  const SeraKontrolPage({Key? key}) : super(key: key);

  @override
  _SeraKontrolPageState createState() => _SeraKontrolPageState();
}

class _SeraKontrolPageState extends State<SeraKontrolPage> {
  final bluetoothManager = BluetoothManager();
  bool isConnected = false;
  String toprakNemi = 'Bilinmiyor';
  String yagmurDurumu = 'Bilinmiyor';

  String nemVerisiisle(int value) {
    if (value >= 900) {
      return 'Kuru ve Kuruya Yakın Toprak';
    } else if (value >= 220) {
      return 'Nemli ve Güzel Bir Toprak';
    } else {
      return 'Aşırı Nemli-ıslak Toprak';
    }
  }

  @override
  void initState() {
    super.initState();
    _requestBluetoothPermissions();
  }

  // Bluetooth izinlerini isteyen metot
  Future<void> _requestBluetoothPermissions() async {
    if (await Permission.bluetoothConnect.request().isGranted) {
      // İzin verildi
      // İşlevsellikle ilgili diğer işlemleri buraya ekleyebilirsiniz.
    } else {
      // Kullanıcı izni reddetti veya bir hata oluştu
      // İsteğe bağlı olarak kullanıcıya bilgi verme veya hata işleme
    }
  }

  void _connectToBluetoothDevice() async {
    List<BluetoothDevice> devices = await bluetoothManager.getBondedDevices();
    try {
      BluetoothDevice hc06 =
          devices.firstWhere((device) => device.name == 'HC-06');
      await bluetoothManager.connectToDevice(hc06);
      bluetoothManager.onDataReceived?.listen((data) {
        String receivedData = utf8.decode(data);
        var parts = receivedData.split(',');
        if (parts.length == 2) {
          int toprakNemdegeri = int.tryParse(parts[0].trim()) ?? 0;
          setState(() {
            toprakNemi = nemVerisiisle(toprakNemdegeri);
            yagmurDurumu = parts[1].trim();
          });
        }
      });

      setState(() {
        isConnected = true;
      });
    } catch (e) {
      // Hata durumunda dialog goster
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Hata'),
            content: Text('Bluetooth cihazına bağlanılamadı.'),
            actions: [
              TextButton(
                child: Text('Tamam'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  void _sendCommand(String command) {
    bluetoothManager.sendData(command);
  }

  //Bilgi sayfasi
  void _openInfoPage() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: Container(
            height: 200,
            child: Center(
              child: Text(
                'Bu uygulama Mimari Dersi kapsamında arduino projesi olarak gerçekleştirilmiştir.',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 238, 231, 231),
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 238, 233, 233),
        title: Text(
          'Sera Kontrol Sistemi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.bluetooth),
            color: isConnected ? Colors.blue : Colors.grey,
            onPressed: isConnected ? null : _connectToBluetoothDevice,
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _openInfoPage,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildProfileCard(),
          _buildWeatherCard(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Expanded(
                  child: Card(
                    elevation: 5,
                    color: Colors.amber,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: <Widget>[
                          Text('Toprak Nem Durumu',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text(toprakNemi),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    elevation: 5,
                    color: Colors.blue.shade400,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: <Widget>[
                          Text('Yağmur Durumu',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text(yagmurDurumu),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.only(left: 40, right: 40),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 45)),
              onPressed: isConnected ? () => _sendCommand('1') : null,
              child: Text('Sulama Sistemini Aktif Et'),
            ),
          ),
          SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.only(left: 40, right: 40),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 45)),
              onPressed: isConnected ? () => _sendCommand('2') : null,
              child: Text('Sera Perde Kapat'),
            ),
          ),
          SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.only(left: 40, right: 40),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 45)),
              onPressed: isConnected ? () => _sendCommand('3') : null,
              child: Text('Sera Perde Aç'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10),
      child: Card(
        elevation: 5,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.location_on, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Yozgat / Merkez'),
                  Spacer(),
                  Lottie.asset('assets/lottie/gunesli.json',
                      width: 40, height: 40),
                  SizedBox(width: 8),
                  Text('15°'),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildWeatherInfo(Icons.compress, '1052 mb'),
                  _buildWeatherInfo(Icons.wind_power, '5 km/s'),
                  _buildWeatherInfo(Icons.water_drop, '5%'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherInfo(IconData icon, String label) {
    return Row(
      children: <Widget>[
        Icon(icon),
        SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

Widget _buildProfileCard() {
  return Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15.0),
    ),
    elevation: 5,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          CircleAvatar(
            backgroundImage: AssetImage('assets/images/alipp.jpg'),
            radius: 40,
          ),
          SizedBox(height: 8),
          Text('Ali İhsan', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}
