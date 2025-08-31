abstract class StorageRepository {
  // String operations
  Future<void> setString(String key, String value);
  Future<String?> getString(String key);
  Future<void> remove(String key);

  // Boolean operations
  Future<void> setBool(String key, bool value);
  Future<bool?> getBool(String key);

  // Integer operations
  Future<void> setInt(String key, int value);
  Future<int?> getInt(String key);

  // Double operations
  Future<void> setDouble(String key, double value);
  Future<double?> getDouble(String key);

  // List operations
  Future<void> setStringList(String key, List<String> value);
  Future<List<String>?> getStringList(String key);

  // Utility
  Future<void> clear();
  Future<Set<String>> getKeys();
}
