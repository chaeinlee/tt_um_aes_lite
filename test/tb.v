`default_nettype none
`timescale 1ns / 1ps
module tb ();
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end
  
  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif
  
 tt_um_aes_lite user_project (
      
     `ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );
  
  // Clock generation (100MHz)
  always #5 clk = ~clk;
  
  // FSM State monitor for Test 1 only - ONLY for RTL simulation
`ifndef GL_TEST
  always @(posedge clk) begin
    if (rst_n && $time > 20 && $time < 500)  // Only during Test 1
      $display("[%0t ns] State=%0d, Round=%0d, Ready=%b", 
               $time, user_project.state, user_project.round_count, uio_out[0]);
  end
`endif
  
  // Test procedure
  initial begin
    // Initialize
    clk = 0;
    rst_n = 0;
    ena = 1;
    ui_in = 8'h00;
    uio_in = 8'h00;
    
    $display("Starting AES Test...\n");
    
    // Test 1: Data=0xAA, Key=0x55 (with FSM monitoring)
    $display("=== Test 1: Data=0xAA, Key=0x55 (FSM States Shown) ===");
    #20 rst_n = 1;
    ui_in = 8'hAA;
    uio_in = 8'h55;
    wait(uio_out[0] == 1);
    $display("Result: 0x%h\n", uo_out);
    
    // Test 2: Data=0x12, Key=0x34
    #20 rst_n = 0;
    #20 rst_n = 1;
    ui_in = 8'h12;
    uio_in = 8'h34;
    $display("Test 2: Data=0x%h, Key=0x%h", ui_in, uio_in);
    wait(uio_out[0] == 1);
    $display("Result: 0x%h\n", uo_out);
    
    // Test 3: Data=0xFF, Key=0xFF
    #20 rst_n = 0;
    #20 rst_n = 1;
    ui_in = 8'hFF;
    uio_in = 8'hFF;
    $display("Test 3: Data=0x%h, Key=0x%h", ui_in, uio_in);
    wait(uio_out[0] == 1);
    $display("Result: 0x%h\n", uo_out);
    
    // Test 4: Data=0x00, Key=0x00
    #20 rst_n = 0;
    #20 rst_n = 1;
    ui_in = 8'h00;
    uio_in = 8'h00;
    $display("Test 4: Data=0x%h, Key=0x%h", ui_in, uio_in);
    wait(uio_out[0] == 1);
    $display("Result: 0x%h\n", uo_out);
    
    //Test Case 5: Pattern Test Data=0x5A, Key=0xA5
    #20 rst_n = 0;
    #20 rst_n = 1;
    ui_in = 8'h5A;
    uio_in = 8'hA5;
    $display("Test 5: Data=0x%h, Key=0x%h", ui_in, uio_in);
    wait(uio_out[0] == 1);
    $display("Result: 0x%h\n", uo_out);
         
    $display("All tests complete!");
    #200 $finish;
  end
  
  // Timeout protection
  initial begin
    #50000;
    $display("ERROR: Timeout!");
    $finish;
  end
endmodule
