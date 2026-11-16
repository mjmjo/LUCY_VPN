import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

void main() {
  runApp(const LucyVpnApp());
}

class LucyVpnApp extends StatelessWidget {
  const LucyVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lucy VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
      ),
      home: const VpnHomePage(),
    );
  }
}

class VpnHomePage extends StatefulWidget {
  const VpnHomePage({super.key});

  @override
  State<VpnHomePage> createState() => _VpnHomePageState();
}

class _VpnHomePageState extends State<VpnHomePage> {
  late final FlutterV2ray flutterV2ray;
  V2RayStatus v2rayStatus = V2RayStatus();
  int selectedServerIndex = 0;

  final servers = [
    {
      'name': 'United States (USA)',
      'flag': '🇺🇸',
      'config': 'vmess://ewogICJ2IjogIjIiLAogICJwcyI6ICJMVUNZLmNvbSIsCiAgImFkZCI6ICIxNTUuMTE3LjEyMC42NSIsCiAgInBvcnQiOiAyMDgzLAogICJpZCI6ICIwODM5ZWFiOC0zZjI5LTQxNmQtODgyOC1kN2E3OTdiMmE0NGEiLAogICJzY3kiOiAiYXV0byIsCiAgIm5ldCI6ICJ3cyIsCiAgInRscyI6ICJub25lIiwKICAicGF0aCI6ICIvIiwKICAiaG9zdCI6ICIiCn0=',
    },
    {
      'name': 'France',
      'flag': '🇫🇷',
      'config': '',
    },
    {
      'name': 'Netherlands',
      'flag': '🇳🇱',
      'config': '',
    },
  ];

  @override
  void initState() {
    super.initState();
    flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        setState(() {
          v2rayStatus = status;
        });
      },
    );
    flutterV2ray.initializeV2Ray();
  }

  Future<void> toggleConnection() async {
    if (v2rayStatus.state == 'CONNECTED') {
      await flutterV2ray.stopV2Ray();
      return;
    }

    String currentConfig = servers[selectedServerIndex]['config'] ?? '';

    if (currentConfig.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('این سرور در حال حاضر غیرفعال است. لطفاً آمریکا را انتخاب کنید.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      V2RayURL parser = FlutterV2ray.parseFromURL(currentConfig);
      if (await flutterV2ray.requestPermission()) {
        await flutterV2ray.startV2Ray(
          remark: parser.remark,
          config: parser.getFullConfiguration(),
          bypassSubnets: [],
          proxyOnly: false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در اتصال: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = v2rayStatus.state == 'CONNECTED';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lucy VPN', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: toggleConnection,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? Colors.green.shade600 : Colors.blue.shade600,
                  boxShadow: [
                    BoxShadow(
                      color: (isConnected ? Colors.green : Colors.blue).withOpacity(0.4),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.power_settings_new,
                  size: 75,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isConnected ? 'متصل شد (Connected)' : 'متصل نیست (Disconnected)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isConnected ? Colors.greenAccent : Colors.white70,
              ),
            ),
            const SizedBox(height: 35),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'انتخاب سرور:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: servers.length,
                itemBuilder: (context, index) {
                  bool isSelected = selectedServerIndex == index;
                  return Card(
                    color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? Colors.blueAccent : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      leading: Text(
                        servers[index]['flag']!,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(
                        servers[index]['name']!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.blueAccent)
                          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                      onTap: () {
                        if (isConnected) {
                          flutterV2ray.stopV2Ray();
                        }
                        setState(() {
                          selectedServerIndex = index;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}