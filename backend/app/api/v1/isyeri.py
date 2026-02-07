# =============================================
# ISYERI API ENDPOINT'LERI
# CRUD islemleri: Listele, Getir, Ekle, Guncelle, Sil
# =============================================
#
# 📚 DERS: Firma API'sinin aynisi, isyeri alanlari ile.
# Isyeri = Bir firmaya ait calisma alani (fabrika, ofis, depo).
#
# Endpoint listesi:
# GET    /api/v1/isyeri           -> Tum isyerlerini listele
# GET    /api/v1/isyeri/{id}      -> Tek isyeri getir
# POST   /api/v1/isyeri           -> Yeni isyeri ekle
# PUT    /api/v1/isyeri/{id}      -> Isyeri guncelle
# DELETE /api/v1/isyeri/{id}      -> Isyeri sil (pasife cek)
#
# Firma'dan farki:
# - firma_id ile filtreleme yapilabilir
# - Response'da firma_adi ek alan olarak donuyor (join ile)
# - tehlike_sinifi Enum kontrolu var

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request, UploadFile, File
from fastapi.responses import Response
from sqlalchemy.orm import Session
from typing import Optional

from app.middleware.deps import mevcut_kullanici_getir, tenant_db_getir, rol_gerekli
from app.models.master import Kullanici, IslemLogEnum
from app.models.tenant import Isyeri, Firma, TehlikeSinifi
from app.services.log_service import islem_logla
from app.services.excel_service import excel_export, excel_import, excel_sablon_olustur, ISYERI_ALANLARI
from app.core.database import get_master_db
from app.schemas.isyeri import (
    IsyeriCreate, IsyeriUpdate, IsyeriResponse, IsyeriListResponse,
)

# Router olustur
router = APIRouter(
    prefix="/isyeri",
    tags=["Isyeri Yonetimi"],
)


# =============================================
# YARDIMCI: Isyeri nesnesine firma_adi ekle
# 📚 DERS: SQLAlchemy ORM nesnesi uzerinde ekstra alan
# dondurmenin bir yolu, dict'e cevirip eklemek.
# Ama biz daha temiz bir yol kullaniyoruz:
# Isyeri nesnesine gecici bir attribute ekliyoruz.
# Pydantic'in from_attributes=True ayari sayesinde bu calisir.
# =============================================
def _firma_adi_ekle(isyeri: Isyeri, db: Session) -> Isyeri:
    """Isyeri nesnesine firma_adi attribute'u ekler."""
    if isyeri.firma_id:
        firma = db.query(Firma).filter(Firma.id == isyeri.firma_id).first()
        isyeri.firma_adi = firma.ad if firma else None
    else:
        isyeri.firma_adi = None
    return isyeri


# =============================================
# GET /api/v1/isyeri
# Tum isyerlerini listele (sayfalama ile)
# =============================================
@router.get("", response_model=IsyeriListResponse)
def isyeri_listele(
    sayfa: int = Query(1, ge=1, description="Sayfa numarasi"),
    adet: int = Query(20, ge=1, le=100, description="Sayfa basina kayit"),
    arama: Optional[str] = Query(None, description="Isyeri adi ile arama"),
    firma_id: Optional[int] = Query(None, description="Firmaya gore filtrele"),
    aktif: Optional[bool] = Query(None, description="Aktif/pasif filtresi"),
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """
    📚 DERS: Isyeri listesi - Firma listesiyle ayni mantik.

    Ek olarak firma_id parametresi var:
    GET /isyeri?firma_id=3  -> Sadece Firma #3'un isyerleri
    GET /isyeri?arama=fabrika -> Adi "fabrika" iceren isyerleri

    Response'da firma_adi ek alan olarak donuyor.
    """
    query = db.query(Isyeri)

    # Aktif filtresi
    if aktif is None or aktif is True:
        query = query.filter(Isyeri.aktif == True)
    else:
        query = query.filter(Isyeri.aktif == False)

    # Firma filtresi
    if firma_id:
        query = query.filter(Isyeri.firma_id == firma_id)

    # Arama filtresi
    if arama:
        query = query.filter(Isyeri.ad.ilike(f"%{arama}%"))

    # Toplam kayit sayisi
    toplam = query.count()

    # Sayfalama uygula
    offset = (sayfa - 1) * adet
    isyerleri = query.order_by(Isyeri.id.desc()).offset(offset).limit(adet).all()

    # Her isyerine firma_adi ekle
    for iy in isyerleri:
        _firma_adi_ekle(iy, db)

    return IsyeriListResponse(toplam=toplam, isyerleri=isyerleri)


# =============================================
# EXCEL ISLEMLERI
# 📚 DERS: /{isyeri_id} ONCESINDE olmali!
# =============================================

@router.get("/excel/export")
def isyeri_excel_export(
    arama: Optional[str] = Query(None),
    firma_id: Optional[int] = Query(None),
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """Mevcut isyerlerini Excel dosyasina aktar."""
    query = db.query(Isyeri).filter(Isyeri.aktif == True)
    if arama:
        query = query.filter(Isyeri.ad.ilike(f"%{arama}%"))
    if firma_id:
        query = query.filter(Isyeri.firma_id == firma_id)
    isyerleri = query.order_by(Isyeri.id.desc()).all()

    # firma_adi'ni export icin ekle
    for iy in isyerleri:
        _firma_adi_ekle(iy, db)

    excel_bytes = excel_export(isyerleri, ISYERI_ALANLARI, sayfa_adi="Isyerleri")
    return Response(
        content=excel_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=isyerleri.xlsx"},
    )


@router.get("/excel/sablon")
def isyeri_excel_sablon(
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
):
    """Bos Excel sablonu indir (iceri aktarim icin)."""
    sablon_bytes = excel_sablon_olustur(ISYERI_ALANLARI, sayfa_adi="Isyeri Sablonu")
    return Response(
        content=sablon_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=isyeri_sablon.xlsx"},
    )


@router.post("/excel/import")
async def isyeri_excel_import(
    request: Request,
    dosya: UploadFile = File(..., description="Excel dosyasi (.xlsx)"),
    kullanici: Kullanici = Depends(
        rol_gerekli("sistem_admin", "osgb_yoneticisi")
    ),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    """Excel dosyasindan toplu isyeri yukle."""
    if not dosya.filename.endswith((".xlsx", ".xls")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Sadece Excel dosyasi (.xlsx) yuklenebilir",
        )
    icerik = dosya.file.read()
    sonuc = excel_import(icerik, ISYERI_ALANLARI)

    eklenen = 0
    atlanan = []
    for veri in sonuc["basarili"]:
        # SGK sicil no benzersiz kontrolu
        mevcut = db.query(Isyeri).filter(Isyeri.sgk_sicil_no == veri.get("sgk_sicil_no")).first()
        if mevcut:
            atlanan.append({"satir": 0, "hata": f"SGK '{veri['sgk_sicil_no']}' zaten mevcut", "veri": veri})
            continue

        # tehlike_sinifi string -> Enum cevir
        ts = veri.get("tehlike_sinifi", "")
        if ts:
            try:
                veri["tehlike_sinifi"] = TehlikeSinifi(ts)
            except ValueError:
                atlanan.append({"satir": 0, "hata": f"Gecersiz tehlike sinifi: '{ts}'", "veri": veri})
                continue

        # firma_id kontrolu
        fid = veri.get("firma_id")
        if fid:
            try:
                veri["firma_id"] = int(fid)
            except (ValueError, TypeError):
                atlanan.append({"satir": 0, "hata": f"Gecersiz firma_id: '{fid}'", "veri": veri})
                continue

        yeni_isyeri = Isyeri(**veri)
        db.add(yeni_isyeri)
        eklenen += 1

    if eklenen > 0:
        db.commit()
        await islem_logla(
            db=master_db, islem_turu=IslemLogEnum.KAYIT_EKLEME, modul="isyeri",
            aciklama=f"Excel'den toplu isyeri yuklendi: {eklenen} adet",
            kullanici=kullanici, request=request,
        )

    return {
        "mesaj": f"{eklenen} isyeri eklendi",
        "toplam_satir": sonuc["toplam"],
        "eklenen": eklenen,
        "hatali": sonuc["hatali"] + atlanan,
        "hatali_sayisi": sonuc["hatali_sayisi"] + len(atlanan),
    }


# =============================================
# GET /api/v1/isyeri/{id}
# Tek isyeri detayi
# =============================================
@router.get("/{isyeri_id}", response_model=IsyeriResponse)
def isyeri_detay(
    isyeri_id: int,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """Tek isyeri detayi getir."""
    isyeri = db.query(Isyeri).filter(Isyeri.id == isyeri_id).first()

    if not isyeri:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Isyeri bulunamadi (ID: {isyeri_id})",
        )

    _firma_adi_ekle(isyeri, db)
    return isyeri


# =============================================
# POST /api/v1/isyeri
# Yeni isyeri ekle
# =============================================
@router.post("", response_model=IsyeriResponse, status_code=status.HTTP_201_CREATED)
async def isyeri_ekle(
    request: Request,
    isyeri_data: IsyeriCreate,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    """
    📚 DERS: Yeni isyeri olustur.

    Firma'dan farki:
    - firma_id zorunlu (hangi firmaya ait)
    - SGK sicil no benzersiz olmali
    - tehlike_sinifi string'den Enum'a cevrilir
    """
    # firma_id gecerli mi kontrol et
    firma = db.query(Firma).filter(Firma.id == isyeri_data.firma_id).first()
    if not firma:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Firma bulunamadi (ID: {isyeri_data.firma_id})",
        )

    # Ayni SGK sicil no var mi kontrol et
    mevcut = db.query(Isyeri).filter(Isyeri.sgk_sicil_no == isyeri_data.sgk_sicil_no).first()
    if mevcut:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Bu SGK sicil numarasi zaten kayitli: '{isyeri_data.sgk_sicil_no}'",
        )

    # Veriyi hazirla
    veri = isyeri_data.model_dump()

    # 📚 DERS: tehlike_sinifi string -> Enum cevir
    # Frontend "tehlikeli" string gonderir, DB'de Enum olarak saklanir
    try:
        veri["tehlike_sinifi"] = TehlikeSinifi(veri["tehlike_sinifi"])
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Gecersiz tehlike sinifi: '{veri['tehlike_sinifi']}'. "
                   f"Gecerli degerler: az_tehlikeli, tehlikeli, cok_tehlikeli",
        )

    yeni_isyeri = Isyeri(**veri)
    db.add(yeni_isyeri)
    db.commit()
    db.refresh(yeni_isyeri)

    # firma_adi ekle (response icin)
    yeni_isyeri.firma_adi = firma.ad

    # Log kaydi
    await islem_logla(
        db=master_db, islem_turu=IslemLogEnum.KAYIT_EKLEME, modul="isyeri",
        aciklama=f"Yeni isyeri eklendi: {yeni_isyeri.ad} (Firma: {firma.ad})",
        kullanici=kullanici, kayit_id=yeni_isyeri.id, kayit_turu="Isyeri",
        yeni_deger=isyeri_data.model_dump(), request=request,
    )

    return yeni_isyeri


# =============================================
# PUT /api/v1/isyeri/{id}
# Isyeri guncelle
# =============================================
@router.put("/{isyeri_id}", response_model=IsyeriResponse)
async def isyeri_guncelle(
    isyeri_id: int,
    request: Request,
    isyeri_data: IsyeriUpdate,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    """Isyeri bilgilerini guncelle."""
    isyeri = db.query(Isyeri).filter(Isyeri.id == isyeri_id).first()

    if not isyeri:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Isyeri bulunamadi (ID: {isyeri_id})",
        )

    # Eski degerleri kaydet (log icin)
    guncel_veriler = isyeri_data.model_dump(exclude_unset=True)
    eski_degerler = {}
    for alan in guncel_veriler:
        eski = getattr(isyeri, alan)
        # Enum ise string'e cevir (JSON serializable olmasi icin)
        if isinstance(eski, TehlikeSinifi):
            eski = eski.value
        eski_degerler[alan] = eski

    # tehlike_sinifi geldiyse Enum'a cevir
    if "tehlike_sinifi" in guncel_veriler and guncel_veriler["tehlike_sinifi"] is not None:
        try:
            guncel_veriler["tehlike_sinifi"] = TehlikeSinifi(guncel_veriler["tehlike_sinifi"])
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Gecersiz tehlike sinifi: '{guncel_veriler['tehlike_sinifi']}'",
            )

    # Sadece gonderilen alanlari guncelle
    for alan, deger in guncel_veriler.items():
        setattr(isyeri, alan, deger)

    db.commit()
    db.refresh(isyeri)

    # firma_adi ekle (response icin)
    _firma_adi_ekle(isyeri, db)

    # Log kaydi - yeni degerleri de string'e cevir
    yeni_log = {}
    for alan, deger in guncel_veriler.items():
        if isinstance(deger, TehlikeSinifi):
            yeni_log[alan] = deger.value
        else:
            yeni_log[alan] = deger

    await islem_logla(
        db=master_db, islem_turu=IslemLogEnum.KAYIT_GUNCELLEME, modul="isyeri",
        aciklama=f"Isyeri guncellendi: {isyeri.ad}",
        kullanici=kullanici, kayit_id=isyeri_id, kayit_turu="Isyeri",
        eski_deger=eski_degerler, yeni_deger=yeni_log, request=request,
    )

    return isyeri


# =============================================
# DELETE /api/v1/isyeri/{id}
# Isyeri sil (pasife cek)
# =============================================
@router.delete("/{isyeri_id}")
async def isyeri_sil(
    isyeri_id: int,
    request: Request,
    kullanici: Kullanici = Depends(
        rol_gerekli("sistem_admin", "osgb_yoneticisi")
    ),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    """
    📚 DERS: Soft Delete - Firma ile ayni mantik.
    Sadece sistem_admin ve osgb_yoneticisi silebilir.
    """
    isyeri = db.query(Isyeri).filter(Isyeri.id == isyeri_id).first()

    if not isyeri:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Isyeri bulunamadi (ID: {isyeri_id})",
        )

    # Soft delete
    isyeri.aktif = False
    db.commit()

    # Log kaydi
    await islem_logla(
        db=master_db, islem_turu=IslemLogEnum.KAYIT_SILME, modul="isyeri",
        aciklama=f"Isyeri silindi (pasife alindi): {isyeri.ad}",
        kullanici=kullanici, kayit_id=isyeri_id, kayit_turu="Isyeri",
        request=request,
    )

    return {"mesaj": f"'{isyeri.ad}' pasife alindi", "id": isyeri_id}
