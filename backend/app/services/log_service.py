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


# ---- DIS IP ADRESI ALMA ----
# 📚 DERS: Kullanicinin gercek internet IP'sini bulmak icin
# 2 yontem var:
# 1) X-Forwarded-For header -> Nginx/Load Balancer arkasindayken
# 2) Harici API -> request.client.host yerel IP verdiginde

async def dis_ip_al(request: Optional[Request] = None) -> Optional[str]:
    """
    📚 DERS: Kullanicinin dis (Public/Internet) IP adresini bul.

    Oncelik sirasi:
    1. X-Client-Public-IP header (Flutter uygulamasi gonderir)
       -> Kullanici tarafinda api.ipify.org'dan ogrenilen gercek IP
    2. X-Forwarded-For header (Nginx/proxy arkasindayken gercek IP)
    3. X-Real-IP header (bazi proxy'ler bunu kullanir)

    📚 DERS: Neden Flutter'dan gondertiyoruz?
    Cunku backend'de request.client.host dedigimizde
    yerel agdaki IC IP gelir (192.168.1.x).
    api.ipify.org'u backend'den cagirirsak SUNUCUNUN IP'si gelir.
    Ama biz KULLANICININ internet IP'sini istiyoruz.
    Kullanici kendi tarayicisindan ipify'a sorunca, KULLANICININ IP'si doner.
    Bunu X-Client-Public-IP header'i ile backend'e gonderir.
    """
    if request:
        # 📚 DERS: 1. Oncelik - Flutter'dan gelen kullanici dis IP'si
        # Flutter uygulamasi giris sirasinda api.ipify.org'dan
        # kullanicinin dis IP'sini ogrenir ve bu header ile gonderir
        client_public_ip = request.headers.get("x-client-public-ip")
        if client_public_ip and client_public_ip != "127.0.0.1":
            return client_public_ip

        # 📚 DERS: 2. Oncelik - Nginx arkasinda calisirken
        # Nginx gercek kullanici IP'sini X-Forwarded-For'a yazar
        # Format: "gercek_ip, proxy1_ip, proxy2_ip"
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            # Ilk IP = gercek kullanici IP'si
            gercek_ip = forwarded_for.split(",")[0].strip()
            if gercek_ip and gercek_ip != "127.0.0.1":
                return gercek_ip

        # 📚 DERS: 3. Oncelik - Bazi proxy'ler X-Real-IP kullanir
        real_ip = request.headers.get("x-real-ip")
        if real_ip and real_ip != "127.0.0.1":
            return real_ip

    return None


async def islem_logla(
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

    Ic IP: request.client.host (yerel ag adresi)
    Dis IP: X-Forwarded-For veya harici API (internet adresi)
    """
    try:
        # Request'ten bilgi cikart
        ip_adresi = None
        dis_ip_adresi = None
        user_agent = None
        http_metod = None
        endpoint = None

        if request:
            # 📚 DERS: request.client.host -> Ic IP (yerel ag)
            ip_adresi = request.client.host if request.client else None
            user_agent = request.headers.get("user-agent", "")[:500]
            http_metod = request.method
            endpoint = str(request.url.path)

            # 📚 DERS: Dis IP (public/internet IP) al
            dis_ip_adresi = await dis_ip_al(request)

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
            dis_ip_adresi=dis_ip_adresi,
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
            f"Kullanici: {k_email or 'anonim'} | Ic IP: {ip_adresi} | Dis IP: {dis_ip_adresi}"
        )

    except Exception as e:
        # Log kaydi basarisiz olsa bile uygulama DURMASIN
        logger.error(f"Log kaydi yazilamadi: {e}")
