module top_fir_filter_serial #(
    parameter integer NUM_TAPS    = 100,
    parameter integer DATA_WIDTH  = 16,
    parameter integer COEFF_WIDTH = 16,
    parameter integer ADDR_WIDTH  = $clog2(NUM_TAPS)
)(
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic signed [DATA_WIDTH-1:0]      data_in,
    input  logic                              data_valid,
    output logic                              ready,
    output logic signed [DATA_WIDTH-1:0]      data_out,
    output logic                              data_out_valid
);

    logic [ADDR_WIDTH-1:0]             coeff_addr;
    logic signed [COEFF_WIDTH-1:0]     coeff_data;

    coeff_rom #(
        .NUM_TAPS    (NUM_TAPS),
        .COEFF_WIDTH (COEFF_WIDTH),
        .ADDR_WIDTH  (ADDR_WIDTH)
    ) u_coeff_rom (
        .clk       (clk),
        .addr      (coeff_addr),
        .coeff_out (coeff_data)
    );

    fir_filter_serial #(
        .NUM_TAPS    (NUM_TAPS),
        .DATA_WIDTH  (DATA_WIDTH),
        .COEFF_WIDTH (COEFF_WIDTH),
        .ADDR_WIDTH  (ADDR_WIDTH)
    ) u_fir_filter_serial (
        .clk            (clk),
        .rst_n          (rst_n),
        .data_in        (data_in),
        .data_valid     (data_valid),
        .ready          (ready),
        .data_out       (data_out),
        .data_out_valid (data_out_valid),
        .coeff_addr     (coeff_addr),
        .coeff_data     (coeff_data)
    );

endmodule
