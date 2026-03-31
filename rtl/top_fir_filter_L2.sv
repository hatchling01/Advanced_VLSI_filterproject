module top_fir_filter_L2 #(
    parameter integer NUM_TAPS    = 100,
    parameter integer DATA_WIDTH  = 16,
    parameter integer COEFF_WIDTH = 16,
    parameter integer ADDR_WIDTH  = $clog2(NUM_TAPS)
)(
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic signed [DATA_WIDTH-1:0]      data_in0,
    input  logic signed [DATA_WIDTH-1:0]      data_in1,
    input  logic                              data_valid,
    output logic                              ready,
    output logic signed [DATA_WIDTH-1:0]      data_out0,
    output logic signed [DATA_WIDTH-1:0]      data_out1,
    output logic                              data_out_valid
);

    fir_filter_L2 #(
        .NUM_TAPS    (NUM_TAPS),
        .DATA_WIDTH  (DATA_WIDTH),
        .COEFF_WIDTH (COEFF_WIDTH),
        .ADDR_WIDTH  (ADDR_WIDTH)
    ) u_fir_filter_L2 (
        .clk            (clk),
        .rst_n          (rst_n),
        .data_in0       (data_in0),
        .data_in1       (data_in1),
        .data_valid     (data_valid),
        .ready          (ready),
        .data_out0      (data_out0),
        .data_out1      (data_out1),
        .data_out_valid (data_out_valid)
    );

endmodule