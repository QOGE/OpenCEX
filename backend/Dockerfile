# Python 3.8 is EOL; stay on 3.8.18 until a dedicated Django 4 / Python 3.12 upgrade.
FROM python:3.8.18-bookworm
ENV PYTHONUNBUFFERED 1
ENV PYTHONDONTWRITEBYTECODE 1
WORKDIR /app
COPY backend/ ./
RUN pip install setuptools==40
RUN pip install -r /app/requirements.txt
RUN apt-get update && apt-get install systemd wkhtmltopdf -y