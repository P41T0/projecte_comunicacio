import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'dart:async';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tunneling/screens/chat.dart';
import 'package:xmpp_plugin/ennums/xmpp_connection_state.dart';
import 'package:xmpp_plugin/error_response_event.dart';
import 'package:xmpp_plugin/models/chat_state_model.dart';
import 'package:xmpp_plugin/models/connection_event.dart';
import 'package:xmpp_plugin/models/message_model.dart';
import 'package:xmpp_plugin/models/present_mode.dart';
import 'package:xmpp_plugin/success_response_event.dart';
import 'package:xmpp_plugin/xmpp_plugin.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tunneling',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: const MyHomePage(title: 'Tunneling'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with WidgetsBindingObserver
    implements DataChangeEvents {
  static late XmppConnection flutterXmpp;
  String connectionStatus = 'Desconnectat';
  bool userSessionStarted = false;
  static const _storage = FlutterSecureStorage();
  String username = "";
  bool isAuthenticating = false;
  @override
  void initState() {
    super.initState();
    XmppConnection.addListener(this);
    _attemptAutoLogin();
    log('didChangeAppLifecycleState() initState');
    WidgetsBinding.instance.addObserver(this);
  }

  void mostraSnackBar(String missatge) {
    if (mounted == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(missatge)));
    }
  }

  Future<void> _attemptAutoLogin() async {
    String password = "";
    String user = "";

    if (await _storage.read(key: "username") != null) {
      user = (await _storage.read(key: "username"))!;
    }
    if (await _storage.read(key: "password") != null) {
      password = (await _storage.read(key: "password"))!;
    }
    if (user != "" && password != "") {
      if (await _storage.read(key: "lastContact") != null) {
        _destinatariController.text = (await _storage.read(
          key: "lastContact",
        ))!;
      }
      setState(() {
        username = user;
        isAuthenticating = true;
      });
      connect(username, password);
    }
  }

  @override
  void dispose() {
    XmppConnection.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    log('didChangeAppLifecycleState() dispose');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log('didChangeAppLifecycleState()');
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        log('detachedCallBack()');
        break;
      case AppLifecycleState.resumed:
        log('resumed detachedCallBack()');
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void onChatMessage(MessageChat messageChat) {
    // TODO: implement onChatMessage
  }

  @override
  void onChatStateChange(ChatState chatState) {
    // TODO: implement onChatStateChange
  }

  @override
  void onConnectionEvents(ConnectionEvent connectionEvent) {
    switch (connectionEvent.type) {
      case (XmppConnectionState.authenticated):
        mostraSnackBar("Usuari autenticat");
        setState(() {
          connectionStatus = 'Autenticat'; // Connexió exitosa
          userSessionStarted = true;
          isAuthenticating = false;
          if (username != _nomUsuariController.text &&
              _nomUsuariController.text != "") {
            username = _nomUsuariController.text;

            _destinatariController.text = "";
          }
        });
        _storage.write(key: "username", value: _nomUsuariController.text);
        _storage.write(key: "password", value: _contrasenyaController.text);
        _storage.write(key: "lastContact", value: "");
        break;

      case (XmppConnectionState.disconnected):
        _storage.write(key: "username", value: "");
        _storage.write(key: "password", value: "");
        _storage.write(key: "lastContact", value: "");
        setState(() {
          isAuthenticating = false;
          connectionStatus = 'Desconnectat'; // Connexió desconnectada
          if (_contrasenyaController.text != "") {
            _contrasenyaController.text = "";
          }
          userSessionStarted = false;
        });
        mostraSnackBar("Usuari desconnectat");
        break;

      case (XmppConnectionState.failed):
        if (kDebugMode) {
          print("Estat de connexió: Error de connexió");
        }
        setState(() {
          connectionStatus = 'Error de connexió';
          isAuthenticating = false;
        });
        mostraSnackBar(
          !userSessionStarted
              ? "Error al realitzar la connexió. Assegura't d'haver introduït les dades correctament i hi hagi connexió a Internet"
              : "Error de connexió. Comprova la teva connexió a Internet",
        );
        break;
      case null:
        break;
      case XmppConnectionState.connected:
        break;
      case XmppConnectionState.connecting:
        break;
    }

    // Opcional: Mostra un missatge a la consola per depuració
    if (kDebugMode) {
      print('Estat de connexió: ${connectionEvent.type}');
    }
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
  void onPresenceChange(PresentModel message) {
    // TODO: implement onPresenceChange
  }

  @override
  void onSuccessEvent(SuccessResponseEvent successResponseEvent) {
    // TODO: implement onSuccessEvent
  }

  @override
  void onXmppError(ErrorResponseEvent errorResponseEvent) {
    // TODO: implement onXmppError
  }

  final TextEditingController _nomUsuariController = TextEditingController();
  final TextEditingController _contrasenyaController = TextEditingController();
  final TextEditingController _destinatariController = TextEditingController();
  String host = "exemple.com";

  Future<bool> checkInternetConnectivity() async {
    final List<ConnectivityResult> connectivityResults = await (Connectivity()
        .checkConnectivity());
    if (connectivityResults.contains(ConnectivityResult.none)) {
      return false;
    } else {
      return true;
    }
  }

  Future<void> connect(String user, String password) async {
    bool isConnected = await checkInternetConnectivity();
    if (isConnected) {
      isAuthenticating = true;
      host = user.split("@")[1];
      final auth = {
        "user_jid": "$user/${Platform.isAndroid ? "Android" : "iOS"}",
        "password": password,
        "host": host,
        "port": '5222',
        "requireSSLConnection": true,
        "autoDeliveryReceipt": false,
        "useStreamManagement": false,
        "automaticReconnection": true,
      };

      if (kDebugMode) {
        print("Intentant connectar amb: $auth");
      }

      flutterXmpp = XmppConnection(auth);
      await flutterXmpp.start(_onError);
      await flutterXmpp.login();
    } else {
      setState(() {
        connectionStatus = 'Error de connexió';
        userSessionStarted = false;
        isAuthenticating = false;
      });

      mostraSnackBar(
        "Error de connexió. Comprova la teva connexió a Internet.",
      );
    }
  }

  void _onError(Object error) {
    if (kDebugMode) {
      setState(() {
        connectionStatus = 'Error de connexió';
        userSessionStarted = false;
        isAuthenticating = false;
      });
      print("Error: ${error.toString()}");
    }
  }

  Future<void> changePresenceType(
    String presenceType,
    String presenceMode,
  ) async {
    await flutterXmpp.changePresenceType(presenceType, presenceMode);
  }

  void checkConnection() {
    if (userSessionStarted == true) {
      disconnectXMPP();
    } else {
      setState(() {
        _nomUsuariController.text = _nomUsuariController.text.trim();
      });
      if (_nomUsuariController.text.trim() == "") {
        mostraSnackBar("No s'ha introduit cap usuari.");
        return;
      } else if (_contrasenyaController.text.trim() == "") {
        mostraSnackBar("No s'ha introduït cap contrasenya.");
        return;
      } else if (!esUnCorreuElectr(_nomUsuariController.text)) {
        mostraSnackBar(
          "L'usuari introduït no correspon a un correu electrònic",
        );
        return;
      } else {
        connect(_nomUsuariController.text, _contrasenyaController.text);
      }
    }
  }

  String presenceType = 'Disponible';
  String realPresenceType = 'available';
  var presenceTypeItems = [
    'Disponible',
    'No disponible',
  ]; //available, unavailable

  ///
  String presenceMode = 'Disponible';
  String realPresenceMode = 'available';
  var presenceModeitems = [
    'En xat',
    'Disponible',
    'Absent',
    'Absent durant un temps',
    'Ocupat',
  ]; //chat, available, away, xa, dnd

  Future<void> disconnectXMPP() async => await flutterXmpp.logout();

  void changeTypeDropdown(String value) {
    if (value == "Disponible") {
      realPresenceMode = 'available';
    } else if (value == "No disponible") {
      realPresenceMode = 'unavailable';
    }
    if (userSessionStarted) {
      changePresenceType(realPresenceType, realPresenceMode);
    }
  }

  void changeModeDropdown(String value) {
    if (value == 'Disponible') {
      realPresenceMode = 'available';
    } else if (value == 'En xat') {
      realPresenceMode = 'chat';
    } else if (value == 'Absent') {
      realPresenceMode = 'away';
    } else if (value == 'Absent durant un temps') {
      realPresenceMode = 'xa';
    } else if (value == 'Ocupat') {
      realPresenceMode = 'dnd';
    }
    if (userSessionStarted) {
      changePresenceType(realPresenceType, realPresenceMode);
    }
  }

  bool esUnCorreuElectr(String email) {
    final RegExp regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    if (userSessionStarted == false) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(
            widget.title,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 20,
              children: [
                Text(
                  'Introdueix les dades de connexió',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                SizedBox(
                  width: 300,
                  child: TextField(
                    keyboardType: TextInputType.emailAddress,
                    controller: _nomUsuariController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Usuari',
                      hintText: 'usuari@servidor.com',
                    ),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _contrasenyaController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Contrasenya',
                      hintText: '***********',
                    ),
                    obscureText: true,
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    checkConnection();
                  },
                  child: Text('Connectar'),
                ),

                Text(
                  "Estat: $connectionStatus",
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                  ),
                ),
                if (isAuthenticating) // Mostra el CircularProgressIndicator si _isAuthenticating és true
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      );
    } else {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Column(
          spacing: 10,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: () async {
                checkConnection();
              },
              child: Text('Desconnectar'),
            ),
            Text(
              "Usuari: $username",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                fontSize: 20,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 10,
              children: [
                Text("Visibilitat:"),
                DropdownButton(
                  value: presenceType,
                  items: presenceTypeItems.map((String items) {
                    return DropdownMenuItem(value: items, child: Text(items));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      presenceType = val.toString();
                    });
                    changeTypeDropdown(presenceType);
                  },
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 10,
              children: [
                Text("Estat:"),
                DropdownButton(
                  value: presenceMode,
                  items: presenceModeitems.map((String items) {
                    return DropdownMenuItem(value: items, child: Text(items));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      presenceMode = val.toString();
                      changeModeDropdown(val.toString());
                    });
                  },
                ),
              ],
            ),
            SizedBox(
              width: 300,
              child: TextField(
                keyboardType: TextInputType.emailAddress,
                controller: _destinatariController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Nom del destinatari',
                  hintText: 'destinatari@servidor.com',
                ),
              ),
            ),
            ElevatedButton(
              child: Text('Chat'),
              onPressed: () {
                if (userSessionStarted == false) {
                  mostraSnackBar(
                    'Inicia la sessió per a poder enviar missatges',
                  );
                  return;
                }
                if (_destinatariController.text.trim().isEmpty) {
                  mostraSnackBar('El camp del destinatari està buit');
                  return;
                } else if (!esUnCorreuElectr(_destinatariController.text)) {
                  mostraSnackBar(
                    "El text introduit en el destinatari no correspon a un correu electrònic",
                  );
                  return;
                }
                _storage.write(
                  key: "lastContact",
                  value: _destinatariController.text,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatPage(
                      xmpp: flutterXmpp,
                      presenceType: realPresenceType,
                      presenceMode: realPresenceMode,
                      destinatari: _destinatariController.text,
                      // Passa l'objecte XMPP
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
  }
}
