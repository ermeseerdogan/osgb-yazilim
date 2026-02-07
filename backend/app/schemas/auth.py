# =============================================
# AUTH SCHEMALARI (Pydantic)
# API'ye gelen/giden verilerin yapisini tanimlar
# =============================================

# 📚 DERS: Pydantic nedir?
# Python'da veri dogrulamasi yapar.
# Kullanici "email" gondermedi mi? -> Hata verir.
# "email" yerine sayi gonderdi mi? -> Hata verir.
# Yani API'ye gelen verileri KONTROL EDER.

from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


# ---- GIRIS ISTEGI ----
class LoginRequest(BaseModel):
    """
    📚 DERS: Kullanici giris yaparken gonderdigi veri.

    Frontend soyle bir JSON gonderir:
    {
        "email": "admin@osgbyazilim.com",
        "sifre": "admin123"
    }

    Pydantic bu JSON'u otomatik kontrol eder:
    - email bos mu? -> Hata
    - sifre bos mu? -> Hata
    """
    email: EmailStr      # EmailStr: Gecerli email formati zorlar
    sifre: str           # Duz metin sifre (DB'deki hash ile karsilastirilacak)


# ---- TOKEN YANITI ----
class TokenResponse(BaseModel):
    """
    📚 DERS: Giris basarili olunca donen veri.

    Kullanici dogru email/sifre girince API su JSON'u doner:
    {
        "access_token": "eyJhbGciOiJ...",  # JWT token (uzun sifreli metin)
        "token_type": "bearer",             # Token tipi (her zaman "bearer")
        "kullanici": { ... }                # Kullanici bilgileri
    }

    Frontend bu token'i saklayip her istekte gonderir:
    Authorization: Bearer eyJhbGciOiJ...
    """
    access_token: str
    token_type: str = "bearer"
    kullanici: "KullaniciBilgi"


# ---- KULLANICI BILGI ----
class KullaniciBilgi(BaseModel):
    """
    📚 DERS: Token ile birlikte donen kullanici bilgileri.

    Frontend bu bilgileri kullanarak:
    - "Hosgeldin Sistem Admin" yazar
    - Role gore menu gosterir (admin daha fazla menu gorur)
    - Tenant bilgisine gore dogru DB'ye yonlendirir
    """
    id: int
    email: str
    ad: str
    soyad: str
    rol: str
    tenant_id: Optional[int] = None      # Sistem admin icin None
    tenant_ad: Optional[str] = None      # OSGB adi
    db_name: Optional[str] = None        # Tenant DB adi


# ---- SIFRE DEGISTIRME ----
class SifreDegistirRequest(BaseModel):
    """Sifre degistirme istegi"""
    mevcut_sifre: str
    yeni_sifre: str


# Pydantic model_rebuild: Iç içe referanslar için gerekli
TokenResponse.model_rebuild()
