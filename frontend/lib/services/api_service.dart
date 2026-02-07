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
      baseUrl: 'http://localhost:8002/api/v1',
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

  // Getter'lar (disaridan okumak icin)
  String? get token => _token;
  Map<String, dynamic>? get kullaniciBilgi => _kullaniciBilgi;
  bool get girisYapildiMi => _token != null;

  // =============================================
  // GIRIS YAP
  // POST /api/v1/auth/login/json
  // =============================================
  Future<Map<String, dynamic>> girisYap(String email, String sifre) async {
    // 📚 DERS: try-catch ile hata yakalama
    // Python'daki try-except ile ayni mantik
    try {
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
  // API DURUM KONTROLU
  // =============================================
  Future<bool> apiDurumKontrol() async {
    try {
      final response = await Dio().get('http://localhost:8002/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
