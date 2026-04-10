import 'dart:math';
import 'package:flutter/material.dart';

class ArUtils {
  /// Skaluje prostokąt z rozdzielczości obrazu kamery do rozdzielczości ekranu.
  /// Uwzględnia proporcje ekranu i przycięcie obrazu (tryb cover).
  static Rect scaleBoundingBox({
    required Rect rawRect,
    required Size imageSize, // Np. Size(1280, 720) z InputImageMetadata
    required Size screenSize, // Fizyczna rozdzielczość ekranu urządzenia
    required bool isAndroid, // Ważne dla obsługi rotacji
  }) {
    double scaleX, scaleY;
    
    // Dla Androida musimy zamienić szerokość z wysokością, bo ML Kit działa na obrazie obróconym o 90 stopni
    if (isAndroid) {
      scaleX = screenSize.width / imageSize.height;
      scaleY = screenSize.height / imageSize.width;
    } else {
      // Dla iOS (na wszelki wypadek, gdybyś kiedyś chciał to odpalić na maku)
      scaleX = screenSize.width / imageSize.width;
      scaleY = screenSize.height / imageSize.height;
    }

    // Wybieramy tryb skalowania. Aby ramka była płynna i pokrywała cały obraz, 
    // Flutter zazwyczaj używa trybu 'Cover', więc bierzemy większą skalę.
    // To sprawia, że obraz jest nieco przycięty, ale wypełnia ekran.
    double scale = max(scaleX, scaleY);
    
    // Obliczamy przesunięcie (ang. offset), jeśli obraz jest przycięty
    double offsetX = (screenSize.width - (imageSize.height * scale)) / 2;
    double offsetY = (screenSize.height - (imageSize.width * scale)) / 2;

    // Przeskalowany prostokąt
    return Rect.fromLTRB(
      (rawRect.left * scale) + offsetX,
      (rawRect.top * scale) + offsetY,
      (rawRect.right * scale) + offsetX,
      (rawRect.bottom * scale) + offsetY,
    );
  }
}