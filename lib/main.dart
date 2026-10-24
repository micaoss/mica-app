import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ble.dart';
import 'l10n/app_localizations.dart';
import 'protocol/client.dart';
import 'protocol/crypto.dart';
import 'setup_page.dart';
import 'wifi.dart';

void main() {
  runApp(MicaApp(radio: PlatformBluetooth(), kdf: _isolateKdf, wifi: PlatformWifi()));
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
    this.open = _openExternal,
    this.locale,
  });

  final Bluetooth radio;
  final Kdf kdf;
  final Wifi wifi;
  final Future<void> Function(Uri url) open;

  /// Null follows the phone's language.
  final Locale? locale;

  @override
  State<MicaApp> createState() => _MicaAppState();
}

class _MicaAppState extends State<MicaApp> {
  late Locale? _locale = widget.locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).title,
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
        builder: (context) => SetupPage(
          radio: widget.radio,
          kdf: widget.kdf,
          wifi: widget.wifi,
          open: widget.open,
          onSwitchLanguage: () => setState(() {
            _locale = Localizations.localeOf(context).languageCode == 'zh' ? const Locale('en') : const Locale('zh');
          }),
        ),
      ),
    );
  }
}
