import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'level_editor.dart';
import 'package:easy_localization/easy_localization.dart';

import 'level.dart';

late double previewSize;
late List<Level> levelsGlobal;

class LevelList extends StatelessWidget {
  final List<Level> levels;

  final int index;

  const LevelList({Key? key, required this.levels, this.index = 0})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    previewSize = MediaQuery.of(context).size.height / 6;
    levelsGlobal = levels;

    return Scaffold(
      body: KeyboardListener(
        autofocus: true,
        focusNode: FocusNode(),
        onKeyEvent: (key) {
          if (key.logicalKey == LogicalKeyboardKey.escape &&
              key is KeyDownEvent) {
            Navigator.pop(context);
          }
        },
        child: Container(
          color: Colors.black,
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              // etc.
            }),
            child: ListView(
              children: makeLevelTabs(levels),
            ),
          ),
        ),
      ),
    );
  }

  makeLevelTabs(List<Level> l) {
    List<LevelTab> tabs = [];
    for (var l_ in l) {
      tabs.add(LevelTab(
        level: l_,
        key: UniqueKey(),
      ));
    }
    return tabs;
  }
}

class LevelTab extends StatelessWidget {
  final Level level;
  const LevelTab({Key? key, required this.level}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Material(
        child: Ink(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.blueGrey[900]!, Colors.blueGrey[800]!])),
          child: InkWell(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => LevelEditor.level(level: level)));
            },
            child: Container(
              decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(8))),
              child: Center(
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.all(Radius.circular(8))),
                      height: previewSize,
                      width: previewSize,
                      child: Center(
                        child: Preview(
                          level: level,
                          key: UniqueKey(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                        '${levelsGlobal.indexOf(level) + 1}. ${level.title.tr()}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20)),
                  ),
                ],
              )),
            ),
          ),
        ),
      ),
    );
  }
}

class Preview extends StatelessWidget {
  final Level level;
  const Preview({Key? key, required this.level}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var width = level.width;
    var height = level.height;
    var mobs = level.mobs;
    double size =
        width > height ? previewSize / (width + 1) : previewSize / (height + 1);
    List<Container> cells = List.generate(
        width * height,
        (i) => Container(
              color: Colors.blueGrey[900],
              width: size,
              height: size,
            ));
    for (var mob in mobs) {
      String literal = mob.keys.first;
      Point<int> coords = mob.values.first['position'];
      int linearCoords = coords.y * width + coords.x;
      Container impression;
      switch (literal) {
        case "arrowMob":
          impression = Container(
            color: Colors.blue[900],
            width: size,
            height: size,
          );
          break;
        case "border":
          if (mob.values.first['color'] == null) {
            impression = Container(
              color: Colors.black,
              width: size,
              height: size,
            );
            break;
          } else {
            switch (mob.values.first['color']) {
              case 1:
                impression = Container(
                  color: Colors.red[900],
                  width: size,
                  height: size,
                );
                break;
              case 2:
                impression = Container(
                  color: Colors.pink[900],
                  width: size,
                  height: size,
                );
                break;
              case 3:
                impression = Container(
                  color: Colors.purple[900],
                  width: size,
                  height: size,
                );
                break;
              case 4:
                impression = Container(
                  color: Colors.blue[900],
                  width: size,
                  height: size,
                );
                break;
              case 5:
                impression = Container(
                  color: Colors.cyan[900],
                  width: size,
                  height: size,
                );
                break;
              case 6:
                impression = Container(
                  color: Colors.green[900],
                  width: size,
                  height: size,
                );
                break;
              case 7:
                impression = Container(
                  color: Colors.yellow[900],
                  width: size,
                  height: size,
                );
                break;
              default:
                impression = Container(
                  color: Colors.black,
                  width: size,
                  height: size,
                );
                break;
            }
          }
          break;
        case "exit":
          impression = Container(
            color: Colors.green[900],
            width: size,
            height: size,
          );
          break;
        case "rotator":
          impression = Container(
            color: Colors.purple[900],
            width: size,
            height: size,
          );
          break;
        case "switcher":
          impression = Container(
            color: Colors.yellow,
            width: size,
            height: size,
          );
          break;

        case "info":
          impression = Container(
            color: Colors.white70,
            width: size,
            height: size,
          );
          break;
        default:
          impression = Container(
            color: Colors.amber,
            width: size,
            height: size,
          );
      }
      cells[linearCoords] = impression;
    }
    cells[level.playerPos.y * width + level.playerPos.x] = Container(
      color: Colors.red[900],
      width: size,
      height: size,
    );
    List<List<Container>> _cells = List.generate(height, (index) => []);
    for (var i = 0; i < height; i++) {
      for (var j = 0; j < width; j++) {
        _cells[i].add(cells[i * width + j]);
      }
    }
    return Padding(
      padding: EdgeInsets.all(size / 2),
      child: Center(
        child: SizedBox(
          width: width * size,
          height: height * size,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                _cells.length,
                (i) => Row(
                      children: _cells[i],
                    )),
          ),
        ),
      ),
    );
  }
}
