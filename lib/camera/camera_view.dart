import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../main.dart'; 
import '../ml/ocr_engine.dart';
import '../ml/allergen_checker.dart';
import '../ml/allergen_classifier.dart'; // Dodany import dla klasyfikatora
import '../models/allergen.dart';
import '../models/detected_word.dart';
import '../ar/ar_overlay_painter.dart';
import '../ar/ar_utils.dart'; // importujemy naszą matematykę

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {

  DateTime? _lastDetectionTime; // Kiedy ostatnio coś znaleźliśmy?
  String _statusMessage = "Szukam alergenów..."; 
  
  // Przykładowe progi czasowe (w sekundach)
  final int _thresholdWarning = 5; // Po 5 sekundach dajemy radę
  final int _thresholdFailure = 10; // Po 10 sekundach poddajemy się

  CameraController? _controller;
  bool _isCameraInitialized = false;
  
  final OcrEngine _ocrEngine = OcrEngine();
  
  // 1. Zmienne dla AI i sprawdzania alergenów
  final AllergenClassifier _classifier = AllergenClassifier();
  late final AllergenChecker _allergenChecker;
  
  bool _isProcessing = false; 
  // Zbiory dla poszczególnych kategorii (Set automatycznie dba, by nie było duplikatów)
  Set<String> _dangerousAllergens = {};
  Set<String> _mediumAllergens = {};
  Set<String> _lightAllergens = {};
  
  // Lista obiektów gotowych do narysowania w AR
  List<DetectedWord> _allergensForAr = [];

  // 2. Zaktualizowana metoda initState()
  @override
  void initState() {
    super.initState();
    _allergenChecker = AllergenChecker(_classifier); // Inicjalizujemy checker
    _initDependencies();
  }

  // 3. Nowa metoda inicjalizacyjna ładująca TFLite przed kamerą
  Future<void> _initDependencies() async {
    // Najpierw ładujemy sztuczną inteligencję (to potrwa ułamek sekundy)
    await _classifier.loadModel();
    // Potem odpalamy kamerę
    _initializeCamera(); 
  }

  void _initializeCamera() async {
    if (cameras.isEmpty) return;
    CameraDescription rearCamera = cameras.first;
    _controller = CameraController(
      rearCamera,
      ResolutionPreset.high, 
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888, 
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      
      setState(() {
        _isCameraInitialized = true;
      });
      _controller!.startImageStream(_processCameraImage);
    } catch (e) {
      print('Błąd kamery: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {

    // 1. ZACZYNAMY MIERZYĆ CZAS NA SAMYM POCZĄTKU
    final startTime = DateTime.now();

    if (_isProcessing || !mounted) return;
    _isProcessing = true;

    try {
      final inputImage = _createInputImageFromCameraImage(image);
      if (inputImage == null) { _isProcessing = false; return; }

      // 1. Dostajemy pełną odpowiedź OCR (bloków, linii, słów i ich BoundingBoxes)
      final RecognizedText recognizedText = await _ocrEngine.processImage(inputImage) ?? RecognizedText(text: "", blocks: []);

      List<DetectedWord> newAllergensOnScreen = [];
      
      // Koszyki na tę konkretną klatkę obrazu
      Set<String> tempDangerous = {};
      Set<String> tempMedium = {};
      Set<String> tempLight = {};

      final imageSize = inputImage.metadata?.size;

      if (recognizedText.text.isNotEmpty && imageSize != null && context.mounted) {
        final screenSize = MediaQuery.of(context).size;

        for (var block in recognizedText.blocks) {
          for (var line in block.lines) {
            for (var element in line.elements) {
              
              final Allergen? matchedAllergen = _allergenChecker.checkSingleWord(element.text);

              if (matchedAllergen != null && element.boundingBox != null) {
                
                final Rect scaledBox = ArUtils.scaleBoundingBox(
                  rawRect: element.boundingBox!,
                  imageSize: imageSize, 
                  screenSize: screenSize,
                  isAndroid: Platform.isAndroid,
                );

                newAllergensOnScreen.add(
                  DetectedWord(allergen: matchedAllergen, rawBoundingBox: scaledBox)
                );

                // Sortowanie do odpowiedniego koszyka na podstawie oceny AI
                String formattedName = matchedAllergen.name.toUpperCase();
                if (matchedAllergen.severity == AllergenSeverity.dangerous) {
                  tempDangerous.add(formattedName);
                } else if (matchedAllergen.severity == AllergenSeverity.medium) {
                  tempMedium.add(formattedName);
                } else if (matchedAllergen.severity == AllergenSeverity.light) {
                  tempLight.add(formattedName);
                }
              }
            }
          }
        }
      }

      // Zapisujemy koszyki do głównego stanu interfejsu
      setState(() {
        _allergensForAr = newAllergensOnScreen;
        _dangerousAllergens = tempDangerous;
        _mediumAllergens = tempMedium;
        _lightAllergens = tempLight;

        if (newAllergensOnScreen.isNotEmpty) {
          // MAMY SUKCES: Resetujemy stoper i komunikaty
          _lastDetectionTime = DateTime.now();
          _statusMessage = ""; // Ukrywamy komunikat pomocniczy, bo są wyniki
        } else {
          // BRAK WYNIKÓW: Obliczamy, ile czasu minęło od ostatniego znaleziska
          if (_lastDetectionTime == null) {
            _lastDetectionTime = DateTime.now(); // Inicjalizacja przy starcie
          }
          
          final secondsEmpty = DateTime.now().difference(_lastDetectionTime!).inSeconds;

          if (secondsEmpty >= _thresholdFailure) {
            _statusMessage = "Przepraszamy, nie udało nam się wykryć żadnych alergenów na tym fragmencie.";
          } else if (secondsEmpty >= _thresholdWarning) {
            _statusMessage = "Spróbuj zmienić kąt kamery lub zapewnić lepsze oświetlenie.";
          } else {
            _statusMessage = "Skupiam ostrość... Szukam składników...";
          }
        }
      });
      
    } catch (e) {
      print("Błąd OCR/AR: $e");
    } finally {
      // 2. KOŃCZYMY POMIAR I WYLICZAMY FPS NA SAMYM KOŃCU
      final endTime = DateTime.now();
      final processingTimeMs = endTime.difference(startTime).inMilliseconds;
      
      // Zabezpieczenie przed dzieleniem przez zero
      final currentFPS = processingTimeMs > 0 ? (1000 ~/ processingTimeMs) : 0; 

      // Wyświetlenie wyniku w konsoli do spisania do sprawozdania!
      print('⏱️ Czas OCR+AI: ${processingTimeMs}ms | Wydajność algorytmu: $currentFPS FPS');

      _isProcessing = false;
    }
  }

  // Helper konwersji (bez zmian)
  InputImage? _createInputImageFromCameraImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) { allBytes.putUint8List(plane.bytes); }
    final bytes = allBytes.done().buffer.asUint8List();
    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final camera = cameras.first;
    final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (imageRotation == null) return null;
    final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw);
    if (inputImageFormat == null) return null;
    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes.first.bytesPerRow,
    );
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  // 4. Czyszczenie pamięci po modelu TFLite w metodzie dispose()
  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _ocrEngine.dispose();
    _classifier.dispose(); // Zwalniamy model AI z pamięci
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          
          // --- NOWOŚĆ: WARSTWA AR JEST TERAZ URUCHOMIONA ---
          // Podpinamy naszego rysownika i przekazujemy przeskalowaną listę
          CustomPaint(
            painter: ArOverlayPainter(allergensOnScreen: _allergensForAr)
          ), 
          
          // Pasek na dole ekranu
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(15),
              ),
              child: _allergensForAr.isEmpty 
                  ? Text(
                      _statusMessage, // Wyświetlamy dynamiczny komunikat błędu/pomocy
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "WYKRYTE ALERGENY:",
                          style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (_dangerousAllergens.isNotEmpty)
                          Text(
                            "🔴 NIEBEZPIECZNE: ${_dangerousAllergens.join(', ')}",
                            style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        if (_mediumAllergens.isNotEmpty)
                          Text(
                            "🟠 ŚREDNIE: ${_mediumAllergens.join(', ')}",
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        if (_lightAllergens.isNotEmpty)
                          Text(
                            "🟡 LEKKIE: ${_lightAllergens.join(', ')}",
                            style: const TextStyle(color: Colors.yellowAccent, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
            ),
          )
        ],
      ),
    );
  }
}