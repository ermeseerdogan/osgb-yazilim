// =============================================
// PERSONEL EKLEME / DUZENLEME FORMU
// OSGB personeli: ISG Uzmani, Isyeri Hekimi, DSP
// =============================================
//
// Calisan formundan farklar:
// - Isyeri secimi yok (personel OSGB'nin kendi kadrosu)
// - Unvan secimi zorunlu (ISG Uzmani / Isyeri Hekimi / DSP)
// - Kosullu alanlar:
//   * uzmanlik_sinifi: Sadece ISG Uzmani icin (A/B/C sinifi)
//   * brans: Sadece Isyeri Hekimi icin
// - Mesleki bilgiler: uzmanlik_belgesi_no, diploma_no

import 'dart:typed_data';
import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/api_service.dart';
import '../widgets/ortak_form.dart';
import '../widgets/dokuman_tab.dart';

class PersonelFormScreen extends StatefulWidget {
  final Map<String, dynamic>? personel;

  const PersonelFormScreen({super.key, this.personel});

  bool get duzenleModu => personel != null;

  @override
  State<PersonelFormScreen> createState() => _PersonelFormScreenState();
}

class _PersonelFormScreenState extends State<PersonelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  bool _kaydediliyor = false;

  // Unvan secimi
  String? _seciliUnvan;

  // Uzmanlik sinifi (sadece ISG Uzmani)
  String? _uzmanlikSinifi;

  // Form alanlari
  late final TextEditingController _adController;
  late final TextEditingController _soyadController;
  late final TextEditingController _tcNoController;
  late final TextEditingController _telefonController;
  late final TextEditingController _emailController;
  late final TextEditingController _uzmanlikBelgeNoController;
  late final TextEditingController _diplomaNoController;
  late final TextEditingController _bransController;

  // Tarih
  DateTime? _iseBaslamaTarihi;

  // Profil fotografi
  bool _profilFotoVar = false;
  bool _fotoYukleniyor = false;
  String? _fotoUrl; // token'li URL

  @override
  void initState() {
    super.initState();
    final p = widget.personel;

    _seciliUnvan = p?['unvan'];
    _uzmanlikSinifi = p?['uzmanlik_sinifi'];

    _adController = TextEditingController(text: p?['ad'] ?? '');
    _soyadController = TextEditingController(text: p?['soyad'] ?? '');
    _tcNoController = TextEditingController(text: p?['tc_no'] ?? '');
    _telefonController = TextEditingController(text: p?['telefon'] ?? '');
    _emailController = TextEditingController(text: p?['email'] ?? '');
    _uzmanlikBelgeNoController = TextEditingController(text: p?['uzmanlik_belgesi_no'] ?? '');
    _diplomaNoController = TextEditingController(text: p?['diploma_no'] ?? '');
    _bransController = TextEditingController(text: p?['brans'] ?? '');

    // Profil foto durumu
    if (p?['profil_foto_url'] != null && (p!['profil_foto_url'] as String).isNotEmpty) {
      _profilFotoVar = true;
      final token = ApiService.tokenGetir();
      _fotoUrl = '${_apiService.personelProfilFotoUrl(p['id'])}?t=$token';
    }

    if (p?['ise_baslama_tarihi'] != null) {
      try {
        _iseBaslamaTarihi = DateTime.parse(p!['ise_baslama_tarihi']);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _tcNoController.dispose();
    _telefonController.dispose();
    _emailController.dispose();
    _uzmanlikBelgeNoController.dispose();
    _diplomaNoController.dispose();
    _bransController.dispose();
    super.dispose();
  }

  String? _tarihToString(DateTime? tarih) {
    if (tarih == null) return null;
    return '${tarih.year}-${tarih.month.toString().padLeft(2, '0')}-${tarih.day.toString().padLeft(2, '0')}';
  }

  String _tarihGosterim(DateTime? tarih) {
    if (tarih == null) return 'Tarih secin';
    return '${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}.${tarih.year}';
  }

  Map<String, dynamic> _formVerisi() {
    final data = <String, dynamic>{
      'ad': _adController.text.trim(),
      'soyad': _soyadController.text.trim(),
      'unvan': _seciliUnvan,
      'tc_no': _tcNoController.text.trim().isNotEmpty ? _tcNoController.text.trim() : null,
      'telefon': _telefonController.text.trim().isNotEmpty ? _telefonController.text.trim() : null,
      'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      'uzmanlik_belgesi_no': _uzmanlikBelgeNoController.text.trim().isNotEmpty ? _uzmanlikBelgeNoController.text.trim() : null,
      'diploma_no': _diplomaNoController.text.trim().isNotEmpty ? _diplomaNoController.text.trim() : null,
      'ise_baslama_tarihi': _tarihToString(_iseBaslamaTarihi),
    };

    // Kosullu alanlar
    if (_seciliUnvan == 'isg_uzmani') {
      data['uzmanlik_sinifi'] = _uzmanlikSinifi;
      data['brans'] = null;
    } else if (_seciliUnvan == 'isyeri_hekimi') {
      data['brans'] = _bransController.text.trim().isNotEmpty ? _bransController.text.trim() : null;
      data['uzmanlik_sinifi'] = null;
    } else {
      data['uzmanlik_sinifi'] = null;
      data['brans'] = null;
    }

    return data;
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;
    if (_seciliUnvan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lutfen bir unvan secin'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _kaydediliyor = true);

    try {
      final data = _formVerisi();
      if (widget.duzenleModu) {
        await _apiService.personelGuncelle(widget.personel!['id'], data);
      } else {
        await _apiService.personelEkle(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.duzenleModu ? 'Personel guncellendi' : 'Personel eklendi'),
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

  Future<void> _kaydetVeYeni() async {
    if (!_formKey.currentState!.validate()) return;
    if (_seciliUnvan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lutfen bir unvan secin'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _kaydediliyor = true);

    try {
      final data = _formVerisi();
      await _apiService.personelEkle(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personel eklendi. Yeni kayit girebilirsiniz.'), backgroundColor: Colors.green),
        );
        // Formu temizle (unvan kalsin)
        _adController.clear();
        _soyadController.clear();
        _tcNoController.clear();
        _telefonController.clear();
        _emailController.clear();
        _uzmanlikBelgeNoController.clear();
        _diplomaNoController.clear();
        _bransController.clear();
        setState(() {
          _kaydediliyor = false;
          _uzmanlikSinifi = null;
          _iseBaslamaTarihi = null;
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

  Future<void> _iseBaslamaTarihiSec() async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: _iseBaslamaTarihi ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr', 'TR'),
      helpText: 'Ise Baslama Tarihi',
    );
    if (secilen != null) {
      setState(() => _iseBaslamaTarihi = secilen);
    }
  }

  // =============================================
  // PROFIL FOTOGRAFI
  // =============================================

  Future<void> _fotoYukle() async {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();
    await uploadInput.onChange.first;
    if (uploadInput.files == null || uploadInput.files!.isEmpty) return;
    final file = uploadInput.files!.first;

    setState(() => _fotoYukleniyor = true);
    try {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final bytes = (reader.result as Uint8List).toList();
      await _apiService.personelProfilFotoYukle(widget.personel!['id'], bytes, file.name);

      // Foto URL'i guncelle (cache-busting icin timestamp ekle)
      final token = ApiService.tokenGetir();
      setState(() {
        _profilFotoVar = true;
        _fotoUrl = '${_apiService.personelProfilFotoUrl(widget.personel!['id'])}?t=$token&_=${DateTime.now().millisecondsSinceEpoch}';
        _fotoYukleniyor = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotograf yuklendi'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _fotoYukleniyor = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fotoSil() async {
    try {
      await _apiService.personelProfilFotoSil(widget.personel!['id']);
      setState(() {
        _profilFotoVar = false;
        _fotoUrl = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotograf kaldirildi'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _profilFotoWidget() {
    final ad = _adController.text.trim();
    final soyad = _soyadController.text.trim();
    final basHarfler = '${ad.isNotEmpty ? ad[0] : ''}${soyad.isNotEmpty ? soyad[0] : ''}'.toUpperCase();

    return Column(
      children: [
        // Avatar
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue[100],
              backgroundImage: (_profilFotoVar && _fotoUrl != null)
                  ? NetworkImage(_fotoUrl!)
                  : null,
              child: (!_profilFotoVar || _fotoUrl == null)
                  ? Text(basHarfler, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue[800]))
                  : null,
            ),
            if (_fotoYukleniyor)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Butonlar (sadece duzenleme modunda)
        if (widget.duzenleModu) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _fotoYukleniyor ? null : _fotoYukle,
                icon: Icon(_profilFotoVar ? Icons.refresh : Icons.camera_alt, size: 16),
                label: Text(
                  _profilFotoVar ? 'Degistir' : 'Fotograf Yukle',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (_profilFotoVar) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _fotoYukleniyor ? null : _fotoSil,
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('Kaldir', style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ],
            ],
          ),
        ] else ...[
          Text('Fotograf eklemek icin once kaydedin',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  // =============================================
  // FORM ICERIGI
  // =============================================
  List<Widget> _formIcerigi() {
    return [
      // ---- PROFIL FOTOGRAFI ----
      _profilFotoWidget(),

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
              hint: 'Mehmet',
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
        hint: 'mehmet@osgb.com',
        icon: Icons.email,
        klavyeTipi: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),

      // ---- UNVAN SECIMI ----
      const FormBolumBaslik(baslik: 'Unvan Secimi', ikon: Icons.badge),
      const SizedBox(height: 8),

      DropdownButtonFormField<String>(
        value: _seciliUnvan,
        decoration: InputDecoration(
          labelText: 'Unvan *',
          hintText: 'Unvan secin',
          prefixIcon: const Icon(Icons.badge),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        isExpanded: true,
        items: const [
          DropdownMenuItem(value: 'isg_uzmani', child: Text('ISG Uzmani')),
          DropdownMenuItem(value: 'isyeri_hekimi', child: Text('Isyeri Hekimi')),
          DropdownMenuItem(value: 'dsp', child: Text('DSP (Diger Saglik Personeli)')),
        ],
        onChanged: widget.duzenleModu ? null : (value) {
          setState(() {
            _seciliUnvan = value;
            // Unvan degisince kosullu alanlari temizle
            if (value != 'isg_uzmani') _uzmanlikSinifi = null;
            if (value != 'isyeri_hekimi') _bransController.clear();
          });
        },
        validator: (value) {
          if (value == null) return 'Unvan secimi zorunlu';
          return null;
        },
      ),

      // Unvan secildikten sonra bilgi goster
      if (_seciliUnvan != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _seciliUnvan == 'isg_uzmani'
                ? Colors.blue[50]
                : _seciliUnvan == 'isyeri_hekimi'
                    ? Colors.green[50]
                    : Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _seciliUnvan == 'isg_uzmani'
                    ? Icons.engineering
                    : _seciliUnvan == 'isyeri_hekimi'
                        ? Icons.medical_services
                        : Icons.health_and_safety,
                size: 18,
                color: _seciliUnvan == 'isg_uzmani'
                    ? Colors.blue
                    : _seciliUnvan == 'isyeri_hekimi'
                        ? Colors.green
                        : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _seciliUnvan == 'isg_uzmani'
                      ? 'ISG Uzmani secildi. Uzmanlik sinifi (A/B/C) belirleyebilirsiniz.'
                      : _seciliUnvan == 'isyeri_hekimi'
                          ? 'Isyeri Hekimi secildi. Brans bilgisini girebilirsiniz.'
                          : 'DSP secildi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _seciliUnvan == 'isg_uzmani'
                        ? Colors.blue[800]
                        : _seciliUnvan == 'isyeri_hekimi'
                            ? Colors.green[800]
                            : Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),

      // ---- MESLEKI BILGILER ----
      const FormBolumBaslik(baslik: 'Mesleki Bilgiler', ikon: Icons.school),
      const SizedBox(height: 8),

      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FormTextAlani(
              controller: _uzmanlikBelgeNoController,
              label: 'Uzmanlik Belgesi No',
              hint: 'ISG-12345',
              icon: Icons.verified,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FormTextAlani(
              controller: _diplomaNoController,
              label: 'Diploma No',
              hint: 'DIP-67890',
              icon: Icons.school,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),

      // Kosullu alan: Uzmanlik sinifi (sadece ISG Uzmani)
      if (_seciliUnvan == 'isg_uzmani') ...[
        DropdownButtonFormField<String>(
          value: _uzmanlikSinifi,
          decoration: InputDecoration(
            labelText: 'Uzmanlik Sinifi',
            prefixIcon: const Icon(Icons.grade),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: null, child: Text('Secin')),
            DropdownMenuItem(value: 'a_sinifi', child: Text('A Sinifi (Cok Tehlikeli)')),
            DropdownMenuItem(value: 'b_sinifi', child: Text('B Sinifi (Tehlikeli)')),
            DropdownMenuItem(value: 'c_sinifi', child: Text('C Sinifi (Az Tehlikeli)')),
          ],
          onChanged: (value) {
            setState(() => _uzmanlikSinifi = value);
          },
        ),
        const SizedBox(height: 8),
      ],

      // Kosullu alan: Brans (sadece Isyeri Hekimi)
      if (_seciliUnvan == 'isyeri_hekimi') ...[
        FormTextAlani(
          controller: _bransController,
          label: 'Brans',
          hint: 'Aile Hekimligi, Ic Hastaliklari...',
          icon: Icons.local_hospital,
        ),
        const SizedBox(height: 8),
      ],

      const SizedBox(height: 8),

      // ---- CALISMA BILGILERI ----
      const FormBolumBaslik(baslik: 'Calisma Bilgileri', ikon: Icons.work),
      const SizedBox(height: 8),

      InkWell(
        onTap: _iseBaslamaTarihiSec,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Ise Baslama Tarihi',
            prefixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: _iseBaslamaTarihi != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _iseBaslamaTarihi = null),
                  )
                : null,
          ),
          child: Text(
            _tarihGosterim(_iseBaslamaTarihi),
            style: TextStyle(
              fontSize: 14,
              color: _iseBaslamaTarihi != null ? Colors.black87 : Colors.grey,
            ),
          ),
        ),
      ),
    ];
  }

  // =============================================
  // BUILD
  // =============================================
  @override
  Widget build(BuildContext context) {
    // Yeni kayit modunda tab yok
    if (!widget.duzenleModu) {
      return OrtakForm(
        formKey: _formKey,
        baslik: 'Yeni Personel',
        duzenleModu: false,
        kaydediliyor: _kaydediliyor,
        onKaydet: _kaydet,
        onKaydetVeYeni: _kaydetVeYeni,
        mevcutKayit: null,
        kayitTuru: 'Personel',
        children: _formIcerigi(),
      );
    }

    // Duzenleme modunda 2 tab
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.personel!['ad']} ${widget.personel!['soyad']}'),
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
            // TAB 1: BILGILER
            SingleChildScrollView(
              child: OrtakForm(
                formKey: _formKey,
                baslik: '',
                baslikGoster: false,
                duzenleModu: true,
                kaydediliyor: _kaydediliyor,
                onKaydet: _kaydet,
                onKaydetVeYeni: null,
                mevcutKayit: widget.personel,
                kayitTuru: 'Personel',
                children: _formIcerigi(),
              ),
            ),

            // TAB 2: DOKUMANLAR
            SingleChildScrollView(
              child: DokumanTab(
                kaynakTipi: 'personel',
                kaynakId: widget.personel!['id'],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
