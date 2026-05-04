import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telephony/telephony.dart';
import 'services/ble_service.dart';
import 'controllers/neural_controller.dart';
import 'widgets/neural_graph.dart';
// Note: Make sure the file is named settings_page.dart, or change this import accordingly
import 'settings_page.dart'; 
import 'package:permission_handler/permission_handler.dart'; // Add this import
import 'services/background_service.dart';
import 'screens/security_dashboard.dart'; // Add this line!
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => NeuralController(BleService()),
      child: const NeuralGateApp(),
    ),
  );
}

// ============================================================================
// 📱 MAIN APP WIDGET
// ============================================================================
class NeuralGateApp extends StatelessWidget {
  const NeuralGateApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<NeuralController>().isDarkMode;

    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505), 
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007AFF), brightness: Brightness.dark), 
      ),
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF0F0F5), 
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007AFF), brightness: Brightness.light),
      ),
      home: const HomeScreen(), 
    );
  }
}

// ============================================================================
// 🏠 HOME SCREEN (Converted to StatefulWidget to support Pop-ups)
// ============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  
@override
  void initState() {
    super.initState();
    
    // 🔥 App khulte hi sabse pehle ye function chalega
    _requestAllPermissions();

    // Fir naya Pop-up system check karega (Handles BOTH Owners and Strangers)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NeuralController>(context, listen: false).checkAlerts(context);
    });
  }

  // 🛡️ PERMISSION MANGER FUNCTION
  // 🛡️ PERMISSION MANAGER & SMS LISTENER
  /*arpit: original Future<void> _requestAllPermissions() async {
    // 1. Location Permission
    LocationPermission locPerm = await Geolocator.checkPermission();
    if (locPerm == LocationPermission.denied) {
      locPerm = await Geolocator.requestPermission();
    }
    
    // 2. SMS & Phone Permission aur Listener ON karna
    bool? smsPermission = await Telephony.instance.requestPhoneAndSmsPermissions;
    
    if (smsPermission != null && smsPermission) {
      print("✅ Permissions Granted! Starting SMS Listener...");
      
      // 🔥 YAHAN ENGINE START HOTA HAI 🔥
      Telephony.instance.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          // Agar app open hai (Foreground) tab bhi check karo
          backgroundSmsHandler(message); 
        },
        onBackgroundMessage: backgroundSmsHandler, // App background/kill hai tab check karo
      );
    } else {
      print("❌ SMS Permission Denied!");
    }
  } */

  // 🛡️ PERMISSION MANAGER & SMS LISTENER
  /*arpit:old Future<void> _requestAllPermissions() async {
    // --------------------------------------------------------
    // STEP 1: FOREGROUND LOCATION
    // --------------------------------------------------------
    LocationPermission locPerm = await Geolocator.checkPermission();
    if (locPerm == LocationPermission.denied) {
      locPerm = await Geolocator.requestPermission();
    }
    
    // --------------------------------------------------------
    // STEP 2: BACKGROUND LOCATION (The Android 11+ Fix)
    // --------------------------------------------------------
    // If the user only gave "While using the app" permission, 
    // we MUST ask again to trigger the Background permission request.
    if (locPerm == LocationPermission.whileInUse) {
      print("⚠️ Foreground granted. Now requesting Background Location...");
      
      // On Android 11+, this will push the user to the App Settings screen.
      // They MUST manually select "Allow all the time".
      locPerm = await Geolocator.requestPermission(); 
    }

    if (locPerm != LocationPermission.always) {
      print("❌ WARNING: Background location ('Allow all the time') denied. Location won't fetch when app is minimized.");
    } else {
      print("✅ Background Location Granted!");
    }

    // --------------------------------------------------------
    // STEP 3: SMS & PHONE PERMISSIONS
    // --------------------------------------------------------
    bool? smsPermission = await Telephony.instance.requestPhoneAndSmsPermissions;
    
    if (smsPermission != null && smsPermission) {
      print("✅ SMS Permissions Granted! Starting Listener...");
      
      // 🔥 YAHAN ENGINE START HOTA HAI 🔥
      Telephony.instance.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          // Agar app open hai (Foreground) tab bhi check karo
          backgroundSmsHandler(message); 
        },
        onBackgroundMessage: backgroundSmsHandler, // App background/kill hai tab check karo
      );
    } else {
      print("❌ SMS Permission Denied!");
    }
  } */

  /* Future<void> _requestAllPermissions() async {
    print("🛡️ Starting aggressive permission requests...");

    // STEP 1: FORCE IGNORE BATTERY OPTIMIZATIONS (Crucial for Vivo/Xiaomi)
    // This pops up a system dialog asking the user to let the app run unrestricted.
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      print("🔋 Requesting Battery Optimization Bypass...");
      await Permission.ignoreBatteryOptimizations.request();
    }

    // STEP 2: FOREGROUND LOCATION
    PermissionStatus locStatus = await Permission.locationWhenInUse.request();

    // STEP 3: BACKGROUND LOCATION (Allow all the time)
    if (locStatus.isGranted) {
      if (await Permission.locationAlways.isDenied) {
        print("📍 Requesting Background Location (Allow all the time)...");
        // This forces the settings page open on Android 11+
        await Permission.locationAlways.request();
      }
    } else {
      print("❌ User denied foreground location.");
    }

    // STEP 4: SMS & PHONE PERMISSIONS
    await Permission.sms.request();
    await Permission.phone.request();

    // old working STEP 5: VERIFY AND START ENGINE
    /* if (await Permission.sms.isGranted) {
      print("✅ All core permissions look good! Starting SMS Listener...");
      
      /* Telephony.instance.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          backgroundSmsHandler(message); 
        },
        onBackgroundMessage: backgroundSmsHandler, 
      ); */

      // 🔥 YAHAN ENGINE START HOTA HAI 🔥
      Telephony.instance.listenIncomingSms(
        onNewMessage: foregroundSmsHandler,      // Use the new Foreground handler!
        onBackgroundMessage: backgroundSmsHandler, // Keep the Background handler here
      );
    } else {
      print("❌ SMS Permission Denied! Engine cannot start.");
    } */

    // STEP 5: VERIFY AND START THE UNSTOPPABLE ENGINE
    if (await Permission.sms.isGranted) {
      print("✅ All permissions granted! Booting Foreground Service...");
      
      // 🔥 Start the 24/7 Service instead of the standard listener
      // This will trigger the persistent notification and run the listener in the background
      await initializeBackgroundService();
      
    } else {
      print("❌ SMS Permission Denied! Engine cannot start.");
    }
  } */
  // 🛡️ THE BULLETPROOF PERMISSION MANAGER
  Future<void> _requestAllPermissions() async {
    print("🛡️ Starting permission checks...");

    try {
      // --------------------------------------------------------
      // STEP 1: FOREGROUND LOCATION (Check first!)
      // --------------------------------------------------------
      if (await Permission.locationWhenInUse.isDenied) {
        await Permission.locationWhenInUse.request();
      }

      // --------------------------------------------------------
      // STEP 1.5: BLUETOOTH PERMISSIONS
      // --------------------------------------------------------
      if (await Permission.bluetoothScan.isDenied) {
        await Permission.bluetoothScan.request();
      }
      if (await Permission.bluetoothConnect.isDenied) {
        await Permission.bluetoothConnect.request();
      }
      if (await Permission.bluetooth.isDenied) {
        await Permission.bluetooth.request();
      }

      // --------------------------------------------------------
      // STEP 2: BACKGROUND LOCATION (Check first!)
      // --------------------------------------------------------
      if (await Permission.locationWhenInUse.isGranted) {
        if (await Permission.locationAlways.isDenied) {
          print("📍 Requesting Background Location...");
          await Permission.locationAlways.request();
        }
      }

      // --------------------------------------------------------
      // STEP 3: SMS & PHONE (Check first!)
      // --------------------------------------------------------
      if (await Permission.sms.isDenied) {
        await Permission.sms.request();
      }
      if (await Permission.phone.isDenied) {
        await Permission.phone.request();
      }

     // --------------------------------------------------------
      // STEP 4: BOOT THE UNSTOPPABLE ENGINE
      // --------------------------------------------------------
      if (await Permission.sms.isGranted) {
        print("✅ Core permissions granted!");
        
        // 1. Turn on the Dumb Shield to keep Vivo awake
        await initializeBackgroundService(); 
        
        // 2. Start the normal Telephony listener 
        Telephony.instance.listenIncomingSms(
          onNewMessage: foregroundSmsHandler, 
          onBackgroundMessage: backgroundSmsHandler, 
        );
      }
      // --------------------------------------------------------
      // STEP 5: BATTERY REQUEST (Protected & Checked)
      // --------------------------------------------------------
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        Future.delayed(const Duration(seconds: 2), () async {
          try {
            print("🔋 Requesting Battery Optimization Bypass...");
            await Permission.ignoreBatteryOptimizations.request();
          } catch (e) {
            // Vivo's custom OS sometimes blocks this command entirely. 
            // This catch prevents the app from crashing if Vivo blocks it.
            print("⚠️ Battery setting returned an error: $e");
          }
        });
      }

    } catch (e) {
      print("❌ Critical error in permissions: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<NeuralController>().isDarkMode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0A0B10), const Color(0xFF050505)] 
                : [Colors.white, const Color(0xFFE2E2E2)], 
          ),
        ),
        child: SafeArea( 
          child: Column(
            children: [
              // --- HEADER ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48), 
                    Row(
                      children: [
                        Text(
                          "NEURALGATE",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4, 
                            color: isDark ? Colors.white : Colors.black87
                          )
                        ),
                        const SizedBox(width: 8),
                        Consumer<NeuralController>(
                          builder: (context, ctrl, _) => Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ctrl.isConnected ? Colors.green : Colors.red,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  ctrl.restartBleScan();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Restarting BLE Scan..."), duration: Duration(seconds: 1)),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                  child: Icon(Icons.refresh, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // 🛡️ WE WRAPPED THE ICONS IN A NEW ROW HERE
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.security, color: isDark ? Colors.white : Colors.black87),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SecurityDashboard()),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.settings, color: isDark ? Colors.white : Colors.black87),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SettingsPage()), // Make sure SettingsPage exists!
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // --- GRAPH PLOTTER ---
              Expanded(
                flex: 3, 
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(28), 
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                    boxShadow: isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 15)],
                  ),
                  child: Consumer<NeuralController>(
                    builder: (context, ctrl, _) => NeuralGraph(
                      points: ctrl.points,
                      threshold: ctrl.threshold,
                      graphMax: ctrl.graphMax,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 5),

              // --- GRAPH SPEED (MEMORY) SLIDER ---
              Opacity(
                opacity: 0.5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    children: [
                      Text("Speed", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 10)),
                      Expanded(
                        child: Consumer<NeuralController>(
                          builder: (context, ctrl, _) => SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2.0,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                              activeTrackColor: const Color(0xFF007AFF),
                              inactiveTrackColor: isDark ? Colors.white24 : Colors.black12,
                              thumbColor: const Color(0xFF007AFF),
                            ),
                            child: Slider(
                              value: ctrl.graphMemory.toDouble(),
                              min: 50.0,
                              max: 600.0,
                              onChanged: (val) => ctrl.setGraphMemory(val),
                            ),
                          ),
                        ),
                      ),
                      Consumer<NeuralController>(
                        builder: (context, ctrl, _) => Text("${ctrl.graphMemory}", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 10)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 5),
              // --- CONTROLLER BOX ---
              Expanded(
                flex: 4, 
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121214) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                    boxShadow: isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 15)],
                  ),
                  child: const SingleChildScrollView(child: ControlLayout()), 
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🎛️ CONTROLS LAYOUT 
// ============================================================================
class ControlLayout extends StatelessWidget {
  const ControlLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NeuralController>();
    final isDark = controller.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("SELECT DEVICE", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
        Selector<NeuralController, String>(
          selector: (_, c) => c.activeMode,
          builder: (context, mode, _) => DropdownButton<String>(
            value: mode, isExpanded: true, underline: const SizedBox(),
            dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
            items: const [
              DropdownMenuItem(value: "relay", child: Text("Relay Module")),
              DropdownMenuItem(value: "phone", child: Text("Smartphone")),
              DropdownMenuItem(value: "sos", child: Text("SOS Mode")),
            ],
            onChanged: (v) => controller.setMode(v!),
          ),
        ),
        Divider(color: isDark ? Colors.white10 : Colors.black12, height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("LIMIT", style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold)),
            Text("${controller.threshold.toInt()}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
        Slider(
          value: controller.threshold, 
          min: 10, 
          max: 500, 
          activeColor: const Color(0xFF007AFF), 
          onChanged: (v) => controller.setThreshold(v)
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () {
            // 🕵️‍♂️ DEBUG LINE: Ye terminal mein print karega ki asal mein kaunsa mode active hai
            print("🧐 Button Clicked! Current Active Mode is: '${controller.activeMode}'");

            if (controller.activeMode == "phone") {
              print("✅ Smart Phone mode detected! Calling triggerSmartPhoneAction...");
              controller.triggerSmartPhoneAction(); 
            } 
            else if (controller.activeMode == "sos") {
              print("✅ SOS mode detected! Calling triggerManual...");
              controller.triggerManual(); 
            } 
            else if (controller.activeMode == "relay") {
              print("✅ Relay Module selected! Triggering relay manually.");
              controller.triggerRelay();
            } 
            else {
              // Agar inme se koi match nahi hua, tab ye chalega
              print("⚠️ WARNING: Mode match nahi hua! Default SMS bhej raha hu.");
              controller.triggerManual(); 
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF), 
            foregroundColor: Colors.white, 
            minimumSize: const Size(double.infinity, 65), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
          ),
          child: const Text("MANUAL TRIGGER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        if (controller.isTrackingActive) 
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: ElevatedButton.icon(
              onPressed: () => controller.stopDistanceTracking(),
              icon: const Icon(Icons.stop_circle, color: Colors.white),
              label: const Text("STOP DISTANCE TRACKING", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, 
                minimumSize: const Size(double.infinity, 60), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
              ),
            ),
          ),
      ],          
    ); 
  } 
}

