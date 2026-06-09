import 'package:flutter/material.dart';
import 'package:facturacuellosuazo_app/presentation/screens/home_screen.dart';

void main() {
  runApp(const FacturaCuelloSuazoApp());
}

class FacturaCuelloSuazoApp extends StatelessWidget {
  const FacturaCuelloSuazoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FacturaCuelloSuazoApp Fiscal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}