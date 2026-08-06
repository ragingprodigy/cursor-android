import 'package:cursor/features/agents/domain/agents_list_grouping.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgentsListGroupingStore {
  AgentsListGroupingStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const key = 'agents_list_grouping';

  final SharedPreferencesAsync _preferences;

  Future<AgentsListGrouping> load() async {
    final value = await _preferences.getString(key);
    return AgentsListGrouping.fromName(value);
  }

  Future<void> save(AgentsListGrouping grouping) {
    return _preferences.setString(key, grouping.name);
  }
}
