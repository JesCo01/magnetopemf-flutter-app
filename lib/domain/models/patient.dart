class Patient {
  final String id;
  final String name;
  final String condition;
  final int age;
  final DateTime createdAt;

  Patient({
    required this.id,
    required this.name,
    required this.condition,
    required this.age,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'condition': condition,
      'age': age,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      name: json['name'],
      condition: json['condition'],
      age: json['age'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
