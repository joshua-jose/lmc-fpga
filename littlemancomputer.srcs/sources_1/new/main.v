`timescale 1ns / 1ps

// Contains the core logic for the CPU (Control Unit)
module main(
    input clk, en,
    output a,b,c,d,e,f,g,
    output [7:0] an,
    output [15:0] led
    );

   reg [7:0] pc; // program counter
   reg [3:0] ir; // instruction register
   reg [7:0] ar; // address register
   reg [11:0] ac; // accumulator

   reg  [7:0] addr_bus; // address buss
   reg [11:0] data_write_bus; // write to memory
   wire [11:0] data_read_bus; // read from memory

   reg we; // ram write enable
   reg re; // ram read enable

   reg [11:0] io_buf; // io buffer for INP/OUT/OTC

   ram ram1(clk, addr_bus, data_read_bus, data_write_bus, we, re);
    
   wire en_edge;

   reg [11:0] alu_operand_1;
   reg [11:0] alu_operand_2;
   reg alu_op;
   wire [11:0] alu_result;

   reg [3:0] dig7, dig6, dig5, dig4, dig3, dig2, dig1, dig0;
   wire led_clk;
   wire rst = 0;

   seginterface U1(clk, rst, 
    dig7, dig6, dig5, dig4, dig3, dig2, dig1, dig0,
    
    led_clk,
    a,b,c,d,e,f,g,
    an
   );
   debounce U2(clk, en, en_edge);
   alu U3(clk, alu_operand_1, alu_operand_2, alu_op, alu_result);

   initial begin
       pc <= 0;
       ir <= 0;
       ar <= 0;
       ac <= 0;
       re <= 0;
       we <= 0;
   end

    reg [3:0] state; // Control Unit state (to progress through fetch-decode-execute cycle)
    initial state <= 0;

    reg running;
    initial running <= 1;
    
    always @(posedge led_clk) begin
    //   if (en_edge & running) begin
        if (running) begin
            // fetch
           if (state == 0) begin
               
               addr_bus <= pc; // put the PC onto addr bus
                
               we <= 0;
               re <= 1; // ram read enable
           end

           if (state == 1) begin

               ir <= data_read_bus[11:8]; // load IR
               ar <= data_read_bus[7:0]; // load AR
                
               re <= 0;

                
               // TODO: use ALU
               // increment PC using BCD counting
               pc[3:0] <= pc[3:0] + 4'd1;
               if (pc[3:0] >= 4'd9) begin
                    pc[7:4] <= pc[7:4] + 4'd1;
                    pc[3:0] <= 4'd0;
               end  
           end


           // decode
           // execute

           if (state == 2) begin
                case (ir)
                    4'd0: running <= 0; // HLT
                    4'd1: begin // ADD
                        // read in operand 2
                       addr_bus <= ar; 
                       
                       we <= 0;
                       re <= 1; 
                    end
                    4'd2: begin // SUB
                        // read in operand 2
                       addr_bus <= ar; 
                       
                       we <= 0;
                       re <= 1; 
                    end
                    4'd3: begin // STA
                       addr_bus <= ar; // Write to address in address register
                       data_write_bus <= ac; // Put accumulator on data bus
                       
                       we <= 1;
                       re <= 0; 
                    end
                    4'd5: begin // LDA
                       addr_bus <= ar; // Read from address in address register
                       we <= 0;
                       re <= 1; 
                    end
                    4'd6: begin // BRA
                       pc <= ar; // Load the PC with the address to jump to
                    end
                    4'd7: begin // BRZ
                       if (ac == 0)
                        pc <= ar; // Load the PC with the address to jump to
                    end

                    4'd9: begin // INP/OUT/OTC
                    //    if (ar == 1) // INP
                    //    ;
                       if (ar == 2) begin // OUT
                        dig0 <= ac[3:0];
                        dig1 <= ac[7:4];
                        dig2 <= ac[11:8];
                       end
                       if (ar == 22) // OTC
                        io_buf <= ac;
                    end
                endcase
           end

           if (state == 3) begin
                case (ir)
                    4'd1: begin // ADD
                       alu_operand_1 <= ac; 
                       alu_operand_2 <= data_read_bus;
                       alu_op <= 0;
                       re <= 0; 
                    end
                    4'd2: begin // SUB
                       alu_operand_1 <= ac; 
                       alu_operand_2 <= data_read_bus;
                       alu_op <= 1;
                       re <= 0; 
                    end
                    4'd3: begin // STA
                        we <= 0; // disable writes
                    end
                    4'd5: begin // LDA
                       ac <= data_read_bus; // Store read address into accumulator
                       re <= 0; 
                    end
                endcase
           end
           if (state == 4) begin
                case (ir)
                    4'd1: begin // ADD
                       ac <= alu_result; // store result of addition
                    end
                    4'd2: begin // SUB
                       ac <= alu_result; // store result of subtraction
                    end
                endcase
           end

            state <= (state >= 4) ? 0 : state + 1;

            // dig0 <= ac[3:0];
            // dig1 <= ac[7:4];
            // dig2 <= ac[11:8];

            // dig4 <= state[3:0];

            dig6 <= pc[3:0];
            dig7 <= pc[7:4];
      end 
    end

    assign led[15] = (state == 0);
    assign led[14] = (state == 1);
    assign led[13] = (state == 2);
    assign led[12] = (state == 3);
    assign led[11] = (state == 4);
    
endmodule
