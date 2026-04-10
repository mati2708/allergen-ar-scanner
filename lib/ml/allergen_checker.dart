import 'dart:math';
import '../models/allergen.dart';
import 'allergen_classifier.dart'; // Przywracamy import AI!

class AllergenChecker {
  final AllergenClassifier _classifier;

  // Wymagamy AI w konstruktorze
  AllergenChecker(this._classifier);

  final Map<String, String> _targetWordsMap = {
    'mleko': 'mleko', 'orzeszki': 'orzeszki', 'orzechy': 'orzeszki',
    'gluten': 'gluten', 'pszenica': 'gluten', 'soja': 'soja',
    'jaja': 'jaja', 'jajka': 'jaja',
    'milk': 'mleko', 'peanuts': 'orzeszki', 'peanut': 'orzeszki',
    'nuts': 'orzeszki', 'wheat': 'gluten', 'soy': 'soja',
    'soybean': 'soja', 'eggs': 'jaja', 'egg': 'jaja',
  };

  List<Allergen> checkText(String scannedText) {
    List<Allergen> detectedAllergens = [];
    String normalizedText = scannedText.toLowerCase().replaceAll(RegExp(r'[^a-ząćęłńóśźż0-9\s]'), '');
    List<String> words = normalizedText.split(RegExp(r'\s+'));

    for (String word in words) {
      if (word.length < 3) continue;

      for (var entry in _targetWordsMap.entries) {
        String targetToSearch = entry.key;      
        String baseWordForAI = entry.value;     

        int maxDistance = targetToSearch.length <= 4 ? 1 : 2;
        int distance = _calculateLevenshtein(word, targetToSearch);

        if (distance <= maxDistance) {
          if (!detectedAllergens.any((a) => a.name == baseWordForAI)) {
            // PYTAMY AI O WAGĘ!
            AllergenSeverity aiSeverity = _classifier.classifyWord(baseWordForAI);
            
            if (aiSeverity != AllergenSeverity.unknown) {
               detectedAllergens.add(Allergen(name: baseWordForAI, severity: aiSeverity));
            }
          }
        }
      }
    }
    return detectedAllergens;
  }

  Allergen? checkSingleWord(String scannedWord) {
     String normalized = scannedWord.toLowerCase().replaceAll(RegExp(r'[^a-ząćęłńóśźż0-9\s]'), '');
     if (normalized.length < 3) return null;

     for (var entry in _targetWordsMap.entries) {
        String targetToSearch = entry.key;
        String baseWordForAI = entry.value;

        int maxDistance = targetToSearch.length <= 4 ? 1 : 2;
        int distance = _calculateLevenshtein(normalized, targetToSearch);
        
        if (distance <= maxDistance) {
          // PYTAMY AI O WAGĘ!
          AllergenSeverity aiSeverity = _classifier.classifyWord(baseWordForAI);
          
          if (aiSeverity != AllergenSeverity.unknown) {
             return Allergen(name: baseWordForAI, severity: aiSeverity);
          }
        }
     }
     return null;
  }

  int _calculateLevenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}