// =============================================
// OSGB YAZILIMI - ANA FLUTTER DOSYASI
// Bu dosya uygulamanin giris noktasidir
// =============================================

// 📚 DERS: import = Baska dosyalardaki kodlari kullanmak
// Python'daki "from x import y" ile ayni mantik

// Flutter'in gorsel araclarini ice aktar (buton, text, renk vs.)
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Kendi dosyalarimiz
import 'screens/login_screen.dart';   // Giris ekrani

// ---- UYGULAMAYI BASLAT ----
// 📚 DERS: Her Dart/Flutter uygulamasi main() ile baslar
// Python'daki "if __name__ == '__main__':" gibi
void main() {
  runApp(const OsgbApp());
}

// ---- ANA UYGULAMA SINIFI ----
// 📚 DERS: StatelessWidget = Degismeyen widget
// Uygulama genelinde sabit olan ayarlar burada
// (tema renkleri, baslik, vs.)
class OsgbApp extends StatelessWidget {
  const OsgbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSGB Yonetim Sistemi',
      debugShowCheckedModeBanner: false, // Debug yazisini gizle

      // ---- TURKCE LOKALIZASYON ----
      // 📚 DERS: DatePicker, TimePicker gibi Material widget'lari
      // dil dosyalarina ihtiyac duyar. Turkce tarih secici icin
      // flutter_localizations paketi ve locale ayari gerekir.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'), // Turkce
        Locale('en', 'US'), // Ingilizce (yedek)
      ],
      locale: const Locale('tr', 'TR'),

      // ---- TEMA AYARLARI ----
      // 📚 DERS: ThemeData = Tum uygulamanin gorunus ayarlari
      // Renkleri bir kez burada tanimla, her yerde kullan
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0), // Koyu mavi (ISG rengi)
          brightness: Brightness.light,
        ),
        useMaterial3: true, // Material Design 3 (en yeni tasarim sistemi)
      ),

      // ---- BASLANGIC SAYFASI ----
      // 📚 DERS: Uygulama acildiginda ilk gosterilecek sayfa
      // Onceden AnaSayfa idi, simdi LoginScreen
      home: const LoginScreen(),
    );
  }
}
