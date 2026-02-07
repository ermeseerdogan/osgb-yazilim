# =============================================
# ISYERI SCHEMALARI (Pydantic)
# Isyeri CRUD islemleri icin veri yapilari
# =============================================
#
# 📚 DERS: Firma schema'larinin aynisi, isyeri alanlari ile.
# Isyeri = Bir firmaya ait calisma alani (fabrika, ofis, depo).
#
# FirmaCreate gibi:
# IsyeriCreate: Yeni isyeri olustururken gereken alanlar
# IsyeriUpdate: Isyeri guncellerken degisebilecek alanlar
# IsyeriResponse: API'nin dondurdugu isyeri bilgisi

from pydantic import BaseModel
from typing import Optional
from datetime import datetime, date


class IsyeriCreate(BaseModel):
    """
    📚 DERS: Yeni isyeri olusturma istegi.

    Frontend su JSON'u gonderir:
    {
        "firma_id": 1,
        "ad": "Merkez Fabrika",
        "sgk_sicil_no": "1234567",
        "nace_kodu": "251100",
        "tehlike_sinifi": "tehlikeli",
        "isveren_ad": "Ahmet",
        "isveren_soyad": "Yilmaz"
    }
    """
    firma_id: int                                  # Hangi firmaya ait (zorunlu)
    ad: str                                        # Isyeri adi (zorunlu)
    sgk_sicil_no: str                              # SGK sicil numarasi (zorunlu)
    nace_kodu: str                                 # 6 haneli NACE kodu (zorunlu)
    nace_aciklama: Optional[str] = None            # NACE kodu aciklamasi
    tehlike_sinifi: str                            # az_tehlikeli / tehlikeli / cok_tehlikeli (zorunlu)
    ana_faaliyet: Optional[str] = None             # Ana faaliyet alani

    # Isveren bilgileri
    isveren_ad: str                                # Isveren adi (zorunlu)
    isveren_soyad: str                             # Isveren soyadi (zorunlu)
    isveren_vekili_ad: Optional[str] = None        # Vekil adi (opsiyonel)
    isveren_vekili_soyad: Optional[str] = None     # Vekil soyadi (opsiyonel)

    # Hizmet bilgileri
    hizmet_baslama: Optional[date] = None          # ISG hizmet baslama tarihi
    ucretlendirme: Optional[float] = None          # Aylik ucret

    # Mali musavir
    mali_musavir_ad: Optional[str] = None
    mali_musavir_soyad: Optional[str] = None
    mali_musavir_telefon: Optional[str] = None
    mali_musavir_email: Optional[str] = None

    # Konum
    lokasyon: Optional[str] = None                 # Adres/lokasyon
    koordinat_lat: Optional[float] = None          # Enlem
    koordinat_lng: Optional[float] = None          # Boylam


class IsyeriUpdate(BaseModel):
    """
    📚 DERS: Isyeri guncelleme istegi.
    Tum alanlar opsiyonel - sadece degisenleri gonder.
    """
    ad: Optional[str] = None
    sgk_sicil_no: Optional[str] = None
    nace_kodu: Optional[str] = None
    nace_aciklama: Optional[str] = None
    tehlike_sinifi: Optional[str] = None
    ana_faaliyet: Optional[str] = None

    isveren_ad: Optional[str] = None
    isveren_soyad: Optional[str] = None
    isveren_vekili_ad: Optional[str] = None
    isveren_vekili_soyad: Optional[str] = None

    hizmet_baslama: Optional[date] = None
    ucretlendirme: Optional[float] = None

    mali_musavir_ad: Optional[str] = None
    mali_musavir_soyad: Optional[str] = None
    mali_musavir_telefon: Optional[str] = None
    mali_musavir_email: Optional[str] = None

    lokasyon: Optional[str] = None
    koordinat_lat: Optional[float] = None
    koordinat_lng: Optional[float] = None

    aktif: Optional[bool] = None


class IsyeriResponse(BaseModel):
    """
    📚 DERS: API'nin dondurdugu isyeri bilgisi.
    firma_adi ek alan olarak eklendi - listede firma adini gostermek icin.
    """
    id: int
    firma_id: int
    firma_adi: Optional[str] = None  # Firma adini da dondurelim (join)

    ad: str
    sgk_sicil_no: str
    nace_kodu: str
    nace_aciklama: Optional[str] = None
    tehlike_sinifi: str
    ana_faaliyet: Optional[str] = None

    isveren_ad: str
    isveren_soyad: str
    isveren_vekili_ad: Optional[str] = None
    isveren_vekili_soyad: Optional[str] = None

    hizmet_baslama: Optional[date] = None
    ucretlendirme: Optional[float] = None

    mali_musavir_ad: Optional[str] = None
    mali_musavir_soyad: Optional[str] = None
    mali_musavir_telefon: Optional[str] = None
    mali_musavir_email: Optional[str] = None

    lokasyon: Optional[str] = None
    koordinat_lat: Optional[float] = None
    koordinat_lng: Optional[float] = None

    aktif: bool
    olusturma_tarihi: Optional[datetime] = None
    guncelleme_tarihi: Optional[datetime] = None

    model_config = {"from_attributes": True}


class IsyeriListResponse(BaseModel):
    """Isyeri listesi yaniti (sayfalama ile)"""
    toplam: int
    isyerleri: list[IsyeriResponse]
