// =============================================
// LOGIN EKRANI
// Kullanici giris yapma ekrani
// =============================================
//
// 📚 DERS: Bu bir "screen" (ekran/sayfa).
// Flutter'da her sayfa bir Widget'tir.
// StatefulWidget kullaniyoruz cunku:
// - Kullanici bilgi girer (email, sifre)
// - Yukleniyor animasyonu gosterilir
// - Hata mesaji degisir
// Bunlarin hepsi "state" (durum) degisikligi.

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 📚 DERS: TextEditingController
  // TextField (metin kutusu) icindeki yaziyi kontrol eder.
  // Python'da tkinter kullansaydin Entry widget'ina benzer.
  final _emailController = TextEditingController();
  final _sifreController = TextEditingController();

  // Form dogrulama icin anahtar
  final _formKey = GlobalKey<FormState>();

  // Durum degiskenleri
  bool _yukleniyor = false;     // Giris islemi suruyor mu?
  bool _sifreGizli = true;      // Sifre gizli mi gosterilsin?
  String? _hataMesaji;           // Hata mesaji (varsa)

  // API servisi
  final _apiService = ApiService();

  // ---- GIRIS YAP BUTONU ----
  Future<void> _girisYap() async {
    // Form dogrulamasini kontrol et
    if (!_formKey.currentState!.validate()) return;

    // Yukleniyor goster
    setState(() {
      _yukleniyor = true;
      _hataMesaji = null;
    });

    try {
      // API'ye giris istegi gonder
      final sonuc = await _apiService.girisYap(
        _emailController.text.trim(),   // .trim() = bosluk temizle
        _sifreController.text,
      );

      // Basarili! Dashboard'a git
      if (mounted) {
        // 📚 DERS: Navigator = Sayfa gecisi
        // pushReplacement: Mevcut sayfayi yeni sayfayla DEGISTIR
        // (Geri tusuyla login'e donemesin diye)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              kullaniciBilgi: sonuc['kullanici'],
            ),
          ),
        );
      }
    } catch (e) {
      // Hata! Mesaji goster
      setState(() {
        _hataMesaji = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      // Her durumda yukleniyor'u kapat
      if (mounted) {
        setState(() => _yukleniyor = false);
      }
    }
  }

  @override
  void dispose() {
    // 📚 DERS: dispose = Temizlik
    // Sayfa kapandiginda controller'lari temizle
    // Bellek sizintisini onler (memory leak)
    _emailController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Arka plan rengi
      backgroundColor: const Color(0xFFF5F5F5),

      body: Center(
        child: SingleChildScrollView(
          // 📚 DERS: SingleChildScrollView
          // Ekran kucukse kaydirilabilir yapar
          // Klavye acildiginda form altta kalmaz
          padding: const EdgeInsets.all(24),

          child: ConstrainedBox(
            // Maksimum genislik sinirla (cok genis ekranlarda guzel gorunsun)
            constraints: const BoxConstraints(maxWidth: 420),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ---- LOGO ve BASLIK ----
                Icon(
                  Icons.security,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'OSGB Yonetim Sistemi',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Is Sagligi ve Guvenligi',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 40),

                // ---- GIRIS FORMU ----
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Baslik
                          Text(
                            'Giris Yap',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // ---- EMAIL ALANI ----
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            // 📚 DERS: decoration = TextField'in gorunumu
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'ornek@osgb.com',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            // 📚 DERS: validator = Dogrulama fonksiyonu
                            // Kullanici "Giris Yap" tusuna basinca calisir
                            // null donerse = gecerli, String donerse = hata mesaji
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Email gerekli';
                              }
                              if (!value.contains('@')) {
                                return 'Gecerli bir email girin';
                              }
                              return null; // Gecerli
                            },
                          ),
                          const SizedBox(height: 16),

                          // ---- SIFRE ALANI ----
                          TextFormField(
                            controller: _sifreController,
                            obscureText: _sifreGizli,
                            // 📚 DERS: obscureText = true ise sifre gizlenir (****)
                            decoration: InputDecoration(
                              labelText: 'Sifre',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              // Sifre goster/gizle butonu
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _sifreGizli
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() => _sifreGizli = !_sifreGizli);
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Sifre gerekli';
                              }
                              return null;
                            },
                            // Enter tusuna basinca giris yap
                            onFieldSubmitted: (_) => _girisYap(),
                          ),
                          const SizedBox(height: 8),

                          // ---- HATA MESAJI ----
                          if (_hataMesaji != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _hataMesaji!,
                                      style: TextStyle(color: Colors.red[700]),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 16),

                          // ---- GIRIS BUTONU ----
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _yukleniyor ? null : _girisYap,
                              // 📚 DERS: _yukleniyor ise buton devre disi
                              // Cift tiklama onlenir
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _yukleniyor
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Giris Yap',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ---- TEST BILGISI ----
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Test Giris Bilgileri',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _testBilgiSatir(
                          'Admin',
                          'admin@osgbyazilim.com',
                          'admin123',
                        ),
                        const Divider(height: 16),
                        _testBilgiSatir(
                          'OSGB',
                          'demo@osgbyazilim.com',
                          'demo123',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  'v0.1.0 | OSGB Yazilim',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Test bilgisi satiri widget'i
  Widget _testBilgiSatir(String rol, String email, String sifre) {
    return InkWell(
      // 📚 DERS: InkWell = Tiklanabilir alan
      // Kullanici tiklayinca email/sifre otomatik doldurulur
      onTap: () {
        _emailController.text = email;
        _sifreController.text = sifre;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              child: Text(
                rol,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '$email / $sifre',
                style: TextStyle(color: Colors.blue[600], fontSize: 12),
              ),
            ),
            Icon(Icons.touch_app, size: 16, color: Colors.blue[300]),
          ],
        ),
      ),
    );
  }
}
