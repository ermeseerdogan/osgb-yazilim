// =============================================
// ISYERI EKLEME / DUZENLEME FORMU
// OrtakForm widget'ini kullaniyor
// =============================================
//
// 📚 DERS: Firma formunun aynisi, isyeri alanlari ile.
// Farklar:
// - Firma secimi (dropdown) zorunlu
// - Tehlike sinifi secimi (dropdown)
// - NACE kodu ve aciklama alanlari
// - Isveren bilgileri
// - Mali musavir bilgileri
// - Konum bilgileri

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/api_service.dart';
import '../widgets/ortak_form.dart';

class IsyeriFormScreen extends StatefulWidget {
  final Map<String, dynamic>? isyeri;

  const IsyeriFormScreen({super.key, this.isyeri});

  bool get duzenleModu => isyeri != null;

  @override
  State<IsyeriFormScreen> createState() => _IsyeriFormScreenState();
}

class _IsyeriFormScreenState extends State<IsyeriFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  bool _kaydediliyor = false;

  // Firma listesi (dropdown icin)
  List<Map<String, dynamic>> _firmalar = [];
  int? _seciliFirmaId;

  // Tehlike sinifi dropdown
  String _tehlikeSinifi = 'tehlikeli';

  // Form alanlari
  late final TextEditingController _adController;
  late final TextEditingController _sgkSicilNoController;
  late final TextEditingController _naceKoduController;
  late final TextEditingController _naceAciklamaController;
  late final TextEditingController _anaFaaliyetController;

  // Isveren
  late final TextEditingController _isverenAdController;
  late final TextEditingController _isverenSoyadController;
  late final TextEditingController _isverenVekiliAdController;
  late final TextEditingController _isverenVekiliSoyadController;

  // Hizmet
  late final TextEditingController _ucretlendirmeController;

  // Mali musavir
  late final TextEditingController _maliMusavirAdController;
  late final TextEditingController _maliMusavirSoyadController;
  late final TextEditingController _maliMusavirTelefonController;
  late final TextEditingController _maliMusavirEmailController;

  // Konum
  late final TextEditingController _lokasyonController;
  late final TextEditingController _koordinatLatController;
  late final TextEditingController _koordinatLngController;

  // Hizmet baslama tarihi
  DateTime? _hizmetBaslama;

  @override
  void initState() {
    super.initState();
    final iy = widget.isyeri;

    _seciliFirmaId = iy?['firma_id'];
    _tehlikeSinifi = iy?['tehlike_sinifi'] ?? 'tehlikeli';

    _adController = TextEditingController(text: iy?['ad'] ?? '');
    _sgkSicilNoController = TextEditingController(text: iy?['sgk_sicil_no'] ?? '');
    _naceKoduController = TextEditingController(text: iy?['nace_kodu'] ?? '');
    _naceAciklamaController = TextEditingController(text: iy?['nace_aciklama'] ?? '');
    _anaFaaliyetController = TextEditingController(text: iy?['ana_faaliyet'] ?? '');

    _isverenAdController = TextEditingController(text: iy?['isveren_ad'] ?? '');
    _isverenSoyadController = TextEditingController(text: iy?['isveren_soyad'] ?? '');
    _isverenVekiliAdController = TextEditingController(text: iy?['isveren_vekili_ad'] ?? '');
    _isverenVekiliSoyadController = TextEditingController(text: iy?['isveren_vekili_soyad'] ?? '');

    _ucretlendirmeController = TextEditingController(
      text: iy?['ucretlendirme'] != null ? iy!['ucretlendirme'].toString() : '',
    );

    _maliMusavirAdController = TextEditingController(text: iy?['mali_musavir_ad'] ?? '');
    _maliMusavirSoyadController = TextEditingController(text: iy?['mali_musavir_soyad'] ?? '');
    _maliMusavirTelefonController = TextEditingController(text: iy?['mali_musavir_telefon'] ?? '');
    _maliMusavirEmailController = TextEditingController(text: iy?['mali_musavir_email'] ?? '');

    _lokasyonController = TextEditingController(text: iy?['lokasyon'] ?? '');
    _koordinatLatController = TextEditingController(
      text: iy?['koordinat_lat'] != null ? iy!['koordinat_lat'].toString() : '',
    );
    _koordinatLngController = TextEditingController(
      text: iy?['koordinat_lng'] != null ? iy!['koordinat_lng'].toString() : '',
    );

    // Hizmet baslama tarihini parse et
    if (iy?['hizmet_baslama'] != null) {
      try {
        _hizmetBaslama = DateTime.parse(iy!['hizmet_baslama']);
      } catch (_) {}
    }

    // Firma listesini yukle
    _firmalariYukle();
  }

  Future<void> _firmalariYukle() async {
    try {
      final firmalar = await _apiService.firmaListesiGetir();
      setState(() {
        _firmalar = firmalar;
      });
    } catch (e) {
      // Hata olursa bos birakilir
    }
  }

  @override
  void dispose() {
    _adController.dispose();
    _sgkSicilNoController.dispose();
    _naceKoduController.dispose();
    _naceAciklamaController.dispose();
    _anaFaaliyetController.dispose();
    _isverenAdController.dispose();
    _isverenSoyadController.dispose();
    _isverenVekiliAdController.dispose();
    _isverenVekiliSoyadController.dispose();
    _ucretlendirmeController.dispose();
    _maliMusavirAdController.dispose();
    _maliMusavirSoyadController.dispose();
    _maliMusavirTelefonController.dispose();
    _maliMusavirEmailController.dispose();
    _lokasyonController.dispose();
    _koordinatLatController.dispose();
    _koordinatLngController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _formVerisi() {
    return {
      'firma_id': _seciliFirmaId,
      'ad': _adController.text.trim(),
      'sgk_sicil_no': _sgkSicilNoController.text.trim(),
      'nace_kodu': _naceKoduController.text.trim(),
      'nace_aciklama': _naceAciklamaController.text.trim().isNotEmpty ? _naceAciklamaController.text.trim() : null,
      'tehlike_sinifi': _tehlikeSinifi,
      'ana_faaliyet': _anaFaaliyetController.text.trim().isNotEmpty ? _anaFaaliyetController.text.trim() : null,
      'isveren_ad': _isverenAdController.text.trim(),
      'isveren_soyad': _isverenSoyadController.text.trim(),
      'isveren_vekili_ad': _isverenVekiliAdController.text.trim().isNotEmpty ? _isverenVekiliAdController.text.trim() : null,
      'isveren_vekili_soyad': _isverenVekiliSoyadController.text.trim().isNotEmpty ? _isverenVekiliSoyadController.text.trim() : null,
      'hizmet_baslama': _hizmetBaslama != null
          ? '${_hizmetBaslama!.year}-${_hizmetBaslama!.month.toString().padLeft(2, '0')}-${_hizmetBaslama!.day.toString().padLeft(2, '0')}'
          : null,
      'ucretlendirme': _ucretlendirmeController.text.trim().isNotEmpty
          ? double.tryParse(_ucretlendirmeController.text.trim())
          : null,
      'mali_musavir_ad': _maliMusavirAdController.text.trim().isNotEmpty ? _maliMusavirAdController.text.trim() : null,
      'mali_musavir_soyad': _maliMusavirSoyadController.text.trim().isNotEmpty ? _maliMusavirSoyadController.text.trim() : null,
      'mali_musavir_telefon': _maliMusavirTelefonController.text.trim().isNotEmpty ? _maliMusavirTelefonController.text.trim() : null,
      'mali_musavir_email': _maliMusavirEmailController.text.trim().isNotEmpty ? _maliMusavirEmailController.text.trim() : null,
      'lokasyon': _lokasyonController.text.trim().isNotEmpty ? _lokasyonController.text.trim() : null,
      'koordinat_lat': _koordinatLatController.text.trim().isNotEmpty
          ? double.tryParse(_koordinatLatController.text.trim())
          : null,
      'koordinat_lng': _koordinatLngController.text.trim().isNotEmpty
          ? double.tryParse(_koordinatLngController.text.trim())
          : null,
    };
  }

  // Kaydet ve geri don
  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;
    if (_seciliFirmaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lutfen bir firma secin'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _kaydediliyor = true);

    try {
      final data = _formVerisi();
      if (widget.duzenleModu) {
        await _apiService.isyeriGuncelle(widget.isyeri!['id'], data);
      } else {
        await _apiService.isyeriEkle(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.duzenleModu ? 'Isyeri guncellendi' : 'Isyeri eklendi'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _kaydediliyor = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Kaydet ve formu temizle
  Future<void> _kaydetVeYeni() async {
    if (!_formKey.currentState!.validate()) return;
    if (_seciliFirmaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lutfen bir firma secin'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _kaydediliyor = true);

    try {
      final data = _formVerisi();
      await _apiService.isyeriEkle(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isyeri eklendi. Yeni kayit girebilirsiniz.'), backgroundColor: Colors.green),
        );
        // Formu temizle (firma secimi kalsin)
        _adController.clear();
        _sgkSicilNoController.clear();
        _naceKoduController.clear();
        _naceAciklamaController.clear();
        _anaFaaliyetController.clear();
        _isverenAdController.clear();
        _isverenSoyadController.clear();
        _isverenVekiliAdController.clear();
        _isverenVekiliSoyadController.clear();
        _ucretlendirmeController.clear();
        _maliMusavirAdController.clear();
        _maliMusavirSoyadController.clear();
        _maliMusavirTelefonController.clear();
        _maliMusavirEmailController.clear();
        _lokasyonController.clear();
        _koordinatLatController.clear();
        _koordinatLngController.clear();
        setState(() {
          _kaydediliyor = false;
          _hizmetBaslama = null;
        });
      }
    } catch (e) {
      setState(() => _kaydediliyor = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Tarih secici
  Future<void> _tarihSec() async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: _hizmetBaslama ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr', 'TR'),
    );
    if (secilen != null) {
      setState(() => _hizmetBaslama = secilen);
    }
  }

  // =============================================
  // KOORDINAT BUL (Geocoding)
  // 📚 DERS: Adresten enlem/boylam bulmak icin Nominatim API kullaniyoruz.
  // Nominatim = OpenStreetMap'in ucretsiz geocoding servisi.
  // Kayit/API key gerektirmez, sadece User-Agent gerekir.
  // Ileride mobilde GPS ile de konum alinabilir.
  // =============================================
  bool _koordinatAraniyor = false;

  // 📚 DERS: Nominatim API ile adres arama
  // Tek bir Dio instance kullaniyoruz, her seferinde yeni olusturmaya gerek yok
  final _geoDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'OSGB-Yazilim/1.0', // Nominatim zorunlu tutuyor
        'Accept-Language': 'tr', // Sonuclari Turkce iste
      },
    ),
  );

  // 📚 DERS: Adresi Nominatim'in anlayabilecegi formata sadeleştir
  // "Merkez Mah. Öksüz Sok. No :10 Yenibosna Bahçelievler İstanbul"
  // gibi detayli adresleri Nominatim bulamayabilir.
  // Strateji: Once tam adresle ara, bulamazsa basitlestirip tekrar dene.
  List<String> _adresVariasyonlari(String adres) {
    final variasyonlar = <String>[adres]; // 1) Tam adres

    // 📚 DERS: Regex ile sokak no, mah., sok. gibi kisaltmalari temizle
    // Boylece "Yenibosna Bahçelievler İstanbul" gibi daha genel arama yapilir
    String basit = adres;

    // "No :10", "No:10", "No: 10", "No.10" gibi kaliplari kaldir
    basit = basit.replaceAll(RegExp(r'No\s*[.:]\s*\d+[/\-]?\d*', caseSensitive: false), '');

    // "Mah." veya "Mahallesi" oncesindeki kelimeyi birak ama kisaltmayi kaldir
    basit = basit.replaceAll(RegExp(r'\bMah\.?\b', caseSensitive: false), '');
    basit = basit.replaceAll(RegExp(r'\bMahallesi\b', caseSensitive: false), '');

    // "Sok." veya "Sokak/Sokağı" ve oncesindeki kelimeyi komple kaldir
    basit = basit.replaceAll(RegExp(r'\S+\s+(Sok\.?|Sokak|Sokağı)\b', caseSensitive: false), '');
    // Kalan "Sok." kaliplarini da temizle
    basit = basit.replaceAll(RegExp(r'\b(Sok\.?|Sokak|Sokağı)\b', caseSensitive: false), '');

    // "Cad." veya "Cadde/Caddesi" oncesindeki kelimeyi kaldir
    basit = basit.replaceAll(RegExp(r'\S+\s+(Cad\.?|Cadde|Caddesi)\b', caseSensitive: false), '');
    basit = basit.replaceAll(RegExp(r'\b(Cad\.?|Cadde|Caddesi)\b', caseSensitive: false), '');

    // "Blok", "Kat", "Daire" gibi bina detaylarini kaldir
    basit = basit.replaceAll(RegExp(r'\b(Blok|Kat|Daire|D\.?|K\.?)\s*[:\s]?\d*\b', caseSensitive: false), '');

    // Fazla bosluklari temizle
    basit = basit.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (basit != adres && basit.isNotEmpty) {
      variasyonlar.add(basit); // 2) Basitlestirilmis adres
    }

    // 3) Sadece semt/ilce/il bilgisi: son 2-3 kelime genelde ilce+sehir
    final kelimeler = basit.split(' ').where((k) => k.length > 2).toList();
    if (kelimeler.length > 2) {
      // Son 3 kelimeyi al (genelde semt ilce il)
      final sonKisim = kelimeler.sublist(kelimeler.length > 3 ? kelimeler.length - 3 : 0).join(' ');
      if (!variasyonlar.contains(sonKisim)) {
        variasyonlar.add(sonKisim); // 3) Semt + Ilce + Sehir
      }
    }

    return variasyonlar;
  }

  Future<List> _nominatimAra(String sorgu) async {
    final response = await _geoDio.get(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        'q': sorgu,
        'format': 'json',
        'limit': '5',
        'countrycodes': 'tr', // Sadece Turkiye sonuclari
        'addressdetails': '1', // Adres detaylarini da getir
      },
    );
    return response.data as List;
  }

  Future<void> _koordinatBul() async {
    final adres = _lokasyonController.text.trim();
    if (adres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oncelik adres/lokasyon alanini doldurun'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _koordinatAraniyor = true);

    try {
      // 📚 DERS: Kademeli arama stratejisi
      // 1) Tam adresle ara
      // 2) Bulamazsa basitlestirilmis adresle ara
      // 3) Bulamazsa sadece semt+ilce+sehir ile ara
      // Bu sayede "Merkez Mah. Öksüz Sok. No:10 Yenibosna Bahçelievler İstanbul"
      // gibi detayli adresler de bulunabilir.
      final variasyonlar = _adresVariasyonlari(adres);
      List sonuclar = [];

      for (final sorgu in variasyonlar) {
        sonuclar = await _nominatimAra(sorgu);
        if (sonuclar.isNotEmpty) break; // Sonuc bulduysa dur
      }

      if (!mounted) return;

      if (sonuclar.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu adres icin koordinat bulunamadi. Farkli bir adres deneyin (ornek: Kadikoy, Istanbul)'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        setState(() => _koordinatAraniyor = false);
        return;
      }

      // Birden fazla sonuc varsa secim yaptir
      if (sonuclar.length == 1) {
        _koordinatSecildi(sonuclar[0]);
      } else {
        _koordinatSecDialog(sonuclar);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Koordinat aranirken hata: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _koordinatAraniyor = false);
  }

  void _koordinatSecildi(Map<String, dynamic> sonuc) {
    final lat = sonuc['lat']?.toString() ?? '';
    final lon = sonuc['lon']?.toString() ?? '';

    setState(() {
      _koordinatLatController.text = lat;
      _koordinatLngController.text = lon;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Koordinat bulundu: $lat, $lon'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _koordinatSecDialog(List sonuclar) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue),
            SizedBox(width: 8),
            Text('Konum Secin', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 300,
          child: ListView.builder(
            itemCount: sonuclar.length,
            itemBuilder: (ctx, i) {
              final s = sonuclar[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[50],
                  child: Text('${i + 1}', style: TextStyle(color: Colors.blue[800])),
                ),
                title: Text(
                  s['display_name'] ?? '',
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Lat: ${s['lat']}, Lon: ${s['lon']}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _koordinatSecildi(s);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Iptal'),
          ),
        ],
      ),
    );
  }

  // 📚 DERS: Google Maps'te koordinati goster
  // Web'de yeni sekmede acilir, ileride mobilde harita uygulamasi acilir
  void _haritadaGoster(String url) {
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return OrtakForm(
      formKey: _formKey,
      baslik: widget.duzenleModu ? 'Isyeri Duzenle' : 'Yeni Isyeri',
      duzenleModu: widget.duzenleModu,
      kaydediliyor: _kaydediliyor,
      onKaydet: _kaydet,
      onKaydetVeYeni: widget.duzenleModu ? null : _kaydetVeYeni,
      mevcutKayit: widget.isyeri,
      kayitTuru: 'Isyeri',
      children: [
        // ---- FIRMA SECIMI ----
        const FormBolumBaslik(baslik: 'Firma Secimi', ikon: Icons.business),
        const SizedBox(height: 8),

        // 📚 DERS: Dropdown - firma listesinden sec
        DropdownButtonFormField<int>(
          value: _seciliFirmaId,
          decoration: InputDecoration(
            labelText: 'Firma *',
            hintText: 'Firma secin',
            prefixIcon: const Icon(Icons.business),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          isExpanded: true,
          items: _firmalar.map((f) {
            return DropdownMenuItem<int>(
              value: f['id'] as int,
              child: Text(f['ad'] as String, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: widget.duzenleModu ? null : (value) {
            setState(() => _seciliFirmaId = value);
          },
          validator: (value) {
            if (value == null) return 'Firma secimi zorunlu';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // ---- TEMEL BILGILER ----
        const FormBolumBaslik(baslik: 'Temel Bilgiler', ikon: Icons.factory),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: FormTextAlani(
                controller: _adController,
                label: 'Isyeri Adi',
                hint: 'Merkez Fabrika',
                icon: Icons.factory,
                zorunlu: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FormTextAlani(
                controller: _sgkSicilNoController,
                label: 'SGK Sicil No',
                hint: '1234567',
                icon: Icons.badge,
                zorunlu: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormTextAlani(
                controller: _naceKoduController,
                label: 'NACE Kodu',
                hint: '251100',
                icon: Icons.code,
                zorunlu: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FormTextAlani(
                controller: _naceAciklamaController,
                label: 'NACE Aciklama',
                hint: 'Metal yapi imalati',
                icon: Icons.description,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tehlike sinifi dropdown
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _tehlikeSinifi,
                decoration: InputDecoration(
                  labelText: 'Tehlike Sinifi *',
                  prefixIcon: const Icon(Icons.warning_amber),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'az_tehlikeli', child: Text('Az Tehlikeli')),
                  DropdownMenuItem(value: 'tehlikeli', child: Text('Tehlikeli')),
                  DropdownMenuItem(value: 'cok_tehlikeli', child: Text('Cok Tehlikeli')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _tehlikeSinifi = value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FormTextAlani(
                controller: _anaFaaliyetController,
                label: 'Ana Faaliyet',
                hint: 'Metal uretim',
                icon: Icons.work,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ---- ISVEREN BILGILERI ----
        const FormBolumBaslik(baslik: 'Isveren Bilgileri', ikon: Icons.person),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormTextAlani(
                controller: _isverenAdController,
                label: 'Isveren Adi',
                hint: 'Ahmet',
                icon: Icons.person,
                zorunlu: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FormTextAlani(
                controller: _isverenSoyadController,
                label: 'Isveren Soyadi',
                hint: 'Yilmaz',
                icon: Icons.person_outline,
                zorunlu: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormTextAlani(
                controller: _isverenVekiliAdController,
                label: 'Isveren Vekili Adi',
                hint: 'Opsiyonel',
                icon: Icons.person_add,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FormTextAlani(
                controller: _isverenVekiliSoyadController,
                label: 'Isveren Vekili Soyadi',
                hint: 'Opsiyonel',
                icon: Icons.person_add_alt,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ---- HIZMET BILGILERI ----
        const FormBolumBaslik(baslik: 'Hizmet Bilgileri', ikon: Icons.handshake),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarih secici
            Expanded(
              child: InkWell(
                onTap: _tarihSec,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Hizmet Baslama Tarihi',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: Text(
                    _hizmetBaslama != null
                        ? '${_hizmetBaslama!.day.toString().padLeft(2, '0')}.${_hizmetBaslama!.month.toString().padLeft(2, '0')}.${_hizmetBaslama!.year}'
                        : 'Tarih secin',
                    style: TextStyle(
                      fontSize: 14,
                      color: _hizmetBaslama != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FormTextAlani(
                controller: _ucretlendirmeController,
                label: 'Aylik Ucret (TL)',
                hint: '5000',
                icon: Icons.attach_money,
                klavyeTipi: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ---- MALI MUSAVIR ----
        const FormBolumBaslik(baslik: 'Mali Musavir', ikon: Icons.account_balance),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormTextAlani(
                controller: _maliMusavirAdController,
                label: 'Ad',
                hint: 'Musavir adi',
                icon: Icons.person,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FormTextAlani(
                controller: _maliMusavirSoyadController,
                label: 'Soyad',
                hint: 'Musavir soyadi',
                icon: Icons.person_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormTextAlani(
                controller: _maliMusavirTelefonController,
                label: 'Telefon',
                hint: '0212 555 1234',
                icon: Icons.phone,
                klavyeTipi: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FormTextAlani(
                controller: _maliMusavirEmailController,
                label: 'Email',
                hint: 'musavir@email.com',
                icon: Icons.email,
                klavyeTipi: TextInputType.emailAddress,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ---- KONUM ----
        const FormBolumBaslik(baslik: 'Konum Bilgileri', ikon: Icons.location_on),
        const SizedBox(height: 8),

        // 📚 DERS: Adres alani + "Koordinat Bul" butonu
        // Kullanici adresi yazar, butona tiklar, Nominatim API'den
        // enlem/boylam otomatik bulunur ve alanlara yazilir.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormTextAlani(
                controller: _lokasyonController,
                label: 'Adres / Lokasyon',
                hint: 'Ornek: Kadikoy, Istanbul',
                icon: Icons.location_on,
                maxSatir: 2,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 150,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _koordinatAraniyor ? null : _koordinatBul,
                icon: _koordinatAraniyor
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search, size: 18),
                label: Text(
                  _koordinatAraniyor ? 'Araniyor...' : 'Koordinat Bul',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormTextAlani(
                controller: _koordinatLatController,
                label: 'Enlem (Lat)',
                hint: '41.0082',
                icon: Icons.my_location,
                klavyeTipi: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FormTextAlani(
                controller: _koordinatLngController,
                label: 'Boylam (Lng)',
                hint: '28.9784',
                icon: Icons.my_location,
                klavyeTipi: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            // Haritada goster butonu (koordinat varsa)
            SizedBox(
              width: 56,
              height: 56,
              child: IconButton(
                onPressed: () {
                  final lat = _koordinatLatController.text.trim();
                  final lng = _koordinatLngController.text.trim();
                  if (lat.isEmpty || lng.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Oncelik koordinatlari girin veya "Koordinat Bul" butonunu kullanin'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  // 📚 DERS: Google Maps linkiyle haritada goster
                  // Web'de yeni sekmede acilir
                  final url = 'https://www.google.com/maps?q=$lat,$lng';
                  // ignore: avoid_web_libraries_in_flutter
                  _haritadaGoster(url);
                },
                icon: Icon(Icons.map, color: Colors.green[700]),
                tooltip: 'Haritada Goster',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.green[200]!),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
