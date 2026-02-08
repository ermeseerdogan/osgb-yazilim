// =============================================
// DOKUMAN TAB WIDGET'I
// Tum formlarda kullanilan ortak dokuman yonetimi
// =============================================
//
// 📚 DERS: Bu widget tum modullerde (Firma, Isyeri, Calisan vs.)
// ayni sekilde kullanilir. Polimorfik yapida calisir:
//
//   DokumanTab(kaynakTipi: 'firma', kaynakId: 5)
//   DokumanTab(kaynakTipi: 'isyeri', kaynakId: 12)
//
// Ozellikler:
// - Dosya yukleme (drag & drop + buton)
// - Dosya listesi (tablo gorunumu)
// - Dosya indirme (yeni sekmede acar)
// - Dosya silme (onay dialogu ile)
// - Dosya boyutu ve tipi gosterimi
// - Aciklama ekleme

import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';
import '../services/api_service.dart';

class DokumanTab extends StatefulWidget {
  final String kaynakTipi; // "firma", "isyeri", "calisan" vs.
  final int kaynakId;      // Ilgili kaydin ID'si

  const DokumanTab({
    super.key,
    required this.kaynakTipi,
    required this.kaynakId,
  });

  @override
  State<DokumanTab> createState() => _DokumanTabState();
}

class _DokumanTabState extends State<DokumanTab> {
  final _apiService = ApiService();

  List<Map<String, dynamic>> _dokumanlar = [];
  bool _yukleniyor = false;
  bool _dosyaYukleniyor = false;

  @override
  void initState() {
    super.initState();
    _dokumanlariYukle();
  }

  // =============================================
  // DOKUMAN LISTESINI YUKLE
  // =============================================
  Future<void> _dokumanlariYukle() async {
    setState(() => _yukleniyor = true);
    try {
      final data = await _apiService.dokumanListele(
        widget.kaynakTipi,
        widget.kaynakId,
      );
      setState(() {
        _dokumanlar = List<Map<String, dynamic>>.from(data['kayitlar'] ?? []);
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() => _yukleniyor = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dokumanlar yuklenemedi: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // =============================================
  // DOSYA SEC VE YUKLE
  // 📚 DERS: Web'de dosya secimi dart:html ile yapilir.
  // html.FileUploadInputElement() ile dosya secme dialogu acilir.
  // Secilen dosya bytes olarak okunur ve API'ye gonderilir.
  //
  // ONEMLI: FileUploadInputElement'i body'ye eklememiz lazim,
  // yoksa bazi tarayicilarda onChange event'i tetiklenmez!
  // =============================================
  Future<void> _dosyaSec() async {
    // 📚 DERS: html.FileUploadInputElement = tarayicinin dosya sec dialogu
    final uploadInput = html.FileUploadInputElement();
    uploadInput.multiple = true; // Birden fazla dosya secebilsin

    // 📚 DERS: accept attribute'u KALDIRILDI!
    // Windows'ta uzun uzanti listesi "Ozel Dosyalar" filtresi olusturuyor
    // ve bazi tarayicilarda dosya secimi engelleniyordu.
    // Backend zaten dosya uzantisini kontrol ediyor (IZINLI_UZANTILAR),
    // o yuzden frontend'de kisitlama yapmaya gerek yok.

    // 📚 DERS: Elementi gorunmez sekilde body'ye ekle
    // Bazi tarayicilarda DOM'a eklenmeden onChange calismaz
    uploadInput.style.display = 'none';
    html.document.body?.append(uploadInput);

    // 📚 DERS: Completer ile dosya secim sonucunu bekle
    // onChange listener yerine Completer kullaniyoruz
    // boylece async/await duzenli calisir
    final filesCompleter = Completer<List<html.File>>();

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        if (!filesCompleter.isCompleted) {
          filesCompleter.complete(files.toList());
        }
      } else {
        if (!filesCompleter.isCompleted) {
          filesCompleter.complete([]);
        }
      }
    });

    // 📚 DERS: Iptal durumunu yakala!
    // Kullanici dosya secmeden pencereyi kapatirsa onChange TETIKLENMEZ.
    // Bu durumda Completer sonsuza kadar bekler ve sonraki tiklamalar calismaz.
    // Cozum: window'un focus event'ini dinle.
    // Dosya secme penceresi kapaninca (sec veya iptal) window tekrar focus alir.
    // Kisa bir gecikme sonrasi Completer hala tamamlanmadiysa iptal edilmis demektir.
    html.window.addEventListener('focus', (event) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!filesCompleter.isCompleted) {
          filesCompleter.complete([]);
        }
      });
    });

    // Dosya secme dialogunu ac
    uploadInput.click();

    // Dosya secilmesini bekle
    final seciliDosyalar = await filesCompleter.future;

    // 📚 DERS: Elementi DOM'dan temizle (bellek sizintisi onlenir)
    uploadInput.remove();

    if (seciliDosyalar.isEmpty) return;

    // Aciklama dialogu
    final aciklama = await _aciklamaDialogu();

    setState(() => _dosyaYukleniyor = true);

    int basarili = 0;
    int basarisiz = 0;

    for (final file in seciliDosyalar) {
      try {
        // 📚 DERS: Dosyayi oku
        // FileReader.readAsArrayBuffer ile binary data okunur
        final bytes = await _dosyaOku(file);

        await _apiService.dokumanYukle(
          kaynakTipi: widget.kaynakTipi,
          kaynakId: widget.kaynakId,
          dosyaBytes: bytes,
          dosyaAdi: file.name,
          aciklama: aciklama,
        );
        basarili++;
      } catch (e) {
        basarisiz++;
        debugPrint('Dosya yukleme hatasi: ${file.name} -> $e');
      }
    }

    setState(() => _dosyaYukleniyor = false);

    if (mounted) {
      if (basarili > 0 && basarisiz == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$basarili dosya basariyla yuklendi'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (basarisiz > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$basarili yuklendi, $basarisiz basarisiz'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      _dokumanlariYukle(); // Listeyi guncelle
    }
  }

  // =============================================
  // DOSYA OKU (helper)
  // 📚 DERS: html.File'i List<int> bytes'a cevirir.
  // FileReader.readAsArrayBuffer() kullanir.
  // =============================================
  Future<List<int>> _dosyaOku(html.File file) async {
    final completer = Completer<List<int>>();
    final reader = html.FileReader();

    reader.onLoadEnd.listen((event) {
      try {
        // 📚 DERS: reader.result tipi platform/tarayiciya gore degisir
        // ByteBuffer, Uint8List veya NativeByteBuffer olabilir
        final result = reader.result;
        if (result is Uint8List) {
          completer.complete(result.toList());
        } else {
          // ByteBuffer veya NativeByteBuffer icin
          final byteList = (result as dynamic);
          completer.complete(List<int>.from(Uint8List.view(byteList)));
        }
      } catch (e) {
        completer.completeError('Dosya okunamadi: $e');
      }
    });

    reader.onError.listen((event) {
      completer.completeError('Dosya okuma hatasi: ${file.name}');
    });

    reader.readAsArrayBuffer(file);
    return completer.future;
  }

  // Aciklama dialogu
  Future<String?> _aciklamaDialogu() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description, color: Colors.blue),
            SizedBox(width: 8),
            Text('Dokuman Aciklamasi', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Ornek: Vergi levhasi 2025, Risk degerlendirme raporu...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            maxLines: 2,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null), // Aciklama olmadan devam
            child: const Text('Atla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  // =============================================
  // DOSYA INDIR
  // 📚 DERS: Web'de dosya indirme iki yontemle yapilabilir:
  //
  // Yontem 1: Token'li URL ile yeni sekmede ac (basit, guvenilir)
  //   - Backend'e token query param olarak eklenir
  //   - Tarayici dosyayi dogrudan indirir
  //
  // Yontem 2: Blob download (API'den bytes al, Blob olustur)
  //   - Daha karmasik ama Authorization header kullanir
  //
  // Biz Yontem 1'i kullaniyoruz cunku daha guvenilir.
  // =============================================
  Future<void> _dosyaIndir(Map<String, dynamic> dokuman) async {
    try {
      // 📚 DERS: Token'i URL'e ekleyerek dogrudan tarayicidan indirme
      // Bu yontem en guvenilir cunku tarayici kendi indirme mekanizmasini kullanir
      final token = ApiService.tokenGetir();
      final baseUrl = _apiService.dokumanIndirUrl(dokuman['id']);
      final indirmeUrl = '$baseUrl?t=$token';

      // Gizli bir <a> etiketi olustur ve tikla
      html.AnchorElement(href: indirmeUrl)
        ..setAttribute('download', dokuman['dosya_adi'] ?? 'dosya')
        ..click();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Indirme hatasi: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // =============================================
  // DOSYA SIL
  // =============================================
  Future<void> _dosyaSil(Map<String, dynamic> dokuman) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Dokuman Sil', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text('"${dokuman['dosya_adi']}" silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (onay != true) return;

    try {
      await _apiService.dokumanSil(dokuman['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokuman silindi'), backgroundColor: Colors.green),
        );
        _dokumanlariYukle();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  // =============================================
  // DOSYA BOYUTUNU FORMATLA
  // 📚 DERS: Byte'i KB/MB olarak gosterir
  // =============================================
  String _boyutFormatla(int? boyut) {
    if (boyut == null) return '-';
    if (boyut < 1024) return '$boyut B';
    if (boyut < 1024 * 1024) return '${(boyut / 1024).toStringAsFixed(1)} KB';
    return '${(boyut / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Dosya tipine gore ikon
  IconData _dosyaIkonu(String? dosyaTipi, String? dosyaAdi) {
    final uzanti = dosyaAdi?.split('.').last.toLowerCase() ?? '';

    if (dosyaTipi?.contains('pdf') == true || uzanti == 'pdf') {
      return Icons.picture_as_pdf;
    }
    if (dosyaTipi?.contains('image') == true || ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].contains(uzanti)) {
      return Icons.image;
    }
    if (dosyaTipi?.contains('spreadsheet') == true || ['xls', 'xlsx', 'csv', 'ods'].contains(uzanti)) {
      return Icons.table_chart;
    }
    if (dosyaTipi?.contains('word') == true || ['doc', 'docx', 'odt', 'rtf'].contains(uzanti)) {
      return Icons.article;
    }
    if (dosyaTipi?.contains('presentation') == true || ['ppt', 'pptx', 'odp'].contains(uzanti)) {
      return Icons.slideshow;
    }
    if (['zip', 'rar', '7z'].contains(uzanti)) {
      return Icons.archive;
    }
    if (['dwg', 'dxf'].contains(uzanti)) {
      return Icons.architecture;
    }
    return Icons.insert_drive_file;
  }

  // Dosya tipine gore renk
  Color _dosyaRengi(String? dosyaTipi, String? dosyaAdi) {
    final uzanti = dosyaAdi?.split('.').last.toLowerCase() ?? '';

    if (dosyaTipi?.contains('pdf') == true || uzanti == 'pdf') return Colors.red;
    if (dosyaTipi?.contains('image') == true || ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].contains(uzanti)) return Colors.blue;
    if (['xls', 'xlsx', 'csv', 'ods'].contains(uzanti)) return Colors.green;
    if (['doc', 'docx', 'odt', 'rtf'].contains(uzanti)) return Colors.indigo;
    if (['ppt', 'pptx', 'odp'].contains(uzanti)) return Colors.orange;
    if (['zip', 'rar', '7z'].contains(uzanti)) return Colors.brown;
    return Colors.grey;
  }

  // Tarih formatla
  String _tarihFormatla(String? tarih) {
    if (tarih == null) return '-';
    try {
      final dt = DateTime.parse(tarih);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return tarih;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- BASLIK VE YUKLE BUTONU ----
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.attach_file, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Dokumanlar (${_dokumanlar.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _dosyaYukleniyor ? null : _dosyaSec,
                icon: _dosyaYukleniyor
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file, size: 18),
                label: Text(_dosyaYukleniyor ? 'Yukleniyor...' : 'Dosya Yukle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ---- ICERIK ----
        if (_yukleniyor)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_dokumanlar.isEmpty)
          // Bos durum
          Padding(
            padding: const EdgeInsets.all(48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_upload, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Henuz dokuman eklenmemis',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"Dosya Yukle" butonuyla dokuman ekleyebilirsiniz',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          )
        else
          // Dokuman listesi
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _dokumanlar.length,
            itemBuilder: (context, index) {
              final dok = _dokumanlar[index];
              final dosyaAdi = dok['dosya_adi'] ?? 'Dosya';
              final dosyaTipi = dok['dosya_tipi'] as String?;
              final ikon = _dosyaIkonu(dosyaTipi, dosyaAdi);
              final renk = _dosyaRengi(dosyaTipi, dosyaAdi);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: renk.withAlpha(30),
                    child: Icon(ikon, color: renk, size: 22),
                  ),
                  title: Text(
                    dosyaAdi,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dok['aciklama'] != null && dok['aciklama'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            dok['aciklama'],
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        '${_boyutFormatla(dok['dosya_boyutu'])}  •  ${_tarihFormatla(dok['olusturma_tarihi'])}  •  ${dok['yukleyen_adi'] ?? '-'}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Indir butonu
                      IconButton(
                        icon: const Icon(Icons.download, size: 20),
                        color: Colors.blue[700],
                        tooltip: 'Indir',
                        onPressed: () => _dosyaIndir(dok),
                      ),
                      // Sil butonu
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: Colors.red[400],
                        tooltip: 'Sil',
                        onPressed: () => _dosyaSil(dok),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: 16),
      ],
    );
  }
}
