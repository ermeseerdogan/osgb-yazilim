# =============================================
# DOKUMAN API ENDPOINT'LERI
# Dosya yukleme, indirme, listeleme, silme
# =============================================
#
# 📚 DERS: Polimorfik dokuman sistemi.
# Tum moduller (firma, isyeri, calisan vs.) ayni endpoint'leri kullanir.
# kaynak_tipi ve kaynak_id parametreleriyle hangi kayda ait oldugu belirlenir.
#
# Endpoint listesi:
# GET    /api/v1/dokuman/indir/{id}                          -> Dosya indir
# GET    /api/v1/dokuman/{kaynak_tipi}/{kaynak_id}          -> Dokumanlari listele
# POST   /api/v1/dokuman/{kaynak_tipi}/{kaynak_id}/yukle    -> Dosya yukle
# DELETE /api/v1/dokuman/{id}                                -> Dokuman sil
#
# 📚 DERS: ONEMLI! Route siralama kurali:
# /dokuman/indir/{id} MUTLAKA /dokuman/{kaynak_tipi}/{kaynak_id} ONCE tanimlanmali!
# Cunku FastAPI ilk eslesen route'u kullanir.
# Eger listeleme once olursa, "indir" kelimesi kaynak_tipi olarak yorumlanir.
#
# 📚 DERS: Dosya yukleme nasil calisir?
# 1. Frontend multipart/form-data ile dosya gonderir
# 2. FastAPI bunu UploadFile nesnesi olarak alir
# 3. Dosya sunucuda uploads/ klasorune kaydedilir
# 4. DB'ye sadece dosya yolu ve meta bilgileri yazilir
# 5. Indirme sirasinda dosya yolundan okunup gonderilir

import os
import uuid
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Request
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session, sessionmaker
from typing import Optional

from app.middleware.deps import mevcut_kullanici_getir, tenant_db_getir
from app.models.master import Kullanici
from app.models.tenant import Dokuman
from app.schemas.dokuman import DokumanResponse, DokumanListResponse

router = APIRouter(tags=["Dokumanlar"])

# 📚 DERS: Dosyalarin kaydedilecegi ana klasor
# Her tenant icin alt klasor olusturulur: uploads/osgb_demo/firma/5/dosya.pdf
UPLOAD_DIR = Path(__file__).resolve().parent.parent.parent.parent / "uploads"

# 📚 DERS: Izin verilen dosya uzantilari
# Guvenlik icin sadece bilinen dosya tiplerini kabul ediyoruz
IZINLI_UZANTILAR = {
    # Dokumanlar
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    '.odt', '.ods', '.odp', '.txt', '.rtf', '.csv',
    # Resimler
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg', '.tiff',
    # Arsivler
    '.zip', '.rar', '.7z',
    # Diger
    '.dwg', '.dxf',  # CAD dosyalari (isg projeleri icin)
}

# Max dosya boyutu: 50 MB
MAX_DOSYA_BOYUTU = 50 * 1024 * 1024


# =============================================
# 1. DOSYA INDIR (ONCE TANIMLANMALI!)
# GET /api/v1/dokuman/indir/{id}
#
# 📚 DERS: Bu endpoint /dokuman/{kaynak_tipi}/{kaynak_id}
# endpointinden ONCE tanimlanmali! Yoksa "indir" kelimesi
# kaynak_tipi olarak yorumlanir ve yanlis endpoint calisir.
# =============================================
@router.get("/dokuman/indir/{dokuman_id}")
def dokuman_indir(
    dokuman_id: int,
    request: Request,
    t: Optional[str] = None,
):
    """
    📚 DERS: Dosya indirme endpoint'i.

    Web'de dosya indirmek icin 2 yontem var:
    1. Authorization header (API istekleri icin)
    2. URL query parametresi: ?t=xxx (tarayicida yeni sekme icin)

    Tarayicida yeni sekme/link ile dosya acildiginda
    Authorization header gonderilemez, bu yuzden
    token'i URL'de query param olarak aliyoruz.

    📚 DERS: Bu endpoint Depends() kullanmaz!
    Cunku OAuth2PasswordBearer sadece header'dan token alir.
    Biz ise hem header hem query param destekliyoruz.
    Token'i kendimiz cozup dogruluyoruz.
    """
    from app.core.security import token_coz
    from app.core.database import get_tenant_engine
    from jose import JWTError

    # 📚 DERS: Token'i bul - once header'dan, yoksa query param'dan
    auth_header = request.headers.get("authorization", "")
    if auth_header.startswith("Bearer "):
        token_str = auth_header.replace("Bearer ", "")
    elif t:
        token_str = t
    else:
        raise HTTPException(status_code=401, detail="Token gerekli")

    # Token'i coz
    try:
        payload = token_coz(token_str)
        email = payload.get("sub")
        db_name = payload.get("db_name")
        if not email or not db_name:
            raise HTTPException(status_code=401, detail="Gecersiz token")
    except JWTError:
        raise HTTPException(status_code=401, detail="Gecersiz token")

    # Tenant DB'ye baglan
    engine = get_tenant_engine(db_name)
    SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    db = SessionLocal()

    try:
        dokuman = db.query(Dokuman).filter(
            Dokuman.id == dokuman_id,
            Dokuman.aktif == True,
        ).first()

        if not dokuman:
            raise HTTPException(status_code=404, detail="Dokuman bulunamadi")

        if not os.path.exists(dokuman.dosya_yolu):
            raise HTTPException(status_code=404, detail="Dosya sunucuda bulunamadi")

        return FileResponse(
            path=dokuman.dosya_yolu,
            filename=dokuman.dosya_adi,
            media_type=dokuman.dosya_tipi or "application/octet-stream",
        )
    finally:
        db.close()


# =============================================
# 2. DOKUMAN LISTELE
# GET /api/v1/dokuman/{kaynak_tipi}/{kaynak_id}
# =============================================
@router.get("/dokuman/{kaynak_tipi}/{kaynak_id}", response_model=DokumanListResponse)
def dokuman_listele(
    kaynak_tipi: str,
    kaynak_id: int,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """
    📚 DERS: Belirli bir kayda ait tum dokumanlari listele.
    Ornek: GET /api/v1/dokuman/firma/5 -> 5 numarali firmanin tum dokumanlari
    """
    sorgu = db.query(Dokuman).filter(
        Dokuman.kaynak_tipi == kaynak_tipi,
        Dokuman.kaynak_id == kaynak_id,
        Dokuman.aktif == True,
    ).order_by(Dokuman.olusturma_tarihi.desc())

    toplam = sorgu.count()
    kayitlar = sorgu.all()

    return DokumanListResponse(
        toplam=toplam,
        kayitlar=[DokumanResponse.model_validate(k) for k in kayitlar],
    )


# =============================================
# 3. DOSYA YUKLE
# POST /api/v1/dokuman/{kaynak_tipi}/{kaynak_id}/yukle
# =============================================
@router.post("/dokuman/{kaynak_tipi}/{kaynak_id}/yukle", response_model=DokumanResponse)
async def dokuman_yukle(
    kaynak_tipi: str,
    kaynak_id: int,
    request: Request,
    dosya: UploadFile = File(...),
    aciklama: Optional[str] = Form(None),
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """
    📚 DERS: Dosya yukleme endpoint'i.

    multipart/form-data ile dosya + aciklama alinir.
    Dosya sunucuya kaydedilir, DB'ye meta bilgiler yazilir.

    Dosya yolu formati:
    uploads/{db_name}/{kaynak_tipi}/{kaynak_id}/{uuid}_{dosya_adi}

    UUID eklenmesinin sebebi: Ayni isimde dosya yuklenirse cakismasin.
    """
    # Dosya uzanti kontrolu
    dosya_adi = dosya.filename or "dosya"
    uzanti = os.path.splitext(dosya_adi)[1].lower()

    if uzanti not in IZINLI_UZANTILAR:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Bu dosya tipi desteklenmiyor: {uzanti}. Izinli tipler: {', '.join(sorted(IZINLI_UZANTILAR))}",
        )

    # Dosya boyut kontrolu
    icerik = await dosya.read()
    if len(icerik) > MAX_DOSYA_BOYUTU:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Dosya boyutu cok buyuk. Maksimum: {MAX_DOSYA_BOYUTU // (1024*1024)} MB",
        )

    # 📚 DERS: Token'dan db_name al (tenant klasoru icin)
    from app.core.security import token_coz
    token = request.headers.get("authorization", "").replace("Bearer ", "")
    payload = token_coz(token)
    db_name = payload.get("db_name", "genel")

    # Klasor olustur: uploads/osgb_demo/firma/5/
    klasor = UPLOAD_DIR / db_name / kaynak_tipi / str(kaynak_id)
    klasor.mkdir(parents=True, exist_ok=True)

    # Benzersiz dosya adi: uuid_orijinal_ad.pdf
    benzersiz_ad = f"{uuid.uuid4().hex[:8]}_{dosya_adi}"
    dosya_yolu = klasor / benzersiz_ad

    # Dosyayi kaydet
    with open(dosya_yolu, "wb") as f:
        f.write(icerik)

    # DB'ye kaydet
    yeni_dokuman = Dokuman(
        kaynak_tipi=kaynak_tipi,
        kaynak_id=kaynak_id,
        dosya_adi=dosya_adi,
        dosya_yolu=str(dosya_yolu),
        dosya_tipi=dosya.content_type,
        dosya_boyutu=len(icerik),
        aciklama=aciklama,
        yukleyen_id=kullanici.id,
        yukleyen_adi=f"{kullanici.ad} {kullanici.soyad}",
    )
    db.add(yeni_dokuman)
    db.commit()
    db.refresh(yeni_dokuman)

    return DokumanResponse.model_validate(yeni_dokuman)


# =============================================
# 4. DOKUMAN SIL (soft delete)
# DELETE /api/v1/dokuman/{id}
# =============================================
@router.delete("/dokuman/{dokuman_id}")
def dokuman_sil(
    dokuman_id: int,
    kullanici: Kullanici = Depends(mevcut_kullanici_getir),
    db: Session = Depends(tenant_db_getir),
):
    """
    📚 DERS: Soft delete - aktif=False yapar, dosya sunucuda kalir.
    Ileride gerekirse gercek silme de eklenebilir.
    """
    dokuman = db.query(Dokuman).filter(
        Dokuman.id == dokuman_id,
        Dokuman.aktif == True,
    ).first()

    if not dokuman:
        raise HTTPException(status_code=404, detail="Dokuman bulunamadi")

    dokuman.aktif = False
    db.commit()

    return {"mesaj": "Dokuman silindi", "id": dokuman_id}
