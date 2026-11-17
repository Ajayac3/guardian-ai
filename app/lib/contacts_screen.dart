import 'package:flutter/material.dart';
import 'package:guardian_shared/guardian_shared.dart';

import 'account_api.dart';

/// Manage emergency contacts: add one, verify it with the OTP it receives, and
/// revoke it. Only a `verified` contact can be a session's stream target.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({required this.api, super.key});

  final AccountApi api;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late Future<List<EmergencyContact>> _contacts;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _contacts = widget.api.listContacts());
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addContact() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddContactDialog(api: widget.api),
    );
    if (added ?? false) _reload();
  }

  Future<void> _verify(EmergencyContact c) async {
    final verified = await showDialog<bool>(
      context: context,
      builder: (_) => _VerifyDialog(api: widget.api, contact: c),
    );
    if (verified ?? false) {
      _toast('${c.name} verified.');
      _reload();
    }
  }

  Future<void> _revoke(EmergencyContact c) async {
    try {
      await widget.api.revokeContact(c.id);
      _reload();
    } catch (e) {
      _toast('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency contacts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addContact,
        icon: const Icon(Icons.person_add),
        label: const Text('Add'),
      ),
      body: FutureBuilder<List<EmergencyContact>>(
        future: _contacts,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          final contacts = (snap.data ?? [])
              .where((c) => !c.isRevoked)
              .toList();
          if (contacts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No contacts yet. Add a trusted person who can watch your '
                  'emergency stream.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: contacts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = contacts[i];
              return ListTile(
                title: Text(c.name),
                subtitle: Text(c.email ?? c.phone ?? c.relationship ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c.isVerified)
                      const Chip(
                        label: Text('verified'),
                        avatar: Icon(Icons.verified, size: 16),
                      )
                    else
                      TextButton(
                        onPressed: () => _verify(c),
                        child: const Text('Verify'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _revoke(c),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AddContactDialog extends StatefulWidget {
  const _AddContactDialog({required this.api});

  final AccountApi api;

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _relationship = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        (_email.text.trim().isEmpty && _phone.text.trim().isEmpty)) {
      setState(() => _error = 'Name and an email or phone are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.api.addContact(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        relationship: _relationship.text.trim(),
      );
      // Fire the verification code immediately so the contact can confirm.
      await widget.api.sendOtp(id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add contact'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            TextField(
              controller: _relationship,
              decoration: const InputDecoration(
                labelText: 'Relationship (optional)',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: GuardianTheme.emergencyRed),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send code'),
        ),
      ],
    );
  }
}

class _VerifyDialog extends StatefulWidget {
  const _VerifyDialog({required this.api, required this.contact});

  final AccountApi api;
  final EmergencyContact contact;

  @override
  State<_VerifyDialog> createState() => _VerifyDialogState();
}

class _VerifyDialogState extends State<_VerifyDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    try {
      await widget.api.sendOtp(widget.contact.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('New code sent.')));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.verifyOtp(widget.contact.id, _code.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Verify ${widget.contact.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter the 6-digit code sent to '
            '${widget.contact.email ?? widget.contact.phone}.',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Code'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: GuardianTheme.emergencyRed),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _resend,
          child: const Text('Resend'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }
}
