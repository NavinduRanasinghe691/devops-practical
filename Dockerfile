FROM python:3.12-slim

# Don't write .pyc files; flush logs straight to `docker logs` / Render's console
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Copy requirements first so this layer is cached until dependencies change
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Run as a non-root user (good container hygiene)
RUN useradd --create-home --uid 10001 appuser
USER 10001

# Documentation only. Locally the app listens on 5000; on Render it listens on $PORT
EXPOSE 5000

CMD ["python", "app.py"]
