import 'mobile_shell.dart';
import 'app_version_title.dart';

import 'package:material_ui/material_ui.dart';

import 'app_theme_controller.dart';

import 'server_client.dart';
import 'server_info.dart';
import 'auth_client.dart';
import 'login_page.dart';
import 'registration_page.dart';
import 'session_store.dart';

void main() {
  runApp(const SpookyfolioApp());
}

typedef ServerInspector = Future<ServerInfo> Function(String address);

class SpookyfolioApp extends StatefulWidget {
  const SpookyfolioApp({super.key, this.inspect});

  final ServerInspector? inspect;

  @override
  State<SpookyfolioApp> createState() => _SpookyfolioAppState();
}

class _SpookyfolioAppState extends State<SpookyfolioApp> {
  final _theme = AppThemeController();

  @override
  void initState() {
    super.initState();
    _theme.load();
  }

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _theme,
    builder: (context, _) => MaterialApp(
      title: 'Spookyfolio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8250DF),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8250DF),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _theme.mode,
      home: SessionGate(
        inspect: widget.inspect ?? ServerClient().inspect,
        themeMode: _theme.mode,
        onThemeChanged: _theme.setMode,
      ),
    ),
  );
}

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key, required this.inspect, this.onConnected});

  final ServerInspector inspect;
  final void Function(String serverUrl, ServerInfo info)? onConnected;

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final _address = TextEditingController();
  bool _cloud = true;
  bool _loading = false;
  ServerInfo? _server;
  String? _error;

  String get _selectedAddress =>
      _cloud ? 'https://ghostfol.io' : _address.text.trim();

  Future<void> _connect() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _server = null;
      _error = null;
    });

    try {
      final result = await widget.inspect(_selectedAddress);
      if (!mounted) return;
      setState(() => _server = result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is FormatException ? error.message : 'Connection failed. Check the server address, network and HTTPS certificate.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppVersionTitle()),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 28),
                const Icon(Icons.account_balance_wallet_outlined, size: 88),
                const SizedBox(height: 16),
                Text(
                  'Spookyfolio',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect to your Ghostfolio server',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SwitchListTile(
                  title: const Text('Ghostfolio Cloud'),
                  subtitle: const Text('https://ghostfol.io'),
                  value: _cloud,
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() {
                            _cloud = value;
                            _server = null;
                            _error = null;
                          });
                        },
                ),
                if (!_cloud) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _address,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://portfolio.example.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_address.text.trim().toLowerCase().startsWith('http://'))
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'LAN HTTP is not encrypted. Use only on a trusted network; authentication tokens are sent in cleartext.',
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _connect,
                  child: Text(_loading ? 'Connecting...' : 'Check connection'),
                ),
                if (_loading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_server != null) ...[
                  const SizedBox(height: 24),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(_server!.edition),
                      subtitle: const Text('Server identified successfully'),
                    ),
                  ),
                ],
                if (_server != null && widget.onConnected != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        widget.onConnected!(_selectedAddress, _server!),
                    child: const Text('Continue to sign in'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 24),
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

class SessionGate extends StatefulWidget {
  const SessionGate({
    super.key,
    required this.inspect,
    this.themeMode = ThemeMode.dark,
    this.onThemeChanged,
  });

  final ServerInspector inspect;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode)? onThemeChanged;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final _store = SessionStore();
  bool _restoring = true;
  String? _serverUrl;
  String? _edition;
  String? _jwt;
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final saved = await _store.read();
      if (saved != null) {
        final info = await widget.inspect(saved.serverUrl);
        final jwt = await AuthClient().authenticate(
          serverUrl: saved.serverUrl,
          accessToken: saved.securityToken,
        );
        if (!mounted) return;
        setState(() {
          _serverUrl = saved.serverUrl;
          _edition = info.edition;
          _jwt = jwt;
        });
      }
    } catch (_) {
      // Keep saved credentials for temporary network failures.
      // An explicit logout always removes them.
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _logout() async {
    await _store.clear();
    if (!mounted) return;
    setState(() {
      _jwt = null;
      _registering = false;
      _serverUrl = null;
      _edition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_jwt != null && _serverUrl != null) {
      return MobileShell(
        serverUrl: _serverUrl!,
        jwt: _jwt!,
        edition: _edition ?? 'Ghostfolio',
        onSignOut: _logout,
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
      );
    }
    if (_serverUrl != null && _registering) {
      return RegistrationPage(
        serverUrl: _serverUrl!,
        onBack: () => setState(() => _registering = false),
        onRegistered: (token, jwt) async {
          // RegistrationPage has already saved (or disclosed) the token.
          if (!mounted) return;
          setState(() {
            _jwt = jwt;
            _registering = false;
          });
        },
      );
    }
    if (_serverUrl != null) {
      return LoginPage(
        serverUrl: _serverUrl!,
        edition: _edition ?? 'Ghostfolio',
        onRegister: _serverUrl == 'https://ghostfol.io'
            ? () => setState(() => _registering = true)
            : null,
        onBack: () => setState(() {
          _serverUrl = null;
          _edition = null;
        }),
        onAuthenticated: (token, jwt) async {
          await _store.save(
            SavedCredentials(serverUrl: _serverUrl!, securityToken: token),
          );
          if (!mounted) return;
          setState(() => _jwt = jwt);
        },
      );
    }
    return ConnectionPage(
      inspect: widget.inspect,
      onConnected: (url, info) => setState(() {
        _serverUrl = url;
        _edition = info.edition;
      }),
    );
  }
}
