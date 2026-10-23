// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get title => 'mica 蓝牙配网';

  @override
  String get lead => '用手机通过蓝牙为 mica 设备配置 Wi-Fi 或有线网络，手机不需要连接设备热点。';

  @override
  String get switchTo => 'English';

  @override
  String get radioUnsupported => '这台手机不支持低功耗蓝牙，请使用设备热点配网';

  @override
  String get radioUnauthorized => '请在手机设置中允许本应用使用蓝牙';

  @override
  String get radioOff => '请打开蓝牙';

  @override
  String get findHint => '列出正在配网的设备，按主机名（如 mica-a4e2e69e）选择。不需要蓝牙配对。';

  @override
  String get findingDevices => '正在查找设备…';

  @override
  String get noDeviceHint => '设备只在配网窗口内可见：开机后 10 分钟内，或在控制台开启配网后。';

  @override
  String get connecting => '正在连接…';

  @override
  String get deviceBusy => '已有其他手机连接该设备，请等对方完成后重试';

  @override
  String get device => '设备';

  @override
  String get model => '型号';

  @override
  String get hostname => '主机名';

  @override
  String get claimed => '已认领';

  @override
  String get unclaimed => '未认领';

  @override
  String get protocolMismatch => '请升级应用或设备';

  @override
  String get passwordUnavailable => '请先登录一次控制台以启用蓝牙恢复';

  @override
  String get authPassword => '管理员密码';

  @override
  String get authTempCode => '临时配网码';

  @override
  String get authTempCodeHint => '控制台“蓝牙配网”中显示的 8 位数字';

  @override
  String get verify => '验证';

  @override
  String get verifying => '正在验证…';

  @override
  String get wrongPassword => '密码错误';

  @override
  String get wrongCode => '配网码错误';

  @override
  String attemptsLeft(int n) {
    return '，还可尝试 $n 次';
  }

  @override
  String locked(int minutes) {
    return '错误次数过多，设备已锁定，请在 $minutes 分钟后重试';
  }

  @override
  String get adminTitle => '设置管理员';

  @override
  String get adminHint => '管理员密码和主机名在完成配网时生效。';

  @override
  String get adminPassword => '管理员密码（至少 8 位）';

  @override
  String get adminPassword2 => '再次输入密码';

  @override
  String get hostnameOptional => '主机名（可选）';

  @override
  String get passwordTooShort => '密码至少 8 位';

  @override
  String get passwordTooLong => '密码过长';

  @override
  String get passwordMismatch => '两次输入的密码不一致';

  @override
  String get hostnameInvalid => '主机名只能包含字母、数字和连字符，不能以连字符开头或结尾，最多 63 个字符';

  @override
  String get next => '下一步';

  @override
  String get statusTitle => '当前状态';

  @override
  String get wifiMode => 'Wi-Fi 模式';

  @override
  String get modeClient => 'Wi-Fi 客户端';

  @override
  String get modeAp => 'Wi-Fi 接入点';

  @override
  String get modeOff => '已关闭';

  @override
  String get connection => '连接';

  @override
  String connectedTo(Object ssid) {
    return '已连接 $ssid';
  }

  @override
  String get notConnected => '未连接';

  @override
  String get ip => 'IP';

  @override
  String get configureWifi => '配置 Wi-Fi';

  @override
  String get networkTitle => '选择网络';

  @override
  String get scanning => '正在扫描…';

  @override
  String get rescan => '重新扫描';

  @override
  String get apNoScan => '设备当前为 Wi-Fi 接入点模式，不能扫描，请输入网络名称。';

  @override
  String get scanFailed => '扫描失败，可以重新扫描或手动输入';

  @override
  String get noNetworks => '没有扫描到网络';

  @override
  String get manual => '手动输入网络名称';

  @override
  String get ssid => '网络名称';

  @override
  String get hidden => '隐藏网络（不广播名称）';

  @override
  String get open => '开放';

  @override
  String get ssidInvalid => '网络名称为 1–32 字节';

  @override
  String passwordTitle(Object ssid) {
    return '连接 $ssid';
  }

  @override
  String get wifiPassword => 'Wi-Fi 密码（开放网络留空）';

  @override
  String get pskInvalid => 'Wi-Fi 密码为 8–63 个可打印字符，或 64 位十六进制数';

  @override
  String apWarning(Object ssid) {
    return '设备将关闭热点并连接 $ssid，连着设备热点的终端会断开';
  }

  @override
  String get join => '连接';

  @override
  String get back => '返回';

  @override
  String progress(Object ssid) {
    return '正在连接 $ssid…';
  }

  @override
  String success(Object ssid, Object ip) {
    return '已连接 $ssid，IP：$ip';
  }

  @override
  String get finish => '完成配网';

  @override
  String get finishing => '正在完成…';

  @override
  String get done => '配网完成';

  @override
  String get openConsole => '打开控制台';

  @override
  String get apPsk => '设备热点的新密码';

  @override
  String get apPskOnce => '只显示这一次，请现在记下。';

  @override
  String get alreadyClaimed => '设备已被其他方式认领';

  @override
  String get closingIdle => '2 分钟无操作，设备断开了蓝牙。';

  @override
  String get disconnectedUnclaimed => '蓝牙已断开，本次未完成的设置已撤销。重新连接后重新开始。';

  @override
  String get disconnectedClaimed => '蓝牙已断开。重新连接并验证后继续。';

  @override
  String get reconnect => '重新连接';

  @override
  String get restart => '重新开始';

  @override
  String get commError => '与设备通信出错，请重新连接';

  @override
  String get resultWrongPassword => 'Wi-Fi 密码错误';

  @override
  String get resultSsidNotFound => '未找到该网络，请检查名称或靠近路由器';

  @override
  String get resultDhcpTimeout => '已连接但未获得 IP，请检查路由器';

  @override
  String get resultUnsupportedSecurity => '设备不支持该网络的加密方式';

  @override
  String get resultBusy => '设备忙，请稍候重试';

  @override
  String get resultConnectFailed => '连接失败，请重试';

  @override
  String get resultInvalidSsid => '网络名称无效';

  @override
  String get resultInvalidPsk => 'Wi-Fi 密码格式无效';

  @override
  String get resultNoRadio => '设备没有可用的 Wi-Fi';

  @override
  String get resultNotClaimed => '请先设置管理员';

  @override
  String get resultInvalidPassword => '管理员密码无效（8–1024 字节）';

  @override
  String get resultInvalidHostname => '主机名无效';

  @override
  String failed(Object reason) {
    return '操作失败：$reason';
  }

  @override
  String get chooseHint => '设备通过 Wi-Fi 还是网线上网？';

  @override
  String get configureWired => '配置有线网络';

  @override
  String get ethernet => '有线';

  @override
  String get wifi => 'Wi-Fi';

  @override
  String get cableIn => '已插网线';

  @override
  String get noCable => '未插网线';

  @override
  String get linkUp => '已连接';

  @override
  String get wiredTitle => '有线网络';

  @override
  String get port => '网口';

  @override
  String get dhcp => '自动获取（DHCP）';

  @override
  String get staticAddress => '静态地址';

  @override
  String get addressLabel => '地址/前缀（如 192.168.1.40/24）';

  @override
  String get gateway => '网关（可选）';

  @override
  String get dns => 'DNS 服务器（可选，用空格或逗号分隔）';

  @override
  String get apply => '应用';

  @override
  String applying(Object name) {
    return '正在配置 $name…';
  }

  @override
  String wiredUp(Object name, Object address) {
    return '$name 已配置，地址：$address';
  }

  @override
  String doneConnected(Object kind, Object address) {
    return '已连接。$kind $address。';
  }

  @override
  String get consoleAt => '打开控制台：';

  @override
  String get consoleOffNetwork => '此设备的控制台未对网络开放，无法从这里打开。';

  @override
  String get doneClaim => '打开控制台设置管理员密码。控制台会要求输入设备标签上的设备码。';

  @override
  String get hotspotOn => '设备热点仍开启，密码见设备标签。';

  @override
  String get resultBadRequest => '请求格式错误';

  @override
  String get resultUnknownOp => '设备不支持此操作';

  @override
  String get resultUnknownInterface => '设备上没有这个有线网口';

  @override
  String get resultInvalidAddress => '地址应为 IPv4 地址加前缀，如 192.168.1.40/24';

  @override
  String get resultInvalidGateway => '网关应为 IPv4 地址';

  @override
  String get resultInvalidDns => 'DNS 服务器应为 IP 地址';

  @override
  String get resultValidationFailed => '设备拒绝了这组网络设置';

  @override
  String get resultNameInvalid => '网络设置不接受这个网口名称';

  @override
  String get resultGatewayOutOfSubnet => '网关不在该地址的子网内';

  @override
  String get resultAddressOverlap => '该子网与设备另一个接口的子网重叠';

  @override
  String get resultMetricDuplicate => '另一个接口的默认路由使用了相同的优先级';

  @override
  String get resultVlanDuplicate => '同一父接口上有两个 VLAN 使用了相同的 ID';

  @override
  String get resultVlanParentInvalid => 'VLAN 的父接口无效';

  @override
  String get resultBridgePortInvalid => '网桥端口无效';

  @override
  String get resultBridgePortAddressed => '该网口属于网桥，不能单独设置地址';

  @override
  String get resultBridgePortTaken => '该网口属于多个网桥';

  @override
  String get resultNoCarrier => '没有插网线。设置已保存，插上网线后生效';

  @override
  String get resultWiredDhcpTimeout => '30 秒内没有获得 DHCP 地址。设置已保存';
}
