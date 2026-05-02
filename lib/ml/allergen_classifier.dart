import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/allergen.dart';

class AllergenClassifier {
  Interpreter? _interpreter;
  Map<String, dynamic> _vocab = {};
  final int _maxLen = 3; 

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/allergen_model.tflite');
      String jsonString = await rootBundle.loadString('assets/models/vocab.json');
      _vocab = jsonDecode(jsonString);
      print("🤖 AI: Model i słownik załadowane pomyślnie!");
    } catch (e) {
      print("🤖 BŁĄD ładowania modelu AI: $e");
    }
  }

  AllergenSeverity classifyWord(String word) {
    if (_interpreter == null) return AllergenSeverity.unknown;

    try {
      List<int> sequence = [];
      String normalized = word.toLowerCase();
      
      if (_vocab.containsKey(normalized)) {
        sequence.add(_vocab[normalized]);
      } else {
        sequence.add(0);
      }

      List<int> inputSequence = List.filled(_maxLen, 0);
      for (int i = 0; i < sequence.length && i < _maxLen; i++) {
        inputSequence[i] = sequence[i];
      }

      var inputTensor = [inputSequence];
      var outputTensor = List.filled(1 * 4, 0.0).reshape([1, 4]);

      _interpreter!.run(inputTensor, outputTensor);
      
      List<double> probabilities = (outputTensor[0] as List).cast<double>();
      
      int maxIndex = 0;
      double maxProb = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      if (maxProb < 0.5) return AllergenSeverity.unknown;

      switch (maxIndex) {
        case 0: return AllergenSeverity.dangerous;
        case 1: return AllergenSeverity.medium;
        case 2: return AllergenSeverity.light;
        case 3: // Neutralne
        default: return AllergenSeverity.unknown;
      }
    } catch (e) {
      print("🤖 Błąd podczas predykcji AI: $e");
      return AllergenSeverity.unknown;
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}