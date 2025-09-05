import 'package:flutter/material.dart';
import 'package:map_trade/intro/intro_page.dart'; // IntroPage import 추가

void main() {
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
