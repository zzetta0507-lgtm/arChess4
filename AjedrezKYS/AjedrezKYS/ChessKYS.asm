INCLUDE Irvine32.inc

.data
    ; ADR-01: Vector Lineal de 64 Posiciones (1D Array de bytes)
    ; 0-63 representan las casillas (0 = a8, 63 = h1, por ejemplo)
    board BYTE 64 DUP(0) 

    ; Mensajes de la interfaz (ui_console)
    msgTitulo BYTE "=== arChess 4.0 ===", 13, 10, 0
    msgAutores BYTE "Desarrolladores: Santiago, Kenneth y Yamil", 13, 10, 13, 10, 0
    msgPrompt BYTE "Ingrese movimiento (ej. e2e4): ", 0
    
    ; Búfer para leer el teclado
    bufferEntrada BYTE 10 DUP(0)

.code
main PROC
    ; Limpiar la consola y mostrar encabezado
    call Clrscr
    mov edx, OFFSET msgTitulo
    call WriteString
    mov edx, OFFSET msgAutores
    call WriteString

    ; Aquí invocaremos la inicialización de las piezas (board.asm)
    ; call SetupBoard

GameLoop:
    ; Aquí invocaremos el dibujo del tablero (ui_console.asm)
    ; call DrawBoard

    ; Solicitar entrada al jugador
    mov edx, OFFSET msgPrompt
    call WriteString

    mov edx, OFFSET bufferEntrada
    mov ecx, SIZEOF bufferEntrada
    call ReadString

    ; Aquí invocaremos la lógica de validación (move_validator.asm)
    ; y la sincronización remota (sync_manager.asm)

    ; Salto de línea y reiniciar el ciclo
    call Crlf
    jmp GameLoop

    exit
main ENDP

END main