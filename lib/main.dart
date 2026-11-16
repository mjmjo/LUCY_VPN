import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const VpnHomeScreen(),
    );
  }
}

class VpnHomeScreen extends StatefulWidget {
  const VpnHomeScreen({super.key});

  @override
  State<VpnHomeScreen> createState() => _VpnHomeScreenState();
}

class _VpnHomeScreenState extends State<VpnHomeScreen> {
  late final FlutterV2ray _v2ray;
  bool _isConnected = false;
  String _v2rayStatus = 'Disconnected';

  String _downloadSpeedStr = '0 KB/s';
  String _uploadSpeedStr = '0 KB/s';
  String _downloadTotalStr = '0 MB';
  String _uploadTotalStr = '0 MB';

  int _lastDownloadBytes = 0;
  int _lastUploadBytes = 0;

  int _secondsConnected = 0;
  Timer? _timer;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  final String _adUnitId = 'ca-app-pub-3940256099942544/6300978111';

  final List<dynamic> _servers = [
    {
      "name": "United States (New York)",
      "flag": "🇺🇸",
      "url": "vmess://ewogICJ2IjogIjIiLAogICJwcyI6ICJMVUNZLmNvbSIsCiAgImFkZCI6ICIxNTUuMTE3LjEyMC42NSIsCiAgInBvcnQiOiAyMDgzLAogICJpZCI6ICIwODM5ZWFiOC0zZjI5LTQxNmQtODgyOC1kN2E3OTdiMmE0NGEiLAogICJzY3kiOiAiYXV0byIsCiAgIm5ldCI6ICJ3cyIsCiAgInRscyI6ICJub25lIiwKICAicGF0aCI6ICIvIiwKICAiaG9zdCI6ICIiCn0="
    },
    {
      "name": "Germany (Frankfurt)",
      "flag": "🇩🇪",
      "config": '''
{
  "log": {"loglevel": "warning"},
  "inbounds": [{"port": 10808, "protocol": "socks", "settings": {"auth": "noauth", "udp": true}}],
  "outbounds": [{"protocol": "vless", "settings": {"vnext": [{"address": "germany.testserver.com", "port": 443, "users": [{"id": "b831381d-6324-4d53-ad4f-8cda48b30811", "encryption": "none"}]}]}, "streamSettings": {"network": "ws", "security": "tls"}}]
}
'''
    },
    {
      "name": "France (Paris)",
      "flag": "🇫🇷",
      "config": '''
{
  "log": {"loglevel": "warning"},
  "inbounds": [{"port": 10808, "protocol": "socks", "settings": {"auth": "noauth", "udp": true}}],
  "outbounds": [{"protocol": "vless", "settings": {"vnext": [{"address": "france.testserver.com", "port": 443, "users": [{"id": "b831381d-6324-4d53-ad4f-8cda48b30811", "encryption": "none"}]}]}, "streamSettings": {"network": "ws", "security": "tls"}}]
}
'''
    }
  ];

  late Map<String, dynamic> _selectedServer;

  @override
  void initState() {
    super.initState();
    _selectedServer = _servers[0];
    _initV2ray();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    )..load();
  }

  void _initV2ray() async {
    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        setState(() {
          _v2rayStatus = status.state;
          _isConnected = status.state == 'CONNECTED';

          int currentDownload = status.download;
          int currentUpload = status.upload;

          int diffDownload = currentDownload - _lastDownloadBytes;
          int diffUpload = currentUpload - _lastUploadBytes;

          if (diffDownload < 0) diffDownload = 0;
          if (diffUpload < 0) diffUpload = 0;

          _downloadSpeedStr = _formatSpeed(diffDownload);
          _uploadSpeedStr = _formatSpeed(diffUpload);

          _downloadTotalStr = _formatBytes(currentDownload);
          _uploadTotalStr = _formatBytes(currentUpload);

          _lastDownloadBytes = currentDownload;
          _lastUploadBytes = currentUpload;

          if (_isConnected) {
            _startTimer();
          } else {
            _stopTimer();
          }
        });
      },
    );
    await _v2ray.initializeV2Ray();
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return "$bytesPerSecond B/s";
    if (bytesPerSecond < 1024 * 1024) return "${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s";
    return "${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s";
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsConnected = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsConnected++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _secondsConnected = 0;
    _lastDownloadBytes = 0;
    _lastUploadBytes = 0;
    _downloadSpeedStr = '0 KB/s';
    _uploadSpeedStr = '0 KB/s';
    _downloadTotalStr = '0 MB';
    _uploadTotalStr = '0 MB';
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$secs";
  }

  Future<void> _toggleVpn() async {
    if (_isConnected) {
      await _v2ray.stopV2Ray();
    } else {
      if (await _v2ray.requestPermission()) {
        String finalConfig;

        if (_selectedServer.containsKey("url")) {
          final V2RayURL parser = FlutterV2ray.parseFromURL(_selectedServer["url"]!);
          finalConfig = parser.getFullConfiguration();
        } else {
          finalConfig = _selectedServer["config"]!;
        }

        await _v2ray.startV2Ray(
          remark: _selectedServer["name"]!,
          config: finalConfig,
          bypassSubnets: [],
          proxyOnly: false,
        );
      }
    }
  }

  void _showServerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select Location",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  itemCount: _servers.length,
                  itemBuilder: (context, index) {
                    final server = _servers[index];
                    return ListTile(
                      leading: Text(server["flag"]!, style: const TextStyle(fontSize: 26)),
                      title: Text(server["name"]!),
                      trailing: _selectedServer["name"] == server["name"]
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.circle_outlined, color: Colors.grey),
                      onTap: () {
                        setState(() {
                          _selectedServer = server;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lucy VPN', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.dns_rounded),
            onPressed: _isConnected ? null : _showServerBottomSheet,
            tooltip: 'Select Location',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: _isConnected ? null : _showServerBottomSheet,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.grey.shade700),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_selectedServer["flag"]!, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 10),
                              Text(_selectedServer["name"]!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 8),
                              const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Status: $_v2rayStatus',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isConnected ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Duration: ${_formatDuration(_secondsConnected)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                      const SizedBox(height: 35),
                      GestureDetector(
                        onTap: _toggleVpn,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isConnected ? Colors.green.shade700 : Colors.red.shade700,
                            boxShadow: [
                              BoxShadow(
                                color: (_isConnected ? Colors.green : Colors.red).withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 8,
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
                      const SizedBox(height: 15),
                      Text(
                        _isConnected ? 'TAP TO DISCONNECT' : 'TAP TO CONNECT',
                        style: const TextStyle(fontSize: 13, color: Colors.grey, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 35),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSpeedCard(
                            icon: Icons.arrow_downward_rounded,
                            label: "DOWNLOAD",
                            speed: _downloadSpeedStr,
                            total: _downloadTotalStr,
                            color: Colors.lightBlueAccent,
                          ),
                          const SizedBox(width: 16),
                          _buildSpeedCard(
                            icon: Icons.arrow_upward_rounded,
                            label: "UPLOAD",
                            speed: _uploadSpeedStr,
                            total: _uploadTotalStr,
                            color: Colors.purpleAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isBannerAdLoaded && _bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedCard({
    required IconData icon,
    required String label,
    required String speed,
    required String total,
    required Color color,
  }) {
    return Container(
      width: 145,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            speed,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Total: $total',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ],
      ),
    );
  }
}