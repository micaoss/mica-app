import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ble.dart';
import 'l10n/app_localizations.dart';
import 'protocol/client.dart';
import 'protocol/crypto.dart';

// The phone's provisioning flow, mica-network-spec chapter 5 section 3: step 1
// (find and connect) to step 9 (finish); step 10 is the console on the
// router's LAN.

class Status {
  const Status(this.wifiMode, this.connected, this.ssid, this.ip);

  final String wifiMode;
  final bool connected;
  final String? ssid, ip;
}

class Network {
  const Network(this.ssid, this.signalDbm, this.security);

  final String ssid;
  final int signalDbm;
  final String security;
}

/// Scan results merged by name, strongest first; hidden networks have no name
/// to show.
List<Network> mergeNetworks(Object? list) {
  final best = <String, Network>{};
  for (final n in list is List ? list : const []) {
    if (n is! Map || n['ssid'] is! String || (n['ssid'] as String).isEmpty || n['signalDbm'] is! num) continue;
    final ssid = n['ssid'] as String, dbm = (n['signalDbm'] as num).toInt();
    if (best[ssid] == null || dbm > best[ssid]!.signalDbm) best[ssid] = Network(ssid, dbm, '${n['security']}');
  }
  return best.values.toList()..sort((a, b) => b.signalDbm.compareTo(a.signalDbm));
}

sealed class Step {
  const Step();
}

class FindStep extends Step {
  const FindStep();
}

class BusyStep extends Step {
  const BusyStep(this.text);
  final String text;
}

class StopStep extends Step {
  const StopStep(this.text);
  final String text;
}

class DroppedStep extends Step {
  const DroppedStep(this.text);
  final String text;
}

class AuthStep extends Step {
  const AuthStep(this.mode);
  final SpakeMode mode;
}

class AdminStep extends Step {
  const AdminStep();
}

class StatusStep extends Step {
  const StatusStep(this.status);
  final Status status;
}

class NetworkStep extends Step {
  const NetworkStep(this.status, this.networks, {required this.manual});
  final Status status;
  final List<Network>? networks;
  final bool manual;
}

class PasswordStep extends Step {
  const PasswordStep(this.ssid, this.hidden, this.status);
  final String ssid;
  final bool hidden;
  final Status status;
}

class JoinedStep extends Step {
  const JoinedStep(this.ssid, this.ip);
  final String ssid, ip;
}

class DoneStep extends Step {
  const DoneStep(this.ssid, this.ip, this.hostname, this.apPsk);
  final String ssid, ip, hostname;
  final String? apPsk;
}

final _hostnamePattern = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$', caseSensitive: false);
final _pskPattern = RegExp(r'^(?:[\x20-\x7E]{8,63}|[0-9a-fA-F]{64})$');
int _bytes(String s) => utf8.encode(s).length;

class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.radio, required this.kdf, required this.onSwitchLanguage});

  final Bluetooth radio;
  final Kdf kdf;
  final VoidCallback onSwitchLanguage;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  Step _step = const FindStep();
  String _notice = '';
  ProvisioningClient? _client;
  FoundDevice? _device;
  DeviceInfo? _info;
  String _closing = '';

  AppLocalizations get t => AppLocalizations.of(context);

  @override
  void dispose() {
    _client?.disconnect();
    super.dispose();
  }

  void _go(Step s, [String notice = '']) {
    if (!mounted) return;
    setState(() {
      _step = s;
      _notice = notice;
    });
  }

  void _stop(String text) {
    _go(StopStep(text));
    _client?.disconnect();
  }

  String _reason(DeviceEvent e) => switch (e.reason) {
    'wrong_password' => t.resultWrongPassword,
    'ssid_not_found' => t.resultSsidNotFound,
    'dhcp_timeout' => t.resultDhcpTimeout,
    'unsupported_security' => t.resultUnsupportedSecurity,
    'busy' => t.resultBusy,
    'connect_failed' => t.resultConnectFailed,
    'invalid_ssid' => t.resultInvalidSsid,
    'invalid_psk' => t.resultInvalidPsk,
    'no_radio' => t.resultNoRadio,
    'not_claimed' => t.resultNotClaimed,
    'invalid_password' => t.resultInvalidPassword,
    'invalid_hostname' => t.resultInvalidHostname,
    'already_claimed' => t.alreadyClaimed,
    _ => t.failed('${e.reason}'),
  };

  // Any error an operation can end with that the step itself does not handle.
  void _broken(Object e) {
    if (e is DisconnectedError) return;
    _stop(t.commError);
  }

  void _onDrop() {
    if (!mounted || _step is DoneStep || _step is StopStep || _step is FindStep) return;
    if (_closing == 'claimed_elsewhere') return _go(StopStep(t.alreadyClaimed));
    final text = _info?.auth == Auth.none ? t.disconnectedUnclaimed : t.disconnectedClaimed;
    _go(DroppedStep(_closing == 'idle' ? '${t.closingIdle} $text' : text));
  }

  Future<void> _open(FoundDevice d) async {
    _device = d;
    _closing = '';
    _info = null;
    _go(BusyStep(t.connecting));
    final ProvisioningClient c;
    final DeviceInfo i;
    try {
      c = ProvisioningClient(await widget.radio.connect(d), kdf: widget.kdf);
      _client = c;
      c.onDisconnect = _onDrop;
      c.onClosing = (r) => _closing = r;
    } catch (_) {
      return _go(const FindStep(), t.commError);
    }
    try {
      i = await c.readInfo();
    } on ProtocolError {
      return _stop(t.commError);
    } catch (_) {
      // A second central has every read refused (org.bluez.Error.InProgress).
      c.onDisconnect = () {};
      await c.disconnect();
      return _go(const FindStep(), t.deviceBusy);
    }
    _info = i;
    if (!supportedProtocols.contains(i.protocol)) return _stop(t.protocolMismatch);
    switch (i.auth) {
      case Auth.passwordUnavailable:
        return _stop(t.passwordUnavailable);
      case Auth.password:
        return _go(const AuthStep(SpakeMode.password));
      case Auth.tempCode:
        return _go(const AuthStep(SpakeMode.tempCode));
      case Auth.none:
        try {
          await c.authenticateNone();
        } catch (e) {
          return _broken(e);
        }
        _go(const AdminStep());
    }
  }

  Future<void> _authenticate(SpakeMode mode, String secret) async {
    _go(BusyStep(t.verifying));
    try {
      await _client!.authenticateSpake(mode, secret);
    } on SessionError catch (e) {
      switch (e.reason) {
        case 'auth_failed':
          final wrong = mode == SpakeMode.password ? t.wrongPassword : t.wrongCode;
          return _go(AuthStep(mode), e.attemptsLeft == null ? wrong : wrong + t.attemptsLeft(e.attemptsLeft!));
        case 'locked':
          return _stop(t.locked(((e.retryAfter ?? 600) / 60).ceil()));
        case 'busy':
          return _go(AuthStep(mode), t.resultBusy);
        case 'password_unavailable':
          return _stop(t.passwordUnavailable);
      }
      return _broken(e);
    } catch (e) {
      return _broken(e);
    }
    await _showStatus();
  }

  Future<Status?> _getStatus() async {
    final e = await _client!.run('getStatus');
    if (e.event != 'status') {
      setState(() => _notice = _reason(e));
      return null;
    }
    return Status('${e['wifiMode']}', e['connected'] == true, e['ssid'] as String?, e['ip'] as String?);
  }

  Future<void> _showStatus([String notice = '']) async {
    try {
      final s = await _getStatus();
      if (s != null) _go(StatusStep(s), notice);
    } catch (e) {
      _broken(e);
    }
  }

  Future<void> _claim(String password, String hostname) async {
    _go(BusyStep(t.connecting));
    try {
      final e = await _client!.run('claim', {'password': password, if (hostname.isNotEmpty) 'hostname': hostname});
      if (e.event == 'claimStaged') return await _showStatus();
      if (e.reason == 'already_claimed') return _stop(t.alreadyClaimed);
      _go(const AdminStep(), _reason(e));
    } catch (e) {
      _broken(e);
    }
  }

  Future<void> _chooseNetwork([String notice = '']) async {
    _go(BusyStep(t.scanning));
    try {
      final status = await _getStatus();
      if (status == null) return;
      if (status.wifiMode == 'ap') {
        return _go(NetworkStep(status, null, manual: true), notice.isEmpty ? t.apNoScan : notice);
      }
      final e = await _client!.run('scanWifi');
      if (e.event == 'networks') return _go(NetworkStep(status, mergeNetworks(e['networks']), manual: false), notice);
      final why = switch (e.reason) {
        'ap_active' => t.apNoScan,
        'scan_failed' => t.scanFailed,
        _ => _reason(e),
      };
      _go(NetworkStep(status, null, manual: true), notice.isEmpty ? why : notice);
    } catch (e) {
      _broken(e);
    }
  }

  Future<void> _join(String ssid, String psk, bool hidden, Status status) async {
    _go(BusyStep(t.progress(ssid)));
    try {
      final e = await _client!.run('setWifi', {'ssid': ssid, 'psk': psk, 'hidden': hidden});
      if (e.event == 'connected') return _go(JoinedStep(ssid, '${e['ip']}'));
      switch (e.reason) {
        case 'ssid_not_found' || 'unsupported_security' || 'invalid_ssid' || 'no_radio':
          return await _chooseNetwork(_reason(e));
        case 'not_claimed':
          return _go(const AdminStep(), _reason(e));
        case 'already_claimed':
          return _stop(t.alreadyClaimed);
        default: // wrong_password, dhcp_timeout, busy, connect_failed, invalid_psk
          return _go(PasswordStep(ssid, hidden, status), _reason(e));
      }
    } catch (e) {
      _broken(e);
    }
  }

  Future<void> _finish(String ssid, String ip) async {
    _go(BusyStep(t.finishing));
    try {
      final e = await _client!.run('finish');
      if (e.event == 'finished') {
        // Set before the device disconnects, which follows `finished` at once.
        _step = DoneStep(ssid, ip, '${e['hostname']}', e['apPsk'] is String ? e['apPsk'] as String : null);
        _info = _info?.copyWith(claimed: e['claimed'] == true, hostname: '${e['hostname']}');
        return _go(_step);
      }
      if (e.reason == 'already_claimed') return _stop(t.alreadyClaimed);
      if (e.reason == 'not_claimed') return _go(const AdminStep(), _reason(e));
      _go(JoinedStep(ssid, ip), _reason(e));
    } catch (e) {
      _broken(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.title),
        actions: [TextButton(onPressed: widget.onSwitchLanguage, child: Text(t.switchTo))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.lead, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (info != null && _step is! FindStep) ...[DeviceCard(info: info), const SizedBox(height: 12)],
            if (_notice.isNotEmpty) ...[Alert(_notice), const SizedBox(height: 12)],
            _stepView(),
          ],
        ),
      ),
    );
  }

  Widget _stepView() {
    return switch (_step) {
      FindStep() => FindView(radio: widget.radio, onPick: _open),
      BusyStep(:final text) => Row(
        children: [
          const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
      StopStep(:final text) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Alert(text),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => _go(const FindStep()), child: Text(t.restart)),
        ],
      ),
      DroppedStep(:final text) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Alert(text),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => _open(_device!), child: Text(t.reconnect)),
        ],
      ),
      AuthStep(:final mode) => AuthForm(key: ValueKey(mode), mode: mode, onSubmit: (s) => _authenticate(mode, s)),
      AdminStep() => AdminForm(hostname: _info?.hostname ?? '', onSubmit: _claim),
      StatusStep(:final status) => StatusView(status: status, onConfigure: _chooseNetwork),
      final NetworkStep s => NetworkForm(
        key: ObjectKey(s),
        step: s,
        onRescan: _chooseNetwork,
        onPick: (ssid, hidden) => _go(PasswordStep(ssid, hidden, s.status)),
      ),
      final PasswordStep s => PasswordForm(
        key: ObjectKey(s),
        step: s,
        onBack: _chooseNetwork,
        onSubmit: (psk) => _join(s.ssid, psk, s.hidden, s.status),
      ),
      JoinedStep(:final ssid, :final ip) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.success(ssid, ip), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => _finish(ssid, ip), child: Text(t.finish)),
        ],
      ),
      final DoneStep s => DoneView(step: s),
    };
  }
}

class Alert extends StatelessWidget {
  const Alert(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: c.onErrorContainer)),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows(this.rows);

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelMedium;
    return Column(
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(width: 110, child: Text(k, style: label)),
                Expanded(child: Text(v)),
              ],
            ),
          ),
      ],
    );
  }
}

class DeviceCard extends StatelessWidget {
  const DeviceCard({super.key, required this.info});

  final DeviceInfo info;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _Rows([
          (t.hostname, info.hostname),
          (t.model, info.model),
          (t.device, info.claimed ? t.claimed : t.unclaimed),
        ]),
      ),
    );
  }
}

/// Step 1: the devices that advertise the provisioning service.
class FindView extends StatefulWidget {
  const FindView({super.key, required this.radio, required this.onPick});

  final Bluetooth radio;
  final void Function(FoundDevice) onPick;

  @override
  State<FindView> createState() => _FindViewState();
}

class _FindViewState extends State<FindView> {
  RadioState _state = RadioState.unknown;
  List<FoundDevice> _found = const [];
  StreamSubscription<RadioState>? _stateSub;
  StreamSubscription<List<FoundDevice>>? _scanSub;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.radio.state.listen((s) {
      setState(() => _state = s);
      if (s == RadioState.on) {
        _scanSub ??= widget.radio.scan().listen((f) => setState(() => _found = f), onError: (_) {});
      } else {
        _scanSub?.cancel();
        _scanSub = null;
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return switch (_state) {
      RadioState.unsupported => Alert(t.radioUnsupported),
      RadioState.unauthorized => Alert(t.radioUnauthorized),
      RadioState.off => Alert(t.radioOff),
      RadioState.unknown => const SizedBox.shrink(),
      RadioState.on => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.findHint),
          const SizedBox(height: 12),
          for (final d in _found)
            Card(
              child: ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(d.name.isEmpty ? d.id : d.name),
                trailing: Text('${d.rssi} dBm'),
                onTap: () => widget.onPick(d),
              ),
            ),
          if (_found.isEmpty) ...[
            Row(
              children: [
                const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text(t.findingDevices),
              ],
            ),
            const SizedBox(height: 12),
            Text(t.noDeviceHint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    };
  }
}

/// Step 3 on a claimed device: the administrator password or the temp-code.
class AuthForm extends StatefulWidget {
  const AuthForm({super.key, required this.mode, required this.onSubmit});

  final SpakeMode mode;
  final void Function(String) onSubmit;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _secret = TextEditingController();

  @override
  void dispose() {
    _secret.dispose();
    super.dispose();
  }

  void _submit() {
    if (_secret.text.isNotEmpty) widget.onSubmit(_secret.text);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final password = widget.mode == SpakeMode.password;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _secret,
          obscureText: password,
          keyboardType: password ? TextInputType.visiblePassword : TextInputType.number,
          autofillHints: password ? const [AutofillHints.password] : const [AutofillHints.oneTimeCode],
          decoration: InputDecoration(
            labelText: password ? t.authPassword : t.authTempCode,
            helperText: password ? null : t.authTempCodeHint,
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _submit, child: Text(t.verify)),
      ],
    );
  }
}

/// Step 4: only on an unclaimed device; staged until `finish`.
class AdminForm extends StatefulWidget {
  const AdminForm({super.key, required this.hostname, required this.onSubmit});

  final String hostname;
  final void Function(String password, String hostname) onSubmit;

  @override
  State<AdminForm> createState() => _AdminFormState();
}

class _AdminFormState extends State<AdminForm> {
  final _pw = TextEditingController(), _pw2 = TextEditingController(), _host = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    _host.dispose();
    super.dispose();
  }

  void _submit() {
    final t = AppLocalizations.of(context);
    final n = _bytes(_pw.text), host = _host.text.trim();
    final problem = n < 8
        ? t.passwordTooShort
        : n > 1024
        ? t.passwordTooLong
        : _pw.text != _pw2.text
        ? t.passwordMismatch
        : host.isNotEmpty && !_hostnamePattern.hasMatch(host)
        ? t.hostnameInvalid
        : '';
    setState(() => _error = problem);
    if (problem.isEmpty) widget.onSubmit(_pw.text, host);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.adminTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(t.adminHint, style: Theme.of(context).textTheme.bodySmall),
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
          decoration: InputDecoration(labelText: t.hostnameOptional, hintText: widget.hostname),
        ),
        if (_error.isNotEmpty) ...[const SizedBox(height: 12), Alert(_error)],
        const SizedBox(height: 16),
        FilledButton(onPressed: _submit, child: Text(t.next)),
      ],
    );
  }
}

/// Step 5.
class StatusView extends StatelessWidget {
  const StatusView({super.key, required this.status, required this.onConfigure});

  final Status status;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final mode = switch (status.wifiMode) {
      'client' => t.modeClient,
      'ap' => t.modeAp,
      _ => t.modeOff,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.statusTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _Rows([
          (t.wifiMode, mode),
          (t.connection, status.connected && status.ssid != null ? t.connectedTo(status.ssid!) : t.notConnected),
          (t.ip, status.ip ?? '—'),
        ]),
        const SizedBox(height: 16),
        FilledButton(onPressed: onConfigure, child: Text(t.configureWifi)),
      ],
    );
  }
}

/// Step 6: the scan list, or the name typed in (always in access-point mode).
class NetworkForm extends StatefulWidget {
  const NetworkForm({super.key, required this.step, required this.onRescan, required this.onPick});

  final NetworkStep step;
  final VoidCallback onRescan;
  final void Function(String ssid, bool hidden) onPick;

  @override
  State<NetworkForm> createState() => _NetworkFormState();
}

class _NetworkFormState extends State<NetworkForm> {
  late bool _manual = widget.step.manual;
  final _ssid = TextEditingController();
  bool _hidden = false;
  String _error = '';

  @override
  void dispose() {
    _ssid.dispose();
    super.dispose();
  }

  void _submit() {
    final n = _bytes(_ssid.text);
    if (n < 1 || n > 32) return setState(() => _error = AppLocalizations.of(context).ssidInvalid);
    widget.onPick(_ssid.text, _hidden);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final networks = widget.step.networks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.networkTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (networks != null) ...[
          if (networks.isEmpty) Text(t.noNetworks),
          for (final n in networks)
            Card(
              child: ListTile(
                leading: Icon(n.security == 'open' ? Icons.wifi : Icons.wifi_lock),
                title: Text(n.ssid),
                subtitle: Text('${n.security == 'open' ? t.open : n.security} · ${n.signalDbm} dBm'),
                onTap: () => widget.onPick(n.ssid, false),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: widget.onRescan, child: Text(t.rescan)),
              if (!_manual) OutlinedButton(onPressed: () => setState(() => _manual = true), child: Text(t.manual)),
            ],
          ),
        ],
        if (_manual) ...[
          TextField(
            controller: _ssid,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: t.ssid),
            onSubmitted: (_) => _submit(),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _hidden,
            onChanged: (v) => setState(() => _hidden = v ?? false),
            title: Text(t.hidden),
          ),
          if (_error.isNotEmpty) ...[Alert(_error), const SizedBox(height: 12)],
          FilledButton(onPressed: _submit, child: Text(t.next)),
        ],
      ],
    );
  }
}

/// Step 7.
class PasswordForm extends StatefulWidget {
  const PasswordForm({super.key, required this.step, required this.onBack, required this.onSubmit});

  final PasswordStep step;
  final VoidCallback onBack;
  final void Function(String psk) onSubmit;

  @override
  State<PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<PasswordForm> {
  final _psk = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _psk.dispose();
    super.dispose();
  }

  void _submit() {
    if (_psk.text.isNotEmpty && !_pskPattern.hasMatch(_psk.text)) {
      return setState(() => _error = AppLocalizations.of(context).pskInvalid);
    }
    widget.onSubmit(_psk.text);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.passwordTitle(widget.step.ssid), style: Theme.of(context).textTheme.titleLarge),
        TextField(
          controller: _psk,
          obscureText: true,
          autocorrect: false,
          decoration: InputDecoration(labelText: t.wifiPassword),
          onSubmitted: (_) => _submit(),
        ),
        if (widget.step.status.wifiMode == 'ap') ...[
          const SizedBox(height: 12),
          Text(t.apWarning(widget.step.ssid), style: TextStyle(color: Theme.of(context).colorScheme.tertiary)),
        ],
        if (_error.isNotEmpty) ...[const SizedBox(height: 12), Alert(_error)],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: widget.onBack, child: Text(t.back)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: _submit, child: Text(t.join)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Step 9 done; the console (step 10) opens in the browser.
class DoneView extends StatelessWidget {
  const DoneView({super.key, required this.step});

  final DoneStep step;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final apPsk = step.apPsk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.done, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SelectableText(t.doneText(step.ssid, step.ip, step.hostname)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => launchUrl(Uri.parse('http://${step.ip}'), mode: LaunchMode.externalApplication),
          child: Text(t.openConsole),
        ),
        if (apPsk != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.apPsk),
                  const SizedBox(height: 4),
                  SelectableText(apPsk, style: const TextStyle(fontFamily: 'monospace', fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(t.apPskOnce, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
