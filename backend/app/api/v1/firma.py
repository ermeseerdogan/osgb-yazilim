# =============================================
# FIRMA API ENDPOINT'LERI
# CRUD islemleri: Listele, Getir, Ekle, Guncelle, Sil
# =============================================
#
# 📚 DERS: Bu dosya "Firma Yonetimi" modulunun API katmanidir.
#
# Endpoint listesi:
# GET    /api/v1/firma         -> Tum firmalari listele
# GET    /api/v1/firma/{id}    -> Tek firma getir
# POST   /api/v1/firma         -> Yeni firma ekle
# PUT    /api/v1/firma/{id}    -> Firma guncelle
# DELETE /api/v1/firma/{id}    -> Firma sil (pasife cek)
#
# Her endpoint tenant_db_getir kullanir:
# Token'daki db_name'e gore dogru OSGB DB'sine baglanir.

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request, UploadFile, File
from fastapi.responses import Response, FileResponse
from sqlalchemy.orm import Session
from typing import Optional
import os
import uuid
from pathlib import Path

from app.middleware.deps import mevcut_kullanici_getir, tenant_db_getir, rol_gerekli
from app.models.master import Kullanici, IslemLogEnum
from app.models.tenant import Firma
from app.services.log_service import islem_logla
from app.services.excel_service import excel_export, excel_import, excel_sablon_olustur, FIRMA_ALANLARI
from app.core.database import get_master_db
from app.schemas.firma import (
    FirmaCreate, FirmaUpdate, FirmaResponse, FirmaListResponse,
)

# Router olustur
router = APIRouter(
    prefix="/firma",
    tags=["Firma Yonetimi"],
)


# =============================================
# GET /api/v1/firma
# Tum firmalari listele (sayfalama ile)
# =============================================
@router.get("", response_model=FirmaListResponse)
def firma_listele(
    sayfa: int = Query(1, ge=1, description="Sayfa numarasi"),
    adet: int = Query(20, ge=1, le=100, description="Sayfa basina kayit"),
    arama: Optional[str] = Query(None, description="Firma adi ile arama"),
    aktif: Optional[bool] = Query(None, description="Aktif/pasif filtresi"),
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """
    📚 DERS: Sayfalama (Pagination) nasil calisir?

    1000 firma varsa hepsini bir kerede gondermek yavas olur.
    Bunun yerine sayfa sayfa gonderiyoruz:

    GET /firma?sayfa=1&adet=20  -> Ilk 20 firma
    GET /firma?sayfa=2&adet=20  -> 21-40 arasi firmalar
    GET /firma?arama=abc        -> Adi "abc" iceren firmalar

    Query parametreleri:
    - sayfa: Kacinci sayfa (varsayilan: 1)
    - adet: Sayfa basina kac kayit (varsayilan: 20, max: 100)
    - arama: Firma adi ile arama
    - aktif: True/False filtresi
    """
    # Sorgu olustur
    query = db.query(Firma)

    # 📚 DERS: Varsayilan olarak sadece aktif kayitlari getir
    # aktif=None (varsayilan) -> sadece aktif olanlar
    # aktif=True  -> sadece aktif olanlar
    # aktif=False -> sadece pasif olanlar (silinen kayitlar)
    # Boylece silinen firmalar normal listede gorunmez
    if aktif is None or aktif is True:
        query = query.filter(Firma.aktif == True)
    else:
        query = query.filter(Firma.aktif == False)

    # Arama filtresi
    if arama:
        # 📚 DERS: ilike = case-insensitive LIKE
        # "abc" aradiginda "ABC Insaat", "Abc Ltd." hepsini bulur
        query = query.filter(Firma.ad.ilike(f"%{arama}%"))

    # Toplam kayit sayisi
    toplam = query.count()

    # Sayfalama uygula
    # 📚 DERS: offset = kac kayit atla, limit = kac kayit getir
    # sayfa=2, adet=20 -> offset=20, limit=20 (21-40 arasi)
    offset = (sayfa - 1) * adet
    firmalar = query.order_by(Firma.id.desc()).offset(offset).limit(adet).all()

    return FirmaListResponse(toplam=toplam, firmalar=firmalar)


# =============================================
# EXCEL ISLEMLERI
# 📚 DERS: Bu endpoint'ler /{firma_id} ONCESINDE olmali!
# Yoksa FastAPI "excel" kelimesini firma_id olarak algilar.
#
# GET  /excel/export  -> Mevcut verileri Excel'e aktar
# GET  /excel/sablon  -> Bos sablon indir (iceri aktarim icin)
# POST /excel/import  -> Excel'den veri yukle
# =============================================

@router.get("/excel/export")
def firma_excel_export(
    arama: Optional[str] = Query(None),
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """Mevcut firmalari Excel dosyasina aktar."""
    query = db.query(Firma).filter(Firma.aktif == True)
    if arama:
        query = query.filter(Firma.ad.ilike(f"%{arama}%"))
    firmalar = query.order_by(Firma.id.desc()).all()
    excel_bytes = excel_export(firmalar, FIRMA_ALANLARI, sayfa_adi="Firmalar")
    return Response(
        content=excel_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=firmalar.xlsx"},
    )


@router.get("/excel/sablon")
def firma_excel_sablon(
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
):
    """Bos Excel sablonu indir (iceri aktarim icin)."""
    sablon_bytes = excel_sablon_olustur(FIRMA_ALANLARI, sayfa_adi="Firma Sablonu")
    return Response(
        content=sablon_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=firma_sablon.xlsx"},
    )


@router.post("/excel/import")
async def firma_excel_import(
    request: Request,
    dosya: UploadFile = File(..., description="Excel dosyasi (.xlsx)"),
    kullanici: Kullanici = Depends(
        rol_gerekli("sistem_admin", "osgb_yoneticisi")
    ),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    """Excel dosyasindan toplu firma yukle."""
    if not dosya.filename.endswith((".xlsx", ".xls")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Sadece Excel dosyasi (.xlsx) yuklenebilir",
        )
    icerik = dosya.file.read()
    sonuc = excel_import(icerik, FIRMA_ALANLARI)

    eklenen = 0
    atlanan = []
    for veri in sonuc["basarili"]:
        mevcut = db.query(Firma).filter(Firma.ad == veri.get("ad")).first()
        if mevcut:
            atlanan.append({"satir": 0, "hata": f"'{veri['ad']}' zaten mevcut", "veri": veri})
            continue
        yeni_firma = Firma(**veri)
        db.add(yeni_firma)
        eklenen += 1

    if eklenen > 0:
        db.commit()
        await islem_logla(
            db=master_db, islem_turu=IslemLogEnum.KAYIT_EKLEME, modul="firma",
            aciklama=f"Excel'den toplu firma yuklendi: {eklenen} adet",
            kullanici=kullanici, request=request,
        )

    return {
        "mesaj": f"{eklenen} firma eklendi",
        "toplam_satir": sonuc["toplam"],
        "eklenen": eklenen,
        "hatali": sonuc["hatali"] + atlanan,
        "hatali_sayisi": sonuc["hatali_sayisi"] + len(atlanan),
    }


# =============================================
# LOGO ISLEMLERI
# =============================================

IZINLI_RESIM_UZANTILARI = {'.jpg', '.jpeg', '.png', '.gif', '.webp'}
MAX_LOGO_BOYUTU = 5 * 1024 * 1024  # 5 MB

@router.post("/{firma_id}/logo")
async def firma_logo_yukle(
    firma_id: int,
    request: Request,
    logo: UploadFile = File(..., description="Logo dosyasi (jpg, png, gif, webp)"),
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """Firmaya logo yukle. Mevcut logo varsa degistirir."""
    firma = db.query(Firma).filter(Firma.id == firma_id).first()
    if not firma:
        raise HTTPException(status_code=404, detail="Firma bulunamadi")

    dosya_adi = logo.filename or "logo.jpg"
    uzanti = os.path.splitext(dosya_adi)[1].lower()
    if uzanti not in IZINLI_RESIM_UZANTILARI:
        raise HTTPException(
            status_code=400,
            detail=f"Gecersiz dosya formati. Izinli: {', '.join(IZINLI_RESIM_UZANTILARI)}",
        )

    icerik = await logo.read()
    if len(icerik) > MAX_LOGO_BOYUTU:
        raise HTTPException(status_code=400, detail="Dosya boyutu 5 MB'i gecemez")

    # Eski logoyu sil
    if firma.logo_url and os.path.exists(firma.logo_url):
        try:
            os.remove(firma.logo_url)
        except OSError:
            pass

    from app.core.security import token_coz
    token_str = request.headers.get("authorization", "").replace("Bearer ", "")
    payload = token_coz(token_str)
    db_name = payload.get("db_name", "default")
    dizin = Path("uploads") / db_name / "firma" / str(firma_id)
    dizin.mkdir(parents=True, exist_ok=True)

    dosya_uuid = uuid.uuid4().hex[:8]
    kayit_adi = f"logo_{dosya_uuid}{uzanti}"
    tam_yol = dizin / kayit_adi

    with open(tam_yol, "wb") as f:
        f.write(icerik)

    firma.logo_url = str(tam_yol)
    db.commit()

    return {"mesaj": "Logo yuklendi", "logo_url": str(tam_yol)}


@router.get("/{firma_id}/logo")
def firma_logo_getir(
    firma_id: int,
    request: Request,
    t: Optional[str] = None,
):
    """Logo dosyasini getir. Token: Authorization header veya ?t=xxx query param."""
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
        firma = sess.query(Firma).filter(Firma.id == firma_id).first()
        if not firma or not firma.logo_url:
            raise HTTPException(status_code=404, detail="Logo bulunamadi")

        if not os.path.exists(firma.logo_url):
            raise HTTPException(status_code=404, detail="Dosya sunucuda bulunamadi")

        uzanti = os.path.splitext(firma.logo_url)[1].lower()
        mime_map = {'.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
                    '.gif': 'image/gif', '.webp': 'image/webp'}
        media_type = mime_map.get(uzanti, 'image/jpeg')

        return FileResponse(path=firma.logo_url, media_type=media_type)
    finally:
        sess.close()


@router.delete("/{firma_id}/logo")
def firma_logo_sil(
    firma_id: int,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """Firma logosunu sil."""
    firma = db.query(Firma).filter(Firma.id == firma_id).first()
    if not firma:
        raise HTTPException(status_code=404, detail="Firma bulunamadi")

    if firma.logo_url and os.path.exists(firma.logo_url):
        try:
            os.remove(firma.logo_url)
        except OSError:
            pass

    firma.logo_url = None
    db.commit()

    return {"mesaj": "Logo silindi"}


# =============================================
# GET /api/v1/firma/{id}
# Tek firma detayi
# =============================================
@router.get("/{firma_id}", response_model=FirmaResponse)
def firma_detay(
    firma_id: int,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """
    📚 DERS: Path parametresi.

    /firma/5 -> firma_id = 5
    URL'deki {firma_id} otomatik olarak fonksiyon parametresine gelir.
    """
    firma = db.query(Firma).filter(Firma.id == firma_id).first()

    if not firma:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Firma bulunamadi (ID: {firma_id})",
        )

    return firma


# =============================================
# POST /api/v1/firma
# Yeni firma ekle
# =============================================
@router.post("", response_model=FirmaResponse, status_code=status.HTTP_201_CREATED)
async def firma_ekle(
    request: Request,
    firma_data: FirmaCreate,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    """
    📚 DERS: POST = Yeni kayit olustur.

    status_code=201: "Olusturuldu" anlamina gelir.
    (200 = Basarili, 201 = Olusturuldu, 404 = Bulunamadi, 500 = Sunucu hatasi)

    Pydantic FirmaCreate schemasi sayesinde:
    - Zorunlu alanlar kontrol edilir
    - Email formati dogrulanir
    - Yanlis tip gelirse otomatik hata doner
    """
    # Ayni isimde firma var mi kontrol et
    mevcut = db.query(Firma).filter(Firma.ad == firma_data.ad).first()
    if mevcut:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"'{firma_data.ad}' isimli firma zaten mevcut",
        )

    # Yeni firma olustur
    # 📚 DERS: **firma_data.model_dump()
    # Pydantic modelini dict'e cevirir ve ** ile acarak
    # Firma() constructor'ina parametre olarak gonderir.
    # Yani: Firma(ad="ABC", il="Istanbul", ...) gibi olur
    yeni_firma = Firma(**firma_data.model_dump())
    db.add(yeni_firma)
    db.commit()
    db.refresh(yeni_firma)

    # Log kaydi
    await islem_logla(
        db=master_db, islem_turu=IslemLogEnum.KAYIT_EKLEME, modul="firma",
        aciklama=f"Yeni firma eklendi: {yeni_firma.ad}",
        kullanici=kullanici, kayit_id=yeni_firma.id, kayit_turu="Firma",
        yeni_deger=firma_data.model_dump(), request=request,
    )

    return yeni_firma


# =============================================
# PUT /api/v1/firma/{id}
# Firma guncelle
# =============================================
@router.put("/{firma_id}", response_model=FirmaResponse)
async def firma_guncelle(
    firma_id: int,
    request: Request,
    firma_data: FirmaUpdate,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    """
    📚 DERS: PUT = Guncelle.

    Sadece gonderilen alanlari gunceller:
    {"telefon": "0216 444 5678"} -> Sadece telefonu degisir
    Diger alanlar ayni kalir.

    exclude_unset=True: None olan alanlar dahil edilmez.
    """
    firma = db.query(Firma).filter(Firma.id == firma_id).first()

    if not firma:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Firma bulunamadi (ID: {firma_id})",
        )

    # Eski degerleri kaydet (log icin)
    guncel_veriler = firma_data.model_dump(exclude_unset=True)
    eski_degerler = {alan: getattr(firma, alan) for alan in guncel_veriler}

    # Sadece gonderilen alanlari guncelle
    for alan, deger in guncel_veriler.items():
        setattr(firma, alan, deger)

    db.commit()
    db.refresh(firma)

    # Log kaydi
    await islem_logla(
        db=master_db, islem_turu=IslemLogEnum.KAYIT_GUNCELLEME, modul="firma",
        aciklama=f"Firma guncellendi: {firma.ad}",
        kullanici=kullanici, kayit_id=firma_id, kayit_turu="Firma",
        eski_deger=eski_degerler, yeni_deger=guncel_veriler, request=request,
    )

    return firma


# =============================================
# DELETE /api/v1/firma/{id}
# Firma sil (aslinda pasife cek)
# =============================================
@router.delete("/{firma_id}")
async def firma_sil(
    firma_id: int,
    request: Request,
    kullanici: Kullanici = Depends(
        rol_gerekli("sistem_admin", "osgb_yoneticisi")
    ),
    db: Session = Depends(tenant_db_getir),
    master_db: Session = Depends(get_master_db),
):
    """
    📚 DERS: Soft Delete (Yumusak Silme)

    Veritabanindan gercekten silMIYORUZ!
    Sadece aktif=False yapiyoruz.

    Neden?
    1. Yanlislikla silinen veri kurtarilabilir
    2. Gecmis kayitlar (faturalar, ziyaretler) bozulmaz
    3. Yasal zorunluluklar (bazi verilerin saklanmasi gerekir)

    Sadece sistem_admin ve osgb_yoneticisi silebilir.
    rol_gerekli() ile kontrol ediyoruz.
    """
    firma = db.query(Firma).filter(Firma.id == firma_id).first()

    if not firma:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Firma bulunamadi (ID: {firma_id})",
        )

    # Soft delete: Aktif -> Pasif
    firma.aktif = False
    db.commit()

    # Log kaydi
    await islem_logla(
        db=master_db, islem_turu=IslemLogEnum.KAYIT_SILME, modul="firma",
        aciklama=f"Firma silindi (pasife alindi): {firma.ad}",
        kullanici=kullanici, kayit_id=firma_id, kayit_turu="Firma",
        request=request,
    )

    return {"mesaj": f"'{firma.ad}' pasife alindi", "id": firma_id}
