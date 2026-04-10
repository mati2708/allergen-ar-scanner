import 'dart:ui'; // Potrzebujemy tego importu dla klasy 'Rect'
import 'allergen.dart';

class DetectedWord {
  final Allergen allergen;
  
  // To jest prostokąt, który dostajemy z OCR (współrzędne na obrazie)
  final Rect rawBoundingBox; 

  DetectedWord({
    required this.allergen, 
    required this.rawBoundingBox
  });
}