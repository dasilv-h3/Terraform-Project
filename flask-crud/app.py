import psycopg2
import os
import datetime

from flask import Flask, request, jsonify
from flask_cors import CORS
from azure.storage.blob import generate_blob_sas, BlobSasPermissions, BlobServiceClient
from dotenv import load_dotenv

load_dotenv()

# Configuration Azure Blob Storage
AZURE_CONNECTION_STRING = os.getenv('AZURE_CONNECTION_STRING')
# print(AZURE_CONNECTION_STRING)
AZURE_ACCOUNT_NAME = os.getenv('AZURE_ACCOUNT_NAME')
# print(AZURE_ACCOUNT_NAME)
# AZURE_STORAGE_KEY = os.getenv('AZURE_STORAGE_KEY')
# print(AZURE_STORAGE_KEY)
CONTAINER_NAME = "flask-container"

blob_service_client = BlobServiceClient.from_connection_string(AZURE_CONNECTION_STRING)
container_client = blob_service_client.get_container_client(CONTAINER_NAME)

try:
    blob_service_client = BlobServiceClient.from_connection_string(AZURE_CONNECTION_STRING)
    # blob_service_client = BlobServiceClient(account_url=f"https://{AZURE_ACCOUNT_NAME}.blob.core.windows.net", credential=AZURE_STORAGE_KEY)
    print("✅ Connexion réussie à Azure Blob Storage !")
except Exception as e:
    print(f"❌ Erreur de connexion : {e}")

# Configuration PostgreSQL
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_NAME = os.getenv('DB_NAME', 'flaskdb')
DB_USER = os.getenv('DB_USER', 'user')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'password')

# Initialisation de l'application Flask
app = Flask(__name__)

CORS(app)

# Connexion à la base de données PostgreSQL
def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            sslmode="disable"
        )
        return conn
    except Exception as e:
        print(f"❌ Erreur de connexion à la base de données : {e}")
        raise

# Création de la base de données et de la table si elles n'existent pas
def init_db():
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS files (
                    id SERIAL PRIMARY KEY,
                    filename TEXT,
                    url TEXT
                )
            ''')
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"❌ Erreur lors de l'initialisation de la base de données : {e}")

init_db()

# Upload d'un fichier vers Azure Blob Storage
@app.route("/upload", methods=["PUT"])
def upload_file():
    print(request.files)
    
    # Vérifie si le fichier est bien présent dans la requête
    if "file" not in request.files:
        return jsonify({"error": "No file part"}), 400
    
    file = request.files["file"]
    
    # Création du client Blob et récupération du container
    blob_client = container_client.get_blob_client(file.filename)

    try:
        # Générer la SAS Token
        sas_token = generate_blob_sas(
            account_name=AZURE_ACCOUNT_NAME,
            container_name=CONTAINER_NAME,
            blob_name=file.filename,
            account_key=AZURE_CONNECTION_STRING,
            permission=BlobSasPermissions(read=True, write=True),
            expiry=datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=1),
            credential=blob_service_client.credential
        )
        
        # # Créer l'URL avec le SAS Token
        blob_url = f"https://{container_client.account_name}.blob.core.windows.net/{container_client.container_name}/{file.filename}?{sas_token}"

        # Upload du fichier avec l'URL
        blob_client.upload_blob(file.read(), overwrite=True)

        print('Fichier uploadé avec succès')
    
    except Exception as e:
        print(f"❌ Erreur lors de l'upload du fichier sur Azure : {e}")
        return jsonify({"error": "File upload failed"}), 500

    # Enregistrement des informations dans PostgreSQL
    try:
        conn = get_db_connection()
        with conn:
            with conn.cursor() as cursor:
                cursor.execute("INSERT INTO files (filename, url) VALUES (%s, %s)", (file.filename, blob_url))
        print("✅ Fichier enregistré dans la base de données avec succès")
    except Exception as e:
        print(f"❌ Erreur lors de l'insertion dans la base de données : {e}")
        conn.rollback()  # Annuler la transaction en cas d'erreur
        return jsonify({"error": "Database insertion failed"}), 500

    return jsonify({"message": "File uploaded successfully", "url": blob_url})


# Liste des fichiers stockés
@app.route("/files", methods=["GET"])
def list_files():
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM files")
            files = [{"id": row[0], "filename": row[1], "url": row[2]} for row in cursor.fetchall()]
        conn.close()
    except Exception as e:
        print(f"❌ Erreur lors de la récupération des fichiers de la base de données : {e}")
        return jsonify({"error": "Failed to retrieve files"}), 500

    return jsonify(files)

# Suppression d'un fichier
@app.route("/delete/<filename>", methods=["DELETE"])
def delete_file(filename):
    try:
        # Suppression du fichier dans Azure Blob Storage
        blob_client = container_client.get_blob_client(filename)
        blob_client.delete_blob()
    except Exception as e:
        print(f"❌ Erreur lors de la suppression du fichier sur Azure : {e}")
        return jsonify({"error": "File deletion failed"}), 500
    
    try:
        # Suppression des informations dans PostgreSQL
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("DELETE FROM files WHERE filename = %s", (filename,))
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"❌ Erreur lors de la suppression du fichier dans la base de données : {e}")
        return jsonify({"error": "Database deletion failed"}), 500
    
    return jsonify({"message": "File deleted successfully"})

# Gestion des erreurs globales
@app.errorhandler(Exception)
def handle_exception(e):
    """Gestion des erreurs non capturées"""
    print(f"❌ Erreur interne du serveur : {e}")
    return jsonify({"error": "Internal server error"}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)