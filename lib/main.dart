import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ble.dart';
import 'console/devices.dart';
import 'console/discovery.dart';
import 'l10n/app_localizations.dart';
import 'manage_page.dart';
import 'protocol/client.dart';
import 'protocol/crypto.dart';
import 'setup_page.dart';
import 'update.dart';
import 'wifi.dart';

void main() {
  runApp(
    MicaApp(
      radio: PlatformBluetooth(),
      kdf: _isolateKdf,
      wifi: PlatformWifi(),
      discovery: MdnsDiscovery(),
      store: PrefsDeviceStore(),
      // iOS updates come from the App Store.
      newerRelease: Platform.isAndroid ? newerRelease : null,
    ),
  );
}

Future<void> _openExternal(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

// PBKDF2 at the device's iteration count takes seconds: off the UI isolate.
Future<({BigInt w0, BigInt w1})> _isolateKdf(String pw, List<int> salt, int iterations) =>
    Isolate.run(() => spakeScalars(pw, salt, iterations));

class MicaApp extends StatefulWidget {
  const MicaApp({
    super.key,
    required this.radio,
    required this.kdf,
    required this.wifi,
    required this.discovery,
    required this.store,
    this.transport = ioTransport,
    this.open = _openExternal,
    this.newerRelease,
    this.locale,
  });

  final Bluetooth radio;
  final Kdf kdf;
  final Wifi wifi;
  final Discovery discovery;
  final DeviceStore store;
  final TransportFactory transport;
  final Future<void> Function(Uri url) open;

  /// Asked once at start: a later release's version, offered as a download.
  final Future<String?> Function()? newerRelease;

  /// Null follows the phone's language.
  final Locale? locale;

  @override
  State<MicaApp> createState() => _MicaAppState();
}

class _MicaAppState extends State<MicaApp> {
  late Locale? _locale = widget.locale;
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _offerUpdate();
  }

  Future<void> _offerUpdate() async {
    final version = await widget.newerRelease?.call();
    final context = _navigator.currentContext;
    if (version == null || context == null || !context.mounted) return;
    final t = AppLocalizations.of(context);
    final download = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.updateTitle),
        content: Text(t.updateBody(version)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.updateLater)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.updateDownload)),
        ],
      ),
    );
    if (download == true) await widget.open(apkUrl);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigator,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: ThemeData(colorSchemeSeed: const Color(0xff0b6e8a), useMaterial3: true),
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => HomePage(
          onSwitchLanguage: () => setState(() {
            _locale = Localizations.localeOf(context).languageCode == 'zh' ? const Locale('en') : const Locale('zh');
          }),
          onBluetooth: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => SetupPage(
                radio: widget.radio,
                kdf: widget.kdf,
                wifi: widget.wifi,
                open: widget.open,
                onManage: (url) => _manage(context, url),
                onSwitchLanguage: () => setState(() {
                  _locale = Localizations.localeOf(context).languageCode == 'zh'
                      ? const Locale('en')
                      : const Locale('zh');
                }),
              ),
            ),
          ),
          onNetwork: () => _manage(context),
        ),
      ),
    );
  }

  void _manage(BuildContext context, [Uri? initial]) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => ManagePage(
        discovery: widget.discovery,
        store: widget.store,
        transport: widget.transport,
        open: widget.open,
        initial: initial,
      ),
    ),
  );
}

/// The two ways in: Bluetooth setup, and the device's API over the network.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onSwitchLanguage, required this.onBluetooth, required this.onNetwork});

  final VoidCallback onSwitchLanguage, onBluetooth, onNetwork;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [TextButton(onPressed: onSwitchLanguage, child: Text(t.switchTo))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.homeLead),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(t.homeBle),
                subtitle: Text(t.homeBleHint),
                onTap: onBluetooth,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lan_outlined),
                title: Text(t.homeNetwork),
                subtitle: Text(t.homeNetworkHint),
                onTap: onNetwork,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
