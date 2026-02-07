// =============================================
// DASHBOARD EKRANI
// Giris yapildiktan sonra gosterilen ana sayfa
// =============================================
//
// 📚 DERS: Bu sayfa basarili giris sonrasi gosterilir.
// Simdilik basit bir "Hosgeldin" mesaji gosteriyor.
// Ileride buraya KPI kartlari, grafikler,
// bildirimler ve hizli erisim menusu eklenecek.

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'firma_list_screen.dart';
import 'isyeri_list_screen.dart';
import 'log_screen.dart';

class DashboardScreen extends StatelessWidget {
  // 📚 DERS: Constructor parametresi
  // Login ekranindan gelen kullanici bilgileri
  final Map<String, dynamic> kullaniciBilgi;

  const DashboardScreen({super.key, required this.kullaniciBilgi});

  @override
  Widget build(BuildContext context) {
    // Kullanici bilgilerini cikart
    final ad = kullaniciBilgi['ad'] ?? '';
    final soyad = kullaniciBilgi['soyad'] ?? '';
    final rol = kullaniciBilgi['rol'] ?? '';
    final email = kullaniciBilgi['email'] ?? '';
    final tenantAd = kullaniciBilgi['tenant_ad'];

    // Rol'u okunabilir formata cevir
    String rolYazisi;
    IconData rolIkon;
    switch (rol) {
      case 'sistem_admin':
        rolYazisi = 'Sistem Yoneticisi';
        rolIkon = Icons.admin_panel_settings;
        break;
      case 'osgb_yoneticisi':
        rolYazisi = 'OSGB Yoneticisi';
        rolIkon = Icons.business;
        break;
      case 'isg_uzmani':
        rolYazisi = 'ISG Uzmani';
        rolIkon = Icons.engineering;
        break;
      case 'isyeri_hekimi':
        rolYazisi = 'Isyeri Hekimi';
        rolIkon = Icons.medical_services;
        break;
      default:
        rolYazisi = rol;
        rolIkon = Icons.person;
    }

    return Scaffold(
      // ---- UST BAR ----
      appBar: AppBar(
        title: const Text('OSGB Yonetim'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // Cikis butonu
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cikis Yap',
            onPressed: () {
              // 📚 DERS: showDialog = Acilan pencere (popup)
              // Kullanicidan onay iste
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cikis Yap'),
                  content: const Text('Oturumunuzu kapatmak istiyor musunuz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx), // Kapat
                      child: const Text('Iptal'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Token'i temizle
                        ApiService().cikisYap();
                        // Login ekranina don
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text('Cikis Yap'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),

      // ---- SOL MENU (Drawer) ----
      // 📚 DERS: Drawer = Hamburger menusu
      // Sol taraftan acilan menu paneli
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Kullanici bilgi paneli
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              accountName: Text('$ad $soyad'),
              accountEmail: Text(email),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(rolIkon, size: 32, color: Theme.of(context).colorScheme.primary),
              ),
            ),

            // Menu ogerleri
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: true, // Aktif sayfa
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Firmalar'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FirmaListScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_city),
              title: const Text('Isyerleri'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IsyeriListScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Calisanlar'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Calisan listesi sayfasina git
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Ziyaretler'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Ziyaret listesi sayfasina git
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Faturalar'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Fatura listesi sayfasina git
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Sistem Loglari'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LogScreen()),
                );
              },
            ),
          ],
        ),
      ),

      // ---- SAYFA ICERIGI ----
      // 📚 DERS: SingleChildScrollView = icerik ekrana sigmayinca
      // otomatik scroll eklenir. Column tek basina kullanilinca
      // icerik buyukse overflow (tasma) hatasi verir.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hosgeldin karti
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(30),
                      child: Icon(rolIkon, size: 30, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hosgeldin, $ad $soyad',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rolYazisi,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (tenantAd != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              tenantAd,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ---- HIZLI ERISIM KARTLARI ----
            Text(
              'Hizli Erisim',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // 📚 DERS: Wrap = Esnek grid
            // Kartlar ekran genisligine gore alt alta veya yan yana dizilir
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _hizliErisimKarti(
                  context,
                  Icons.business,
                  'Firmalar',
                  'Firma kayit ve yonetim',
                  Colors.blue,
                ),
                _hizliErisimKarti(
                  context,
                  Icons.location_city,
                  'Isyerleri',
                  'Isyeri kayit ve takip',
                  Colors.green,
                ),
                _hizliErisimKarti(
                  context,
                  Icons.people,
                  'Calisanlar',
                  'Calisan kayit ve bilgi',
                  Colors.orange,
                ),
                _hizliErisimKarti(
                  context,
                  Icons.calendar_today,
                  'Ziyaretler',
                  'Ziyaret planlama',
                  Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 48),

            // Alt bilgi
            Center(
              child: Text(
                'OSGB Yonetim Sistemi v0.1.0',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hizli erisim karti widget'i
  Widget _hizliErisimKarti(
    BuildContext context,
    IconData ikon,
    String baslik,
    String aciklama,
    Color renk,
  ) {
    return SizedBox(
      width: 180,
      child: Card(
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (baslik == 'Firmalar') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FirmaListScreen()),
              );
            } else if (baslik == 'Isyerleri') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IsyeriListScreen()),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$baslik modulu yakin zamanda eklenecek')),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(ikon, size: 36, color: renk),
                const SizedBox(height: 8),
                Text(
                  baslik,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  aciklama,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
