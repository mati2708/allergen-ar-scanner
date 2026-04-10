import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrEngine {
  // Inicjalizacja domyślnego rozpoznawania tekstu (skrypt łaciński)
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Główna metoda przyjmująca obraz i zwracająca rozpoznany tekst
  Future<RecognizedText?> processImage(InputImage inputImage) async {
    try {
      // Przekazanie obrazu do silnika ML Kit
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText;
    } catch (e) {
      print('Błąd podczas przetwarzania OCR: $e');
      return null;
    }
  }

  /// Pamiętajmy o zwolnieniu zasobów, gdy aplikacja jest zamykana
  void dispose() {
    _textRecognizer.close();
  }
}