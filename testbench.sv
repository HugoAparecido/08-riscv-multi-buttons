module testbench();
  // Sinais de entrada para o módulo 'top'
  logic       CLOCK_50;
  logic [3:0] KEY;
  logic [9:0] SW;

  // Sinais de saída do módulo 'top'
  wire  [9:0] LEDR;
  wire  [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0;

  // Instanciar o "Device Under Test" (DUT) - o seu sistema completo
  top dut (
    .CLOCK_50(CLOCK_50),
    .KEY(KEY),
    .SW(SW),
    .LEDR(LEDR),
    .HEX5(HEX5),
    .HEX4(HEX4),
    .HEX3(HEX3),
    .HEX2(HEX2),
    .HEX1(HEX1),
    .HEX0(HEX0)
  );
    
  // Gerador de Clock (50 MHz simulado - 20ns de período)
  always begin
    CLOCK_50 = 1'b1; #10;
    CLOCK_50 = 1'b0; #10;
  end

  // Sequência de Teste
  initial begin
    $dumpfile("dump.vcd"); 
    $dumpvars(0, testbench);
    
    // 1. Iniciar em estado de Reset
    // (KEY[0] = 0 -> reset = 1, pois é ativo baixo)
    KEY = 4'b1110; // KEY[0] = 0
    SW  = 10'b0;
    #100; // Espera 100ns

    // 2. Liberar o Reset
    KEY = 4'b1111; // KEY[0] = 1
    $display("[%0t] Reset liberado. CPU iniciando...", $time);
    
    // Espera o CPU iniciar e escrever '1' nos LEDs
    wait (LEDR == 10'b1);
    $display("[%0t] CPU inicializou. LEDR = %b", $time, LEDR);
    #1000; // Espera um tempo

    // 3. Simular o primeiro pressionamento do SW[1]
    // A máscara no seu programa.asm é 0x2, que corresponde ao SW[1]
    $display("[%0t] Pressionando SW[1]...", $time);
    SW[1] <= 1'b1;
    
    // Espera o programa detectar a borda, rotacionar e escrever '2' nos LEDs
    wait (LEDR == 10'b10); 
    $display("[%0t] Rotação 1 detectada. LEDR = %b", $time, LEDR);
    
    // 4. Soltar o SW[1] (essencial para a detecção de borda)
    SW[1] <= 1'b0;
    $display("[%0t] Soltando SW[1].", $time);
    #1000; // Espera a liberação

    // 5. Simular o segundo pressionamento do SW[1]
    $display("[%0t] Pressionando SW[1] novamente...", $time);
    SW[1] <= 1'b1;
    
    // Espera o programa detectar a borda e escrever '4' nos LEDs
    wait (LEDR == 10'b100);
    $display("[%0t] Rotação 2 detectada. LEDR = %b", $time, LEDR);
    SW[1] <= 1'b0; // Solta o botão
    
    $display("\n[%0t] SIMULAÇÃO BEM-SUCEDIDA!", $time);
    $finish;
  end

endmodule
