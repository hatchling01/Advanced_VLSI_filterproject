`timescale 1ns / 1ps

module fir_filter_pipelined_L3_tb;

    localparam integer NUM_TAPS    = 100;
    localparam integer DATA_WIDTH  = 16;
    localparam integer COEFF_WIDTH = 16;
    localparam integer ADDR_WIDTH  = $clog2(NUM_TAPS);

    reg clk;
    reg rst_n;
    reg signed [DATA_WIDTH-1:0] data_in0, data_in1, data_in2;
    reg data_valid;
    wire ready;
    wire signed [DATA_WIDTH-1:0] data_out0, data_out1, data_out2;
    wire data_out_valid;

    integer out_cnt;
    integer i;

    top_fir_filter_pipelined_L3 #(
        .NUM_TAPS(NUM_TAPS),
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in0(data_in0),
        .data_in1(data_in1),
        .data_in2(data_in2),
        .data_valid(data_valid),
        .ready(ready),
        .data_out0(data_out0),
        .data_out1(data_out1),
        .data_out2(data_out2),
        .data_out_valid(data_out_valid)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (data_valid) begin
            $display("[%0t] SENT : x0=%6d (0x%04h)  x1=%6d (0x%04h)  x2=%6d (0x%04h)  ready=%0b",
                     $time,
                     data_in0, data_in0,
                     data_in1, data_in1,
                     data_in2, data_in2,
                     ready);
        end

        if (data_out_valid) begin
            $display("[%0t] OUT  : block %0d  y0=%6d (0x%04h)  y1=%6d (0x%04h)  y2=%6d (0x%04h)",
                     $time, out_cnt,
                     data_out0, data_out0,
                     data_out1, data_out1,
                     data_out2, data_out2);
            out_cnt = out_cnt + 1;
        end
    end

    task send_block;
        input signed [DATA_WIDTH-1:0] x0;
        input signed [DATA_WIDTH-1:0] x1;
        input signed [DATA_WIDTH-1:0] x2;
        integer wait_cycles;
        begin
            wait_cycles = 0;

            while (!ready) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
                if (wait_cycles > 500) begin
                    $display("[%0t] ERROR: wait for ready timed out", $time);
                    $finish;
                end
            end

            @(posedge clk);
            data_in0   <= x0;
            data_in1   <= x1;
            data_in2   <= x2;
            data_valid <= 1'b1;

            @(posedge clk);
            data_valid <= 1'b0;
            data_in0   <= 0;
            data_in1   <= 0;
            data_in2   <= 0;

            wait_cycles = 0;
            while (!data_out_valid) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
                if (wait_cycles > 1000) begin
                    $display("[%0t] ERROR: wait for data_out_valid timed out", $time);
                    $finish;
                end
            end

            @(posedge clk);
        end
    endtask

    initial begin
        clk        = 0;
        rst_n      = 0;
        data_in0   = 0;
        data_in1   = 0;
        data_in2   = 0;
        data_valid = 0;
        out_cnt    = 0;
        i          = 0;

        $display("=== Starting pipelined L3 FIR simulation ===");

        repeat (5) @(posedge clk);
        rst_n = 1;
        $display("[%0t] Reset released", $time);

        repeat (3) @(posedge clk);

        $display("\n=== Test 1: Impulse at x[0] = 16384 ===");
        send_block(16'sd16384, 16'sd0, 16'sd0);
        for (i = 0; i < 4; i = i + 1)
            send_block(16'sd0, 16'sd0, 16'sd0);

        $display("\n=== Test 2: Step (all = 1000) for 5 blocks ===");
        for (i = 0; i < 5; i = i + 1)
            send_block(16'sd1000, 16'sd1000, 16'sd1000);

        $display("\n=== Test 3: Impulse at x[1] = 16384 ===");
        send_block(16'sd0, 16'sd16384, 16'sd0);
        for (i = 0; i < 4; i = i + 1)
            send_block(16'sd0, 16'sd0, 16'sd0);

        $display("\n=== Test 4: Negative impulse at x[2] = -16384 ===");
        send_block(16'sd0, 16'sd0, -16'sd16384);
        for (i = 0; i < 4; i = i + 1)
            send_block(16'sd0, 16'sd0, 16'sd0);

        repeat (20) @(posedge clk);
        $display("\n=== Simulation Complete (%0d output blocks) ===", out_cnt);
        $finish;
    end

    initial begin
        #1000000;
        $display("[%0t] TIMEOUT", $time);
        $finish;
    end

endmodule