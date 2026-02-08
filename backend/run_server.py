# Backend'i baslatma dosyasi
# uvicorn string ref yerine dogrudan app objesi kullanir
import uvicorn
from app.main import app

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001, reload=False)
