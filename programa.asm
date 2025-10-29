# Substituímos .equ por .eqv (RARS-specific)

# Definições de Endereçamento de I/O (baseado no seu testbench)
# Endereço dos LEDs (IO_LEDS_bit = 2 -> 0x00000104)
.eqv LEDS_ADDR, 0x00000104
# Endereço dos Switches (IO_SW_bit = 5 -> 0x00000120)
.eqv SW_ADDR, 0x00000120
# Máscara para o Switch 1 (assumindo que SW[1] é o bit 1 no valor lido de 0x120)
.eqv SW1_MASK, 0x00000002
# Constante para verificar o bit mais significativo (para o wrap)
.eqv MSB_MASK, 0x80000000

.text
.globl _start

_start:
    # Registradores usados:
    # s0: Endereço dos LEDs (LEDS_ADDR)
    # s1: Endereço dos Switches (SW_ADDR)
    # s2: Estado atual do LED (Valor a ser escrito)
    # s3: Estado anterior do Switch 1 (Usado para detecção de borda)
    # t0: Valor lido do SW_ADDR / Constante temporária (MSB_MASK)
    # t1: Resultado da rotação

    # 1. Configuração Inicial
    li s0, LEDS_ADDR        # s0 = 0x104 (Endereço de Escrita dos LEDs)
    li s1, SW_ADDR          # s1 = 0x120 (Endereço de Leitura dos Switches)
    li s2, 1                # s2 = 1 (Padrão inicial de LED: LSB ligado)
    li s3, 0                # s3 = 0 (Estado anterior do SW1: liberado)

    sw s2, 0(s0)            # Escreve o padrão inicial (1) nos LEDs

loop:
    # 2. Leitura do Switch
    lw t0, 0(s1)            # t0 = Lê o valor dos Switches (Endereço 0x120)
    
    # Aplicando a máscara SW1_MASK
    li t1, SW1_MASK         # t1 = 0x2
    and t0, t0, t1          # t0 = Filtra apenas o bit do SW1 (0 ou 0x2)

    # 3. Detecção de Borda (Switch Pressionado: s3=0 -> t0!=0x2)
    bne s3, t0, check_press # Se s3 != t0, houve mudança de estado. Vai para 'check_press'.
    j loop                  # Se não houve mudança, continua lendo e aguarda.

check_press:
    li s3, 0                # Assume que o próximo estado anterior será liberado (default)
    # Verifica se a borda foi de subida (liberado -> pressionado)
    bne t0, zero, is_pressed # Se t0 != 0 (ou seja, t0 = 0x2), significa que o Switch foi Pressionado (0 -> 0x2)
    j loop                  # Se t0 == 0, significa que o Switch foi Liberado (0x2 -> 0). Apenas volta para o loop.

is_pressed:
    # Switch Pressionado (Borda de Subida detectada)
    li s3, SW1_MASK         # Atualiza s3: Agora s3 = 0x2 (Próximo estado anterior é Pressionado)
    
    # 4. Lógica de Rotação (Shift Left e Wrapping)
    slli t1, s2, 1          # t1 = s2 << 1 (Resultado do shift. Ex: 1->2, 0x80000000 -> 0)
    
    # Verifica se o valor atual (s2) era o bit mais significativo (0x80000000).
    li t0, MSB_MASK         # t0 = 0x80000000
    
    bne s2, t0, no_wrap     # Se s2 != 0x80000000, não precisa de wrap. Usa o valor em t1.
    
    # Se s2 == 0x80000000, houve overflow e precisamos fazer o wrap-around.
    li t1, 1                # t1 = 1 (Novo valor é 1 para o wrap)
    
no_wrap:
    mv s2, t1               # s2 = t1 (Atualiza o novo padrão de LED)
    sw s2, 0(s0)            # 5. Escreve o novo padrão nos LEDs
    j loop                  # Volta ao loop para aguardar a liberação do switch