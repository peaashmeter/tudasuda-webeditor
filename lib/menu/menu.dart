import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:webeditor/level_editor.dart';
import 'dart:convert';
import '../generator.dart' as generator;
import '../level.dart';
import 'menu_game.dart' as menu_game;

ValueNotifier<bool> interfaceNotifier = ValueNotifier(false);
ValueNotifier<bool> backgroundNotifier = ValueNotifier(true);
ValueNotifier<bool> isBannerLoaded = ValueNotifier(false);

class Menu extends StatefulWidget {
  const Menu({Key? key}) : super(key: key);

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  late Widget game;
  late DropzoneViewController controller;
  bool highlighted = false;

  @override
  void initState() {
    backgroundNotifier.value = true;

    game = menu_game.MenuGame(
        level: generator.generateLevel(isTimed: true, time: 1000));

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(
          color: Colors.blueGrey[900],
        ),
        Center(
          child: SizedBox(
            height: MediaQuery.of(context).size.height / 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const Expanded(
                  child: Text(
                      'Добро пожаловать в веб-редактор уровней Tuda-Suda! Здесь можно:',
                      style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(3, 3),
                              blurRadius: 3.0,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ])),
                ),
                Expanded(
                  child: MenuTab(
                    title: 'Создать новый уровень',
                    route: () => MaterialPageRoute(
                        builder: (context) => LevelEditor.level(
                              level: const Level.empty('Уровень'),
                            )),
                    icon: Icons.square_foot_rounded,
                  ),
                ),
                Expanded(
                  child: MenuTab(
                    title: 'Выбрать уровень из списка',
                    route: () => MaterialPageRoute(
                        builder: (context) => LevelEditor.level(
                              level: const Level.empty('Уровень'),
                            )),
                    icon: Icons.sort_rounded,
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width / 2,
                    child: Stack(children: [
                      DropzoneView(
                        cursor: CursorType.grab,
                        onCreated: (c) => controller = c,
                        onHover: () => setState(() {
                          highlighted = true;
                        }),
                        onLeave: () => setState(() {
                          highlighted = false;
                        }),
                        onDrop: (file) async {
                          final bytes = await controller.getFileData(file);
                          final levelBase64 =
                              const Utf8Decoder().convert(bytes);
                          final levelJson =
                              utf8.decode(base64Decode(levelBase64));
                          final json = jsonDecode(levelJson);
                          final level = Level.fromJson(json);

                          setState(() {
                            highlighted = false;
                          });

                          if (!mounted) return;
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => LevelEditor.level(
                                        level: level,
                                      )));
                        },
                      ),
                      Center(
                        child: TextField(
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 20, color: Colors.white),
                            controller: TextEditingController(
                                text:
                                    '...или просто перетащить файл уровня в это поле'),
                            enabled: false,
                            decoration: InputDecoration(
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 40),
                              disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                      color: highlighted
                                          ? Colors.green
                                          : Colors.white,
                                      width: 2)),
                            )),
                      ),
                    ]),
                  ),
                )
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class MenuTab extends StatelessWidget {
  final String title;
  final MaterialPageRoute Function() route;
  final IconData icon;
  const MenuTab(
      {Key? key, required this.title, required this.route, required this.icon})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: backgroundNotifier,
        builder: (context, bool simple, child) {
          return Material(
            color: Colors.blueGrey[900],
            child: InkWell(
              onTap: () {
                _onTap(context);
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Expanded(child: SizedBox.shrink()),
                    Expanded(
                      flex: 5,
                      child: Text(title,
                          textAlign: TextAlign.start,
                          style: !simple
                              ? const TextStyle(
                                  shadows: [],
                                  color: Colors.white,
                                  fontSize: 20)
                              : const TextStyle(shadows: [
                                  Shadow(
                                    offset: Offset(3, 3),
                                    blurRadius: 3.0,
                                    color: Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ], color: Colors.white, fontSize: 20)),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                    Expanded(
                      child: Stack(children: [
                        simple
                            ? Positioned(
                                left: 3.0,
                                top: 3.0,
                                child: Icon(
                                  icon,
                                  size: 32,
                                  color: Colors.black54,
                                ),
                              )
                            : const SizedBox.shrink(),
                        Icon(
                          icon,
                          size: 32,
                          color: Colors.white,
                        ),
                      ]),
                    ),
                    const Expanded(child: SizedBox.shrink())
                  ],
                ),
              ),
            ),
          );
        });
  }

  void _onTap(BuildContext context) {
    Navigator.push(context, route());
  }
}
