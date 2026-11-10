import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const PowerUpApp());
}

class PowerUpApp extends StatelessWidget {
  const PowerUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.cyan,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
      ),
      home: const RemoteHomePage(),
    );
  }
}

class RemoteHomePage extends StatefulWidget {
  const RemoteHomePage({super.key});

  @override
  State<RemoteHomePage> createState() => _RemoteHomePageState();
}

class _RemoteHomePageState extends State<RemoteHomePage> {
  // BLE UUIDs (Harus sama dengan Firmware ESP32)
  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String rxUuid = "8ec90001-f525-4504-a354-1193f66d4103";
  final String txUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? rxCharacteristic;
  BluetoothCharacteristic? txCharacteristic;
  StreamSubscription? scanSub;
  StreamSubscription? notifySub;

  bool isScanning = false;
  bool isConnected = false;

  // Data Telemetri
  double vIn = 0.0;
  double vOut = 0.0;
  double vBat = 0.0;
  int batPct = 0;
  bool relayState = false;
  bool isCharging = false;

  void startScan() async {
    setState(() => isScanning = true);

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName == "ESP32_POWER_REMOTE") {
          FlutterBluePlus.stopScan();
          connectToDevice(r.device);
          break;
        }
      }
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => isScanning = false);
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        targetDevice = device;
        isConnected = true;
        isScanning = false;
      });

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == serviceUuid) {
          for (var c in service.characteristics) {
            if (c.uuid.toString() == rxUuid) {
              rxCharacteristic = c;
            } else if (c.uuid.toString() == txUuid) {
              txCharacteristic = c;
              await txCharacteristic!.setNotifyValue(true);
              notifySub = txCharacteristic!.lastValueStream.listen((data) {
                parseTelemetry(utf8.decode(data));
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal konek: $e");
    }
  }

  void parseTelemetry(String data) {
    // Format: Vin, Vout, Vbat, BatPct, RelayState, IsCharging
    List<String> parts = data.split(',');
    if (parts.length >= 6) {
      setState(() {
        vIn = double.tryParse(parts[0]) ?? 0.0;
        vOut = double.tryParse(parts[1]) ?? 0.0;
        vBat = double.tryParse(parts[2]) ?? 0.0;
        batPct = int.tryParse(parts[3]) ?? 0;
        relayState = parts[4] == "1";
        isCharging = parts[5] == "1";
      });
    }
  }

  void sendCommand(String cmd) async {
    if (rxCharacteristic != null) {
      await rxCharacteristic!.write(utf8.encode(cmd));
    }
  }

  void disconnectDevice() async {
    notifySub?.cancel();
    scanSub?.cancel();
    await targetDevice?.disconnect();
    setState(() {
      isConnected = false;
      targetDevice = null;
    });
  }

  @override
  void dispose() {
    notifySub?.cancel();
    scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ESP Controller"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
            ),
            color: isConnected ? Colors.cyanAccent : Colors.grey,
            onPressed: isConnected ? disconnectDevice : startScan,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status Koneksi Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  isConnected ? Icons.link : Icons.link_off,
                  color: isConnected ? Colors.greenAccent : Colors.redAccent,
                  size: 32,
                ),
                title: Text(isConnected ? "Terhubung ke ESP32" : "Terputus"),
                subtitle: Text(
                  isConnected
                      ? targetDevice!.platformName
                      : "Tekan scan untuk menghubungkan",
                ),
                trailing: isScanning
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: isConnected ? disconnectDevice : startScan,
                        child: Text(isConnected ? "Putus" : "Scan"),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Power Switch Utama
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "POWER UP RELAY",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          relayState ? "AKTIF" : "NONAKTIF",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: relayState
                                ? Colors.cyanAccent
                                : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    Transform.scale(
                      scale: 1.3,
                      child: Switch(
                        value: relayState,
                        activeColor: Colors.cyanAccent,
                        onChanged: isConnected
                            ? (val) {
                                sendCommand(val ? "POWER_ON" : "POWER_OFF");
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sensor Tegangan Gauges
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    "INPUT VOLT",
                    "${vIn.toStringAsFixed(1)} V",
                    Icons.bolt,
                    Colors.orangeAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    "OUTPUT VOLT",
                    "${vOut.toStringAsFixed(1)} V",
                    Icons.speed,
                    Colors.cyanAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Battery ESP32 Indicator
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCharging
                                  ? Icons.battery_charging_full
                                  : Icons.battery_std,
                              color: isCharging
                                  ? Colors.greenAccent
                                  : Colors.lightBlueAccent,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Baterai ESP32",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          "$batPct % (${vBat.toStringAsFixed(2)}V)",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: batPct / 100.0,
                      backgroundColor: Colors.white12,
                      color: batPct < 30
                          ? Colors.redAccent
                          : Colors.greenAccent,
                      minHeight: 8,
                    ),
                    if (isCharging) ...[
                      const SizedBox(height: 8),
                      const Text(
                        "Auto-Charging Aktif (<30%)",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons (Alarm & Music)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                ),
                label: const Text(
                  "BUNYIKAN ALARM / MUSIC",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                onPressed: isConnected ? () => sendCommand("PLAY_ALARM") : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color accentColor,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
