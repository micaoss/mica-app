import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'console/client.dart';
import 'console/devices.dart';
import 'console/discovery.dart';
import 'l10n/app_localizations.dart';
import 'manage_settings.dart';
import 'setup_page.dart' show Alert;

// Managing a device over its HTTP API, for one with no Bluetooth or no web
// console: find it, set it up or sign in, then its status (mica-core
// `docs/provisioning-flow.md` sections 4 and 6).

typedef TransportFactory = Transport Function(Uri base, String? pin);

Transport ioTransport(Uri base, String? pin) => IoTransport(base, pin: pin);

sealed class Stage {
  const Stage();
}

class PickStage extends Stage {
  const PickStage();
}

class BusyStage extends Stage {
  const BusyStage(this.text);
  final String text;
}

class StopStage extends Stage {
  const StopStage(this.text);
  final String text;
}

/// The certificate changed since the device was saved.
class PinStage extends Stage {
  const PinStage(this.device, this.seen);
  final Saved device;
  final String seen;
}

class SetupStage extends Stage {
  const SetupStage({required this.deviceCode});
  final bool deviceCode;
}

class SignInStage extends Stage {
  const SignInStage();
}

/// What the status screen shows; every part may be missing.
class Dash {
  const Dash({
    required this.hostname,
    required this.meta,
    required this.health,
    required this.info,
    required this.time,
    required this.network,
    required this.console,
  });

  final String? hostname;
  final Json? meta, health, info, time, network;
  final bool console;

  List<String> get features => [for (final f in meta?['features'] is List ? meta!['features'] as List : const []) '$f'];
}

class DashStage extends Stage {
  const DashStage(this.dash);
  final Dash dash;
}

class NetworkStage extends Stage {
  const NetworkStage(this.dash);
  final Dash dash;
}

class SettingsStage extends Stage {
  const SettingsStage(this.dash);
  final Dash dash;
}

class ManagePage extends StatefulWidget {
  const ManagePage({
    super.key,
    required this.discovery,
    required this.store,
    required this.open,
    this.transport = ioTransport,
    this.initial,
  });

  final Discovery discovery;
  final DeviceStore store;
  final TransportFactory transport;

  /// Opens the remote console in the phone's browser.
  final Future<void> Function(Uri url) open;

  /// An address to connect to at once, such as a console URL from Bluetooth setup.
  final Uri? initial;

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
  Stage _stage = const PickStage();
  String _notice = '';
  List<Saved> _saved = const [];
  ConsoleClient? _client;
  Saved? _device;

  AppLocalizations get t => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    widget.store.load().then((s) {
      if (mounted) setState(() => _saved = s);
      final initial = widget.initial;
      if (initial != null && mounted) _connect(initial.host, [initial]);
    });
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  void _go(Stage s, [String notice = '']) {
    if (!mounted) return;
    setState(() {
      _stage = s;
      _notice = notice;
    });
  }

  String _failure(Object e) => switch (e) {
    ApiFailure(code: 'login_throttled') || ApiFailure(status: 429) => t.throttled,
    ApiFailure(:final code) => t.requestFailed(code),
    _ => t.connectionLost,
  };

  /// Tries [tries] in order with the pin saved for the address, if any.
  Future<void> _connect(String name, List<Uri> tries) async {
    _go(BusyStage(t.connecting));
    _client?.close();
    _client = null;
    for (var base in tries) {
      if (base.host.endsWith('.local')) {
        final ip = await widget.discovery.resolve(base.host);
        if (ip != null) base = base.replace(host: ip);
      }
      final saved = _saved.where((d) => d.base == base).firstOrNull;
      final client = ConsoleClient(widget.transport(base, saved?.pin));
      try {
        final session = await client.session();
        _client = client;
        _device = Saved(saved?.name ?? name, base, pin: saved?.pin ?? client.transport.seen);
        return switch (session.state) {
          SessionState.setup => _go(SetupStage(deviceCode: session.deviceCodeRequired)),
          SessionState.unauthenticated => _go(const SignInStage()),
          SessionState.authenticated => _load(),
        };
      } on PinMismatch catch (e) {
        client.close();
        return _go(PinStage(saved!, e.seen));
      } catch (_) {
        client.close();
      }
    }
    _go(const PickStage(), t.unreachable(name));
  }

  Future<void> _trust(Saved device, String seen) async {
    final updated = device.withPin(seen);
    await _remember(updated);
    await _connect(device.name, [device.base]);
  }

  Future<void> _remember(Saved d) async {
    _saved = remember(_saved, d);
    await widget.store.save(_saved);
  }

  Future<void> _forget(Saved d) async {
    setState(() => _saved = _saved.where((x) => x.base != d.base).toList());
    await widget.store.save(_saved);
  }

  /// The device answered a signed-in request: keep it, with its certificate.
  Future<void> _signedIn() async {
    final d = _device!;
    _device = d.withPin(d.pin ?? _client!.transport.seen);
    await _remember(_device!);
    await _load();
  }

  Future<void> _setup(String password, String hostname, String code) async {
    _go(BusyStage(t.connecting));
    try {
      await _client!.setup(password: password, hostname: hostname, deviceCode: code);
    } on ApiFailure catch (e) {
      return switch (e.code) {
        'device_code_incorrect' => _go(SetupStage(deviceCode: code.isNotEmpty), t.deviceCodeIncorrect),
        'already_configured' => _go(const SignInStage(), t.alreadyConfigured),
        _ => _go(SetupStage(deviceCode: code.isNotEmpty), _failure(e)),
      };
    } catch (e) {
      return _go(const PickStage(), _failure(e));
    }
    await _signedIn();
  }

  Future<void> _signIn(String password) async {
    _go(BusyStage(t.verifying));
    try {
      await _client!.login(password);
    } on ApiFailure catch (e) {
      return switch (e.status) {
        401 => _go(const SignInStage(), t.wrongPassword),
        409 => _connect(_device!.name, [_device!.base]),
        _ => _go(const SignInStage(), _failure(e)),
      };
    } catch (e) {
      return _go(const PickStage(), _failure(e));
    }
    await _signedIn();
  }

  Future<void> _load() async {
    final c = _client!;
    _go(BusyStage(t.connecting));
    Future<T?> part<T>(Future<T> f) async {
      try {
        return await f;
      } on ApiFailure catch (e) {
        if (e.status == 401) rethrow;
        return null;
      } on SocketException {
        return null;
      }
    }

    try {
      final meta = await c.meta();
      if (meta['api'] is String && meta['api'] != 'v1') return _go(StopStage(t.apiUnsupported('${meta['api']}')));
      final r = await Future.wait([
        part(c.hostname()),
        part(c.health()),
        part(c.systemInfo()),
        part(c.timeStatus()),
        part(c.networkStatus()),
        part(c.hasConsole()),
      ]);
      _go(
        DashStage(
          Dash(
            hostname: r[0] as String?,
            meta: meta,
            health: r[1] as Json?,
            info: r[2] as Json?,
            time: r[3] as Json?,
            network: r[4] as Json?,
            console: r[5] == true,
          ),
        ),
      );
    } on ApiFailure catch (e) {
      if (e.status == 401) return _go(const SignInStage(), t.sessionExpired);
      _go(const PickStage(), _failure(e));
    } catch (e) {
      _go(const PickStage(), _failure(e));
    }
  }

  void _expired() => _go(const SignInStage(), t.sessionExpired);

  Future<void> _signOut() async {
    try {
      await _client?.logout();
    } catch (_) {}
    _client?.close();
    _client = null;
    _go(const PickStage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.manageTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_device != null && _stage is! PickStage) ...[
                Text(_device!.name, style: Theme.of(context).textTheme.titleMedium),
                Text('${_device!.base}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
              ],
              if (_notice.isNotEmpty) ...[Alert(_notice), const SizedBox(height: 12)],
              _stageView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageView() {
    return switch (_stage) {
      PickStage() => PickView(
        discovery: widget.discovery,
        saved: _saved,
        onPick: _connect,
        onForget: _forget,
        onLocal: () => _go(const PickStage(), t.consoleLocal),
      ),
      BusyStage(:final text) => Row(
        children: [
          const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
      StopStage(:final text) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Alert(text),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => _go(const PickStage()), child: Text(t.back)),
        ],
      ),
      PinStage(:final device, :final seen) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Alert(t.certChanged),
          const SizedBox(height: 12),
          Text(t.certFingerprint, style: Theme.of(context).textTheme.labelMedium),
          SelectableText(seen, style: const TextStyle(fontFamily: 'monospace')),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => _go(const PickStage()), child: Text(t.back)),
          const SizedBox(height: 8),
          TextButton(onPressed: () => _trust(device, seen), child: Text(t.trustNew)),
        ],
      ),
      SetupStage(:final deviceCode) => SetupForm(key: ValueKey(deviceCode), deviceCode: deviceCode, onSubmit: _setup),
      SignInStage() => SignInForm(onSubmit: _signIn),
      DashStage(:final dash) => DashView(
        dash: dash,
        onRefresh: _load,
        onNetwork: () => _go(NetworkStage(dash)),
        onSettings: () => _go(SettingsStage(dash)),
        onOpenConsole: () => widget.open(_device!.base),
        onSignOut: _signOut,
      ),
      NetworkStage(:final dash) => NetworkView(
        client: _client!,
        wifi: dash.features.contains('wifi'),
        onExpired: _expired,
        onBack: _load,
      ),
      SettingsStage(:final dash) => SettingsView(
        client: _client!,
        hostname: dash.hostname ?? '',
        ssh: dash.features.contains('ssh'),
        onExpired: _expired,
        onBack: _load,
      ),
    };
  }
}

/// Devices on this network, the ones signed in to before, and an address.
class PickView extends StatefulWidget {
  const PickView({
    super.key,
    required this.discovery,
    required this.saved,
    required this.onPick,
    required this.onForget,
    required this.onLocal,
  });

  final Discovery discovery;
  final List<Saved> saved;
  final void Function(String name, List<Uri> tries) onPick;
  final void Function(Saved) onForget;

  /// A device whose console does not serve the network was picked.
  final VoidCallback onLocal;

  @override
  State<PickView> createState() => _PickViewState();
}

class _PickViewState extends State<PickView> {
  final _address = TextEditingController();
  List<Found>? _found;
  Timer? _again;

  @override
  void initState() {
    super.initState();
    _browse();
  }

  /// A round of discovery now and every 5 seconds while the list shows.
  Future<void> _browse() async {
    List<Found> found;
    try {
      found = await widget.discovery.browse();
    } catch (_) {
      found = _found ?? const [];
    }
    if (!mounted) return;
    setState(() => _found = found);
    _again = Timer(const Duration(seconds: 5), _browse);
  }

  @override
  void dispose() {
    _again?.cancel();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    final tries = candidates(_address.text);
    if (tries.isNotEmpty) widget.onPick(_address.text.trim(), tries);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final found = _found;
    final label = Theme.of(context).textTheme.titleSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.saved.isNotEmpty) ...[
          Text(t.saved, style: label),
          for (final d in widget.saved)
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text(d.name),
                subtitle: Text('${d.base}'),
                onTap: () => widget.onPick(d.name, [d.base]),
                trailing: IconButton(
                  tooltip: t.forget,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => widget.onForget(d),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        Text(t.discovered, style: label),
        for (final f in found ?? const <Found>[])
          Card(
            child: ListTile(
              leading: const Icon(Icons.router_outlined),
              title: Text(f.hostname),
              subtitle: Text([f.address, if (f.product.isNotEmpty) f.product].join(' · ')),
              onTap: () => f.port == 0 ? widget.onLocal() : widget.onPick(f.hostname, forPort(f.address, f.port)),
            ),
          ),
        // The search goes on every 5 seconds; the spinner is for the first round.
        if (found == null)
          Row(
            children: [
              const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(child: Text(t.searching)),
            ],
          )
        else if (found.isEmpty)
          Text(t.noDiscovered, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        TextField(
          controller: _address,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: t.manualAddress, helperText: t.manualAddressHint, helperMaxLines: 2),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(onPressed: _submit, child: Text(t.connect)),
      ],
    );
  }
}

final _hostname = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$', caseSensitive: false);

/// `POST /api/v1/setup`: the password twice, the device code when the device
/// asks for one, and a hostname.
class SetupForm extends StatefulWidget {
  const SetupForm({super.key, required this.deviceCode, required this.onSubmit});

  final bool deviceCode;
  final void Function(String password, String hostname, String deviceCode) onSubmit;

  @override
  State<SetupForm> createState() => _SetupFormState();
}

class _SetupFormState extends State<SetupForm> {
  final _code = TextEditingController(), _pw = TextEditingController(), _pw2 = TextEditingController();
  final _host = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    for (final c in [_code, _pw, _pw2, _host]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final t = AppLocalizations.of(context);
    final n = utf8.encode(_pw.text).length, host = _host.text.trim(), code = _code.text.trim();
    final problem = widget.deviceCode && code.isEmpty
        ? t.deviceCodeHint
        : n < 8
        ? t.passwordTooShort
        : _pw.text != _pw2.text
        ? t.passwordMismatch
        : host.isNotEmpty && !_hostname.hasMatch(host)
        ? t.hostnameInvalid
        : '';
    setState(() => _error = problem);
    if (problem.isEmpty) widget.onSubmit(_pw.text, host, code);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.setupTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(t.setupHint, style: Theme.of(context).textTheme.bodySmall),
        if (widget.deviceCode)
          TextField(
            controller: _code,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: t.deviceCode, helperText: t.deviceCodeHint),
          ),
        TextField(
          controller: _pw,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(labelText: t.adminPassword),
        ),
        TextField(
          controller: _pw2,
          obscureText: true,
          decoration: InputDecoration(labelText: t.adminPassword2),
        ),
        TextField(
          controller: _host,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: t.hostnameOptional),
        ),
        if (_error.isNotEmpty) ...[const SizedBox(height: 12), Alert(_error)],
        const SizedBox(height: 16),
        FilledButton(onPressed: _submit, child: Text(t.next)),
      ],
    );
  }
}

class SignInForm extends StatefulWidget {
  const SignInForm({super.key, required this.onSubmit});

  final void Function(String password) onSubmit;

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _pw = TextEditingController();

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  void _submit() {
    if (_pw.text.isNotEmpty) widget.onSubmit(_pw.text);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.signInTitle, style: Theme.of(context).textTheme.titleLarge),
        TextField(
          controller: _pw,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(labelText: t.authPassword),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _submit, child: Text(t.signIn)),
      ],
    );
  }
}

/// An `AvailableFact` member of `/api/v1/system/info`, when available.
Json? fact(Json? info, String key) {
  final f = info?[key];
  return f is Map && f['available'] == true ? f.cast<String, Object?>() : null;
}

/// The interfaces worth showing, with their global addresses: not the
/// loopback or the container engines' links (the web console's rule).
List<(String, List<String>, String)> interfaces(Json? network) {
  final ifs = network?['interfaces'];
  final entries = ifs is Map && ifs['entries'] is List ? ifs['entries'] as List : const [];
  const hidden = ['veth', 'podman', 'cni-', 'docker', 'dummy'];
  return [
    for (final i in entries)
      if (i is Map && i['name'] is String)
        if (!(i['name'] == 'lo' ||
            RegExp(r'^lo\d+$').hasMatch(i['name'] as String) ||
            hidden.any((p) => (i['name'] as String).startsWith(p)) ||
            ['loopback', 'veth', 'dummy'].contains(i['kind'])))
          (
            i['name'] as String,
            [
              for (final a in i['addresses'] is List ? i['addresses'] as List : const [])
                if (a is Map && a['scope'] == 'global' && a['address'] is String)
                  a['prefixLength'] is int ? '${a['address']}/${a['prefixLength']}' : '${a['address']}',
            ],
            i['link'] is Map ? '${(i['link'] as Map)['operationalState'] ?? ''}' : '',
          ),
  ];
}

class DashView extends StatelessWidget {
  const DashView({
    super.key,
    required this.dash,
    required this.onRefresh,
    required this.onNetwork,
    required this.onSettings,
    required this.onOpenConsole,
    required this.onSignOut,
  });

  final Dash dash;
  final VoidCallback onRefresh, onNetwork, onSettings, onOpenConsole, onSignOut;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final info = dash.info;
    final release = fact(info, 'release'), board = fact(info, 'board'), kernel = fact(info, 'kernel');
    final deployment = fact(info, 'deployment'), uptime = fact(info, 'uptime');
    final seconds = uptime?['seconds'] is int ? uptime!['seconds'] as int : null;
    final health = dash.health;
    final synced = dash.time?['synchronized'];
    final rows = <(String, String)>[
      (t.hostname, dash.hostname ?? '—'),
      (
        t.health,
        health == null
            ? '—'
            : health['micad'] == 'ok'
            ? t.healthOk
            : t.healthDown,
      ),
      (t.software, '${release?['version'] ?? release?['prettyName'] ?? '—'}'),
      (t.board, '${board?['model'] ?? '—'}'),
      (t.deployment, '${deployment?['version'] ?? '—'}'),
      (t.kernel, '${kernel?['release'] ?? '—'}'),
      (
        t.uptime,
        seconds == null ? '—' : t.uptimeValue(seconds ~/ 86400, seconds % 86400 ~/ 3600, seconds % 3600 ~/ 60),
      ),
      (
        t.clock,
        synced == true
            ? t.synchronized
            : synced == false
            ? t.notSynchronized
            : '—',
      ),
      if (dash.features.isNotEmpty) (t.features, dash.features.join(', ')),
      for (final (name, addresses, state) in interfaces(dash.network))
        (name, [if (addresses.isEmpty) t.noAddress else addresses.join(', '), if (state.isNotEmpty) state].join(' · ')),
    ];
    final label = Theme.of(context).textTheme.labelMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.dashTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 110, child: Text(k, style: label)),
                Expanded(child: Text(v)),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onNetwork,
                icon: const Icon(Icons.lan_outlined),
                label: Text(t.networkButton),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onSettings,
                icon: const Icon(Icons.settings_outlined),
                label: Text(t.settingsButton),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (dash.console) FilledButton(onPressed: onOpenConsole, child: Text(t.openConsole)) else Text(t.noConsole),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRefresh, child: Text(t.refresh)),
        const SizedBox(height: 8),
        TextButton(onPressed: onSignOut, child: Text(t.signOut)),
      ],
    );
  }
}
