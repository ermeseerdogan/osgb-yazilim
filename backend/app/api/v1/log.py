# =============================================
# LOG API ENDPOINT'LERI
# Islem loglarini goruntuleme
# =============================================
#
# 📚 DERS: Bu endpoint'ler sadece yetkili kullanicilara aciktir.
# Sistem admin ve OSGB yoneticisi loglari gorebilir.
# Normal kullanicilar goremez.

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime, timedelta

from app.core.database import get_master_db
from app.middleware.deps import rol_gerekli
from app.models.master import Kullanici, IslemLog, IslemLogEnum
from app.schemas.log import IslemLogResponse, LogListResponse

router = APIRouter(
    prefix="/log",
    tags=["Sistem Loglari"],
)


# =============================================
# GET /api/v1/log
# Islem loglarini listele (sayfalama + filtreleme)
# =============================================
@router.get("", response_model=LogListResponse)
def log_listele(
    sayfa: int = Query(1, ge=1),
    adet: int = Query(50, ge=1, le=200),
    modul: Optional[str] = Query(None, description="Modul filtresi: auth, firma, calisan..."),
    islem_turu: Optional[str] = Query(None, description="Islem turu filtresi: giris, kayit_ekleme..."),
    kullanici_email: Optional[str] = Query(None, description="Kullanici email filtresi"),
    basarili: Optional[bool] = Query(None, description="Basarili/basarisiz filtresi"),
    son_gun: Optional[int] = Query(None, description="Son X gun icindeki loglar"),
    kayit_turu: Optional[str] = Query(None, description="Kayit turu: Firma, Isyeri, Calisan..."),
    kayit_id: Optional[int] = Query(None, description="Belirli bir kaydin loglari"),
    kullanici: Kullanici = Depends(
        rol_gerekli("sistem_admin", "osgb_yoneticisi")
    ),
    db: Session = Depends(get_master_db),
):
    """
    📚 DERS: Log filtreleme.

    Ornekler:
    GET /log?modul=auth                -> Sadece giris/cikis loglari
    GET /log?modul=firma               -> Sadece firma islem loglari
    GET /log?basarili=false            -> Sadece basarisiz islemler
    GET /log?son_gun=7                 -> Son 7 gunun loglari
    GET /log?kullanici_email=admin@... -> Belirli kullanicinin loglari
    """
    query = db.query(IslemLog)

    # OSGB yoneticisi sadece kendi tenant loglarini gorsun
    if kullanici.rol.value == "osgb_yoneticisi" and kullanici.tenant_id:
        query = query.filter(IslemLog.tenant_id == kullanici.tenant_id)

    # Filtreler
    if modul:
        query = query.filter(IslemLog.modul == modul)

    if islem_turu:
        query = query.filter(IslemLog.islem_turu == islem_turu)

    if kullanici_email:
        query = query.filter(IslemLog.kullanici_email.ilike(f"%{kullanici_email}%"))

    if basarili is not None:
        query = query.filter(IslemLog.basarili == basarili)

    if son_gun:
        baslangic = datetime.utcnow() - timedelta(days=son_gun)
        query = query.filter(IslemLog.tarih >= baslangic)

    # 📚 DERS: kayit_turu ve kayit_id filtresi
    # Belirli bir kaydın (mesela Firma ID:5) loglarini gormek icin
    # GET /log?kayit_turu=Firma&kayit_id=5
    if kayit_turu:
        query = query.filter(IslemLog.kayit_turu == kayit_turu)

    if kayit_id:
        query = query.filter(IslemLog.kayit_id == kayit_id)

    # Toplam
    toplam = query.count()

    # Sayfalama (en yeniden en eskiye)
    offset = (sayfa - 1) * adet
    loglar = query.order_by(IslemLog.tarih.desc()).offset(offset).limit(adet).all()

    return LogListResponse(toplam=toplam, loglar=loglar)


# =============================================
# GET /api/v1/log/ozet
# Log istatistikleri (dashboard icin)
# =============================================
@router.get("/ozet")
def log_ozet(
    son_gun: int = Query(7, description="Son X gun"),
    kullanici: Kullanici = Depends(
        rol_gerekli("sistem_admin", "osgb_yoneticisi")
    ),
    db: Session = Depends(get_master_db),
):
    """Log ozeti: Son X gundeki islem sayilari"""
    baslangic = datetime.utcnow() - timedelta(days=son_gun)
    query = db.query(IslemLog).filter(IslemLog.tarih >= baslangic)

    # OSGB yoneticisi kendi tenant'ini gorsun
    if kullanici.rol.value == "osgb_yoneticisi" and kullanici.tenant_id:
        query = query.filter(IslemLog.tenant_id == kullanici.tenant_id)

    toplam = query.count()
    basarili = query.filter(IslemLog.basarili == True).count()
    basarisiz = query.filter(IslemLog.basarili == False).count()
    giris_sayisi = query.filter(IslemLog.islem_turu == IslemLogEnum.GIRIS).count()
    basarisiz_giris = query.filter(IslemLog.islem_turu == IslemLogEnum.GIRIS_BASARISIZ).count()

    return {
        "son_gun": son_gun,
        "toplam_islem": toplam,
        "basarili": basarili,
        "basarisiz": basarisiz,
        "giris_sayisi": giris_sayisi,
        "basarisiz_giris": basarisiz_giris,
    }
