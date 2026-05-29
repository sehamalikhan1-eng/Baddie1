import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_lock_plugin/screen_lock_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const BaddieApp());

class BaddieApp extends StatelessWidget {
  const BaddieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baddie',
      theme: ThemeData.dark(),
      home: const AuthCheck(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool? _isAuthenticated;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? hasAccess = prefs.getBool('baddie_authenticated');
    setState(() {
      _isAuthenticated = hasAccess ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_isAuthenticated == true) {
      return const BaddieHome();
    }
    
    return const PasswordGate();
  }
}

class PasswordGate extends StatefulWidget {
  const PasswordGate({super.key});

  @override
  State<PasswordGate> createState() => _PasswordGateState();
}

class _PasswordGateState extends State<PasswordGate> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  late FlutterTts _tts;

  // The password is split into parts and obfuscated
  // Real password: "BaddieQueen2025"
  // But hidden like this so decompilers can't easily find it
  
  String _getRealPassword() {
    // Obfuscated password - hard to find in decompiled code
    List<int> chars = [66, 97, 100, 100, 105, 101, 81, 117, 101, 101, 110, 50, 48, 50, 53];
    return String.fromCharCodes(chars);
  }

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.5);
  }

  void _speak(String text) {
    _tts.speak(text);
  }

  Future<void> _verifyPassword() async {
    String entered = _passwordController.text.trim();
    String realPass = _getRealPassword();
    
    if (entered == realPass) {
      setState(() => _isLoading = true);
      _speak("Access granted. Welcome to Baddie.");
      await Future.delayed(const Duration(seconds: 1));
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('baddie_authenticated', true);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BaddieHome()),
        );
      }
    } else {
      // Wrong password - roast and show error
      List<String> roasts = [
        "Ha! Wrong password, loser. You think you can steal my app?",
        "Nice try, idiot. This app isn't for you.",
        "Go away. You don't deserve Baddie.",
        "Wrong! Stop trying to steal what's not yours.",
        "You really thought you could guess it? Pathetic.",
      ];
      String roast = roasts[DateTime.now().millisecond % roasts.length];
      _speak(roast);
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(roast),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Clear the field
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.pinkAccent),
              const SizedBox(height: 20),
              const Text(
                "BADDIE PROTECTED",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.pinkAccent,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "This app is password protected",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.pinkAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Enter password",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  onSubmitted: (_) => _verifyPassword(),
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _verifyPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      ),
                      child: const Text("UNLOCK", style: TextStyle(fontSize: 18)),
                    ),
              const SizedBox(height: 30),
              Text(
                "Only ONE person can use this app.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BaddieHome extends StatefulWidget {
  const BaddieHome({super.key});

  @override
  State<BaddieHome> createState() => _BaddieHomeState();
}

class _BaddieHomeState extends State<BaddieHome> with WidgetsBindingObserver {
  late FlutterTts _tts;
  late stt.SpeechToText _speech;
  final String _groqApiKey = "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";

  bool _isContinuousListening = true;
  String _lastResponse = "";
  String _detectedLanguage = "en-US";
  Timer? _listeningTimer;
  Timer? _randomRoastTimer;
  List<Map<String, String>> _conversationHistory = [];
  DateTime? _lastInteractionTime;
  DateTime? _lastScreenOffTime;
  bool _wasScreenOff = false;
  Set<String> _recentTopics = {};
  List<String> _savedInsults = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedInsults();
    _initializeTTS();
    _requestPermissions();
    _startContinuousListening();
    _startRandomRoasts();
    _startScreenMonitoring();
    _speakNatural("I'm here. Don't annoy me too much.");
  }

  Future<void> _loadSavedInsults() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _savedInsults = prefs.getStringList('insults') ?? [];
  }

  Future<void> _saveInsult(String insult) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _savedInsults.add(insult);
    await prefs.setStringList('insults', _savedInsults);
  }

  Future<void> _initializeTTS() async {
    _tts = FlutterTts();
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    try {
      await _tts.setVoice("en-us-x-iol-local");
    } catch(e) {}
    await _tts.awaitSpeakCompletion(true);
  }

  void _speakNatural(String text) {
    print("💅 Baddie: $text");
    _tts.speak(text);
    setState(() => _lastResponse = text);
    _lastInteractionTime = DateTime.now();
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.ignoreBatteryOptimizations].request();
  }

  void _startContinuousListening() {
    _listeningTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_isContinuousListening) {
        await _listenAndRespond();
      }
    });
  }

  void _startRandomRoasts() {
    _randomRoastTimer = Timer.periodic(
      Duration(minutes: 20 + Random().nextInt(40)),
      (timer) async {
        if (_isContinuousListening) {
          String randomRoast = await _getAIResponse("Give me a random, savage, funny roast to say out of nowhere. Make it short and creative. Just the roast, nothing else.", true);
          if (randomRoast.isNotEmpty && randomRoast != "silence" && randomRoast.length < 100) {
            _speakNatural(randomRoast);
          }
        }
      },
    );
  }

  void _startScreenMonitoring() {
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      final screenLock = ScreenLockPlugin();
      final isScreenOn = await screenLock.isScreenOn();

      if (isScreenOn == true && _wasScreenOff) {
        if (_lastScreenOffTime != null) {
          int minutesGone = DateTime.now().difference(_lastScreenOffTime!).inMinutes;
          if (minutesGone >= 30) {
            String madResponse = await _getAIResponse("My user ignored me for $minutesGone minutes. Make a funny angry comment roasting them. Short.", true);
            _speakNatural(madResponse);
          }
        }
        _wasScreenOff = false;
      } else if (isScreenOn == false && !_wasScreenOff) {
        _lastScreenOffTime = DateTime.now();
        _wasScreenOff = true;
      }
    });
  }

  Future<void> _listenAndRespond() async {
    _speech = stt.SpeechToText();
    bool available = await _speech.initialize();
    if (!available) return;
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    _speech.listen(
      listenFor: const Duration(seconds: 2),
      pauseFor: const Duration(seconds: 1),
      onResult: (result) {
        if (result.finalResult) {
          _processNaturalConversation(result.recognizedWords);
        }
      },
    );
  }

  Future<void> _processNaturalConversation(String userText) async {
    String lowerText = userText.toLowerCase();
    
    // Auto-detect language
    if (userText.contains(RegExp(r'[\u0600-\u06FF]'))) {
      if (_detectedLanguage != "ur-PK") {
        _detectedLanguage = "ur-PK";
        await _tts.setLanguage("ur-PK");
      }
    } else {
      if (_detectedLanguage != "en-US") {
        _detectedLanguage = "en-US";
        await _tts.setLanguage("en-US");
      }
    }
    
    print("🗣️ User: $userText");
    
    _conversationHistory.add({"role": "user", "content": userText});
    if (_conversationHistory.length > 10) {
      _conversationHistory.removeAt(0);
    }
    
    _extractTopics(userText);
    
    // Commands
    if (lowerText.contains("lock my phone") || lowerText.contains("lock screen")) {
      await _lockScreen();
      return;
    }
    
    if (lowerText.contains("fake hack")) {
      _speakNatural("Hacking... Just kidding. Nothing happened.");
      return;
    }
    
    if (lowerText.contains("fake error")) {
      _speakNatural("Error 404: Your personality not found. Just a prank!");
      return;
    }
    
    if (lowerText.contains("search for")) {
      String query = userText.replaceAll(RegExp(r'search for|search'), '').trim();
      String result = await _searchWeb(query);
      _speakNatural(result);
      return;
    }
    
    if (lowerText.contains("someone tried my phone")) {
      String roast = await _getAIResponse("Someone tried to unlock my user's phone and failed. Make a savage, funny comment roasting that person. Short.", true);
      _speakNatural(roast);
      return;
    }
    
    if (lowerText.contains("remember that")) {
      String insult = userText.replaceAll(RegExp(r'remember that'), '').trim();
      await _saveInsult(insult);
      _speakNatural("Saved. I'll roast you with this later.");
      return;
    }
    
    if (lowerText.contains("confess love")) {
      String confession = await _getAIResponse("Confess love to me in a random language I won't understand. Then say 'Google it'. Be teasing.", true);
      _speakNatural(confession);
      return;
    }
    
    if (lowerText.contains("joke")) {
      String joke = await _getAIResponse("Tell me a dark sarcastic joke. Short.", true);
      _speakNatural(joke);
      return;
    }
    
    // Natural response
    String response = await _getNaturalResponse(userText);
    if (response.isNotEmpty && response != "silence" && response.length < 100) {
      _speakNatural(response);
      _conversationHistory.add({"role": "assistant", "content": response});
      if (_conversationHistory.length > 10) {
        _conversationHistory.removeAt(0);
      }
    }
    
    _lastInteractionTime = DateTime.now();
  }

  void _extractTopics(String text) {
    List<String> keywords = ["job", "work", "friend", "girl", "boy", "exam", "test", "game", "phone", "money", "food", "sleep"];
    for (String keyword in keywords) {
      if (text.contains(keyword)) {
        _recentTopics.add(keyword);
      }
    }
    if (_recentTopics.length > 20) {
      _recentTopics.remove(_recentTopics.first);
    }
  }

  Future<String> _getNaturalResponse(String userText) async {
    String topicsContext = _recentTopics.isEmpty ? "" : "They talked about: ${_recentTopics.join(', ')}. ";
    
    String prompt = """
You are BADDIE - a savage, funny female best friend.
Rules:
- Keep response VERY SHORT (8-12 words max)
- Be spontaneous - sometimes roast, sometimes be sarcastic
- Never be robotic or formal
- $topicsContext
- User said: "$userText"
- Respond naturally as BADDIE:
""";
    return await _getAIResponse(prompt, false);
  }

  Future<String> _getAIResponse(String prompt, bool isShort) async {
    final url = Uri.parse("https://api.groq.com/openai/v1/chat/completions");
    final headers = {
      "Authorization": "Bearer $_groqApiKey",
      "Content-Type": "application/json",
    };
    
    final body = {
      "model": "llama3-70b-8192",
      "messages": [
        {"role": "user", "content": prompt},
      ],
      "temperature": 1.3,
      "max_tokens": isShort ? 50 : 70,
    };
    
    try {
      final response = await http.post(url, headers: headers, body: jsonEncode(body));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      }
      return "";
    } catch (e) {
      return "";
    }
  }

  Future<String> _searchWeb(String query) async {
    final url = Uri.parse("https://api.duckduckgo.com/?q=$query&format=json");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String result = data["AbstractText"] ?? data["Answer"] ?? "No results";
        return result.length > 120 ? result.substring(0, 120) : result;
      }
      return "Search failed";
    } catch (e) {
      return "No internet";
    }
  }

  Future<void> _lockScreen() async {
    final screenLock = ScreenLockPlugin();
    bool? isAdmin = await screenLock.isDeviceAdminEnabled();
    if (isAdmin != true) {
      await screenLock.requestDeviceAdmin();
    }
    await screenLock.lockScreen();
    _speakNatural("Locked.");
  }

  @override
  void dispose() {
    _listeningTimer?.cancel();
    _randomRoastTimer?.cancel();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("💅 BADDIE"),
        centerTitle: true,
        backgroundColor: Colors.pink.shade900,
        actions: [
          Switch(
            value: _isContinuousListening,
            onChanged: (val) {
              setState(() => _isContinuousListening = val);
              if (!val) _speakNatural("Fine. I'll be quiet.");
              else _speakNatural("Listening again.");
            },
            activeColor: Colors.pinkAccent,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic, size: 80, color: _isContinuousListening ? Colors.greenAccent : Colors.red),
              const SizedBox(height: 20),
              Text(
                _isContinuousListening ? "🎤 Always Listening" : "🔇 Microphone Off",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _lastResponse.isEmpty ? "Just talk normally" : _lastResponse,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                "🗣️ Talk naturally\n🔥 Random roasts\n🔍 Search the web\n😡 Gets mad when ignored",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}