FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    libpq-dev gcc \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    fastapi==0.115.0 \
    uvicorn[standard]==0.30.6 \
    psycopg2-binary==2.9.9 \
    pydantic==2.8.2 \
    requests==2.32.3 \
    slowapi==0.1.9 \
    PyJWT==2.9.0 \
    redis==5.2.1 \
    alembic==1.13.3 \
    SQLAlchemy==2.0.36

COPY . .

RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
