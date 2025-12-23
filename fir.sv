module fir #(
    parameter data_width = 16 // Q1.15 fixed point
)(
    input logic clk,
    input logic rst_n,
    input logic valid_in, // input available
    input logic signed [data_width-1:0] data_in, // input
    output logic valid_out, // output valid
    output logic signed [data_width-1:0] data_out // the output
);
    // filter coefficients for a 4 tap moving average (0.25 each)
    // 0.25 in Q1.15: 0.25 * 2^15 = 8192 = 0x2000
    localparam signed [data_width-1:0] h0 = 16'h2000;
    localparam signed [data_width-1:0] h1 = 16'h2000;
    localparam signed [data_width-1:0] h2 = 16'h2000;
    localparam signed [data_width-1:0] h3 = 16'h2000;

    // shift register for the inputs
    logic signed [data_width-1:0] shift_reg [0:3];

    // products from doing the multiplication
    // 32 bits because 16 bits * 16 bits gives 32 bits
    logic signed [2*data_width-1:0] product [0:3];

    // total sum
    logic signed [2*data_width-1:0] total_sum;

    // valids
    logic valid1, valid2;

    // make teh shift register and moving stuff over when there's new inputs
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg[0] <= '0; // reset everything
            shift_reg[1] <= '0;
            shift_reg[2] <= '0;
            shift_reg[3] <= '0;
            valid1 <= 1'b0;
        end else begin
            if (valid_in) begin
                shift_reg[0] <= data_in;
                shift_reg[1] <= shift_reg[0];
                shift_reg[2] <= shift_reg[1];
                shift_reg[3] <= shift_reg[2];
            end
            valid1 <= valid_in;
        end
    end

    // do the multiplication
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product[0] <= '0;
            product[1] <= '0;
            product[2] <= '0;
            product[3] <= '0;
            valid2 <= 1'b0;
        end else begin
            product[0] <= shift_reg[0] * h0;
            product[1] <= shift_reg[1] * h1;
            product[2] <= shift_reg[2] * h2;
            product[3] <= shift_reg[3] * h3;
            valid2 <= valid1;
        end
    end

    // add up the results from the multiplication
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_sum <= '0;
            valid_out <= 1'b0;
        end else begin
            total_sum <= product[0] + product[1] + product[2] + product[3];
            valid_out <= valid2;
        end
    end

    // now, it is in Q2.30, but we need Q1.15
    // take [30:15] to convert it back
    assign data_out = total_sum[30:15];

endmodule