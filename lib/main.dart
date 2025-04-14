import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'dart:async';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provacomunicacio2/native_log_helper.dart';
import 'package:provacomunicacio2/screens/chat.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:xmpp_plugin/ennums/xmpp_connection_state.dart';
import 'package:xmpp_plugin/error_response_event.dart';
import 'package:xmpp_plugin/models/chat_state_model.dart';
import 'package:xmpp_plugin/models/connection_event.dart';
import 'package:xmpp_plugin/models/message_model.dart';
import 'package:xmpp_plugin/models/present_mode.dart';
import 'package:xmpp_plugin/success_response_event.dart';
import 'package:xmpp_plugin/xmpp_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: const MyHomePage(title: 'ChatApp'),
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
  @override
  void initState() {
    checkStoragePermission();
    XmppConnection.addListener(this);
    super.initState();
    log('didChangeAppLifecycleState() initState');
    WidgetsBinding.instance.addObserver(this);
  }

  void checkStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      final PermissionStatus permissionStatus =
          await Permission.storage.request();
      if (permissionStatus.isGranted) {
        String filePath = await NativeLogHelper().getDefaultLogFilePath();
        if (kDebugMode) {
          print('logFilePath: $filePath');
        }
      } else {
        if (kDebugMode) {
          print('logFilePath: please allow permission');
        }
      }
    } else {
      String filePath = await NativeLogHelper().getDefaultLogFilePath();
      if (kDebugMode) {
        print('logFilePath: $filePath');
      }
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
        // TODO: Handle this case.
        throw UnimplementedError();
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
    setState(() {
      switch (connectionEvent.type) {
        case XmppConnectionState.authenticated:
          connectionStatus = 'Autenticat'; // Connexió exitosa
          userSessionStarted = true;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Usuari autenticat")));
          break;
        case XmppConnectionState.disconnected:
          connectionStatus = 'Desconnectat'; // Connexió desconnectada
          userSessionStarted = false;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Usuari desconnectat")));
          break;
        case XmppConnectionState.failed:
          connectionStatus = 'Error de connexió'; // Error durant la connexió
          userSessionStarted = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Error de connexió. Assegura't d'haver introduït les dades correctament",
              ),
            ),
          );
          break;
        default:
          connectionStatus = 'Estat desconegut'; // Altres estats
          userSessionStarted = false;
      }
    });

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

  Future<void> connect() async {
    host = _nomUsuariController.text.split("@")[1];
    final auth = {
      "user_jid":
          "${_nomUsuariController.text}/${Platform.isAndroid ? "Android" : "iOS"}",
      "password": _contrasenyaController.text,
      "host": host,
      "port": '5222',
      "nativeLogFilePath": NativeLogHelper.logFilePath,
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
    await changePresenceType(presenceType, presenceMode);
  }

  void _onError(Object error) {
    // TODO : Handle the Error event
    if (kDebugMode) {
      print("Error: ${error.toString()}");
    }
  }

  Future<void> changePresenceType(presenceType, presenceMode) async {
    await flutterXmpp.changePresenceType(presenceType, presenceMode);
  }

  void checkConnection() {
    if (connectionStatus == 'Autenticat') {
      disconnectXMPP();
    } else {
      setState(() {
        _nomUsuariController.text = _nomUsuariController.text.trim();
      });
      if (_nomUsuariController.text.trim() == "") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No s'ha introduit cap usuari.")),
        );
        return;
      } else if (_contrasenyaController.text.trim() == "") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No s'ha introduït cap contrasenya.")),
        );
        return;
      } else if (!esUnCorreuElectr(_nomUsuariController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "L'usuari introduït no correspon a un correu electrònic",
            ),
          ),
        );
        return;
      } else {
        connect();
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
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: Column(
            // Column is also a layout widget. It takes a list of children and
            // arranges them vertically. By default, it sizes itself to fit its
            // children horizontally, and tries to be as tall as its parent.
            //
            // Column has various properties to control how it sizes itself and
            // how it positions its children. Here we use mainAxisAlignment to
            // center the children vertically; the main axis here is the vertical
            // axis because Columns are vertical (the cross axis would be
            // horizontal).
            //
            // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
            // action in the IDE, or press "p" in the console), to see the
            // wireframe for each widget.
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Introdueix les dades de connexió',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 10),
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    TextField(
                      keyboardType: TextInputType.emailAddress,
                      controller: _nomUsuariController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Usuari',
                        hintText: 'usuari@servidor.com',
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _contrasenyaController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Contrasenya',
                        hintText: '***********',
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  checkConnection();
                },
                child: Text(
                  connectionStatus == 'Autenticat'
                      ? 'Desconnectar'
                      : 'Connectar',
                ),
              ),

              Text("Estat: $connectionStatus"),
              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Visibilitat:"),
                  SizedBox(width: 10),
                  DropdownButton(
                    value: presenceType,
                    items:
                        presenceTypeItems.map((String items) {
                          return DropdownMenuItem(
                            value: items,
                            child: Text(items),
                          );
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
              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Estat:"),
                  SizedBox(width: 10),
                  DropdownButton(
                    value: presenceMode,
                    items:
                        presenceModeitems.map((String items) {
                          return DropdownMenuItem(
                            value: items,
                            child: Text(items),
                          );
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
                child: Column(
                  children: [
                    TextField(
                      keyboardType: TextInputType.emailAddress,
                      controller: _destinatariController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Nom del destinatari',
                        hintText: 'destinatari@servidor.com',
                      ),
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              ),
              ElevatedButton(
                child: Text('Chat'),
                onPressed: () {
                  if (userSessionStarted == false) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Inicia la sessió per a poder enviar missatges',
                        ),
                      ),
                    );
                    return;
                  }
                  if (_destinatariController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('El camp del destinatari està buit'),
                      ),
                    );
                    return;
                  } else if (!esUnCorreuElectr(_destinatariController.text)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "El text introduit en el destinatari no correspon a un correu electrònic",
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ChatPage(
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
        ),
        // This trailing comma makes auto-formatting nicer for build methods.
      ),
    );
  }
}
