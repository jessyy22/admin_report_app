import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'admin_login.dart';
import 'admin_main_layout.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await Supabase.initialize(
    url: 'https://haryaqpwigdqthiulgwu.supabase.co', 
    anonKey: 
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhhcnlhcXB3aWdkcXRoaXVsZ3d1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NzY2NDAsImV4cCI6MjA5MTQ1MjY0MH0.iW3Tujg1Q81Fsepj6LgBef7f1s0cMhJcSoEmjpWSKRk', 
  ); 
 
  runApp(const RTODAAdminApp()); 
} 
 
class RTODAAdminApp extends StatelessWidget { 
  const RTODAAdminApp({super.key}); 
 
  @override 
  Widget build(BuildContext context) { 
    return MaterialApp( 
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green), 
      // StreamBuilder listens to Auth state changes 
      home: StreamBuilder<AuthState>( 
        stream: Supabase.instance.client.auth.onAuthStateChange, 
        builder: (context, snapshot) { 
          if (snapshot.connectionState == ConnectionState.waiting) { 
            return const Scaffold( 
              body: Center(child: CircularProgressIndicator()), 
            ); 
          } 
 
          final session = snapshot.data?.session; 
          return session != null 
              ? const AdminMainLayout() 
              : const AdminLoginPage(); 
        }, 
      ), 
    ); 
  } 
} 