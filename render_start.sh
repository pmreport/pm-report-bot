#!/bin/bash
# Jalankan bot di background
python app.py bot &

# Jalankan Gunicorn Web Server di foreground
gunicorn --workers 2 --bind 0.0.0.0:$PORT app:app
