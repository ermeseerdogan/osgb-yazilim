// =============================================
// FIRMA EKLEME / DUZENLEME FORMU
// Artik OrtakForm widget'ini kullaniyor
// =============================================
//
// 📚 DERS: Bu ekran OrtakForm'u kullanir
// OrtakForm saglar: max-width, Ctrl+S, degisiklik uyarisi, butonlar, bilgi satiri
// Bu dosya sadece firma'ya ozel alanlari tanimlar

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../services/api_service.dart';
import '../widgets/ortak_form.dart';
import '../widgets/dokuman_tab.dart';

class FirmaFormScreen extends StatefulWidget {
  final Map<String, dynamic>? firma;

  const FirmaFormScreen({super.key, this.firma});

  bool get duzenleModu => firma != null;

  @override
  State<FirmaFormScreen> createState() => _FirmaFormScreenState();
}

class _FirmaFormScreenState extends State<FirmaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  bool _kaydediliyor = false;

  // Logo state
  bool _logoVar = false;
  bool _logoYukleniyor = false;
  String? _logoUrl;

  // Form alanlari
  late final TextEditingController _adController;
  late final TextEditingController _kisaAdController;
  late final TextEditingController _ilController;
  late final TextEditingController _ilceController;
  late final TextEditingController _emailController;
  late final TextEditingController _telefonController;
  late final TextEditingController _adresController;
  late final TextEditingController _vergiDairesiController;
  late final TextEditingController _vergiNoController;
  late final TextEditingController _notController;

  @override
  void initState() {
    super.initState();
    final f = widget.firma;
    _adController = TextEditingController(text: f?['ad'] ?? '');
    _kisaAdController = TextEditingController(text: f?['kisa_ad'] ?? '');
    _ilController = TextEditingController(text: f?['il'] ?? '');
    _ilceController = TextEditingController(text: f?['ilce'] ?? '');
    _emailController = TextEditingController(text: f?['email'] ?? '');
    _telefonController = TextEditingController(text: f?['telefon'] ?? '');
    _adresController = TextEditingController(text: f?['adres'] ?? '');
    _vergiDairesiController = TextEditingController(text: f?['vergi_dairesi'] ?? '');
    _vergiNoController = TextEditingController(text: f?['vergi_no'] ?? '');
    _notController = TextEditingController(text: f?['not'] ?? '');

    // Logo durumunu kontrol et
    if (f != null) {
      final logoUrl = f['logo_url']?.toString() ?? '';
      _logoVar = logoUrl.isNotEmpty;
      if (_logoVar) {
        final token = ApiService.tokenGetir();
        _logoUrl = '${_apiService.firmaLogoUrl(f['id'])}?t=$token&_=${DateTime.now().millisecondsSinceEpoch}';
      }
    }
  }

  @override
  void dispose() {
    _adController.dispose();
    _kisaAdController.dispose();
    _ilController.dispose();
    _ilceController.dispose();
    _emailController.dispose();
    _telefonController.dispose();
    _adresController.dispose();
    _vergiDairesiController.dispose();
    _vergiNoController.dispose();
    _notController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _formVerisi() {
    return {
      'ad': _adController.text.trim(),
      'kisa_ad': _kisaAdController.text.trim().isNotEmpty ? _kisaAdController.text.trim() : null,
      'il': _ilController.text.trim(),
      'ilce': _ilceController.text.trim(),
      'email': _emailController.text.trim(),
      'telefon': _telefonController.text.trim(),
      'adres': _adresController.text.trim().isNotEmpty ? _adresController.text.trim() : null,
      'vergi_dairesi': _vergiDairesiController.text.trim().isNotEmpty ? _vergiDairesiController.text.trim() : null,
      'vergi_no': _vergiNoController.text.trim().isNotEmpty ? _vergiNoController.text.trim() : null,
      'not': _notController.text.trim().isNotEmpty ? _notController.text.trim() : null,
    };
  }

  // Kaydet ve geri don
  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _kaydediliyor = true);

    try {
      final data = _formVerisi();
      if (widget.duzenleModu) {
        await _apiService.firmaGuncelle(widget.firma!['id'], data);
      } else {
        await _apiService.firmaEkle(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.duzenleModu ? 'Firma guncellendi' : 'Firma eklendi'),
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

  // Kaydet ve formu temizle (yeni kayit icin)
  Future<void> _kaydetVeYeni() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _kaydediliyor = true);

    try {
      final data = _formVerisi();
      await _apiService.firmaEkle(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firma eklendi. Yeni kayit girebilirsiniz.'), backgroundColor: Colors.green),
        );
        // Formu temizle
        _adController.clear();
        _kisaAdController.clear();
        _ilController.clear();
        _ilceController.clear();
        _emailController.clear();
        _telefonController.clear();
        _adresController.clear();
        _vergiDairesiController.clear();
        _vergiNoController.clear();
        _notController.clear();
        setState(() => _kaydediliyor = false);
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

  // ---- LOGO ISLEMLERI ----
  Future<void> _logoYukle() async {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      final file = files[0];
      if (file.size > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dosya boyutu 5 MB\'i gecemez'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      setState(() => _logoYukleniyor = true);

      try {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;

        final bytes = (reader.result as Uint8List).toList();
        await _apiService.firmaLogoYukle(widget.firma!['id'], bytes, file.name);

        if (mounted) {
          final token = ApiService.tokenGetir();
          setState(() {
            _logoVar = true;
            _logoUrl = '${_apiService.firmaLogoUrl(widget.firma!['id'])}?t=$token&_=${DateTime.now().millisecondsSinceEpoch}';
            _logoYukleniyor = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo yuklendi'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _logoYukleniyor = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logo yuklenemedi: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
          );
        }
      }
    });
  }

  Future<void> _logoSil() async {
    setState(() => _logoYukleniyor = true);
    try {
      await _apiService.firmaLogoSil(widget.firma!['id']);
      if (mounted) {
        setState(() {
          _logoVar = false;
          _logoUrl = null;
          _logoYukleniyor = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo kaldirildi'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _logoYukleniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logo silinemedi: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _logoWidget() {
    final ad = _adController.text.isNotEmpty ? _adController.text : 'F';
    final basHarfler = ad.substring(0, ad.length >= 2 ? 2 : 1).toUpperCase();

    return Column(
      children: [
        const SizedBox(height: 8),
        _logoYukleniyor
            ? const CircleAvatar(radius: 45, child: CircularProgressIndicator())
            : _logoVar && _logoUrl != null
                ? CircleAvatar(
                    radius: 45,
                    backgroundImage: NetworkImage(_logoUrl!),
                    backgroundColor: Colors.grey[200],
                  )
                : CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.blue[100],
                    child: Text(basHarfler, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                  ),
        const SizedBox(height: 8),
        if (widget.duzenleModu) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _logoYukleniyor ? null : _logoYukle,
                icon: Icon(_logoVar ? Icons.edit : Icons.add_a_photo, size: 16),
                label: Text(_logoVar ? 'Degistir' : 'Logo Yukle', style: const TextStyle(fontSize: 12)),
              ),
              if (_logoVar) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _logoYukleniyor ? null : _logoSil,
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('Kaldir', style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  // 📚 DERS: Form icerigini metod olarak cikariyoruz
  // Tab yapısında ve normal modda ayni icerik kullanılır
  List<Widget> _formIcerigi() {
    return [
      // ---- LOGO ----
      _logoWidget(),

      // ---- TEMEL BILGILER ----
      const FormBolumBaslik(baslik: 'Temel Bilgiler', ikon: Icons.business),
      const SizedBox(height: 8),

      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: FormTextAlani(
              controller: _adController,
              label: 'Firma Adi',
              hint: 'ABC Insaat Ltd. Sti.',
              icon: Icons.business,
              zorunlu: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FormTextAlani(
              controller: _kisaAdController,
              label: 'Kisa Ad',
              hint: 'Max 16 kr.',
              icon: Icons.short_text,
              maxUzunluk: 16,
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
              controller: _ilController,
              label: 'Il',
              hint: 'Istanbul',
              icon: Icons.location_city,
              zorunlu: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FormTextAlani(
              controller: _ilceController,
              label: 'Ilce',
              hint: 'Kadikoy',
              icon: Icons.location_on,
              zorunlu: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // ---- ILETISIM BILGILERI ----
      const FormBolumBaslik(baslik: 'Iletisim Bilgileri', ikon: Icons.contact_phone),
      const SizedBox(height: 8),

      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FormTextAlani(
              controller: _emailController,
              label: 'Email',
              hint: 'info@firma.com',
              icon: Icons.email_outlined,
              zorunlu: true,
              emailAlani: true,
              klavyeTipi: TextInputType.emailAddress,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FormTextAlani(
              controller: _telefonController,
              label: 'Telefon',
              hint: '0212 555 1234',
              icon: Icons.phone_outlined,
              zorunlu: true,
              klavyeTipi: TextInputType.phone,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),

      FormTextAlani(
        controller: _adresController,
        label: 'Adres',
        hint: 'Firma adresi',
        icon: Icons.home_outlined,
        maxSatir: 2,
      ),
      const SizedBox(height: 16),

      // ---- VERGI BILGILERI ----
      const FormBolumBaslik(baslik: 'Vergi Bilgileri', ikon: Icons.account_balance),
      const SizedBox(height: 8),

      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FormTextAlani(
              controller: _vergiDairesiController,
              label: 'Vergi Dairesi',
              hint: 'Kadikoy VD',
              icon: Icons.account_balance,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FormTextAlani(
              controller: _vergiNoController,
              label: 'Vergi No',
              hint: '1234567890',
              icon: Icons.numbers,
              klavyeTipi: TextInputType.number,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // ---- NOTLAR ----
      FormNotAlani(controller: _notController),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // 📚 DERS: Yeni kayit modunda tab yok, direkt form goster
    if (!widget.duzenleModu) {
      return OrtakForm(
        formKey: _formKey,
        baslik: 'Yeni Firma',
        duzenleModu: false,
        kaydediliyor: _kaydediliyor,
        onKaydet: _kaydet,
        onKaydetVeYeni: _kaydetVeYeni,
        mevcutKayit: null,
        kayitTuru: 'Firma',
        children: _formIcerigi(),
      );
    }

    // 📚 DERS: Duzenleme modunda 2 tab: Bilgiler + Dokumanlar
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Firma Duzenle'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.edit_note), text: 'Bilgiler'),
              Tab(icon: Icon(Icons.attach_file), text: 'Dokumanlar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ---- TAB 1: BILGILER ----
            SingleChildScrollView(
              child: OrtakForm(
                formKey: _formKey,
                baslik: '',
                baslikGoster: false,
                duzenleModu: true,
                kaydediliyor: _kaydediliyor,
                onKaydet: _kaydet,
                onKaydetVeYeni: null,
                mevcutKayit: widget.firma,
                kayitTuru: 'Firma',
                children: _formIcerigi(),
              ),
            ),

            // ---- TAB 2: DOKUMANLAR ----
            SingleChildScrollView(
              child: DokumanTab(
                kaynakTipi: 'firma',
                kaynakId: widget.firma!['id'],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
