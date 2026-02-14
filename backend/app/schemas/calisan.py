# =============================================
# CALISAN SCHEMALARI (Pydantic)
# Calisan CRUD islemleri icin veri yapilari
# =============================================
#
# Calisan = Bir isyerinde calisan personel.
# Bir isyerinin birden fazla calisani olabilir.
#
# CalisanCreate: Yeni calisan olustururken gereken alanlar
# CalisanUpdate: Calisan guncellerken degisebilecek alanlar
# CalisanResponse: API'nin dondurdugu calisan bilgisi

from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime, date


class CalisanCreate(BaseModel):
    """
    Yeni calisan olusturma istegi.

    Frontend su JSON'u gonderir:
    {
        "isyeri_id": 1,
        "ad": "Ahmet",
        "soyad": "Yilmaz",
        "tc_no": "12345678901",
        "telefon": "0532 555 1234",
        "email": "ahmet@firma.com",
        "dogum_tarihi": "1990-01-15",
        "ise_giris_tarihi": "2024-03-01",
        "gorev": "Operator",
        "bolum": "Uretim",
        "kan_grubu": "A+"
    }
    """
    isyeri_id: int                              # Hangi isyerine ait (zorunlu)
    ad: str                                     # Ad (zorunlu)
    soyad: str                                  # Soyad (zorunlu)
    tc_no: Optional[str] = None                 # TC kimlik no (opsiyonel ama unique)
    telefon: Optional[str] = None               # Telefon
    email: Optional[EmailStr] = None            # Email
    dogum_tarihi: Optional[date] = None         # Dogum tarihi
    ise_giris_tarihi: Optional[date] = None     # Ise giris tarihi
    gorev: Optional[str] = None                 # Gorev/pozisyon
    bolum: Optional[str] = None                 # Calistigi bolum
    kan_grubu: Optional[str] = None             # Kan grubu


class CalisanUpdate(BaseModel):
    """
    Calisan guncelleme istegi.
    Tum alanlar opsiyonel - sadece degisenleri gonder.
    """
    ad: Optional[str] = None
    soyad: Optional[str] = None
    tc_no: Optional[str] = None
    telefon: Optional[str] = None
    email: Optional[EmailStr] = None
    dogum_tarihi: Optional[date] = None
    ise_giris_tarihi: Optional[date] = None
    gorev: Optional[str] = None
    bolum: Optional[str] = None
    kan_grubu: Optional[str] = None
    aktif: Optional[bool] = None


class CalisanResponse(BaseModel):
    """
    API'nin dondurdugu calisan bilgisi.
    isyeri_adi ek alan olarak eklendi - listede isyeri adini gostermek icin.
    """
    id: int
    isyeri_id: int
    isyeri_adi: Optional[str] = None  # Isyeri adini da dondurelim (join)

    ad: str
    soyad: str
    tc_no: Optional[str] = None
    telefon: Optional[str] = None
    email: Optional[str] = None
    dogum_tarihi: Optional[date] = None
    ise_giris_tarihi: Optional[date] = None
    gorev: Optional[str] = None
    bolum: Optional[str] = None
    kan_grubu: Optional[str] = None

    profil_foto_url: Optional[str] = None

    aktif: bool
    olusturma_tarihi: Optional[datetime] = None
    guncelleme_tarihi: Optional[datetime] = None

    model_config = {"from_attributes": True}


class CalisanListResponse(BaseModel):
    """Calisan listesi yaniti (sayfalama ile)"""
    toplam: int
    calisanlar: list[CalisanResponse]
