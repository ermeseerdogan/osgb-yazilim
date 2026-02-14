// =============================================
// PERSONEL LISTESI EKRANI
// OSGB personeli: ISG Uzmani, Isyeri Hekimi, DSP
// =============================================
//
// Calisan liste ekraninin ayni yapisi, farklar:
// - Isyeri filtresi yok (personel isyerine bagli degil)
// - Unvan filtresi var (ISG Uzmani / Isyeri Hekimi / DSP)
// - Unvan renkli badge olarak gosterilir

import 'dart:typed_data';
import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/api_service.dart';
import 'personel_form_screen.dart';

class KolonTanimi {
  final String anahtar;
  final String baslik;
  final bool varsayilanGorunum;
  final double genislik;

  const KolonTanimi({
    required this.anahtar,
    required this.baslik,
    this.varsayilanGorunum = false,
    this.genislik = 120,
  });
}

class PersonelListScreen extends StatefulWidget {
  const PersonelListScreen({super.key});

  @override
  State<PersonelListScreen> createState() => _PersonelListScreenState();
}

class _PersonelListScreenState extends State<PersonelListScreen> {
  final _apiService = ApiService();

  static const List<KolonTanimi> _kolonlar = [
    KolonTanimi(anahtar: 'ad', baslik: 'Ad', varsayilanGorunum: true, genislik: 130),
    KolonTanimi(anahtar: 'soyad', baslik: 'Soyad', varsayilanGorunum: true, genislik: 130),
    KolonTanimi(anahtar: 'unvan_turkce', baslik: 'Unvan', varsayilanGorunum: true, genislik: 150),
    KolonTanimi(anahtar: 'telefon', baslik: 'Telefon', varsayilanGorunum: true, genislik: 130),
    KolonTanimi(anahtar: 'email', baslik: 'Email', genislik: 180),
    KolonTanimi(anahtar: 'tc_no', baslik: 'TC No', genislik: 130),
    KolonTanimi(anahtar: 'uzmanlik_sinifi', baslik: 'Uzmanlik Sinifi', genislik: 140),
    KolonTanimi(anahtar: 'brans', baslik: 'Brans', genislik: 150),
    KolonTanimi(anahtar: 'uzmanlik_belgesi_no', baslik: 'Belge No', genislik: 130),
    KolonTanimi(anahtar: 'ise_baslama_tarihi', baslik: 'Ise Baslama', genislik: 120),
  ];

  List<dynamic> _personeller = [];
  int _toplam = 0;
  bool _yukleniyor = true;
  String? _hata;
  String _aramaMetni = '';

  late Set<String> _gorunurKolonlar;
  final Map<String, Set<String>> _kolonFiltreleri = {};
  String? _grupKolonu;
  final Set<String> _acikGruplar = {};

  // Unvan filtresi
  String? _seciliUnvan;

  List<dynamic> get _filtreliPersoneller {
    if (_kolonFiltreleri.isEmpty) return _personeller;
    return _personeller.where((p) {
      for (final entry in _kolonFiltreleri.entries) {
        final kolonAdi = entry.key;
        final seciliDegerler = entry.value;
        if (seciliDegerler.isEmpty) continue;
        final deger = p[kolonAdi]?.toString() ?? '';
        if (!seciliDegerler.contains(deger)) return false;
      }
      return true;
    }).toList();
  }

  final _aramaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _gorunurKolonlar = _kolonlar
        .where((k) => k.varsayilanGorunum)
        .map((k) => k.anahtar)
        .toSet();
    _personelleriYukle();
  }

  Future<void> _personelleriYukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });

    try {
      final sonuc = await _apiService.personelListele(
        arama: _aramaMetni.isNotEmpty ? _aramaMetni : null,
        unvan: _seciliUnvan,
      );

      setState(() {
        _personeller = sonuc['personeller'] as List<dynamic>;
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

  // Personel avatar (profil foto veya basharfler)
  Widget _personelAvatar(dynamic personel, {double radius = 16}) {
    final ad = personel['ad']?.toString() ?? '';
    final soyad = personel['soyad']?.toString() ?? '';
    final basHarfler = '${ad.isNotEmpty ? ad[0] : ''}${soyad.isNotEmpty ? soyad[0] : ''}'.toUpperCase();
    final fotoUrl = personel['profil_foto_url']?.toString() ?? '';

    if (fotoUrl.isNotEmpty) {
      final token = ApiService.tokenGetir();
      final url = '${_apiService.personelProfilFotoUrl(personel['id'])}?t=$token';
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blue[100],
      child: Text(basHarfler, style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.bold, color: Colors.blue[800])),
    );
  }

  // Unvan badge renkleri
  Widget _unvanBadge(String deger) {
    Color renk;
    if (deger.contains('ISG')) {
      renk = Colors.blue;
    } else if (deger.contains('Hekim')) {
      renk = Colors.green;
    } else if (deger.contains('DSP')) {
      renk = Colors.orange;
    } else {
      renk = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: renk.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: renk.withAlpha(80)),
      ),
      child: Text(deger, style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.w600)),
    );
  }

  String _tarihFormatla(String? tarih) {
    if (tarih == null || tarih.isEmpty) return '';
    try {
      final dt = DateTime.parse(tarih);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return tarih;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Personel ($_toplam)'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // Gruplama butonu
          PopupMenuButton<String>(
            icon: Icon(
              _grupKolonu != null ? Icons.workspaces : Icons.workspaces_outlined,
              color: _grupKolonu != null ? Colors.yellow : Colors.white,
            ),
            tooltip: 'Grupla',
            onSelected: (value) {
              setState(() {
                if (value == 'kaldir') {
                  _grupKolonu = null;
                  _acikGruplar.clear();
                } else {
                  _grupKolonu = value;
                  _acikGruplar.clear();
                  final degerler = <String>{};
                  for (final p in _filtreliPersoneller) {
                    degerler.add(p[value]?.toString() ?? '(Bos)');
                  }
                  _acikGruplar.addAll(degerler);
                }
              });
            },
            itemBuilder: (context) => [
              if (_grupKolonu != null)
                PopupMenuItem(
                  value: 'kaldir',
                  child: Row(
                    children: [
                      Icon(Icons.clear, size: 18, color: Colors.red[400]),
                      const SizedBox(width: 8),
                      const Text('Gruplamayi Kaldir', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              if (_grupKolonu != null) const PopupMenuDivider(),
              ..._kolonlar
                  .where((k) => _gorunurKolonlar.contains(k.anahtar))
                  .map((k) => PopupMenuItem(
                        value: k.anahtar,
                        child: Row(
                          children: [
                            Icon(
                              _grupKolonu == k.anahtar ? Icons.check : Icons.workspaces_outlined,
                              size: 18,
                              color: _grupKolonu == k.anahtar ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(k.baslik, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      )),
            ],
          ),
          // Kolon secici
          IconButton(
            icon: const Icon(Icons.view_column),
            tooltip: 'Kolonlari Sec',
            onPressed: _kolonSeciciGoster,
          ),
          // Excel islemleri
          PopupMenuButton<String>(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Excel Islemleri',
            onSelected: (value) {
              if (value == 'export') _excelExport();
              if (value == 'sablon') _excelSablonIndir();
              if (value == 'import') _excelImport();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Excel\'e Aktar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sablon',
                child: Row(
                  children: [
                    Icon(Icons.description, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Bos Sablon Indir'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Excel\'den Yukle'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final eklendi = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const PersonelFormScreen(),
            ),
          );
          if (eklendi == true) _personelleriYukle();
        },
        icon: const Icon(Icons.add),
        label: const Text('Yeni Personel'),
      ),

      body: Column(
        children: [
          // Arama + Unvan filtresi + yenile
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                // Arama kutusu
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _aramaController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Personel ara (ad, soyad, TC)...',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: _aramaMetni.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _aramaController.clear();
                                  setState(() => _aramaMetni = '');
                                  _personelleriYukle();
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() => _aramaMetni = value);
                      },
                      onSubmitted: (_) => _personelleriYukle(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Unvan filtresi dropdown
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 38,
                    child: DropdownButtonFormField<String?>(
                      value: _seciliUnvan,
                      isExpanded: true,
                      isDense: true,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Tum Unvanlar',
                        hintStyle: const TextStyle(fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tum Unvanlar', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'isg_uzmani',
                          child: Text('ISG Uzmani', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'isyeri_hekimi',
                          child: Text('Isyeri Hekimi', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'dsp',
                          child: Text('DSP', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _seciliUnvan = value);
                        _personelleriYukle();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: _personelleriYukle,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Yenile', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Icerik
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _hata != null
                    ? _hataWidget()
                    : _personeller.isEmpty
                        ? _bosListeWidget()
                        : _personelTablosu(),
          ),
        ],
      ),
    );
  }

  // =============================================
  // KOLON SECICI DIALOG
  // =============================================
  void _kolonSeciciGoster() {
    showDialog(
      context: context,
      builder: (ctx) {
        final geciciSecim = Set<String>.from(_gorunurKolonlar);

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
                            setDialogState(() {
                              geciciSecim.addAll(_kolonlar.map((k) => k.anahtar));
                            });
                          },
                          child: const Text('Tumunu Sec', style: TextStyle(fontSize: 12)),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              geciciSecim.clear();
                              geciciSecim.add('ad');
                            });
                          },
                          child: const Text('Tumunu Kaldir', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    ..._kolonlar.map((kolon) {
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
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Iptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _gorunurKolonlar = geciciSecim;
                    });
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
  // PERSONEL TABLOSU
  // =============================================
  Widget _personelTablosu() {
    final aktifKolonlar = _kolonlar
        .where((k) => _gorunurKolonlar.contains(k.anahtar))
        .toList();

    final gosterilecek = _filtreliPersoneller;

    return Column(
      children: [
        // Aktif filtre + gruplama bilgisi
        if (_kolonFiltreleri.isNotEmpty || _grupKolonu != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 14, color: Colors.blue[700]),
                const SizedBox(width: 4),
                if (_kolonFiltreleri.isNotEmpty)
                  Text(
                    'Filtre: ${gosterilecek.length}/${_personeller.length}',
                    style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                  ),
                if (_kolonFiltreleri.isNotEmpty && _grupKolonu != null)
                  Text(' | ', style: TextStyle(fontSize: 11, color: Colors.blue[300])),
                if (_grupKolonu != null)
                  Text(
                    'Grup: ${_kolonlar.firstWhere((k) => k.anahtar == _grupKolonu).baslik}',
                    style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                  ),
                const Spacer(),
                if (_kolonFiltreleri.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() => _kolonFiltreleri.clear()),
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
                if (_grupKolonu != null)
                  InkWell(
                    onTap: () => setState(() { _grupKolonu = null; _acikGruplar.clear(); }),
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
          ),
        // Baslik satiri
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              const SizedBox(
                width: 40,
                child: Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              ...aktifKolonlar.map((k) => Expanded(
                    child: _filtreliKolonBaslik(k),
                  )),
              const SizedBox(width: 40),
            ],
          ),
        ),
        // Tablo icerigi
        Expanded(
          child: _grupKolonu != null
              ? _grupluTablo(aktifKolonlar, gosterilecek)
              : _duzTablo(aktifKolonlar, gosterilecek),
        ),
      ],
    );
  }

  Widget _duzTablo(List<KolonTanimi> aktifKolonlar, List<dynamic> personeller) {
    return ListView.builder(
      itemCount: personeller.length,
      itemBuilder: (context, index) {
        return _personelSatiri(aktifKolonlar, personeller[index], index + 1);
      },
    );
  }

  // =============================================
  // GRUPLU TABLO
  // =============================================
  Widget _grupluTablo(List<KolonTanimi> aktifKolonlar, List<dynamic> personeller) {
    final gruplar = <String, List<dynamic>>{};
    for (final p in personeller) {
      final deger = p[_grupKolonu]?.toString() ?? '';
      final grupAdi = deger.isEmpty ? '(Bos)' : deger;
      gruplar.putIfAbsent(grupAdi, () => []).add(p);
    }

    final grupIsimleri = gruplar.keys.toList()..sort();

    final satirlar = <_TabloSatir>[];
    int siraNo = 1;
    for (final grupAdi in grupIsimleri) {
      final grupPersonelleri = gruplar[grupAdi]!;
      satirlar.add(_TabloSatir(tip: _SatirTip.grupBaslik, grupAdi: grupAdi, grupSayisi: grupPersonelleri.length));
      if (_acikGruplar.contains(grupAdi)) {
        for (final p in grupPersonelleri) {
          satirlar.add(_TabloSatir(tip: _SatirTip.veri, personel: p, siraNo: siraNo++));
        }
      }
    }

    return ListView.builder(
      itemCount: satirlar.length,
      itemBuilder: (context, index) {
        final satir = satirlar[index];
        if (satir.tip == _SatirTip.grupBaslik) {
          return _grupBaslikSatiri(satir.grupAdi!, satir.grupSayisi!);
        }
        return _personelSatiri(aktifKolonlar, satir.personel!, satir.siraNo!);
      },
    );
  }

  Widget _grupBaslikSatiri(String grupAdi, int sayi) {
    final acik = _acikGruplar.contains(grupAdi);
    return InkWell(
      onTap: () {
        setState(() {
          if (acik) {
            _acikGruplar.remove(grupAdi);
          } else {
            _acikGruplar.add(grupAdi);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.indigo[50],
          border: Border(bottom: BorderSide(color: Colors.indigo[100]!)),
        ),
        child: Row(
          children: [
            Icon(
              acik ? Icons.expand_more : Icons.chevron_right,
              size: 20,
              color: Colors.indigo[700],
            ),
            const SizedBox(width: 4),
            Text(
              grupAdi,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.indigo[800],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.indigo[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$sayi',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tek personel satiri
  Widget _personelSatiri(List<KolonTanimi> aktifKolonlar, dynamic personel, int siraNo) {
    return InkWell(
      onTap: () => _personelDuzenle(personel),
      child: Container(
        decoration: BoxDecoration(
          color: siraNo.isOdd ? Colors.white : Colors.grey[50],
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            // Profil fotografi veya basharfler
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _personelAvatar(personel, radius: 16),
            ),
            ...aktifKolonlar.map((k) {
              final deger = personel[k.anahtar]?.toString() ?? '';

              // Unvan ozel gosterim (badge)
              if (k.anahtar == 'unvan_turkce' && deger.isNotEmpty) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _unvanBadge(deger),
                  ),
                );
              }

              // Tarih alanlari formatlama
              if (k.anahtar == 'ise_baslama_tarihi' && deger.isNotEmpty) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _tarihFormatla(deger),
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    deger,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: (k.anahtar == 'ad' || k.anahtar == 'soyad')
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: k.anahtar == 'ad' ? Colors.blue[800] : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }),
            SizedBox(
              width: 40,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 20,
                onSelected: (value) async {
                  if (value == 'duzenle') {
                    _personelDuzenle(personel);
                  } else if (value == 'sil') {
                    _personelSilOnay(personel);
                  } else if (value == 'log') {
                    _kayitLogGoster(personel['id'], '${personel['ad']} ${personel['soyad']}');
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'duzenle',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Duzenle', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'log',
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 18, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('Degisiklik Gecmisi', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sil',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Sil', style: TextStyle(fontSize: 13, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================
  // KOLON BAZLI FILTRE
  // =============================================
  Widget _filtreliKolonBaslik(KolonTanimi kolon) {
    final aktifFiltre = _kolonFiltreleri.containsKey(kolon.anahtar) &&
        _kolonFiltreleri[kolon.anahtar]!.isNotEmpty;

    return InkWell(
      onTap: () => _kolonFiltreDialogGoster(kolon),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                kolon.baslik,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
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

  void _kolonFiltreDialogGoster(KolonTanimi kolon) {
    final tumDegerler = <String>{};
    for (final p in _personeller) {
      final deger = p[kolon.anahtar]?.toString() ?? '';
      if (deger.isNotEmpty) tumDegerler.add(deger);
    }
    final siraliDegerler = tumDegerler.toList()..sort();
    final geciciSecim = Set<String>.from(
      _kolonFiltreleri[kolon.anahtar] ?? <String>{},
    );
    String filtreArama = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final gosterilecek = filtreArama.isEmpty
                ? siraliDegerler
                : siraliDegerler
                    .where((d) => d.toLowerCase().contains(filtreArama.toLowerCase()))
                    .toList();

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
                              hintText: 'Ara...',
                              hintStyle: const TextStyle(fontSize: 12),
                              prefixIcon: const Icon(Icons.search, size: 16),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onChanged: (val) {
                              setDialogState(() => filtreArama = val);
                            },
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() => geciciSecim.addAll(gosterilecek));
                          },
                          child: const Text('Tumunu Sec', style: TextStyle(fontSize: 11)),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() => geciciSecim.clear());
                          },
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
                                final sayi = _personeller.where((p) =>
                                    (p[kolon.anahtar]?.toString() ?? '') == deger).length;
                                return CheckboxListTile(
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(deger, style: const TextStyle(fontSize: 13),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      Text('($sayi)', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                    ],
                                  ),
                                  value: geciciSecim.contains(deger),
                                  dense: true,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        geciciSecim.add(deger);
                                      } else {
                                        geciciSecim.remove(deger);
                                      }
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
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Iptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (geciciSecim.isEmpty) {
                        _kolonFiltreleri.remove(kolon.anahtar);
                      } else {
                        _kolonFiltreleri[kolon.anahtar] = geciciSecim;
                      }
                    });
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

  // Personel duzenleme
  Future<void> _personelDuzenle(Map<String, dynamic> personel) async {
    final guncellendi = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonelFormScreen(personel: personel),
      ),
    );
    if (guncellendi == true) _personelleriYukle();
  }

  // Bos liste
  Widget _bosListeWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.badge_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _aramaMetni.isNotEmpty
                ? '"$_aramaMetni" icin sonuc bulunamadi'
                : 'Henuz personel eklenmemis',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_aramaMetni.isEmpty)
            Text(
              'Sag alttaki + butonuyla yeni personel ekleyin',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
        ],
      ),
    );
  }

  // Hata
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
            onPressed: _personelleriYukle,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  // =============================================
  // EXCEL ISLEMLERI
  // =============================================

  Future<void> _excelExport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel hazirlaniyor...')),
      );
      final bytes = await _apiService.personelExcelExport(
        arama: _aramaMetni.isNotEmpty ? _aramaMetni : null,
        unvan: _seciliUnvan,
      );
      final blob = html.Blob([Uint8List.fromList(bytes)],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'personel.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel dosyasi indirildi'), backgroundColor: Colors.green),
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

  Future<void> _excelSablonIndir() async {
    try {
      final bytes = await _apiService.personelExcelSablon();
      final blob = html.Blob([Uint8List.fromList(bytes)],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'personel_sablon.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sablon indirildi'), backgroundColor: Colors.green),
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

  // Personel import - isyeri secimi gereksiz (personel isyerine bagli degil)
  Future<void> _excelImport() async {
    try {
      final uploadInput = html.FileUploadInputElement();
      uploadInput.accept = '.xlsx,.xls';
      uploadInput.click();
      await uploadInput.onChange.first;
      if (uploadInput.files == null || uploadInput.files!.isEmpty) return;
      final file = uploadInput.files!.first;
      if (!file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
        throw Exception('Sadece Excel dosyasi (.xlsx) yuklenebilir');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel yukleniyor...')),
        );
      }
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final bytes = (reader.result as Uint8List).toList();
      final sonuc = await _apiService.personelExcelImport(bytes, file.name);
      if (mounted) {
        _excelImportSonuc(sonuc);
        _personelleriYukle();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _excelImportSonuc(Map<String, dynamic> sonuc) {
    final eklenen = sonuc['eklenen'] ?? 0;
    final toplamSatir = sonuc['toplam_satir'] ?? 0;
    final hataliSayisi = sonuc['hatali_sayisi'] ?? 0;
    final hatali = sonuc['hatali'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(eklenen > 0 ? Icons.check_circle : Icons.warning,
                color: eklenen > 0 ? Colors.green : Colors.orange),
            const SizedBox(width: 8),
            const Text('Excel Yukleme Sonucu'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  _ozetSatir('Toplam satir', '$toplamSatir'),
                  _ozetSatir('Basariyla eklenen', '$eklenen', renk: Colors.green),
                  if (hataliSayisi > 0) _ozetSatir('Hatali / Atlanan', '$hataliSayisi', renk: Colors.red),
                ]),
              ),
              if (hatali.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Hatali satirlar:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: hatali.length,
                    itemBuilder: (ctx, i) {
                      final h = hatali[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                          child: Text('Satir ${h['satir']}: ${h['hata']}',
                              style: TextStyle(fontSize: 12, color: Colors.red[700])),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
      ),
    );
  }

  Widget _ozetSatir(String etiket, String deger, {Color? renk}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiket),
          Text(deger, style: TextStyle(fontWeight: FontWeight.bold, color: renk)),
        ],
      ),
    );
  }

  // =============================================
  // KAYIT LOG GECMISI
  // =============================================
  void _kayitLogGoster(int kayitId, String kayitAd) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _KayitLogDialog(
          kayitId: kayitId,
          kayitAd: kayitAd,
          kayitTuru: 'Personel',
          apiService: _apiService,
        );
      },
    );
  }

  // Personel silme onay
  void _personelSilOnay(Map<String, dynamic> personel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Personel Sil'),
        content: Text("'${personel['ad']} ${personel['soyad']}' personelini silmek istiyor musunuz?"),
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
                await _apiService.personelSil(personel['id']);
                _personelleriYukle();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("'${personel['ad']} ${personel['soyad']}' silindi")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: ${e.toString()}'), backgroundColor: Colors.red),
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

// =============================================
// KAYIT LOG DIALOG
// =============================================
class _KayitLogDialog extends StatefulWidget {
  final int kayitId;
  final String kayitAd;
  final String kayitTuru;
  final ApiService apiService;

  const _KayitLogDialog({
    required this.kayitId,
    required this.kayitAd,
    required this.kayitTuru,
    required this.apiService,
  });

  @override
  State<_KayitLogDialog> createState() => _KayitLogDialogState();
}

class _KayitLogDialogState extends State<_KayitLogDialog> {
  List<dynamic> _loglar = [];
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _loglariYukle();
  }

  Future<void> _loglariYukle() async {
    try {
      final sonuc = await widget.apiService.logListele(
        kayitTuru: widget.kayitTuru,
        kayitId: widget.kayitId,
        adet: 100,
      );
      setState(() {
        _loglar = sonuc['loglar'] as List<dynamic>;
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() {
        _hata = e.toString().replaceAll('Exception: ', '');
        _yukleniyor = false;
      });
    }
  }

  String _islemTurkce(String islemTuru) {
    switch (islemTuru) {
      case 'kayit_ekleme': return 'Olusturuldu';
      case 'kayit_guncelleme': return 'Duzenlendi';
      case 'kayit_silme': return 'Silindi (pasife alindi)';
      default: return islemTuru;
    }
  }

  IconData _islemIkon(String islemTuru) {
    switch (islemTuru) {
      case 'kayit_ekleme': return Icons.add_circle;
      case 'kayit_guncelleme': return Icons.edit;
      case 'kayit_silme': return Icons.delete;
      default: return Icons.info;
    }
  }

  Color _islemRenk(String islemTuru) {
    switch (islemTuru) {
      case 'kayit_ekleme': return Colors.green;
      case 'kayit_guncelleme': return Colors.orange;
      case 'kayit_silme': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.history, color: Colors.purple),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Degisiklik Gecmisi', style: TextStyle(fontSize: 16)),
                Text(widget.kayitAd, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _yukleniyor
            ? const Center(child: CircularProgressIndicator())
            : _hata != null
                ? Center(child: Text(_hata!, style: TextStyle(color: Colors.red[600])))
                : _loglar.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Bu kayit icin log bulunamadi'),
                            SizedBox(height: 4),
                            Text('Not: Sadece log sistemi eklendikten sonraki\nislemler kayit altindadir.',
                                textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      )
                    : _logTimeline(),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
    );
  }

  Widget _logTimeline() {
    return ListView.builder(
      itemCount: _loglar.length,
      itemBuilder: (context, index) {
        final log = _loglar[index];
        final islemTuru = log['islem_turu'] ?? '';
        final tarih = log['tarih'] ?? '';
        final renk = _islemRenk(islemTuru);

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

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(width: 2, height: index == 0 ? 0 : 12, color: Colors.grey[300]),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: renk.withAlpha(30),
                    child: Icon(_islemIkon(islemTuru), size: 16, color: renk),
                  ),
                  if (index < _loglar.length - 1)
                    Container(width: 2, height: 40, color: Colors.grey[300]),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_islemTurkce(islemTuru),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: renk)),
                        const Spacer(),
                        Text(tarihStr, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(log['kullanici_ad'] ?? log['kullanici_email'] ?? 'Bilinmiyor',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    if (log['eski_deger'] != null && log['yeni_deger'] != null)
                      _degisiklikOzet(log['eski_deger'], log['yeni_deger']),
                    if (log['yeni_deger'] != null && log['eski_deger'] == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)),
                          child: Text('Yeni kayit olusturuldu',
                              style: TextStyle(fontSize: 11, color: Colors.green[700])),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _degisiklikOzet(dynamic eski, dynamic yeni) {
    if (eski is! Map || yeni is! Map) return const SizedBox.shrink();
    final degisiklikler = <Widget>[];
    final alanlar = <String>{...eski.keys.cast<String>(), ...yeni.keys.cast<String>()};
    for (final alan in alanlar) {
      if (eski[alan] != yeni[alan]) {
        degisiklikler.add(Padding(
          padding: const EdgeInsets.only(top: 2),
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 11, color: Colors.grey[800]),
              children: [
                TextSpan(text: '$alan: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: '${eski[alan] ?? '-'}',
                    style: TextStyle(color: Colors.red[600], decoration: TextDecoration.lineThrough)),
                const TextSpan(text: ' \u2192 '),
                TextSpan(text: '${yeni[alan] ?? '-'}',
                    style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ));
      }
    }
    if (degisiklikler.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: degisiklikler),
      ),
    );
  }
}

// =============================================
// YARDIMCI SINIFLAR
// =============================================
enum _SatirTip { grupBaslik, veri }

class _TabloSatir {
  final _SatirTip tip;
  final String? grupAdi;
  final int? grupSayisi;
  final dynamic personel;
  final int? siraNo;

  const _TabloSatir({
    required this.tip,
    this.grupAdi,
    this.grupSayisi,
    this.personel,
    this.siraNo,
  });
}
