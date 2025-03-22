from flask import Flask
from flask_sqlalchemy import SQLAlchemy
import os
from os import path
from flask_login import LoginManager
from werkzeug.middleware.proxy_fix import ProxyFix
from dotenv import load_dotenv
from sqlalchemy_utils import database_exists, create_database

db = SQLAlchemy()
load_dotenv()

SQL_USERNAME = os.getenv("SQL_USERNAME")
SQL_PASSWORD = os.getenv("SQL_PASSWORD")
SQL_HOST = os.getenv("SQL_HOST")
SQL_PORT = os.getenv("SQL_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_SECRET = os.getenv("DB_SECRET")


def create_app():
    app = Flask(__name__)
    app.config["SECRET_KEY"] = DB_SECRET
    url = f"mysql+pymysql://{SQL_USERNAME}:{SQL_PASSWORD}@{SQL_HOST}:{SQL_PORT}/{DB_NAME}?charset=utf8"
    app.config["SQLALCHEMY_DATABASE_URI"] = url
    # app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_port=1, x_prefix=1)
    db.init_app(app)

    from .views import views
    from .auth import auth

    app.register_blueprint(views, url_prefix="/")
    app.register_blueprint(auth, url_prefix="/")

    from .models import User, Note

    create_db(url, app)

    login_manager = LoginManager()
    login_manager.login_view = "auth.login"
    login_manager.init_app(app)

    @login_manager.user_loader
    def load_user(id):
        return User.query.get(int(id))

    return app


def create_db(url, app):
    try:
        if not database_exists(url):
            create_database(url)
            with app.app_context():
                db.create_all()
            print("Created Database!")
    except Exception as e:
        if e.code != "f405":
            raise e
