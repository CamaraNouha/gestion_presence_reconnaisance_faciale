FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .

# Dépendances système pour OpenCV
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

# Lance les migrations puis démarre FastAPI.
# --workers 4 : 4 process = 4 moteurs faciaux en parallèle
# (les modèles OpenCV sont sérialisés par un verrou dans chaque
# process — voir face_engine.py)
CMD ["sh", "-c", "python init_db.py && uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4"]