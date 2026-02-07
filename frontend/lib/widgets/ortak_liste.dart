// =============================================
// ORTAK LISTE WIDGET'LARI
// Tum liste ekranlarinda kullanilacak standart bilesenler
// =============================================
//
// 📚 DERS: Bu dosya liste ekranlari icin ortak kalip saglar
// Her modul (firma, isyeri, calisan vb.) bu widget'lari kullanir
//
// Icerik:
// 1. KolonTanimi    -> Kolon tanimi sinifi
// 2. ListeAramaBar -> Arama + yenile satiri
// 3. ListeTablosu  -> Tum tablo mantigi (duz/gruplu, filtre, baslik)
// 4. _SatirTip, _TabloSatir -> Yardimci siniflar

import 'package:flutter/material.dart';

// =============================================
// 1. KOLON TANIMI
// 📚 DERS: Her kolon icin tanim
// Tum listelerde bu sinif kullanilir
// =============================================
class KolonTanimi {
  final String anahtar;      // API'deki alan adi (ornek: 'ad', 'il')
  final String baslik;       // Gosterilecek isim (ornek: 'Firma Adi', 'Il')
  final bool varsayilanGorunum; // Sayfa acildiginda gorunur mu?
  final double genislik;     // Onerilen genislik (px)

  const KolonTanimi({
    required this.anahtar,
    required this.baslik,
    this.varsayilanGorunum = false,
    this.genislik = 120,
  });
}

// =============================================
// 2. LISTE ARAMA BAR
// 📚 DERS: Tum listelerde ayni arama cubugu
// =============================================
class ListeAramaBar extends StatelessWidget {
  final TextEditingController controller;
  final String aramaMetni;
  final ValueChanged<String> onChanged;
  final VoidCallback onAra;
  final VoidCallback onTemizle;
  final VoidCallback onYenile;
  final String? hintText;

  const ListeAramaBar({
    super.key,
    required this.controller,
    required this.aramaMetni,
    required this.onChanged,
    required this.onAra,
    required this.onTemizle,
    required this.onYenile,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: hintText ?? 'Ara...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: aramaMetni.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: onTemizle,
                        )
                      : null,
                ),
                onChanged: onChanged,
                onSubmitted: (_) => onAra(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              onPressed: onYenile,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Yenile', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================
// 3. KOLON SECICI DIALOG
// 📚 DERS: Tum listelerde ayni kolon secici
// =============================================
void kolonSeciciDialogGoster({
  required BuildContext context,
  required List<KolonTanimi> kolonlar,
  required Set<String> gorunurKolonlar,
  required ValueChanged<Set<String>> onUygula,
}) {
  final geciciSecim = Set<String>.from(gorunurKolonlar);

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.view_column, color: Colors.blue),
                SizedBox(width: 8),
                Text('Gorunur Kolonlar', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setDialogState(() => geciciSecim.addAll(kolonlar.map((k) => k.anahtar)));
                        },
                        child: const Text('Tumunu Sec', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            geciciSecim.clear();
                            geciciSecim.add(kolonlar.first.anahtar);
                          });
                        },
                        child: const Text('Tumunu Kaldir', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  ...kolonlar.map((kolon) {
                    return CheckboxListTile(
                      title: Text(kolon.baslik, style: const TextStyle(fontSize: 14)),
                      value: geciciSecim.contains(kolon.anahtar),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            geciciSecim.add(kolon.anahtar);
                          } else {
                            if (geciciSecim.length > 1) {
                              geciciSecim.remove(kolon.anahtar);
                            }
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
              ElevatedButton(
                onPressed: () {
                  onUygula(geciciSecim);
                  Navigator.pop(ctx);
                },
                child: const Text('Uygula'),
              ),
            ],
          );
        },
      );
    },
  );
}

// =============================================
// 4. KOLON FILTRE DIALOG
// 📚 DERS: Excel tarzi kolon filtreleme - tum listelerde ortak
// =============================================
void kolonFiltreDialogGoster({
  required BuildContext context,
  required KolonTanimi kolon,
  required List<dynamic> tumKayitlar,
  required Map<String, Set<String>> kolonFiltreleri,
  required VoidCallback onUygula,
}) {
  final tumDegerler = <String>{};
  for (final kayit in tumKayitlar) {
    final deger = kayit[kolon.anahtar]?.toString() ?? '';
    if (deger.isNotEmpty) tumDegerler.add(deger);
  }

  final siraliDegerler = tumDegerler.toList()..sort();
  final geciciSecim = Set<String>.from(kolonFiltreleri[kolon.anahtar] ?? <String>{});
  String filtreArama = '';

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final gosterilecek = filtreArama.isEmpty
              ? siraliDegerler
              : siraliDegerler.where((d) => d.toLowerCase().contains(filtreArama.toLowerCase())).toList();

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.filter_alt, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text('${kolon.baslik} Filtrele', style: const TextStyle(fontSize: 15)),
              ],
            ),
            content: SizedBox(
              width: 300,
              height: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (siraliDegerler.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        height: 34,
                        child: TextField(
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Ara...', hintStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.search, size: 16),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onChanged: (val) => setDialogState(() => filtreArama = val),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setDialogState(() => geciciSecim.addAll(gosterilecek)),
                        child: const Text('Tumunu Sec', style: TextStyle(fontSize: 11)),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(() => geciciSecim.clear()),
                        child: const Text('Temizle', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: gosterilecek.isEmpty
                        ? const Center(child: Text('Deger bulunamadi', style: TextStyle(fontSize: 12)))
                        : ListView.builder(
                            itemCount: gosterilecek.length,
                            itemBuilder: (ctx, i) {
                              final deger = gosterilecek[i];
                              final sayi = tumKayitlar.where((f) => (f[kolon.anahtar]?.toString() ?? '') == deger).length;
                              return CheckboxListTile(
                                title: Row(
                                  children: [
                                    Expanded(child: Text(deger, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                    Text('($sayi)', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                  ],
                                ),
                                value: geciciSecim.contains(deger),
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) { geciciSecim.add(deger); } else { geciciSecim.remove(deger); }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
              ElevatedButton(
                onPressed: () {
                  if (geciciSecim.isEmpty) {
                    kolonFiltreleri.remove(kolon.anahtar);
                  } else {
                    kolonFiltreleri[kolon.anahtar] = Set<String>.from(geciciSecim);
                  }
                  onUygula();
                  Navigator.pop(ctx);
                },
                child: const Text('Uygula'),
              ),
            ],
          );
        },
      );
    },
  );
}

// =============================================
// 5. FILTRELI KOLON BASLIK WIDGET
// 📚 DERS: Her kolon basliginda filtre ikonu
// =============================================
class FiltreliKolonBaslik extends StatelessWidget {
  final KolonTanimi kolon;
  final Map<String, Set<String>> kolonFiltreleri;
  final VoidCallback onTap;

  const FiltreliKolonBaslik({
    super.key,
    required this.kolon,
    required this.kolonFiltreleri,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final aktifFiltre = kolonFiltreleri.containsKey(kolon.anahtar) &&
        kolonFiltreleri[kolon.anahtar]!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                kolon.baslik,
                style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12,
                  color: aktifFiltre ? Colors.blue[700] : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              aktifFiltre ? Icons.filter_alt : Icons.arrow_drop_down,
              size: 14,
              color: aktifFiltre ? Colors.blue[700] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================
// 6. FILTRE VE GRUP BILGI CUBUGU
// =============================================
class FiltreGrupBilgiCubugu extends StatelessWidget {
  final int filtrelenmisAdet;
  final int toplamAdet;
  final bool filtreAktif;
  final String? grupKolonBaslik;
  final VoidCallback? onFiltreSil;
  final VoidCallback? onGrupSil;

  const FiltreGrupBilgiCubugu({
    super.key,
    required this.filtrelenmisAdet,
    required this.toplamAdet,
    required this.filtreAktif,
    this.grupKolonBaslik,
    this.onFiltreSil,
    this.onGrupSil,
  });

  @override
  Widget build(BuildContext context) {
    if (!filtreAktif && grupKolonBaslik == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.blue[50],
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 14, color: Colors.blue[700]),
          const SizedBox(width: 4),
          if (filtreAktif)
            Text('Filtre: $filtrelenmisAdet/$toplamAdet', style: TextStyle(fontSize: 11, color: Colors.blue[700])),
          if (filtreAktif && grupKolonBaslik != null)
            Text(' | ', style: TextStyle(fontSize: 11, color: Colors.blue[300])),
          if (grupKolonBaslik != null)
            Text('Grup: $grupKolonBaslik', style: TextStyle(fontSize: 11, color: Colors.blue[700])),
          const Spacer(),
          if (filtreAktif && onFiltreSil != null)
            InkWell(
              onTap: onFiltreSil,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(Icons.filter_alt_off, size: 14, color: Colors.blue[700]),
                    const SizedBox(width: 2),
                    Text('Filtre Sil', style: TextStyle(fontSize: 11, color: Colors.blue[700])),
                  ],
                ),
              ),
            ),
          if (grupKolonBaslik != null && onGrupSil != null)
            InkWell(
              onTap: onGrupSil,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(Icons.clear, size: 14, color: Colors.blue[700]),
                    const SizedBox(width: 2),
                    Text('Grup Sil', style: TextStyle(fontSize: 11, color: Colors.blue[700])),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================
// 7. GRUP BASLIK SATIRI
// =============================================
class GrupBaslikSatiri extends StatelessWidget {
  final String grupAdi;
  final int sayi;
  final bool acik;
  final VoidCallback onTap;

  const GrupBaslikSatiri({
    super.key,
    required this.grupAdi,
    required this.sayi,
    required this.acik,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.indigo[50],
          border: Border(bottom: BorderSide(color: Colors.indigo[100]!)),
        ),
        child: Row(
          children: [
            Icon(acik ? Icons.expand_more : Icons.chevron_right, size: 20, color: Colors.indigo[700]),
            const SizedBox(width: 4),
            Text(grupAdi, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo[800])),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.indigo[100], borderRadius: BorderRadius.circular(10)),
              child: Text('$sayi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo[700])),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================
// 8. BOS LISTE VE HATA WIDGET'LARI
// =============================================
class BosListeWidget extends StatelessWidget {
  final String aramaMetni;
  final String modulAdi;
  final IconData ikon;

  const BosListeWidget({
    super.key,
    required this.aramaMetni,
    required this.modulAdi,
    this.ikon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ikon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            aramaMetni.isNotEmpty ? '"$aramaMetni" icin sonuc bulunamadi' : 'Henuz $modulAdi eklenmemis',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (aramaMetni.isEmpty)
            Text('Sag alttaki + butonuyla yeni $modulAdi ekleyin',
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ],
      ),
    );
  }
}

class HataWidget extends StatelessWidget {
  final String hata;
  final VoidCallback onTekrarDene;

  const HataWidget({super.key, required this.hata, required this.onTekrarDene});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(hata, style: TextStyle(color: Colors.red[600])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onTekrarDene, child: const Text('Tekrar Dene')),
        ],
      ),
    );
  }
}

// Yardimci siniflar (gruplu tablo icin)
enum SatirTip { grupBaslik, veri }

class TabloSatir {
  final SatirTip tip;
  final String? grupAdi;
  final int? grupSayisi;
  final dynamic kayit;
  final int? siraNo;

  const TabloSatir({
    required this.tip,
    this.grupAdi,
    this.grupSayisi,
    this.kayit,
    this.siraNo,
  });
}
