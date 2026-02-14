# =============================================
# PERSONEL SCHEMALARI (Pydantic)
# OSGB personeli CRUD islemleri icin veri yapilari
# =============================================
#
# Personel = OSGB'nin kendi calisanlari
# (ISG Uzmani, Isyeri Hekimi, DSP)
#
# PersonelCreate: Yeni personel olustururken gereken alanlar
# PersonelUpdate: Personel guncellerken degisebilecek alanlar
# PersonelResponse: API'nin dondurdugu personel bilgisi

from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime, date


class PersonelCreate(BaseModel):
    """
    Yeni personel olusturma istegi.

    Frontend su JSON'u gonderir:
    {
        "ad": "Ahmet",
        "soyad": "Yilmaz",
        "unvan": "isg_uzmani",
        "tc_no": "12345678901",
        "uzmanlik_sinifi": "b_sinifi",
        "uzmanlik_belgesi_no": "ISG-12345"
    }
    """
    ad: str
    soyad: str
    unvan: str  # "isg_uzmani", "isyeri_hekimi", "dsp"

    tc_no: Optional[str] = None
    telefon: Optional[str] = None
    email: Optional[EmailStr] = None

    uzmanlik_belgesi_no: Optional[str] = None
    diploma_no: Optional[str] = None
    uzmanlik_sinifi: Optional[str] = None  # "a_sinifi", "b_sinifi", "c_sinifi"
    brans: Optional[str] = None

    ise_baslama_tarihi: Optional[date] = None
    kullanici_id: Optional[int] = None


class PersonelUpdate(BaseModel):
    """
    Personel guncelleme istegi.
    Tum alanlar opsiyonel - sadece degisenleri gonder.
    Not: unvan degistirilemez (yeni kayit gerekir).
    """
    ad: Optional[str] = None
    soyad: Optional[str] = None
    tc_no: Optional[str] = None
    telefon: Optional[str] = None
    email: Optional[EmailStr] = None

    uzmanlik_belgesi_no: Optional[str] = None
    diploma_no: Optional[str] = None
    uzmanlik_sinifi: Optional[str] = None
    brans: Optional[str] = None

    ise_baslama_tarihi: Optional[date] = None
    kullanici_id: Optional[int] = None
    aktif: Optional[bool] = None


class PersonelResponse(BaseModel):
    """API'nin dondurdugu personel bilgisi."""
    id: int
    ad: str
    soyad: str
    unvan: str
    unvan_turkce: Optional[str] = None  # "ISG Uzmani" vs. (API'de eklenir)

    tc_no: Optional[str] = None
    telefon: Optional[str] = None
    email: Optional[str] = None

    uzmanlik_belgesi_no: Optional[str] = None
    diploma_no: Optional[str] = None
    uzmanlik_sinifi: Optional[str] = None
    brans: Optional[str] = None

    ise_baslama_tarihi: Optional[date] = None
    kullanici_id: Optional[int] = None

    profil_foto_url: Optional[str] = None

    aktif: bool
    olusturma_tarihi: Optional[datetime] = None
    guncelleme_tarihi: Optional[datetime] = None

    model_config = {"from_attributes": True}


class PersonelListResponse(BaseModel):
    """Personel listesi yaniti (sayfalama ile)"""
    toplam: int
    personeller: list[PersonelResponse]
