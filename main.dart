import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:map_trade/firebase_options.dart';
import 'package:map_trade/intro/intro_page.dart'; // IntroPage import 추가

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map Trade',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const IntroPage(), // MapPage에서 IntroPage로 변경
      debugShowCheckedModeBanner: false,
    );
  }
}
