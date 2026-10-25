import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'console/client.dart';
import 'l10n/app_localizations.dart';
import 'setup_page.dart';

// The configuration a device with no console needs: its Wi-Fi and wired
// ports, its hostname, the administrator password and SSH. Every write is
// persisted by the device and applied as a task, which these screens wait for.

/// The result of a write, in the words the screens show.
mixin Applying<T extends StatefulWidget> on State<T> {
  String busy = '', error = '';

  AppLocalizations get t => AppLocalizations.of(context);

  /// The session ended; the page asks to sign in again.
  VoidCallback get onExpired;

  /// Runs [write], waits for its task and reports. True when it succeeded.
  Future<bool> run(String text, Future<String?> Function() write, ConsoleClient client) async {
    setState(() {
      busy = text;
      error = '';
    });
    String problem = '';
    try {
      final id = await write();
      final failed = id == null ? null : await client.settle(id);
      if (failed != null) problem = t.applyFailed(failed);
    } on ApiFailure catch (e) {
      if (e.status == 401) {
        onExpired();
        return false;
      }
      problem = e.code == 'wrong_password' ? t.wrongCurrent : t.requestFailed(e.code);
    } on TaskPending {
      problem = t.applyPending;
    } catch (_) {
      problem = t.maybeMoved;
    }
    if (!mounted) return false;
    setState(() {
      busy = '';
      error = problem;
    });
    if (problem.isEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.applied)));
    return problem.isEmpty;
  }

  Widget progress([String? text]) => Row(
    children: [
      const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      const SizedBox(width: 12),
      Expanded(child: Text(text ?? busy)),
    ],
  );
}

/// An Ethernet port as `/api/v1/network/status` observes it.
class Wire {
  const Wire(this.name, this.carrier, this.address);

  final String name;
  final bool carrier;
  final String? address;
}

/// The wired ports among the observed interfaces.
List<Wire> wires(Json? network) {
  final ifs = network?['interfaces'];
  final entries = ifs is Map && ifs['entries'] is List ? ifs['entries'] as List : const [];
  return [
    for (final i in entries)
      if (i is Map && i['name'] is String && (i['type'] == 'ether' || RegExp(r'^(eth|en)').hasMatch('${i['name']}')))
        if (!RegExp(r'^(veth|podman|cni-|docker|dummy)').hasMatch(i['name'] as String))
          Wire(
            i['name'] as String,
            i['link'] is Map &&
                ((i['link'] as Map)['carrier'] == true || (i['link'] as Map)['carrierState'] == 'carrier'),
            [
              for (final a in i['addresses'] is List ? i['addresses'] as List : const [])
                if (a is Map && a['scope'] == 'global' && a['family'] == 'ipv4' && a['address'] is String)
                  a['prefixLength'] is int ? '${a['address']}/${a['prefixLength']}' : '${a['address']}',
            ].firstOrNull,
          ),
  ];
}

/// `/api/v1/wifi/client/scan`'s networks in the shape the Bluetooth screens
/// take: a security name from the scan's flags.
List<Network> scanned(Json scan) => mergeNetworks([
  for (final n in scan['networks'] is List ? scan['networks'] as List : const [])
    if (n is Map)
      {
        'ssid': n['ssid'],
        'signalDbm': n['signalDbm'] ?? -100,
        'security': '${n['flags']}'.contains('SAE')
            ? 'sae'
            : RegExp('WPA|RSN|PSK').hasMatch('${n['flags']}')
            ? 'wpa2-psk'
            : 'open',
      },
]);

/// [entry] for [name] with the addressing of [form]: the rest of the stored
/// entry (its kind, routes, internet) kept.
Json wiredEntry(Json? stored, Wired form) {
  final e = {...?stored};
  e['kind'] = e['kind'] ?? 'physical';
  e['dhcp'] = form.dhcp;
  if (form.dhcp) {
    e.remove('static');
  } else {
    e.remove('dns');
    e['static'] = {
      'address': form.address,
      if (form.gateway.isNotEmpty) 'gateway': form.gateway,
      'dns': splitList(form.dns),
    };
  }
  return e;
}

sealed class _View {
  const _View();
}

class _Overview extends _View {
  const _Overview();
}

class _Pick extends _View {
  const _Pick(this.step);
  final NetworkStep step;
}

class _Psk extends _View {
  const _Psk(this.step);
  final PasswordStep step;
}

class _Wired extends _View {
  const _Wired(this.step);
  final WiredStep step;
}

/// Wi-Fi (on a device with the feature) and the wired ports.
class NetworkView extends StatefulWidget {
  const NetworkView({
    super.key,
    required this.client,
    required this.wifi,
    required this.onExpired,
    required this.onBack,
  });

  final ConsoleClient client;

  /// The device has Wi-Fi (`features` of `/api/v1/meta`).
  final bool wifi;
  final VoidCallback onExpired, onBack;

  @override
  State<NetworkView> createState() => _NetworkViewState();
}

class _NetworkViewState extends State<NetworkView> with Applying {
  _View _view = const _Overview();
  bool _loaded = false;
  Json? _role, _status, _configured;
  List<Json> _networks = const [];

  @override
  VoidCallback get onExpired => widget.onExpired;

  ConsoleClient get c => widget.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loaded) setState(() => busy = t.connecting);
    try {
      final r = await Future.wait<Object?>([
        widget.wifi ? c.wifiRole() : Future.value(null),
        widget.wifi ? c.wifiNetworks() : Future.value(const <Json>[]),
        c.networkStatus(),
        c.configuredNetwork(),
      ]);
      if (!mounted) return;
      setState(() {
        _role = r[0] as Json?;
        _networks = r[1] as List<Json>;
        _status = r[2] as Json?;
        _configured = r[3] as Json?;
        _loaded = true;
        busy = '';
        _view = const _Overview();
      });
    } on ApiFailure catch (e) {
      if (e.status == 401) return widget.onExpired();
      if (mounted) {
        setState(() {
          busy = '';
          error = t.requestFailed(e.code);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = '';
          error = t.maybeMoved;
        });
      }
    }
  }

  /// The radio's role as the Bluetooth screens name it.
  String get _mode => _role?['enabled'] != true ? 'off' : '${_role?['mode']}';

  Status get _asStatus => Status(_mode, false, null, null, [
    for (final w in wires(_status)) Port(w.name, 'ethernet', w.carrier, w.address),
  ]);

  Future<void> _chooseNetwork() async {
    if (_mode != 'client') return setState(() => _view = _Pick(NetworkStep(_asStatus, null, manual: true)));
    setState(() => busy = t.scanning);
    try {
      final scan = await c.scanWifi();
      final list = scan['available'] == true ? scanned(scan) : null;
      if (!mounted) return;
      setState(() {
        busy = '';
        error = list == null ? t.scanFailed : '';
        _view = _Pick(NetworkStep(_asStatus, list, manual: list == null || list.isEmpty));
      });
    } on ApiFailure catch (e) {
      if (e.status == 401) return widget.onExpired();
      if (mounted) {
        setState(() {
          busy = '';
          error = t.scanFailed;
          _view = _Pick(NetworkStep(_asStatus, null, manual: true));
        });
      }
    }
  }

  /// Saves the network, then gives the radio to the station when it is not.
  Future<void> _join(String ssid, String psk, bool hidden) async {
    final ok = await run(t.progress(ssid), () async {
      await c.addWifiNetwork(ssid, psk, hidden: hidden);
      return _mode == 'client' ? null : await c.setWifiRole(enabled: true, mode: 'client');
    }, c);
    if (ok) await _load();
  }

  Future<void> _remove(String ssid) async {
    final ok = await run(t.removing(ssid), () async {
      await c.removeWifiNetwork(ssid);
      return null;
    }, c);
    if (ok) await _load();
  }

  Future<void> _wired(Wired form) async {
    final stored = _configured?[form.port];
    final ok = await run(
      t.applying(form.port),
      () => c.setInterface(form.port, wiredEntry(stored is Map ? stored.cast<String, Object?>() : null, form)),
      c,
    );
    if (ok) await _load();
  }

  String _addressing(String port) {
    final e = _configured?[port];
    if (e is! Map) return t.notConfigured;
    if (e['dhcp'] == true) return t.dhcp;
    final s = e['static'];
    return s is Map ? '${t.staticAddress} ${s['address']}' : t.noAddress;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded && error.isEmpty) return progress(t.connecting);
    if (busy.isNotEmpty) return progress();
    final alert = error.isEmpty ? null : Alert(error);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (alert != null) ...[alert, const SizedBox(height: 12)],
        switch (_view) {
          _Overview() => _overview(),
          _Pick(:final step) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_mode != 'client') ...[Text(t.apNoScan), const SizedBox(height: 8)],
              NetworkForm(
                key: ObjectKey(step),
                step: step,
                onRescan: _chooseNetwork,
                onRescanAp: _chooseNetwork,
                onPick: (ssid, hidden) => setState(() => _view = _Psk(PasswordStep(ssid, hidden, step.status))),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => setState(() => _view = const _Overview()), child: Text(t.back)),
            ],
          ),
          _Psk(:final step) => PasswordForm(
            key: ObjectKey(step),
            step: step,
            onBack: () => setState(() => _view = const _Overview()),
            onSubmit: (psk) => _join(step.ssid, psk, step.hidden),
          ),
          _Wired(:final step) => WiredForm(
            key: ObjectKey(step),
            step: step,
            onBack: () => setState(() => _view = const _Overview()),
            onSubmit: _wired,
          ),
        },
      ],
    );
  }

  Widget _overview() {
    final title = Theme.of(context).textTheme.titleMedium;
    final ports = wires(_status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.wifi) ...[
          Text(t.wifi, style: title),
          const SizedBox(height: 4),
          Text(
            '${t.wifiMode}: ${switch (_mode) {
              'client' => t.modeClient,
              'ap' => t.modeAp,
              _ => t.modeOff,
            }}',
          ),
          const SizedBox(height: 4),
          if (_networks.isEmpty) Text(t.noKnownNetworks, style: Theme.of(context).textTheme.bodySmall),
          for (final n in _networks)
            Card(
              child: ListTile(
                leading: const Icon(Icons.wifi),
                title: Text('${n['ssid']}'),
                trailing: IconButton(
                  tooltip: t.remove,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _remove('${n['ssid']}'),
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _chooseNetwork, child: Text(t.configureWifi)),
          const SizedBox(height: 20),
        ],
        Text(t.wiredTitle, style: title),
        const SizedBox(height: 4),
        if (ports.isEmpty) Text(t.noWiredPorts, style: Theme.of(context).textTheme.bodySmall),
        for (final w in ports)
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_ethernet),
              title: Text(w.name),
              subtitle: Text(
                [w.carrier ? t.cableIn : t.noCable, w.address ?? t.noAddress, _addressing(w.name)].join(' · '),
              ),
              onTap: () => setState(() => _view = _Wired(WiredStep(_asStatus, _form(w.name)))),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: widget.onBack, child: Text(t.back)),
      ],
    );
  }

  /// The wired form filled with what the port declares.
  Wired _form(String port) {
    final e = _configured?[port];
    final s = e is Map && e['static'] is Map ? e['static'] as Map : null;
    return Wired(
      port,
      dhcp: s == null,
      address: '${s?['address'] ?? ''}',
      gateway: '${s?['gateway'] ?? ''}',
      dns: s?['dns'] is List ? (s!['dns'] as List).join(' ') : '',
    );
  }
}

/// Hostname, the administrator password and, on a device with the feature, SSH.
class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.client,
    required this.hostname,
    required this.ssh,
    required this.onExpired,
    required this.onBack,
  });

  final ConsoleClient client;
  final String hostname;
  final bool ssh;
  final VoidCallback onExpired, onBack;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

final _hostnamePattern = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$', caseSensitive: false);

class _SettingsViewState extends State<SettingsView> with Applying {
  late final _host = TextEditingController(text: widget.hostname);
  final _current = TextEditingController(), _next = TextEditingController(), _next2 = TextEditingController();
  final _key = TextEditingController();
  bool? _sshOn;
  List<Json> _keys = const [];

  @override
  VoidCallback get onExpired => widget.onExpired;

  ConsoleClient get c => widget.client;

  @override
  void initState() {
    super.initState();
    if (widget.ssh) _loadSsh();
  }

  @override
  void dispose() {
    for (final x in [_host, _current, _next, _next2, _key]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSsh() async {
    try {
      final on = await c.setting('access.ssh.enabled');
      final keys = await c.sshKeys();
      if (mounted) {
        setState(() {
          _sshOn = on == true;
          _keys = keys;
        });
      }
    } on ApiFailure catch (e) {
      if (e.status == 401) widget.onExpired();
    } catch (_) {}
  }

  Future<void> _saveHostname() async {
    final host = _host.text.trim();
    if (!_hostnamePattern.hasMatch(host)) return setState(() => error = t.hostnameInvalid);
    await run(t.saving, () => c.setHostname(host), c);
  }

  Future<void> _changePassword() async {
    final n = utf8.encode(_next.text).length;
    final problem = _current.text.isEmpty
        ? t.wrongCurrent
        : n < 8
        ? t.passwordTooShort
        : _next.text != _next2.text
        ? t.passwordMismatch
        : '';
    if (problem.isNotEmpty) return setState(() => error = problem);
    final ok = await run(t.saving, () async {
      await c.changePassword(_current.text, _next.text);
      return null;
    }, c);
    if (ok) {
      for (final x in [_current, _next, _next2]) {
        x.clear();
      }
    }
  }

  Future<void> _setSsh(bool on) async {
    if (await run(t.saving, () => c.setSetting('access.ssh.enabled', on), c)) await _loadSsh();
  }

  Future<void> _addKey() async {
    final line = _key.text.trim();
    if (line.isEmpty) return;
    final ok = await run(t.saving, () async {
      await c.addSshKey(line);
      return null;
    }, c);
    if (ok) {
      _key.clear();
      await _loadSsh();
    }
  }

  Future<void> _removeKey(String fingerprint) async {
    final ok = await run(t.saving, () async {
      await c.removeSshKey(fingerprint);
      return null;
    }, c);
    if (ok) await _loadSsh();
  }

  @override
  Widget build(BuildContext context) {
    if (busy.isNotEmpty) return progress();
    final title = Theme.of(context).textTheme.titleMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error.isNotEmpty) ...[Alert(error), const SizedBox(height: 12)],
        Text(t.hostname, style: title),
        TextField(
          controller: _host,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: t.hostname),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(onPressed: _saveHostname, child: Text(t.save)),
        const SizedBox(height: 20),
        Text(t.changePassword, style: title),
        TextField(
          controller: _current,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(labelText: t.currentPassword),
        ),
        TextField(
          controller: _next,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(labelText: t.adminPassword),
        ),
        TextField(
          controller: _next2,
          obscureText: true,
          decoration: InputDecoration(labelText: t.adminPassword2),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(onPressed: _changePassword, child: Text(t.changePassword)),
        if (widget.ssh) ...[
          const SizedBox(height: 20),
          Text('SSH', style: title),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.sshServer),
            value: _sshOn ?? false,
            onChanged: _sshOn == null ? null : _setSsh,
          ),
          Text(t.sshKeys, style: Theme.of(context).textTheme.labelLarge),
          if (_keys.isEmpty) Text(t.noSshKeys, style: Theme.of(context).textTheme.bodySmall),
          for (final k in _keys)
            Card(
              child: ListTile(
                title: Text('${k['comment'] ?? k['fingerprint'] ?? ''}'),
                subtitle: Text(
                  '${k['fingerprint'] ?? ''}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                trailing: IconButton(
                  tooltip: t.remove,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeKey('${k['fingerprint']}'),
                ),
              ),
            ),
          TextField(
            controller: _key,
            autocorrect: false,
            enableSuggestions: false,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(labelText: t.addSshKey, helperText: t.sshKeyHint, helperMaxLines: 2),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: _addKey, child: Text(t.addSshKey)),
        ],
        const SizedBox(height: 16),
        OutlinedButton(onPressed: widget.onBack, child: Text(t.back)),
      ],
    );
  }
}
