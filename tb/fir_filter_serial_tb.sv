`timescale 1ns / 1ps

module fir_filter_serial_tb;

    localparam integer NUM_TAPS    = 100;
    localparam integer DATA_WIDTH  = 16;
    localparam integer COEFF_WIDTH = 16;
    localparam integer ADDR_WIDTH  = $clog2(NUM_TAPS);

    reg clk;
    reg rst_n;
    reg signed [DATA_WIDTH-1:0] data_in;
    reg data_valid;
    wire ready;
    wire signed [DATA_WIDTH-1:0] data_out;
    wire data_out_valid;

    integer output_count;

    top_fir_filter_serial #(
        .NUM_TAPS(NUM_TAPS),
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_valid(data_valid),
        .ready(ready),
        .data_out(data_out),
        .data_out_valid(data_out_valid)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (data_out_valid) begin
            $display("[%0t] Output %0d: y = %6d (0x%04h)",
                     $time, output_count, data_out, data_out);
            output_count = output_count + 1;
        end
    end

    task send_sample;
        input signed [DATA_WIDTH-1:0] sample;
        begin
            while (!ready) @(posedge clk);
            @(posedge clk);
            data_in    <= sample;
            data_valid <= 1'b1;
            @(posedge clk);
            data_valid <= 1'b0;
            data_in    <= 0;
            while (!data_out_valid) @(posedge clk);
        end
    endtask

    integer i;

    initial begin
        clk          = 0;
        rst_n        = 0;
        data_in      = 0;
        data_valid   = 0;
        output_count = 0;

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        $display("\n=== Test 1: Impulse Response ===");
        send_sample(16'sd16384);
        for (i = 0; i < 4; i = i + 1)
            send_sample(16'sd0);

        $display("\n=== Test 2: Step Response ===");
        for (i = 0; i < 5; i = i + 1)
            send_sample(16'sd1000);

        $display("\n=== Test 3: Negative Impulse ===");
        send_sample(-16'sd16384);
        send_sample(16'sd0);

        repeat (10) @(posedge clk);
        $display("\n=== Simulation Complete ===");
        $display("Total outputs: %0d", output_count);
        $finish;
    end

    initial begin
        #500000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule