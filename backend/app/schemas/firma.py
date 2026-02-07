# =============================================
# FIRMA SCHEMALARI (Pydantic)
# Firma CRUD islemleri icin veri yapilari
# =============================================
#
# 📚 DERS: CRUD nedir?
# C = Create (Olustur)  -> POST /firma
# R = Read   (Oku)      -> GET /firma/{id}
# U = Update (Guncelle) -> PUT /firma/{id}
# D = Delete (Sil)      -> DELETE /firma/{id}
#
# Her islem icin farkli schema kullaniyoruz:
# FirmaCreate: Yeni firma olustururken gereken alanlar
# FirmaUpdate: Firma guncellerken degisebilecek alanlar
# FirmaResponse: API'nin dondurdugu firma bilgisi

from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


class FirmaCreate(BaseModel):
    """
    📚 DERS: Yeni firma olusturma istegi.

    Frontend su JSON'u gonderir:
    {
        "ad": "ABC Insaat Ltd.",
        "il": "Istanbul",
        "ilce": "Kadikoy",
        "email": "info@abcinsaat.com",
        "telefon": "0212 555 1234",
        "adres": "Kadikoy Mah. ...",
        "vergi_dairesi": "Kadikoy VD",
        "vergi_no": "1234567890"
    }
    """
    ad: str                              # Firma adi (zorunlu)
    kisa_ad: Optional[str] = None        # Kisa ad (opsiyonel)
    il: str                              # Il (zorunlu)
    ilce: str                            # Ilce (zorunlu)
    email: EmailStr                      # Email (zorunlu, format kontrol)
    telefon: str                         # Telefon (zorunlu)
    adres: Optional[str] = None          # Adres (opsiyonel)
    vergi_dairesi: Optional[str] = None  # Vergi dairesi
    vergi_no: Optional[str] = None       # Vergi numarasi


class FirmaUpdate(BaseModel):
    """
    📚 DERS: Firma guncelleme istegi.

    Tum alanlar Optional (opsiyonel):
    Sadece degisen alanlari gonder, gerisini bos birak.

    Ornek: Sadece telefonu degistirmek icin:
    {"telefon": "0216 444 5678"}
    """
    ad: Optional[str] = None
    kisa_ad: Optional[str] = None
    il: Optional[str] = None
    ilce: Optional[str] = None
    email: Optional[EmailStr] = None
    telefon: Optional[str] = None
    adres: Optional[str] = None
    vergi_dairesi: Optional[str] = None
    vergi_no: Optional[str] = None
    aktif: Optional[bool] = None


class FirmaResponse(BaseModel):
    """
    📚 DERS: API'nin dondurdugu firma bilgisi.

    model_config ile ORM modelden otomatik donusum yapilir.
    SQLAlchemy nesnesi -> Pydantic modeli -> JSON
    """
    id: int
    ad: str
    kisa_ad: Optional[str] = None
    il: str
    ilce: str
    email: str
    telefon: str
    adres: Optional[str] = None
    vergi_dairesi: Optional[str] = None
    vergi_no: Optional[str] = None
    logo_url: Optional[str] = None
    aktif: bool
    olusturma_tarihi: Optional[datetime] = None
    guncelleme_tarihi: Optional[datetime] = None

    model_config = {"from_attributes": True}
    # 📚 DERS: from_attributes = True
    # SQLAlchemy nesnesinden otomatik donusum yapar
    # Yani firma.ad, firma.email gibi attribute'leri alir


class FirmaListResponse(BaseModel):
    """Firma listesi yaniti (sayfalama ile)"""
    toplam: int                          # Toplam firma sayisi
    firmalar: list[FirmaResponse]        # Firma listesi
