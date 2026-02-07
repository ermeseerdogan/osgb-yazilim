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
      baseUrl: 'http://localhost:8001/api/v1',
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
      // 401 = Yanlis email/sifre
      // 403 = Hesap devre disi
      // 500 = Sunucu hatasi
      if (e.response != null) {
        final detail = e.response?.data['detail'] ?? 'Bilinmeyen hata';
        throw Exception(detail);
      }
      throw Exception('Sunucuya baglanilamadi. Backend calisiyor mu?');
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
      if (e.response != null) {
        throw Exception(e.response?.data['detail'] ?? 'Hata olustu');
      }
      throw Exception('Sunucuya baglanilamadi');
    }
  }

  // Yeni firma ekle
  Future<Map<String, dynamic>> firmaEkle(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/firma', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['detail'] ?? 'Hata olustu');
      }
      throw Exception('Sunucuya baglanilamadi');
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
      if (e.response != null) {
        throw Exception(e.response?.data['detail'] ?? 'Hata olustu');
      }
      throw Exception('Sunucuya baglanilamadi');
    }
  }

  // Firma sil (pasife cek)
  Future<void> firmaSil(int id) async {
    try {
      await _dio.delete('/firma/$id');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['detail'] ?? 'Hata olustu');
      }
      throw Exception('Sunucuya baglanilamadi');
    }
  }

  // =============================================
  // API DURUM KONTROLU
  // =============================================
  Future<bool> apiDurumKontrol() async {
    try {
      final response = await Dio().get('http://localhost:8001/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
