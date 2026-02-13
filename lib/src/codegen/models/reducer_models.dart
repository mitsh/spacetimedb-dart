/// Reducer schema models for SpacetimeDB
library;

import 'type_models.dart';

class ReducerSchema {
  final String name;
  final ProductType params;
  final Map<String, dynamic> lifecycle;

  ReducerSchema({
    required this.name,
    required this.params,
    required this.lifecycle,
  });

  factory ReducerSchema.fromJson(Map<String, dynamic> json) {
    return ReducerSchema(
      name: json['name'] ?? '',
      params: ProductType.fromJson(json['params'] ?? {}),
      lifecycle: json['lifecycle'] ?? {},
    );
  }
}
