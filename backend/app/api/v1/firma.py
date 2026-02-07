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

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import Optional

from app.middleware.deps import mevcut_kullanici_getir, tenant_db_getir, rol_gerekli
from app.models.master import Kullanici
from app.models.tenant import Firma
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

    # Arama filtresi
    if arama:
        # 📚 DERS: ilike = case-insensitive LIKE
        # "abc" aradiginda "ABC Insaat", "Abc Ltd." hepsini bulur
        query = query.filter(Firma.ad.ilike(f"%{arama}%"))

    # Aktiflik filtresi
    if aktif is not None:
        query = query.filter(Firma.aktif == aktif)

    # Toplam kayit sayisi
    toplam = query.count()

    # Sayfalama uygula
    # 📚 DERS: offset = kac kayit atla, limit = kac kayit getir
    # sayfa=2, adet=20 -> offset=20, limit=20 (21-40 arasi)
    offset = (sayfa - 1) * adet
    firmalar = query.order_by(Firma.id.desc()).offset(offset).limit(adet).all()

    return FirmaListResponse(toplam=toplam, firmalar=firmalar)


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
def firma_ekle(
    firma_data: FirmaCreate,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
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
    db.refresh(yeni_firma)  # DB'den guncel halini al (id eklenmis hali)

    return yeni_firma


# =============================================
# PUT /api/v1/firma/{id}
# Firma guncelle
# =============================================
@router.put("/{firma_id}", response_model=FirmaResponse)
def firma_guncelle(
    firma_id: int,
    firma_data: FirmaUpdate,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
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

    # Sadece gonderilen alanlari guncelle
    guncel_veriler = firma_data.model_dump(exclude_unset=True)
    for alan, deger in guncel_veriler.items():
        setattr(firma, alan, deger)
        # 📚 DERS: setattr(obj, "ad", "Yeni Ad")
        # obj.ad = "Yeni Ad" ile ayni sey
        # Dinamik olarak attribute set etmenin yolu

    db.commit()
    db.refresh(firma)

    return firma


# =============================================
# DELETE /api/v1/firma/{id}
# Firma sil (aslinda pasife cek)
# =============================================
@router.delete("/{firma_id}")
def firma_sil(
    firma_id: int,
    kullanici: Kullanici = Depends(
        rol_gerekli("sistem_admin", "osgb_yoneticisi")
    ),
    db: Session = Depends(tenant_db_getir),
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

    return {"mesaj": f"'{firma.ad}' pasife alindi", "id": firma_id}
