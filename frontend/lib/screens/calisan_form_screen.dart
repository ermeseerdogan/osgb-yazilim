// =============================================
// CALISAN EKLEME / DUZENLEME FORMU
// OrtakForm widget'ini kullaniyor
// =============================================
//
// 📚 DERS: Isyeri formunun aynisi, calisan alanlari ile.
// Farklar:
// - Isyeri secimi (dropdown) zorunlu
// - Tarih alanlari: dogum tarihi ve ise giris tarihi
// - Kan grubu secimi (dropdown)
// - TC No kontrolu
// - Dokumanlar tab'i (saglik raporu, egitim sertifikasi vb.)

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/ortak_form.dart';
import '../widgets/dokuman_tab.dart';

class CalisanFormScreen extends StatefulWidget {
  final Map<String, dynamic>? calisan;

  const CalisanFormScreen({super.key, this.calisan});

  bool get duzenleModu => calisan != null;

  @override
  State<CalisanFormScreen> createState() => _CalisanFormScreenState();
}

class _CalisanFormScreenState extends State<CalisanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  bool _kaydediliyor = false;

  // Isyeri listesi (dropdown icin)
  List<Map<String, dynamic>> _isyerleri = [];
  int? _seciliIsyeriId;

  // Kan grubu dropdown
  String? _kanGrubu;

  // Form alanlari
  late final TextEditingController _adController;
  late final TextEditingController _soyadController;
  late final TextEditingController _tcNoController;
  late final TextEditingController _telefonController;
  late final TextEditingController _emailController;
  late final TextEditingController _gorevController;
  late final TextEditingController _bolumController;

  // Tarih alanlari
  DateTime? _dogumTarihi;
  DateTime? _iseGirisTarihi;

  @override
  void initState() {
    super.initState();
    final c = widget.calisan;

    _seciliIsyeriId = c?['isyeri_id'];
    _kanGrubu = c?['kan_grubu'];

    _adController = TextEditingController(text: c?['ad'] ?? '');
    _soyadController = TextEditingController(text: c?['soyad'] ?? '');
    _tcNoController = TextEditingController(text: c?['tc_no'] ?? '');
    _telefonController = TextEditingController(text: c?['telefon'] ?? '');
    _emailController = TextEditingController(text: c?['email'] ?? '');
    _gorevController = TextEditingController(text: c?['gorev'] ?? '');
    _bolumController = TextEditingController(text: c?['bolum'] ?? '');

    // Tarihleri parse et
    if (c?['dogum_tarihi'] != null) {
      try {
        _dogumTarihi = DateTime.parse(c!['dogum_tarihi']);
      } catch (_) {}
    }
    if (c?['ise_giris_tarihi'] != null) {
      try {
        _iseGirisTarihi = DateTime.parse(c!['ise_giris_tarihi']);
      } catch (_) {}
    }

    // Isyeri listesini yukle
    _isyerleriYukle();
  }

  Future<void> _isyerleriYukle() async {
    try {
      final isyerleri = await _apiService.isyeriListesiGetir();
      setState(() {
        _isyerleri = isyerleri;
      });
    } catch (e) {
      // Hata olursa bos birakilir
    }
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _tcNoController.dispose();
    _telefonController.dispose();
    _emailController.dispose();
    _gorevController.dispose();
    _bolumController.dispose();
    super.dispose();
  }

  // 📚 DERS: Tarih -> API string formati (YYYY-MM-DD)
  String? _tarihToString(DateTime? tarih) {
    if (tarih == null) return null;
    return '${tarih.year}-${tarih.month.toString().padLeft(2, '0')}-${tarih.day.toString().padLeft(2, '0')}';
  }

  // 📚 DERS: Tarih -> gosterim formati (GG.AA.YYYY)
  String _tarihGosterim(DateTime? tarih) {
    if (tarih == null) return 'Tarih secin';
    return '${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}.${tarih.year}';
  }

  Map<String, dynamic> _formVerisi() {
    return {
      'isyeri_id': _seciliIsyeriId,
      'ad': _adController.text.trim(),
      'soyad': _soyadController.text.trim(),
      'tc_no': _tcNoController.text.trim().isNotEmpty ? _tcNoController.text.trim() : null,
      'telefon': _telefonController.text.trim().isNotEmpty ? _telefonController.text.trim() : null,
      'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      'dogum_tarihi': _tarihToString(_dogumTarihi),
      'ise_giris_tarihi': _tarihToString(_iseGirisTarihi),
      'gorev': _gorevController.text.trim().isNotEmpty ? _gorevController.text.trim() : null,
      'bolum': _bolumController.text.trim().isNotEmpty ? _bolumController.text.trim() : null,
      'kan_grubu': _kanGrubu,
    };
  }

  // Kaydet ve geri don
  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;
    if (_seciliIsyeriId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lutfen bir isyeri secin'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _kaydediliyor = true);

    try {
      final data = _formVerisi();
      if (widget.duzenleModu) {
        await _apiService.calisanGuncelle(widget.calisan!['id'], data);
      } else {
        await _apiService.calisanEkle(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.duzenleModu ? 'Calisan guncellendi' : 'Calisan eklendi'),
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
    if (_seciliIsyeriId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lutfen bir isyeri secin'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _kaydediliyor = true);

    try {
      final data = _formVerisi();
      await _apiService.calisanEkle(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calisan eklendi. Yeni kayit girebilirsiniz.'), backgroundColor: Colors.green),
        );
        // Formu temizle (isyeri secimi kalsin)
        _adController.clear();
        _soyadController.clear();
        _tcNoController.clear();
        _telefonController.clear();
        _emailController.clear();
        _gorevController.clear();
        _bolumController.clear();
        setState(() {
          _kaydediliyor = false;
          _kanGrubu = null;
          _dogumTarihi = null;
          _iseGirisTarihi = null;
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

  // 📚 DERS: Tarih secici (Turkce lokalizasyon ile)
  Future<void> _dogumTarihiSec() async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: _dogumTarihi ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
      helpText: 'Dogum Tarihi',
    );
    if (secilen != null) {
      setState(() => _dogumTarihi = secilen);
    }
  }

  Future<void> _iseGirisTarihiSec() async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: _iseGirisTarihi ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr', 'TR'),
      helpText: 'Ise Giris Tarihi',
    );
    if (secilen != null) {
      setState(() => _iseGirisTarihi = secilen);
    }
  }

  // =============================================
  // FORM ICERIGI
  // 📚 DERS: Bolumler halinde duzenlenmis form
  // 1. Isyeri Secimi
  // 2. Kisisel Bilgiler (ad, soyad, TC, telefon, email)
  // 3. Is Bilgileri (gorev, bolum, ise giris)
  // 4. Saglik Bilgileri (dogum tarihi, kan grubu)
  // =============================================
  List<Widget> _formIcerigi() {
    return [
      // ---- ISYERI SECIMI ----
      const FormBolumBaslik(baslik: 'Isyeri Secimi', ikon: Icons.factory),
      const SizedBox(height: 8),

      DropdownButtonFormField<int>(
        value: _seciliIsyeriId,
        decoration: InputDecoration(
          labelText: 'Isyeri *',
          hintText: 'Isyeri secin',
          prefixIcon: const Icon(Icons.factory),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        isExpanded: true,
        items: _isyerleri.map((iy) {
          return DropdownMenuItem<int>(
            value: iy['id'] as int,
            child: Text(iy['ad'] as String, style: const TextStyle(fontSize: 14)),
          );
        }).toList(),
        onChanged: widget.duzenleModu ? null : (value) {
          setState(() => _seciliIsyeriId = value);
        },
        validator: (value) {
          if (value == null) return 'Isyeri secimi zorunlu';
          return null;
        },
      ),
      const SizedBox(height: 16),

      // ---- KISISEL BILGILER ----
      const FormBolumBaslik(baslik: 'Kisisel Bilgiler', ikon: Icons.person),
      const SizedBox(height: 8),

      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FormTextAlani(
              controller: _adController,
              label: 'Ad',
              hint: 'Ahmet',
              icon: Icons.person,
              zorunlu: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FormTextAlani(
              controller: _soyadController,
              label: 'Soyad',
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
              controller: _tcNoController,
              label: 'TC Kimlik No',
              hint: '12345678901',
              icon: Icons.credit_card,
              klavyeTipi: TextInputType.number,
              maxUzunluk: 11,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FormTextAlani(
              controller: _telefonController,
              label: 'Telefon',
              hint: '0532 555 1234',
              icon: Icons.phone,
              klavyeTipi: TextInputType.phone,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),

      FormTextAlani(
        controller: _emailController,
        label: 'Email',
        hint: 'ahmet@firma.com',
        icon: Icons.email,
        klavyeTipi: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),

      // ---- IS BILGILERI ----
      const FormBolumBaslik(baslik: 'Is Bilgileri', ikon: Icons.work),
      const SizedBox(height: 8),

      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FormTextAlani(
              controller: _gorevController,
              label: 'Gorev / Pozisyon',
              hint: 'Operator',
              icon: Icons.work_outline,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FormTextAlani(
              controller: _bolumController,
              label: 'Bolum',
              hint: 'Uretim',
              icon: Icons.business,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),

      // Ise giris tarihi
      InkWell(
        onTap: _iseGirisTarihiSec,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Ise Giris Tarihi',
            prefixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: _iseGirisTarihi != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _iseGirisTarihi = null),
                  )
                : null,
          ),
          child: Text(
            _tarihGosterim(_iseGirisTarihi),
            style: TextStyle(
              fontSize: 14,
              color: _iseGirisTarihi != null ? Colors.black87 : Colors.grey,
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),

      // ---- SAGLIK BILGILERI ----
      const FormBolumBaslik(baslik: 'Saglik Bilgileri', ikon: Icons.favorite),
      const SizedBox(height: 8),

      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dogum tarihi
          Expanded(
            child: InkWell(
              onTap: _dogumTarihiSec,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Dogum Tarihi',
                  prefixIcon: const Icon(Icons.cake),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: _dogumTarihi != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _dogumTarihi = null),
                        )
                      : null,
                ),
                child: Text(
                  _tarihGosterim(_dogumTarihi),
                  style: TextStyle(
                    fontSize: 14,
                    color: _dogumTarihi != null ? Colors.black87 : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 📚 DERS: Kan grubu dropdown
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _kanGrubu,
              decoration: InputDecoration(
                labelText: 'Kan Grubu',
                prefixIcon: const Icon(Icons.bloodtype),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Secin')),
                DropdownMenuItem(value: 'A+', child: Text('A Rh+')),
                DropdownMenuItem(value: 'A-', child: Text('A Rh-')),
                DropdownMenuItem(value: 'B+', child: Text('B Rh+')),
                DropdownMenuItem(value: 'B-', child: Text('B Rh-')),
                DropdownMenuItem(value: 'AB+', child: Text('AB Rh+')),
                DropdownMenuItem(value: 'AB-', child: Text('AB Rh-')),
                DropdownMenuItem(value: '0+', child: Text('0 Rh+')),
                DropdownMenuItem(value: '0-', child: Text('0 Rh-')),
              ],
              onChanged: (value) {
                setState(() => _kanGrubu = value);
              },
            ),
          ),
        ],
      ),
    ];
  }

  // =============================================
  // BUILD METODU
  // 📚 DERS: Duzenleme modunda TabBar ile 2 tab:
  // 1. Bilgiler = form alanlari
  // 2. Dokumanlar = saglik raporu, egitim sertifikasi vb.
  // Yeni kayit modunda sadece form gosterilir.
  // =============================================
  @override
  Widget build(BuildContext context) {
    // Yeni kayit modunda tab yok
    if (!widget.duzenleModu) {
      return OrtakForm(
        formKey: _formKey,
        baslik: 'Yeni Calisan',
        duzenleModu: false,
        kaydediliyor: _kaydediliyor,
        onKaydet: _kaydet,
        onKaydetVeYeni: _kaydetVeYeni,
        mevcutKayit: null,
        kayitTuru: 'Calisan',
        children: _formIcerigi(),
      );
    }

    // Duzenleme modunda 2 tab
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.calisan!['ad']} ${widget.calisan!['soyad']}'),
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
                mevcutKayit: widget.calisan,
                kayitTuru: 'Calisan',
                children: _formIcerigi(),
              ),
            ),

            // ---- TAB 2: DOKUMANLAR ----
            // 📚 DERS: kaynakTipi='calisan' olarak gonderiyoruz
            // Backend'de polimorfik dokuman sistemi bunu anlayip
            // calisan'a ait dokumanlari getirir.
            SingleChildScrollView(
              child: DokumanTab(
                kaynakTipi: 'calisan',
                kaynakId: widget.calisan!['id'],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
