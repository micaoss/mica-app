import 'package:multicast_dns/multicast_dns.dart';

/// A device announcing `_mica._tcp` on the LAN (mica-core `docs/mica-core.md`
/// section 3.13): its hostname, an IPv4 address and the console's port, 0 when
/// the console does not serve the network.
class Found {
  const Found(this.hostname, this.address, this.port, {this.product = ''});

  final String hostname, address, product;
  final int port;
}

abstract class Discovery {
  /// One round of queries: the devices that answered.
  Future<List<Found>> browse();

  /// The IPv4 address of `<name>.local`, or null.
  Future<String?> resolve(String name);
}

const _type = '_mica._tcp.local';
const _round = Duration(seconds: 3);

/// mDNS on the phone's Wi-Fi.
class MdnsDiscovery implements Discovery {
  @override
  Future<List<Found>> browse() async {
    final client = MDnsClient();
    final found = <String, Found>{};
    try {
      await client.start();
      await for (final ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(_type),
        timeout: _round,
      )) {
        var txt = <String, String>{};
        await for (final t in client.lookup<TxtResourceRecord>(ResourceRecordQuery.text(ptr.domainName))) {
          txt = parseTxt(t.text);
        }
        await for (final srv in client.lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))) {
          await for (final ip in client.lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))) {
            final host = txt['hostname'] ?? srv.target.replaceFirst(RegExp(r'\.local\.?$'), '');
            found[host] = Found(host, ip.address.address, srv.port, product: txt['product'] ?? '');
            break;
          }
        }
      }
    } finally {
      client.stop();
    }
    return found.values.toList()..sort((a, b) => a.hostname.compareTo(b.hostname));
  }

  @override
  Future<String?> resolve(String name) async {
    final client = MDnsClient();
    try {
      await client.start();
      await for (final ip in client.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv4(name.endsWith('.local') ? name : '$name.local'),
        timeout: _round,
      )) {
        return ip.address.address;
      }
      return null;
    } finally {
      client.stop();
    }
  }
}

/// A TXT record's `key=value` strings, one per line as multicast_dns joins them.
Map<String, String> parseTxt(String text) => {
  for (final line in text.split('\n'))
    if (line.contains('=')) line.substring(0, line.indexOf('=')): line.substring(line.indexOf('=') + 1),
};
