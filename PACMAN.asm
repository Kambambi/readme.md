; ============================================
; PAC-MAN PARA PEPE-16 (VERSÃO FINAL CORRIGIDA)
; ============================================

; --------------------------------------------------
; CONSTANTES
; --------------------------------------------------
BUFFER	EQU	4000H         ; endereço de memória onde se guarda a tecla
PIN     EQU 0E000H       ; Endereço do porto de entrada do teclado
POUT    EQU 0C000H       ; Endereço do porto de saida do teclado
pixelsMatriz EQU 8000H   ; inicio do endereço do ecrã

; Constantes dos Display
displays 	EQU	0A000H	  ; endereço do porto dos displays hexadecimais
nibble_3_0	EQU	000FH     ; máscara para isolar os 4 bits de menor peso
nibble_7_4	EQU	00F0H	  ; máscara para isolar os bits 7 a 4

; --------------------------------------------------
; PILHA
; --------------------------------------------------
stackSize  EQU 100H
PLACE 2000H
pilha: TABLE stackSize
stackBase:

; --------------------------------------------------
; TABELA DE BITS PARA PIXELS
; --------------------------------------------------
PLACE 2200H
ptable: STRING 80H, 40H, 20H, 10H, 08H, 04H, 02H, 01H

; --------------------------------------------------
; VARIÁVEIS DO PAC-MAN
; --------------------------------------------------
PLACE 3200H

; Posições do Pac-Man
linha_pac:      WORD 15
coluna_pac:     WORD 15

; Posições do Fantasma
fantasma_linha:  WORD 14      ; Nasce na caixa central
fantasma_coluna: WORD 14
fantasma_dir:    WORD 3       ; 3 = DIREITA, 2 = ESQUERDA

; Caixa central
caixa_linha:    WORD 14
caixa_coluna:   WORD 14

; Outras variáveis
tecla_atual:    WORD 0FFH
pontuacao:      WORD 0
vidas:          WORD 3
game_active:    WORD 1        ; 1 = jogo ativo, 0 = game over


; --------------------------------------------------
; VARIÁVEIS DOS OBJETOS DOS CANTOS
; --------------------------------------------------
objetos_coletados:  WORD 0      ; contador de objetos coletados (0-4)

; Estados dos objetos (0 = não coletado, 1 = coletado)
objeto_0:          WORD 0      ; canto (0,0)
objeto_1:          WORD 0      ; canto (0,28)
objeto_2:          WORD 0      ; canto (28,0)
objeto_3:          WORD 0      ; canto (28,28)

; --------------------------------------------------
; SPRITES 3x3 CONFORME ENUNCIADO
; --------------------------------------------------
PLACE 3500H

; Sprite Pac-Man (3x3 - "C" virada para direita)
sprite_pacman:
    STRING 1, 1, 0    ; ● ● ○
    STRING 1, 0, 0    ; ● ○ ○  
    STRING 1, 1, 0    ; ● ● ○

; Sprite Fantasma (3x3 - "X")
sprite_fantasma:
    STRING 1, 0, 1    ; ● ○ ●
    STRING 0, 1, 0    ; ○ ● ○
    STRING 1, 0, 1    ; ● ○ ●

; Sprite Canto (3x3 - "+")
sprite_canto:
    STRING 0, 1, 0    ; ○ ● ○
    STRING 1, 1, 1    ; ● ● ●
    STRING 0, 1, 0    ; ○ ● ○

; Sprite Caixa Centro (3x3 - quadrado)
sprite_caixa:
    STRING 1, 1, 1    ; ● ● ●
    STRING 1, 0, 1    ; ● ○ ●
    STRING 1, 1, 1    ; ● ● ●

; --------------------------------------------------
; PROGRAMA PRINCIPAL (SIMPLIFICADO)
; --------------------------------------------------
PLACE 0

inicio:
    MOV SP, stackBase     ; Inicialização do registro da pilha
    CALL Carregamento     ; preprocessamento

; Ciclo principal do jogo
main_loop:
    CALL pTeclado         ; Chama o processo do teclado
    
    ; Verificar se jogo está ativo
    MOV R1, game_active
    MOV R1, [R1]
    CMP R1, 0
    JNZ jogo_ativo
    JMP main_loop

jogo_ativo:
    MOV R1, BUFFER
    MOVB R2, [R1]         ; Valor da tecla pressionada
    
    ; Processar teclas de direção
    MOV R3, R2
    CMP R2, 1H            ; Tecla 1 (CIMA)
    JZ mover_cima

    MOV R4, 9H
    CMP R2, R4            ; Tecla 9 (BAIXO)
    JZ mover_baixo
    CMP R2, 4H            ; Tecla 4 (ESQUERDA)
    JZ mover_esquerda
    CMP R2, 6H            ; Tecla 6 (DIREITA)
    JZ mover_direita
    MOV R4, 0FH
    CMP R2, R4           ; Tecla F (sair)
    JZ terminar_programa
    
    JMP continuar_jogo    ; Tecla não reconhecida

mover_cima:
    CALL mover_pac_cima
    JMP continuar_jogo

mover_baixo:
    CALL mover_pac_baixo
    JMP continuar_jogo

mover_esquerda:
    CALL mover_pac_esquerda
    JMP continuar_jogo

mover_direita:
    CALL mover_pac_direita
    JMP continuar_jogo

continuar_jogo:
    CALL mover_fantasma
    CALL verificar_colisao
    CALL verificar_colisao_objetos
    CALL delay
    
    JMP main_loop
    
terminar_programa:        ; NOVA ROTINA PARA TERMINAR
    ; Limpar tela
    CALL mostrar_game_over
    ; Loop infinito para parar execução
fim_programa:
    JMP fim_programa 

game_over:
    MOV R1, game_active
    MOV R2, 0
    MOV [R1], R2
    CALL mostrar_game_over
    ;JMP main_loop
    RET

; --------------------------------------------------
; FUNÇÃO PIXEL_XY (SIMPLIFICADA)
; --------------------------------------------------
pixel_xy: 
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5
    PUSH R6
    PUSH R7
    
    ; R1 = linha, R2 = coluna
    
    ; Calcular endereço: endereço = 8000H + 4*linha + coluna/8
    MOV R4, R1          ; Copiar linha
    SHL R4, 2           ; R4 = 4 * linha
    
    MOV R5, R2          ; Copiar coluna
    SHR R5, 3           ; R5 = coluna / 8
    
    ADD R4, R5          ; R4 = 4*linha + coluna/8
    MOV R5, pixelsMatriz
    ADD R4, R5          ; R4 = endereço do byte
    
    ; Calcular bit dentro do byte (0-7) sem AND
    ; R5 = coluna mod 8
    MOV R5, R2          ; Copiar coluna
    
calc_mod:
    MOV R6, 8           ; Divisor
mod_loop:
    SUB R5, R6          ; Subtrair 8
    JN mod_done         ; Se negativo, terminou
    JZ mod_done         ; Se zero, terminou
    JMP mod_loop        ; Continue
mod_done:
    ADD R5, R6          ; Adicionar 8 de volta (última subtração foi demais)
    
    ; Obter máscara da tabela ptable
    MOV R6, ptable
    ADD R6, R5          ; R6 = endereço da máscara
    MOVB R7, [R6]       ; R7 = máscara do bit
    
    ; Ativar o pixel
    MOVB R5, [R4]       ; Ler byte atual
    OR R5, R7           ; Ativar o bit
    MOVB [R4], R5       ; Escrever byte atualizado
    
    POP R7
    POP R6
    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; --------------------------------------------------
; FUNÇÃO APAGAR PIXEL ESPECÍFICO
; --------------------------------------------------
; R1 = linha, R2 = coluna
apagar_pixel_xy:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5
    PUSH R6
    PUSH R7
    
    ; Mesmo cálculo que pixel_xy
    MOV R4, R1          ; Copiar linha
    SHL R4, 2           ; R4 = 4 * linha
    
    MOV R5, R2          ; Copiar coluna
    SHR R5, 3           ; R5 = coluna / 8
    
    ADD R4, R5          ; R4 = 4*linha + coluna/8
    MOV R5, pixelsMatriz
    ADD R4, R5          ; R4 = endereço do byte
    
    ; Calcular bit dentro do byte (0-7)
    MOV R5, R2          ; Copiar coluna
    
calc_mod2:
    MOV R6, 8           ; Divisor
mod_loop2:
    SUB R5, R6          ; Subtrair 8
    JN mod_done2        ; Se negativo, terminou
    JZ mod_done2        ; Se zero, terminou
    JMP mod_loop2       ; Continue
mod_done2:
    ADD R5, R6          ; Adicionar 8 de volta
    
    ; Obter máscara da tabela ptable
    MOV R6, ptable
    ADD R6, R5          ; R6 = endereço da máscara
    MOVB R7, [R6]       ; R7 = máscara do bit
    NOT R7              ; Inverter bits para apagar
    
    ; Apagar o pixel
    MOVB R5, [R4]       ; Ler byte atual
    AND R5, R7          ; Apagar o bit
    MOVB [R4], R5       ; Escrever byte atualizado
    
    POP R7
    POP R6
    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; --------------------------------------------------
; DESENHAR SPRITE 3x3 (SIMPLIFICADA)
; --------------------------------------------------
; R1 = linha base, R2 = coluna base, R3 = endereço do sprite
desenhar_sprite_3x3:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5
    PUSH R6
    
    MOV R5, R1          ; Guardar linha base
    MOV R6, R2          ; Guardar coluna base
    
    ; Ler todos os pixels do sprite
    MOVB R4, [R3]       ; Pixel (0,0)
    MOV R1, R4
    SUB R1, 0
    JZ sprite_01
    MOV R1, R5
    MOV R2, R6
    CALL pixel_xy
    
sprite_01:
    ADD R3, 1
    MOVB R4, [R3]       ; Pixel (0,1)
    MOV R1, R4
    SUB R1, 0
    JZ sprite_02
    MOV R1, R5
    MOV R2, R6
    ADD R2, 1
    CALL pixel_xy
    
sprite_02:
    ADD R3, 1
    MOVB R4, [R3]       ; Pixel (0,2)
    MOV R1, R4
    SUB R1, 0
    JZ sprite_10
    MOV R1, R5
    MOV R2, R6
    ADD R2, 2
    CALL pixel_xy
    
sprite_10:
    ADD R3, 1
    MOVB R4, [R3]       ; Pixel (1,0)
    MOV R1, R4
    SUB R1, 0
    JZ sprite_11
    MOV R1, R5
    ADD R1, 1
    MOV R2, R6
    CALL pixel_xy
    
sprite_11:
    ADD R3, 1
    MOVB R4, [R3]       ; Pixel (1,1)
    MOV R1, R4
    SUB R1, 0
    JZ sprite_12
    MOV R1, R5
    ADD R1, 1
    MOV R2, R6
    ADD R2, 1
    CALL pixel_xy
    
sprite_12:
    ADD R3, 1
    MOVB R4, [R3]       ; Pixel (1,2)
    MOV R1, R4
    SUB R1, 0
    JZ sprite_20
    MOV R1, R5
    ADD R1, 1
    MOV R2, R6
    ADD R2, 2
    CALL pixel_xy
    
sprite_20:
    ADD R3, 1
    MOVB R4, [R3]       ; Pixel (2,0)
    MOV R1, R4
    SUB R1, 0
    JZ sprite_21
    MOV R1, R5
    ADD R1, 2
    MOV R2, R6
    CALL pixel_xy
    
sprite_21:
    ADD R3, 1
    MOVB R4, [R3]       ; Pixel (2,1)
    MOV R1, R4
    SUB R1, 0
    JZ sprite_22
    MOV R1, R5
    ADD R1, 2
    MOV R2, R6
    ADD R2, 1
    CALL pixel_xy
    
sprite_22:
    ADD R3, 1
    MOVB R4, [R3]       ; Pixel (2,2)
    MOV R1, R4
    SUB R1, 0
    JZ fim_desenhar_sprite
    MOV R1, R5
    ADD R1, 2
    MOV R2, R6
    ADD R2, 2
    CALL pixel_xy
    
fim_desenhar_sprite:
    POP R6
    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; --------------------------------------------------
; DESENHAR PAC-MAN
; --------------------------------------------------
desenhar_pacman:
    PUSH R1
    PUSH R2
    PUSH R3
    
    MOV R1, linha_pac
    MOV R1, [R1]
    MOV R2, coluna_pac
    MOV R2, [R2]
    MOV R3, sprite_pacman
    
    CALL desenhar_sprite_3x3
    
    POP R3
    POP R2
    POP R1
    RET

; --------------------------------------------------
; DESENHAR FANTASMA
; --------------------------------------------------
desenhar_fantasma:
    PUSH R1
    PUSH R2
    PUSH R3
    
    MOV R1, fantasma_linha
    MOV R1, [R1]
    MOV R2, fantasma_coluna
    MOV R2, [R2]
    MOV R3, sprite_fantasma
    
    CALL desenhar_sprite_3x3
    
    POP R3
    POP R2
    POP R1
    RET


; --------------------------------------------------
; DESENHAR CANTOS (APENAS OS NÃO COLETADOS)
; --------------------------------------------------
desenhar_cantos:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    
    ; Canto 0 (0,0)
    MOV R1, objeto_0
    MOV R1, [R1]
    MOV R2, R1
    SUB R2, 0
    JNZ ver_objeto1      ; Se já coletado, não desenha
    
    MOV R1, 0
    MOV R2, 0
    MOV R3, sprite_canto
    CALL desenhar_sprite_3x3
    
ver_objeto1:
    ; Canto 1 (0,28)
    MOV R1, objeto_1
    MOV R1, [R1]
    MOV R2, R1
    SUB R2, 0
    JNZ ver_objeto2
    
    MOV R1, 0
    MOV R2, 28
    MOV R3, sprite_canto
    CALL desenhar_sprite_3x3
    
ver_objeto2:
    ; Canto 2 (28,0)
    MOV R1, objeto_2
    MOV R1, [R1]
    MOV R2, R1
    SUB R2, 0
    JNZ ver_objeto3
    
    MOV R1, 28
    MOV R2, 0
    MOV R3, sprite_canto
    CALL desenhar_sprite_3x3
    
ver_objeto3:
    ; Canto 3 (28,28)
    MOV R1, objeto_3
    MOV R1, [R1]
    MOV R2, R1
    SUB R2, 0
    JNZ fim_desenhar_cantos
    
    MOV R1, 28
    MOV R2, 28
    MOV R3, sprite_canto
    CALL desenhar_sprite_3x3
    
fim_desenhar_cantos:
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; --------------------------------------------------
; APAGAR SPRITE 3x3 (SIMPLIFICADA)
; --------------------------------------------------
; R1 = linha base, R2 = coluna base
apagar_sprite_3x3:
    PUSH R1
    PUSH R2
    PUSH R3
    
    MOV R3, R1          ; Guardar linha base
    
    ; Apagar 3x3 área
    MOV R1, R3
    CALL apagar_pixel_xy       ; (0,0)
    
    ADD R2, 1
    CALL apagar_pixel_xy       ; (0,1)
    
    ADD R2, 1
    CALL apagar_pixel_xy       ; (0,2)
    
    SUB R2, 2           ; Voltar à coluna base
    MOV R1, R3
    ADD R1, 1           ; Linha +1
    CALL apagar_pixel_xy       ; (1,0)
    
    ADD R2, 1
    CALL apagar_pixel_xy       ; (1,1)
    
    ADD R2, 1
    CALL apagar_pixel_xy       ; (1,2)
    
    SUB R2, 2           ; Voltar à coluna base
    MOV R1, R3
    ADD R1, 2           ; Linha +2
    CALL apagar_pixel_xy       ; (2,0)
    
    ADD R2, 1
    CALL apagar_pixel_xy       ; (2,1)
    
    ADD R2, 1
    CALL apagar_pixel_xy       ; (2,2)
    
    POP R3
    POP R2
    POP R1
    RET

; --------------------------------------------------
; MOVER PAC-MAN PARA CIMA
; --------------------------------------------------
mover_pac_cima:
    PUSH R1
    PUSH R2
    
    ; Apagar na posição atual
    MOV R1, linha_pac
    MOV R1, [R1]
    MOV R2, coluna_pac
    MOV R2, [R2]
    CALL apagar_sprite_3x3
    
    ; Atualizar posição
    MOV R1, linha_pac
    MOV R2, [R1]
    MOV R3, R2
    SUB R3, 0           ; Verificar se linha = 0
    JZ fim_mover_cima
    
    SUB R2, 1           ; Mover para cima
    MOV [R1], R2
    
    ; Desenhar na nova posição
    CALL desenhar_pacman
    
fim_mover_cima:
    POP R2
    POP R1
    RET

; --------------------------------------------------
; MOVER PAC-MAN PARA BAIXO
; --------------------------------------------------
mover_pac_baixo:
    PUSH R1
    PUSH R2
    
    ; Apagar na posição atual
    MOV R1, linha_pac
    MOV R1, [R1]
    MOV R2, coluna_pac
    MOV R2, [R2]
    CALL apagar_sprite_3x3
    
    ; Atualizar posição
    MOV R1, linha_pac
    MOV R2, [R1]
    MOV R3, R2
    MOV R4, 28          ; Limite inferior para sprite 3x3
    SUB R3, R4          ; Verificar se linha >= 28
    JZ fim_mover_baixo  ; Se igual a 28
    JN baixo_pode_mover ; Se negativo, pode mover
    JMP fim_mover_baixo ; Se positivo, não pode mover
    
baixo_pode_mover:
    ADD R2, 1           ; Mover para baixo
    MOV [R1], R2
    
    ; Desenhar na nova posição
    CALL desenhar_pacman
    
fim_mover_baixo:
    POP R2
    POP R1
    RET

; --------------------------------------------------
; MOVER PAC-MAN PARA ESQUERDA
; --------------------------------------------------
mover_pac_esquerda:
    PUSH R1
    PUSH R2
    
    ; Apagar na posição atual
    MOV R1, linha_pac
    MOV R1, [R1]
    MOV R2, coluna_pac
    MOV R2, [R2]
    CALL apagar_sprite_3x3
    
    ; Atualizar posição
    MOV R1, coluna_pac
    MOV R2, [R1]
    MOV R3, R2
    SUB R3, 0           ; Verificar se coluna = 0
    JZ fim_mover_esquerda
    
    SUB R2, 1           ; Mover para esquerda
    MOV [R1], R2
    
    ; Desenhar na nova posição
    CALL desenhar_pacman
    
fim_mover_esquerda:
    POP R2
    POP R1
    RET

; --------------------------------------------------
; MOVER PAC-MAN PARA DIREITA
; --------------------------------------------------
mover_pac_direita:
    PUSH R1
    PUSH R2
    
    ; Apagar na posição atual
    MOV R1, linha_pac
    MOV R1, [R1]
    MOV R2, coluna_pac
    MOV R2, [R2]
    CALL apagar_sprite_3x3
    
    ; Atualizar posição
    MOV R1, coluna_pac
    MOV R2, [R1]
    MOV R3, R2
    MOV R4, 28          ; Limite direito para sprite 3x3
    SUB R3, R4          ; Verificar se coluna >= 28
    JZ fim_mover_direita
    JN direita_pode_mover
    JMP fim_mover_direita
    
direita_pode_mover:
    ADD R2, 1           ; Mover para direita
    MOV [R1], R2
    
    ; Desenhar na nova posição
    CALL desenhar_pacman
    
fim_mover_direita:
    POP R2
    POP R1
    RET

; --------------------------------------------------
; MOVER FANTASMA (SIMPLIFICADO)
; --------------------------------------------------
mover_fantasma:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    
    ; Apagar fantasma na posição atual
    MOV R1, fantasma_linha
    MOV R1, [R1]
    MOV R2, fantasma_coluna
    MOV R2, [R2]
    CALL apagar_sprite_3x3
    
    ; Obter direção atual
    MOV R1, fantasma_dir
    MOV R3, [R1]        ; Direção (2=esquerda, 3=direita)
    
    ; Obter posição atual
    MOV R1, fantasma_coluna
    MOV R4, [R1]        ; Coluna atual
    
    ; Verificar direção
    MOV R1, R3
    SUB R1, 3           ; É direita?
    JZ mover_direita_fantasma
    
    ; ESQUERDA (2)
    MOV R1, R4
    SUB R1, 0           ; Coluna = 0?
    JZ mudar_para_direita_f
    
    ; Mover para esquerda
    MOV R1, fantasma_coluna
    MOV R4, [R1]
    SUB R4, 1
    MOV [R1], R4
    JMP fim_mover_fantasma
    
mudar_para_direita_f:
    ; Mudar direção para direita
    MOV R1, fantasma_dir
    MOV R2, 3
    MOV [R1], R2
    MOV R1, fantasma_coluna
    MOV R4, [R1]
    ADD R4, 1
    MOV [R1], R4
    JMP fim_mover_fantasma
    
mover_direita_fantasma:
    MOV R1, R4
    MOV R2, 28          ; Limite direito
    SUB R1, R2          ; Coluna >= 28?
    JZ mudar_para_esquerda_f
    JN continuar_direita_f
    
mudar_para_esquerda_f:
    ; Mudar direção para esquerda
    MOV R1, fantasma_dir
    MOV R2, 2
    MOV [R1], R2
    MOV R1, fantasma_coluna
    MOV R4, [R1]
    SUB R4, 1
    MOV [R1], R4
    JMP fim_mover_fantasma
    
continuar_direita_f:
    ; Mover para direita
    MOV R1, fantasma_coluna
    MOV R4, [R1]
    ADD R4, 1
    MOV [R1], R4
    
fim_mover_fantasma:
    ; Desenhar fantasma na nova posição
    CALL desenhar_fantasma
    
    POP R4
    POP R3
    POP R2
    POP R1
    RET


; --------------------------------------------------
; VERIFICAR COLISÃO COM OBJETOS DOS CANTOS
; --------------------------------------------------
verificar_colisao_objetos:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5
    
    ; Posição do Pac-Man
    MOV R1, linha_pac
    MOV R1, [R1]
    MOV R2, coluna_pac
    MOV R2, [R2]
    
    ; Verificar cada canto
    CALL verificar_objeto_0
    CALL verificar_objeto_1
    CALL verificar_objeto_2
    CALL verificar_objeto_3
    
    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; --------------------------------------------------
; VERIFICAR OBJETO 0 (0,0)
; --------------------------------------------------
verificar_objeto_0:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    
    ; Verificar se já foi coletado
    MOV R3, objeto_0
    MOV R4, [R3]
    SUB R4, 0
    JNZ fim_verificar_0  ; Já coletado
    
    ; Posição do objeto (0,0) - centro do sprite 3x3 está em (1,1)
    ; Para colisão simples, verificar se Pac-Man está na área 3x3
    MOV R3, R1          ; linha Pac-Man
    SUB R3, 0           ; linha >= 0?
    JN fim_verificar_0
    MOV R3, R1
    SUB R3, 2
    ;JN dentro_linha_0
    JGT fim_verificar_0

    MOV R4, 2           ; linha <= 2?
    SUB R3, 0
    JN fim_verificar_0

    MOV R3, R2           ; linha <= 2?
    SUB R3, 2
    JGT fim_verificar_0

    MOV R3, objeto_0
    MOV R4, 1
    MOV[R3], R4

    MOV R3, objetos_coletados
    MOV R4, [R3]
    ADD R4, 1
    MOV [R3], R4

    MOV R1, 0
    MOV R2, 0
    CALL apagar_sprite_3x3

    MOV R3, objetos_coletados
    MOV R4, [R3]
    SUB R4, 4
    JZ vitoria_sir

    POP R4
    POP R3
    POP R2
    POP R1
    RET

vitoria_sir:
    CALL vitoria
    
dentro_linha_0:
    MOV R3, R1          ; coluna Pac-Man
    SUB R3, 0           ; coluna >= 0?
    JN fim_verificar_0
    MOV R3, R1
    MOV R4, 2           ; coluna <= 2?
    SUB R3, R4
    ;JN dentro_coluna_0
    JMP fim_verificar_0
    
dentro_coluna_0:
    ; COLISÃO DETETADA - coletar objeto 0
    MOV R3, R2
    SUB R3, 0
    JN fim_verificar_0
    MOV R3, R2
    MOV R4, 2
    SUB R3, R4
    JGT fim_verificar_0
    
    ; Incrementar contador
    MOV R3, objetos_coletados
    MOV R4, [R3]
    ADD R4, 1
    MOV [R3], R4
    
    ; Apagar objeto do ecrã
    MOV R1, 0
    MOV R2, 0
    CALL apagar_sprite_3x3
    
    ; Verificar se ganhou
    MOV R3, objetos_coletados
    MOV R4, [R3]
    MOV R5, R4
    SUB R5, 4
    JZ vitoria_sair
    RET
vitoria_sair:
    CALL vitoria

fim_verificar_0:
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; --------------------------------------------------
; VERIFICAR OBJETO 1 (0,28)
; --------------------------------------------------
verificar_objeto_1:
PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    
    ; Verificar se já foi coletado
    MOV R3, objeto_0
    MOV R4, [R3]
    SUB R4, 0
    JNZ fim_verificar_0  ; Já coletado
    
    ; Posição do objeto (0,0) - centro do sprite 3x3 está em (1,1)
    ; Para colisão simples, verificar se Pac-Man está na área 3x3
    MOV R3, R1          ; linha Pac-Man
    SUB R3, 0           ; linha >= 0?
    JN fim_verificar_0
    MOV R3, R1
    SUB R3, 2
    ;JN dentro_linha_0
    JGT fim_verificar_0

    MOV R4, 2           ; linha <= 2?
    SUB R3, 0
    JN fim_verificar_0

    MOV R3, R2           ; linha <= 2?
    SUB R3, 2
    JGT fim_verificar_0

    MOV R3, objeto_0
    MOV R4, 1
    MOV[R3], R4

    MOV R3, objetos_coletados
    MOV R4, [R3]
    ADD R4, 1
    MOV [R3], R4

    MOV R1, 0
    MOV R2, 0
    CALL apagar_sprite_3x3

    MOV R3, objetos_coletados
    MOV R4, [R3]
    SUB R4, 4
    JZ vitoria_si

    POP R4
    POP R3
    POP R2
    POP R1
    RET

vitoria_si:
    CALL vitoria
    
    
dentro_linha_1:
    MOV R3, R2          ; coluna
    MOV R4, 28
    SUB R3, R4
    JN fim_verificar_1
    MOV R3, R2
    MOV R4, 30
    SUB R3, R4
    JN dentro_coluna_1
    JMP fim_verificar_1
    
dentro_coluna_1:
    ; Coletar objeto 1
    MOV R3, objeto_1
    MOV R4, 1
    MOV [R3], R4
    
    MOV R3, objetos_coletados
    MOV R4, [R3]
    ADD R4, 1
    MOV [R3], R4
    
    ; Apagar objeto
    MOV R1, 0
    MOV R2, 28
    CALL apagar_sprite_3x3
    
    ; Verificar vitória
    MOV R3, objetos_coletados
    MOV R4, [R3]
    MOV R5, R4
    SUB R5, 4
    JZ vitoria_sai
    RET
vitoria_sai:
    CALL vitoria

    
fim_verificar_1:
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; --------------------------------------------------
; VERIFICAR OBJETO 2 (28,0)
; --------------------------------------------------
verificar_objeto_2:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    
    MOV R3, objeto_2
    MOV R4, [R3]
    SUB R4, 0
    JNZ fim_verificar_2
    
    ; Objeto em (28,0) - área: linhas 28-30, colunas 0-2
    MOV R3, R1          ; linha
    MOV R4, 28
    SUB R3, R4
    JN fim_verificar_2
    MOV R3, R1
    MOV R4, 30
    SUB R3, R4
    JN dentro_linha_2
    JMP fim_verificar_2
    
dentro_linha_2:
    MOV R3, R2          ; coluna
    SUB R3, 1
    JN fim_verificar_2
    MOV R3, R2
    MOV R4, 2
    SUB R3, R4
    JN dentro_coluna_2
    JMP fim_verificar_2
    
dentro_coluna_2:
    ; Coletar objeto 2
    MOV R3, objeto_2
    MOV R4, 1
    MOV [R3], R4
    
    MOV R3, objetos_coletados
    MOV R4, [R3]
    ADD R4, 1
    MOV [R3], R4
    
    ; Apagar objeto
    MOV R1, 28
    MOV R2, 0
    CALL apagar_sprite_3x3
    
    ; Verificar vitória
    MOV R3, objetos_coletados
    MOV R4, [R3]
    MOV R5, R4
    SUB R5, 4
    JZ vitoria_sa
    RET
vitoria_sa:
    CALL vitoria



    
fim_verificar_2:
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; --------------------------------------------------
; VERIFICAR OBJETO 3 (28,28)
; --------------------------------------------------
verificar_objeto_3:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    
    MOV R3, objeto_3
    MOV R4, [R3]
    SUB R4, 0
    JNZ fim_verificar_3
    
    ; Objeto em (28,28) - área: linhas 28-30, colunas 28-30
    MOV R3, R1          ; linha
    MOV R4, 28
    SUB R3, R4
    JN fim_verificar_3
    MOV R3, R1
    MOV R4, 30
    SUB R3, R4
    JN dentro_linha_3
    JMP fim_verificar_3
    
dentro_linha_3:
    MOV R3, R2          ; coluna
    MOV R4, 28
    SUB R3, R4
    JN fim_verificar_3
    MOV R3, R2
    MOV R4, 30
    SUB R3, R4
    JN dentro_coluna_3
    JMP fim_verificar_3
    
dentro_coluna_3:
    ; Coletar objeto 3
    MOV R3, objeto_3
    MOV R4, 1
    MOV [R3], R4
    
    MOV R3, objetos_coletados
    MOV R4, [R3]
    ADD R4, 1
    MOV [R3], R4
    
    ; Apagar objeto
    MOV R1, 28
    MOV R2, 28
    CALL apagar_sprite_3x3
    
    ; Verificar vitória
    MOV R3, objetos_coletados
    MOV R4, [R3]
    MOV R5, R4
    SUB R5, 4
    JZ vitoria_s
    RET
vitoria_s:
    CALL vitoria


contianua_:
    
fim_verificar_3:
    POP R4
    POP R3
    POP R2
    POP R1
    RET


; --------------------------------------------------
; VERIFICAR COLISÃO (SIMPLIFICADA)
; --------------------------------------------------
verificar_colisao:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    
    ; Obter posições
    MOV R1, linha_pac
    MOV R1, [R1]
    MOV R2, coluna_pac
    MOV R2, [R2]
    MOV R3, fantasma_linha
    MOV R3, [R3]
    MOV R4, fantasma_coluna
    MOV R4, [R4]
    
    ; Verificar se posições são iguais (colisão simples)
    MOV R5, R1
    SUB R5, R3          ; Comparar linhas
    JNZ sem_colisao     ; Se diferente, sem colisão
    
    MOV R5, R2
    SUB R5, R4          ; Comparar colunas
    JNZ sem_colisao     ; Se diferente, sem colisão
    
    ; COLISÃO DETECTADA
    CALL perder_vida
    
sem_colisao:
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; --------------------------------------------------
; PERDER VIDA
; --------------------------------------------------
perder_vida:
    PUSH R1
    PUSH R2
    
    MOV R1, vidas
    MOV R2, [R1]
    MOV R3, R2
    SUB R3, 0           ; Verificar se vidas = 0
    JZ game_over_screen
    
    SUB R2, 1           ; Perder uma vida
    MOV [R1], R2
    
    ; Apagar Pac-Man
    MOV R1, linha_pac
    MOV R1, [R1]
    MOV R2, coluna_pac
    MOV R2, [R2]
    CALL apagar_sprite_3x3
    
    ; Reposicionar Pac-Man
    MOV R1, linha_pac
    MOV R2, 15
    MOV [R1], R2
    MOV R1, coluna_pac
    MOV [R1], R2
    
    ; Desenhar Pac-Man
    CALL desenhar_pacman
    
    POP R2
    POP R1
    RET
    
;===========================================
; GAME_OVRR_SCREEN
;==========================================
game_over_screen:
    ; Desativar jogo
    MOV R1, game_active
    MOV R2, 0
    MOV [R1], R2
    
    CALL mostrar_game_over

    RET

; --------------------------------------------------
; VITÓRIA
; --------------------------------------------------
vitoria:
    PUSH R1
    PUSH R2
    
    ; Desativar jogo
    MOV R1, game_active
    MOV R2, 0
    MOV [R1], R2
    
    ; Mostrar mensagem de vitória
    CALL mostrar_vitoria
    

    POP R2
    POP R1
    RET

; --------------------------------------------------
; MOSTRAR VITÓRIA
; --------------------------------------------------
mostrar_vitoria:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    
    ; Limpar tela
    MOV R1, 8000h
    MOV R2, 8080h
    MOV R3, 0H
    
limpar_tela_vitoria:
    MOVB [R1], R3
    ADD R1, 1H
    MOV R4, R1
    SUB R4, R2
    JN limpar_tela_vitoria
    
    ; Mostrar "VIT" no centro
    ; Desenhar 'V' (15,13)
    MOV R1, 15
    MOV R2, 13
    CALL desenhar_V
    
    ; Desenhar 'I' (15,17)
    MOV R1, 15
    MOV R2, 17
    CALL desenhar_I
    
    ; Desenhar 'T' (15,21)
    MOV R1, 15
    MOV R2, 21
    CALL desenhar_T
    
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; Letras para VITÓRIA
desenhar_V:
    ; Linha 1: #   #
    MOV R3, R1
    MOV R4, R2
    CALL pixel_xy
    ADD R4, 4
    CALL pixel_xy
    
    ; Linha 2: #   #
    ADD R3, 1
    MOV R4, R2
    CALL pixel_xy
    ADD R4, 4
    CALL pixel_xy
    
    ; Linha 3: #   #
    ADD R3, 1
    MOV R4, R2
    CALL pixel_xy
    ADD R4, 4
    CALL pixel_xy
    
    ; Linha 4:  # #
    ADD R3, 1
    MOV R4, R2
    ADD R4, 1
    CALL pixel_xy
    ADD R4, 2
    CALL pixel_xy
    
    ; Linha 5:   #
    ADD R3, 1
    MOV R4, R2
    ADD R4, 2
    CALL pixel_xy
    RET

desenhar_I:
    ; Linha 1: #####
    MOV R3, R1
    MOV R4, R2
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    
    ; Linha 2:   #
    ADD R3, 1
    MOV R4, R2
    ADD R4, 2
    CALL pixel_xy
    
    ; Linha 3:   #
    ADD R3, 1
    MOV R4, R2
    ADD R4, 2
    CALL pixel_xy
    
    ; Linha 4:   #
    ADD R3, 1
    MOV R4, R2
    ADD R4, 2
    CALL pixel_xy
    
    ; Linha 5: #####
    ADD R3, 1
    MOV R4, R2
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    RET

desenhar_T:
    ; Linha 1: #####
    MOV R3, R1
    MOV R4, R2
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    
    ; Linha 2-5:   #
    MOV R3, R1
    ADD R3, 1
    MOV R4, R2
    ADD R4, 2
    CALL pixel_xy
    
    ADD R3, 1
    CALL pixel_xy
    
    ADD R3, 1
    CALL pixel_xy
    
    ADD R3, 1
    CALL pixel_xy
    RET


; --------------------------------------------------
; MOSTRAR GAME OVER (ATUALIZADA)
; --------------------------------------------------
mostrar_game_over:
    PUSH R1
    PUSH R2
    PUSH R3
    
    ; Limpar tela
    MOV R1, 8000h
    MOV R2, 8080h
    MOV R3, 0H
    
limpar_tela_loop:
    MOVB [R1], R3
    ADD R1, 1H
    MOV R4, R1
    SUB R4, R2
    JN limpar_tela_loop
    
    ; Opcional: mostrar mensagem "FIM" no centro
    ; Desenhar 'F' no centro
    MOV R1, 15           ; Linha do centro
    MOV R2, 13           ; Coluna para começar 'F'
    
    ; Desenhar F (3x5 pixels)
    ; Linha 1: ###
    MOV R3, R1
    MOV R4, R2
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    
    ; Linha 2: #
    MOV R3, R1
    ADD R3, 1
    MOV R4, R2
    CALL pixel_xy
    
    ; Linha 3: ###
    MOV R3, R1
    ADD R3, 2
    MOV R4, R2
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    ADD R4, 1
    CALL pixel_xy
    
    ; Linha 4: #
    MOV R3, R1
    ADD R3, 3
    MOV R4, R2
    CALL pixel_xy
    
    ; Linha 5: #
    MOV R3, R1
    ADD R3, 4
    MOV R4, R2
    CALL pixel_xy
    
    POP R3
    POP R2
    POP R1
    RET


;---------------------------------------------
;DESENHAR Caixa central
;---------------------------------------------

desenhar_caixa_central:
PUSH R1
PUSH R2
PUSH R3

MOV R1, 14
MOV R2, 14
MOV R3, sprite_caixa

CALL desenhar_sprite_3x3

POP R3
POP R2
POP R1
RET

; --------------------------------------------------
; CARREGAMENTO INICIAL
; --------------------------------------------------
Carregamento:
    PUSH R1
    PUSH R2
    
    ; Limpar buffer do teclado
    MOV R1, BUFFER
    MOV R2, 0
    MOVB [R1], R2
    
    ; Ativar jogo
    MOV R1, game_active
    MOV R2, 1
    MOV [R1], R2
    
    ; Inicializar posições do Pac-Man
    MOV R1, linha_pac
    MOV R2, 15
    MOV [R1], R2
    MOV R1, coluna_pac
    MOV [R1], R2
    
    ; Fantasma nasce na caixa central
    MOV R1, fantasma_linha
    MOV R2, 14
    MOV [R1], R2
    MOV R1, fantasma_coluna
    MOV [R1], R2
    
    MOV R1, fantasma_dir
    MOV R2, 3
    MOV [R1], R2
    
    ; Inicializar vidas e pontuação
    MOV R1, vidas
    MOV R2, 3
    MOV [R1], R2
    
    MOV R1, pontuacao
    MOV R2, 0
    MOV [R1], R2
    
    
    ; Inicializar objetos dos cantos
    MOV R1, objetos_coletados
    MOV R2, 0
    MOV [R1], R2
    
    MOV R1, objeto_0
    MOV [R1], R2
    
    MOV R1, objeto_1
    MOV [R1], R2
    
    MOV R1, objeto_2
    MOV [R1], R2
    
    MOV R1, objeto_3
    MOV [R1], R2

    ; Limpar tela
    CALL mostrar_game_over

    ; Desenhar elementos do jogo
    CALL desenhar_cantos
    CALL desenhar_caixa_central
    CALL desenhar_pacman
    CALL desenhar_fantasma
    
    POP R2
    POP R1
    RET

; --------------------------------------------------
; DELAY
; --------------------------------------------------
delay:
    PUSH R1
    PUSH R2
    PUSH R3
    MOV R1, 5
delay_externo:
    MOV R2, 50
delay_loop:
    MOV R3, 20
delay_interno:
    SUB R3, 1
    JNZ delay_interno
    SUB R2, 1
    JNZ delay_loop
    SUB R1, 1
    POP R3
    POP R2
    POP R1
    RET


; --------------------------------------------------
; TECLADO (ADAPTADO DO SEU CÓDIGO)
; --------------------------------------------------
pTeclado:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5
    PUSH R6
    PUSH R8
    PUSH R10
    
    MOV R5, BUFFER        ; R5 com endereço de memoria BUFFER
    MOV R1, 1             ; testar a linha 1
    MOV R6, PIN           ; R6 com endereço do porto de entrada
    MOV R2, POUT          ; R2 com o endereço do porto de saida

; Corpo principal do programa

ciclo:
    MOVB [R2], R1         ; escrever no porto de saida
    MOVB R3, [R6]         ; ler do porto de entrada
    AND R3, R3            ; afectar as flags (MOVs não afectam as flags)
    JZ inicializarLinha   ; Se nenhuma tecla foi premida
    
    ; Verificar qual linha foi pressionada
    MOV R8, 1
    CMP R8, R1
    JZ linha1
    MOV R8, 2
    CMP R8, R1
    JZ linha2
    MOV R8, 4
    CMP R8, R1
    JZ linha3
    MOV R8, 8
    CMP R8, R1
    JZ linha4
    JMP fim_teclado_nenhuma

; Esta etiqueta verifica qual coluna e tecla da quarta linha foi primida

linha4:
    linha4C1:
        MOV R8, 1
        CMP R8, R3
        JZ EC
        JNZ linha4C2
    linha4C2:
        MOV R8, 2
        CMP R8, R3
        JZ ED
        JNZ linha4C3
    linha4C3:
        MOV R8, 4
        CMP R8, R3
        JZ EE
        JNZ linha4C4
    linha4C4:
        MOV R8, 8
        CMP R8, R3
        JZ EF
        JMP fim_teclado_nenhuma

; Esta etiqueta verifica qual coluna e tecla da terceira linha foi primida

linha3:
    linha3C1:
        MOV R8, 1
        CMP R8, R3
        JZ Esete
        JNZ linha3C2
    linha3C2:
        MOV R8, 2
        CMP R8, R3
        JZ Eoito
        JNZ linha3C3
    linha3C3:
        MOV R8, 4
        CMP R8, R3
        JZ Enove
        JNZ linha3C4
    linha3C4:
        MOV R8, 8
        CMP R8, R3
        JZ EA
        JMP fim_teclado_nenhuma

; Esta etiqueta verifica qual coluna e tecla da segunda linha foi primida

linha2:
    linha2C1:
        MOV R8, 1
        CMP R8, R3
        JZ Equatro
        JNZ linha2C2
    linha2C2:
        MOV R8, 2
        CMP R8, R3
        JZ Ecinco
        JNZ linha2C3
    linha2C3:
        MOV R8, 4
        CMP R8, R3
        JZ Eseis
        JNZ linha2C4
    linha2C4:
        MOV R8, 8
        CMP R8, R3
        JZ Ezero
        JMP fim_teclado_nenhuma

; Esta etiqueta verifica qual coluna e tecla da primeira linha foi primida

linha1:
    linha1C1:
        MOV R8, 1
        CMP R8, R3
        JZ Eum
        JNZ linha1C2
    linha1C2:
        MOV R8, 2
        CMP R8, R3
        JZ Edois
        JNZ linha1C3
    linha1C3:
        MOV R8, 4
        CMP R8, R3
        JZ Etres
        JNZ linha1C4
    linha1C4:
        MOV R8, 8
        CMP R8, R3
        JZ EF           ; Na sua versão original era "tres", mas ajustei para layout comum
        JMP fim_teclado_nenhuma

; Mapeamento das teclas (ajustado para o seu jogo Pac-Man)
Ezero:
    MOV R10, 0H
    JMP armazena
Eum:
    MOV R10, 1H
    JMP armazena
Edois:
    MOV R10, 2H
    JMP armazena
Etres:
    MOV R10, 3H
    JMP armazena
Equatro:
    MOV R10, 4H
    JMP armazena
Ecinco:
    MOV R10, 5H
    JMP armazena
Eseis:
    MOV R10, 6H
    JMP armazena
Esete:
    MOV R10, 7H
    JMP armazena
Eoito:
    MOV R10, 8H
    JMP armazena
Enove:
    MOV R10, 9H
    JMP armazena
EA:
    MOV R10, 0AH
    JMP armazena
; EB, EC, ED, EE não são usados no seu jogo, mas mantenho por completude
EB:
    MOV R10, 0BH
    JMP armazena
EC:
    MOV R10, 0CH
    JMP armazena
ED:
    MOV R10, 0DH
    JMP armazena
EE:
    MOV R10, 0EH
    JMP armazena
EF:
    MOV R10, 0FH        ; Tecla F para sair

; Esta etiqueta armazena a tecla digitada na memoria
armazena:
    MOVB [R5], R10      ; guarda tecla premida em memória
    JMP fim_teclado

; Esta etiqueta verifica se a linha passou a quarta
inicializarLinha:
    MOV R8, 2
    MUL R1, R8           ; Multiplica a linha por 2
    MOV R8, 16           ; Verificar se passou de 8 (1000b)
    CMP R1, R8
    JLT ciclo            ; Se menor que 16, continua
    
    ; Se chegou aqui, nenhuma tecla foi pressionada
    MOV R10, 0FFH        ; Valor para "nenhuma tecla"
    MOVB [R5], R10
    JMP fim_teclado

fim_teclado_nenhuma:
    MOV R10, 0FFH
    MOVB [R5], R10

fim_teclado:
    POP R10
    POP R8
    POP R6
    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; --------------------------------------------------
; FIM DO PROGRAMA
; --------------------------------------------------