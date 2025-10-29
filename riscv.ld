/*
 * Arquivo: riscv.ld
 * Descrição: Linker Script básico para um programa RISC-V RV32I em ambiente bare-metal.
 * Define o mapa de memória e coloca o código na posição inicial.
 */

/* ==========================================================
 * 1. DEFINIÇÃO DE MEMÓRIAS
 * ========================================================== */

/* Definimos uma única região de RAM que será usada para código e dados.
 * O endereço 0x0 é tipicamente o reset vector em sistemas simples.
 * Usamos 16MB de tamanho como um exemplo razoável (0x1000000 bytes).
 * Se seu sistema Verilog/simulador tiver um endereço de memória diferente, ajuste aqui.
 */
MEMORY
{
  RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16M
}

/* ==========================================================
 * 2. SEÇÃO DE SAÍDA (OUTPUT SECTIONS)
 * ========================================================== */

SECTIONS
{
  /* Coloca todas as seções de saída dentro da região de memória RAM */
  . = 0x00000000;

  /*
   * A seção .text contém as instruções do seu código assembly.
   * O ponto de entrada (_start) deve ser a primeira instrução.
   */
  .text :
  {
    /* Garante que a primeira instrução a ser executada seja _start */
    KEEP (*(.text._start))
    /* Inclui todo o código restante (sua rotina 'loop', etc.) */
    *(.text)
    . = ALIGN(4);
  } > RAM

  /*
   * A seção .data contém variáveis inicializadas (se houver).
   * Note que seu código assembly não tem variáveis .data ou .bss.
   */
  .data :
  {
    *(.data)
    . = ALIGN(4);
  } > RAM

  /*
   * A seção .bss contém variáveis não inicializadas (zeradas pelo sistema).
   */
  .bss :
  {
    *(.bss)
    . = ALIGN(4);
  } > RAM
}

/* ==========================================================
 * 3. PONTO DE ENTRADA
 * ========================================================== */

/* Define o símbolo _start como o endereço onde a execução deve começar. */
ENTRY(_start)