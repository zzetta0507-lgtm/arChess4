INCLUDE Irvine32.inc

.data
    ; Mensajes de la interfaz de usuario
    msgTitulo           BYTE "=== arChess 4.0 ===", 13, 10, 0
    msgMovRival         BYTE "--- Movimiento del rival actualizado ---", 13, 10, 0
    msgSiguienteMov     BYTE "Tu siguiente movimiento será (ej. e2e4): ", 0
    msgTurnoBlanca      BYTE "Turno: Blancas (PC)", 13, 10, 0
    msgTurnoNegra       BYTE "Turno: Negras (Laptop)", 13, 10, 0
    msgErrorTurno       BYTE "Error: No es tu turno o jugada inválida.", 13, 10, 0

    ; Matriz del tablero y control
    board BYTE 64 DUP(0)
    currentTurn BYTE 0        ; 0 = Blancas, 1 = Negras
    bufferEntrada BYTE 10 DUP(0)

.code
main PROC
    call Clrscr
    call SetupBoard

GameLoop:
    ; 1. Limpiar la pantalla en cada turno / actualización
    call Clrscr

    ; 2. Mostrar título de la aplicación
    mov edx, OFFSET msgTitulo
    call WriteString

    ; 3. Verificar si el rival acaba de mover (leyendo el estado sincronizado)
    ; Aquí puedes evaluar una bandera o comparar el estado con el JSON de Firebase
    call CheckRivalMove       
    cmp al, 1                 ; Si el rival movió, mostramos su aviso
    jne MostrarTurnoPropio
    
    mov edx, OFFSET msgMovRival
    call WriteString

MostrarTurnoPropio:
    ; 4. Mostrar de quién es el turno actual
    mov al, currentTurn
    cmp al, 0
    jne TurnoNegrasLabel
    mov edx, OFFSET msgTurnoBlanca
    call WriteString
    jmp DibujarTableroUI

TurnoNegrasLabel:
    mov edx, OFFSET msgTurnoNegra
    call WriteString

DibujarTableroUI:
    ; 5. Dibujar el tablero con emojis (♙, ♖, ♘, ♗, ♕, ♔, ♟, etc.) y coordenadas
    call DrawBoard

    ; 6. Solicitar la entrada con el formato exacto requerido
    mov edx, OFFSET msgSiguienteMov
    call WriteString

    mov edx, OFFSET bufferEntrada
    mov ecx, SIZEOF bufferEntrada
    call ReadString

    ; 7. Validar movimiento, reglas, y actualizar archivo JSON para el sync_manager.py
    call ProcessMove

    jmp GameLoop

    exit
main ENDP

SetupBoard PROC
    ret
SetupBoard ENDP

DrawBoard PROC
    ; Lógica para pintar filas (8 a 1), columnas (a-h) y traducir IDs a emojis
    ret
SetupBoard ENDP

CheckRivalMove PROC
    ; Compara con el game_state.json si la laptop/PC contraria realizó un cambio
    mov al, 0 
    ret
CheckRivalMove ENDP

ProcessMove PROC
    ; Valida reglas de piezas (Caballo en L, peón al frente, enroque, jaquemate)
    ret
ProcessMove ENDP

END main