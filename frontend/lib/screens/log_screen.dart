// =============================================
// LOG EKRANI
// Sistem islem loglarini goruntuleme
// =============================================
//
// 📚 DERS: Bu ekran sadece yetkili kullanicilara aciktir.
// Kim ne zaman ne yapti? sorusunun cevabi burada.
//
// Logda gorunen islemler:
// - Giris/Cikis (basarili veya basarisiz)
// - Kayit ekleme (yeni firma, calisan vs.)
// - Kayit guncelleme (eski ve yeni degerler kayitli)
// - Kayit silme (pasife alma - veri silinmez!)
// - Yetki hatasi (izinsiz erisim denemeleri)

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final _apiService = ApiService();

  List<dynamic> _loglar = [];
  int _toplam = 0;
  Map<String, dynamic>? _ozet;
  bool _yukleniyor = true;
  String? _hata;

  // Filtreler
  String? _seciliModul;
  String? _seciliIslemTuru;
  bool? _seciliBasarili;
  int _seciliGun = 7;

  // 📚 DERS: Modul ve islem turu listeleri
  // Backend'deki enum degerleri ile eslesmeli
  final List<Map<String, String>> _moduller = [
    {'deger': 'auth', 'etiket': 'Giris/Cikis'},
    {'deger': 'firma', 'etiket': 'Firmalar'},
    {'deger': 'calisan', 'etiket': 'Calisanlar'},
    {'deger': 'isyeri', 'etiket': 'Isyerleri'},
    {'deger': 'ziyaret', 'etiket': 'Ziyaretler'},
  ];

  final List<Map<String, String>> _islemTurleri = [
    {'deger': 'giris', 'etiket': 'Giris Yapma'},
    {'deger': 'cikis', 'etiket': 'Cikis Yapma'},
    {'deger': 'giris_basarisiz', 'etiket': 'Basarisiz Giris'},
    {'deger': 'kayit_ekleme', 'etiket': 'Yeni Kayit'},
    {'deger': 'kayit_guncelleme', 'etiket': 'Kayit Duzenleme'},
    {'deger': 'kayit_silme', 'etiket': 'Kayit Silme'},
    {'deger': 'yetki_hatasi', 'etiket': 'Yetki Hatasi'},
  ];

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  Future<void> _verileriYukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });

    try {
      // Log listesi ve ozeti paralel yukle
      final sonuclar = await Future.wait([
        _apiService.logListele(
          modul: _seciliModul,
          islemTuru: _seciliIslemTuru,
          basarili: _seciliBasarili,
          sonGun: _seciliGun,
        ),
        _apiService.logOzet(sonGun: _seciliGun),
      ]);

      setState(() {
        final logSonuc = sonuclar[0] as Map<String, dynamic>;
        _loglar = logSonuc['loglar'] as List<dynamic>;
        _toplam = logSonuc['toplam'] as int;
        _ozet = sonuclar[1] as Map<String, dynamic>;
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() {
        _hata = e.toString().replaceAll('Exception: ', '');
        _yukleniyor = false;
      });
    }
  }

  // 📚 DERS: Islem turunu Turkce'ye cevir
  String _islemTuruTurkce(String islemTuru) {
    switch (islemTuru) {
      case 'giris':
        return 'Giris Yapti';
      case 'cikis':
        return 'Cikis Yapti';
      case 'giris_basarisiz':
        return 'Basarisiz Giris Denemesi';
      case 'kayit_ekleme':
        return 'Yeni Kayit Ekledi';
      case 'kayit_guncelleme':
        return 'Kayit Duzenledi';
      case 'kayit_silme':
        return 'Kayit Sildi';
      case 'yetki_hatasi':
        return 'Yetkisiz Erisim Denemesi';
      case 'sifre_degistirme':
        return 'Sifre Degistirdi';
      case 'sistem':
        return 'Sistem Islemi';
      default:
        return islemTuru;
    }
  }

  // 📚 DERS: Modul adini Turkce'ye cevir
  String _modulTurkce(String modul) {
    switch (modul) {
      case 'auth':
        return 'Giris/Cikis';
      case 'firma':
        return 'Firma';
      case 'calisan':
        return 'Calisan';
      case 'isyeri':
        return 'Isyeri';
      case 'ziyaret':
        return 'Ziyaret';
      case 'fatura':
        return 'Fatura';
      default:
        return modul;
    }
  }

  // 📚 DERS: Rolu Turkce'ye cevir
  String _rolTurkce(String? rol) {
    switch (rol) {
      case 'sistem_admin':
        return 'Sistem Yoneticisi';
      case 'osgb_yoneticisi':
        return 'OSGB Yoneticisi';
      case 'isg_uzmani':
        return 'ISG Uzmani';
      case 'isyeri_hekimi':
        return 'Isyeri Hekimi';
      default:
        return rol ?? 'Bilinmiyor';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sistem Loglari ($_toplam)'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // Filtreleri temizle butonu
          if (_seciliModul != null || _seciliIslemTuru != null || _seciliBasarili != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              onPressed: () {
                setState(() {
                  _seciliModul = null;
                  _seciliIslemTuru = null;
                  _seciliBasarili = null;
                });
                _verileriYukle();
              },
              tooltip: 'Filtreleri Temizle',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _verileriYukle,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- OZET KARTLARI ----
          if (_ozet != null) _ozetKartlari(),

          // ---- FILTRELER ----
          _filtreSatiri(),

          // ---- LOG LISTESI ----
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _hata != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                            const SizedBox(height: 8),
                            Text(_hata!, style: TextStyle(color: Colors.red[600])),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _verileriYukle,
                              child: const Text('Tekrar Dene'),
                            ),
                          ],
                        ),
                      )
                    : _loglar.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Bu filtrelere uygun log bulunamadi'),
                              ],
                            ),
                          )
                        : _logListesi(),
          ),
        ],
      ),
    );
  }

  // ---- OZET KARTLARI ----
  Widget _ozetKartlari() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[50],
      child: Row(
        children: [
          _ozetKarti('Toplam', _ozet!['toplam_islem'] ?? 0, Colors.blue, Icons.list),
          _ozetKarti('Basarili', _ozet!['basarili'] ?? 0, Colors.green, Icons.check_circle),
          _ozetKarti('Basarisiz', _ozet!['basarisiz'] ?? 0, Colors.red, Icons.cancel),
          _ozetKarti('Girisler', _ozet!['giris_sayisi'] ?? 0, Colors.purple, Icons.login),
        ],
      ),
    );
  }

  Widget _ozetKarti(String baslik, int deger, Color renk, IconData ikon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(ikon, color: renk, size: 24),
              const SizedBox(height: 4),
              Text(
                '$deger',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: renk,
                ),
              ),
              Text(baslik, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  // ---- FILTRE SATIRI ----
  // 📚 DERS: 4 filtre yan yana
  // Modul, Islem Turu, Durum, Sure
  Widget _filtreSatiri() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Modul filtresi
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _seciliModul,
              decoration: InputDecoration(
                labelText: 'Modul',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tumu')),
                ..._moduller.map((m) => DropdownMenuItem(
                      value: m['deger'],
                      child: Text(m['etiket']!, style: const TextStyle(fontSize: 13)),
                    )),
              ],
              onChanged: (v) {
                setState(() => _seciliModul = v);
                _verileriYukle();
              },
            ),
          ),
          const SizedBox(width: 6),

          // Islem turu filtresi
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _seciliIslemTuru,
              decoration: InputDecoration(
                labelText: 'Islem',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tumu')),
                ..._islemTurleri.map((t) => DropdownMenuItem(
                      value: t['deger'],
                      child: Text(t['etiket']!, style: const TextStyle(fontSize: 13)),
                    )),
              ],
              onChanged: (v) {
                setState(() => _seciliIslemTuru = v);
                _verileriYukle();
              },
            ),
          ),
          const SizedBox(width: 6),

          // Basari filtresi
          Expanded(
            child: DropdownButtonFormField<bool?>(
              value: _seciliBasarili,
              decoration: InputDecoration(
                labelText: 'Durum',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Tumu')),
                DropdownMenuItem(value: true, child: Text('Basarili')),
                DropdownMenuItem(value: false, child: Text('Basarisiz')),
              ],
              onChanged: (v) {
                setState(() => _seciliBasarili = v);
                _verileriYukle();
              },
            ),
          ),
          const SizedBox(width: 6),

          // Gun filtresi
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _seciliGun,
              decoration: InputDecoration(
                labelText: 'Sure',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Bugun')),
                DropdownMenuItem(value: 7, child: Text('7 gun')),
                DropdownMenuItem(value: 30, child: Text('30 gun')),
                DropdownMenuItem(value: 90, child: Text('3 ay')),
                DropdownMenuItem(value: 365, child: Text('1 yil')),
              ],
              onChanged: (v) {
                setState(() => _seciliGun = v ?? 7);
                _verileriYukle();
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- LOG LISTESI ----
  Widget _logListesi() {
    return RefreshIndicator(
      onRefresh: _verileriYukle,
      child: ListView.builder(
        itemCount: _loglar.length,
        itemBuilder: (context, index) {
          final log = _loglar[index];
          final basarili = log['basarili'] == true;
          final islemTuru = log['islem_turu'] ?? '';
          final tarih = log['tarih'] ?? '';
          final kullaniciAd = log['kullanici_ad'] ?? log['kullanici_email'] ?? 'Anonim';

          // Tarih formatlama
          String tarihStr = '';
          if (tarih.isNotEmpty) {
            try {
              final dt = DateTime.parse(tarih);
              tarihStr =
                  '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            } catch (_) {
              tarihStr = tarih;
            }
          }

          // 📚 DERS: Islem turune gore ikon, renk ve aciklama
          IconData ikon;
          Color renk;
          switch (islemTuru) {
            case 'giris':
              ikon = Icons.login;
              renk = Colors.green;
              break;
            case 'cikis':
              ikon = Icons.logout;
              renk = Colors.blueGrey;
              break;
            case 'giris_basarisiz':
              ikon = Icons.no_accounts;
              renk = Colors.red;
              break;
            case 'kayit_ekleme':
              ikon = Icons.add_circle;
              renk = Colors.blue;
              break;
            case 'kayit_guncelleme':
              ikon = Icons.edit;
              renk = Colors.orange;
              break;
            case 'kayit_silme':
              ikon = Icons.delete;
              renk = Colors.red;
              break;
            case 'yetki_hatasi':
              ikon = Icons.shield;
              renk = Colors.deepOrange;
              break;
            case 'sifre_degistirme':
              ikon = Icons.lock_reset;
              renk = Colors.purple;
              break;
            default:
              ikon = Icons.info;
              renk = Colors.grey;
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: ListTile(
              // Sol tarafta ikon
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: (basarili ? renk : Colors.red).withAlpha(25),
                child: Icon(ikon, size: 22, color: basarili ? renk : Colors.red),
              ),
              // Baslik: Kim ne yapti
              title: Text(
                '$kullaniciAd - ${_islemTuruTurkce(islemTuru)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Alt yazi: Aciklama + modul + tarih
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    log['aciklama'] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // Modul etiketi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _modulTurkce(log['modul'] ?? ''),
                          style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tarih
                      Text(
                        tarihStr,
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
              // Sag tarafta basarisiz isaret
              trailing: basarili
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        'BASARISIZ',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              isThreeLine: true,
              onTap: () => _logDetayGoster(log),
            ),
          );
        },
      ),
    );
  }

  // ---- LOG DETAY POPUP ----
  // 📚 DERS: Bir loga tiklandiginda tum detaylar gosterilir.
  // Kim, ne zaman, nereden, ne yapti - hepsi burada.
  void _logDetayGoster(Map<String, dynamic> log) {
    final islemTuru = log['islem_turu'] ?? '';
    final basarili = log['basarili'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              basarili ? Icons.check_circle : Icons.error,
              color: basarili ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _islemTuruTurkce(islemTuru),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Kullanici bilgileri
              _detayBaslik('Kullanici Bilgileri'),
              _detaySatir('Ad Soyad', log['kullanici_ad']),
              _detaySatir('Email', log['kullanici_email']),
              _detaySatir('Rol', _rolTurkce(log['kullanici_rol'])),

              const Divider(height: 20),

              // Islem bilgileri
              _detayBaslik('Islem Bilgileri'),
              _detaySatir('Islem', _islemTuruTurkce(islemTuru)),
              _detaySatir('Modul', _modulTurkce(log['modul'] ?? '')),
              _detaySatir('Aciklama', log['aciklama']),
              _detaySatir('Durum', basarili ? 'Basarili' : 'Basarisiz'),
              if (log['hata_mesaji'] != null)
                _detaySatir('Hata Mesaji', log['hata_mesaji']),
              if (log['kayit_turu'] != null)
                _detaySatir('Kayit Turu', log['kayit_turu']),
              if (log['kayit_id'] != null)
                _detaySatir('Kayit ID', log['kayit_id'].toString()),

              // Eski ve yeni degerler (guncelleme loglarinda)
              if (log['eski_deger'] != null) ...[
                const Divider(height: 20),
                _detayBaslik('Degisiklikler'),
                _degisiklikGoster(log['eski_deger'], log['yeni_deger']),
              ],
              if (log['yeni_deger'] != null && log['eski_deger'] == null) ...[
                const Divider(height: 20),
                _detayBaslik('Eklenen Veriler'),
                _yeniDegerGoster(log['yeni_deger']),
              ],

              const Divider(height: 20),

              // Teknik bilgiler
              _detayBaslik('Teknik Bilgiler'),
              _detaySatir('IP Adresi', log['ip_adresi']),
              _detaySatir('Istek', '${log['http_metod'] ?? ''} ${log['endpoint'] ?? ''}'),
              _detaySatir('Tarih', _tarihFormatla(log['tarih'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  // Baslik widget'i
  Widget _detayBaslik(String baslik) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        baslik,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // Satir widget'i
  Widget _detaySatir(String etiket, dynamic deger) {
    if (deger == null || deger.toString().trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$etiket:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(deger.toString(), style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // 📚 DERS: Degisiklik karsilastirmasi
  // Guncelleme loglarinda eski ve yeni degerleri yan yana goster
  // Boylece "kim neyi ne yapti" acikca gorunur
  Widget _degisiklikGoster(dynamic eskiDeger, dynamic yeniDeger) {
    if (eskiDeger is! Map || yeniDeger is! Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detaySatir('Onceki', eskiDeger?.toString()),
          _detaySatir('Sonraki', yeniDeger?.toString()),
        ],
      );
    }

    // Her degisen alani goster
    final alanlar = <String>{...eskiDeger.keys.cast<String>(), ...yeniDeger.keys.cast<String>()};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: alanlar.map((alan) {
        final eski = eskiDeger[alan];
        final yeni = yeniDeger[alan];
        // Sadece degisen alanlari goster
        if (eski == yeni) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alan.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              Row(
                children: [
                  // Eski deger (kirmizi)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${eski ?? '-'}',
                        style: TextStyle(fontSize: 11, color: Colors.red[700]),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                  ),
                  // Yeni deger (yesil)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${yeni ?? '-'}',
                        style: TextStyle(fontSize: 11, color: Colors.green[700]),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Yeni eklenen verileri goster
  Widget _yeniDegerGoster(dynamic yeniDeger) {
    if (yeniDeger is! Map) {
      return Text(yeniDeger.toString(), style: const TextStyle(fontSize: 12));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: yeniDeger.entries.map<Widget>((entry) {
        if (entry.value == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  '${entry.key}:',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${entry.value}',
                    style: TextStyle(fontSize: 11, color: Colors.green[700]),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Tarih formatlama
  String _tarihFormatla(String? tarih) {
    if (tarih == null || tarih.isEmpty) return '';
    try {
      final dt = DateTime.parse(tarih);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return tarih;
    }
  }
}
