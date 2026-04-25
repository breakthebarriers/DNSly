import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';

class ProfileRepository {
  static const _key = 'dnsly_profiles';

  Future<List<Profile>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => Profile.fromJson(jsonDecode(s)))
        .toList();
  }

  Future<void> save(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getAll();
    final idx = profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      profiles[idx] = profile;
    } else {
      profiles.add(profile);
    }
    await prefs.setStringList(
      _key,
      profiles.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getAll();
    profiles.removeWhere((p) => p.id == id);
    await prefs.setStringList(
      _key,
      profiles.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}
