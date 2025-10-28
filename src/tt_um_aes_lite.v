/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`timescale 1ns / 1ps

module tt_um_aes_lite (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire start;
  wire [7:0] data_in;
  wire [7:0] key_in;
  wire [7:0] data_out;
  wire ready;
  
  reg start_reg;
  reg prev_rst_n;
  
  // Input assignments
  assign data_in = ui_in; // ui_in[7:0] - data_in (8-bit data input)
  assign key_in = uio_in; // uio_in[7:0] - key_in (8-bit key input)
  
  // Generate start pulse on rising edge of reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prev_rst_n <= 1'b0;
      start_reg <= 1'b0;
    end else begin
      prev_rst_n <= rst_n;
      // Generate start pulse when coming out of reset
      start_reg <= (!prev_rst_n && rst_n);
    end
  end
  
  assign start = start_reg;
  
  // Output assignments
  assign uo_out = data_out;   // uo_out[7:0] - data_out (8-bit encrypted output)
  assign uio_out = {7'b0, ready}; // uio_out[0] - ready signal
  assign uio_oe = 8'b00000001;  // Only bit 0 is output (ready), rest are inputs
  
  // Internal registers
  reg [3:0] state, next_state;
  reg [3:0] round_count;
  reg [7:0] state_reg, key_reg;
  
  localparam IDLE   = 3'd0,
             LOAD   = 3'd1,
             ROUND  = 3'd2,
             DONE   = 3'd3;
             
  // Combinational logic for state transitions
  always @(*) begin
    next_state = state;
    case (state)
      IDLE:   if (start) next_state = LOAD;
      LOAD:   next_state = ROUND;
      ROUND:  if (round_count == 4'd9) next_state = DONE;
      DONE:   next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
  
  // Sequential state transition and round counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      round_count <= 0;
    end else begin
      state <= next_state;
      
      // Round counter control based on state transitions
      case (next_state)
        LOAD: begin
          round_count <= 0;  // Reset counter when entering LOAD
        end
        ROUND: begin
          if (state == ROUND)
            round_count <= round_count + 1;  // Increment in ROUND
          else
            round_count <= 0;  // First cycle in ROUND, start at 0
        end
        default: begin
          round_count <= 0;  // Reset in all other states
        end
      endcase
    end
  end
  
  // AES-lite byte operation
  reg [7:0] data_out_reg;
  reg ready_reg;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_out_reg <= 8'b0;
      ready_reg <= 1'b0;
      state_reg <= 8'b0;
      key_reg <= 8'b0;
    end else begin
      case (state)
        IDLE: begin
          ready_reg <= 1'b0;
        end
        LOAD: begin
          state_reg <= data_in;
          key_reg   <= key_in;
          ready_reg <= 1'b0;
        end
        ROUND: begin
          state_reg <= state_reg ^ key_reg ^ round_count;
        end
        DONE: begin
          data_out_reg <= state_reg;
          ready_reg <= 1'b1;
        end
        default: begin
          ready_reg <= 1'b0;
        end
      endcase
    end
  end
  
  assign data_out = data_out_reg;
  assign ready = ready_reg;

  // List all unused inputs to prevent warnings
wire _unused = &{ena,uio_out[7:1], 1'b0};

endmodule
