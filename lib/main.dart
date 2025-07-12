import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'screens/business_home_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ApiService(),
      child: MaterialApp(
        title: 'Business Ad Platform',
        home: BusinessHomeScreen(),
      ),
    ),
  );
}
