# =============================================
# CALISAN API ENDPOINT'LERI
# CRUD islemleri: Listele, Getir, Ekle, Guncelle, Sil
# =============================================
#
# Endpoint listesi:
# GET    /api/v1/calisan              -> Tum calisanlari listele
# GET    /api/v1/calisan/excel/export -> Excel'e aktar
# GET    /api/v1/calisan/excel/sablon -> Bos sablon indir
# POST   /api/v1/calisan/excel/import -> Excel'den yukle
# GET    /api/v1/calisan/{id}         -> Tek calisan getir
# POST   /api/v1/calisan              -> Yeni calisan ekle
# PUT    /api/v1/calisan/{id}         -> Calisan guncelle
# DELETE /api/v1/calisan/{id}         -> Calisan sil (pasife cek)

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request, UploadFile, File
from fastapi.responses import Response, FileResponse
from sqlalchemy.orm import Session
from typing import Optional
import os
import uuid
from pathlib import Path

from app.middleware.deps import mevcut_kullanici_getir, tenant_db_getir, rol_gerekli
from app.models.master import Kullanici, IslemLogEnum
from app.models.tenant import Calisan, Isyeri
from app.services.log_service import islem_logla
from app.services.excel_service import excel_export, excel_import, excel_sablon_olustur, CALISAN_ALANLARI
from app.core.database import get_master_db
from app.schemas.calisan import (
    CalisanCreate, CalisanUpdate, CalisanResponse, CalisanListResponse,
)

# Router olustur
router = APIRouter(
    prefix="/calisan",
    tags=["Calisan Yonetimi"],
)


# =============================================
# GET /api/v1/calisan
# Tum calisanlari listele (sayfalama ile)
# =============================================
@router.get("", response_model=CalisanListResponse)
def calisan_listele(
    sayfa: int = Query(1, ge=1, description="Sayfa numarasi"),
    adet: int = Query(20, ge=1, le=100, description="Sayfa basina kayit"),
    arama: Optional[str] = Query(None, description="Ad/soyad ile arama"),
    isyeri_id: Optional[int] = Query(None, description="Isyeri filtresi"),
    aktif: Optional[bool] = Query(None, description="Aktif/pasif filtresi"),
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """
    Calisan listesi. Isyeri filtresi ve arama destekler.
    """
    query = db.query(Calisan)

    # Aktif filtresi
    if aktif is None or aktif is True:
        query = query.filter(Calisan.aktif == True)
    else:
        query = query.filter(Calisan.aktif == False)

    # Isyeri filtresi
    if isyeri_id:
        query = query.filter(Calisan.isyeri_id == isyeri_id)

    # Arama filtresi (ad veya soyad)
    if arama:
        query = query.filter(
            (Calisan.ad.ilike(f"%{arama}%")) |
            (Calisan.soyad.ilike(f"%{arama}%")) |
            (Calisan.tc_no.ilike(f"%{arama}%"))
        )

    # Toplam kayit sayisi
    toplam = query.count()

    # Sayfalama uygula
    offset = (sayfa - 1) * adet
    calisanlar = query.order_by(Calisan.id.desc()).offset(offset).limit(adet).all()

    # Isyeri adlarini ekle (join)
    sonuc = []
    for calisan in calisanlar:
        isyeri = db.query(Isyeri).filter(Isyeri.id == calisan.isyeri_id).first()
        calisan_dict = CalisanResponse.model_validate(calisan).model_dump()
        calisan_dict["isyeri_adi"] = isyeri.ad if isyeri else "Bilinmiyor"
        sonuc.append(calisan_dict)

    return CalisanListResponse(toplam=toplam, calisanlar=sonuc)


# =============================================
# EXCEL ISLEMLERI
# =============================================

@router.get("/excel/export")
def calisan_excel_export(
    arama: Optional[str] = Query(None),
    isyeri_id: Optional[int] = Query(None),
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """Mevcut calisanlari Excel dosyasina aktar."""
    query = db.query(Calisan).filter(Calisan.aktif == True)
    if arama:
        query = query.filter(
            (Calisan.ad.ilike(f"%{arama}%")) |
            (Calisan.soyad.ilike(f"%{arama}%"))
        )
    if isyeri_id:
        query = query.filter(Calisan.isyeri_id == isyeri_id)
    calisanlar = query.order_by(Calisan.id.desc()).all()

    # Isyeri adlarini ekle
    export_data = []
    for calisan in calisanlar:
        isyeri = db.query(Isyeri).filter(Isyeri.id == calisan.isyeri_id).first()
        veri = {alan["alan"]: getattr(calisan, alan["alan"], "") for alan in CALISAN_ALANLARI if alan["alan"] != "isyeri_adi"}
        veri["isyeri_adi"] = isyeri.ad if isyeri else ""
        export_data.append(veri)

    excel_bytes = excel_export(export_data, CALISAN_ALANLARI, sayfa_adi="Calisanlar")
    return Response(
        content=excel_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=calisanlar.xlsx"},
    )


@router.get("/excel/sablon")
def calisan_excel_sablon(
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
):
    """Bos Excel sablonu indir (iceri aktarim icin)."""
    sablon_bytes = excel_sablon_olustur(CALISAN_ALANLARI, sayfa_adi="Calisan Sablonu")
    return Response(
        content=sablon_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=calisan_sablon.xlsx"},
    )


@router.post("/excel/import")
async def calisan_excel_import(
    request: Request,
    dosya: UploadFile = File(..., description="Excel dosyasi (.xlsx)"),
    isyeri_id: int = Query(..., description="Calisanlarin eklenecegi isyeri ID"),
    kullanici: Kullanici = Depends(
        rol_gerekli("sistem_admin", "osgb_yoneticisi")
    ),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    """Excel dosyasindan toplu calisan yukle."""
    if not dosya.filename.endswith((".xlsx", ".xls")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Sadece Excel dosyasi (.xlsx) yuklenebilir",
        )

    # Isyeri var mi kontrol et
    isyeri = db.query(Isyeri).filter(Isyeri.id == isyeri_id).first()
    if not isyeri:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Isyeri bulunamadi (ID: {isyeri_id})",
        )

    icerik = dosya.file.read()
    sonuc = excel_import(icerik, CALISAN_ALANLARI)

    eklenen = 0
    atlanan = []
    for veri in sonuc["basarili"]:
        # TC no ile tekrar kontrolu
        if veri.get("tc_no"):
            mevcut = db.query(Calisan).filter(Calisan.tc_no == veri["tc_no"]).first()
            if mevcut:
                atlanan.append({"satir": 0, "hata": f"TC: {veri['tc_no']} zaten mevcut", "veri": veri})
                continue

        # isyeri_adi alanini cikar (DB'de yok)
        veri.pop("isyeri_adi", None)
        veri["isyeri_id"] = isyeri_id
        yeni_calisan = Calisan(**veri)
        db.add(yeni_calisan)
        eklenen += 1

    if eklenen > 0:
        db.commit()
        await islem_logla(
            db=master_db, islem_turu=IslemLogEnum.KAYIT_EKLEME, modul="calisan",
            aciklama=f"Excel'den toplu calisan yuklendi: {eklenen} adet ({isyeri.ad})",
            kullanici=kullanici, request=request,
        )

    return {
        "mesaj": f"{eklenen} calisan eklendi",
        "toplam_satir": sonuc["toplam"],
        "eklenen": eklenen,
        "hatali": sonuc["hatali"] + atlanan,
        "hatali_sayisi": sonuc["hatali_sayisi"] + len(atlanan),
    }


# =============================================
# PROFIL FOTOGRAFI ISLEMLERI
# =============================================

IZINLI_RESIM_UZANTILARI = {'.jpg', '.jpeg', '.png', '.gif', '.webp'}
MAX_FOTO_BOYUTU = 5 * 1024 * 1024  # 5 MB

@router.post("/{calisan_id}/profil-foto")
async def calisan_profil_foto_yukle(
    calisan_id: int,
    request: Request,
    foto: UploadFile = File(..., description="Profil fotografi (jpg, png, gif, webp)"),
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """Calisana profil fotografi yukle. Mevcut foto varsa degistirir."""
    calisan = db.query(Calisan).filter(Calisan.id == calisan_id).first()
    if not calisan:
        raise HTTPException(status_code=404, detail="Calisan bulunamadi")

    dosya_adi = foto.filename or "foto.jpg"
    uzanti = os.path.splitext(dosya_adi)[1].lower()
    if uzanti not in IZINLI_RESIM_UZANTILARI:
        raise HTTPException(
            status_code=400,
            detail=f"Gecersiz dosya formati. Izinli: {', '.join(IZINLI_RESIM_UZANTILARI)}",
        )

    icerik = await foto.read()
    if len(icerik) > MAX_FOTO_BOYUTU:
        raise HTTPException(status_code=400, detail="Dosya boyutu 5 MB'i gecemez")

    if calisan.profil_foto_url and os.path.exists(calisan.profil_foto_url):
        try:
            os.remove(calisan.profil_foto_url)
        except OSError:
            pass

    from app.core.security import token_coz
    token_str = request.headers.get("authorization", "").replace("Bearer ", "")
    payload = token_coz(token_str)
    db_name = payload.get("db_name", "default")
    dizin = Path("uploads") / db_name / "calisan" / str(calisan_id)
    dizin.mkdir(parents=True, exist_ok=True)

    dosya_uuid = uuid.uuid4().hex[:8]
    kayit_adi = f"profil_{dosya_uuid}{uzanti}"
    tam_yol = dizin / kayit_adi

    with open(tam_yol, "wb") as f:
        f.write(icerik)

    calisan.profil_foto_url = str(tam_yol)
    db.commit()

    return {"mesaj": "Profil fotografi yuklendi", "profil_foto_url": str(tam_yol)}


@router.get("/{calisan_id}/profil-foto")
def calisan_profil_foto_getir(
    calisan_id: int,
    request: Request,
    t: Optional[str] = None,
):
    """Profil fotografini getir. Token: Authorization header veya ?t=xxx query param."""
    from app.core.security import token_coz
    from app.core.database import get_tenant_engine
    from sqlalchemy.orm import sessionmaker
    from jose import JWTError

    auth_header = request.headers.get("authorization", "")
    if auth_header.startswith("Bearer "):
        token_str = auth_header.replace("Bearer ", "")
    elif t:
        token_str = t
    else:
        raise HTTPException(status_code=401, detail="Token gerekli")

    try:
        payload = token_coz(token_str)
        db_name = payload.get("db_name")
        if not db_name:
            raise HTTPException(status_code=401, detail="Gecersiz token")
    except JWTError:
        raise HTTPException(status_code=401, detail="Gecersiz token")

    engine = get_tenant_engine(db_name)
    SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    sess = SessionLocal()

    try:
        calisan = sess.query(Calisan).filter(Calisan.id == calisan_id).first()
        if not calisan or not calisan.profil_foto_url:
            raise HTTPException(status_code=404, detail="Profil fotografi bulunamadi")

        if not os.path.exists(calisan.profil_foto_url):
            raise HTTPException(status_code=404, detail="Dosya sunucuda bulunamadi")

        uzanti = os.path.splitext(calisan.profil_foto_url)[1].lower()
        mime_map = {'.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
                    '.gif': 'image/gif', '.webp': 'image/webp'}
        media_type = mime_map.get(uzanti, 'image/jpeg')

        return FileResponse(path=calisan.profil_foto_url, media_type=media_type)
    finally:
        sess.close()


@router.delete("/{calisan_id}/profil-foto")
def calisan_profil_foto_sil(
    calisan_id: int,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """Profil fotografini sil."""
    calisan = db.query(Calisan).filter(Calisan.id == calisan_id).first()
    if not calisan:
        raise HTTPException(status_code=404, detail="Calisan bulunamadi")

    if calisan.profil_foto_url and os.path.exists(calisan.profil_foto_url):
        try:
            os.remove(calisan.profil_foto_url)
        except OSError:
            pass

    calisan.profil_foto_url = None
    db.commit()

    return {"mesaj": "Profil fotografi silindi"}


# =============================================
# GET /api/v1/calisan/{id}
# Tek calisan detayi
# =============================================
@router.get("/{calisan_id}", response_model=CalisanResponse)
def calisan_detay(
    calisan_id: int,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    calisan = db.query(Calisan).filter(Calisan.id == calisan_id).first()

    if not calisan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Calisan bulunamadi (ID: {calisan_id})",
        )

    # Isyeri adini ekle
    isyeri = db.query(Isyeri).filter(Isyeri.id == calisan.isyeri_id).first()
    calisan_dict = CalisanResponse.model_validate(calisan).model_dump()
    calisan_dict["isyeri_adi"] = isyeri.ad if isyeri else "Bilinmiyor"

    return calisan_dict


# =============================================
# POST /api/v1/calisan
# Yeni calisan ekle
# =============================================
@router.post("", response_model=CalisanResponse, status_code=status.HTTP_201_CREATED)
async def calisan_ekle(
    request: Request,
    calisan_data: CalisanCreate,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    # Isyeri var mi kontrol et
    isyeri = db.query(Isyeri).filter(Isyeri.id == calisan_data.isyeri_id).first()
    if not isyeri:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Isyeri bulunamadi (ID: {calisan_data.isyeri_id})",
        )

    # TC no ile tekrar kontrolu
    if calisan_data.tc_no:
        mevcut = db.query(Calisan).filter(Calisan.tc_no == calisan_data.tc_no).first()
        if mevcut:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"TC: {calisan_data.tc_no} ile kayitli calisan zaten mevcut",
            )

    # Yeni calisan olustur
    yeni_calisan = Calisan(**calisan_data.model_dump())
    db.add(yeni_calisan)
    db.commit()
    db.refresh(yeni_calisan)

    # Log kaydi
    await islem_logla(
        db=master_db, islem_turu=IslemLogEnum.KAYIT_EKLEME, modul="calisan",
        aciklama=f"Yeni calisan eklendi: {yeni_calisan.ad} {yeni_calisan.soyad}",
        kullanici=kullanici, kayit_id=yeni_calisan.id, kayit_turu="Calisan",
        yeni_deger=calisan_data.model_dump(), request=request,
    )

    # Isyeri adini ekle
    calisan_dict = CalisanResponse.model_validate(yeni_calisan).model_dump()
    calisan_dict["isyeri_adi"] = isyeri.ad

    return calisan_dict


# =============================================
# PUT /api/v1/calisan/{id}
# Calisan guncelle
# =============================================
@router.put("/{calisan_id}", response_model=CalisanResponse)
async def calisan_guncelle(
    calisan_id: int,
    request: Request,
    calisan_data: CalisanUpdate,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    calisan = db.query(Calisan).filter(Calisan.id == calisan_id).first()

    if not calisan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Calisan bulunamadi (ID: {calisan_id})",
        )

    # TC no degisiyorsa tekrar kontrolu
    guncel_veriler = calisan_data.model_dump(exclude_unset=True)
    if "tc_no" in guncel_veriler and guncel_veriler["tc_no"]:
        mevcut = db.query(Calisan).filter(
            Calisan.tc_no == guncel_veriler["tc_no"],
            Calisan.id != calisan_id
        ).first()
        if mevcut:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"TC: {guncel_veriler['tc_no']} ile kayitli baska calisan var",
            )

    # Eski degerleri kaydet (log icin)
    eski_degerler = {alan: getattr(calisan, alan) for alan in guncel_veriler}

    # Sadece gonderilen alanlari guncelle
    for alan, deger in guncel_veriler.items():
        setattr(calisan, alan, deger)

    db.commit()
    db.refresh(calisan)

    # Log kaydi
    await islem_logla(
        db=master_db, islem_turu=IslemLogEnum.KAYIT_GUNCELLEME, modul="calisan",
        aciklama=f"Calisan guncellendi: {calisan.ad} {calisan.soyad}",
        kullanici=kullanici, kayit_id=calisan_id, kayit_turu="Calisan",
        eski_deger=eski_degerler, yeni_deger=guncel_veriler, request=request,
    )

    # Isyeri adini ekle
    isyeri = db.query(Isyeri).filter(Isyeri.id == calisan.isyeri_id).first()
    calisan_dict = CalisanResponse.model_validate(calisan).model_dump()
    calisan_dict["isyeri_adi"] = isyeri.ad if isyeri else "Bilinmiyor"

    return calisan_dict


# =============================================
# DELETE /api/v1/calisan/{id}
# Calisan sil (pasife cek)
# =============================================
@router.delete("/{calisan_id}")
async def calisan_sil(
    calisan_id: int,
    request: Request,
    kullanici: Kullanici = Depends(
        rol_gerekli("sistem_admin", "osgb_yoneticisi")
    ),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    """Soft delete: aktif=False yapar."""
    calisan = db.query(Calisan).filter(Calisan.id == calisan_id).first()

    if not calisan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Calisan bulunamadi (ID: {calisan_id})",
        )

    # Soft delete
    calisan.aktif = False
    db.commit()

    # Log kaydi
    await islem_logla(
        db=master_db, islem_turu=IslemLogEnum.KAYIT_SILME, modul="calisan",
        aciklama=f"Calisan silindi (pasife alindi): {calisan.ad} {calisan.soyad}",
        kullanici=kullanici, kayit_id=calisan_id, kayit_turu="Calisan",
        request=request,
    )

    return {"mesaj": f"'{calisan.ad} {calisan.soyad}' pasife alindi", "id": calisan_id}
