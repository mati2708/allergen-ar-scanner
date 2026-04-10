# 🛡️ Allergen AR Scanner - System Wspomagania Alergików (R&D)

Projekt badawczo-rozwojowy (Etap 2) realizowany w ramach kursu inżynierskiego. Aplikacja mobilna wykorzystująca rozszerzoną rzeczywistość (AR) oraz sieci neuronowe do detekcji i klasyfikacji alergenów w składzie produktów spożywczych.

---

## 📋 Cel Projektu
Celem projektu jest stworzenie narzędzia typu Proof of Concept (PoC), które pozwoli na natychmiastową identyfikację składników niebezpiecznych dla zdrowia bezpośrednio na etykiecie produktu, eliminując konieczność żmudnego czytania drobnego druku.

## 🧠 Architektura Systemu (Pipeline R&D)
Aplikacja realizuje proces przetwarzania danych w następujących krokach:
1. **Akwizycja Danych**: Przechwytywanie strumienia wideo (NV21/BGRA8888) za pomocą Camera2 API.
2. **OCR (Preprocessing)**: Ekstrakcja tekstu za pomocą Google ML Kit Text Recognition.
3. **NLP Classification**: Autorski model **TensorFlow Lite** (sieć neuronowa z warstwą Embedding), klasyfikujący tokeny tekstowe do kategorii zagrożenia.
4. **Wizualizacja AR**: Mapowanie koordynatów bounding-boxów z sensora kamery na Canvas UI z uwzględnieniem skalowania ekranu.

## 📊 Metodyka Badawcza (Etap 2)
W obecnym etapie skupiono się na ewaluacji modelu klasyfikacyjnego.

### Charakterystyka Zbioru Danych (Dataset)
- **Rozmiar**: 200+ unikalnych fraz (składników) w języku polskim i angielskim.
- **Klasy**: Dangerous (Mleko, Orzechy), Medium (Gluten, Jaja), Light (Soja), Unknown.
- **Preprocessing**: Normalizacja tekstu, usuwanie znaków specjalnych, tokenizacja.

### Wyniki Modelu AI
Podczas testów R&D badano wpływ liczby epok uczenia na precyzję (Accuracy) modelu:
| Epoki | Accuracy | Średnia Pewność (Confidence) |
|-------|----------|-----------------------------|
| 50    | ~30%     | Niska (Underfitting)        |
| 500   | ~98%     | Wysoka (Target reached)     |

## 🛠️ Instalacja i Uruchomienie
1. Sklonuj repozytorium: `git clone [url]`
2. Pobierz zależności: `flutter pub get`
3. Upewnij się, że pliki `assets/models/allergen_model.tflite` oraz `vocab.json` są na miejscu.
4. Uruchom aplikację: `flutter run`

## ⚠️ Przypadki Brzegowe i Ograniczenia
W toku badań zidentyfikowano następujące wyzwania:
- **Oświetlenie**: Refleksy na foliowych opakowaniach obniżają skuteczność OCR.
- **Geometria**: Zagięcia opakowań (np. batony) zniekształcają tekst (implementacja podpowiedzi UX pomaga rozwiązać ten problem).
- **Fleksja**: Model AI radzi sobie z odmianą słów dzięki treningowi na rozszerzonym zbiorze synonimów.

## 📅 Mapa Drogowa (Roadmap)
- [x] Implementacja silnika OCR i nakładki AR.
- [x] Trening i integracja modelu TFLite (NLP).
- [x] Obsługa wielojęzyczności (PL/EN).
- [ ] Etap 3: Optymalizacja wydajności (FPS) i rozbudowa bazy danych o 500 nowych fraz.

---
*Projekt ma charakter badawczy i nie powinien być traktowany jako ostateczne źródło informacji medycznej.*