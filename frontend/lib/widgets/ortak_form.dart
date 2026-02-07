// =============================================
// ORTAK FORM WIDGET'LARI
// Tum form ekranlarinda kullanilacak standart bilesenler
// =============================================
//
// 📚 DERS: Bu dosya "Shared Widgets" kalibidir
// Her yeni form ekrani bu widget'lari kullanir
// Boylece tum formlar ayni gorunume ve davranisa sahip olur
//
// Icerik:
// 1. OrtakForm       -> Ana form iskeleti (scroll, max-width, kisayollar, degisiklik uyarisi)
// 2. FormBolumBaslik -> Bolum basligi (Temel Bilgiler, Iletisim vb.)
// 3. FormTextAlani   -> Standart text input (zorunlu, email, telefon vb.)
// 4. FormButonlari   -> Kaydet + Kaydet&Yeni + Iptal butonlari
// 5. FormBilgiSatiri -> Alt bilgi (olusturan, tarih)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =============================================
// 1. ORTAK FORM ISKELETI
// 📚 DERS: Tum formlari sarar, standart ozellikler saglar:
// - Max genislik siniri (700px)
// - Ctrl+S kisayolu
// - Degisiklik uyarisi (kaydedilmeden cikma)
// - Scroll + padding
// =============================================
class OrtakForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final String baslik;
  final bool duzenleModu;
  final bool kaydediliyor;
  final VoidCallback onKaydet;
  final VoidCallback? onKaydetVeYeni; // null ise buton gosterilmez
  final List<Widget> children;
  final Map<String, dynamic>? mevcutKayit; // Duzenleme modunda mevcut kayit bilgileri

  const OrtakForm({
    super.key,
    required this.formKey,
    required this.baslik,
    required this.duzenleModu,
    required this.kaydediliyor,
    required this.onKaydet,
    this.onKaydetVeYeni,
    required this.children,
    this.mevcutKayit,
  });

  @override
  State<OrtakForm> createState() => _OrtakFormState();
}

class _OrtakFormState extends State<OrtakForm> {
  // 📚 DERS: Form degisti mi takibi
  // Kullanici formu degistirip kaydetmeden ciktiginda uyari gosterilir
  bool _formDegisti = false;

  @override
  Widget build(BuildContext context) {
    // 📚 DERS: PopScope -> Geri tusu veya sayfa kapanmadan once kontrol
    // Eskiden WillPopScope idi, Flutter 3.16+ ile PopScope oldu
    return PopScope(
      canPop: !_formDegisti,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ciksinMi = await _cikisOnay(context);
        if (ciksinMi && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.baslik),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: _kisayolSarmalayici(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Form(
                  key: widget.formKey,
                  onChanged: () {
                    if (!_formDegisti) setState(() => _formDegisti = true);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Form alanlari
                      ...widget.children,

                      const SizedBox(height: 24),

                      // Butonlar
                      FormButonlari(
                        duzenleModu: widget.duzenleModu,
                        kaydediliyor: widget.kaydediliyor,
                        onKaydet: widget.onKaydet,
                        onKaydetVeYeni: widget.onKaydetVeYeni,
                      ),

                      // Kayit bilgisi (duzenleme modunda)
                      if (widget.duzenleModu && widget.mevcutKayit != null) ...[
                        const SizedBox(height: 16),
                        FormBilgiSatiri(kayit: widget.mevcutKayit!),
                      ],

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 📚 DERS: Ctrl+S kisayolu
  // KeyboardListener ile klavye olaylarini yakalar
  Widget _kisayolSarmalayici({required Widget child}) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyS &&
            HardwareKeyboard.instance.isControlPressed) {
          if (!widget.kaydediliyor) {
            widget.onKaydet();
          }
        }
      },
      child: child,
    );
  }

  // Kaydedilmeden cikis uyarisi
  Future<bool> _cikisOnay(BuildContext context) async {
    final sonuc = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Kaydedilmemis Degisiklikler', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text(
          'Formda kaydedilmemis degisiklikler var.\nKaydetmeden cikmak istiyor musunuz?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kaldir, Duzenlemeye Devam'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaydetmeden Cik', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return sonuc ?? false;
  }
}

// =============================================
// 2. FORM BOLUM BASLIGI
// 📚 DERS: Formu bolumlere ayirmak icin (Temel Bilgiler, Iletisim vb.)
// =============================================
class FormBolumBaslik extends StatelessWidget {
  final String baslik;
  final IconData? ikon;

  const FormBolumBaslik({super.key, required this.baslik, this.ikon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          if (ikon != null) ...[
            Icon(ikon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
          ],
          Text(
            baslik,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.primary.withAlpha(50)),
          ),
        ],
      ),
    );
  }
}

// =============================================
// 3. FORM TEXT ALANI
// 📚 DERS: Standart text input widget
// Zorunlu alanlar kirmizi yildiz (*) ile isaretlenir
// Email, telefon, sayisal vb. validasyonlar dahil
// =============================================
class FormTextAlani extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool zorunlu;
  final bool emailAlani;
  final int? maxUzunluk;
  final int maxSatir;
  final TextInputType? klavyeTipi;
  final bool readOnly;
  final VoidCallback? onTap;

  const FormTextAlani({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.zorunlu = false,
    this.emailAlani = false,
    this.maxUzunluk,
    this.maxSatir = 1,
    this.klavyeTipi,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLength: maxUzunluk,
      maxLines: maxSatir,
      keyboardType: klavyeTipi,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        // 📚 DERS: Zorunlu alan ise label sonuna kirmizi * eklenir
        label: RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            children: zorunlu
                ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]
                : null,
          ),
        ),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        counterText: '',
      ),
      validator: (value) {
        if (zorunlu && (value == null || value.trim().isEmpty)) {
          return '$label gerekli';
        }
        if (emailAlani && value != null && value.trim().isNotEmpty) {
          final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
          if (!emailRegex.hasMatch(value.trim())) {
            return 'Gecerli bir email adresi girin';
          }
        }
        return null;
      },
    );
  }
}

// =============================================
// 4. FORM BUTONLARI
// 📚 DERS: Kaydet + Kaydet&Yeni + Iptal
// Tum formlarda ayni buton yapisi kullanilir
// =============================================
class FormButonlari extends StatelessWidget {
  final bool duzenleModu;
  final bool kaydediliyor;
  final VoidCallback onKaydet;
  final VoidCallback? onKaydetVeYeni;

  const FormButonlari({
    super.key,
    required this.duzenleModu,
    required this.kaydediliyor,
    required this.onKaydet,
    this.onKaydetVeYeni,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Ana kaydet butonu
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              onPressed: kaydediliyor ? null : onKaydet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: kaydediliyor
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(duzenleModu ? Icons.save : Icons.add, size: 18),
              label: Text(
                duzenleModu ? 'Kaydet' : 'Ekle',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),

        // Kaydet & Yeni butonu (sadece ekleme modunda)
        if (!duzenleModu && onKaydetVeYeni != null) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: kaydediliyor ? null : onKaydetVeYeni,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Kaydet & Yeni', style: TextStyle(fontSize: 13)),
              ),
            ),
          ),
        ],

        // Ctrl+S bilgisi
        const SizedBox(width: 8),
        Tooltip(
          message: 'Ctrl+S ile de kaydedebilirsiniz',
          child: Icon(Icons.keyboard, size: 18, color: Colors.grey[400]),
        ),
      ],
    );
  }
}

// =============================================
// 5. FORM BILGI SATIRI
// 📚 DERS: Formun altinda olusturma/guncelleme bilgisi gosterir
// "Olusturan: demo@osgb.com | 05.02.2026 14:30"
// "Son guncelleme: 07.02.2026 21:00"
// =============================================
class FormBilgiSatiri extends StatelessWidget {
  final Map<String, dynamic> kayit;

  const FormBilgiSatiri({super.key, required this.kayit});

  String _tarihFormat(String? tarihStr) {
    if (tarihStr == null || tarihStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(tarihStr);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return tarihStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final olusturanEmail = kayit['olusturan_email'] ?? kayit['olusturan'] ?? '';
    final olusturmaTarihi = _tarihFormat(kayit['olusturma_tarihi']?.toString());
    final guncellemeTarihi = _tarihFormat(kayit['guncelleme_tarihi']?.toString());

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text('Kayit Bilgisi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 6),
          if (olusturanEmail.isNotEmpty)
            _bilgiSatir('Olusturan', olusturanEmail),
          _bilgiSatir('Olusturma Tarihi', olusturmaTarihi),
          _bilgiSatir('Son Guncelleme', guncellemeTarihi),
          if (kayit['id'] != null)
            _bilgiSatir('Kayit ID', '#${kayit['id']}'),
        ],
      ),
    );
  }

  Widget _bilgiSatir(String etiket, String deger) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(etiket, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ),
          Expanded(
            child: Text(deger, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// =============================================
// 6. FORM NOTU ALANI
// 📚 DERS: Her kayitta serbest not alani
// =============================================
class FormNotAlani extends StatelessWidget {
  final TextEditingController controller;

  const FormNotAlani({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormBolumBaslik(baslik: 'Notlar', ikon: Icons.note_alt_outlined),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Bu kayitla ilgili notlarinizi yazin...',
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}
