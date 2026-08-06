import 'package:equatable/equatable.dart';

class LaunchRepositoryOption extends Equatable {
  const LaunchRepositoryOption({
    required this.name,
    required this.url,
    this.defaultBranch,
  });

  final String name;
  final String url;
  final String? defaultBranch;

  @override
  List<Object?> get props => [name, url, defaultBranch];
}

class LaunchModel extends Equatable {
  const LaunchModel({required this.id, required this.name});

  static const defaultModel = LaunchModel(id: 'default', name: 'Default');

  final String id;
  final String name;

  bool get isDefault => id == defaultModel.id;

  @override
  List<Object?> get props => [id, name];
}

class LaunchCatalog extends Equatable {
  const LaunchCatalog({
    required this.repositories,
    required this.models,
    this.message,
  });

  final List<LaunchRepositoryOption> repositories;
  final List<LaunchModel> models;
  final String? message;

  @override
  List<Object?> get props => [repositories, models, message];
}
