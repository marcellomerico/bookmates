final _usernamePattern = RegExp(r'^[a-z0-9_.]{3,24}$');

/// Mirrors the DB check `profiles_username_format` (DB allows 30 to leave room for suffixes).
String? validateUsername(String value) {
  if (_usernamePattern.hasMatch(value)) return null;
  return 'Benutzername: 3–24 Zeichen, nur a–z, 0–9, _ und .';
}

/// Removes characters with meaning inside PostgREST `or()` filters or LIKE patterns.
String sanitizeSearchTerm(String input) =>
    input.replaceAll(RegExp(r'[,()%*\\"]'), ' ').trim();
