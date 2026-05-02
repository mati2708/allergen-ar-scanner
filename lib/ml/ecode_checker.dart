class ECodeChecker {
  // Baza popularnych kodów E z ich tłumaczeniem i poziomem zagrożenia
  static final Map<String, Map<String, String>> dictionary = {
    // 🟢 NEUTRALNE I BEZPIECZNE (Barwniki naturalne, witaminy, zagęstniki)
    'E100': {'name': 'Kurkumina (naturalny barwnik)', 'level': 'neutral'},
    'E101': {'name': 'Ryboflawina (Witamina B2)', 'level': 'neutral'},
    'E160A': {'name': 'Karoteny (naturalny barwnik)', 'level': 'neutral'},
    'E162': {'name': 'Czerwień buraczana', 'level': 'neutral'},
    'E170': {'name': 'Węglan wapnia', 'level': 'neutral'},
    'E290': {'name': 'Dwutlenek węgla', 'level': 'neutral'},
    'E300': {'name': 'Kwas askorbinowy (Witamina C)', 'level': 'neutral'},
    'E330': {'name': 'Kwas cytrynowy', 'level': 'neutral'},
    'E406': {'name': 'Agar (roślinna żelatyna)', 'level': 'neutral'},
    'E412': {'name': 'Guma guar', 'level': 'neutral'},
    'E440': {'name': 'Pektyny (z owoców)', 'level': 'neutral'},
    'E901': {'name': 'Wosk pszczeli', 'level': 'neutral'},
    'E941': {'name': 'Azot', 'level': 'neutral'},

    // 🟠 ŚREDNIE / OSTRZEGAWCZE (Mogą wywoływać nadpobudliwość lub lekkie reakcje)
    'E102': {'name': 'Tartrazyna (sztuczny barwnik)', 'level': 'warning'},
    'E110': {'name': 'Żółcień pomarańczowa', 'level': 'warning'},
    'E129': {'name': 'Czerwień Allura', 'level': 'warning'},
    'E621': {'name': 'Glutaminian sodu', 'level': 'warning'},
    'E951': {'name': 'Aspartam (słodzik)', 'level': 'warning'},

    // 🔴 NIEBEZPIECZNE / KONTROWERSYJNE (Konserwanty o wysokim ryzyku)
    'E211': {'name': 'Benzoesan sodu', 'level': 'danger'},
    'E220': {'name': 'Dwutlenek siarki (Silny alergen!)', 'level': 'danger'},
    'E249': {'name': 'Azotyn potasu', 'level': 'danger'},
    'E250': {'name': 'Azotyn sodu', 'level': 'danger'},
  };

  /// Funkcja analizująca tekst za pomocą Wyrażeń Regularnych (Regex)
  static Map<String, String>? check(String text) {
    // Regex szuka litery 'E', opcjonalnej spacji/myślnika i 3 lub 4 cyfr z opcjonalną literą (np. E160a)
    final regExp = RegExp(r'E\s?-?(\d{3,4}[a-zA-Z]?)', caseSensitive: false);
    final match = regExp.firstMatch(text);

    if (match != null) {
      // Standaryzujemy kod (np. "e-330" -> "E330")
      String rawCode = match.group(0)!.toUpperCase().replaceAll(RegExp(r'[^E0-9A-Z]'), '');
      
      if (dictionary.containsKey(rawCode)) {
        return {'code': rawCode, ...dictionary[rawCode]!};
      } else {
        // Jeśli wykryjemy kod E, którego nie ma w naszej bazie
        return {'code': rawCode, 'name': 'Dodatek do żywności', 'level': 'neutral'};
      }
    }
    return null;
  }
}