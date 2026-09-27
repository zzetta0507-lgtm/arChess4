import os
import json
import time
import firebase_admin
from firebase_admin import credentials, db

# --- CONFIGURACIÓN DE FIREBASE ---
# Asegúrate de que el archivo JSON con tus credenciales de servicio 
# esté en la misma carpeta y se llame exactamente así (o cambia el nombre).
CREDENTIAL_FILE = "serviceAccountKey.json"
DATABASE_URL = "https://chesskys-default-rtdb.firebaseio.com/"

if not firebase_admin._apps:
    cred = credentials.Certificate(CREDENTIAL_FILE)
    firebase_admin.initialize_app(cred, {
        'databaseURL': DATABASE_URL
    })

db_ref = db.reference('arChess/gameState')

STATE_FILE = "game_state.json"
last_local_mtime = 0

def push_local_to_firebase(file_path):
    """Lee el game_state.json local y lo sube a Firebase"""
    try:
        if os.path.exists(file_path):
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            db_ref.set(data)
            print("[SYNC] Movimiento local subido a Firebase exitosamente.")
    except Exception as e:
        print(f"[ERROR] No se pudo subir a Firebase: {e}")

def pull_firebase_to_local(event):
    """Callback: Detecta cambios en Firebase y actualiza el archivo local"""
    try:
        global last_local_mtime
        remote_data = event.data
        if remote_data:
            with open(STATE_FILE, "w", encoding="utf-8") as f:
                json.dump(remote_data, f, indent=4)
            # Actualizamos la marca de tiempo para evitar loops infinitos locales
            last_local_mtime = os.path.getmtime(STATE_FILE)
            print("[SYNC] ¡Nuevo movimiento del rival descargado desde Firebase!")
    except Exception as e:
        print(f"[ERROR] No se pudo sincronizar desde Firebase: {e}")

def main():
    global last_local_mtime
    print("=== Servicio de Sincronización arChess 4.0 (Firebase) ===")
    
    # Asegurar que el archivo local exista inicialmente
    if not os.path.exists(STATE_FILE):
        initial_data = {"turn": 0, "move": "start"}
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(initial_data, f, indent=4)

    last_local_mtime = os.path.getmtime(STATE_FILE)

    # Escuchar cambios remotos en tiempo real desde Firebase
    db_ref.listen(pull_firebase_to_local)

    print("Monitoreando game_state.json y Firebase en tiempo real...\n")

    # Bucle principal para detectar cambios locales hechos por el Ensamblador
    while True:
        try:
            if os.path.exists(STATE_FILE):
                current_mtime = os.path.getmtime(STATE_FILE)
                if current_mtime != last_local_mtime:
                    # El archivo cambió localmente (hiciste un movimiento en ASM)
                    time.sleep(0.1) # Pequeña pausa para asegurar escritura completa
                    push_local_to_firebase(STATE_FILE)
                    last_local_mtime = os.path.getmtime(STATE_FILE)
        except KeyboardInterrupt:
            print("\nSaliendo del sincronizador...")
            break
        except Exception as e:
            print(f"[AVISO] Esperando estabilidad en archivo local: {e}")
        
        time.sleep(0.5)

if __name__ == "__main__":
    main()