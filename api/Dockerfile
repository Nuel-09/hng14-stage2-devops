FROM python:3.12-slim-bookworm AS builder
WORKDIR /app

# this is used to prevent the python from writing the bytecode to the disk
ENV PYTHONDONTWRITEBYTECODE=1
# this is used to prevent the python from buffering the output
ENV PYTHONUNBUFFERED=1

# this is used to create a virtual environment
RUN python -m venv /opt/venv
# this is used to set the path for the virtual environment
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt ./
# this is used to install the dependencies in the virtual environment
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim-bookworm AS runtime

# Apply security updates so Trivy/OS scans pass on patched Debian packages
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/opt/venv/bin:$PATH"

COPY --from=builder /opt/venv /opt/venv
COPY main.py ./main.py

RUN groupadd --system appgroup && useradd --system --gid appgroup appuser \
    && chown -R appuser:appgroup /app

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import sys, urllib.request; \
url='http://127.0.0.1:8000/health'; \
sys.exit(0 if urllib.request.urlopen(url, timeout=4).getcode()==200 else 1)"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
