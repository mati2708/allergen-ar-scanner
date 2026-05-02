import 'package:allergen_ar_scanner/camera/camera_view.dart';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'preferences_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _savedScans = [];

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  Future<void> _refreshHistory() async {
    final data = await DbHelper.instance.fetchAllScans();
    setState(() {
      _savedScans = data;
    });
  }

  // Funkcja potwierdzająca usunięcie (używana przy kliknięciu w ikonę kosza)
  void _confirmDelete(int id, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Usuń skanowanie"),
        content: const Text("Czy na pewno chcesz usunąć ten wpis z historii?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ANULUJ"),
          ),
          TextButton(
            onPressed: () async {
              // 1. Usuwamy fizycznie z bazy danych
              await DbHelper.instance.deleteScan(id);
              
              // 2. Zamykamy okno dialogowe
              Navigator.pop(context);
              
              // 3. KLUCZOWY MOMENT: Usuwamy element z lokalnej listy i odświeżamy UI
              setState(() {
                _savedScans.removeAt(index);
              });
              
              _showSnackBar("Skanowanie zostało usunięte");
            },
            child: const Text("USUŃ", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editTitle(int id, String currentTitle) {
    TextEditingController controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Zmień nazwę skanowania"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Np. Płatki śniadaniowe"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Anuluj")
          ),
          ElevatedButton(
            onPressed: () async {
              await DbHelper.instance.updateScanTitle(id, controller.text);
              Navigator.pop(context);
              _refreshHistory();
            }, 
            child: const Text("Zapisz")
          )
        ],
      ),
    );
  }

  // Pomocnicza funkcja do wyświetlania powiadomienia na dole
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.grey[800],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia Skanowań'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 28),
            tooltip: 'Moje Alergeny',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PreferencesScreen()),
              );
            },
          ),
        ],
      ),
      body: _savedScans.isEmpty
          ? const Center(
              child: Text(
                "Brak zapisanych skanowań.\nKliknij + aby zacząć.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _savedScans.length,
              itemBuilder: (context, index) {
                final scan = _savedScans[index];
                final scanId = scan['id'];

                // --- NOWOŚĆ: IMPLEMENTACJA PRZESUNIĘCIA (SWIPE TO DELETE) ---
                return Dismissible(
                  // Klucz musi być unikalny dla każdego elementu listy
                  key: Key(scanId.toString()),
                  
                  // Ustawiamy kierunek przesunięcia: tylko z prawej do lewej (w lewo)
                  direction: DismissDirection.endToStart,
                  
                  // Czerwone tło z ikoną kosza, które pojawia się pod spodem podczas przesuwania
                  background: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.redAccent[700],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 25.0),
                    child: const Icon(Icons.delete, color: Colors.white, size: 30),
                  ),

                  // Funkcja wywoływana przed ostatecznym usunięciem (potwierdzenie)
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("Potwierdź usunięcie"),
                          content: const Text("Czy na pewno chcesz usunąć ten wpis?"),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false), // Nie usuwaj
                              child: const Text("ANULUJ"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true), // Usuń
                              child: const Text("USUŃ", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        );
                      },
                    );
                  },

                  // Funkcja wywoływana po zaakceptowaniu usunięcia
                  onDismissed: (direction) async {
                    // Usuwamy fizycznie z bazy
                    await DbHelper.instance.deleteScan(scanId);
                    
                    // Usuwamy z lokalnej listy, aby UI się zaktualizowało (bez odświeżania całej bazy)
                    setState(() {
                      _savedScans.removeAt(index);
                    });
                    
                    // Pokazujemy SnackBar z informacją
                    _showSnackBar("Skanowanie zostało usunięte");
                  },
                  
                  // --- TWOJA DOTYCHCZASOWA KARTA SKANOWANIA (Teraz jako dziecko Dismissible) ---
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    elevation: 2,
                    child: ListTile(
                      title: Text(
                        scan['title'], 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                      // Zostawiamy przyciski na karcie (UX: użytkownik ma wybór metody)
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            onPressed: () => _editTitle(scanId, scan['title']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _confirmDelete(scanId, index),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Data: ${scan['scan_date']}", 
                              style: const TextStyle(fontSize: 12, color: Colors.black54)
                            ),
                            const SizedBox(height: 8),
                            Text(
                              scan['detected_items'], 
                              style: const TextStyle(
                                color: Colors.black87, 
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add, size: 30, color: Colors.white),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CameraView()),
          );
          _refreshHistory();
        },
      ),
    );
  }
}