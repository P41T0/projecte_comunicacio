import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xmpp_plugin/error_response_event.dart';
import 'package:xmpp_plugin/models/chat_state_model.dart';
import 'package:xmpp_plugin/models/connection_event.dart';
import 'package:xmpp_plugin/models/message_model.dart';
import 'package:xmpp_plugin/models/present_mode.dart';
import 'package:xmpp_plugin/success_response_event.dart';
import 'package:xmpp_plugin/xmpp_plugin.dart';
import 'dart:async';

class Message {
  String hour;
  String missatge;
  String user;
  String id;
  String status;

  Message({
    required this.hour,
    required this.missatge,
    required this.user,
    required this.id,
    required this.status,
  });
}

class ChatPage extends StatefulWidget {
  final XmppConnection xmpp; // Afegeix el camp per a l'objecte XMPP
  final String destinatari; // Afegeix el camp per al destinatari
  final String presenceMode;
  final String presenceType;

  const ChatPage({
    required this.xmpp,
    required this.destinatari,
    required this.presenceMode,
    required this.presenceType,
    super.key,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> implements DataChangeEvents {
  String _missatgeEnviar = "";
  Message m1 = Message(
    hour: "12:00",
    missatge: "Hola, aquest és un xat temporal",
    user: "other",
    id: "1",
    status: "llegit",
  );
  Message m2 = Message(
    hour: "12:01",
    missatge: "Què vol dir això?",
    user: "me",
    id: "1",
    status: "llegit",
  );
  Message m3 = Message(
    hour: "12:02",
    missatge: "Quan surtis d'aquest, el xat serà eliminat de forma permanent.",
    user: "other",
    id: "1",
    status: "llegit",
  );
  Message m4 = Message(
    hour: "12:02",
    missatge: "Què passa si no connecto el dispositiu?",
    user: "me",
    id: "1",
    status: "llegit",
  );
  Message m5 = Message(
    hour: "12:05",
    missatge:
        "Si no connectes el dispositiu, no podràs enviar missatges ni desencriptar els missatges que rebis.",
    user: "other",
    id: "1",
    status: "llegit",
  );
  Message m6 = Message(
    hour: "12:06",
    missatge: "Assegura't de tenir el dispositiu connectat.",
    user: "other",
    id: "1",
    status: "llegit",
  );
  late final List<Message> _missatges = [m1, m2, m3, m4, m5, m6];
  final ScrollController _scrollController = ScrollController();
  String destinatari = "";
  String estatDestinatari = "Desconegut";
  String estatXatDestinatari = "";
  String modeDestinatari = "Desconegut";
  String mode = "composing";
  UsbPort? _port;
  late final List<String> _data = [];
  Stream<String>? _stream;
  String buttonMessage = "Connecta a l'arduino";
  bool arduinoConnected = false;
  StreamSubscription<String>? _arduinoSubscription;

  Future<void> connectaAArduino(context) async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (devices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("No hi ha cap placa connectada")));
      return;
    }

    if (arduinoConnected == false) {
      connecta(devices[0], false);
    } else {
      connecta(null, false);
    }
  }

  Future<bool> connecta(device, desconnectant) async {
    if (_arduinoSubscription != null) {
      _arduinoSubscription!.cancel();
      _arduinoSubscription = null;
    }
    if (_port != null) {
      _port!.close();
      _port = null;
    }

    if (device == null) {
      arduinoConnected = false;
      if (desconnectant == false) {
        checkWakelock(false);
        setState(() {
          buttonMessage = "Torna a connectar al dispositiu";
        });
      }
      return true;
    }
    _port = await device.create();
    if (await (_port!.open()) != true) {
      arduinoConnected = false;
      return false;
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
    arduinoConnected = true;
    setState(() {
      buttonMessage = 'Desconnecta de ${device.productName}';
    });
    checkWakelock(true);
    // CANCEL·LA qualsevol subscripció anterior
    _arduinoSubscription?.cancel();

    // CREA el listener aquí
    _arduinoSubscription = _stream?.listen((String data) async {
      if (data.isNotEmpty) {
        setState(() {
          _data.add(data);
        });
        await enviaMissatgeXMPP(data.trim());
      }
    });

    return true;
  }

  void enviaDadesAArduino(String dades) {
    if (arduinoConnected) {
      String fulldades = "$dades\r\n";
      _port!.write(Uint8List.fromList(fulldades.codeUnits));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No s'ha pogut enviar dades a l'Arduino.")),
      );
    }
  }

  Future setPresence() async {
    await widget.xmpp.changePresenceType(
      widget.presenceType,
      widget.presenceMode,
    );
  }

  @override
  void initState() {
    super.initState();
    setPresence();
    subscribeToPresence(); // Sol·licita subscriure's a l'estat de presència
    XmppConnection.addListener(this); // Registra el listener
    connectaAArduino(context);

    // Escolta el flux de dades de l'Arduino
    _arduinoSubscription = _stream?.listen((String data) {
      setState(() {
        if (data.isNotEmpty) {
          _data.add(data);
        }
      });
    });
  }

  @override
  void dispose() {
    XmppConnection.removeListener(this);
    _arduinoSubscription?.cancel();
    checkWakelock(false);
    super.dispose();
    connecta(null, true);
  }

  void checkWakelock(bool enable) async {
    bool wakelockActive = await WakelockPlus.enabled;
    if (enable) {
      if (wakelockActive == false) {
        await WakelockPlus.enable();
      }
    } else {
      if (wakelockActive == true) {
        await WakelockPlus.disable();
      }
    }
  }

  Future<void> changePresenceType(presenceType, presenceMode) async {
    await widget.xmpp.changePresenceType(presenceType, presenceMode);
  }

  void setMissatge(resposta, user) {
    DateTime hora = DateTime.now();
    String horaFormatada =
        "${hora.hour}:${hora.minute < 10 ? "0${hora.minute}" : hora.minute}";
    Message missatge = Message(
      hour: horaFormatada,
      missatge: resposta, // Utilitza la resposta de l'Arduino
      user: user,
      status: "enviant",
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    setState(() {
      _missatges.add(missatge);
    });
  }

  Future<void> enviaMissatgeXMPP(resposta) async {
    // Afegeix el missatge processat a la llista local
    setMissatge(resposta, "me");

    // Envia el missatge processat a través de XMPP
    int id = DateTime.now().millisecondsSinceEpoch;
    if (kDebugMode) {
      print("missatge$resposta");
    }
    await widget.xmpp.sendMessageWithType(
      widget.destinatari,
      resposta, // Envia la resposta de l'Arduino
      "$id",
      DateTime.now().millisecondsSinceEpoch,
    );

    // Notifica que estàs actiu després d'enviar el missatge
    enviarEstatEscrivint("active");

    // Neteja el camp de text
    _messageController.clear();
    _desplacarAbaix();
  }

  Future<void> _sendMessage(context) async {
    enviarEstatEscrivint("active");
    _missatgeEnviar = _messageController.text;

    if ((_missatgeEnviar.trim()) != "") {
      try {
        enviaMissatgeXMPP(_messageController.text);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error en enviar el missatge: $e")),
        );
      }
    }
  }

  void _desplacarAbaix() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void connectArduinoFunction() {
    try {
      if (arduinoConnected == false) {
        connectaAArduino(context);
      } else {
        _port!.close();
        setState(() {
          buttonMessage = 'Torna a connectar a la placa';
          arduinoConnected = false;
        });
        checkWakelock(false);
        if (kDebugMode) {
          print("Port USB tancat correctament.");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error en tancar el port USB: $e");
      }
    }
  }

  void _desencriptarMissatge(int index, context) async {
    try {
      // Espera la resposta desencriptada de l'Arduino
      if (arduinoConnected == true) {
        // Envia el missatge xifrat a l'Arduino
        enviaDadesAArduino(_missatges[index].missatge);
        if (kDebugMode) {
          print("Missatge desencriptat: ${_missatges[index].missatge}");
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "No es pot enviar el missatge a la placa. Assegura't que estigui ben connectada",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error en desencriptar el missatge $e")),
      );
    }
  }

  @override
  void onChatMessage(MessageChat messageChat) {
    if ((messageChat.type)?.toLowerCase() == "ack") {
      for (var message in _missatges) {
        if (message.id == messageChat.id) {
          setState(() {
            message.status = "enviat"; // Marca el missatge com a llegit
          });
        }
      }
    }
    if (kDebugMode) {
      print("tipus   ${messageChat.type} : ${messageChat.chatStateType}");
    }
    if ((messageChat.type)?.toLowerCase() == "message" ||
        (messageChat.type)?.toLowerCase() == "chatstate") {
      if (messageChat.chatStateType == "composing") {
        setState(() {
          estatXatDestinatari = "${widget.destinatari} esta escrivint...";
        });
        if (kDebugMode) {
          print("està escrivint");
        }
      } else if (messageChat.chatStateType == "paused") {
        setState(() {
          estatXatDestinatari = "${widget.destinatari} ha deixat d'escriure";
        });
      } else if (messageChat.chatStateType == "inactive") {
        setState(() {
          estatXatDestinatari = "";
        });
      } else if (messageChat.chatStateType == "gone") {
        if (kDebugMode) {
          print("ha marxat");
        }
      }
      if (kDebugMode) {
        print(
          "estatus: ${messageChat.chatStateType} ${messageChat.toString()}",
        );
      }
      if (messageChat.chatStateType == "active" ||
          messageChat.chatStateType == "") {
        setState(() {
          estatXatDestinatari = "";
        });
        if (messageChat.body != null && messageChat.body!.trim().isNotEmpty) {
          // Afegeix el missatge rebut a la llista de missatges
          setMissatge(messageChat.body, messageChat.from.toString());
          sendReceipt(messageChat);
          if (arduinoConnected) {
            _desencriptarMissatge(_missatges.length - 1, context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "No s'ha pogut desencriptar el missatge automaticament perquè la placa no està connectada",
                ),
              ),
            );
          }
        }
      }
    }

    // Opcional: Mostra el missatge a la consola per depuració
    if (kDebugMode) {
      print("Missatge rebut de ${messageChat.from}: ${messageChat.body}");
    }

    // Desplaça la vista cap avall per mostrar el nou missatge
    _desplacarAbaix();
  }

  void sendReceipt(MessageChat messageChat) async {
    widget.xmpp.sendDelieveryReceipt(
      messageChat.from.toString(),
      messageChat.id.toString(),
      true.toString(),
    );
  }

  @override
  void onChatStateChange(ChatState chatState) {
    if (kDebugMode) {
      print('onChatStateChange ~~>>$chatState');
    }
  }

  @override
  void onConnectionEvents(ConnectionEvent connectionEvent) {
    // TODO: implement onConnectionEvents
  }

  @override
  void onGroupMessage(MessageChat messageChat) {
    // TODO: implement onGroupMessage
  }

  @override
  void onNormalMessage(MessageChat messageChat) {
    // TODO: implement onNormalMessage
  }

  @override
  void onPresenceChange(PresentModel presentModel) {
    if (presentModel.from!.contains("/")) {
      destinatari = presentModel.from!.split("/")[0];
    } else {
      destinatari = presentModel.from!;
    }
    if (widget.destinatari == destinatari) {
      setState(() {
        estatDestinatari = presentModel.presenceType.toString();
        modeDestinatari = presentModel.presenceMode.toString();
      });
    }
    if (kDebugMode) {
      print(
        "Presència de $destinatari: Type: $estatDestinatari, Mode: $modeDestinatari",
      );
    }
  }

  @override
  void onSuccessEvent(SuccessResponseEvent successResponseEvent) {
    if (successResponseEvent.type.toString() == "message_read_receipt") {
      // Actualitza l'estat del missatge a "llegit"

      for (var message in _missatges) {
        if (message.id.toString() == successResponseEvent.toString()) {
          setState(() {
            message.status = "llegit"; // Marca el missatge com a llegit
          });
        }
      }

      // Opcional: Mostra un missatge a la consola
    }
  }

  @override
  void onXmppError(ErrorResponseEvent errorResponseEvent) {
    // TODO: implement onXmppError
  }

  void onNewMessage(message) {
    // Afegeix el missatge rebut a la llista de missatges
    // Desplaça la vista cap avall per mostrar el nou missatge
    _desplacarAbaix();
  }

  void enviarEstatEscrivint(String estat) async {
    if (mode != estat) {
      setState(() {
        mode = estat;
      });
      await widget.xmpp.changeTypingStatus(widget.destinatari, estat);
      if (kDebugMode) {
        print("Estat de xat enviat: $estat");
      }
    }
  }

  Future<void> subscribeToPresence() async {
    await widget.xmpp.createRoster(widget.destinatari);
    if (kDebugMode) {
      print("Sol·licitud de subscripció enviada a ${widget.destinatari}");
    }
  }

  final _messageController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          spacing: 10,
          children: [
            CircleAvatar(
              child: Text(
                widget.destinatari[0].toUpperCase(),
              ), // Inicial del destinatari
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (widget.destinatari.toUpperCase()).length < 25
                      ? widget.destinatari
                      : "${widget.destinatari.substring(0, 23)}...",
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  estatDestinatari == "PresenceType.available"
                      ? modeDestinatari == "PresenceMode.available"
                          ? "Disponible"
                          : modeDestinatari == "PresenceMode.unavailable"
                          ? "Fora de línia"
                          : modeDestinatari == "PresenceMode.dnd"
                          ? "Ocupat"
                          : modeDestinatari == "PresenceMode.away"
                          ? "Absent"
                          : modeDestinatari == "PresenceMode.xa"
                          ? "Absent durant un temps"
                          : "Estat desconegut"
                      : "",
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        modeDestinatari == "PresenceMode.available"
                            ? Colors.green
                            : modeDestinatari == "PresenceMode.unavailable"
                            ? Colors.red
                            : modeDestinatari == "PresenceMode.dnd"
                            ? Colors.red
                            : modeDestinatari == "PresenceMode.away"
                            ? Colors.orange
                            : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          spacing: 10,
          children: <Widget>[
            ElevatedButton(
              onPressed: () => {connectArduinoFunction()},
              child: Text(buttonMessage),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _missatges.length,
                itemBuilder: (context, index) {
                  bool itsMe = _missatges[index].user == "me" ? true : false;
                  return Align(
                    alignment:
                        itsMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Card(
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          vertical: 5,
                          horizontal: 5,
                        ),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              itsMe ? Colors.orange[100] : Colors.orange[200],
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                            bottomLeft:
                                itsMe ? Radius.circular(20) : Radius.zero,
                            bottomRight:
                                itsMe ? Radius.zero : Radius.circular(20),
                          ),
                        ),
                        alignment: Alignment.center,
                        width: MediaQuery.of(context).size.width * 0.75,
                        child: Column(
                          crossAxisAlignment:
                              itsMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                          children: [
                            Text(
                              _missatges[index].missatge,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.normal,
                                color: Colors.black,
                              ),
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              spacing: 10,
                              children: [
                                Text(
                                  _missatges[index].hour,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                if (_missatges[index].user == "me")
                                  Icon(
                                    _missatges[index].status == "enviat"
                                        ? Icons.done_all
                                        : Icons.done,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Column(
              children: [
                Text(estatXatDestinatari),
                SizedBox(height: 10),
                Row(
                  spacing: 15,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 225,
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(),
                          labelText: "Escriu un missatge",
                        ),
                        onChanged: (text) {
                          if (text.isNotEmpty) {
                            enviarEstatEscrivint(
                              "composing",
                            ); // Notifica que estàs escrivint
                          } else {
                            enviarEstatEscrivint(
                              "paused",
                            ); // Notifica que has deixat d'escriure
                          }
                        },
                        onEditingComplete: () {
                          _sendMessage(context);
                          // Notifica que estàs actiu
                        },
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _sendMessage(context),
                      child: Text('Enviar'),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
