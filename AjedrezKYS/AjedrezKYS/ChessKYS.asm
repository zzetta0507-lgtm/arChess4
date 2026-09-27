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

    ; 3. Verificar si el rival acaba de mover
    call CheckRivalMove       
    cmp al, 1                 
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
    ; 5. Dibujar el tablero con emojis y coordenadas
    call DrawBoard

    ; 6. Solicitar la entrada con el formato requerido
    mov edx, OFFSET msgSiguienteMov
    call WriteString

    mov edx, OFFSET bufferEntrada
    mov ecx, SIZEOF bufferEntrada
    call ReadString

    ; 7. Validar movimiento y sincronizar
    call ProcessMove

    jmp GameLoop

    exit
main ENDP

SetupBoard PROC
    ret
SetupBoard ENDP

DrawBoard PROC
    ret
DrawBoard ENDP

CheckRivalMove PROC
    mov al, 0 
    ret
CheckRivalMove ENDP

ProcessMove PROC
    ret
ProcessMove ENDP

END main