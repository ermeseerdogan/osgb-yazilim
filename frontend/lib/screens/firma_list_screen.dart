// =============================================
// FIRMA LISTESI EKRANI
// Tum firmalari listeler, arama ve ekleme yapar
// =============================================
//
// 📚 DERS: Liste ekrani kaliplari
// 1. Veri yukle (API'den)
// 2. Liste goster (ListView)
// 3. Arama/filtreleme
// 4. Yeni kayit ekleme butonu (FloatingActionButton)
// 5. Tiklaninca detaya git

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'firma_form_screen.dart';

class FirmaListScreen extends StatefulWidget {
  const FirmaListScreen({super.key});

  @override
  State<FirmaListScreen> createState() => _FirmaListScreenState();
}

class _FirmaListScreenState extends State<FirmaListScreen> {
  final _apiService = ApiService();

  // Durum degiskenleri
  List<dynamic> _firmalar = [];
  int _toplam = 0;
  bool _yukleniyor = true;
  String? _hata;
  String _aramaMetni = '';

  // Arama kontrolcusu
  final _aramaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _firmalariYukle();
  }

  // API'den firmalari yukle
  Future<void> _firmalariYukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });

    try {
      final sonuc = await _apiService.firmaListele(
        arama: _aramaMetni.isNotEmpty ? _aramaMetni : null,
      );

      setState(() {
        _firmalar = sonuc['firmalar'] as List<dynamic>;
        _toplam = sonuc['toplam'] as int;
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() {
        _hata = e.toString().replaceAll('Exception: ', '');
        _yukleniyor = false;
      });
    }
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firmalar ($_toplam)'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),

      // ---- YENI FIRMA EKLEME BUTONU ----
      // 📚 DERS: FloatingActionButton (FAB)
      // Ekranin sag alt kosesinde yuvarlak buton
      // Material Design'da "ana eylem" icin kullanilir
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Firma ekleme ekranina git
          final eklendi = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const FirmaFormScreen(),
            ),
          );

          // Eklendi ise listeyi yenile
          if (eklendi == true) {
            _firmalariYukle();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Yeni Firma'),
      ),

      body: Column(
        children: [
          // ---- ARAMA ALANI ----
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _aramaController,
              decoration: InputDecoration(
                hintText: 'Firma ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                // Temizle butonu
                suffixIcon: _aramaMetni.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _aramaController.clear();
                          setState(() => _aramaMetni = '');
                          _firmalariYukle();
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _aramaMetni = value);
              },
              onSubmitted: (_) => _firmalariYukle(),
            ),
          ),

          // ---- ICERIK ----
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _hata != null
                    ? _hataWidget()
                    : _firmalar.isEmpty
                        ? _bosListeWidget()
                        : _firmaListesi(),
          ),
        ],
      ),
    );
  }

  // Firma listesi
  Widget _firmaListesi() {
    // 📚 DERS: RefreshIndicator
    // Asagi cekerek yenileme (pull-to-refresh)
    // Mobilde cok yaygin, web'de de calisir
    return RefreshIndicator(
      onRefresh: _firmalariYukle,
      child: ListView.builder(
        // 📚 DERS: ListView.builder
        // Sadece ekranda gorunen ogerleri olusturur (lazy loading)
        // 1000 firma olsa bile sadece ekrandaki 10-15 tane olusturulur
        // Performans icin onemli!
        itemCount: _firmalar.length,
        itemBuilder: (context, index) {
          final firma = _firmalar[index];
          final aktif = firma['aktif'] as bool;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              // Sol ikon
              leading: CircleAvatar(
                backgroundColor: aktif ? Colors.blue[100] : Colors.grey[200],
                child: Icon(
                  Icons.business,
                  color: aktif ? Colors.blue : Colors.grey,
                ),
              ),

              // Firma adi
              title: Text(
                firma['ad'] ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: aktif ? null : Colors.grey,
                  decoration: aktif ? null : TextDecoration.lineThrough,
                ),
              ),

              // Alt bilgi
              subtitle: Text(
                '${firma['il']} / ${firma['ilce']} - ${firma['telefon']}',
                style: TextStyle(
                  color: aktif ? Colors.grey[600] : Colors.grey,
                ),
              ),

              // Sag taraf: Duzenle butonu
              trailing: PopupMenuButton<String>(
                // 📚 DERS: PopupMenuButton
                // Tiklaninca acilan menu (3 nokta menusu)
                onSelected: (value) async {
                  if (value == 'duzenle') {
                    final guncellendi = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FirmaFormScreen(firma: firma),
                      ),
                    );
                    if (guncellendi == true) _firmalariYukle();
                  } else if (value == 'sil') {
                    _firmaSilOnay(firma);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'duzenle',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Duzenle'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sil',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Sil', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),

              onTap: () async {
                // Tiklaninca duzenleme ekranina git
                final guncellendi = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FirmaFormScreen(firma: firma),
                  ),
                );
                if (guncellendi == true) _firmalariYukle();
              },
            ),
          );
        },
      ),
    );
  }

  // Bos liste mesaji
  Widget _bosListeWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _aramaMetni.isNotEmpty
                ? '"$_aramaMetni" icin sonuc bulunamadi'
                : 'Henuz firma eklenmemis',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_aramaMetni.isEmpty)
            Text(
              'Sag alttaki + butonuyla yeni firma ekleyin',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
        ],
      ),
    );
  }

  // Hata mesaji
  Widget _hataWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_hata!, style: TextStyle(color: Colors.red[600])),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _firmalariYukle,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  // Firma silme onay dialog'u
  void _firmaSilOnay(Map<String, dynamic> firma) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Firma Sil'),
        content: Text("'${firma['ad']}' firmasini silmek istiyor musunuz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _apiService.firmaSil(firma['id']);
                _firmalariYukle();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("'${firma['ad']}' silindi")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hata: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
