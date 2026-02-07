// =============================================
// FIRMA EKLEME / DUZENLEME FORMU
// Yeni firma ekle veya mevcut firmayı duzenle
// =============================================
//
// 📚 DERS: Ayni ekran hem ekleme hem duzenleme icin kullanilir.
// firma parametresi null ise -> EKLEME modu
// firma parametresi dolu ise -> DUZENLEME modu
// Bu kaliba "reusable form" denir.

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FirmaFormScreen extends StatefulWidget {
  // 📚 DERS: Optional parametre
  // final Map? firma -> ? isareti "null olabilir" demek
  // Python'daki Optional[dict] = None gibi
  final Map<String, dynamic>? firma;

  const FirmaFormScreen({super.key, this.firma});

  // Duzenleme modu mu?
  bool get duzenleModu => firma != null;

  @override
  State<FirmaFormScreen> createState() => _FirmaFormScreenState();
}

class _FirmaFormScreenState extends State<FirmaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  bool _kaydediliyor = false;

  // Form alanlari icin controller'lar
  late final TextEditingController _adController;
  late final TextEditingController _kisaAdController;
  late final TextEditingController _ilController;
  late final TextEditingController _ilceController;
  late final TextEditingController _emailController;
  late final TextEditingController _telefonController;
  late final TextEditingController _adresController;
  late final TextEditingController _vergiDairesiController;
  late final TextEditingController _vergiNoController;

  @override
  void initState() {
    super.initState();
    // 📚 DERS: Duzenleme modundaysa mevcut degerlerle doldur
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
  }

  // Formu kaydet
  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _kaydediliyor = true);

    try {
      final data = {
        'ad': _adController.text.trim(),
        'kisa_ad': _kisaAdController.text.trim().isNotEmpty
            ? _kisaAdController.text.trim()
            : null,
        'il': _ilController.text.trim(),
        'ilce': _ilceController.text.trim(),
        'email': _emailController.text.trim(),
        'telefon': _telefonController.text.trim(),
        'adres': _adresController.text.trim().isNotEmpty
            ? _adresController.text.trim()
            : null,
        'vergi_dairesi': _vergiDairesiController.text.trim().isNotEmpty
            ? _vergiDairesiController.text.trim()
            : null,
        'vergi_no': _vergiNoController.text.trim().isNotEmpty
            ? _vergiNoController.text.trim()
            : null,
      };

      if (widget.duzenleModu) {
        await _apiService.firmaGuncelle(widget.firma!['id'], data);
      } else {
        await _apiService.firmaEkle(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.duzenleModu
                ? 'Firma guncellendi'
                : 'Firma eklendi'),
            backgroundColor: Colors.green,
          ),
        );
        // Onceki ekrana don ve basarili oldugunu bildir
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _kaydediliyor = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.duzenleModu ? 'Firma Duzenle' : 'Yeni Firma'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),

      // 📚 DERS: Center + ConstrainedBox ile formun max genisligini sinirla
      // Genis ekranlarda form 700px'den fazla yayilmaz
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- TEMEL BILGILER ----
                  _bolumBaslik('Temel Bilgiler'),
                  const SizedBox(height: 8),

                  // Firma adi + Kisa ad yan yana
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _textAlani(
                          controller: _adController,
                          label: 'Firma Adi *',
                          hint: 'ABC Insaat Ltd. Sti.',
                          icon: Icons.business,
                          zorunlu: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _textAlani(
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

                  // Il ve Ilce yan yana
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _textAlani(
                          controller: _ilController,
                          label: 'Il *',
                          hint: 'Istanbul',
                          icon: Icons.location_city,
                          zorunlu: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _textAlani(
                          controller: _ilceController,
                          label: 'Ilce *',
                          hint: 'Kadikoy',
                          icon: Icons.location_on,
                          zorunlu: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ---- ILETISIM BILGILERI ----
                  _bolumBaslik('Iletisim Bilgileri'),
                  const SizedBox(height: 8),

                  // Email + Telefon yan yana
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _textAlani(
                          controller: _emailController,
                          label: 'Email *',
                          hint: 'info@firma.com',
                          icon: Icons.email_outlined,
                          zorunlu: true,
                          emailAlani: true,
                          klavyeTipi: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _textAlani(
                          controller: _telefonController,
                          label: 'Telefon *',
                          hint: '0212 555 1234',
                          icon: Icons.phone_outlined,
                          zorunlu: true,
                          klavyeTipi: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _textAlani(
                    controller: _adresController,
                    label: 'Adres',
                    hint: 'Firma adresi',
                    icon: Icons.home_outlined,
                    maxSatir: 2,
                  ),
                  const SizedBox(height: 16),

                  // ---- VERGI BILGILERI ----
                  _bolumBaslik('Vergi Bilgileri'),
                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _textAlani(
                          controller: _vergiDairesiController,
                          label: 'Vergi Dairesi',
                          hint: 'Kadikoy VD',
                          icon: Icons.account_balance,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _textAlani(
                          controller: _vergiNoController,
                          label: 'Vergi No',
                          hint: '1234567890',
                          icon: Icons.numbers,
                          klavyeTipi: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ---- KAYDET BUTONU ----
                  SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: _kaydediliyor ? null : _kaydet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _kaydediliyor
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(widget.duzenleModu ? Icons.save : Icons.add, size: 18),
                      label: Text(
                        widget.duzenleModu ? 'Kaydet' : 'Firma Ekle',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- YARDIMCI WIDGET'LAR ----

  // Bolum basligi
  Widget _bolumBaslik(String baslik) {
    return Text(
      baslik,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  // Text alani (tekrar eden kodu azaltmak icin)
  // 📚 DERS: emailAlani parametresi true ise email validasyonu yapar
  Widget _textAlani({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool zorunlu = false,
    bool emailAlani = false,
    int? maxUzunluk,
    int maxSatir = 1,
    TextInputType? klavyeTipi,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxUzunluk,
      maxLines: maxSatir,
      keyboardType: klavyeTipi,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        counterText: '', // Karakter sayacini gizle
      ),
      validator: (value) {
        // Zorunlu alan kontrolu
        if (zorunlu && (value == null || value.trim().isEmpty)) {
          return '$label gerekli';
        }
        // 📚 DERS: Email format kontrolu
        // RegExp = Duzgun ifade (Regular Expression)
        // Basit email formati: abc@def.ghi
        if (emailAlani && value != null && value.trim().isNotEmpty) {
          final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
          if (!emailRegex.hasMatch(value.trim())) {
            return 'Gecerli bir email adresi girin (ornek: info@firma.com)';
          }
        }
        return null;
      },
    );
  }
}
