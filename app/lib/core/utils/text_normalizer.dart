/// Normalises names so that visually identical Arabic/English spellings
/// compare equal (used for duplicate detection and matching during import).
///
/// Must stay in sync with `public.sanad_normalize` in the database migration.
class TextNormalizer {
  const TextNormalizer._();

  static final _whitespace = RegExp(r'\s+');
  // Tatweel and Arabic diacritics (harakat).
  static final _strip = RegExp('[ـً-ْ]');

  static const _map = {'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ى': 'ي', 'ة': 'ه'};

  /// Returns the normalised key, or an empty string for blank input.
  static String key(String? input) {
    if (input == null) return '';
    final buffer = StringBuffer();
    for (final rune in input.trim().toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_map[char] ?? char);
    }
    return buffer.toString().replaceAll(_strip, '').replaceAll(_whitespace, ' ').trim();
  }

  /// Trims and collapses internal whitespace while keeping the original spelling.
  static String clean(String? input) => (input ?? '').trim().replaceAll(_whitespace, ' ');

  static bool sameName(String? a, String? b) => key(a) == key(b);
}
