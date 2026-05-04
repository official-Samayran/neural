import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async'; 
import 'dart:convert';
import 'dart:math'; 
import 'package:crypto/crypto.dart'; 
import '../services/ble_service.dart';
import 'package:flutter/services.dart'; // MethodChannel ke liye zaroori hai


// ============================================================================
// 🌐 3. THE GATEKEEPER: BACKGROUND SMS HANDLER
// ============================================================================
/* @pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) async {
  // 🔥 FIX 1: THE MAGIC LINE (Zaroori for Background Tasks)
  WidgetsFlutterBinding.ensureInitialized();
  //arpit: ping test
  print("📥 [STEP 1] Background Handler Wake Up!");
  // 🚨 THE PING TEST: Fire this off immediately to prove the isolate woke up
  if (message.address != null) {
    Telephony.backgroundInstance.sendSms(
      to: message.address!, 
      message: "🤖 PING: NeuralGate Background Isolate is awake!"
    );
  }

  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isEnabled = prefs.getBool('remote_request_enabled') ?? true;
    if (!isEnabled) {
      print("🛑 Master Switch OFF. Rejecting request.");
      return;
    }

    String r = message.body?.toLowerCase().trim() ?? ""; // Received Code (r)
    String? sender = message.address;
    if (sender == null) return;

    print("📩 Sender: $sender | Message: '$r'");

    // 📥 Load Limits & Dictionaries
    int maxTpLimit = prefs.getInt('max_tp_limit') ?? 3;
    int maxReqLimit = prefs.getInt('max_req_limit') ?? 5;

    Map<String, dynamic> dic1 = {};
    String? d1Data = prefs.getString('dic1_authorized');
    if (d1Data != null) dic1 = jsonDecode(d1Data);

    Map<String, dynamic> dic2 = {};
    String? d2Data = prefs.getString('dic2_leaks');
    if (d2Data != null) dic2 = jsonDecode(d2Data);

    // 🔍 CODE MATCHING (r == h check)
    String? matchedOwner; // h1 ka number
    for (String ownerNumber in dic1.keys) {
      if (dic1[ownerNumber]['code'] == r) {
        matchedOwner = ownerNumber;
        break;
      }
    }

    if (matchedOwner == null) {
      print("❌ [STEP 2 FAIL] Request Reject: Invalid Code from $sender");
      return; 
    }

    print("✅ [STEP 2 PASS] Code Match ho gaya! Asli malik: $matchedOwner");

    // 🛡️ AUTHORIZATION & LEAK TRACKING
    if (sender == matchedOwner) {
      // SCENARIO A: Asli Malik
      print("✅ Owner Request Accept for $sender");
      await _sendLocationSafely(sender);
    } 
    else {
      // SCENARIO B: Anjaan Banda (Third Party / x)
      if (!dic2.containsKey(sender)) {
        // B1: NAYA CHOR
        int currentLeakCount = dic1[matchedOwner]['leak_count'] ?? 0;

        if (currentLeakCount >= maxTpLimit) {
          // 🚨 LIMIT CROSSED! Expiring code.
          print("🚨 Limit Crossed! Expiring code for $matchedOwner");
          dic1[matchedOwner]['code'] = "EXPIRED"; 
          await prefs.setString('dic1_authorized', jsonEncode(dic1));
          
          List<String> compromisedUsers = prefs.getStringList('compromised_users') ?? [];
          if (!compromisedUsers.contains(matchedOwner)) {
            compromisedUsers.add(matchedOwner);
            await prefs.setStringList('compromised_users', compromisedUsers);
          }
          return; 
        } else {
          // Naye chor ko allow karo
          dic1[matchedOwner]['leak_count'] = currentLeakCount + 1; 
          dic2[sender] = {
            "owner": matchedOwner,
            "count": 1 
          };
          await prefs.setString('dic1_authorized', jsonEncode(dic1));
          await prefs.setString('dic2_leaks', jsonEncode(dic2));
          
          print("⚠️ New Stranger Added to Dic2. Sending Location.");
          await _sendLocationSafely(sender);
        }
      } 
      else {
        // B2: PURANA CHOR
        int reqCount = dic2[sender]['count'] ?? 0;

        if (reqCount >= maxReqLimit) {
          print("🚫 Stranger Blocked: Request Limit Crossed for $sender");
        } else {
          dic2[sender]['count'] = reqCount + 1;
          await prefs.setString('dic2_leaks', jsonEncode(dic2));
          
          print("⚠️ Stranger limit not crossed. Sending Location.");
          await _sendLocationSafely(sender);
        }
      }
    }
  } catch (e) {
    print("❌ Background Handler Error: $e");
  }
}
 */

// ============================================================================
// 🌐 3. THE GATEKEEPERS: FOREGROUND & BACKGROUND HANDLERS
// ============================================================================
/* 
// 1. THIS RUNS ONLY WHEN APP IS KILLED/MINIMIZED
@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  print("📥 BACKGROUND Wake Up!");
  await _processSmsLogic(message, isBackground: true);
}

// 2. THIS RUNS ONLY WHEN APP IS OPEN ON SCREEN
void foregroundSmsHandler(SmsMessage message) async {
  print("📥 FOREGROUND Wake Up!");
  await _processSmsLogic(message, isBackground: false);
}

// 3. THE CORE LOGIC (Shared by both)
Future<void> _processSmsLogic(SmsMessage message, {required bool isBackground}) async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isEnabled = prefs.getBool('remote_request_enabled') ?? true;
    if (!isEnabled) return;

    String r = message.body?.toLowerCase().trim() ?? ""; 
    String? sender = message.address;
    if (sender == null) return;

    print("📩 Sender: $sender | Message: '$r'");

    // ... [KEEP ALL YOUR EXISTING DIC1 / DIC2 CHECKING LOGIC HERE] ...
    // (Assuming matchedOwner logic is the same as before)
    
    // For the sake of the fix, let's pretend it matched:
    print("✅ Logic complete. Sending Location.");
    await _sendLocationSafely(sender, isBackground); // Pass the flag!

  } catch (e) {
    print("❌ Handler Error: $e");
  }
}

// ============================================================================
// 📍 2. HELPER FUNCTION: SAFE LOCATION SENDER
// ============================================================================
Future<void> _sendLocationSafely(String sender, bool isBackground) async {
  print("📍 Fetching location...");
  Position? pos;
  
  try {
    pos = await Geolocator.getLastKnownPosition();
    if (pos == null) {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, 
        timeLimit: const Duration(seconds: 4) 
      );
    }
  } catch (e) {
    print("⚠️ Location fail: $e");
  }

  // 🔥 THE FIX: Choose the correct instance based on app state!
  final telephony = isBackground ? Telephony.backgroundInstance : Telephony.instance;

  if (pos != null) {
    String mapLink = "https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
    
    telephony.sendSms(
      to: sender, 
      /* message: "NeuralGate Secure Auto-Reply:\n📍 Location:\n $mapLink",
      isMultipart: true */
      message: mapLink
    );
    print("🚀 [SUCCESS] Location SMS sent!");
  } else {
    telephony.sendSms(
      to: sender, 
      message: "⚠️ NeuralGate Alert: Code accepted, but GPS is OFF."
    );
  }
}
 */


// Put this OUTSIDE the NeuralController class!

// 1. BACKGROUND HANDLER
@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  print("📥 [BACKGROUND MODE] SMS Received!");
  await _processSmsLogic(message, isBackground: true);
}

// 2. FOREGROUND HANDLER
void foregroundSmsHandler(SmsMessage message) async {
  print("📥 [FOREGROUND MODE] SMS Received!");
  await _processSmsLogic(message, isBackground: false);
}

// ============================================================================
// 🧠 THE CORE SMS LOGIC (Rebuilt for Strict Constraints & UI Visibility)
// ============================================================================
Future<void> _processSmsLogic(SmsMessage message, {required bool isBackground}) async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // 🚨 MAGIC FIX: Force the background isolate to sync with the main app!
    await prefs.reload();

    bool isEnabled = prefs.getBool('remote_request_enabled') ?? true;
    if (!isEnabled) return;

    String r = message.body?.toLowerCase().trim() ?? ""; 
    String? sender = message.address;
    if (sender == null) return;

    print("📩 Sender: $sender | Message: '$r'");

    int maxTpLimit = prefs.getInt('max_tp_limit') ?? 3; // Global Leak Limit
    int maxReqLimit = prefs.getInt('max_req_limit') ?? 5; // Individual Stranger Limit

    Map<String, dynamic> dic1 = jsonDecode(prefs.getString('dic1_authorized') ?? "{}");
    Map<String, dynamic> dic2 = jsonDecode(prefs.getString('dic2_leaks') ?? "{}");

    // 🔍 1. FIND THE CODE OWNER
    String? matchedOwner; 
    for (String ownerNumber in dic1.keys) {
      if (dic1[ownerNumber]['code'] == r) {
        matchedOwner = ownerNumber;
        break;
      }
    }

    if (matchedOwner == null) {
      print("❌ Invalid Code. Ignoring.");
      return; 
    }

    // 🛑 2. CHECK IF CODE IS ALREADY DEAD
    if (dic1[matchedOwner]['code'] == "EXPIRED") {
      print("🚫 This code was compromised and is EXPIRED. Ignoring request.");
      return;
    }

    // ✅ 3. SCENARIO A: AUTHORIZED OWNER (Send as is)-----------
    /*if (sender == matchedOwner) {
      print("✅ Owner verified. Sending location immediately.");
      await _sendLocationSafely(sender, isBackground);
      return;
    } */
     //---------------------------
    // ✅ 3. SCENARIO A: AUTHORIZED OWNER (Send as is)
    // 🔥 FIX: The "Last 10 Digits" Ultimate Matcher (Ignores 0, +91, spaces)
    String cleanSender = sender.replaceAll(RegExp(r'[^0-9]'), ''); // Sirf numbers rakhega
    if (cleanSender.length > 10) cleanSender = cleanSender.substring(cleanSender.length - 10);

    String cleanOwner = matchedOwner.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanOwner.length > 10) cleanOwner = cleanOwner.substring(cleanOwner.length - 10);

    if (cleanSender == cleanOwner) {
      print("✅ Owner verified! (Matched 10 digits). Sending location...");
      await _sendLocationSafely(sender, isBackground);
      return; // Ye code ko aage counter tak jaane hi nahi dega
    }
      //---------------------------
    // ⚠️ 4. SCENARIO B: THIRD PARTY (Stranger)
    print("⚠️ Third Party detected! Sender: $sender using code of: $matchedOwner");
    
    bool isNewStranger = false;

    // Initialize the stranger if it's their first time
    if (!dic2.containsKey(sender)) {
      isNewStranger = true;
      dic2[sender] = {
        "used_code_of": matchedOwner,
        "request_count": 0,
        "status": "ACTIVE"
      };
    }

    // Check if this specific stranger is already blocked
    if (dic2[sender]['status'] == "BLOCKED") {
      print("🚫 This Third Party is BLOCKED. Ignoring request.");
      return;
    }

    // 📈 5. INCREMENT BOTH COUNTERS
    int strangerCount = (dic2[sender]['request_count'] ?? 0) + 1;
    dic2[sender]['request_count'] = strangerCount;

    //owner count increment when new stranger use the code of owner
    if(isNewStranger){
      dic1[matchedOwner]['leak_count'] = (dic1[matchedOwner]['leak_count'] ?? 0) + 1;
    }

    bool shouldSendLocation = true;
    int totalLeakCount = (dic1[matchedOwner]['leak_count'] ?? 0);
    
    
    dic1[matchedOwner]['leak_count'] = totalLeakCount;


    // 🚨 6. CHECK GLOBAL LEAK LIMIT (Third party count > limit)
    if (totalLeakCount > maxTpLimit) {
      print("🚨 Owner's Leak Limit Exceeded! Expiring Code...");
      dic1[matchedOwner]['code'] = "EXPIRED";
      shouldSendLocation = false;

      // Add to popup list so UI can ask user to generate a new code
      List<String> compromised = prefs.getStringList('compromised_users') ?? [];
      if (!compromised.contains(matchedOwner)) compromised.add(matchedOwner);
      await prefs.setStringList('compromised_users', compromised);
    }

    // 🚨 7. CHECK INDIVIDUAL THIRD PARTY LIMIT (Stranger count > limit)
    // (Only checks if the global limit wasn't already tripped)
    if (shouldSendLocation && strangerCount > maxReqLimit) {
      print("🚨 Third Party reached max requests! Blocking...");
      dic2[sender]['status'] = "BLOCKED";
      shouldSendLocation = false;

      // Add to popup list so UI can ask user to reset their limit
      List<String> exhaustedTPs = prefs.getStringList('exhausted_third_parties') ?? [];
      if (!exhaustedTPs.contains(sender)) exhaustedTPs.add(sender);
      await prefs.setStringList('exhausted_third_parties', exhaustedTPs);
    }

    // 💾 8. SAVE EVERYTHING TO MEMORY
    await prefs.setString('dic1_authorized', jsonEncode(dic1));
    await prefs.setString('dic2_leaks', jsonEncode(dic2));

    // 🚀 9. FINALLY SEND LOCATION (If limits weren't breached)
    if (shouldSendLocation) {
      print("✅ Limits OK. Sending Location to Third Party.");
      await _sendLocationSafely(sender, isBackground);
    } else {
      print("🚫 Limits breached. Location withheld.");
    }

  } catch (e) {
    print("❌ Logic Error: $e");
  }
}

// 4. LOCATION SENDER
Future<void> _sendLocationSafely(String sender, bool isBackground) async {
  /*print("📍 Fetching location...");
  Position? pos;
  try {
    if (isBackground) {
      pos = await Geolocator.getLastKnownPosition();
    } else {
      pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 4));
    }
  } catch (e) {
    print("⚠️ Location fail: $e");
  }*/
  print("📍 Fetching location...");
  Position? pos;
  try {
    // 🔥 NAYA LOGIC: Sabse pehle fresh location try karo (10 sec do)
    pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high, 
      timeLimit: const Duration(seconds: 10)
    );
  } catch (e) {
    print("⚠️ Fresh location fail. Trying Last Known... Error: $e");
    // Agar fresh na mile, tabhi purani location uthao
    try {
      pos = await Geolocator.getLastKnownPosition();
    } catch (e2) {
      print("⚠️ Purani location bhi fail: $e2");
    }
  }

  // 🔥 MAGIC SWITCH
  final telephony = isBackground ? Telephony.backgroundInstance : Telephony.instance;

  /*if (pos != null) {
    String mapLink = "https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
    telephony.sendSms(to: sender, message: "📍 Location:\n$mapLink");
    print("🚀 SMS Sent!");
  }*/
  if (pos != null) {
    String mapLink = "https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
    telephony.sendSms(to: sender, message: "📍 Location:\n$mapLink");
    print("🚀 SMS Sent!");
  } else {
    // 🔥 NAYA LOGIC: Agar location na mile toh fail SMS bhejo
    telephony.sendSms(
      to: sender, 
      message: "⚠️ NeuralGate Alert: Code verified, but GPS is taking too long or turned OFF. Please try again."
    );
    print("❌ Location null thi, Error SMS bhej diya.");
  }

}



// ============================================================================
// 🔐 1. CODE GENERATOR (Algorithm)
// ============================================================================
String generateNewCodeFor(String ownerNumber) {
  int rng = Random().nextInt(999999); // Random factor
  String rawData = ownerNumber + rng.toString();
  List<int> bytes = utf8.encode(rawData); 
  String newCode = sha256.convert(bytes).toString().substring(0, 6); 
  return newCode;
}

// ============================================================================
// 📍 2. HELPER FUNCTION: SAFE LOCATION SENDER (Anti-Freeze)
// ============================================================================
/* Future<void> _sendLocationSafely(String sender) async {
  print("📍 [STEP 3] Background location fetch...");
  Position? pos;
  
  try {
    pos = await Geolocator.getLastKnownPosition();
    if (pos == null) {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, 
        timeLimit: const Duration(seconds: 4) 
      );
    }
  } catch (e) {
    print("⚠️ [ERROR] Background location fail: $e");
  }

  // Background isolate ke liye specific instance
  final telephony = Telephony.backgroundInstance; //arpit: instance; 

  if (pos != null) {
    print("✅ [STEP 4] Location mil gayi! Bhej raha hoon...");
    // 🔥 FIX: Standard URL
    String mapLink = "https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
    
    telephony.sendSms(
      to: sender, 
      message: "NeuralGate Secure Auto-Reply:\n📍 Location:\n $mapLink",
      isMultipart: true 
    );
    print("🚀 [SUCCESS] no Location SMS sent!");

  } else {
    print("❌ [FAILED] Phone ne koi location nahi di.");
    telephony.sendSms(
      to: sender, 
      message: "⚠️ NeuralGate Alert: Code accepted, but GPS is OFF or signal is weak on the target device."
    );
  }
} */


// ============================================================================
// 🧠 4. MAIN NEURAL CONTROLLER CLASS
// ============================================================================
class NeuralController extends ChangeNotifier {
  final BleService _service;

  // --- DICTIONARIES & SECURITY LIMITS ---
  Map<String, dynamic> dic1Authorized = {};
  Map<String, dynamic> dic2Leaks = {}; 
  int maxTpLimit = 3;    
  int maxReqLimit = 5;   

  Map<String, dynamic> get getDic1 => dic1Authorized;
  Map<String, dynamic> get getDic2 => dic2Leaks;

  // 🌉 Native Android se baat karne ke liye Bridge
  // 📱 Smart Phone Action Mode
  String smartPhoneAction = "media"; // Default action
  static const platform = MethodChannel('sos_app/sms');
  // --- ESP, GRAPH & UI VARIABLES (RESTORED) ---
  List<double> points = [];
  double threshold = 100.0;
  double get graphMax {
    double maxPoint = 0.0;
    for (double p in points) {
      if (p > maxPoint) maxPoint = p;
    }
    double maxVal = threshold > maxPoint ? threshold : maxPoint;
    if (maxVal < 250.0) return 250.0;
    return maxVal + 50.0; 
  }

  String activeMode = "relay";
  bool isConnected = false;
  bool isDarkMode = true; 
  bool _isCooldown = false;
  
  // --- SOS & TRACKING SETTINGS (RESTORED) ---
  bool isRemoteRequestEnabled = true; 
  String locationStrategy = "off";
  double distanceThreshold = 1.0;
  bool isTrackingActive = false;

  int graphMemory = 300; 

  void setGraphMemory(double value) {
    graphMemory = value.toInt();
    if (points.length > graphMemory) {
      points = points.sublist(points.length - graphMemory);
    }
    notifyListeners();
  }

  NeuralController(this._service) {
    loadSettings(); 
    loadDictionaries();
    points = List.generate(graphMemory, (index) => 0.0);

    _service.signalStream.listen((value) {
      points.add(value);
      if (points.length > graphMemory) {
        points.removeAt(0);
      }
      _checkThreshold(value);
      notifyListeners();
    });

    _service.connectionStream.listen((connected) {
      isConnected = connected;
      notifyListeners();
    });
  }

  // =======================================================================
  // 🔔 SMART ALERT SYSTEM (Handles both Compromised Owners & Third Parties)
  // =======================================================================
  
  Future<void> checkAlerts(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // 1. Check Third Parties first
    List<String> exhaustedTPs = prefs.getStringList('exhausted_third_parties') ?? [];
    if (exhaustedTPs.isNotEmpty) {
      _showThirdPartyAlert(context, exhaustedTPs.first, prefs);
      return; // Stop here, the popup will trigger the next check when closed
    }

    // 2. If no Third Parties, check Compromised Owners
    List<String> compromised = prefs.getStringList('compromised_users') ?? [];
    if (compromised.isNotEmpty) {
      _showCompromisedOwnerAlert(context, compromised.first, prefs);
    }
  }

  void _showThirdPartyAlert(BuildContext context, String strangerNum, SharedPreferences prefs) {
    // Safely get the owner's number for the UI text
    String ownerNum = "Unknown";
    if (dic2Leaks.containsKey(strangerNum)) {
      ownerNum = dic2Leaks[strangerNum]['used_code_of'] ?? "Unknown";
    }

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        title: const Text("🚨 Stranger Limit Reached!"),
        content: Text("Number: $strangerNum has exhausted their request limit using $ownerNum's code.\n\nDo you want to reset their limit and allow them to request locations again?"),
        actions: [
          TextButton(
            onPressed: () async {
              // NO: Keep blocked, just remove from alert list
              List<String> list = prefs.getStringList('exhausted_third_parties') ?? [];
              list.remove(strangerNum);
              await prefs.setStringList('exhausted_third_parties', list);
              
              Navigator.pop(context);
              checkAlerts(context); // 🔄 Check if there are more alerts
            },
            child: const Text("NO (Keep Blocked)", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              // YES: Reset count, unblock, and remove from alert list
              if (dic2Leaks.containsKey(strangerNum)) {
                dic2Leaks[strangerNum]['request_count'] = 0;
                dic2Leaks[strangerNum]['status'] = "ACTIVE";
                await prefs.setString('dic2_leaks', jsonEncode(dic2Leaks));
              }

              List<String> list = prefs.getStringList('exhausted_third_parties') ?? [];
              list.remove(strangerNum);
              await prefs.setStringList('exhausted_third_parties', list);
              
              notifyListeners();
              Navigator.pop(context);
              checkAlerts(context); // 🔄 Check if there are more alerts
            },
            child: const Text("YES (Reset Limit)"),
          )
        ],
      )
    );
  }

  void _showCompromisedOwnerAlert(BuildContext context, String ownerNum, SharedPreferences prefs) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        title: const Text("🚨 Code Leak Detected!"),
        content: Text("Number: $ownerNum ka code limit cross kar chuka hai aur block ho gaya hai.\n\nKya aap naya code generate karke is user ko bhejna chahte hain?"),
        actions: [
          TextButton(
            onPressed: () async {
              // NO: Keep code EXPIRED, just remove from alert list
              List<String> list = prefs.getStringList('compromised_users') ?? [];
              list.remove(ownerNum);
              await prefs.setStringList('compromised_users', list);
              
              Navigator.pop(context);
              checkAlerts(context); // 🔄 Check if there are more alerts
            },
            child: const Text("NO (Keep Expired)", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              // YES: Generate new code, update dictionaries, text user
              String newCode = generateNewCodeFor(ownerNum);
              
              // 1. Reset Owner's record
              dic1Authorized[ownerNum] = {"code": newCode, "leak_count": 0};
              await prefs.setString('dic1_authorized', jsonEncode(dic1Authorized));
              
              // 2. Erase any third parties who were using the old code
              dic2Leaks.removeWhere((key, value) => value['used_code_of'] == ownerNum);
              await prefs.setString('dic2_leaks', jsonEncode(dic2Leaks));
              
              // 3. Send SMS
              Telephony.instance.sendSms(
                to: ownerNum, 
                message: "NeuralGate Alert: Your previous code was compromised. Your NEW Secret Code is: $newCode"
              );

              // 4. Clear from popup list
              List<String> list = prefs.getStringList('compromised_users') ?? [];
              list.remove(ownerNum);
              await prefs.setStringList('compromised_users', list);
              
              notifyListeners();
              Navigator.pop(context);
              checkAlerts(context); // 🔄 Check if there are more alerts
            },
            child: const Text("YES (Generate & Send)"),
          )
        ],
      )
    );
  }

  // ==========================================
  // 🗄️ DICTIONARY & LIMITS MANAGEMENT
  // ==========================================
  Future<void> loadDictionaries() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // 🚨 MAGIC FIX: Force the UI to fetch the absolute latest data
    await prefs.reload(); 
    
    String? d1Data = prefs.getString('dic1_authorized');
    if (d1Data != null) dic1Authorized = jsonDecode(d1Data);

    String? d2Data = prefs.getString('dic2_leaks');
    if (d2Data != null) dic2Leaks = jsonDecode(d2Data);
    
    notifyListeners();
  }

  void clearDic1Data() async {
    dic1Authorized.clear();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('dic1_authorized');
    notifyListeners();
    print("🧹 Dictionary 1 poori tarah clear ho gayi!");
  }

  void clearDic2Data() async {
    dic2Leaks.clear();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('dic2_leaks');
    notifyListeners();
    print("🧹 Dictionary 2 (Third Parties) poori tarah clear ho gayi!");
  }

  void updateLimits(int tpLimit, int reqLimit) async {
    maxTpLimit = tpLimit;
    maxReqLimit = reqLimit;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('max_tp_limit', tpLimit);
    await prefs.setInt('max_req_limit', reqLimit);
    notifyListeners();
  }

  void addNewAuthorizedUser(String phoneNumber) async {
    if (!dic1Authorized.containsKey(phoneNumber)) {
      String generatedCode = generateNewCodeFor(phoneNumber);
      dic1Authorized[phoneNumber] = {
        "code": generatedCode,
        "leak_count": 0
      };
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('dic1_authorized', jsonEncode(dic1Authorized));
      notifyListeners();

      print("Sending initial code to $phoneNumber");
      Telephony.instance.sendSms(
        to: phoneNumber, 
        message: "NeuralGate SOS Alert: You are added as an Emergency Contact. Your Secret Code to request my location is: $generatedCode",
        isMultipart: true
      );
    }
  }

  void resetCodeForUser(String phoneNumber) async {
    if (dic1Authorized.containsKey(phoneNumber)) {
      String newCode = generateNewCodeFor(phoneNumber);
      dic1Authorized[phoneNumber] = {
        "code": newCode,
        "leak_count": 0
      };
      
      dic2Leaks.removeWhere((key, value) => value['owner'] == phoneNumber);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('dic1_authorized', jsonEncode(dic1Authorized));
      await prefs.setString('dic2_leaks', jsonEncode(dic2Leaks));
      notifyListeners();
    }
  }

  // ==========================================
  // ⚙️ GENERAL SETTINGS & UI CONTROLS (RESTORED)
  // ==========================================
  void loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    maxTpLimit = prefs.getInt('max_tp_limit') ?? 3;
    maxReqLimit = prefs.getInt('max_req_limit') ?? 5;
    isRemoteRequestEnabled = prefs.getBool('remote_request_enabled') ?? true;
    isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    locationStrategy = prefs.getString('location_strategy') ?? "off";
    distanceThreshold = prefs.getDouble('distance_threshold') ?? 1.0;
    smartPhoneAction = prefs.getString('smart_phone_action') ?? "media";
    notifyListeners();
  }

  void toggleTheme(bool value) async {
    isDarkMode = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    notifyListeners();
  }

  void toggleRemoteRequest(bool value) async {
    isRemoteRequestEnabled = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remote_request_enabled', value);
    notifyListeners();
  }

  void setLocationStrategy(String strategy) async {
    locationStrategy = strategy;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('location_strategy', strategy);
    notifyListeners();
  }

  void setSmartPhoneAction(String action) async {
    smartPhoneAction = action;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('smart_phone_action', action);
    notifyListeners();
  }

  void setDistanceThreshold(double dist) async {
    distanceThreshold = dist;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('distance_threshold', dist);
    notifyListeners();
  }

  void setMode(String mode) {
    activeMode = mode;
    notifyListeners();
  }

  void setThreshold(double val) {
    threshold = val;
    _service.sendThreshold(val);
    notifyListeners();
  }

  void restartBleScan() {
    _service.restartScan();
  }

  void _checkThreshold(double value) {
    if (value > threshold && !_isCooldown) {
      _isCooldown = true;
      print("🚨 THRESHOLD CROSSED! Value: $value > $threshold");
      
      _triggerActiveModeAction();

      // Cooldown of 5 seconds to avoid spamming the trigger
      Future.delayed(const Duration(seconds: 5), () {
        _isCooldown = false;
        print("✅ Cooldown finished. Ready for next trigger.");
      });
    }
  }

  void _triggerActiveModeAction() {
    print("⚙️ Auto-Triggering action for mode: $activeMode");
    if (activeMode == "phone") {
      triggerSmartPhoneAction();
    } else if (activeMode == "sos") {
      triggerManual();
    } else if (activeMode == "relay") {
      triggerRelay();
    }
  }

  void triggerRelay() {
    print("🔌 Relay trigger requested! Sending 'R' command via BLE...");
    _service.sendCommand("R");
  }
   
  //--------------
  // 📱 SMART PHONE HARDWARE CONTROL
  // 📱 SMART PHONE HARDWARE CONTROL (Media Play/Pause)
  // 📱 SMART PHONE HARDWARE CONTROL (Multi-Action)
  Future<void> triggerSmartPhoneAction() async {
    print("📱 Smart Phone Mode: Action triggered -> $smartPhoneAction");

    try {
      if (smartPhoneAction == "media") {
        await platform.invokeMethod('playPauseMedia');
        print("✅ Media toggled!");
      } 
      else if (smartPhoneAction == "call_pick") {
        await platform.invokeMethod('pickCall');
        print("✅ Call pick command sent!");
      } 
      else if (smartPhoneAction == "flashlight") {
        await platform.invokeMethod('toggleFlashlight');
        print("✅ Flashlight toggled!");
      }
      else if (smartPhoneAction == "assistant") {
        await platform.invokeMethod('triggerAssistant');
        print("✅ Voice Assistant triggered!");
      }
      else if (smartPhoneAction == "volume_up") {
        await platform.invokeMethod('volumeUp');
        print("✅ Volume increased!");
      }
    } catch (e) {
      print("❌ Failed to execute native action: $e");
    }
  }
  // 🚨 FIXED MANUAL TRIGGER (With Location Support)
  // 🚨 FIXED MANUAL TRIGGER (Anti-Freeze & Anti-Spam)
  void triggerManual() async {
    print("🚨 Manual SOS Trigger Started!");
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> contacts = prefs.getStringList('emergency_contacts') ?? [];
    String msg = prefs.getString('sos_message') ?? "Emergency! Brain Signal Threshold Exceeded.";

    if (contacts.isEmpty) {
      print("⚠️ Warning: Memory mein number nahi mila! Default number use kar raha hoon.");
      // 👇 Yahan +91 ke baad apna default number daal de
      contacts = ["+916267364421"];
    }

    String finalMessage = msg;
    if (locationStrategy != "off") {
      print("📍 Location fetch kar raha hoon...");
      try {
        // Pehle fast location uthao taaki app freeze na ho
        Position? pos = await Geolocator.getLastKnownPosition();
        pos ??= await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high, 
            timeLimit: const Duration(seconds: 10)
          );
        
        // 🔥 FIX: Standard Google Maps Link (Spam nahi lagega)
        finalMessage += "\n📍 Location: https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
        print("✅ Location mil gayi aur message mein jud gayi!");
      } catch (e) {
        print("⚠️ Location fail ho gayi: $e");
        finalMessage += "\n⚠️ (Location fetch failed. GPS might be off)";
      }
    }

    for (String number in contacts) {  
      print("✉️ Sending SMS to $number...");
      Telephony.instance.sendSms(
        to: number, 
        message: finalMessage,
        isMultipart: true // 🔥 Naya fix (Ye lambe location message ko tootne nahi dega)
      );
      print("✅ SMS Successfully sent to $number");
    }
    notifyListeners();
  }

  // 🔥 FIX 2: MISSING FUNCTION RESTORED
  void stopDistanceTracking() {
    isTrackingActive = false;
    notifyListeners();
  }
}