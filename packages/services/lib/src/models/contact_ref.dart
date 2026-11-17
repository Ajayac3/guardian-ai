import 'package:meta/meta.dart';

/// A reference to a verified emergency contact (the stream target).
@immutable
class ContactRef {
  const ContactRef({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
}
