# ==========================================================
#                  CONFIGURAÇÕES GERAIS
# ==========================================================
# Prefixo da Toolchain RISC-V (ajuste se necessário)
CROSS   = riscv64-unknown-elf
AS      = $(CROSS)-as
LD      = $(CROSS)-ld
OBJCOPY = $(CROSS)-objcopy
OBJDUMP = $(CROSS)-objdump

# ==========================================================
#                   DEFINIÇÃO DE ARQUIVOS
# ==========================================================
# Arquivo Assembly de entrada
SRC     = programa.asm
# Script do Linker (fundamental para a organização da memória)
LDS     = riscv.ld

# Arquivos de saída
OBJ     = $(SRC:.asm=.o)
ELF     = programa.elf
HEX     = programa.hex
LST     = programa.lst

# ==========================================================
#                      REGRAS
# ==========================================================

# Regra Principal: Gera HEX e LST
all: $(HEX) $(LST)
	@echo "Processo concluído: $(HEX) e $(LST) gerados com sucesso."

# 1. Monta o Assembly (RV32I)
# Depende do arquivo Assembly (SRC)
$(OBJ): $(SRC)
	@echo "-> Montando $(SRC)..."
	$(AS) -march=rv32i -o $@ $<

# 2. Linka em 32 bits
# Depende do Objeto (.o) e do Linker Script (.ld)
$(ELF): $(OBJ) $(LDS)
	@echo "-> Linkando em ELF..."
	$(LD) -m elf32lriscv -T $(LDS) -o $@ $<

# 3. Gera o HEX de memória para o Verilog
# Depende do ELF (.elf)
$(HEX): $(ELF)
	@echo "-> Gerando o arquivo HEX $(HEX)..."
	# -O verilog é crucial para o formato de inicialização de memória no Verilog/SystemVerilog
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@

# 4. Gera a Listagem para Debug
# Depende do ELF (.elf)
$(LST): $(ELF)
	@echo "-> Gerando a Listagem $(LST)..."
	$(OBJDUMP) -D $< > $@

# Regra de Limpeza
clean:
	@echo "Limpando arquivos intermediários e de saída..."
	rm -f $(OBJ) $(ELF) $(HEX) $(LST)