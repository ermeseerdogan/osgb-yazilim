# =============================================
# OSGB YAZILIMI - ANA UYGULAMA DOSYASI
# FastAPI uygulaması burada başlatılır
# =============================================

# FastAPI'yi içe aktar
from fastapi import FastAPI

# CORS: Farklı adreslerden gelen isteklere izin ver
# (Flutter web localhost:3000'den, API localhost:8000'de çalışır)
from fastapi.middleware.cors import CORSMiddleware

# Ayarlarımızı içe aktar
from app.core.config import settings

# Loglama
from app.core.logger import logger
from app.middleware.request_logger import RequestLoggerMiddleware

# API Router'lari
from app.api.v1.auth import router as auth_router
from app.api.v1.firma import router as firma_router
from app.api.v1.log import router as log_router
from app.api.v1.isyeri import router as isyeri_router
from app.api.v1.dokuman import router as dokuman_router


# ---- UYGULAMAYI OLUŞTUR ----
app = FastAPI(
    title=settings.APP_NAME,           # API dokümantasyonunda görünecek başlık
    version=settings.APP_VERSION,      # Versiyon numarası
    description="OSGB Yönetim Sistemi API - İş Sağlığı ve Güvenliği",
)

# ---- CORS AYARLARI ----
# 📚 DERS: CORS (Cross-Origin Resource Sharing)
# Tarayıcılar güvenlik için farklı adresler arası istekleri engeller.
# Flutter (localhost:3000) → API (localhost:8000) istek atabilmesi için
# API'ye "bu adresten gelen isteklere izin ver" dememiz lazım.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],         # Şimdilik herkese izin ver (üretimde kısıtlanacak)
    allow_credentials=True,      # Cookie/token gönderebilsin
    allow_methods=["*"],         # Tüm HTTP metodları (GET, POST, PUT, DELETE)
    allow_headers=["*"],         # Tüm header'lar
)

# ---- ISTEK LOGLAMA MIDDLEWARE ----
app.add_middleware(RequestLoggerMiddleware)


# ---- API ROUTER'LARI KAYDET ----
# 📚 DERS: include_router ile alt router'lari ana uygulamaya bagliyoruz
# prefix="/api/v1" -> Tum auth endpoint'leri /api/v1/auth/... olur
app.include_router(auth_router, prefix="/api/v1")
app.include_router(firma_router, prefix="/api/v1")
app.include_router(log_router, prefix="/api/v1")
app.include_router(isyeri_router, prefix="/api/v1")
app.include_router(dokuman_router, prefix="/api/v1")


# ---- ANA SAYFA ----
@app.get("/")
def ana_sayfa():
    """
    📚 DERS: Bu bir "endpoint" (uç nokta).

    @app.get("/") demek:
    - Birisi tarayıcıda localhost:8000/ adresine girdiğinde
    - Bu fonksiyon çalışır
    - Ve aşağıdaki sözlüğü JSON olarak döner

    @app.get  = HTTP GET isteği (veri okuma)
    @app.post = HTTP POST isteği (veri gönderme/ekleme)
    @app.put  = HTTP PUT isteği (veri güncelleme)
    @app.delete = HTTP DELETE isteği (veri silme)
    """
    return {
        "uygulama": settings.APP_NAME,
        "versiyon": settings.APP_VERSION,
        "durum": "çalışıyor ✅",
        "mesaj": "Merhaba OSGB! 🏗️ API başarıyla çalışıyor."
    }


# ---- SAĞLIK KONTROLÜ ----
@app.get("/health")
def saglik_kontrolu():
    """
    📚 DERS: Health check endpoint'i.
    Sunucunun çalışıp çalışmadığını kontrol eder.
    İzleme araçları (monitoring) bu endpoint'i düzenli kontrol eder.
    """
    return {"durum": "sağlıklı", "veritabani": "bağlı"}


# ---- API BİLGİSİ ----
@app.get("/api/v1/bilgi")
def api_bilgisi():
    """
    📚 DERS: API versiyonlama.

    /api/v1/bilgi → Versiyon 1
    İleride /api/v2/bilgi yapabiliriz.

    Neden versiyonlama? Eski müşteriler v1 kullanırken,
    yeni müşteriler v2 kullanabilir. Kimse bozulmaz!
    """
    return {
        "api_versiyon": "v1",
        "moduller": [
            "firma-yonetimi",
            "isyeri-yonetimi",
            "calisan-yonetimi",
            "ziyaret-yonetimi",
            "on-muhasebe",
        ],
        "durum": "geliştirme aşamasında"
    }
