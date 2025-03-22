cd /home/python/tnote
/home/python/.local/bin/gunicorn -w 2 -b 0.0.0.0:80 "website:create_app()" 
