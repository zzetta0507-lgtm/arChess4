INCLUDE Irvine32.inc

; =====================================================================
;  arChess 4.0 - Ajedrez por turnos sincronizado con Firebase via JSON
;
;  Cada jugador ejecuta ESTE .exe (eligiendo si es J1/Blancas o
;  J2/Negras) Y ADEMAS debe tener corriendo el script de Python
;  (sync_firebase.py) apuntando a la MISMA base de datos de Firebase.
;
;  El archivo game_state.json es la "fuente de verdad": cada vez que
;  alguien mueve, se reescribe completo (tablero + turno + ultimo
;  movimiento). El script de Python sube ese archivo a Firebase y,
;  cuando detecta cambios remotos (el otro jugador movio), reescribe
;  este mismo archivo localmente. El .exe simplemente relee el
;  archivo en cada vuelta para saber si ya le toca jugar.
; =====================================================================

.data
    msgTitulo           BYTE "=== arChess 4.0 ===", 13, 10, 0
    msgMovRival         BYTE "--- El rival ya jugo, tablero actualizado ---", 13, 10, 0
    msgSiguienteMov     BYTE 13, 10, "Tu siguiente movimiento (ej. e2e4): ", 0
    msgTurnoBlanca      BYTE "Turno: Blancas", 13, 10, 0
    msgTurnoNegra       BYTE "Turno: Negras", 13, 10, 0
    msgTuMovimiento     BYTE "== Es tu turno de mover ==", 13, 10, 0
    msgEsperando        BYTE "Esperando el movimiento del rival...", 13, 10, 0
    msgMovInvalido      BYTE "Movimiento invalido (usa formato e2e4 y una pieza tuya en origen).", 13, 10, 0
    msgPreguntaRol      BYTE "Quien eres? 1 = Jugador 1 (Blancas)  2 = Jugador 2 (Negras): ", 0

    msgBordeSuperior    BYTE "  +----+----+----+----+----+----+----+----+", 13, 10, 0
    msgColumnas         BYTE "    a    b    c    d    e    f    g    h  ", 13, 10, 0
    msgLeyenda          BYTE "(May.=Blancas min.=Negras  T=Torre C=Caballo A=Alfil Q=Reina K=Rey P=Peon)", 13, 10, 0
    msgUltimoMov        BYTE "Ultimo movimiento: ", 0

    ; --- Archivo compartido con el sincronizador de Python ---
    fileName            BYTE "game_state.json", 0
    fileHandle          HANDLE ?

    ; Buffers para construir/leer el JSON
    jsonOut             BYTE 256 DUP(0)
    jsonIn              BYTE 256 DUP(0)

    ; Fragmentos de texto para armar/leer el JSON (formato FIJO, sin espacios)
    strJsonHeaderTurn   BYTE '{"turn":', 0
    strJsonBoardKey     BYTE ',"board":"', 0
    strJsonLastMoveKey  BYTE '","lastMove":"', 0
    strJsonFooter       BYTE '"}', 0

    prefixTurn          BYTE '"turn":', 0
    prefixBoard         BYTE '"board":"', 0
    prefixLastMove      BYTE '"lastMove":"', 0

    hexDigits           BYTE "0123456789ABC"

    ; Matriz del tablero (64 casillas), 0=vacio, 1-6=Blancas, 7-12=Negras
    board               BYTE 64 DUP(0)
    currentTurn         BYTE 0        ; 0 = Blancas, 1 = Negras
    playerRole          BYTE 0        ; 0 = J1 (Blancas), 1 = J2 (Negras)

    bufferEntrada       BYTE 10 DUP(0)
    bufferRol           BYTE 4 DUP(0)
    lastSeenMove        BYTE 8 DUP(0)

    ; Piezas (letras con notacion en espanol, mayus=Blancas, min=Negras)
    strPawnW   BYTE " P  ", 0
    strRookW   BYTE " T  ", 0
    strKnightW BYTE " C  ", 0
    strBishopW BYTE " A  ", 0
    strQueenW  BYTE " Q  ", 0
    strKingW   BYTE " K  ", 0

    strPawnB   BYTE " p  ", 0
    strRookB   BYTE " t  ", 0
    strKnightB BYTE " c  ", 0
    strBishopB BYTE " a  ", 0
    strQueenB  BYTE " q  ", 0
    strKingB   BYTE " k  ", 0

    strEmpty   BYTE "    ", 0

.code
main PROC
    call Clrscr
    call SetupBoard

    ; --- Preguntar rol (Jugador 1 = Blancas, Jugador 2 = Negras) ---
    mov edx, OFFSET msgPreguntaRol
    call WriteString
    mov edx, OFFSET bufferRol
    mov ecx, SIZEOF bufferRol
    call ReadString
    mov al, bufferRol[0]
    cmp al, '2'
    je EsJ2
    mov playerRole, 0
    jmp RolListo
EsJ2:
    mov playerRole, 1
RolListo:

    ; --- Intentar cargar partida existente; si no hay, crear la inicial ---
    call ReadGameState
    cmp al, 1
    je GameLoop

    mov currentTurn, 0
    call WriteGameState        ; crea game_state.json con el tablero inicial

GameLoop:
    call Clrscr
    mov edx, OFFSET msgTitulo
    call WriteString

    ; Releer el estado por si el rival ya jugo mientras esperabamos
    call ReadGameState

    ; ¿Es mi turno?
    movzx eax, currentTurn
    movzx ebx, playerRole
    cmp eax, ebx
    je EsMiTurno

    ; --- No es mi turno: mostrar tablero y esperar ---
    call DrawBoard
    mov edx, OFFSET msgEsperando
    call WriteString
    mov eax, 1200
    call Delay
    jmp GameLoop

EsMiTurno:
    cmp eax, 0
    jne TurnoNegrasLabel
    mov edx, OFFSET msgTurnoBlanca
    call WriteString
    jmp DibujarTableroUI
TurnoNegrasLabel:
    mov edx, OFFSET msgTurnoNegra
    call WriteString

DibujarTableroUI:
    call DrawBoard
    mov edx, OFFSET msgTuMovimiento
    call WriteString

PedirMovimiento:
    mov edx, OFFSET msgSiguienteMov
    call WriteString
    mov edx, OFFSET bufferEntrada
    mov ecx, SIZEOF bufferEntrada
    call ReadString

    call ValidarYAplicarMovimiento
    cmp al, 1
    je MovimientoOk

    mov edx, OFFSET msgMovInvalido
    call WriteString
    jmp PedirMovimiento

MovimientoOk:
    xor currentTurn, 1          ; pasa el turno al rival
    call WriteGameState          ; guarda tablero+turno+ultimo mov -> Python lo sube a Firebase
    jmp GameLoop

    exit
main ENDP

; --- Inicializar todas las piezas en el tablero de 64 casillas ---
SetupBoard PROC
    mov board[0], 8
    mov board[1], 9
    mov board[2], 10
    mov board[3], 11
    mov board[4], 12
    mov board[5], 10
    mov board[6], 9
    mov board[7], 8

    mov ecx, 8
    mov esi, 8
InitPeonesN:
    mov board[esi], 7
    inc esi
    loop InitPeonesN

    mov ecx, 8
    mov esi, 48
InitPeonesB:
    mov board[esi], 1
    inc esi
    loop InitPeonesB

    mov board[56], 2
    mov board[57], 3
    mov board[58], 4
    mov board[59], 5
    mov board[60], 6
    mov board[61], 4
    mov board[62], 3
    mov board[63], 2
    ret
SetupBoard ENDP

; --- Dibujar el tablero con letras y coordenadas ---
DrawBoard PROC
    LOCAL fila:DWORD
    mov edx, OFFSET msgBordeSuperior
    call WriteString

    mov fila, 0
RowLoop:
    cmp fila, 8
    jge EndDrawBoard

    mov eax, 8
    sub eax, fila
    call WriteInt
    mov al, ' '
    call WriteChar
    mov al, '|'
    call WriteChar

    mov ecx, 0
ColLoop:
    cmp ecx, 8
    jge EndRowLoop

    push ecx
    mov eax, fila
    shl eax, 3
    pop ecx
    add eax, ecx
    mov esi, eax

    movzx ebx, board[esi]

    cmp ebx, 1
    je P_W
    cmp ebx, 2
    je T_W
    cmp ebx, 3
    je C_W
    cmp ebx, 4
    je A_W
    cmp ebx, 5
    je Q_W
    cmp ebx, 6
    je K_W
    cmp ebx, 7
    je P_B
    cmp ebx, 8
    je T_B
    cmp ebx, 9
    je C_B
    cmp ebx, 10
    je A_B
    cmp ebx, 11
    je Q_B
    cmp ebx, 12
    je K_B
    jmp PrintEmpty

P_W: mov edx, OFFSET strPawnW
     jmp DoPrint
T_W: mov edx, OFFSET strRookW
     jmp DoPrint
C_W: mov edx, OFFSET strKnightW
     jmp DoPrint
A_W: mov edx, OFFSET strBishopW
     jmp DoPrint
Q_W: mov edx, OFFSET strQueenW
     jmp DoPrint
K_W: mov edx, OFFSET strKingW
     jmp DoPrint

P_B: mov edx, OFFSET strPawnB
     jmp DoPrint
T_B: mov edx, OFFSET strRookB
     jmp DoPrint
C_B: mov edx, OFFSET strKnightB
     jmp DoPrint
A_B: mov edx, OFFSET strBishopB
     jmp DoPrint
Q_B: mov edx, OFFSET strQueenB
     jmp DoPrint
K_B: mov edx, OFFSET strKingB
     jmp DoPrint

PrintEmpty:
    mov edx, OFFSET strEmpty

DoPrint:
    call WriteString
    mov al, '|'
    call WriteChar

    inc ecx
    jmp ColLoop

EndRowLoop:
    call Crlf
    mov edx, OFFSET msgBordeSuperior
    call WriteString
    inc fila
    jmp RowLoop

EndDrawBoard:
    mov edx, OFFSET msgColumnas
    call WriteString
    call Crlf
    mov edx, OFFSET msgLeyenda
    call WriteString

    mov esi, OFFSET lastSeenMove
    mov al, [esi]
    cmp al, 0
    je NoUltimoMov
    mov edx, OFFSET msgUltimoMov
    call WriteString
    mov edx, OFFSET lastSeenMove
    call WriteString
    call Crlf
NoUltimoMov:
    ret
DrawBoard ENDP

; ---------------------------------------------------------------------
; Valida el texto en bufferEntrada (ej "e2e4") y, si es legal, mueve
; la pieza dentro del arreglo board[]. Devuelve AL=1 si aplico el
; movimiento, AL=0 si es invalido (no toca el turno ni el archivo).
; ---------------------------------------------------------------------
ValidarYAplicarMovimiento PROC
    mov esi, OFFSET bufferEntrada

    mov al, [esi]
    cmp al, 'a'
    jb Invalido
    cmp al, 'h'
    ja Invalido
    mov cl, al
    sub cl, 'a'            ; columna origen (0-7)

    mov al, [esi+1]
    cmp al, '1'
    jb Invalido
    cmp al, '8'
    ja Invalido
    mov ch, al
    sub ch, '1'            ; fila origen (0-7), 0 = fila '1'

    mov al, [esi+2]
    cmp al, 'a'
    jb Invalido
    cmp al, 'h'
    ja Invalido
    mov dl, al
    sub dl, 'a'            ; columna destino

    mov al, [esi+3]
    cmp al, '1'
    jb Invalido
    cmp al, '8'
    ja Invalido
    mov dh, al
    sub dh, '1'            ; fila destino

    ; indice = (7 - fila) * 8 + columna
    movzx eax, ch
    mov ebx, 7
    sub ebx, eax
    shl ebx, 3
    movzx eax, cl
    add ebx, eax
    mov esi, ebx            ; esi = indice origen

    movzx eax, dh
    mov ebx, 7
    sub ebx, eax
    shl ebx, 3
    movzx eax, dl
    add ebx, eax
    mov edi, ebx            ; edi = indice destino

    cmp esi, edi
    je Invalido

    movzx eax, board[esi]
    cmp eax, 0
    je Invalido             ; no hay pieza en origen

    movzx ebx, currentTurn
    cmp ebx, 0
    jne VerificarNegras
    cmp eax, 6
    ja Invalido             ; le toca a blancas y la pieza no es blanca
    jmp MoverPieza
VerificarNegras:
    cmp eax, 7
    jb Invalido             ; le toca a negras y la pieza no es negra

MoverPieza:
    mov board[edi], al
    mov board[esi], 0
    mov al, 1
    ret

Invalido:
    mov al, 0
    ret
ValidarYAplicarMovimiento ENDP

; --- Copia una cadena null-terminada desde ESI hacia EDI (avanza EDI) ---
CopyStr PROC
CopyStrLoop:
    mov al, [esi]
    cmp al, 0
    je CopyStrDone
    mov [edi], al
    inc esi
    inc edi
    jmp CopyStrLoop
CopyStrDone:
    ret
CopyStr ENDP

; --- Convierte un caracter hex ('0'-'9','A'-'C') a su valor 0-12 ---
HexCharToVal PROC
    cmp al, '9'
    jbe HCV_Digit
    sub al, 'A'
    add al, 10
    ret
HCV_Digit:
    sub al, '0'
    ret
HexCharToVal ENDP

; ---------------------------------------------------------------------
; Busca la cadena null-terminada NEEDLE (EDX) dentro de HAYSTACK (ESI,
; tambien null-terminada). Devuelve EAX = puntero justo DESPUES del
; match, o 0 si no se encontro. No importan mayus/minus ya que el
; formato lo generamos siempre nosotros mismos.
; ---------------------------------------------------------------------
FindSubstring PROC
    LOCAL hPtr:DWORD
    mov hPtr, esi
SearchOuter:
    mov esi, hPtr
    mov al, [esi]
    cmp al, 0
    je NotFound

    mov edi, esi
    mov ebx, edx
CompareLoop:
    mov al, [ebx]
    cmp al, 0
    je MatchFound
    mov ah, [edi]
    cmp ah, 0
    je AdvanceOuter
    cmp al, ah
    jne AdvanceOuter
    inc ebx
    inc edi
    jmp CompareLoop

MatchFound:
    mov eax, edi
    ret

AdvanceOuter:
    mov eax, hPtr
    inc eax
    mov hPtr, eax
    jmp SearchOuter

NotFound:
    xor eax, eax
    ret
FindSubstring ENDP

; ---------------------------------------------------------------------
; Escribe game_state.json con el tablero actual, currentTurn (a quien
; le toca AHORA) y el ultimo movimiento (bufferEntrada). El
; sincronizador de Python detecta el cambio y lo sube a Firebase.
; ---------------------------------------------------------------------
WriteGameState PROC
    mov edi, OFFSET jsonOut

    mov esi, OFFSET strJsonHeaderTurn
    call CopyStr

    movzx eax, currentTurn
    add al, '0'
    mov [edi], al
    inc edi

    mov esi, OFFSET strJsonBoardKey
    call CopyStr

    mov ecx, 0
BuildBoardLoop:
    cmp ecx, 64
    jge BuildBoardDone
    movzx eax, board[ecx]
    mov al, hexDigits[eax]
    mov [edi], al
    inc edi
    inc ecx
    jmp BuildBoardLoop
BuildBoardDone:

    mov esi, OFFSET strJsonLastMoveKey
    call CopyStr

    mov esi, OFFSET bufferEntrada
CopyMoveLoop:
    mov al, [esi]
    cmp al, 0
    je CopyMoveDone
    mov [edi], al
    inc esi
    inc edi
    jmp CopyMoveLoop
CopyMoveDone:

    mov esi, OFFSET strJsonFooter
    call CopyStr

    mov BYTE PTR [edi], 0

    mov edx, OFFSET fileName
    call CreateOutputFile
    mov fileHandle, eax
    cmp eax, INVALID_HANDLE_VALUE
    je WGS_Skip

    mov edx, OFFSET jsonOut
    mov eax, edi
    sub eax, OFFSET jsonOut
    mov ecx, eax
    call WriteToFile

    mov eax, fileHandle
    call CloseFile

WGS_Skip:
    ret
WriteGameState ENDP

; ---------------------------------------------------------------------
; Lee game_state.json y actualiza board[], currentTurn y lastSeenMove.
; Devuelve AL=1 si pudo leer un estado valido, AL=0 si el archivo no
; existe o no tiene el formato esperado (partida nueva).
; ---------------------------------------------------------------------
ReadGameState PROC
    mov edx, OFFSET fileName
    call OpenInputFile
    cmp eax, INVALID_HANDLE_VALUE
    je RGS_NoFile
    mov fileHandle, eax

    mov edx, OFFSET jsonIn
    mov ecx, 255
    call ReadFromFile
    mov esi, OFFSET jsonIn
    add esi, eax
    mov BYTE PTR [esi], 0

    mov eax, fileHandle
    call CloseFile

    mov esi, OFFSET jsonIn
    mov edx, OFFSET prefixTurn
    call FindSubstring
    cmp eax, 0
    je RGS_NoFile
    mov ebx, eax
    mov al, [ebx]
    cmp al, '0'
    jb RGS_NoFile
    cmp al, '1'
    ja RGS_NoFile
    sub al, '0'
    mov dl, al                 ; dl = turno leido

    mov esi, OFFSET jsonIn
    mov edx, OFFSET prefixBoard
    call FindSubstring
    cmp eax, 0
    je RGS_NoFile
    mov esi, eax

    mov ecx, 0
ParseBoardLoop:
    cmp ecx, 64
    jge ParseBoardDone
    mov al, [esi]
    call HexCharToVal
    mov board[ecx], al
    inc esi
    inc ecx
    jmp ParseBoardLoop
ParseBoardDone:

    mov currentTurn, dl

    mov esi, OFFSET jsonIn
    mov edx, OFFSET prefixLastMove
    call FindSubstring
    cmp eax, 0
    je RGS_Ok
    mov esi, eax
    mov edi, OFFSET lastSeenMove
CopyLastMoveLoop:
    mov al, [esi]
    cmp al, '"'
    je CopyLastMoveDone
    cmp al, 0
    je CopyLastMoveDone
    mov [edi], al
    inc esi
    inc edi
    jmp CopyLastMoveLoop
CopyLastMoveDone:
    mov BYTE PTR [edi], 0

RGS_Ok:
    mov al, 1
    ret

RGS_NoFile:
    mov al, 0
    ret
ReadGameState ENDP

END main