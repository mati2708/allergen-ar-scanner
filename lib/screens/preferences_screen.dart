import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({Key? key}) : super(key: key);

  @override
  _PreferencesScreenState createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  // Baza głównych alergenów do wyboru (Rozszerzona!)
  final List<String> _availableAllergens = [
    'mleko', 
    'orzeszki', 
    'gluten', 
    'soja', 
    'jaja',
    'ryby',
    'skorupiaki',
    'seler',
    'gorczyca',
    'sezam',
    'dwutlenek siarki',
    'mięczaki'
  ];

  // Koszyk na to, co zaznaczy użytkownik
  Set<String> _selectedAllergens = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // Odczyt z pamięci telefonu (uruchamiane przy starcie ekranu)
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? saved = prefs.getStringList('my_allergens');
    
    if (saved != null) {
      setState(() {
        _selectedAllergens = saved.toSet();
      });
    } else {
      // Domyślnie zaznaczamy wszystko przy pierwszym uruchomieniu aplikacji
      setState(() {
        _selectedAllergens = _availableAllergens.toSet();
      });
    }
  }

  // Zapis do pamięci telefonu (uruchamiane po każdym kliknięciu)
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_allergens', _selectedAllergens.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje Alergeny'),
        backgroundColor: Colors.blueAccent,
      ),
      body: ListView.builder(
        itemCount: _availableAllergens.length,
        itemBuilder: (context, index) {
          final allergen = _availableAllergens[index];
          
          return CheckboxListTile(
            title: Text(
              allergen.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Ostrzegaj mnie przed tym składnikiem'),
            activeColor: Colors.redAccent,
            value: _selectedAllergens.contains(allergen),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedAllergens.add(allergen);
                } else {
                  _selectedAllergens.remove(allergen);
                }
                _savePreferences(); // Zapisujemy od razu w tle
              });
            },
          );
        },
      ),
    );
  }
}