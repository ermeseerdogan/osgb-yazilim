# =============================================
# DOKUMAN SCHEMA'LARI (Pydantic)
# Upload, response ve liste schemalar
# =============================================
#
# 📚 DERS: Dokuman icin ozel schema'lar.
# Dosya yukleme multipart/form-data ile yapilir,
# bu yuzden dosya alanlari UploadFile ile gelir,
# text alanlar ise Form() ile alinir.

from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class DokumanResponse(BaseModel):
    """
    📚 DERS: Tek dokuman response'u.
    Frontend'e gonderilen veri yapisi.
    """
    id: int
    kaynak_tipi: str
    kaynak_id: int
    dosya_adi: str
    dosya_tipi: Optional[str] = None
    dosya_boyutu: Optional[int] = None
    aciklama: Optional[str] = None
    yukleyen_id: Optional[int] = None
    yukleyen_adi: Optional[str] = None
    olusturma_tarihi: Optional[datetime] = None

    class Config:
        from_attributes = True


class DokumanListResponse(BaseModel):
    """Dokuman listesi + toplam sayi"""
    toplam: int
    kayitlar: list[DokumanResponse]
