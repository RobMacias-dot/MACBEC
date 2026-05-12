class QuotationDraftProspect {
  const QuotationDraftProspect({
    required this.fullName,
    this.phone,
    this.whatsapp,
    this.email,
    this.address,
    this.notes,
  });

  final String fullName;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? address;
  final String? notes;

  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;
  bool get hasWhatsapp => whatsapp != null && whatsapp!.trim().isNotEmpty;
  bool get hasEmail => email != null && email!.trim().isNotEmpty;
  bool get hasAddress => address != null && address!.trim().isNotEmpty;
  bool get hasNotes => notes != null && notes!.trim().isNotEmpty;
}
