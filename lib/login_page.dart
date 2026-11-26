import 'app_version_title.dart';

import 'package:material_ui/material_ui.dart';

import 'auth_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.serverUrl,
    required this.edition,
    required this.onAuthenticated,
    this.authenticate,
    this.onBack,
    this.onRegister,
  });

  final String serverUrl;
  final String edition;
  final Future<void> Function(String securityToken, String jwt) onAuthenticated;
  final Future<String> Function({
    required String serverUrl,
    required String accessToken,
  })?
  authenticate;
  final VoidCallback? onBack;
  final VoidCallback? onRegister;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _token = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  Future<void> _signIn() async {
    if (_busy) return;
    final securityToken = _token.text.trim();
    if (securityToken.isEmpty) {
      setState(() => _error = 'Enter your Ghostfolio security token.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final jwt = await (widget.authenticate ?? AuthClient().authenticate)(
        serverUrl: widget.serverUrl,
        accessToken: securityToken,
      );
      if (!mounted) return;
      await widget.onAuthenticated(securityToken, jwt);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is AuthException
            ? error.message
            : 'Sign-in failed. Check your token and connection.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppVersionTitle(),
        leading: widget.onBack == null
            ? null
            : IconButton(
                tooltip: 'Back',
                onPressed: _busy ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 32),
                const Icon(Icons.lock_outline, size: 72),
                const SizedBox(height: 20),
                Text(
                  widget.edition,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(widget.serverUrl, textAlign: TextAlign.center),
                if (widget.serverUrl.toLowerCase().startsWith('http://')) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'LAN HTTP is not encrypted. Use only on a trusted network; authentication tokens are sent in cleartext.',
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                TextField(
                  controller: _token,
                  obscureText: !_show,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: InputDecoration(
                    labelText: 'Ghostfolio security token',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _show ? 'Hide token' : 'Show token',
                      icon: Icon(
                        _show ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _show = !_show),
                    ),
                  ),
                  onSubmitted: (_) => _signIn(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _signIn,
                  child: Text(_busy ? 'Signing in...' : 'Sign in'),
                ),
                if (widget.onRegister != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _busy ? null : widget.onRegister,
                    child: const Text('Create a Ghostfolio Cloud account'),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 18),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Your security token is stored in the device secure storage. '
                  'It will be used to renew your session after restarting the app.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
