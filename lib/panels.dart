import 'dart:math';

import 'package:flutter/material.dart';

import 'game/directions.dart';
import 'game/mobs.dart' hide Border;
import 'game/mobs.dart' as mob_class;
import 'level_editor.dart';
import 'shortcuts.dart';

class BottomPanels extends StatelessWidget {
  const BottomPanels({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Container(
        color: Colors.blueGrey[900],
        height: getCellSize() * 2 + 16,
        child: Column(
          children: const [
            UtilityPanel(),
            TilePanel(),
          ],
        ),
      ),
    );
  }
}

class TuningButton extends StatefulWidget {
  const TuningButton({Key? key}) : super(key: key);

  @override
  State<TuningButton> createState() => _TuningButtonState();
}

class _TuningButtonState extends State<TuningButton> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: isTuning,
        builder: (context, bool tuning, child) {
          return IconButton(
            onPressed: () {
              tuningAction();
            },
            color: Colors.blueGrey[900],
            iconSize: 32,
            icon: Icon(
              Icons.build_rounded,
              color: tuning ? Colors.green : Colors.white70,
            ),
          );
        });
  }
}

class EyedropperButton extends StatefulWidget {
  const EyedropperButton({Key? key}) : super(key: key);

  @override
  State<EyedropperButton> createState() => _EyedropperButtonState();
}

class _EyedropperButtonState extends State<EyedropperButton> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: isCopying,
        builder: (context, bool tuning, child) {
          return IconButton(
            onPressed: () {
              eyedropperAction();
            },
            color: Colors.blueGrey[900],
            iconSize: 32,
            icon: Icon(
              Icons.colorize_rounded,
              color: tuning ? Colors.green : Colors.white70,
            ),
          );
        });
  }
}

class DeletingButton extends StatelessWidget {
  const DeletingButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: isDeleting,
        builder: (context, bool deleting, child) {
          return IconButton(
            onPressed: () {
              selectedMob.value = null;
              isTuning.value = false;
              isDeleting.value = !isDeleting.value;
              isCopying.value = false;
            },
            color: Colors.blueGrey[900],
            iconSize: 32,
            icon: Icon(
              Icons.clear_rounded,
              color: deleting ? Colors.red : Colors.white70,
            ),
          );
        });
  }
}

class UtilityPanel extends StatelessWidget {
  const UtilityPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: getCellSize(),
      color: Colors.blueGrey[900]!.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          ActionButtons(),
          TuningButton(),
          EyedropperButton(),
          LayerChanger()
        ],
      ),
    );
  }
}

class ActionButtons extends StatelessWidget {
  const ActionButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [BackButton(), ForthButton()],
    );
  }
}

class BackButton extends StatefulWidget {
  const BackButton({Key? key}) : super(key: key);

  @override
  State<BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<BackButton> {
  bool isActive = true;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: historyPointer,
        builder: (context, int value, child) {
          if (historyPointer.value == 0) {
            isActive = false;
          } else {
            isActive = true;
          }
          return IconButton(
              onPressed: () {
                if (isActive) {
                  undoAction();
                }
              },
              icon: Icon(
                Icons.undo_rounded,
                color: isActive ? Colors.white70 : Colors.white30,
              ));
        });
  }
}

class ForthButton extends StatefulWidget {
  const ForthButton({Key? key}) : super(key: key);

  @override
  State<ForthButton> createState() => _ForthButtonState();
}

class _ForthButtonState extends State<ForthButton> {
  bool isActive = false;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: historyPointer,
        builder: (context, int value, child) {
          if (historyPointer.value < changeHistory.length - 1) {
            isActive = true;
          } else {
            isActive = false;
          }

          return IconButton(
              onPressed: () {
                if (isActive) {
                  redoAction();
                }
              },
              icon: Icon(
                Icons.redo_rounded,
                color: isActive ? Colors.white70 : Colors.white30,
              ));
        });
  }
}

class LayerChanger extends StatelessWidget {
  const LayerChanger({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
            onPressed: () {
              layerDownAction();
            },
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Colors.white70,
            )),
        ValueListenableBuilder<int>(
            valueListenable: currentLayer,
            builder: (BuildContext context, int layer, Widget? child) {
              return Text(
                '$layer',
                style: const TextStyle(fontSize: 20, color: Colors.white),
              );
            }),
        IconButton(
            onPressed: () {
              layerUpAction();
            },
            icon:
                const Icon(Icons.chevron_right_rounded, color: Colors.white70)),
      ],
    );
  }
}

class TilePanel extends StatelessWidget {
  const TilePanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: getCellSize() + 16,
      color: Colors.blueGrey[900],
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              TilePanelItem(mob: Player(const Point<int>(0, 0))),
              TilePanelItem(mob: Exit(0, const Point<int>(0, 0))),
              TilePanelItem(
                mob: mob_class.Border(1, const Point<int>(0, 0)),
              ),
              TilePanelItem(
                mob: ArrowMob(2, const Point<int>(0, 0), Directions.right, 0, 0,
                    isAnimated: false),
              ),
              TilePanelItem(
                  mob: Rotator(3, const Point<int>(0, 0), Directions.right,
                      isAnimated: false)),
              TilePanelItem(
                  mob: Switcher(4, const Point<int>(0, 0), [], false)),
              TilePanelItem(mob: Gate(5, const Point<int>(0, 0), true)),
              TilePanelItem(mob: TimedDoor(6, const Point<int>(0, 0), 1, [])),
              TilePanelItem(mob: Info(7, const Point<int>(0, 0), '')),
              TilePanelItem(mob: Repeater(8, const Point<int>(0, 0), [], 1)),
              TilePanelItem(
                mob: Annihilator(
                  9,
                  const Point<int>(0, 0),
                  Directions.right,
                  1,
                  4,
                  [],
                ),
              ),
              TilePanelItem(mob: Wire(10, const Point<int>(0, 0), [])),
              TilePanelItem(mob: Pressure(11, const Point<int>(0, 0), [])),
              TilePanelItem(mob: Portal(12, const Point<int>(0, 0), [], true)),
            ],
          )),
    );
  }
}

class TilePanelItem extends StatefulWidget {
  final Mob mob;

  const TilePanelItem({Key? key, required this.mob}) : super(key: key);

  @override
  State<TilePanelItem> createState() => _TilePanelItemState();
}

class _TilePanelItemState extends State<TilePanelItem> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Mob?>(
        valueListenable: selectedMob,
        builder: (BuildContext context, Mob? selected, Widget? child) {
          return GestureDetector(
              onTap: _onTap,
              child: widget.mob != selected
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              spreadRadius: 4,
                              blurRadius: 5,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        width: getCellSize(),
                        height: getCellSize(),
                        key: UniqueKey(),
                        child: ClipRRect(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(8)),
                            child: widget.mob.getImpression(getCellSize())),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        width: getCellSize(),
                        height: getCellSize(),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.greenAccent)),
                        key: UniqueKey(),
                        child: ClipRRect(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(8)),
                            child: widget.mob.getImpression(getCellSize())),
                      ),
                    ));
        });
  }

  _onTap() {
    isDeleting.value = false;
    isTuning.value = false;
    isCopying.value = false;
    if (selectedMob.value != widget.mob) {
      selectedMob.value = widget.mob;
    } else if (widget.mob.direction != Directions.zero) {
      switch (widget.mob.direction) {
        case Directions.left:
          setState(() {
            widget.mob.direction = Directions.up;
          });
          break;
        case Directions.up:
          setState(() {
            widget.mob.direction = Directions.right;
          });
          break;
        case Directions.right:
          setState(() {
            widget.mob.direction = Directions.down;
          });
          break;
        case Directions.down:
          setState(() {
            widget.mob.direction = Directions.left;
          });
          break;
        default:
      }
    } else if (widget.mob is TimedDoor) {
      setState(() {
        if ((widget.mob as TimedDoor).turns == 16) {
          (widget.mob as TimedDoor).turns = 1;
        } else {
          (widget.mob as TimedDoor).turns++;
        }
      });
    } else if (widget.mob is mob_class.Border) {
      setState(() {
        if ((widget.mob as mob_class.Border).color == 7) {
          (widget.mob as mob_class.Border).color = 0;
        } else {
          (widget.mob as mob_class.Border).color++;
        }
      });
    }
  }
}
