import 'package:flutter/material.dart';
import '../models/detected_word.dart';

class ArOverlayPainter extends CustomPainter {
  // Przeskalowana lista alergenów z ich pozycjami na ekranie
  final List<DetectedWord> allergensOnScreen;

  ArOverlayPainter({required this.allergensOnScreen});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Definiujemy jak wygląda pędzel do rysowania ramki
    final paintFrame = Paint()
      ..style = PaintingStyle.stroke // Tylko obrys
      ..strokeWidth = 3.0 // Grubość linii
      ..isAntiAlias = true; // Wygładzanie krawędzi

    // 2. Definiujemy pędzel do tła napisu
    final paintLabelBg = Paint()
      ..style = PaintingStyle.fill; // Wypełnienie

    // 3. Iterujemy po wszystkich znalezionych alergenach
    for (var detected in allergensOnScreen) {
      // Pobieramy kolor przypisany do poziomu zagrożenia
      final Color severityColor = Color(detected.allergen.severityColorHex);
      paintFrame.color = severityColor; // Ustawiamy kolor ramki
      paintLabelBg.color = severityColor.withOpacity(0.9); // Kolor tła napisu (półprzezroczysty)

      final Rect rect = detected.rawBoundingBox;

      // 4. RYSUJEMY RAMKĘ
      canvas.drawRect(rect, paintFrame);

      // 5. RYSUJEMY NAPIS (etykietę) nad ramką
      _drawTextLabel(canvas, rect, detected.allergen.name, severityColor);
    }
  }

  /// Helper: Rysuje małą etykietę z nazwą alergenu bezpośrednio nad ramką
  void _drawTextLabel(Canvas canvas, Rect rect, String text, Color color) {
    // Przygotowanie napisu (biały, pogrubiony)
    final textSpan = TextSpan(
      text: text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    
    // Konfiguracja układu tekstu
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Pozycja napisu: na środku prostokąta, 10px powyżej ramki
    final Offset labelPosition = Offset(
      rect.left + (rect.width - textPainter.width) / 2,
      rect.top - textPainter.height - 10,
    );

    // Tło dla napisu, żeby był czytelny
    final Rect labelBg = Rect.fromLTWH(
      labelPosition.dx - 5,
      labelPosition.dy - 3,
      textPainter.width + 10,
      textPainter.height + 6,
    );
    
    // Rysujemy tło napisu (małe zaokrąglone prostokąty wyglądają ładniej)
    canvas.drawRRect(
        RRect.fromRectAndRadius(labelBg, const Radius.circular(5)), 
        Paint()..color = color // Kolor tła etykiety taki sam jak ramka
    );
    
    // Rysujemy finalnie tekst
    textPainter.paint(canvas, labelPosition);
  }

  /// Kluczowe: Mówimy Flutterowi, kiedy ma odświeżyć obraz.
  /// W AR czasu rzeczywistego musimy to robić w każdej klatce, gdy lista się zmienia.
  @override
  bool shouldRepaint(covariant ArOverlayPainter oldDelegate) {
    // Jeśli lista alergenów na ekranie się zmieniła, przemaluj obraz
    return oldDelegate.allergensOnScreen != allergensOnScreen;
  }
}