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

class Port {
  const Port(this.name, this.kind, this.carrier, this.address);

  final String name;

  /// `ethernet` or `wifi`.
  final String kind;
  final bool carrier;

  /// IPv4 with its prefix, or null.
  final String? address;
}

class Status {
  const Status(this.wifiMode, this.connected, this.ssid, this.ip, this.interfaces);

  /// A `status` event: getStatus's answer, or the one that follows `ready`.
  factory Status.of(DeviceEvent e) => Status(
    '${e['wifiMode']}',
    e['connected'] == true,
    e['ssid'] is String ? e['ssid'] as String : null,
    e['ip'] is String ? e['ip'] as String : null,
    [
      for (final p in e['interfaces'] is List ? e['interfaces'] as List : const [])
        if (p is Map && p['name'] is String)
          Port(
            p['name'] as String,
            '${p['kind']}',
            p['carrier'] == true,
            p['address'] is String ? p['address'] as String : null,
          ),
    ],
  );

  final String wifiMode;
  final bool connected;
  final String? ssid, ip;
  final List<Port> interfaces;

  List<Port> get ethernet => interfaces.where((p) => p.kind == 'ethernet').toList();
}

final _ipv4Pattern = RegExp(r'^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$');

bool isIpv4(String s) => _ipv4Pattern.hasMatch(s);

/// An IPv4 or IPv6 address.
bool isIp(String s) => isIpv4(s) || (s.contains(':') && Uri.tryParse('http://[$s]/')?.host.isNotEmpty == true);

/// An IPv4 address with its prefix, as `static.address` takes it.
bool isCidr(String s) {
  final parts = s.split('/');
  final prefix = parts.length == 2 && RegExp(r'^\d{1,2}$').hasMatch(parts[1]) ? int.parse(parts[1]) : -1;
  return prefix >= 0 && prefix <= 32 && isIpv4(parts[0]);
}

/// DNS servers typed with spaces or commas between them.
List<String> splitList(String s) => s.split(RegExp(r'[\s,]+')).where((x) => x.isNotEmpty).toList();

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

/// What the wired form holds, kept when an attempt fails.
class Wired {
  const Wired(this.port, {this.dhcp = true, this.address = '', this.gateway = '', this.dns = ''});
  final String port;
  final bool dhcp;
  final String address, gateway, dns;
}

class WiredStep extends Step {
  const WiredStep(this.status, [this.form]);
  final Status status;
  final Wired? form;
}

/// Wi-Fi or the wired port is up; [ip] is a 0.0.3 device's console address.
class JoinedStep extends Step {
  const JoinedStep(this.text, [this.ip]);
  final String text;
  final String? ip;
}

class DoneStep extends Step {
  const DoneStep({required this.reached, required this.urls, required this.claimed, required this.apOn, this.apPsk});

  /// `{kind, address}` of the port the session brought up.
  final (String, String?)? reached;
  final List<String> urls;
  final bool claimed, apOn;

  /// A 0.0.3 device's generated access-point key, shown once.
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
  Status? _status;
  String _closing = '';

  /// A core 0.0.3 device: it claims over BLE (`claim`) and has no `setNetwork`.
  bool get _legacy => _info?.ops.contains('claim') ?? false;

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
    'bad_request' => t.resultBadRequest,
    'unknown_op' => t.resultUnknownOp,
    'unknown_interface' => t.resultUnknownInterface,
    'invalid_address' => t.resultInvalidAddress,
    'invalid_gateway' => t.resultInvalidGateway,
    'invalid_dns' => t.resultInvalidDns,
    'validation_failed' => t.resultValidationFailed,
    'name_invalid' => t.resultNameInvalid,
    'gateway_out_of_subnet' => t.resultGatewayOutOfSubnet,
    'address_overlap' => t.resultAddressOverlap,
    'metric_duplicate' => t.resultMetricDuplicate,
    'vlan_duplicate' => t.resultVlanDuplicate,
    'vlan_parent_invalid' => t.resultVlanParentInvalid,
    'bridge_port_invalid' => t.resultBridgePortInvalid,
    'bridge_port_addressed' => t.resultBridgePortAddressed,
    'bridge_port_taken' => t.resultBridgePortTaken,
    'no_carrier' => t.resultNoCarrier,
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
    _status = null;
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
        final DeviceEvent? status;
        try {
          status = await c.authenticateNone();
        } catch (e) {
          return _broken(e);
        }
        if (status != null) _status = Status.of(status);
        if (_legacy) return _go(const AdminStep());
        await _showStatus(status);
    }
  }

  Future<void> _authenticate(SpakeMode mode, String secret) async {
    _go(BusyStep(t.verifying));
    final DeviceEvent? status;
    try {
      status = await _client!.authenticateSpake(mode, secret);
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
    await _showStatus(status);
  }

  Future<Status?> _getStatus() async {
    final e = await _client!.run('getStatus');
    if (e.event != 'status') {
      setState(() => _notice = _reason(e));
      return null;
    }
    return _status = Status.of(e);
  }

  /// Step 5, from the status that came with `ready` when there is one.
  Future<void> _showStatus([DeviceEvent? given]) async {
    try {
      final s = given != null ? Status.of(given) : await _getStatus();
      if (s != null) _go(StatusStep(s));
    } catch (e) {
      _broken(e);
    }
  }

  Future<void> _claim(String password, String hostname) async {
    _go(BusyStep(t.connecting));
    try {
      final e = await _client!.run('claim', {'password': password, if (hostname.isNotEmpty) 'hostname': hostname});
      if (e.event == 'claimStaged') {
        final s = _status;
        return s != null ? _go(StatusStep(s)) : await _showStatus();
      }
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
      if (e.event == 'connected') return _go(JoinedStep(t.success(ssid, '${e['ip']}'), '${e['ip']}'));
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

  Future<void> _applyWired(Status status, Wired form) async {
    _go(BusyStep(t.applying(form.port)));
    final params = {
      'interface': form.port,
      if (form.dhcp) 'dhcp': true,
      if (!form.dhcp)
        'static': {
          'address': form.address,
          if (form.gateway.isNotEmpty) 'gateway': form.gateway,
          if (form.dns.trim().isNotEmpty) 'dns': splitList(form.dns),
        },
    };
    try {
      final e = await _client!.run('setNetwork', params);
      if (e.event == 'up') return _go(JoinedStep(t.wiredUp('${e['interface']}', '${e['address'] ?? '—'}')));
      if (e.reason == 'already_claimed') return _stop(t.alreadyClaimed);
      _go(WiredStep(status, form), e.reason == 'dhcp_timeout' ? t.resultWiredDhcpTimeout : _reason(e));
    } catch (e) {
      _broken(e);
    }
  }

  Future<void> _finish(JoinedStep joined) async {
    _go(BusyStep(t.finishing));
    try {
      final e = await _client!.run('finish');
      if (e.event == 'finished') {
        final host = '${e['hostname']}';
        final r = e['interface'];
        final urls = e['consoleUrls'] is List
            ? (e['consoleUrls'] as List)
                  .whereType<String>()
                  .where((u) => u.startsWith('http://') || u.startsWith('https://'))
                  .toList()
            : [if (joined.ip != null) 'http://${joined.ip}', 'http://$host.local'];
        // Set before the device disconnects, which follows `finished` at once.
        _step = DoneStep(
          reached: r is Map && r['name'] is String
              ? ('${r['kind']}', r['address'] is String ? r['address'] as String : null)
              : null,
          urls: urls,
          claimed: e['claimed'] == true,
          apOn: e['ap'] == 'on',
          apPsk: e['apPsk'] is String ? e['apPsk'] as String : null,
        );
        _info = _info?.copyWith(claimed: e['claimed'] == true, hostname: host);
        return _go(_step);
      }
      if (e.reason == 'already_claimed') return _stop(t.alreadyClaimed);
      if (e.reason == 'not_claimed') return _go(const AdminStep(), _reason(e));
      _go(joined, _reason(e));
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.lead, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              if (info != null && _step is! FindStep) ...[DeviceCard(info: info), const SizedBox(height: 12)],
              if (_notice.isNotEmpty) ...[Alert(_notice), const SizedBox(height: 12)],
              _stepView(),
            ],
          ),
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
      StatusStep(:final status) => StatusView(
        status: status,
        wired: (_info?.ops.contains('setNetwork') ?? false) && status.ethernet.isNotEmpty,
        onConfigure: _chooseNetwork,
        onWired: () => _go(WiredStep(status)),
      ),
      final WiredStep s => WiredForm(
        key: ObjectKey(s),
        step: s,
        onBack: () => _go(StatusStep(s.status)),
        onSubmit: (form) => _applyWired(s.status, form),
      ),
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
      final JoinedStep s => JoinedView(step: s, onFinish: () => _finish(s)),
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
  const StatusView({
    super.key,
    required this.status,
    required this.wired,
    required this.onConfigure,
    required this.onWired,
  });

  final Status status;

  /// The device offers `setNetwork` and has an Ethernet port.
  final bool wired;
  final VoidCallback onConfigure, onWired;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final mode = switch (status.wifiMode) {
      'client' => t.modeClient,
      'ap' => t.modeAp,
      _ => t.modeOff,
    };
    final wifi = status.interfaces.isEmpty || status.interfaces.any((p) => p.kind == 'wifi');
    String port(Port p) => [
      p.kind == 'ethernet' ? t.ethernet : t.wifi,
      p.kind == 'ethernet' ? (p.carrier ? t.cableIn : t.noCable) : (p.carrier ? t.linkUp : t.notConnected),
      ?p.address,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.statusTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _Rows([
          (t.wifiMode, mode),
          (t.connection, status.connected && status.ssid != null ? t.connectedTo(status.ssid!) : t.notConnected),
          (t.ip, status.ip ?? '—'),
          for (final p in status.interfaces) (p.name, port(p)),
        ]),
        if (wired) ...[const SizedBox(height: 12), Text(t.chooseHint)],
        const SizedBox(height: 16),
        if (wifi) FilledButton(onPressed: onConfigure, child: Text(t.configureWifi)),
        if (wifi && wired) const SizedBox(height: 8),
        if (wired) FilledButton.tonal(onPressed: onWired, child: Text(t.configureWired)),
      ],
    );
  }
}

/// The Ethernet port's addressing: DHCP by default, or static, checked here
/// as the device would check it.
class WiredForm extends StatefulWidget {
  const WiredForm({super.key, required this.step, required this.onBack, required this.onSubmit});

  final WiredStep step;
  final VoidCallback onBack;
  final void Function(Wired form) onSubmit;

  @override
  State<WiredForm> createState() => _WiredFormState();
}

class _WiredFormState extends State<WiredForm> {
  late final _ports = widget.step.status.ethernet;
  late String _port = widget.step.form?.port ?? _ports.first.name;
  late bool _dhcp = widget.step.form?.dhcp ?? true;
  late final _address = TextEditingController(text: widget.step.form?.address);
  late final _gateway = TextEditingController(text: widget.step.form?.gateway);
  late final _dns = TextEditingController(text: widget.step.form?.dns);
  String _error = '';

  @override
  void dispose() {
    _address.dispose();
    _gateway.dispose();
    _dns.dispose();
    super.dispose();
  }

  void _submit() {
    final t = AppLocalizations.of(context);
    final address = _address.text.trim(), gateway = _gateway.text.trim();
    final problem = _dhcp
        ? ''
        : !isCidr(address)
        ? t.resultInvalidAddress
        : gateway.isNotEmpty && !isIpv4(gateway)
        ? t.resultInvalidGateway
        : splitList(_dns.text).any((d) => !isIp(d))
        ? t.resultInvalidDns
        : '';
    setState(() => _error = problem);
    if (problem.isEmpty) {
      widget.onSubmit(Wired(_port, dhcp: _dhcp, address: address, gateway: gateway, dns: _dns.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.wiredTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _port,
          decoration: InputDecoration(labelText: t.port),
          items: [for (final p in _ports) DropdownMenuItem(value: p.name, child: Text(p.name))],
          onChanged: (v) => setState(() => _port = v ?? _port),
        ),
        RadioGroup<bool>(
          groupValue: _dhcp,
          onChanged: (v) => setState(() => _dhcp = v ?? true),
          child: Column(
            children: [
              RadioListTile(contentPadding: EdgeInsets.zero, value: true, title: Text(t.dhcp)),
              RadioListTile(contentPadding: EdgeInsets.zero, value: false, title: Text(t.staticAddress)),
            ],
          ),
        ),
        if (!_dhcp) ...[
          TextField(
            controller: _address,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(labelText: t.addressLabel),
          ),
          TextField(
            controller: _gateway,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(labelText: t.gateway),
          ),
          TextField(
            controller: _dns,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(labelText: t.dns),
          ),
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
              child: FilledButton(onPressed: _submit, child: Text(t.apply)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Step 8 done: `finish` takes no fields.
class JoinedView extends StatelessWidget {
  const JoinedView({super.key, required this.step, required this.onFinish});

  final JoinedStep step;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(step.text, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 16),
        FilledButton(onPressed: onFinish, child: Text(AppLocalizations.of(context).finish)),
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

/// Step 9 done; the console (step 10) opens in the browser, where the
/// device is claimed.
class DoneView extends StatelessWidget {
  const DoneView({super.key, required this.step});

  final DoneStep step;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final reached = step.reached, apPsk = step.apPsk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.done, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (reached != null)
          Text(
            t.doneConnected(reached.$1 == 'ethernet' ? t.ethernet : t.wifi, (reached.$2 ?? '—').split('/').first),
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        if (!step.claimed) ...[const SizedBox(height: 8), Text(t.doneClaim)],
        const SizedBox(height: 12),
        Text(step.urls.isEmpty ? t.consoleOffNetwork : t.consoleAt),
        for (final u in step.urls)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: () => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication),
              child: Text(u),
            ),
          ),
        if (step.apOn) ...[const SizedBox(height: 12), Text(t.hotspotOn)],
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
