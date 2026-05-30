FROM python:3.14-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY server.py config.py auth.py ./

EXPOSE 8001

ENV HOST=0.0.0.0
ENV PORT=8001

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8001"]
