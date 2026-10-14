FROM python:3.12
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt

ENV PYTHONUNBUFFERED=1
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]