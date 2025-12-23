`timescale 1ns/1ps

module fir_tb;
    logic clk;
    logic rst_n;
    logic valid_in;
    logic signed [15:0] data_in;
    logic valid_out;
    logic signed [15:0] data_out;

    fir dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .data_in(data_in),
        .valid_out(valid_out),
        .data_out(data_out)
    );

    // 10 ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        valid_in = 0;
        data_in = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        $display("Starting");
        $display("Sending square wave pattern: [1,1,1,1,-1,-1,-1,-1]");

        // send test pattern (same as the one in the golden model)
        // in Q1.15: 1.0 ≈ 0x7FFF, -1.0 = 0x8000
        send_sample(16'h7FFF);  // 1.0
        send_sample(16'h7FFF);  // 1.0
        send_sample(16'h7FFF);  // 1.0
        send_sample(16'h7FFF);  // 1.0
        send_sample(16'h8000);  // -1.0
        send_sample(16'h8000);  // -1.0
        send_sample(16'h8000);  // -1.0
        send_sample(16'h8000);  // -1.0

        // repeat it a couple times
        repeat(3) begin
            repeat(4) send_sample(16'h7FFF);
            repeat(4) send_sample(16'h8000);
        end

        repeat(10) @(posedge clk);

        $display("Done");
        $finish;
    end

    // task to send the sample
    task send_sample(input logic signed [15:0] sample);
        @(posedge clk);
        valid_in = 1;
        data_in = sample;
        @(posedge clk);
        valid_in = 0;
    endtask

    // seeing the outputs
    integer sample_count = 0;
    always @(posedge clk) begin
        if (valid_out) begin
            real output_real;
            output_real = $itor(data_out) / 32768.0;
            $display("Sample %2d: Output = %7.4f (hex: 0x%h)", sample_count, output_real, data_out);
            sample_count = sample_count + 1;
        end
    end
endmodule