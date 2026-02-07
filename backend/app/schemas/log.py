# =============================================
# LOG SCHEMALARI
# Log goruntuleme icin veri yapilari
# =============================================

from pydantic import BaseModel
from typing import Optional, Any
from datetime import datetime


class IslemLogResponse(BaseModel):
    """Tek log kaydi"""
    id: int
    kullanici_email: Optional[str] = None
    kullanici_ad: Optional[str] = None
    kullanici_rol: Optional[str] = None
    tenant_ad: Optional[str] = None
    islem_turu: str
    modul: Optional[str] = None
    aciklama: Optional[str] = None
    kayit_id: Optional[int] = None
    kayit_turu: Optional[str] = None
    eski_deger: Optional[Any] = None
    yeni_deger: Optional[Any] = None
    ip_adresi: Optional[str] = None
    dis_ip_adresi: Optional[str] = None
    http_metod: Optional[str] = None
    endpoint: Optional[str] = None
    basarili: bool = True
    hata_mesaji: Optional[str] = None
    tarih: Optional[datetime] = None

    model_config = {"from_attributes": True}


class LogListResponse(BaseModel):
    """Log listesi yaniti"""
    toplam: int
    loglar: list[IslemLogResponse]
