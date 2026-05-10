class Client {
  const Client({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
}
