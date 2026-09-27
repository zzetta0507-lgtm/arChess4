import json
import time
import os
from datetime import datetime

# Archivo de intercambio definido en el ADR-03
STATE_FILE = "game_state.json"

def get_initial_state():
    """Genera el estado inicial basado en la estructura de arChess 4.0."""
    return {
        "gameId": "chess_room_01",
        "version": 0,
        "turn": "w",
        "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq 01",
        "lastMove": "",
        "updatedAt": datetime.utcnow().isoformat() + "Z",
        "status": "ongoing"
    }

def read_local_state():
    """Lee el archivo JSON que modifica el cliente MASM."""
    if not os.path.exists(STATE_FILE):
        initial = get_initial_state()
        write_local_state(initial)
        return initial
        
    try:
        with open(STATE_FILE, 'r') as f:
            return json.load(f)
    except json.JSONDecodeError:
        # Prevención de crasheos si MASM está escribiendo el archivo en este instante
        return None

def write_local_state(state):
    """Escribe el estado actualizado para que el cliente MASM lo lea (Polling)."""
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f, indent=2)

def fetch_cloud_state(game_id):
    """
    Aquí conectas tu base de datos (Supabase / Firebase).
    Debe retornar el JSON de la partida desde la nube.
    """
    # Ejemplo de cómo se vería con Supabase:
    # response = supabase.table('partidas').select('*').eq('gameId', game_id).execute()
    # return response.data[0] if response.data else None
    
    return None # Simulado por ahora

def update_cloud_state(state):
    """
    Sube el nuevo movimiento/estado validado por MASM a la nube.
    """
    # Ejemplo con Supabase:
    # supabase.table('partidas').upsert(state).execute()
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] Nube actualizada a la versión {state['version']} - Último mov: {state.get('lastMove', 'N/A')}")

def main():
    print("=== Servicio de Sincronización arChess 4.0 ===")
    print(f"Monitoreando {STATE_FILE}...")
    
    local_state = read_local_state()
    last_known_version = local_state["version"] if local_state else -1

    while True:
        try:
            # 1. Leer el estado actual del archivo local (modificado por MASM)
            current_local = read_local_state()
            
            if current_local:
                # Si MASM incrementó la versión (el jugador local hizo un movimiento válido)
                if current_local["version"] > last_known_version:
                    update_cloud_state(current_local)
                    last_known_version = current_local["version"]
            
            # 2. Consultar a la nube si el rival hizo un movimiento
            cloud_state = fetch_cloud_state("chess_room_01")
            
            if cloud_state and cloud_state["version"] > last_known_version:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Movimiento del rival detectado. Actualizando MASM...")
                write_local_state(cloud_state)
                last_known_version = cloud_state["version"]

            # Pausa de 500ms a 1s según el ADR-03 para evitar sobrecarga de I/O
            time.sleep(1) 

        except Exception as e:
            print(f"Error en el ciclo de sincronización: {e}")
            time.sleep(2)

if __name__ == "__main__":
    main()