import 'package:flutter/material.dart';

import 'editor_game.dart';
import 'level.dart';
import 'level_editor.dart';

class UndoIntent extends Intent {
  const UndoIntent();
}

void undoAction() {
  if (historyPointer.value != 0) {
    historyPointer.value--;
    mobsAsMap = newMobMap(changeHistory[historyPointer.value]);
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    currentLayer.notifyListeners();
  }
}

class RedoIntent extends Intent {
  const RedoIntent();
}

void redoAction() {
  if (historyPointer.value < changeHistory.length - 1) {
    historyPointer.value++;
    mobsAsMap = newMobMap(changeHistory[historyPointer.value]);
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    currentLayer.notifyListeners();
  }
}

class LayerDownIntent extends Intent {
  const LayerDownIntent();
}

void layerDownAction() {
  if (currentLayer.value > 0) {
    currentLayer.value--;
  }
}

class LayerUpIntent extends Intent {
  const LayerUpIntent();
}

void layerUpAction() {
  if (currentLayer.value < 15) {
    currentLayer.value++;
  }
}

class TuningIntent extends Intent {
  const TuningIntent();
}

void tuningAction() {
  selectedMob.value = null;

  isTuning.value = !isTuning.value;
  isDeleting.value = false;
  isCopying.value = false;
}

class EyedropperIntent extends Intent {
  const EyedropperIntent();
}

void eyedropperAction() {
  selectedMob.value = null;

  isCopying.value = !isCopying.value;
  isDeleting.value = false;
  isTuning.value = false;
}

class RunLevelIntent extends Intent {
  const RunLevelIntent();
}

void runLevelAction(BuildContext context, Level level_) {
  var json_ = level_.toJson();
  //json.value = jsonEncode(_json);
  var level = Level.fromJson(json_);

  Navigator.push(context,
      MaterialPageRoute(builder: (context) => EditorGame(level: level)));
}

class BackIntent extends Intent {
  const BackIntent();
}

void backAction(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.blueGrey[900],
        title: const Text(
          'Выйти из редактора?',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        actions: [
          ElevatedButton.icon(
              onPressed: () {
                int c = 0;
                Navigator.popUntil(context, (_) => c++ >= 2);
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text(
                'Выйти',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ))
        ],
      );
    },
  );
}
