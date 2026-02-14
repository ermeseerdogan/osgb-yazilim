# =============================================
# PERSONEL API ENDPOINT'LERI
# OSGB personeli (ISG Uzmani, Isyeri Hekimi, DSP) CRUD islemleri
# =============================================
#
# Endpoint listesi:
# GET    /api/v1/personel              -> Tum personeli listele
# GET    /api/v1/personel/excel/export -> Excel'e aktar
# GET    /api/v1/personel/excel/sablon -> Bos sablon indir
# POST   /api/v1/personel/excel/import -> Excel'den yukle
# GET    /api/v1/personel/{id}         -> Tek personel getir
# POST   /api/v1/personel              -> Yeni personel ekle
# PUT    /api/v1/personel/{id}         -> Personel guncelle
# DELETE /api/v1/personel/{id}         -> Personel sil (pasife cek)

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request, UploadFile, File
from fastapi.responses import Response, FileResponse
from sqlalchemy.orm import Session
from typing import Optional
import os
import uuid
from pathlib import Path

from app.middleware.deps import mevcut_kullanici_getir, tenant_db_getir, rol_gerekli
from app.models.master import Kullanici, IslemLogEnum
from app.models.tenant import Personel, PersonelUnvan, UzmanlikSinifi
from app.services.log_service import islem_logla
from app.services.excel_service import excel_export, excel_import, excel_sablon_olustur, PERSONEL_ALANLARI
from app.core.database import get_master_db
from app.schemas.personel import (
    PersonelCreate, PersonelUpdate, PersonelResponse, PersonelListResponse,
)

router = APIRouter(
    prefix="/personel",
    tags=["Personel Yonetimi"],
)


# Unvan Turkce cevirisi
def _unvan_turkce(unvan_deger) -> str:
    """Enum degerini okunabilir Turkce'ye cevir"""
    if unvan_deger is None:
        return ""
    u = unvan_deger.value if hasattr(unvan_deger, 'value') else str(unvan_deger)
    mapping = {
        "isg_uzmani": "ISG Uzmani",
        "isyeri_hekimi": "Isyeri Hekimi",
        "dsp": "DSP",
    }
    return mapping.get(u, u)


# =============================================
# GET /api/v1/personel
# Tum personeli listele (sayfalama ile)
# =============================================
@router.get("", response_model=PersonelListResponse)
def personel_listele(
    sayfa: int = Query(1, ge=1, description="Sayfa numarasi"),
    adet: int = Query(20, ge=1, le=100, description="Sayfa basina kayit"),
    arama: Optional[str] = Query(None, description="Ad/soyad ile arama"),
    unvan: Optional[str] = Query(None, description="Unvan filtresi: isg_uzmani, isyeri_hekimi, dsp"),
    aktif: Optional[bool] = Query(None, description="Aktif/pasif filtresi"),
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """Personel listesi. Unvan filtresi ve arama destekler."""
    query = db.query(Personel)

    # Aktif filtresi
    if aktif is None or aktif is True:
        query = query.filter(Personel.aktif == True)
    else:
        query = query.filter(Personel.aktif == False)

    # Unvan filtresi
    if unvan:
        query = query.filter(Personel.unvan == unvan)

    # Arama filtresi (ad, soyad, tc_no)
    if arama:
        query = query.filter(
            (Personel.ad.ilike(f"%{arama}%")) |
            (Personel.soyad.ilike(f"%{arama}%")) |
            (Personel.tc_no.ilike(f"%{arama}%"))
        )

    toplam = query.count()

    offset = (sayfa - 1) * adet
    personeller = query.order_by(Personel.id.desc()).offset(offset).limit(adet).all()

    sonuc = []
    for p in personeller:
        p_dict = PersonelResponse.model_validate(p).model_dump()
        p_dict["unvan_turkce"] = _unvan_turkce(p.unvan)
        sonuc.append(p_dict)

    return PersonelListResponse(toplam=toplam, personeller=sonuc)


# =============================================
# EXCEL ISLEMLERI
# =============================================

@router.get("/excel/export")
def personel_excel_export(
    arama: Optional[str] = Query(None),
    unvan: Optional[str] = Query(None),
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """Mevcut personeli Excel dosyasina aktar."""
    query = db.query(Personel).filter(Personel.aktif == True)
    if arama:
        query = query.filter(
            (Personel.ad.ilike(f"%{arama}%")) |
            (Personel.soyad.ilike(f"%{arama}%"))
        )
    if unvan:
        query = query.filter(Personel.unvan == unvan)
    personeller = query.order_by(Personel.id.desc()).all()

    export_data = []
    for p in personeller:
        veri = {alan["alan"]: getattr(p, alan["alan"], "") for alan in PERSONEL_ALANLARI}
        # Enum degerlerini string'e cevir
        if veri.get("unvan") and hasattr(veri["unvan"], "value"):
            veri["unvan"] = _unvan_turkce(veri["unvan"])
        if veri.get("uzmanlik_sinifi") and hasattr(veri["uzmanlik_sinifi"], "value"):
            veri["uzmanlik_sinifi"] = veri["uzmanlik_sinifi"].value
        export_data.append(veri)

    excel_bytes = excel_export(export_data, PERSONEL_ALANLARI, sayfa_adi="Personel")
    return Response(
        content=excel_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=personel.xlsx"},
    )


@router.get("/excel/sablon")
def personel_excel_sablon(
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
):
    """Bos Excel sablonu indir (iceri aktarim icin)."""
    sablon_bytes = excel_sablon_olustur(PERSONEL_ALANLARI, sayfa_adi="Personel Sablonu")
    return Response(
        content=sablon_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=personel_sablon.xlsx"},
    )


@router.post("/excel/import")
async def personel_excel_import(
    request: Request,
    dosya: UploadFile = File(..., description="Excel dosyasi (.xlsx)"),
    kullanici: Kullanici = Depends(
        rol_gerekli("sistem_admin", "osgb_yoneticisi")
    ),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    """Excel dosyasindan toplu personel yukle."""
    if not dosya.filename.endswith((".xlsx", ".xls")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Sadece Excel dosyasi (.xlsx) yuklenebilir",
        )

    icerik = dosya.file.read()
    sonuc = excel_import(icerik, PERSONEL_ALANLARI)

    eklenen = 0
    atlanan = []
    for veri in sonuc["basarili"]:
        # TC no ile tekrar kontrolu
        if veri.get("tc_no"):
            mevcut = db.query(Personel).filter(Personel.tc_no == veri["tc_no"]).first()
            if mevcut:
                atlanan.append({"satir": 0, "hata": f"TC: {veri['tc_no']} zaten mevcut", "veri": veri})
                continue

        # Unvan kontrolu
        unvan_str = veri.get("unvan", "").lower().strip()
        # Excel'den gelen Turkce degerleri enum'a cevir
        unvan_mapping = {
            "isg uzmani": "isg_uzmani",
            "isg uzmanı": "isg_uzmani",
            "isyeri hekimi": "isyeri_hekimi",
            "işyeri hekimi": "isyeri_hekimi",
            "dsp": "dsp",
        }
        veri["unvan"] = unvan_mapping.get(unvan_str, unvan_str)

        yeni = Personel(**veri)
        db.add(yeni)
        eklenen += 1

    if eklenen > 0:
        db.commit()
        await islem_logla(
            db=master_db, islem_turu=IslemLogEnum.KAYIT_EKLEME, modul="personel",
            aciklama=f"Excel'den toplu personel yuklendi: {eklenen} adet",
            kullanici=kullanici, request=request,
        )

    return {
        "mesaj": f"{eklenen} personel eklendi",
        "toplam_satir": sonuc["toplam"],
        "eklenen": eklenen,
        "hatali": sonuc["hatali"] + atlanan,
        "hatali_sayisi": sonuc["hatali_sayisi"] + len(atlanan),
    }


# =============================================
# PROFIL FOTOGRAFI ISLEMLERI
# Not: Bu endpoint'ler /{personel_id}'den ONCE tanimlanmali
# yoksa FastAPI "profil-foto" string'ini personel_id olarak algilar
# =============================================

IZINLI_RESIM_UZANTILARI = {'.jpg', '.jpeg', '.png', '.gif', '.webp'}
MAX_FOTO_BOYUTU = 5 * 1024 * 1024  # 5 MB

@router.post("/{personel_id}/profil-foto")
async def profil_foto_yukle(
    personel_id: int,
    request: Request,
    foto: UploadFile = File(..., description="Profil fotografi (jpg, png, gif, webp)"),
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """Personele profil fotografi yukle. Mevcut foto varsa degistirir."""
    personel = db.query(Personel).filter(Personel.id == personel_id).first()
    if not personel:
        raise HTTPException(status_code=404, detail="Personel bulunamadi")

    # Uzanti kontrolu
    dosya_adi = foto.filename or "foto.jpg"
    uzanti = os.path.splitext(dosya_adi)[1].lower()
    if uzanti not in IZINLI_RESIM_UZANTILARI:
        raise HTTPException(
            status_code=400,
            detail=f"Gecersiz dosya formati. Izinli: {', '.join(IZINLI_RESIM_UZANTILARI)}",
        )

    # Dosya boyutu kontrolu
    icerik = await foto.read()
    if len(icerik) > MAX_FOTO_BOYUTU:
        raise HTTPException(status_code=400, detail="Dosya boyutu 5 MB'i gecemez")

    # Eski fotoyu sil
    if personel.profil_foto_url and os.path.exists(personel.profil_foto_url):
        try:
            os.remove(personel.profil_foto_url)
        except OSError:
            pass

    # Token'dan db_name al (tenant klasoru icin)
    from app.core.security import token_coz
    token_str = request.headers.get("authorization", "").replace("Bearer ", "")
    payload = token_coz(token_str)
    db_name = payload.get("db_name", "default")
    dizin = Path("uploads") / db_name / "personel" / str(personel_id)
    dizin.mkdir(parents=True, exist_ok=True)

    dosya_uuid = uuid.uuid4().hex[:8]
    kayit_adi = f"profil_{dosya_uuid}{uzanti}"
    tam_yol = dizin / kayit_adi

    # Dosyayi kaydet
    with open(tam_yol, "wb") as f:
        f.write(icerik)

    # DB guncelle
    personel.profil_foto_url = str(tam_yol)
    db.commit()

    return {"mesaj": "Profil fotografi yuklendi", "profil_foto_url": str(tam_yol)}


@router.get("/{personel_id}/profil-foto")
def profil_foto_getir(
    personel_id: int,
    request: Request,
    t: Optional[str] = None,
):
    """
    Profil fotografini getir (FileResponse).
    Token: Authorization header veya ?t=xxx query param.
    """
    from app.core.security import token_coz
    from app.core.database import get_tenant_engine
    from sqlalchemy.orm import sessionmaker
    from jose import JWTError

    # Token'i bul
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
        personel = sess.query(Personel).filter(Personel.id == personel_id).first()
        if not personel or not personel.profil_foto_url:
            raise HTTPException(status_code=404, detail="Profil fotografi bulunamadi")

        if not os.path.exists(personel.profil_foto_url):
            raise HTTPException(status_code=404, detail="Dosya sunucuda bulunamadi")

        # MIME type belirle
        uzanti = os.path.splitext(personel.profil_foto_url)[1].lower()
        mime_map = {'.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
                    '.gif': 'image/gif', '.webp': 'image/webp'}
        media_type = mime_map.get(uzanti, 'image/jpeg')

        return FileResponse(
            path=personel.profil_foto_url,
            media_type=media_type,
        )
    finally:
        sess.close()


@router.delete("/{personel_id}/profil-foto")
def profil_foto_sil(
    personel_id: int,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """Profil fotografini sil."""
    personel = db.query(Personel).filter(Personel.id == personel_id).first()
    if not personel:
        raise HTTPException(status_code=404, detail="Personel bulunamadi")

    if personel.profil_foto_url and os.path.exists(personel.profil_foto_url):
        try:
            os.remove(personel.profil_foto_url)
        except OSError:
            pass

    personel.profil_foto_url = None
    db.commit()

    return {"mesaj": "Profil fotografi silindi"}


# =============================================
# GET /api/v1/personel/{id}
# Tek personel detayi
# =============================================
@router.get("/{personel_id}", response_model=PersonelResponse)
def personel_detay(
    personel_id: int,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    personel = db.query(Personel).filter(Personel.id == personel_id).first()

    if not personel:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Personel bulunamadi (ID: {personel_id})",
        )

    p_dict = PersonelResponse.model_validate(personel).model_dump()
    p_dict["unvan_turkce"] = _unvan_turkce(personel.unvan)

    return p_dict


# =============================================
# POST /api/v1/personel
# Yeni personel ekle
# =============================================
@router.post("", response_model=PersonelResponse, status_code=status.HTTP_201_CREATED)
async def personel_ekle(
    request: Request,
    personel_data: PersonelCreate,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    # Unvan kontrolu
    gecerli_unvanlar = [e.value for e in PersonelUnvan]
    if personel_data.unvan not in gecerli_unvanlar:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Gecersiz unvan: {personel_data.unvan}. Gecerli degerler: {gecerli_unvanlar}",
        )

    # TC no ile tekrar kontrolu
    if personel_data.tc_no:
        mevcut = db.query(Personel).filter(Personel.tc_no == personel_data.tc_no).first()
        if mevcut:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"TC: {personel_data.tc_no} ile kayitli personel zaten mevcut",
            )

    yeni = Personel(**personel_data.model_dump())
    db.add(yeni)
    db.commit()
    db.refresh(yeni)

    await islem_logla(
        db=master_db, islem_turu=IslemLogEnum.KAYIT_EKLEME, modul="personel",
        aciklama=f"Yeni personel eklendi: {yeni.ad} {yeni.soyad} ({_unvan_turkce(yeni.unvan)})",
        kullanici=kullanici, kayit_id=yeni.id, kayit_turu="Personel",
        yeni_deger=personel_data.model_dump(), request=request,
    )

    p_dict = PersonelResponse.model_validate(yeni).model_dump()
    p_dict["unvan_turkce"] = _unvan_turkce(yeni.unvan)

    return p_dict


# =============================================
# PUT /api/v1/personel/{id}
# Personel guncelle
# =============================================
@router.put("/{personel_id}", response_model=PersonelResponse)
async def personel_guncelle(
    personel_id: int,
    request: Request,
    personel_data: PersonelUpdate,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    personel = db.query(Personel).filter(Personel.id == personel_id).first()

    if not personel:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Personel bulunamadi (ID: {personel_id})",
        )

    guncel_veriler = personel_data.model_dump(exclude_unset=True)

    # TC no degisiyorsa tekrar kontrolu
    if "tc_no" in guncel_veriler and guncel_veriler["tc_no"]:
        mevcut = db.query(Personel).filter(
            Personel.tc_no == guncel_veriler["tc_no"],
            Personel.id != personel_id
        ).first()
        if mevcut:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"TC: {guncel_veriler['tc_no']} ile kayitli baska personel var",
            )

    eski_degerler = {alan: getattr(personel, alan) for alan in guncel_veriler}

    for alan, deger in guncel_veriler.items():
        setattr(personel, alan, deger)

    db.commit()
    db.refresh(personel)

    await islem_logla(
        db=master_db, islem_turu=IslemLogEnum.KAYIT_GUNCELLEME, modul="personel",
        aciklama=f"Personel guncellendi: {personel.ad} {personel.soyad}",
        kullanici=kullanici, kayit_id=personel_id, kayit_turu="Personel",
        eski_deger=eski_degerler, yeni_deger=guncel_veriler, request=request,
    )

    p_dict = PersonelResponse.model_validate(personel).model_dump()
    p_dict["unvan_turkce"] = _unvan_turkce(personel.unvan)

    return p_dict


# =============================================
# DELETE /api/v1/personel/{id}
# Personel sil (pasife cek)
# =============================================
@router.delete("/{personel_id}")
async def personel_sil(
    personel_id: int,
    request: Request,
    kullanici: Kullanici = Depends(
        rol_gerekli("sistem_admin", "osgb_yoneticisi")
    ),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    """Soft delete: aktif=False yapar."""
    personel = db.query(Personel).filter(Personel.id == personel_id).first()

    if not personel:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Personel bulunamadi (ID: {personel_id})",
        )

    personel.aktif = False
    db.commit()

    await islem_logla(
        db=master_db, islem_turu=IslemLogEnum.KAYIT_SILME, modul="personel",
        aciklama=f"Personel silindi (pasife alindi): {personel.ad} {personel.soyad}",
        kullanici=kullanici, kayit_id=personel_id, kayit_turu="Personel",
        request=request,
    )

    return {"mesaj": f"'{personel.ad} {personel.soyad}' pasife alindi", "id": personel_id}
