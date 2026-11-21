import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_version_title.dart';

import 'package:material_ui/material_ui.dart';

import 'registration_client.dart';
import 'session_store.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({
    super.key,
    required this.serverUrl,
    required this.onRegistered,
    required this.onBack,
    this.register,
    this.saveCredentials,
  });

  final String serverUrl;
  final Future<void> Function(String securityToken, String jwt) onRegistered;
  final VoidCallback onBack;
  final Future<RegistrationResult> Function({required String serverUrl})?
  register;
  final Future<void> Function(SavedCredentials credentials)? saveCredentials;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  bool _busy = false;
  bool _acknowledged = false;
  RegistrationResult? _created;
  String? _error;
  bool _stored = false;

  Future<void> _create() async {
    if (_busy || _created != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // This POST creates a real account. Never retry automatically.
      final result = await (widget.register ?? RegistrationClient().register)(
        serverUrl: widget.serverUrl,
      );
      if (!mounted) return;
      // Preserve the token before navigating away. If storage fails, keep it
      // visible so the user can record it manually.
      setState(() => _created = result);
      try {
        await (widget.saveCredentials ?? SessionStore().save)(
          SavedCredentials(
            serverUrl: widget.serverUrl,
            securityToken: result.securityToken,
          ),
        );
        if (!mounted) return;
        setState(() => _stored = true);
      } catch (_) {
        if (!mounted) return;
        setState(
          () => _error = 'Secure storage failed. Save the token manually before leaving this screen.',
        );
      }
    } catch (error) {
      if (!mounted) return;

      String message;

      if (error is RegistrationException) {
        message = error.message;
      } else if (error is FormatException) {
        const knownMessages = {
          'Invalid registration content type',
          'Registration response too large',
          'Invalid registration response',
        };

        message = knownMessages.contains(error.message)
            ? error.message
            : 'The server returned invalid JSON. Account creation '
                  'may have succeeded; do not retry yet.';
      } else if (error is TimeoutException) {
        message =
            'Registration timed out. Account creation may have '
            'succeeded; do not retry yet.';
      } else if (error is HandshakeException) {
        message = 'TLS certificate or handshake error.';
      } else if (error is SocketException || error is http.ClientException) {
        message =
            'Network error during registration. The outcome '
            'is uncertain; do not retry yet.';
      } else {
        message =
            'Unexpected registration error '
            '(${error.runtimeType}). Do not retry yet.';
      }

      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continue() async {
    final created = _created;
    if (_busy || created == null || !_acknowledged) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onRegistered(created.securityToken, created.jwt);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'Could not complete sign-in. Keep a copy of your security token.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    return Scaffold(
      appBar: AppBar(
        title: const AppVersionTitle(),
        leading: created == null
            ? IconButton(
                tooltip: 'Back',
                onPressed: _busy ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),
                Icon(
                  created == null ? Icons.person_add_alt_1 : Icons.key,
                  size: 76,
                ),
                const SizedBox(height: 20),
                Text(
                  created == null
                      ? 'Create a new account'
                      : 'Save your security token',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (created == null) ...[
                  const Text(
                    'This creates a new anonymous Ghostfolio Cloud account. '
                    'No email address is required. Your security token will be '
                    'your account credential; losing it may prevent access to '
                    'your portfolio.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _create,
                    child: const Text('Create account'),
                  ),
                ] else ...[
                  const Text(
                    'This is your new account credential. Record it in your '
                    'password manager before continuing. Never share it.',
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        created.securityToken,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _stored
                        ? 'Credentials saved in device secure storage.'
                        : 'Secure storage not confirmed. Keep a manual copy.',
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('I have saved my security token'),
                    value: _acknowledged,
                    onChanged: _busy
                        ? null
                        : (value) =>
                              setState(() => _acknowledged = value ?? false),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || !_acknowledged ? null : _continue,
                    child: const Text('Continue to Spookyfolio'),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
