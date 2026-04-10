import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera/camera_view.dart'; // Ten plik stworzymy za chwilę

// Globalna zmienna do przechowywania dostępnych kamer
List<CameraDescription> cameras = [];

Future<void> main() async {
  // Wymagane, gdy inicjalizujemy rzeczy przed runApp()
  WidgetsFlutterBinding.ensureInitialized(); 
  
  try {
    // Pobranie listy aparatów (szukamy tylnego)
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Błąd inicjalizacji kamery: ${e.code}, ${e.description}');
  }

  runApp(const AllergenScannerApp());
}

class AllergenScannerApp extends StatelessWidget {
  const AllergenScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR Allergen Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // Ukrywamy wstążkę "DEBUG" w rogu
      debugShowCheckedModeBanner: false, 
      home: const CameraView(),
    );
  }
}