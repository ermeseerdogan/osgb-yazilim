# =============================================
# LOG SERVICE
# Islem loglarini veritabanina kaydeder
# =============================================
#
# 📚 DERS: Bu servis her islemde cagirilir.
#
# Ornek kullanim:
#   islem_logla(
#       db=db,
#       kullanici=kullanici,
#       islem_turu=IslemLogEnum.KAYIT_EKLEME,
#       modul="firma",
#       aciklama="Yeni firma eklendi: ABC Insaat Ltd.",
#       kayit_id=1,
#       kayit_turu="Firma",
#       yeni_deger={"ad": "ABC Insaat Ltd.", "il": "Istanbul"},
#       request=request,
#   )

from datetime import datetime
from typing import Optional, Any
from sqlalchemy.orm import Session
from fastapi import Request

from app.models.master import IslemLog, IslemLogEnum, Kullanici
from app.core.logger import logger


def islem_logla(
    db: Session,
    islem_turu: IslemLogEnum,
    modul: str,
    aciklama: str,
    kullanici: Optional[Kullanici] = None,
    kayit_id: Optional[int] = None,
    kayit_turu: Optional[str] = None,
    eski_deger: Optional[dict] = None,
    yeni_deger: Optional[dict] = None,
    request: Optional[Request] = None,
    basarili: bool = True,
    hata_mesaji: Optional[str] = None,
    tenant_id: Optional[int] = None,
    tenant_ad: Optional[str] = None,
):
    """
    📚 DERS: Islem loglama fonksiyonu.

    Hem veritabanina hem dosyaya log yazar.
    Tek bir fonksiyon cagirisyla her sey kaydedilir.
    """
    try:
        # Request'ten bilgi cikart
        ip_adresi = None
        user_agent = None
        http_metod = None
        endpoint = None

        if request:
            # 📚 DERS: request.client.host -> Kullanicinin IP adresi
            ip_adresi = request.client.host if request.client else None
            user_agent = request.headers.get("user-agent", "")[:500]
            http_metod = request.method
            endpoint = str(request.url.path)

        # Kullanici bilgileri
        k_id = None
        k_email = None
        k_rol = None
        k_ad = None
        k_tenant_id = tenant_id
        k_tenant_ad = tenant_ad

        if kullanici:
            k_id = kullanici.id
            k_email = kullanici.email
            k_rol = kullanici.rol.value if kullanici.rol else None
            k_ad = f"{kullanici.ad} {kullanici.soyad}"
            if not k_tenant_id:
                k_tenant_id = kullanici.tenant_id

        # DB'ye kaydet
        log = IslemLog(
            kullanici_id=k_id,
            kullanici_email=k_email,
            kullanici_rol=k_rol,
            kullanici_ad=k_ad,
            tenant_id=k_tenant_id,
            tenant_ad=k_tenant_ad,
            islem_turu=islem_turu,
            modul=modul,
            aciklama=aciklama,
            kayit_id=kayit_id,
            kayit_turu=kayit_turu,
            eski_deger=eski_deger,
            yeni_deger=yeni_deger,
            ip_adresi=ip_adresi,
            user_agent=user_agent,
            http_metod=http_metod,
            endpoint=endpoint,
            basarili=basarili,
            hata_mesaji=hata_mesaji,
            tarih=datetime.utcnow(),
        )
        db.add(log)
        db.commit()

        # Dosya loguna da yaz
        log_seviye = "INFO" if basarili else "WARNING"
        logger.info(
            f"[{islem_turu.value}] {modul} | {aciklama} | "
            f"Kullanici: {k_email or 'anonim'} | IP: {ip_adresi}"
        )

    except Exception as e:
        # Log kaydi basarisiz olsa bile uygulama DURMASIN
        logger.error(f"Log kaydi yazilamadi: {e}")
