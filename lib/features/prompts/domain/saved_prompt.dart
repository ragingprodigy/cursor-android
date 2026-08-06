import 'package:equatable/equatable.dart';

class SavedPrompt extends Equatable {
  const SavedPrompt({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String body;
  final String? notes;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool matchesQuery(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    if (title.toLowerCase().contains(needle)) {
      return true;
    }
    if (body.toLowerCase().contains(needle)) {
      return true;
    }
    final notesText = notes?.toLowerCase();
    if (notesText != null && notesText.contains(needle)) {
      return true;
    }
    return tags.any((tag) => tag.toLowerCase().contains(needle));
  }

  @override
  List<Object?> get props => [id, title, body, notes, tags, createdAt, updatedAt];
}
