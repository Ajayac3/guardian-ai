import 'package:supabase_flutter/supabase_flutter.dart';

/// One of the owner's emergency contacts.
class EmergencyContact {
  EmergencyContact({
    required this.id,
    required this.name,
    required this.status,
    this.email,
    this.phone,
    this.relationship,
  });

  final String id;
  final String name;
  final String status;
  final String? email;
  final String? phone;
  final String? relationship;

  bool get isVerified => status == 'verified';
  bool get isRevoked => status == 'revoked';

  static EmergencyContact fromRow(Map<String, dynamic> r) => EmergencyContact(
    id: r['id'] as String,
    name: r['name'] as String,
    status: r['status'] as String,
    email: r['contact_email'] as String?,
    phone: r['contact_phone'] as String?,
    relationship: r['relationship'] as String?,
  );
}

/// Owner-side account operations: onboarding attestation, contacts + OTP
/// verification, region/consent, and GDPR export/delete. Direct table writes go
/// through RLS (owner-scoped); the privileged paths call Edge functions.
class AccountApi {
  AccountApi(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  Future<bool> isOnboarded() async {
    final uid = _uid;
    if (uid == null) return false;
    final row = await _client
        .from('profiles')
        .select('anti_stalking_attested_at')
        .eq('id', uid)
        .maybeSingle();
    return row?['anti_stalking_attested_at'] != null;
  }

  Future<void> attestAntiStalking({String? regionCode}) async {
    final uid = _requireUid();
    await _client.from('profiles').upsert({
      'id': uid,
      'anti_stalking_attested_at': DateTime.now().toUtc().toIso8601String(),
      if (regionCode != null && regionCode.isNotEmpty)
        'region_code': regionCode,
    });
  }

  Future<List<EmergencyContact>> listContacts() async {
    final rows = await _client
        .from('emergency_contacts')
        .select('id,name,contact_email,contact_phone,relationship,status')
        .order('created_at');
    return (rows as List)
        .map((r) => EmergencyContact.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<String> addContact({
    required String name,
    String? email,
    String? phone,
    String? relationship,
  }) async {
    final uid = _requireUid();
    final row = await _client
        .from('emergency_contacts')
        .insert({
          'owner_id': uid,
          'name': name,
          if (email != null && email.isNotEmpty) 'contact_email': email,
          if (phone != null && phone.isNotEmpty) 'contact_phone': phone,
          if (relationship != null && relationship.isNotEmpty)
            'relationship': relationship,
          'status': 'pending',
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> revokeContact(String id) async {
    await _client
        .from('emergency_contacts')
        .update({'status': 'revoked'})
        .eq('id', id);
  }

  Future<void> sendOtp(String contactId) =>
      _call('send-contact-otp', {'contact_id': contactId});

  Future<void> verifyOtp(String contactId, String code) =>
      _call('contact-verify', {'contact_id': contactId, 'code': code});

  Future<void> setRegion(String code) async {
    final uid = _requireUid();
    await _client.from('profiles').upsert({'id': uid, 'region_code': code});
  }

  Future<Map<String, dynamic>> exportData() async {
    final res = await _call('export-user-data', null);
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<void> deleteAccount() => _call('delete-user-account', null);

  String _requireUid() {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in.');
    return uid;
  }

  Future<FunctionResponse> _call(String fn, Map<String, dynamic>? body) async {
    try {
      return await _client.functions.invoke(fn, body: body);
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = (d is Map && d['error'] != null)
          ? d['error'].toString()
          : 'request failed (${e.status})';
      throw Exception(msg);
    }
  }
}
