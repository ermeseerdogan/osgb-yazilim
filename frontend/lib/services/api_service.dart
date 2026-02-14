// =============================================
// API SERVICE - Backend ile iletisim
// =============================================
//
// 📚 DERS: Bu dosya tum API isteklerini yonetir.
// Python'daki "requests" kutuphanesi gibi dusun.
//
// Dio paketi kullaniyoruz:
// - HTTP istekleri gonderir (GET, POST, PUT, DELETE)
// - JSON otomatik cevirir
// - Hata yonetimi yapar
// - Token'i otomatik ekler (interceptor)

import 'package:dio/dio.dart';

// 📚 DERS: Hata mesajlarini kullanici dostu Turkce'ye ceviren yardimci
// Backend'den gelen teknik/ingilizce hatalari anlasilir hale getiriyoruz
String _kullaniciDostuHata(DioException e) {
  // Sunucuya hic ulasilamadiysa
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return 'Sunucu cevap vermiyor. Lutfen biraz bekleyip tekrar deneyin.';
  }
  if (e.type == DioExceptionType.connectionError) {
    return 'Sunucuya baglanilamiyor. Internet baglantinizi ve backend\'in calistigini kontrol edin.';
  }

  // Sunucudan cevap geldiyse
  if (e.response != null) {
    final statusCode = e.response?.statusCode ?? 0;
    final data = e.response?.data;

    // Backend'in gonderdigi "detail" mesaji
    String? detail;
    if (data is Map) {
      detail = data['detail']?.toString();
    }

    // Status koduna gore Turkce mesaj
    switch (statusCode) {
      case 400:
        return detail ?? 'Gonderdigeniz bilgilerde hata var. Lutfen kontrol edip tekrar deneyin.';
      case 401:
        return detail ?? 'Oturum suresi dolmus. Lutfen tekrar giris yapin.';
      case 403:
        return detail ?? 'Bu islemi yapmaya yetkiniz bulunmuyor.';
      case 404:
        return detail ?? 'Aradiginiz kayit bulunamadi. Silinmis veya tasinmis olabilir.';
      case 409:
        return detail ?? 'Bu kayit zaten mevcut.';
      case 422:
        // 📚 DERS: 422 = Pydantic validation hatasi
        // Backend'den gelen teknik Ingilizce mesajlari Turkce'ye ceviriyoruz
        if (data is Map && data['detail'] is List) {
          final hatalar = (data['detail'] as List).map((h) {
            final alan = (h['loc'] as List?)?.last?.toString() ?? '';
            final msg = h['msg']?.toString() ?? '';
            return _validasyonMesajiTurkce(alan, msg);
          }).where((m) => m.isNotEmpty).join('\n');
          return hatalar.isNotEmpty ? hatalar : 'Formda hatali alanlar var.';
        }
        return 'Formda eksik veya hatali alanlar var. Lutfen kontrol edin.';
      case 500:
        return 'Sunucuda beklenmeyen bir hata olustu. Lutfen daha sonra tekrar deneyin.';
      default:
        return detail ?? 'Bir hata olustu (Kod: $statusCode). Lutfen tekrar deneyin.';
    }
  }

  return 'Baglanti hatasi. Lutfen internet baglantinizi kontrol edin.';
}

// 📚 DERS: Backend'den gelen Ingilizce validasyon mesajlarini Turkce'ye cevir
// Pydantic hatalari "value is not a valid email address" gibi gelir
// Biz bunu "Email adresi gecersiz" diye gosteriyoruz
String _validasyonMesajiTurkce(String alan, String mesaj) {
  // Alan adini Turkce'ye cevir
  final alanTurkce = {
    'email': 'Email',
    'ad': 'Firma adi',
    'il': 'Il',
    'ilce': 'Ilce',
    'telefon': 'Telefon',
    'sifre': 'Sifre',
    'vergi_no': 'Vergi numarasi',
    'vergi_dairesi': 'Vergi dairesi',
  }[alan] ?? alan;

  // Mesaji Turkce'ye cevir
  if (mesaj.contains('not a valid email')) {
    return '$alanTurkce gecerli bir email adresi degil. Ornek: info@firma.com';
  }
  if (mesaj.contains('required') || mesaj.contains('missing')) {
    return '$alanTurkce alani zorunludur.';
  }
  if (mesaj.contains('at least') || mesaj.contains('too short')) {
    return '$alanTurkce cok kisa.';
  }
  if (mesaj.contains('at most') || mesaj.contains('too long')) {
    return '$alanTurkce cok uzun.';
  }
  if (mesaj.contains('not a valid')) {
    return '$alanTurkce gecersiz formatta.';
  }

  return '$alanTurkce: $mesaj';
}

class ApiService {
  // 📚 DERS: Singleton Pattern
  // Tum uygulamada tek bir ApiService instance'i olur.
  // Her yerden ayni instance'a erisirsin.
  // Python'da boyle bir sey yok, Dart'a ozel kalip.
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Dio: HTTP istemcisi (Python'daki requests gibi)
  final Dio _dio = Dio(
    BaseOptions(
      // API'nin adresi (backend port'u)
      baseUrl: 'http://62.171.185.38:8001/api/v1',
      // Timeout: 10 saniye icinde cevap gelmezse hata ver
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      // JSON olarak gonder/al
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // JWT Token (giris yapilinca doldurulur)
  String? _token;

  // Kullanici bilgileri (giris yapilinca doldurulur)
  Map<String, dynamic>? _kullaniciBilgi;

  // 📚 DERS: Kullanicinin dis (public/internet) IP adresi
  // Kullanici uygulamayi actiginda api.ipify.org'dan ogrenilir
  // ve her istekte backend'e X-Client-Public-IP header'i ile gonderilir.
  // Boylece backend, kullanicinin gercek internet IP'sini loglar.
  String? _disIp;

  // Getter'lar (disaridan okumak icin)
  String? get token => _token;
  Map<String, dynamic>? get kullaniciBilgi => _kullaniciBilgi;
  String? get disIp => _disIp;
  bool get girisYapildiMi => _token != null;

  // 📚 DERS: Static getter - Singleton uzerinden token'a erisim
  // Dosya indirme gibi islemlerde URL'e token eklemek icin kullanilir
  static String? tokenGetir() => _instance._token;

  // =============================================
  // KULLANICININ DIS IP ADRESINI OGREN
  // 📚 DERS: Bu fonksiyon kullanicinin internet IP'sini bulur.
  // api.ipify.org = ucretsiz, basit bir "IP'n ne?" servisi.
  // Kullanici tarayicidan bu siteye istek atar, site IP'yi dondurur.
  // Boylece backend sunucusunun degil, KULLANICININ IP'si loglanir.
  // =============================================
  Future<void> disIpOgren() async {
    try {
      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      ).get('https://api.ipify.org?format=json');

      if (response.statusCode == 200) {
        _disIp = response.data['ip'];
        // Her istekte bu header'i gonder
        _dio.options.headers['X-Client-Public-IP'] = _disIp;
      }
    } catch (e) {
      // 📚 DERS: Dis IP alinamazsa uygulama DURMASIN!
      // Internet yok veya ipify cevap vermiyorsa sorun degil,
      // sadece dis IP loglanamazsa null olarak kalir.
      _disIp = null;
    }
  }

  // =============================================
  // GIRIS YAP
  // POST /api/v1/auth/login/json
  // =============================================
  Future<Map<String, dynamic>> girisYap(String email, String sifre) async {
    // 📚 DERS: try-catch ile hata yakalama
    // Python'daki try-except ile ayni mantik
    try {
      // 📚 DERS: Giris yapmadan once kullanicinin dis IP'sini ogren
      // Bu IP, backend tarafinda log'a kaydedilecek
      await disIpOgren();

      // POST istegi gonder
      final response = await _dio.post(
        '/auth/login/json',
        data: {
          'email': email,
          'sifre': sifre,
        },
      );

      // 📚 DERS: response.data otomatik olarak JSON'dan Map'e cevirilir
      // Python'da response.json() yaparsin, burada otomatik
      final data = response.data as Map<String, dynamic>;

      // Token'i sakla
      _token = data['access_token'];
      _kullaniciBilgi = data['kullanici'];

      // Bundan sonraki isteklere token ekle
      _dio.options.headers['Authorization'] = 'Bearer $_token';

      return data;
    } on DioException catch (e) {
      // 📚 DERS: DioException = HTTP hatasi
      // Kullanici dostu Turkce mesaj goster
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // =============================================
  // CIKIS YAP
  // =============================================
  void cikisYap() {
    _token = null;
    _kullaniciBilgi = null;
    _dio.options.headers.remove('Authorization');
  }

  // =============================================
  // FIRMA ISLEMLERI
  // =============================================

  // Firma listesi getir
  Future<Map<String, dynamic>> firmaListele({
    int sayfa = 1,
    int adet = 20,
    String? arama,
  }) async {
    try {
      final params = <String, dynamic>{
        'sayfa': sayfa,
        'adet': adet,
      };
      if (arama != null && arama.isNotEmpty) {
        params['arama'] = arama;
      }

      final response = await _dio.get('/firma', queryParameters: params);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Yeni firma ekle
  Future<Map<String, dynamic>> firmaEkle(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/firma', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Firma guncelle
  Future<Map<String, dynamic>> firmaGuncelle(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put('/firma/$id', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Firma sil (pasife cek)
  Future<void> firmaSil(int id) async {
    try {
      await _dio.delete('/firma/$id');
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // =============================================
  // EXCEL ISLEMLERI
  // 📚 DERS: Excel export/import/sablon islemleri
  // Backend'den dosya (bytes) indirme ve yukleme
  // =============================================

  // Excel export - firmalari Excel olarak indir
  Future<List<int>> firmaExcelExport({String? arama}) async {
    try {
      final params = <String, dynamic>{};
      if (arama != null && arama.isNotEmpty) {
        params['arama'] = arama;
      }
      final response = await _dio.get(
        '/firma/excel/export',
        queryParameters: params,
        options: Options(responseType: ResponseType.bytes),
      );
      return List<int>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Excel sablon indir
  Future<List<int>> firmaExcelSablon() async {
    try {
      final response = await _dio.get(
        '/firma/excel/sablon',
        options: Options(responseType: ResponseType.bytes),
      );
      return List<int>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Excel import - dosyadan toplu firma yukle
  Future<Map<String, dynamic>> firmaExcelImport(List<int> dosyaBytes, String dosyaAdi) async {
    try {
      final formData = FormData.fromMap({
        'dosya': MultipartFile.fromBytes(dosyaBytes, filename: dosyaAdi),
      });
      final response = await _dio.post('/firma/excel/import', data: formData);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // =============================================
  // LOG ISLEMLERI
  // =============================================

  // Log listesi getir
  // 📚 DERS: kayitTuru ve kayitId parametreleri
  // Belirli bir kaydın loglarini gormek icin kullanilir
  // Ornek: logListele(kayitTuru: 'Firma', kayitId: 5)
  // -> Sadece Firma ID:5 ile ilgili loglari getirir
  Future<Map<String, dynamic>> logListele({
    int sayfa = 1,
    int adet = 50,
    String? modul,
    String? islemTuru,
    bool? basarili,
    int? sonGun,
    String? kayitTuru,
    int? kayitId,
  }) async {
    try {
      final params = <String, dynamic>{
        'sayfa': sayfa,
        'adet': adet,
      };
      if (modul != null) params['modul'] = modul;
      if (islemTuru != null) params['islem_turu'] = islemTuru;
      if (basarili != null) params['basarili'] = basarili;
      if (sonGun != null) params['son_gun'] = sonGun;
      if (kayitTuru != null) params['kayit_turu'] = kayitTuru;
      if (kayitId != null) params['kayit_id'] = kayitId;

      final response = await _dio.get('/log', queryParameters: params);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Log ozeti getir
  Future<Map<String, dynamic>> logOzet({int sonGun = 7}) async {
    try {
      final response = await _dio.get('/log/ozet', queryParameters: {'son_gun': sonGun});
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // =============================================
  // ISYERI ISLEMLERI
  // 📚 DERS: Firma islemleriyle ayni mantik.
  // Ek olarak firma_id filtresi var.
  // =============================================

  // Isyeri listesi getir
  Future<Map<String, dynamic>> isyeriListele({
    int sayfa = 1,
    int adet = 20,
    String? arama,
    int? firmaId,
  }) async {
    try {
      final params = <String, dynamic>{
        'sayfa': sayfa,
        'adet': adet,
      };
      if (arama != null && arama.isNotEmpty) {
        params['arama'] = arama;
      }
      if (firmaId != null) {
        params['firma_id'] = firmaId;
      }

      final response = await _dio.get('/isyeri', queryParameters: params);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Yeni isyeri ekle
  Future<Map<String, dynamic>> isyeriEkle(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/isyeri', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Isyeri guncelle
  Future<Map<String, dynamic>> isyeriGuncelle(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put('/isyeri/$id', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Isyeri sil (pasife cek)
  Future<void> isyeriSil(int id) async {
    try {
      await _dio.delete('/isyeri/$id');
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Isyeri Excel export
  Future<List<int>> isyeriExcelExport({String? arama, int? firmaId}) async {
    try {
      final params = <String, dynamic>{};
      if (arama != null && arama.isNotEmpty) {
        params['arama'] = arama;
      }
      if (firmaId != null) {
        params['firma_id'] = firmaId;
      }
      final response = await _dio.get(
        '/isyeri/excel/export',
        queryParameters: params,
        options: Options(responseType: ResponseType.bytes),
      );
      return List<int>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Isyeri Excel sablon indir
  Future<List<int>> isyeriExcelSablon() async {
    try {
      final response = await _dio.get(
        '/isyeri/excel/sablon',
        options: Options(responseType: ResponseType.bytes),
      );
      return List<int>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Isyeri Excel import
  Future<Map<String, dynamic>> isyeriExcelImport(List<int> dosyaBytes, String dosyaAdi) async {
    try {
      final formData = FormData.fromMap({
        'dosya': MultipartFile.fromBytes(dosyaBytes, filename: dosyaAdi),
      });
      final response = await _dio.post('/isyeri/excel/import', data: formData);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Firma listesi getir (dropdown icin - sadece id ve ad)
  // 📚 DERS: Isyeri formunda firma secimi icin kullanilir
  Future<List<Map<String, dynamic>>> firmaListesiGetir() async {
    try {
      final response = await _dio.get('/firma', queryParameters: {'adet': 100});
      final data = response.data as Map<String, dynamic>;
      final firmalar = (data['firmalar'] as List)
          .map((f) => {'id': f['id'], 'ad': f['ad']})
          .toList();
      return firmalar;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // =============================================
  // CALISAN ISLEMLERI
  // 📚 DERS: Isyeri islemleriyle ayni mantik.
  // Ek olarak isyeri_id filtresi var.
  // Bir isyerindeki calisanlari listelerken isyeriId gonderilir.
  // =============================================

  // Calisan listesi getir
  // 📚 DERS: isyeriId parametresi ile belirli isyerinin
  // calisanlarini filtreleyebiliriz.
  Future<Map<String, dynamic>> calisanListele({
    int sayfa = 1,
    int adet = 20,
    String? arama,
    int? isyeriId,
  }) async {
    try {
      final params = <String, dynamic>{
        'sayfa': sayfa,
        'adet': adet,
      };
      if (arama != null && arama.isNotEmpty) {
        params['arama'] = arama;
      }
      if (isyeriId != null) {
        params['isyeri_id'] = isyeriId;
      }

      final response = await _dio.get('/calisan', queryParameters: params);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Yeni calisan ekle
  Future<Map<String, dynamic>> calisanEkle(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/calisan', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Calisan guncelle
  Future<Map<String, dynamic>> calisanGuncelle(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put('/calisan/$id', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Calisan sil (pasife cek)
  // 📚 DERS: Gercek silme yapmiyoruz, aktif=False yapiyoruz
  Future<void> calisanSil(int id) async {
    try {
      await _dio.delete('/calisan/$id');
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Calisan Excel export
  Future<List<int>> calisanExcelExport({String? arama, int? isyeriId}) async {
    try {
      final params = <String, dynamic>{};
      if (arama != null && arama.isNotEmpty) {
        params['arama'] = arama;
      }
      if (isyeriId != null) {
        params['isyeri_id'] = isyeriId;
      }
      final response = await _dio.get(
        '/calisan/excel/export',
        queryParameters: params,
        options: Options(responseType: ResponseType.bytes),
      );
      return List<int>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Calisan Excel sablon indir
  Future<List<int>> calisanExcelSablon() async {
    try {
      final response = await _dio.get(
        '/calisan/excel/sablon',
        options: Options(responseType: ResponseType.bytes),
      );
      return List<int>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Calisan Excel import
  // 📚 DERS: isyeriId zorunlu! Excel'den yuklenen calisanlar
  // hangi isyerine ait oldugunu bilmeli.
  Future<Map<String, dynamic>> calisanExcelImport(
    List<int> dosyaBytes,
    String dosyaAdi,
    int isyeriId,
  ) async {
    try {
      final formData = FormData.fromMap({
        'dosya': MultipartFile.fromBytes(dosyaBytes, filename: dosyaAdi),
      });
      final response = await _dio.post(
        '/calisan/excel/import?isyeri_id=$isyeriId',
        data: formData,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Isyeri listesi getir (dropdown icin - sadece id ve ad)
  // 📚 DERS: Calisan formunda isyeri secimi icin kullanilir
  Future<List<Map<String, dynamic>>> isyeriListesiGetir() async {
    try {
      final response = await _dio.get('/isyeri', queryParameters: {'adet': 100});
      final data = response.data as Map<String, dynamic>;
      final isyerleri = (data['isyerleri'] as List)
          .map((i) => {'id': i['id'], 'ad': i['ad']})
          .toList();
      return isyerleri;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // =============================================
  // DOKUMAN ISLEMLERI
  // 📚 DERS: Polimorfik dokuman sistemi.
  // Tum moduller (firma, isyeri, calisan vs.) ayni metodlari kullanir.
  // kaynakTipi = "firma", "isyeri" vs.
  // kaynakId = ilgili kaydin ID'si
  // =============================================

  // Dokuman listesi getir
  Future<Map<String, dynamic>> dokumanListele(String kaynakTipi, int kaynakId) async {
    try {
      final response = await _dio.get('/dokuman/$kaynakTipi/$kaynakId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Dokuman yukle (dosya + aciklama)
  // 📚 DERS: MultipartFile ile dosya yukleme
  // Web'de dosya secimi dart:html ile yapilir,
  // secilen dosyanin bytes'lari buraya gelir.
  Future<Map<String, dynamic>> dokumanYukle({
    required String kaynakTipi,
    required int kaynakId,
    required List<int> dosyaBytes,
    required String dosyaAdi,
    String? aciklama,
  }) async {
    try {
      // 📚 DERS: MultipartFile ile dosya gonderimi
      // Content-Type otomatik olarak multipart/form-data olur
      final formData = FormData.fromMap({
        'dosya': MultipartFile.fromBytes(dosyaBytes, filename: dosyaAdi),
        if (aciklama != null && aciklama.isNotEmpty) 'aciklama': aciklama,
      });
      final response = await _dio.post(
        '/dokuman/$kaynakTipi/$kaynakId/yukle',
        data: formData,
        // 📚 DERS: Dosya yukleme icin timeout'u artiriyoruz
        // Buyuk dosyalar uzun surebilir, normal 10sn yetmez
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Dokuman indir (bytes olarak)
  // 📚 DERS: Path degisti: /dokuman/indir/{id}
  // Cunku /dokuman/{kaynak_tipi}/{kaynak_id} ile cakisiyordu!
  Future<List<int>> dokumanIndir(int dokumanId) async {
    try {
      final response = await _dio.get(
        '/dokuman/indir/$dokumanId',
        options: Options(responseType: ResponseType.bytes),
      );
      return List<int>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // Dokuman indirme URL'i (tarayicida yeni sekmede acmak icin)
  String dokumanIndirUrl(int dokumanId) {
    return 'http://62.171.185.38:8001/api/v1/dokuman/indir/$dokumanId';
  }

  // Dokuman sil
  Future<void> dokumanSil(int dokumanId) async {
    try {
      await _dio.delete('/dokuman/$dokumanId');
    } on DioException catch (e) {
      throw Exception(_kullaniciDostuHata(e));
    }
  }

  // =============================================
  // API DURUM KONTROLU
  // =============================================
  Future<bool> apiDurumKontrol() async {
    try {
      final response = await Dio().get('http://62.171.185.38:8001/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
