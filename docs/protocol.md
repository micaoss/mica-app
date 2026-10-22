# Protocol

The app speaks micad's BLE provisioning protocol, version 1. The normative document is mica-core's
[`docs/ble-provisioning.md`](https://github.com/micaoss/mica-core/blob/main/docs/ble-provisioning.md);
its test vectors are checked in `test/protocol/crypto_test.dart`.

The user flow and its texts follow mica-network-spec chapter 5 section 3, the same flow the web page
`setup-test.micaos.dev` implements.
