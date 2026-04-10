// Typ wyliczeniowy dla poziomu zagrożenia
enum AllergenSeverity { light, medium, dangerous, unknown }

class Allergen {
  final String name;
  final AllergenSeverity severity;

  Allergen({required this.name, required this.severity});

  // Pomocnicza metoda do wyświetlania koloru w zależności od zagrożenia
  // Przydadzą się później do rysowania ramek AR!
  int get severityColorHex {
    switch (severity) {
      case AllergenSeverity.light:
        return 0xFFFDD835; // Żółty
      case AllergenSeverity.medium:
        return 0xFFFB8C00; // Pomarańczowy
      case AllergenSeverity.dangerous:
        return 0xFFE53935; // Czerwony
      default:
        return 0xFF9E9E9E; // Szary
    }
  }
}