import 'dart:convert';

import 'dart:typed_data';

BleDevice bleDeviceFromJson(String str) => BleDevice.fromJson(json.decode(str));

String bleDeviceToJson(BleDevice data) => json.encode(data.toJson());

class BleDevice {
  BleDevice(
      {required this.address,
      required this.rssi,
      required this.timestamp,
      required this.advType,
      required this.name,
      required this.serviceUuids,
      required this.manufacturerData,
      this.adStructures});

  String address;
  String name;
  String rssi;
  String timestamp;
  String advType;
  Uint8List manufacturerData;
  List<dynamic> serviceUuids;
  List<AdStructure>? adStructures;

  factory BleDevice.fromJson(Map<String, dynamic> json) {
    // Prefer raw bytes for device name to handle non-ASCII correctly (e.g., Chinese characters)
    String deviceName = json["localName"] ?? "N/A";
    if (json["localNameBytes"] != null) {
      try {
        final bytes = List<int>.from(json["localNameBytes"]);
        if (bytes.isNotEmpty) {
          deviceName = utf8.decode(bytes, allowMalformed: true);
        }
      } catch (_) {
        // fallback to existing localName
      }
    }

    return BleDevice(
      address: json["bluetoothAddress"] ?? "",
      rssi: json["rssi"]?.toString() ?? "",
      timestamp: json["timestamp"]?.toString() ?? "",
      advType: json["advType"] ?? "",
      name: deviceName,
      serviceUuids: json["serviceUuids"],
      manufacturerData: json["manufacturerData"] != null
          ? Uint8List.fromList(List<int>.from(json["manufacturerData"]))
          : Uint8List.fromList(List.empty()),
      adStructures: json["adStructures"] == null
          ? null
          : List<AdStructure>.from(json["adStructures"].map((x) =>
              AdStructure(type: x["type"], data: List<int>.from(x["data"])))),
    );
  }


  Map<String, dynamic> toJson() => {
        "bluetoothAddress": address,
        "rssi": rssi,
        "timestamp": timestamp,
        "advType": advType,
        "localName": name,
        "serviceUuids": serviceUuids.toString(),
        "manufacturerData": manufacturerData.toString(),
      };
}

class AdStructure {
  int type;
  List<int> data;
  AdStructure({required this.type, required this.data});
}
