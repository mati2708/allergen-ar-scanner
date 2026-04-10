import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/allergen.dart';

class AllergenClassifier {
  Interpreter? _interpreter;
  
  // Zmienne dla naszego "Tłumacza" słów na liczby
  Map<String, dynamic> _vocab = {};
  
  // To musi być DOKŁADNIE taka sama wartość jak MAX_LEN w Pythonie
  final int _maxLen = 3; 

  Future<void> loadModel() async {
    try {
      // 1. Ładowanie pliku modelu
      _interpreter = await Interpreter.fromAsset('assets/models/allergen_model.tflite');
      
      // 2. Ładowanie słownika tokenów (zamiennika słów na cyfry)
      String jsonString = await rootBundle.loadString('assets/models/vocab.json');
      _vocab = jsonDecode(jsonString);
      
      print("🤖 AI: Model TFLite oraz słownik (vocab.json) załadowane pomyślnie!");
    } catch (e) {
      print("🤖 BŁĄD ładowania modelu AI: $e");
    }
  }

  AllergenSeverity classifyWord(String word) {
    if (_interpreter == null) {
      print("🤖 AI nie jest jeszcze gotowe!");
      return AllergenSeverity.unknown;
    }

    try {
      // --- 1. TOKENIZACJA (Przygotowanie Inputu) ---
      List<int> sequence = [];
      String normalized = word.toLowerCase();
      
      // Sprawdzamy, czy słowo występuje w słowniku wygenerowanym przez AI
      if (_vocab.containsKey(normalized)) {
        sequence.add(_vocab[normalized]);
      } else {
        sequence.add(0); // 0 oznacza "słowo nieznane" (Out of Vocabulary)
      }

      // Wypełniamy resztę zerami, by zachować stały wymiar _maxLen (np. [5, 0, 0])
      List<int> inputSequence = List.filled(_maxLen, 0);
      for (int i = 0; i < sequence.length && i < _maxLen; i++) {
        inputSequence[i] = sequence[i];
      }

      // Tworzymy Tensor Wejściowy o wymiarach [1, 3]
      var inputTensor = [inputSequence];

      // --- 2. TENSOR WYJŚCIOWY ---
      // Nasz model z Pythona zwraca 4 klasy zagrożenia (0, 1, 2, 3), 
      // więc oczekujemy tablicy [1, 4] wypełnionej na razie zerami.
      var outputTensor = List.filled(1 * 4, 0.0).reshape([1, 4]);

      // --- 3. INFERENCJA (Magia AI) ---
      _interpreter!.run(inputTensor, outputTensor);
      
      // --- 4. INTERPRETACJA WYNIKÓW ---
      List<double> probabilities = (outputTensor[0] as List).cast<double>();
      
      // Szukamy, dla której kategorii sztuczna inteligencja jest najbardziej pewna
      int maxIndex = 0;
      double maxProb = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      // PODSŁUCH DLA CIEBIE DO RAPORTU R&D:
      print("🤖 AI WYNIK dla '$word' -> Klasa $maxIndex (Pewność: ${(maxProb * 100).toStringAsFixed(1)}%)");

      // Możemy ustalić próg pewności. Jeśli model waha się (pewność poniżej 50%), odrzucamy wynik
      if (maxProb < 0.5) return AllergenSeverity.unknown;

      // Zwracamy wynik zgodnie z indeksami ustawionymi w Pythonie
      switch (maxIndex) {
        case 0: return AllergenSeverity.dangerous;
        case 1: return AllergenSeverity.medium;
        case 2: return AllergenSeverity.light;
        case 3: 
        default: 
          return AllergenSeverity.unknown;
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