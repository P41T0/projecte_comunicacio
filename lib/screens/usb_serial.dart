import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'dart:typed_data';

class UsbPage extends StatefulWidget {
  const UsbPage({super.key});
  @override
  UsbPageState createState() => UsbPageState();
}

class UsbPageState extends State<UsbPage> {
  UsbPort? _port;
  late final List<String> _data = [];
  Stream<String>? _stream;
  String error = "";
  String buttonMessage = "Connecta a l'arduino";
  bool arduinoConnected = false;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    connectaAArduino();
  }

  Future<void> connectaAArduino() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (arduinoConnected == false) {
      if (devices.isEmpty) {
        setState(() {
          error = "No s'ha trobat cap dispositiu.";
        });
        return;
      }
      _port = await devices[0].create();
      if (!await _port!.open()) {
        setState(() {
          error = "No s'ha pogut obrir el port.";
        });
        return;
      }

      await _port!.setDTR(true);
      await _port!.setRTS(true);
      await _port!.setPortParameters(
        9600,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _stream = _port!.inputStream!.map((data) {
        return String.fromCharCodes(data);
      });

      _stream!.listen((String data) {
        setState(() {
          if (data != "") {
            _data.add(data);
          }
          error = "";
          buttonMessage = 'Desconnecta de ${devices[0].productName}';
        });
        arduinoConnected = true;
      });
    } else {
      if (devices.isNotEmpty) {
        await _port!.close();
        setState(() {
          buttonMessage = 'Torna a connectar a ${devices[0].productName}';
          if (_data.isNotEmpty) {
            _data.removeRange(0, _data.length);
          }
        });
        arduinoConnected = false;
      } else {
        setState(() {
          buttonMessage = "Connecta a l'arduino";
          if (_data.isNotEmpty) {
            _data.removeRange(0, _data.length);
          }
        });
        arduinoConnected = false;
      }
    }
  }

  void enviaDadesAArduino(String dades) {
    if (_port != null && arduinoConnected) {
      String fulldades = "$dades\n";
      _port!.write(Uint8List.fromList(fulldades.codeUnits));
    }
  }

  @override
  void dispose() {
    _port?.close();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("Prova ping Arduino")),
        body: Container(
          margin: const EdgeInsets.all(20.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.extended(
                  label: Text(buttonMessage),
                  onPressed: connectaAArduino,
                  extendedPadding: EdgeInsets.all(20),
                ),
                Text(error),
                Text(
                  'Dades rebudes des de Arduino:',
                  style: TextStyle(fontSize: 20),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 20,
                      bottom: 20,
                      top: 30,
                    ),
                    itemCount: _data.length,
                    itemBuilder: (context, index) {
                      return Card(child: ListTile(title: Text(_data[index])));
                    },
                  ),
                ),
                TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    labelText: "Envia dades a l'Arduino",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      enviaDadesAArduino(_textController.text);
                      _textController.clear(); // Neteja el camp de text després d'enviar
                    }
                  },
                  child: Text("Envia dades"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
