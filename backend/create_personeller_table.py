"""
Personeller tablosunu tenant DB'de olustur.
Kullanim: python3 create_personeller_table.py
"""
from app.core.database import get_tenant_engine
from sqlalchemy import text

engine = get_tenant_engine('demo_osgb')
with engine.connect() as conn:
    # Enum type'larini olustur
    conn.execute(text("""
        DO $$ BEGIN
            CREATE TYPE personelunvan AS ENUM ('isg_uzmani', 'isyeri_hekimi', 'dsp');
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
    """))
    conn.execute(text("""
        DO $$ BEGIN
            CREATE TYPE uzmanliksinifi AS ENUM ('a_sinifi', 'b_sinifi', 'c_sinifi');
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
    """))
    # Personeller tablosunu olustur
    conn.execute(text("""
        CREATE TABLE IF NOT EXISTS personeller (
            id SERIAL PRIMARY KEY,
            ad VARCHAR(100) NOT NULL,
            soyad VARCHAR(100) NOT NULL,
            tc_no VARCHAR(11) UNIQUE,
            telefon VARCHAR(20),
            email VARCHAR(255),
            unvan personelunvan NOT NULL,
            uzmanlik_belgesi_no VARCHAR(100),
            diploma_no VARCHAR(100),
            uzmanlik_sinifi uzmanliksinifi,
            brans VARCHAR(255),
            ise_baslama_tarihi DATE,
            kullanici_id INTEGER,
            aktif BOOLEAN DEFAULT TRUE,
            olusturma_tarihi TIMESTAMP DEFAULT NOW(),
            guncelleme_tarihi TIMESTAMP DEFAULT NOW()
        );
    """))
    conn.execute(text('CREATE INDEX IF NOT EXISTS ix_personeller_id ON personeller (id)'))
    conn.execute(text('CREATE INDEX IF NOT EXISTS ix_personeller_tc_no ON personeller (tc_no)'))
    conn.execute(text('CREATE INDEX IF NOT EXISTS ix_personeller_unvan ON personeller (unvan)'))
    conn.execute(text('CREATE INDEX IF NOT EXISTS ix_personeller_kullanici_id ON personeller (kullanici_id)'))
    conn.commit()
    print('Personeller tablosu basariyla olusturuldu!')
