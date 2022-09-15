import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:webeditor/panels.dart';
import 'package:webeditor/shortcuts.dart';

import 'game/directions.dart';
import 'game/impressions.dart';
import 'game/mob_handler.dart';
import 'game/mobs.dart' hide Border;
import 'game/mobs.dart' as mob_class;

import '../level.dart';

int height = 4;
int width = 4;

ValueNotifier<bool> buildBoard = ValueNotifier(false);

ValueNotifier<Mob?> selectedMob = ValueNotifier(null);
ValueNotifier<bool> isTuning = ValueNotifier(false);
ValueNotifier<bool> isDeleting = ValueNotifier(false);
ValueNotifier<bool> isCopying = ValueNotifier(false);
ValueNotifier<int> currentLayer = ValueNotifier(0);
//Impression? selectedWidgetImpression;

//Emitter? tuningStart;

int id = 0;

List<List<Cell>> cells = List.generate(height, (index) => []);
List<Mob> mobs = [];
Map<Point<int>, List<Mob?>> mobsAsMap = {};

Point<int>? playerPos;
late String title;
late int turnTime;
late String dialog;
late int turns;
late bool deathTimer;
late double boardSize;

String? titleAtLoad;

ValueNotifier<String> json = ValueNotifier('');

List<Map<Point<int>, List<Mob?>>> changeHistory = [];
ValueNotifier<int> historyPointer = ValueNotifier(0);

class LevelEditor extends StatefulWidget {
  LevelEditor({Key? key}) : super(key: key) {
    title = 'Unnamed';
    turnTime = 0;
    dialog = '';
    turns = 0;
    deathTimer = false;
    boardSize = 7.0;
    changeHistory = [
      Map.fromIterables(
          List.generate(width * height, (i) => Point(i % width, i ~/ width)),
          List.filled(width * height, List.filled(16, null)))
    ];
  }
  LevelEditor.level({Key? key, required Level level}) : super(key: key) {
    height = level.height;
    width = level.width;
    mobs = decodeMobs(level.mobs, width, height);
    mobsAsMap = mobListToMap(mobs);
    changeHistory = [Map<Point<int>, List<Mob?>>.from(mobsAsMap)];
    historyPointer = ValueNotifier(0);
    playerPos = level.playerPos;
    mobsAsMap[playerPos]![0] = Player(playerPos!);
    title = level.title;
    turnTime = level.turnTime;
    dialog = level.dialog;
    turns = level.turns;
    isTuning.value = false;
    deathTimer = level.deathTimer;
    boardSize = level.boardSize;
    //tuningStart = null;
    cells = List.generate(height, (index) => []);
    titleAtLoad = level.title;
    id = mobs.length;
  }

  @override
  State<LevelEditor> createState() => _LevelEditorState();
}

class _LevelEditorState extends State<LevelEditor> {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
            const UndoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY):
            const RedoIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyS): const LayerDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyW): const LayerUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyE): const TuningIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyC): const EyedropperIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyR): const RunLevelIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const BackIntent()
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (UndoIntent intent) => undoAction(),
          ),
          RedoIntent: CallbackAction<RedoIntent>(
              onInvoke: (RedoIntent intent) => redoAction()),
          LayerDownIntent: CallbackAction<LayerDownIntent>(
              onInvoke: (LayerDownIntent intent) => layerDownAction()),
          LayerUpIntent: CallbackAction<LayerUpIntent>(
              onInvoke: (LayerUpIntent intent) => layerUpAction()),
          TuningIntent: CallbackAction<TuningIntent>(
              onInvoke: (TuningIntent intent) => tuningAction()),
          EyedropperIntent: CallbackAction<EyedropperIntent>(
              onInvoke: (EyedropperIntent intent) => eyedropperAction()),
          RunLevelIntent: CallbackAction<RunLevelIntent>(
              onInvoke: (RunLevelIntent intent) =>
                  runLevelAction(context, _createLevelFromScratch())),
          BackIntent: CallbackAction<BackIntent>(
              onInvoke: (BackIntent intent) => backAction(context)),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            key: UniqueKey(),
            appBar: AppBar(
              backgroundColor: Colors.blueGrey[900],
              title: ValueListenableBuilder<bool>(
                  valueListenable: buildBoard,
                  builder: (BuildContext context, bool built, Widget? child) {
                    return Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    );
                  }),
              actions: [
                IconButton(
                    onPressed: () {
                      runLevelAction(context, _createLevelFromScratch());
                    },
                    icon: const Icon(Icons.play_arrow_rounded)),
                IconButton(
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return SimpleDialog(
                              backgroundColor: Colors.blueGrey[900],
                              children: const [
                                Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: ParametersForm(),
                                )
                              ],
                            );
                          });
                    },
                    icon: const Icon(Icons.settings_rounded)),
                IconButton(
                    onPressed: () => _showHelpDialog(),
                    icon: const Icon(Icons.help_outline_rounded))
              ],
              leading: IconButton(
                  onPressed: () {
                    _getCodeDialog(context);
                  },
                  icon: const Icon(Icons.download_rounded)),
            ),
            body: Builder(builder: (context) {
              return Container(
                  color: Colors.black,
                  child: ValueListenableBuilder<bool>(
                      valueListenable: buildBoard,
                      builder:
                          (BuildContext context, bool built, Widget? child) {
                        //extending mobsmap
                        Map<Point<int>, List<Mob?>> map_ = {};
                        for (var x = 0; x < width; x++) {
                          for (var y = 0; y < height; y++) {
                            map_.addAll({
                              Point<int>(x, y):
                                  List.generate(16, (index) => null)
                            });
                          }
                        }
                        for (var e in mobsAsMap.entries) {
                          map_[e.key] = e.value;
                        }
                        mobsAsMap = map_;

                        return Board(
                          key: UniqueKey(),
                        );
                      }));
            }),
            bottomNavigationBar: const BottomPanels(),
          ),
        ),
      ),
    );
  }

  void _getCodeDialog(BuildContext context) {
    var level = _createLevelFromScratch();
    var json = jsonEncode(level.toJson());
    var code = base64.encode(utf8.encode(json));

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.blueGrey[900],
            title: const Text(
              'Сохранить файл уровня на устройство',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            content: Text(code,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            actions: [
              Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                          onPressed: () {
                            final bytes = utf8.encode(code);
                            final blob = Blob([bytes]);
                            final url = Url.createObjectUrlFromBlob(blob);
                            final anchor =
                                document.createElement('a') as AnchorElement
                                  ..href = url
                                  ..style.display = 'none'
                                  ..download = '$title.txt';
                            document.body?.children.add(anchor);

                            anchor.click();

                            document.body?.children.remove(anchor);
                            Url.revokeObjectUrl(url);

                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.code_rounded),
                          label: const Text(
                            'Сохранить',
                            style: TextStyle(color: Colors.white, fontSize: 20),
                          )),
                    ]),
              )
            ],
          );
        });
  }

  Level _createLevelFromScratch() {
    mobsAsMap.removeWhere((key, value) => key.x >= width || key.y >= height);
    for (var l in mobsAsMap.values) {
      if (l.whereType<Player>().isNotEmpty) {
        playerPos = l.whereType<Player>().first.position;
        break;
      }
    }
    mobs = mobMapToList(mobsAsMap);
    return Level(
        width: width,
        height: height,
        playerPos: playerPos ?? const Point(0, 0),
        mobs: encodeMobs(mobs),
        dialog: dialog,
        turnTime: turnTime,
        deathTimer: deathTimer,
        title: title,
        boardSize: boardSize);
  }

  _showHelpDialog() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.blueGrey[900],
            title: const Text(
              'Горячие клавиши',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            content: const Text('''
Разместить блок: ЛКМ
Удалить блок: ПКМ
Отменить: Ctrl + Z
Повторить: Ctrl + Y
На слой вверх: W
На слой вниз: S
Режим редактирования: E
Режим копирования: C
Запустить уровень: R
Если не работает – переключи на английскую раскладку!
''', style: TextStyle(color: Colors.white, fontSize: 16)),
          );
        });
  }
}

class ParametersForm extends StatefulWidget {
  const ParametersForm({Key? key}) : super(key: key);

  @override
  State<ParametersForm> createState() => _ParametersFormState();
}

class _ParametersFormState extends State<ParametersForm> {
  final _formKey = GlobalKey<FormState>();
  bool deathTimer_ = deathTimer;
  double boardWidth = boardSize;

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: 400,
              width: 300,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        initialValue: title,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20),
                        decoration: InputDecoration(
                            enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white)),
                            labelText: 'editor_title'.tr(),
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            )),
                        onSaved: (value) => title = value ?? 'Unnamed',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              validator: (value) {
                                var w = int.tryParse(value!) ?? 0;
                                if (w < 1 || w > 1024) {
                                  return 'Ошибка';
                                }
                              },
                              initialValue: width.toString(),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 20),
                              decoration: InputDecoration(
                                  enabledBorder: const OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.white)),
                                  labelText: 'editor_width'.tr(),
                                  labelStyle: const TextStyle(
                                      color: Colors.white, fontSize: 16)),
                              onSaved: (value) =>
                                  width = int.tryParse(value!) ?? 4,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              validator: (value) {
                                var w = int.tryParse(value!) ?? 0;
                                if (w < 1 || w > 1024) {
                                  return 'Ошибка';
                                }
                              },
                              initialValue: height.toString(),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 20),
                              decoration: InputDecoration(
                                  enabledBorder: const OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.white)),
                                  labelText: 'editor_height'.tr(),
                                  labelStyle: const TextStyle(
                                      color: Colors.white, fontSize: 16)),
                              onSaved: (value) =>
                                  height = int.tryParse(value!) ?? 4,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            'board_width'.tr(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          ),
                          Slider(
                              value: boardWidth,
                              min: 4.0,
                              max: 10.0,
                              divisions: 12,
                              label: boardWidth.toString(),
                              onChanged: (value) {
                                setState(() {
                                  setState(() {
                                    boardWidth = value;
                                  });
                                });
                              }),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        validator: (value) {
                          var w = ((double.tryParse(
                                      value?.replaceAll(',', '.') ?? '0') ??
                                  0) *
                              1000);
                          if (w < 0 || (w != 0 && w < 300)) {
                            return 'Ошибка';
                          }
                          return null;
                        },
                        initialValue: turnTime == 0
                            ? '0'
                            : (turnTime.toDouble() / 1000).toString(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20),
                        decoration: const InputDecoration(
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white)),
                            labelText: 'Время на ход (сек)',
                            labelStyle:
                                TextStyle(color: Colors.white, fontSize: 16)),
                        onSaved: (value) => turnTime = ((double.tryParse(
                                        value?.replaceAll(',', '.') ?? '0') ??
                                    0) *
                                1000)
                            .toInt(),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const Text('Хардкор:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            )),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              deathTimer_ = !deathTimer_;
                            });
                            deathTimer = deathTimer_;
                          },
                          child: deathTimer_
                              ? const Text('Вкл')
                              : const Text('Выкл'),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        initialValue: dialog,
                        maxLines: 5,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20),
                        decoration: InputDecoration(
                            enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white)),
                            labelText: 'editor_dialog'.tr(),
                            labelStyle: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                        onSaved: (value) => dialog = value ?? 'dialog',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // TextFormField(
            //     onSaved: (value) => turnTime = int.tryParse(value!) ?? 0,
            //     keyboardType: TextInputType.number,
            //     decoration: const InputDecoration(hintText: 'turnTime')),

            // TextFormField(
            //     onSaved: (value) => turns = int.tryParse(value!) ?? 0,
            //     keyboardType: TextInputType.number,
            //     decoration: const InputDecoration(hintText: 'turns')),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    boardSize = boardWidth;

                    buildBoard.value = !buildBoard.value;

                    Navigator.pop(context);
                  }
                },
                child: Text('editor_save'.tr()),
              ),
            )
          ],
        ));
  }
}

class TimedDoorForm extends StatefulWidget {
  final TimedDoor mob;
  const TimedDoorForm({Key? key, required this.mob}) : super(key: key);

  @override
  State<TimedDoorForm> createState() => _TimedDoorFormState();
}

class _TimedDoorFormState extends State<TimedDoorForm> {
  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 100,
                child: TextFormField(
                  validator: (value) {
                    if ((int.tryParse(value!) ?? 0) < 1) {
                      return 'Ошибка';
                    }
                    return null;
                  },
                  onSaved: (newValue) {
                    widget.mob.id = int.tryParse(newValue ?? '1') ?? id;
                  },
                  keyboardType: TextInputType.number,
                  initialValue: widget.mob.id.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      labelText: 'Id',
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      )),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                validator: (value) {
                  if ((int.tryParse(value!) ?? 0) < 1) {
                    return 'Ошибка';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
                initialValue: widget.mob.turns.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: const InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    labelText: 'Таймер',
                    labelStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    )),
                onSaved: (value) =>
                    widget.mob.turns = int.tryParse(value ?? '1') ?? 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                  keyboardType: TextInputType.number,
                  initialValue: widget.mob.connectedTo.isNotEmpty
                      ? widget.mob.connectedTo.first.toString() != '-1'
                          ? widget.mob.connectedTo.first.toString()
                          : ''
                      : '',
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      labelText: 'Соединение',
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      )),
                  onSaved: (value) {
                    if (value != '' && widget.mob.connectedTo.isNotEmpty) {
                      widget.mob.connectedTo[0] = int.parse(value!);
                      return;
                    } else if (value != '') {
                      widget.mob.connectedTo.add(int.parse(value!));
                    }
                  }),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    buildBoard.value = !buildBoard.value;
                    Navigator.pop(context);
                  }
                },
                child: Text('editor_save'.tr()),
              ),
            )
          ],
        ));
  }
}

class AnnihilatorForm extends StatefulWidget {
  final Annihilator mob;
  const AnnihilatorForm({Key? key, required this.mob}) : super(key: key);

  @override
  State<AnnihilatorForm> createState() => _AnnihilatorFormState();
}

class _AnnihilatorFormState extends State<AnnihilatorForm> {
  final _formKey = GlobalKey<FormState>();
  late Directions direction;
  @override
  void initState() {
    direction = widget.mob.direction;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 100,
                child: TextFormField(
                  validator: (value) {
                    if ((int.tryParse(value!) ?? 0) < 1) {
                      return 'Ошибка';
                    }
                    return null;
                  },
                  onSaved: (newValue) {
                    widget.mob.id = int.tryParse(newValue ?? '1') ?? id;
                  },
                  keyboardType: TextInputType.number,
                  initialValue: widget.mob.id.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      labelText: 'Id',
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      )),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                validator: (value) {
                  if ((int.tryParse(value!) ?? 0) < 1) {
                    return 'Ошибка';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
                initialValue: widget.mob.turns.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: const InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    labelText: 'Перезарядка',
                    labelStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    )),
                onSaved: (value) =>
                    widget.mob.turns = int.tryParse(value ?? '1') ?? 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                validator: (value) {
                  if ((int.tryParse(value!) ?? -1) < 0) {
                    return 'Ошибка';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
                initialValue: widget.mob.charge.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: const InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    labelText: 'Заряд',
                    labelStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    )),
                onSaved: (value) =>
                    widget.mob.charge = int.tryParse(value ?? '1') ?? 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                  keyboardType: TextInputType.number,
                  initialValue: widget.mob.connectedTo.isNotEmpty
                      ? widget.mob.connectedTo.first.toString() != '-1'
                          ? widget.mob.connectedTo.first.toString()
                          : ''
                      : '',
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      labelText: 'Соединение',
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      )),
                  onSaved: (value) {
                    if (value != '' && widget.mob.connectedTo.isNotEmpty) {
                      widget.mob.connectedTo[0] = int.parse(value!);
                      return;
                    } else if (value != '') {
                      widget.mob.connectedTo.add(int.parse(value!));
                    }
                  }),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButtonFormField(
                value: direction,
                dropdownColor: Colors.blueGrey[900],
                decoration: const InputDecoration(
                    disabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    labelText: 'Направление',
                    labelStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    )),
                items: const [
                  DropdownMenuItem<Directions>(
                      value: Directions.left,
                      child: Text(
                        'Налево',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<Directions>(
                      value: Directions.up,
                      child: Text(
                        'Вверх',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<Directions>(
                      value: Directions.right,
                      child: Text(
                        'Направо',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<Directions>(
                      value: Directions.down,
                      child: Text(
                        'Вниз',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      )),
                ],
                onChanged: (Directions? newDir) {
                  direction = newDir ?? direction;
                },
                onSaved: (newValue) {
                  widget.mob.direction = direction;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    buildBoard.value = !buildBoard.value;
                    Navigator.pop(context);
                  }
                },
                child: Text('editor_save'.tr()),
              ),
            )
          ],
        ));
  }
}

class RepeaterForm extends StatefulWidget {
  final Repeater mob;
  const RepeaterForm({Key? key, required this.mob}) : super(key: key);

  @override
  State<RepeaterForm> createState() => _RepeaterFormState();
}

class _RepeaterFormState extends State<RepeaterForm> {
  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 100,
                child: TextFormField(
                  validator: (value) {
                    if ((int.tryParse(value!) ?? 0) < 1) {
                      return 'Ошибка';
                    }
                    return null;
                  },
                  onSaved: (newValue) {
                    widget.mob.id = int.tryParse(newValue ?? '1') ?? id;
                  },
                  keyboardType: TextInputType.number,
                  initialValue: widget.mob.id.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      labelText: 'Id',
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      )),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                validator: (value) {
                  if ((int.tryParse(value!) ?? 0) < 1) {
                    return 'Ошибка';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
                initialValue: widget.mob.repeat.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: const InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    labelText: 'Повторения',
                    labelStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    )),
                onSaved: (value) =>
                    widget.mob.repeat = int.tryParse(value ?? '1') ?? 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                  keyboardType: TextInputType.number,
                  initialValue: widget.mob.connectedTo.isNotEmpty
                      ? widget.mob.connectedTo.first.toString() != '-1'
                          ? widget.mob.connectedTo.first.toString()
                          : ''
                      : '',
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      labelText: 'Соединение',
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      )),
                  onSaved: (value) {
                    if (value != '' && widget.mob.connectedTo.isNotEmpty) {
                      widget.mob.connectedTo[0] = int.parse(value!);
                      return;
                    } else if (value != '') {
                      widget.mob.connectedTo.add(int.parse(value!));
                    }
                  }),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    buildBoard.value = !buildBoard.value;
                    Navigator.pop(context);
                  }
                },
                child: Text('editor_save'.tr()),
              ),
            )
          ],
        ));
  }
}

class InfoForm extends StatefulWidget {
  final Info mob;
  const InfoForm({Key? key, required this.mob}) : super(key: key);

  @override
  State<InfoForm> createState() => _InfoFormState();
}

class _InfoFormState extends State<InfoForm> {
  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 100,
                child: TextFormField(
                  validator: (value) {
                    if ((int.tryParse(value!) ?? 0) < 1) {
                      return 'Ошибка';
                    }
                    return null;
                  },
                  onSaved: (newValue) {
                    widget.mob.id = int.tryParse(newValue ?? '1') ?? id;
                  },
                  keyboardType: TextInputType.number,
                  initialValue: widget.mob.id.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      labelText: 'Id',
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      )),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                maxLines: 5,
                validator: (value) {},
                keyboardType: TextInputType.multiline,
                initialValue: widget.mob.dialog.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: const InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    labelText: 'Диалог',
                    labelStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    )),
                onSaved: (value) => widget.mob.dialog = value ?? '',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    currentLayer.notifyListeners();
                    Navigator.pop(context);
                  }
                },
                child: Text('editor_save'.tr()),
              ),
            )
          ],
        ));
  }
}

class GateForm extends StatefulWidget {
  final Gate mob;
  const GateForm({Key? key, required this.mob}) : super(key: key);

  @override
  State<GateForm> createState() => _GateFormState();
}

class _GateFormState extends State<GateForm> {
  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 100,
                child: TextFormField(
                  validator: (value) {
                    if ((int.tryParse(value!) ?? 0) < 1) {
                      return 'Ошибка';
                    }
                    return null;
                  },
                  onSaved: (newValue) {
                    widget.mob.id = int.tryParse(newValue ?? '1') ?? id;
                  },
                  keyboardType: TextInputType.number,
                  initialValue: widget.mob.id.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      labelText: 'Id',
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      )),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    currentLayer.notifyListeners();
                    Navigator.pop(context);
                  }
                },
                child: Text('editor_save'.tr()),
              ),
            )
          ],
        ));
  }
}

class ArrowMobForm extends StatefulWidget {
  final ArrowMob mob;
  const ArrowMobForm({Key? key, required this.mob}) : super(key: key);

  @override
  State<ArrowMobForm> createState() => _ArrowMobFormState();
}

class _ArrowMobFormState extends State<ArrowMobForm> {
  final _formKey = GlobalKey<FormState>();
  late Directions direction;

  @override
  void initState() {
    super.initState();
    direction = widget.mob.direction;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 100,
                child: TextFormField(
                  validator: (value) {
                    if ((int.tryParse(value!) ?? 0) < 1) {
                      return 'Ошибка';
                    }
                    return null;
                  },
                  onSaved: (newValue) {
                    widget.mob.id = int.tryParse(newValue ?? '1') ?? id;
                  },
                  keyboardType: TextInputType.number,
                  initialValue: widget.mob.id.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      labelText: 'Id',
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      )),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButtonFormField(
                value: direction,
                dropdownColor: Colors.blueGrey[900],
                decoration: const InputDecoration(
                    disabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    labelText: 'Направление',
                    labelStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    )),
                items: const [
                  DropdownMenuItem<Directions>(
                      value: Directions.left,
                      child: Text(
                        'Налево',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<Directions>(
                      value: Directions.up,
                      child: Text(
                        'Вверх',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<Directions>(
                      value: Directions.right,
                      child: Text(
                        'Направо',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<Directions>(
                      value: Directions.down,
                      child: Text(
                        'Вниз',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      )),
                ],
                onChanged: (Directions? newDir) {
                  direction = newDir ?? direction;
                },
                onSaved: (newValue) {
                  widget.mob.direction = direction;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    currentLayer.notifyListeners();
                    Navigator.pop(context);
                  }
                },
                child: Text('editor_save'.tr()),
              ),
            )
          ],
        ));
  }
}

class RotatorForm extends StatefulWidget {
  final Rotator mob;
  const RotatorForm({Key? key, required this.mob}) : super(key: key);

  @override
  State<RotatorForm> createState() => _RotatorFormState();
}

class _RotatorFormState extends State<RotatorForm> {
  final _formKey = GlobalKey<FormState>();
  late Directions direction;

  @override
  void initState() {
    super.initState();
    direction = widget.mob.direction;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 100,
                child: TextFormField(
                  validator: (value) {
                    if ((int.tryParse(value!) ?? 0) < 1) {
                      return 'Ошибка';
                    }
                    return null;
                  },
                  onSaved: (newValue) {
                    widget.mob.id = int.tryParse(newValue ?? '1') ?? id;
                  },
                  keyboardType: TextInputType.number,
                  initialValue: widget.mob.id.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      labelText: 'Id',
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      )),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButtonFormField(
                value: direction,
                dropdownColor: Colors.blueGrey[900],
                decoration: const InputDecoration(
                    disabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    labelText: 'Направление',
                    labelStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    )),
                items: const [
                  DropdownMenuItem<Directions>(
                      value: Directions.left,
                      child: Text(
                        'Налево',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<Directions>(
                      value: Directions.up,
                      child: Text(
                        'Вверх',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<Directions>(
                      value: Directions.right,
                      child: Text(
                        'Направо',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<Directions>(
                      value: Directions.down,
                      child: Text(
                        'Вниз',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      )),
                ],
                onChanged: (Directions? newDir) {
                  direction = newDir ?? direction;
                },
                onSaved: (newValue) {
                  widget.mob.direction = direction;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    currentLayer.notifyListeners();
                    Navigator.pop(context);
                  }
                },
                child: Text('editor_save'.tr()),
              ),
            )
          ],
        ));
  }
}

class BorderForm extends StatefulWidget {
  final mob_class.Border mob;
  const BorderForm({Key? key, required this.mob}) : super(key: key);

  @override
  State<BorderForm> createState() => _BorderFormState();
}

class _BorderFormState extends State<BorderForm> {
  final _formKey = GlobalKey<FormState>();
  late int color;

  @override
  void initState() {
    super.initState();
    color = widget.mob.color;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 100,
                child: TextFormField(
                  validator: (value) {
                    if ((int.tryParse(value!) ?? 0) < 1) {
                      return 'Ошибка';
                    }
                    return null;
                  },
                  onSaved: (newValue) {
                    widget.mob.id = int.tryParse(newValue ?? '1') ?? id;
                  },
                  keyboardType: TextInputType.number,
                  initialValue: widget.mob.id.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      labelText: 'Id',
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      )),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButtonFormField(
                value: color,
                dropdownColor: Colors.blueGrey,
                decoration: const InputDecoration(
                    disabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    labelText: 'Цвет',
                    labelStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    )),
                items: [
                  const DropdownMenuItem<int>(
                      value: 0,
                      child: Text(
                        'Чёрный',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 1,
                      child: Text(
                        'Красный',
                        style: TextStyle(
                          color: Colors.red[900],
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 2,
                      child: Text(
                        'Розовый',
                        style: TextStyle(
                          color: Colors.pink[900],
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 3,
                      child: Text(
                        'Фиолетовый',
                        style: TextStyle(
                          color: Colors.purple[900],
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 4,
                      child: Text(
                        'Синий',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 5,
                      child: Text(
                        'Циан',
                        style: TextStyle(
                          color: Colors.cyan[900],
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 6,
                      child: Text(
                        'Зелёный',
                        style: TextStyle(
                          color: Colors.green[900],
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 7,
                      child: Text(
                        'Оранжевый',
                        style: TextStyle(
                          color: Colors.yellow[900],
                          fontSize: 16,
                        ),
                      )),
                ],
                onChanged: (int? newcolor) {
                  color = newcolor ?? color;
                },
                onSaved: (newValue) {
                  widget.mob.color = color;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    currentLayer.notifyListeners();
                    Navigator.pop(context);
                  }
                },
                child: Text('editor_save'.tr()),
              ),
            )
          ],
        ));
  }
}

class SwitcherForm extends StatefulWidget {
  final Switcher mob;
  const SwitcherForm({Key? key, required this.mob}) : super(key: key);

  @override
  State<SwitcherForm> createState() => _SwitcherFormState();
}

class _SwitcherFormState extends State<SwitcherForm> {
  final _formKey = GlobalKey<FormState>();
  bool isOn = false;
  late int fields;

  @override
  void initState() {
    isOn = widget.mob.isOn;
    fields = widget.mob.connectedTo.isEmpty ? 1 : widget.mob.connectedTo.length;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: 200,
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 100,
                        child: TextFormField(
                          validator: (value) {
                            if ((int.tryParse(value!) ?? 0) < 1) {
                              return 'Ошибка';
                            }
                            return null;
                          },
                          onSaved: (newValue) {
                            widget.mob.id = int.tryParse(newValue ?? '1') ?? id;
                          },
                          keyboardType: TextInputType.number,
                          initialValue: widget.mob.id.toString(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20),
                          decoration: const InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white)),
                              labelText: 'Id',
                              labelStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              )),
                        ),
                      ),
                    ),
                    ...List.generate(
                      fields,
                      (index) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                            keyboardType: TextInputType.number,
                            initialValue: widget.mob.connectedTo.length > index
                                ? widget.mob.connectedTo[index].toString() !=
                                        '-1'
                                    ? widget.mob.connectedTo[index].toString()
                                    : ''
                                : '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20),
                            decoration: InputDecoration(
                                enabledBorder: const OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white)),
                                labelText: 'Соединение ${index + 1}',
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                )),
                            onSaved: (value) {
                              if (value != '' &&
                                  widget.mob.connectedTo.length > index) {
                                widget.mob.connectedTo[index] =
                                    int.parse(value!);
                                return;
                              } else if (value != '') {
                                widget.mob.connectedTo.add(int.parse(value!));
                              }
                            }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const Text('Cостояние:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    )),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isOn = !isOn;
                    });
                  },
                  child: isOn ? const Text('Вкл') : const Text('Выкл'),
                ),
              ],
            ),
            IconButton(
                onPressed: () {
                  setState(() {
                    fields++;
                  });
                },
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white70,
                  size: 32,
                )),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();

                    widget.mob.isOn = isOn;

                    currentLayer.notifyListeners();
                    Navigator.pop(context);
                  }
                },
                child: Text('editor_save'.tr()),
              ),
            )
          ],
        ));
  }
}

class PortalForm extends StatefulWidget {
  final Portal mob;
  const PortalForm({Key? key, required this.mob}) : super(key: key);

  @override
  State<PortalForm> createState() => _PortalFormState();
}

class _PortalFormState extends State<PortalForm> {
  final _formKey = GlobalKey<FormState>();
  bool isOn = false;
  late int fields;
  late int color;

  @override
  void initState() {
    isOn = widget.mob.isOn;
    fields = widget.mob.connectedTo.isEmpty ? 1 : widget.mob.connectedTo.length;
    color = widget.mob.color;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: 200,
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 100,
                        child: TextFormField(
                          validator: (value) {
                            if ((int.tryParse(value!) ?? 0) < 1) {
                              return 'Ошибка';
                            }
                            return null;
                          },
                          onSaved: (newValue) {
                            widget.mob.id = int.tryParse(newValue ?? '1') ?? id;
                          },
                          keyboardType: TextInputType.number,
                          initialValue: widget.mob.id.toString(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20),
                          decoration: const InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white)),
                              labelText: 'Id',
                              labelStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              )),
                        ),
                      ),
                    ),
                    ...List.generate(
                      fields,
                      (index) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                            keyboardType: TextInputType.number,
                            initialValue: widget.mob.connectedTo.length > index
                                ? widget.mob.connectedTo[index].toString() !=
                                        '-1'
                                    ? widget.mob.connectedTo[index].toString()
                                    : ''
                                : '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20),
                            decoration: InputDecoration(
                                enabledBorder: const OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white)),
                                labelText: 'Соединение ${index + 1}',
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                )),
                            onSaved: (value) {
                              if (value != '' &&
                                  widget.mob.connectedTo.length > index) {
                                widget.mob.connectedTo[index] =
                                    int.parse(value!);
                                return;
                              } else if (value != '') {
                                widget.mob.connectedTo.add(int.parse(value!));
                              }
                            }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButtonFormField(
                value: color,
                dropdownColor: Colors.blueGrey,
                decoration: const InputDecoration(
                    disabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    labelText: 'Цвет',
                    labelStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    )),
                items: [
                  const DropdownMenuItem<int>(
                      value: 0,
                      child: const Text(
                        'Чёрный',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 1,
                      child: Text(
                        'Красный',
                        style: TextStyle(
                          color: Colors.red[900],
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 2,
                      child: Text(
                        'Розовый',
                        style: TextStyle(
                          color: Colors.pink[900],
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 3,
                      child: Text(
                        'Фиолетовый',
                        style: TextStyle(
                          color: Colors.purple[900],
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 4,
                      child: Text(
                        'Синий',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 5,
                      child: Text(
                        'Циан',
                        style: TextStyle(
                          color: Colors.cyan[900],
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 6,
                      child: Text(
                        'Зелёный',
                        style: TextStyle(
                          color: Colors.green[900],
                          fontSize: 16,
                        ),
                      )),
                  DropdownMenuItem<int>(
                      value: 7,
                      child: Text(
                        'Оранжевый',
                        style: TextStyle(
                          color: Colors.yellow[900],
                          fontSize: 16,
                        ),
                      )),
                ],
                onChanged: (int? newcolor) {
                  color = newcolor ?? color;
                },
                onSaved: (newValue) {
                  widget.mob.color = color;
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 100,
                    child: TextFormField(
                      validator: (value) {
                        if ((int.tryParse(value!) ?? 0) +
                                    widget.mob.position.x >=
                                width ||
                            (int.tryParse(value) ?? 0) + widget.mob.position.x <
                                0) {
                          return 'Ошибка';
                        }
                        return null;
                      },
                      onSaved: (newValue) {
                        widget.mob.xShift =
                            int.tryParse(newValue ?? '0') ?? widget.mob.xShift;
                      },
                      keyboardType: TextInputType.number,
                      initialValue: widget.mob.xShift.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      decoration: const InputDecoration(
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white)),
                          labelText: 'Сдвиг по x',
                          labelStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          )),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 100,
                    child: TextFormField(
                      validator: (value) {
                        if ((int.tryParse(value!) ?? 0) +
                                    widget.mob.position.y >=
                                height ||
                            (int.tryParse(value) ?? 0) + widget.mob.position.y <
                                0) {
                          return 'Ошибка';
                        }
                        return null;
                      },
                      onSaved: (newValue) {
                        widget.mob.yShift =
                            int.tryParse(newValue ?? '0') ?? widget.mob.yShift;
                      },
                      keyboardType: TextInputType.number,
                      initialValue: widget.mob.yShift.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      decoration: const InputDecoration(
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white)),
                          labelText: 'Сдвиг по y',
                          labelStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          )),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const Text('Cостояние:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    )),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isOn = !isOn;
                    });
                  },
                  child: isOn ? const Text('Вкл') : const Text('Выкл'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();

                    widget.mob.isOn = isOn;

                    currentLayer.notifyListeners();
                    Navigator.pop(context);
                  }
                },
                child: Text('editor_save'.tr()),
              ),
            )
          ],
        ));
  }
}

class WireForm extends StatefulWidget {
  final Wire mob;
  const WireForm({Key? key, required this.mob}) : super(key: key);

  @override
  State<WireForm> createState() => _WireFormState();
}

class _WireFormState extends State<WireForm> {
  final _formKey = GlobalKey<FormState>();
  late int fields;

  @override
  void initState() {
    fields = widget.mob.connectedTo.isEmpty ? 1 : widget.mob.connectedTo.length;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: 200,
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 100,
                        child: TextFormField(
                          validator: (value) {
                            if ((int.tryParse(value!) ?? 0) < 1) {
                              return 'Ошибка';
                            }
                            return null;
                          },
                          onSaved: (newValue) {
                            widget.mob.id = int.tryParse(newValue ?? '1') ?? id;
                          },
                          keyboardType: TextInputType.number,
                          initialValue: widget.mob.id.toString(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20),
                          decoration: const InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white)),
                              labelText: 'Id',
                              labelStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              )),
                        ),
                      ),
                    ),
                    ...List.generate(
                      fields,
                      (index) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                            keyboardType: TextInputType.number,
                            initialValue: widget.mob.connectedTo.length > index
                                ? widget.mob.connectedTo[index].toString() !=
                                        '-1'
                                    ? widget.mob.connectedTo[index].toString()
                                    : ''
                                : '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20),
                            decoration: InputDecoration(
                                enabledBorder: const OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white)),
                                labelText: 'Соединение ${index + 1}',
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                )),
                            onSaved: (value) {
                              if (value != '' &&
                                  widget.mob.connectedTo.length > index) {
                                widget.mob.connectedTo[index] =
                                    int.parse(value!);
                                return;
                              } else if (value != '') {
                                widget.mob.connectedTo.add(int.parse(value!));
                              }
                            }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
                onPressed: () {
                  setState(() {
                    fields++;
                  });
                },
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white70,
                  size: 32,
                )),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();

                    currentLayer.notifyListeners();
                    Navigator.pop(context);
                  }
                },
                child: Text('editor_save'.tr()),
              ),
            )
          ],
        ));
  }
}

class ActivatorForm extends StatefulWidget {
  final Pressure mob;
  const ActivatorForm({Key? key, required this.mob}) : super(key: key);

  @override
  State<ActivatorForm> createState() => _ActivatorFormState();
}

class _ActivatorFormState extends State<ActivatorForm> {
  final _formKey = GlobalKey<FormState>();
  late int fields;

  @override
  void initState() {
    fields = widget.mob.connectedTo.isEmpty ? 1 : widget.mob.connectedTo.length;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: 200,
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 100,
                        child: TextFormField(
                          validator: (value) {
                            if ((int.tryParse(value!) ?? 0) < 1) {
                              return 'Ошибка';
                            }
                            return null;
                          },
                          onSaved: (newValue) {
                            widget.mob.id = int.tryParse(newValue ?? '1') ?? id;
                          },
                          keyboardType: TextInputType.number,
                          initialValue: widget.mob.id.toString(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20),
                          decoration: const InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white)),
                              labelText: 'Id',
                              labelStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              )),
                        ),
                      ),
                    ),
                    ...List.generate(
                      fields,
                      (index) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                            keyboardType: TextInputType.number,
                            initialValue: widget.mob.connectedTo.length > index
                                ? widget.mob.connectedTo[index].toString() !=
                                        '-1'
                                    ? widget.mob.connectedTo[index].toString()
                                    : ''
                                : '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20),
                            decoration: InputDecoration(
                                enabledBorder: const OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white)),
                                labelText: 'Соединение ${index + 1}',
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                )),
                            onSaved: (value) {
                              if (value != '' &&
                                  widget.mob.connectedTo.length > index) {
                                widget.mob.connectedTo[index] =
                                    int.parse(value!);
                                return;
                              } else if (value != '') {
                                widget.mob.connectedTo.add(int.parse(value!));
                              }
                            }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
                onPressed: () {
                  setState(() {
                    fields++;
                  });
                },
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white70,
                  size: 32,
                )),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();

                    currentLayer.notifyListeners();
                    Navigator.pop(context);
                  }
                },
                child: Text('editor_save'.tr()),
              ),
            )
          ],
        ));
  }
}

class Board extends StatefulWidget {
  const Board({Key? key}) : super(key: key);

  @override
  State<Board> createState() => _BoardState();
}

class _BoardState extends State<Board> {
  late LinkedScrollControllerGroup _controllers;
  late List<ScrollController> horizontalControllers = [];
  late ScrollController verticalController;
  @override
  initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    for (var i = 0; i < height; i++) {
      horizontalControllers.add(_controllers.addAndGet());
    }
    verticalController = ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
        valueListenable: currentLayer,
        builder: (BuildContext context, int layer, Widget? child) {
          cells = List.generate(
              height,
              (row) => List.generate(
                  width,
                  (i) => Cell(
                      key: UniqueKey(),
                      x: i,
                      y: row,
                      child: mobsAsMap[Point(i, row)]?[layer]
                          ?.getImpression(getCellSize()))));

          List<Widget> rows = [];
          for (int k = 0; k < cells.length; k++) {
            var row = cells[k];
            var r = Center(
                child: SizedBox(
              height: 57,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: ListView(
                    shrinkWrap: true,
                    controller: horizontalControllers[k],
                    scrollDirection: Axis.horizontal,
                    children: row),
              ),
            ));
            rows.add(r);
          }
          return ScrollConfiguration(
            behavior: DragBehavior(),
            child: ListView(
                padding: const EdgeInsets.all(0.0),
                controller: verticalController,
                shrinkWrap: false,
                children: rows),
          );
        });
  }
}

class DragBehavior extends ScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        // etc.
      };
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class Cell extends StatefulWidget {
  final Widget? child;
  final int x;
  final int y;

  const Cell({Key? key, required this.child, required this.x, required this.y})
      : super(key: key);

  @override
  State<Cell> createState() => _CellState();
}

class _CellState extends State<Cell> with AutomaticKeepAliveClientMixin {
  late Widget? _child = widget.child;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: () {
        var map = newMobMap(mobsAsMap);
        setState(() {
          if (isTuning.value) {
            var mobInCell = map[Point(widget.x, widget.y)]?[currentLayer.value];
            if (mobInCell is TimedDoor) {
              //isTuning.value = false;
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      backgroundColor: Colors.blueGrey[900],
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TimedDoorForm(mob: mobInCell),
                        )
                      ],
                    );
                  }).then((value) {
                if (value != null) {
                  makeChange(map);
                }
              });
            } else if (mobInCell is Info) {
              //isTuning.value = false;
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      backgroundColor: Colors.blueGrey[900],
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: InfoForm(mob: mobInCell),
                        )
                      ],
                    );
                  }).then((value) {
                if (value != null) {
                  makeChange(map);
                }
              });
            } else if (mobInCell is Gate) {
              //isTuning.value = false;
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      backgroundColor: Colors.blueGrey[900],
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: GateForm(mob: mobInCell),
                        )
                      ],
                    );
                  }).then((value) {
                if (value != null) {
                  makeChange(map);
                }
              });
            } else if (mobInCell is Switcher) {
              // isTuning.value = false;
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      backgroundColor: Colors.blueGrey[900],
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SwitcherForm(mob: mobInCell),
                        )
                      ],
                    );
                  }).then((value) {
                if (value != null) {
                  makeChange(map);
                }
              });
            } else if (mobInCell is mob_class.Border) {
              //isTuning.value = false;
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      backgroundColor: Colors.blueGrey[900],
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: BorderForm(mob: mobInCell),
                        )
                      ],
                    );
                  }).then((value) {
                if (value != null) {
                  makeChange(map);
                }
              });
            } else if (mobInCell is Rotator) {
              //isTuning.value = false;
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      backgroundColor: Colors.blueGrey[900],
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: RotatorForm(mob: mobInCell),
                        )
                      ],
                    );
                  }).then((value) {
                if (value != null) {
                  makeChange(map);
                }
              });
            } else if (mobInCell is Repeater) {
              //isTuning.value = false;
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      backgroundColor: Colors.blueGrey[900],
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: RepeaterForm(mob: mobInCell),
                        )
                      ],
                    );
                  }).then((value) {
                if (value != null) {
                  makeChange(map);
                }
              });
            } else if (mobInCell is Annihilator) {
              //isTuning.value = false;
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      backgroundColor: Colors.blueGrey[900],
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: AnnihilatorForm(mob: mobInCell),
                        )
                      ],
                    );
                  }).then((value) {
                if (value != null) {
                  makeChange(map);
                }
              });
            } else if (mobInCell is Wire) {
              //isTuning.value = false;
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      backgroundColor: Colors.blueGrey[900],
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: WireForm(mob: mobInCell),
                        )
                      ],
                    );
                  }).then((value) {
                if (value != null) {
                  makeChange(map);
                }
              });
            } else if (mobInCell is Pressure) {
              //isTuning.value = false;
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      backgroundColor: Colors.blueGrey[900],
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ActivatorForm(mob: mobInCell),
                        )
                      ],
                    );
                  }).then((value) {
                if (value != null) {
                  makeChange(map);
                }
              });
            } else if (mobInCell is Portal) {
              //isTuning.value = false;
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      backgroundColor: Colors.blueGrey[900],
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: PortalForm(mob: mobInCell),
                        )
                      ],
                    );
                  }).then((value) {
                if (value != null) {
                  makeChange(map);
                }
              });
            } else if (mobInCell is ArrowMob) {
              //isTuning.value = false;
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      backgroundColor: Colors.blueGrey[900],
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ArrowMobForm(mob: mobInCell),
                        )
                      ],
                    );
                  }).then((value) {
                if (value != null) {
                  makeChange(map);
                }
              });
            }
          } else if (isCopying.value) {
            Point<int> pos = Point(widget.x, widget.y);
            if (map[pos]?[currentLayer.value] != null) {
              selectedMob.value = cloneMob(map[pos]![currentLayer.value]!, pos);
              isCopying.value = false;
            }
          } else if (selectedMob.value != null) {
            cells[widget.y][widget.x] =
                Cell(x: widget.x, y: widget.y, child: _child);

            _child = selectedMob.value!.getImpression(getCellSize());
            selectedMob.value!.position = Point<int>(widget.x, widget.y);
            map[Point<int>(widget.x, widget.y)]![currentLayer.value] =
                cloneMob(selectedMob.value!, selectedMob.value!.position);
            if (selectedMob.value is Player) {
              for (var p in map.entries) {
                if (p.key != Point<int>(widget.x, widget.y)) {
                  if (p.value[currentLayer.value] is Player) {
                    p.value[currentLayer.value] = null;
                  }
                }
              }
              // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
              currentLayer.notifyListeners();
            }
            makeChange(map);
          }
        });
      },
      onSecondaryTap: () {
        setState(() {
          var map = newMobMap(mobsAsMap);
          Point<int> pos = Point(widget.x, widget.y);
          map[pos]?[currentLayer.value] = null;
          _child = null;
          cells[widget.y][widget.x] =
              Cell(x: widget.x, y: widget.y, child: _child);
          makeChange(map);
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 57,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blueGrey[900],
              ),
              child: _child,
            ),
          ),
        ),
      ),
    );
  }
}

Map<Point<int>, List<Mob?>> newMobMap(Map<Point<int>, List<Mob?>> oldMobMap) {
  Map<Point<int>, List<Mob?>> map = {};
  for (var point in oldMobMap.entries) {
    Map<Point<int>, List<Mob?>> e = {};
    List<Mob?> l = List.from(point.value);
    e = {Point<int>(point.key.x, point.key.y): l};
    map.addAll(e);
  }
  return map;
}

Mob cloneMob(Mob mob, Point<int> position) {
  id++;
  if (mob.runtimeType == ArrowMob) {
    return ArrowMob.clone(mob as ArrowMob, position, id);
  } else if (mob.runtimeType == mob_class.Border) {
    return mob_class.Border.clone(mob as mob_class.Border, position, id);
  } else if (mob.runtimeType == Exit) {
    return Exit.clone(mob as Exit, position, id);
  } else if (mob.runtimeType == Rotator) {
    return Rotator.clone(mob as Rotator, position, id);
  } else if (mob.runtimeType == Switcher) {
    return Switcher.clone(mob as Switcher, position, id);
  } else if (mob.runtimeType == Gate) {
    return Gate.clone(mob as Gate, position, id);
  } else if (mob.runtimeType == TimedDoor) {
    return TimedDoor.clone(mob as TimedDoor, position, id);
  } else if (mob.runtimeType == Player) {
    return Player.clone(mob, position);
  } else if (mob.runtimeType == Info) {
    return Info.clone(mob as Info, position, id);
  } else if (mob.runtimeType == Repeater) {
    return Repeater.clone(mob as Repeater, position, id);
  } else if (mob.runtimeType == Annihilator) {
    return Annihilator.clone(mob as Annihilator, position, id);
  } else if (mob.runtimeType == Wire) {
    return Wire.clone(mob as Wire, position, id);
  } else if (mob.runtimeType == Pressure) {
    return Pressure.clone(mob as Pressure, position, id);
  } else if (mob.runtimeType == Portal) {
    return Portal.clone(mob as Portal, position, id);
  } else {
    throw Exception('Can\'t clone mob $mob');
  }
}

double getCellSize() {
  return 50.0;
}

impressionsFromLiteral(literal) {
  switch (literal) {
    case 'arrowMob':
      return Impressions.arrowMob;
    case 'exit':
      return Impressions.exit;
    case 'border':
      return Impressions.border;
    default:
      throw ('Can\'t decode mob: $literal');
  }
}

Map<Point<int>, List<Mob?>> mobListToMap(List<Mob> moblist) {
  Map<Point<int>, List<Mob?>> mobmap = {};
  for (var i = 0; i < width; i++) {
    for (var j = 0; j < height; j++) {
      mobmap[Point(i, j)] = [];
    }
  }
  for (var mob in moblist) {
    mobmap[mob.position]?.add(mob);
  }

  int maxsize = 16;
  for (var mobs_ in mobmap.values) {
    var lnull = List.generate(maxsize - mobs_.length, (index) => null);
    mobs_.addAll(lnull);
  }
  return mobmap;
}

List<Mob> mobMapToList(Map<Point, List<Mob?>> mobmap) {
  List<Mob> moblist = [];
  for (var moblist_ in mobmap.values) {
    List<Mob> l = moblist_.whereType<Mob>().where((m) => m is! Player).toList();
    moblist.addAll(l);
  }
  return moblist;
}

void makeChange(Map<Point<int>, List<Mob?>> newMap) {
  changeHistory.add(newMap);
  historyPointer.value = changeHistory.length - 1;
  if (historyPointer.value == 8) {
    List<Map<Point<int>, List<Mob?>>> last8 =
        List.from(changeHistory.getRange(1, changeHistory.length));
    changeHistory = List.from(last8);
    historyPointer.value = 7;
  } else {
    List<Map<Point<int>, List<Mob?>>> newRoot = [
      ...List.from(changeHistory.getRange(0, historyPointer.value)),
      ...[changeHistory.last]
    ];
    changeHistory = List.from(newRoot);
  }
  mobsAsMap = changeHistory.last;
}
