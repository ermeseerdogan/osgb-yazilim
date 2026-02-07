# =============================================
# UYGULAMA AYARLARI
# Tüm konfigürasyon burada toplanır
# =============================================

# pydantic_settings: .env dosyasından ayarları otomatik okur
from pydantic_settings import BaseSettings
from urllib.parse import quote_plus


class Settings(BaseSettings):
    """
    📚 DERS: Bu sınıf uygulamanın tüm ayarlarını tutar.

    BaseSettings'ten türetilmiş (inherit edilmiş).
    Bu sayede .env dosyasındaki değerleri otomatik okur.

    Örnek: .env dosyasında DATABASE_HOST=localhost yazarsan,
    settings.DATABASE_HOST otomatik olarak "localhost" olur.
    """

    # --- UYGULAMA ---
    APP_NAME: str = "OSGB Yönetim Sistemi"  # Uygulamanın adı
    APP_VERSION: str = "0.1.0"               # Versiyon numarası
    DEBUG: bool = True                        # Geliştirme modunda mı? (True = evet)

    # --- VERİTABANI (PostgreSQL) ---
    DATABASE_HOST: str = "localhost"          # Veritabanı adresi
    DATABASE_PORT: int = 5432                 # Veritabanı portu
    DATABASE_USER: str = "postgres"           # Kullanıcı adı
    DATABASE_PASSWORD: str = ""               # Şifre (.env'den okunacak)
    DATABASE_NAME: str = "osgb_master"        # Ana veritabanı adı (master)

    @property
    def DATABASE_URL(self) -> str:
        """
        📚 DERS: @property dekoratörü bir metodu değişken gibi kullanmamızı sağlar.

        settings.DATABASE_URL yazınca bu fonksiyon çalışır ve
        bağlantı URL'sini oluşturur.

        Sonuç: postgresql://postgres:şifre@localhost:5432/osgb_master
        """
        pwd = quote_plus(self.DATABASE_PASSWORD)
        return (
            f"postgresql://{self.DATABASE_USER}:{pwd}"
            f"@{self.DATABASE_HOST}:{self.DATABASE_PORT}/{self.DATABASE_NAME}"
        )

    @property
    def ASYNC_DATABASE_URL(self) -> str:
        """Async (asenkron) bağlantı için URL - daha hızlı"""
        pwd = quote_plus(self.DATABASE_PASSWORD)
        return (
            f"postgresql+asyncpg://{self.DATABASE_USER}:{pwd}"
            f"@{self.DATABASE_HOST}:{self.DATABASE_PORT}/{self.DATABASE_NAME}"
        )

    # --- GÜVENLİK ---
    SECRET_KEY: str = "gizli-anahtar-bunu-uretimde-degistir"  # JWT için gizli anahtar
    ALGORITHM: str = "HS256"                   # JWT şifreleme algoritması
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60      # Token süresi (dakika)

    # --- AYAR DOSYASI ---
    class Config:
        """
        📚 DERS: Config iç sınıfı pydantic'e ".env dosyasını oku" der.
        env_file = ".env" → backend/.env dosyasını arar
        """
        env_file = ".env"
        extra = "allow"


# Tek bir settings nesnesi oluştur (tüm uygulama bunu kullanır)
settings = Settings()
