
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LucyVpnApp());
}

class LucyVpnApp extends StatelessWidget {
  const LucyVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lucy VPN',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1120),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
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
  late final FlutterV2ray flutterV2Ray;

  String vpnStatus = "DISCONNECTED";
  String selectedServer = "USA";

  bool isConnected = false;
  bool isBusy = false;
  bool isInitialized = false;

  int uploadSpeed = 0;
  int downloadSpeed = 0;

  Timer? healthTimer;

  final Map<String, String> serverLinks = {
    "USA":
        "vmess://ewogICJhZGQiOiAiMTU1LjExNy4xMjAuNjUiLAogICJob3N0IjogIiIsCiAgImlkIjogImI3MWZkYmE2LWMyYjItNDY5Yy1hMDY4LTdlODdiYWMxMjVmZSIsCiAgIm5ldCI6ICJ3cyIsCiAgInBhdGgiOiAiLyIsCiAgInBvcnQiOiAyMDgzLAogICJwcyI6ICJMVUNZLmNvbS1BUFAiLAogICJzY3kiOiAiYXV0byIsCiAgInRscyI6ICJub25lIiwKICAidHlwZSI6ICJub25lIiwKICAidiI6ICIyIgp9",
    "France": "",
    "Netherlands": "",
  };

  final Map<String, int> serverDelays = {};
  final Set<String> checkingServers = {};

  final List<Map<String, String>> servers = [
    {
      "key": "USA",
      "name": "United States",
      "flag": "🇺🇸",
    },
    {
      "key": "France",
      "name": "France",
      "flag": "🇫🇷",
    },
    {
      "key": "Netherlands",
      "name": "Netherlands",
      "flag": "🇳🇱",
    },
  ];

  @override
  void initState() {
    super.initState();

    flutterV2Ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (!mounted) return;

        setState(() {
          vpnStatus = status.state;
          isConnected = status.state == "CONNECTED";

          uploadSpeed = status.uploadSpeed;
          downloadSpeed = status.downloadSpeed;

          if (!isConnected) {
            uploadSpeed = 0;
            downloadSpeed = 0;
          }
        });
      },
    );

    initV2Ray();
  }

  Future<void> initV2Ray() async {
    try {
      await flutterV2Ray.initializeV2Ray();

      if (!mounted) return;

      setState(() {
        isInitialized = true;
      });

      await checkAllServers();

      healthTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) {
          if (!isConnected && !isBusy) {
            checkAllServers();
          }
        },
      );
    } catch (e) {
      showMessage("Initialization Error: $e");
    }
  }

  Future<bool> checkServer(String serverKey) async {
    final link = serverLinks[serverKey] ?? "";

    if (link.isEmpty || link.startsWith("vmess://...")) {
      if (mounted) {
        setState(() {
          serverDelays.remove(serverKey);
        });
      }
      return false;
    }

    if (checkingServers.contains(serverKey)) {
      return false;
    }

    if (mounted) {
      setState(() {
        checkingServers.add(serverKey);
      });
    }

    try {
      final parser = FlutterV2ray.parseFromURL(link);

      final int delay = await flutterV2Ray
          .getServerDelay(
            config: parser.getFullConfiguration(),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return false;

      setState(() {
        serverDelays[serverKey] =
            delay > 0 && delay < 10000 ? delay : -1;
      });

      return delay > 0 && delay < 10000;
    } catch (e) {
      if (mounted) {
        setState(() {
          serverDelays[serverKey] = -1;
        });
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          checkingServers.remove(serverKey);
        });
      }
    }
  }

  Future<void> checkAllServers() async {
    if (!isInitialized || isConnected) return;

    for (final server in servers) {
      if (!mounted) return;
      await checkServer(server["key"]!);
    }
  }

  Color serverColor(String key) {
    if (checkingServers.contains(key)) {
      return Colors.orangeAccent;
    }

    final link = serverLinks[key] ?? "";

    if (link.isEmpty || link.startsWith("vmess://...")) {
      return Colors.white38;
    }

    final delay = serverDelays[key];

    if (delay == null) {
      return Colors.white38;
    }

    if (delay > 0) {
      return const Color(0xFF22C55E);
    }

    return const Color(0xFFEF4444);
  }

  String serverStatusText(String key) {
    if (checkingServers.contains(key)) {
      return "Checking server...";
    }

    final link = serverLinks[key] ?? "";

    if (link.isEmpty || link.startsWith("vmess://...")) {
      return "Configuration required";
    }

    final delay = serverDelays[key];

    if (delay == null) {
      return "Not tested";
    }

    if (delay > 0) {
      return "Online • ${delay}ms";
    }

    return "Offline • Connection failed";
  }

  Future<void> toggleVpn() async {
    if (isBusy) return;

    if (!isInitialized) {
      showMessage("VPN is initializing. Please wait.");
      return;
    }

    setState(() {
      isBusy = true;
    });

    try {
      if (isConnected) {
        await flutterV2Ray.stopV2Ray();

        if (mounted) {
          setState(() {
            isConnected = false;
            vpnStatus = "DISCONNECTED";
            uploadSpeed = 0;
            downloadSpeed = 0;
          });
        }

        return;
      }

      final link = serverLinks[selectedServer] ?? "";

      if (link.isEmpty || link.startsWith("vmess://...")) {
        showMessage("No valid configuration for this server.");
        return;
      }

      showMessage("Checking $selectedServer server...");

      final available = await checkServer(selectedServer);

      if (!mounted) return;

      if (!available) {
        showMessage("$selectedServer server is offline.");
        return;
      }

      final parser = FlutterV2ray.parseFromURL(link);

      final permission = await flutterV2Ray.requestPermission();

      if (!permission) {
        showMessage("VPN permission was denied.");
        return;
      }

      setState(() {
        vpnStatus = "CONNECTING";
        uploadSpeed = 0;
        downloadSpeed = 0;
      });

      await flutterV2Ray.startV2Ray(
        remark: parser.remark.isEmpty
            ? selectedServer
            : parser.remark,
        config: parser.getFullConfiguration(),
        bypassSubnets: null,
        blockedApps: null,
        proxyOnly: false,
        notificationDisconnectButtonName: "DISCONNECT",
      );
    } catch (e) {
      if (mounted) {
        showMessage("VPN Error: $e");

        setState(() {
          vpnStatus = "DISCONNECTED";
          isConnected = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
        });
      }
    }
  }

  void selectServer(String key) {
    if (isConnected || isBusy) {
      showMessage("Disconnect VPN before changing server.");
      return;
    }

    final link = serverLinks[key] ?? "";

    if (link.isEmpty || link.startsWith("vmess://...")) {
      showMessage("This server needs a valid configuration.");
      return;
    }

    setState(() {
      selectedServer = key;
    });
  }

  String formatSpeed(int speed) {
    final value = speed < 0 ? 0 : speed;

    if (value >= 1024 * 1024) {
      return "${(value / (1024 * 1024)).toStringAsFixed(2)} MB/s";
    }

    if (value >= 1024) {
      return "${(value / 1024).toStringAsFixed(1)} KB/s";
    }

    return "$value B/s";
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color powerColor = isConnected
        ? const Color(0xFF22C55E)
        : const Color(0xFF2563EB);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // اندازه‌ها با ارتفاع واقعی صفحه تنظیم می‌شوند.
            final bool compact = constraints.maxHeight < 760;

            final double logoSize = compact ? 88 : 108;
            final double powerSize = compact ? 138 : 158;

            final double sectionGap = compact ? 16 : 23;
            final double topGap = compact ? 3 : 10;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                topGap,
                18,
                compact ? 12 : 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - topGap,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(height: compact ? 2 : 8),

                    // LOGO
                    Container(
                      width: logoSize,
                      height: logoSize,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E293B),
                        border: Border.all(
                          color: const Color(0xFF3B82F6),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.25),
                            blurRadius: 22,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          "assets/dog_logo.jpg",
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.shield_rounded,
                              size: 55,
                              color: Colors.blueAccent,
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ONLY ONE LUCY VPN TITLE
                    const Text(
                      "LUCY VPN",
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      "FAST • PRIVATE • SECURE",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),

                    SizedBox(height: sectionGap),

                    // POWER BUTTON
                    GestureDetector(
                      onTap: toggleVpn,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: powerSize,
                        height: powerSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isConnected
                                ? [
                                    const Color(0xFF16A34A),
                                    const Color(0xFF166534),
                                  ]
                                : [
                                    const Color(0xFF3B82F6),
                                    const Color(0xFF1D4ED8),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: powerColor.withValues(alpha: 0.35),
                              blurRadius: 30,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: Center(
                          child: isBusy
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Icon(
                                  Icons.power_settings_new,
                                  size: compact ? 65 : 75,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),

                    SizedBox(height: compact ? 15 : 20),

                    // CONNECTION STATUS
                    Text(
                      vpnStatus,
                      style: TextStyle(
                        color: isConnected
                            ? const Color(0xFF4ADE80)
                            : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      isConnected
                          ? "Your connection is protected"
                          : isInitialized
                              ? "Tap power button to connect"
                              : "Initializing VPN...",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),

                    SizedBox(height: sectionGap),

                    // SPEED CARDS
                    Row(
                      children: [
                        Expanded(
                          child: speedCard(
                            title: "DOWNLOAD",
                            value: formatSpeed(downloadSpeed),
                            icon: Icons.download_rounded,
                            color: const Color(0xFF22C55E),
                            compact: compact,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: speedCard(
                            title: "UPLOAD",
                            value: formatSpeed(uploadSpeed),
                            icon: Icons.upload_rounded,
                            color: const Color(0xFF38BDF8),
                            compact: compact,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: compact ? 16 : 23),

                    // SERVER HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "SELECT SERVER",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: isConnected || isBusy
                              ? null
                              : checkAllServers,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 17,
                          ),
                          label: const Text("Test all"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    // SERVER LIST
                    ...servers.map((server) {
                      return buildServerTile(
                        title: server["name"]!,
                        keyName: server["key"]!,
                        flag: server["flag"]!,
                        compact: compact,
                      );
                    }),

                    const SizedBox(height: 10),

                    const Text(
                      "Secure Connection",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(height: 5),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // SPEED CARD
  Widget speedCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF17243A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: compact ? 21 : 24,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: compact ? 17 : 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // SERVER TILE
  Widget buildServerTile({
    required String title,
    required String keyName,
    required String flag,
    required bool compact,
  }) {
    final bool selected = selectedServer == keyName;
    final Color statusColor = serverColor(keyName);

    final link = serverLinks[keyName] ?? "";
    final bool configured =
        link.isNotEmpty && !link.startsWith("vmess://...");

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF17243A),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: selected
              ? const Color(0xFF3B82F6)
              : Colors.white.withValues(alpha: 0.05),
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: compact ? 3 : 6,
          ),
          leading: Text(
            flag,
            style: TextStyle(
              fontSize: compact ? 26 : 30,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              children: [
                if (checkingServers.contains(keyName))
                  const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orangeAccent,
                    ),
                  )
                else
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                      boxShadow: [
                        if (statusColor == const Color(0xFF22C55E))
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.5),
                            blurRadius: 7,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    serverStatusText(keyName),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          trailing: selected
              ? const Icon(
                  Icons.check_circle,
                  color: Colors.blueAccent,
                  size: 24,
                )
              : Icon(
                  configured
                      ? Icons.radio_button_unchecked
                      : Icons.lock_outline,
                  color: Colors.white38,
                ),
          onTap: configured
              ? () => selectServer(keyName)
              : () => showMessage(
                    "Add a valid $title configuration first.",
                  ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    healthTimer?.cancel();
    super.dispose();
  }
}
