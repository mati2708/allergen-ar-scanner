import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:intl/intl.dart';

import '../main.dart'; 
import '../ml/ocr_engine.dart';
import '../ml/allergen_checker.dart';
import '../ml/allergen_classifier.dart'; 
import '../models/allergen.dart';
import '../models/detected_word.dart';
import '../ar/ar_overlay_painter.dart';
import '../ar/ar_utils.dart'; 
import '../screens/preferences_screen.dart'; 
import '../ml/ecode_checker.dart';
import '../database/db_helper.dart'; 

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {

  DateTime? _lastDetectionTime; 
  String _statusMessage = "Szukam alergenów..."; 
  
  final int _thresholdWarning = 5; 
  final int _thresholdFailure = 10; 

  CameraController? _controller;
  bool _isCameraInitialized = false;
  
  final OcrEngine _ocrEngine = OcrEngine();
  
  final AllergenClassifier _classifier = AllergenClassifier();
  late final AllergenChecker _allergenChecker;
  
  bool _isProcessing = false; 

  Set<String> _dangerousAllergens = {};
  Set<String> _mediumAllergens = {};
  Set<String> _lightAllergens = {};
  Set<String> _dangerEcodes = {};
  Set<String> _warningEcodes = {};
  Set<String> _neutralEcodes = {};
  
  List<DetectedWord> _allergensForAr = [];

  // --- ZMIANA: Pamięć CAŁEJ sesji skanowania z kategoriami ---
  // Klucz: Nazwa (np. "MLEKO"), Wartość: Kategoria (np. "RED", "E_DANGER")
  final Map<String, String> _sessionReportData = {};

  List<String> _activeUserAllergens = [];

  // Pamięć krótkotrwała AR (Temporal Smoothing)
  List<TrackedWord> _trackedWords = [];
  final int _smoothingDurationMs = 500; 

  @override
  void initState() {
    super.initState();
    _allergenChecker = AllergenChecker(_classifier);
    _initDependencies();
  }
  
  Future<void> _initDependencies() async {
    await _loadUserPreferences();
    await _classifier.loadModel();
    _initializeCamera(); 
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _activeUserAllergens = prefs.getStringList('my_allergens') ?? 
          ['mleko', 'orzeszki', 'gluten', 'soja', 'jaja'];
    });
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

  // --- ZMIANA: FORMATOWANIE ZAPISU DO BAZY DANYCH ---
  Future<void> _finishAndSaveSession() async {
    setState(() {
      _isProcessing = true; // Zatrzymujemy przetwarzanie klatek z kamery
    });

    StringBuffer report = StringBuffer();
    List<String> red = [];
    List<String> orange = [];
    List<String> yellow = [];
    List<String> eDanger = [];
    List<String> eWarning = [];
    List<String> eNeutral = [];

    // Podział elementów z pamięci do odpowiednich kategorii
    _sessionReportData.forEach((name, type) {
      if (type == "RED") red.add(name);
      if (type == "ORANGE") orange.add(name);
      if (type == "YELLOW") yellow.add(name);
      if (type == "E_DANGER") eDanger.add(name);
      if (type == "E_WARNING") eWarning.add(name);
      if (type == "E_NEUTRAL") eNeutral.add(name);
    });

    // Budowanie raportu tekstowego identycznie jak UI
    if (red.isNotEmpty || orange.isNotEmpty || yellow.isNotEmpty) {
      report.writeln("WYKRYTE ALERGENY:");
      if (red.isNotEmpty) report.writeln("🔴 NIEBEZPIECZNE: ${red.join(', ')}");
      if (orange.isNotEmpty) report.writeln("🟠 ŚREDNIE: ${orange.join(', ')}");
      if (yellow.isNotEmpty) report.writeln("🟡 LEKKIE: ${yellow.join(', ')}");
      report.writeln(""); // Pusta linia odstępu
    }

    if (eDanger.isNotEmpty || eWarning.isNotEmpty || eNeutral.isNotEmpty) {
      report.writeln("WYKRYTE KODY 'E':");
      if (eDanger.isNotEmpty) report.writeln("🛑 SZKODLIWE: ${eDanger.join(', ')}");
      if (eWarning.isNotEmpty) report.writeln("⚠️ UWAŻAJ NA: ${eWarning.join(', ')}");
      if (eNeutral.isNotEmpty) report.writeln("✅ BEZPIECZNE: ${eNeutral.join(', ')}");
    }

    String detectedString = report.isEmpty 
        ? "✅ Produkt bezpieczny - brak zagrożeń" 
        : report.toString().trim();

    final String currentDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    await DbHelper.instance.insertScan({
      'title': 'Nowe skanowanie', 
      'scan_date': currentDate,
      'detected_items': detectedString,
    });

    if (mounted) {
      Navigator.pop(context); 
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final startTime = DateTime.now();

    if (_isProcessing || !mounted) return;
    _isProcessing = true;

    try {
      final inputImage = _createInputImageFromCameraImage(image);
      if (inputImage == null) { _isProcessing = false; return; }

      final RecognizedText recognizedText = await _ocrEngine.processImage(inputImage) ?? RecognizedText(text: "", blocks: []);

      List<DetectedWord> newAllergensOnScreen = [];
      
      Set<String> tempDangerous = {};
      Set<String> tempMedium = {};
      Set<String> tempLight = {};
      Set<String> tempDangerE = {};
      Set<String> tempWarningE = {};
      Set<String> tempNeutralE = {};

      final imageSize = inputImage.metadata?.size;

      if (recognizedText.text.isNotEmpty && imageSize != null && context.mounted) {
        final screenSize = MediaQuery.of(context).size;
        
        List<DetectedWord> currentFrameWords = []; 

        for (var block in recognizedText.blocks) {
          for (var line in block.lines) {
            for (var element in line.elements) {
              
              // 1. Detekcja Alergenów (dla AR)
              final Allergen? matchedAllergen = _allergenChecker.checkSingleWord(element.text, _activeUserAllergens);

              if (matchedAllergen != null) {
                final Rect scaledBox = ArUtils.scaleBoundingBox(
                  rawRect: element.boundingBox, 
                  imageSize: imageSize, 
                  screenSize: screenSize,
                  isAndroid: Platform.isAndroid,
                );
                currentFrameWords.add(DetectedWord(allergen: matchedAllergen, rawBoundingBox: scaledBox));
              }

              // 2. Detekcja Kodów E
             final eCodeMatch = ECodeChecker.check(element.text);
              if (eCodeMatch != null) {
                String displayEcode = "${eCodeMatch['code']} - ${eCodeMatch['name']}";
                
                AllergenSeverity severity = AllergenSeverity.unknown;

                if (eCodeMatch['level'] == 'danger') {
                  tempDangerE.add(displayEcode);
                  _sessionReportData[displayEcode] = "E_DANGER"; // Zapis z kategorią
                  severity = AllergenSeverity.dangerous;
                } else if (eCodeMatch['level'] == 'warning') {
                  tempWarningE.add(displayEcode);
                  _sessionReportData[displayEcode] = "E_WARNING"; // Zapis z kategorią
                  severity = AllergenSeverity.medium;
                } else {
                  tempNeutralE.add(displayEcode);
                  _sessionReportData[displayEcode] = "E_NEUTRAL"; // Zapis z kategorią
                }

                // Generowanie ramki AR dla konserwantów
                if (severity != AllergenSeverity.unknown && element.boundingBox != null) {
                  final Rect scaledBox = ArUtils.scaleBoundingBox(
                    rawRect: element.boundingBox!, 
                    imageSize: imageSize, 
                    screenSize: screenSize,
                    isAndroid: Platform.isAndroid,
                  );
                  
                  currentFrameWords.add(DetectedWord(
                    allergen: Allergen(name: eCodeMatch['name']!, severity: severity), 
                    rawBoundingBox: scaledBox
                  ));
                }
              }
            }
          }
        }

        // --- TEMPORAL SMOOTHING ---
        final now = DateTime.now();

        for (var newWord in currentFrameWords) {
          int index = _trackedWords.indexWhere((t) => t.detectedWord.allergen.name == newWord.allergen.name);

          if (index != -1) {
            _trackedWords[index].detectedWord = newWord;
            _trackedWords[index].lastSeen = now;
          } else {
            _trackedWords.add(TrackedWord(detectedWord: newWord, lastSeen: now));
          }
        }

        _trackedWords.removeWhere((t) => now.difference(t.lastSeen).inMilliseconds > _smoothingDurationMs);
        newAllergensOnScreen = _trackedWords.map((t) => t.detectedWord).toList();

        // Rozdzielanie STABILNYCH słów do koszyków
        for (var item in newAllergensOnScreen) {
          String formattedName = item.allergen.name.toUpperCase();

          if (item.allergen.severity == AllergenSeverity.dangerous) {
            tempDangerous.add(formattedName);
            _sessionReportData[formattedName] = "RED"; // Zapis z kategorią
          } else if (item.allergen.severity == AllergenSeverity.medium) {
            tempMedium.add(formattedName);
            _sessionReportData[formattedName] = "ORANGE"; // Zapis z kategorią
          } else if (item.allergen.severity == AllergenSeverity.light) {
            tempLight.add(formattedName);
            _sessionReportData[formattedName] = "YELLOW"; // Zapis z kategorią
          }
        }
      }

      setState(() {
        _allergensForAr = newAllergensOnScreen;
        _dangerousAllergens = tempDangerous;
        _mediumAllergens = tempMedium;
        _lightAllergens = tempLight;

        _dangerEcodes = tempDangerE;
        _warningEcodes = tempWarningE;
        _neutralEcodes = tempNeutralE;

        if (newAllergensOnScreen.isNotEmpty || _dangerEcodes.isNotEmpty || _warningEcodes.isNotEmpty || _neutralEcodes.isNotEmpty) {
          _lastDetectionTime = DateTime.now();
          _statusMessage = ""; 
        } else {
          if (_lastDetectionTime == null) {
            _lastDetectionTime = DateTime.now(); 
          }
          
          final secondsEmpty = DateTime.now().difference(_lastDetectionTime!).inSeconds;

          if (secondsEmpty >= _thresholdFailure) {
            _statusMessage = "Przepraszamy, nie udało nam się wykryć składników na tym fragmencie.";
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
      final endTime = DateTime.now();
      final processingTimeMs = endTime.difference(startTime).inMilliseconds;
      
      final currentFPS = processingTimeMs > 0 ? (1000 ~/ processingTimeMs) : 0; 
      print('⏱️ Czas OCR+AI: ${processingTimeMs}ms | Wydajność algorytmu: $currentFPS FPS');

      _isProcessing = false;
    }
  }

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

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _ocrEngine.dispose();
    _classifier.dispose(); 
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
          
          CustomPaint(
            painter: ArOverlayPainter(allergensOnScreen: _allergensForAr)
          ), 
          
          // Przycisk przejścia do ustawień preferencji
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
              ),
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 28),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PreferencesScreen()),
                  );
                  _loadUserPreferences();
                },
              ),
            ),
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
              child: (_allergensForAr.isEmpty && _dangerEcodes.isEmpty && _warningEcodes.isEmpty && _neutralEcodes.isEmpty)
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _statusMessage, 
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        _buildSaveButton(),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_dangerousAllergens.isNotEmpty || _mediumAllergens.isNotEmpty || _lightAllergens.isNotEmpty) ...[
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

                        // INTERFEJS DLA KODÓW E
                        if (_dangerEcodes.isNotEmpty || _warningEcodes.isNotEmpty || _neutralEcodes.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                            child: Text(
                              "WYKRYTE KODY 'E':",
                              style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (_dangerEcodes.isNotEmpty)
                            Text(
                              "🛑 SZKODLIWE: ${_dangerEcodes.join(', ')}",
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            ),
                          if (_warningEcodes.isNotEmpty)
                            Text(
                              "⚠️ UWAŻAJ NA: ${_warningEcodes.join(', ')}",
                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
                            ),
                          if (_neutralEcodes.isNotEmpty)
                            Text(
                              "✅ BEZPIECZNE: ${_neutralEcodes.join(', ')}",
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                            ),
                        ],

                        const SizedBox(height: 15),
                        _buildSaveButton(),
                      ],
                    ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity, 
      child: ElevatedButton.icon(
        onPressed: _finishAndSaveSession, 
        icon: const Icon(Icons.save_alt, color: Colors.white),
        label: const Text(
          "ZAKOŃCZ I ZAPISZ SKANOWANIE",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent, 
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class TrackedWord {
  DetectedWord detectedWord;
  DateTime lastSeen;

  TrackedWord({required this.detectedWord, required this.lastSeen});
}