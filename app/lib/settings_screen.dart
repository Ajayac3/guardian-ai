import 'package:flutter/material.dart';
import 'package:guardian_services/guardian_services.dart';
import 'package:guardian_shared/guardian_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_api.dart';
import 'onboarding_screen.dart' show regions;

/// Region/consent, push opt-in, and the GDPR data export / account deletion
/// controls (App Store + Play Store both require account deletion in-app).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.api, required this.push, super.key});

  final AccountApi api;
  final PushService? push;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _region = regions.first;
  bool _pushOn = false;
  bool _busy = false;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _setRegion(String code) async {
    setState(() => _region = code);
    try {
      await widget.api.setRegion(code);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _togglePush(bool on) async {
    setState(() => _pushOn = on);
    if (!on) return;
    final token = await widget.push?.registerToken();
    if (!mounted) return;
    if (token == null) {
      setState(() => _pushOn = false);
      _toast('Push is not available (Firebase not configured on this build).');
    } else {
      _toast('Push notifications enabled.');
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await widget.api.exportData();
      final sessions = (data['emergency_sessions'] as List?)?.length ?? 0;
      final contacts = (data['emergency_contacts'] as List?)?.length ?? 0;
      final evidence = (data['evidence_manifest'] as List?)?.length ?? 0;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Your data'),
          content: Text(
            'Exported $contacts contacts, $sessions sessions and $evidence '
            'evidence records. The full machine-readable bundle was retrieved '
            'from the server.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account, contacts, sessions and '
          'evidence records. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: GuardianTheme.emergencyRed,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    setState(() => _busy = true);
    try {
      await widget.api.deleteAccount();
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        _toast('Account deleted.');
      }
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Region'),
            subtitle: const Text('Determines recording-consent rules'),
            trailing: DropdownButton<String>(
              value: _region,
              items: regions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => v == null ? null : _setRegion(v),
            ),
          ),
          SwitchListTile(
            title: const Text('Push notifications'),
            subtitle: const Text('Alerts about your session state'),
            value: _pushOn,
            onChanged: _busy ? null : _togglePush,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export my data'),
            onTap: _busy ? null : _export,
          ),
          ListTile(
            leading: const Icon(
              Icons.delete_forever,
              color: GuardianTheme.emergencyRed,
            ),
            title: const Text(
              'Delete my account',
              style: TextStyle(color: GuardianTheme.emergencyRed),
            ),
            onTap: _busy ? null : _deleteAccount,
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
