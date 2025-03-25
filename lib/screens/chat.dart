import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xmpp_plugin/error_response_event.dart';
import 'package:xmpp_plugin/models/chat_state_model.dart';
import 'package:xmpp_plugin/models/connection_event.dart';
import 'package:xmpp_plugin/models/message_model.dart';
import 'package:xmpp_plugin/models/present_mode.dart';
import 'package:xmpp_plugin/success_response_event.dart';
import 'package:xmpp_plugin/xmpp_plugin.dart'; // Importa el paquet XMPP
import 'dart:async';

class Message {
  String hour;
  String missatge;
  String user;
  String id;
  String status;
  bool encrypted;

  Message({
    required this.hour,
    required this.missatge,
    required this.user,
    required this.id,
    required this.status,
    required this.encrypted,
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
    encrypted: false,
  );
  Message m2 = Message(
    hour: "12:01",
    missatge: "Què vol dir això?",
    user: "me",
    id: "1",
    status: "llegit",
    encrypted: false,
  );
  Message m3 = Message(
    hour: "12:02",
    missatge: "Quan surtis d'aquest, el xat serà eliminat de forma permanent.",
    user: "other",
    id: "1",
    status: "llegit",
    encrypted: false,
  );
  late final List<Message> _missatges = [m1, m2, m3];
  final ScrollController _scrollController = ScrollController();
  String estatDestinatari = "Desconegut";
  String estatXatDestinatari = "";
  String modeDestinatari = "Desconegut";
  String mode = "composing";

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
  }

  @override
  void dispose() {
    XmppConnection.removeListener(
      this,
    ); // Elimina el listener quan es destrueix la pàgina
    super.dispose();
  }

  Future<void> changePresenceType(presenceType, presenceMode) async {
    await widget.xmpp.changePresenceType(presenceType, presenceMode);
  }

  Future<void> _sendMessage() async {
    enviarEstatEscrivint("active");
    _missatgeEnviar = _messageController.text;
    DateTime hora = DateTime.now();
    String horaFormatada = "${hora.hour}:${hora.minute}";

    if ((_missatgeEnviar.trim()) != "") {
      setState(() {
        // Afegeix el missatge a la llista local
        Message missatge = Message(
          hour: horaFormatada,
          missatge: _missatgeEnviar,
          user: "me",
          status: "enviant",
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          encrypted: false,
        );
        _missatges.add(missatge);
      });

      // Envia el missatge a través de XMPP
      int id = DateTime.now().millisecondsSinceEpoch;
      await widget.xmpp.sendMessageWithType(
        widget.destinatari,
        _messageController.text,
        "$id",
        DateTime.now().millisecondsSinceEpoch,
      );

      // Notifica que estàs actiu després d'enviar el missatge
      enviarEstatEscrivint("active");

      // Neteja el camp de text
      _messageController.clear();
      _desplacarAbaix();
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

  void _desencriptarMissatge(int index) {
    setState(() {
      // Exemple: Canvia el contingut del missatge a la versió desencriptada
      _missatges[index].missatge =
          "Missatge desencriptat: ${_missatges[index].missatge}";
      _missatges[index].encrypted =
          false; // Marca el missatge com a desencriptat
    });

    if (kDebugMode) {
      print("Missatge desencriptat: ${_missatges[index].missatge}");
    }
  }

  final _messageController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              child: Text(
                widget.destinatari[0].toUpperCase(),
              ), // Inicial del destinatari
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.destinatari, style: TextStyle(fontSize: 18)),
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
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _missatges.length,
                itemBuilder: (context, index) {
                  return Align(
                    alignment:
                        _missatges[index].user == "me"
                            ? Alignment.topRight
                            : Alignment.topLeft,
                    child: Card(
                      child: Container(
                        alignment: Alignment.center,
                        width: MediaQuery.of(context).size.width * 0.75,
                        child: ListTile(
                          title: Text(
                            _missatges[index].missatge,
                            style: TextStyle(
                              fontStyle:
                                  _missatges[index].encrypted
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                              color:
                                  _missatges[index].encrypted
                                      ? Colors.grey
                                      : Colors.black,
                            ),
                          ),
                          subtitle:
                              _missatges[index].user == "me"
                                  ? Row(
                                    children: [
                                      Text(_missatges[index].hour),
                                      SizedBox(width: 10),
                                      Text(_missatges[index].status),
                                    ],
                                  )
                                  : Row(
                                    children: [
                                      Text(_missatges[index].hour),
                                      SizedBox(width: 10),
                                      // Mostra el botó només si el missatge està xifrat
                                      if (_missatges[index].encrypted)
                                        ElevatedButton(
                                          onPressed:
                                              () =>
                                                  _desencriptarMissatge(index),
                                          child: Text('Desencriptar'),
                                        ),
                                    ],
                                  ),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 200,
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
                          _sendMessage();
                          // Notifica que estàs actiu
                        },
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _sendMessage,
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

  @override
  void onChatMessage(MessageChat messageChat) {
    // Comprova si el cos del missatge és buit o null
    if (messageChat.body == null || messageChat.body!.trim().isEmpty) {
      if (kDebugMode) {
        print(
          "Missatge rebut amb cos buit o null de ${messageChat.from} ${messageChat.type} ${messageChat.chatStateType}",
        );
      }
    }

    setState(() {
      if ((messageChat.type)?.toLowerCase() == "ack") {
        for (var message in _missatges) {
          if (message.id == messageChat.id) {
            message.status = "enviat"; // Marca el missatge com a llegit
          }
        }
      }
      if ((messageChat.type)?.toLowerCase() == "chatstate") {
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
        if (messageChat.chatStateType == "active") {
          setState(() {
            estatXatDestinatari = "";
          });
          for (var message in _missatges) {
            if (messageChat.id == message.id) {
              message.status = "llegit"; // Marca el missatge com a llegit
            }
          }
          if (messageChat.body != null && messageChat.body!.trim().isNotEmpty) {
            // Afegeix el missatge rebut a la llista de missatges
            _missatges.add(
              Message(
                hour: "${DateTime.now().hour}:${DateTime.now().minute}",
                missatge: messageChat.body!, // Contingut del missatge
                user:
                    messageChat.from
                        .toString(), // JID de l'usuari que envia el missatge
                id: messageChat.id.toString(), // ID del missatge
                status: "enviat", // Estat del missatge
                encrypted: true,
              ),
            );
            sendReceipt(messageChat);
          }
        }
      }
    });

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
    String from = presentModel.from ?? "desconegut";
    if(presentModel.from.toString() == widget.destinatari){
    setState(() {
      estatDestinatari = presentModel.presenceType.toString();
      modeDestinatari = presentModel.presenceMode.toString();
    });
    }
    if (kDebugMode) {
      print(
        "Presència de $from: Type: $estatDestinatari, Mode: $modeDestinatari",
      );
    }
  }

  @override
  void onSuccessEvent(SuccessResponseEvent successResponseEvent) {
    if (successResponseEvent.type.toString() == "message_read_receipt") {
      // Actualitza l'estat del missatge a "llegit"
      setState(() {
        for (var message in _missatges) {
          if (message.id.toString() == successResponseEvent.toString()) {
            message.status = "llegit"; // Marca el missatge com a llegit
          }
        }
      });

      // Opcional: Mostra un missatge a la consola
    }
  }

  @override
  void onXmppError(ErrorResponseEvent errorResponseEvent) {
    // TODO: implement onXmppError
  }

  void onNewMessage(message) {
    setState(() {
      // Afegeix el missatge rebut a la llista de missatges
      _missatges.add(
        Message(
          hour: "${DateTime.now().hour}:${DateTime.now().minute}",
          missatge: message.body, // Contingut del missatge
          user: "other", // Marca el missatge com a rebut
          id: message.id, // ID del missatge
          status: "enviat", // Estat del missatge
          encrypted: true,
        ),
      );
    });
    // Desplaça la vista cap avall per mostrar el nou missatge
    _desplacarAbaix();
  }

  void enviarEstatEscrivint(String estat) async {
    if (mode != estat) {
      setState(() {
        mode = estat;
      });
      await widget.xmpp.changeTypingStatus(widget.destinatari, estat);
    }
    if (kDebugMode) {
      print("Estat de xat enviat: $estat");
    }
  }

  Future<void> subscribeToPresence() async {
    await widget.xmpp.createRoster(widget.destinatari);
    if (kDebugMode) {
      print("Sol·licitud de subscripció enviada a ${widget.destinatari}");
    }
  }
}

String normalitzarJid(String jid) {
  return jid.split('/')[0]; // Retorna només la part abans de la barra
}
