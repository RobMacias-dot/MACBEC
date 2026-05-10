class CompanyProfile {
  const CompanyProfile({
    required this.id,
    required this.companyName,
    required this.rfc,
    required this.phone,
    required this.email,
    required this.address,
  });

  const CompanyProfile.empty()
      : id = null,
        companyName = '',
        rfc = '',
        phone = '',
        email = '',
        address = '';

  final String? id;
  final String companyName;
  final String rfc;
  final String phone;
  final String email;
  final String address;

  bool get hasData {
    return companyName.trim().isNotEmpty ||
        rfc.trim().isNotEmpty ||
        phone.trim().isNotEmpty ||
        email.trim().isNotEmpty ||
        address.trim().isNotEmpty;
  }

  CompanyProfile copyWith({
    String? id,
    String? companyName,
    String? rfc,
    String? phone,
    String? email,
    String? address,
  }) {
    return CompanyProfile(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      rfc: rfc ?? this.rfc,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
    );
  }
}
