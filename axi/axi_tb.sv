`timescale 1ns/1ps

module axi_tb;
    logic clk;
    logic rst_n;

    logic [31:0] axi_awaddr;
    logic [2:0] axi_awprot;
    logic axi_awvalid;
    logic axi_awready;

    logic [31:0] axi_wdata;
    logic [3:0] axi_wstrb;
    logic axi_wvalid;
    logic axi_wready;

    logic [1:0] axi_bresp;
    logic axi_bvalid;
    logic axi_bready;

    logic [31:0] axi_araddr;
    logic [2:0] axi_arprot;
    logic axi_arvalid;
    logic axi_arready;

    logic [31:0] axi_rdata;
    logic [1:0] axi_rresp;
    logic axi_rvalid;
    logic axi_rready;

    logic valid_in;
    logic [15:0] data_in;
    logic valid_out;
    logic [15:0] data_out;

    axi dut (
        .clk(clk),
        .rst_n(rst_n),
        .axi_awaddr(axi_awaddr),
        .axi_awprot(axi_awprot),
        .axi_awvalid(axi_awvalid),
        .axi_awready(axi_awready),
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb),
        .axi_wvalid(axi_wvalid),
        .axi_wready(axi_wready),
        .axi_bresp(axi_bresp),
        .axi_bvalid(axi_bvalid),
        .axi_bready(axi_bready),
        .axi_araddr(axi_araddr),
        .axi_arprot(axi_arprot),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),
        .axi_rdata(axi_rdata),
        .axi_rresp(axi_rresp),
        .axi_rvalid(axi_rvalid),
        .axi_rready(axi_rready),
        .valid_in(valid_in),
        .data_in(data_in),
        .valid_out(valid_out),
        .data_out(data_out)
    );

    integer sample_num = 0;
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    initial begin
        rst_n = 0;
        axi_awvalid = 0;
        axi_wvalid = 0;
        axi_bready = 1;
        axi_arvalid = 0;
        axi_arready = 1;
        valid_in = 0;
        data_in = 0;

        // reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        $display("Start");

        // read default coefficients
        $display("Reading default coefficients (0x2000)");
        axi_read(32'h0C);
        $display("COEFF0 = 0x%h\n", axi_rdata);

        // write a new coefficient to make it highpass
        $display("Writing for highpass");
        $display("Highpass: h = [0.25, -0.25, -0.25, 0.25]");
        axi_write(32'h0C, 32'h0000_2000);  // h[0] =  0.25
        axi_write(32'h10, 32'h0000_E000);  // h[1] = -0.25 (0xE000 in Q1.15)
        axi_write(32'h14, 32'h0000_E000);  // h[2] = -0.25
        axi_write(32'h18, 32'h0000_2000);  // h[3] =  0.25
        $display("  Coefficients done\n");

        // read them and verify
        $display("Reading back coefficients");
        axi_read(32'h0C);
        $display("  COEFF0 = 0x%h (0x2000)", axi_rdata);
        axi_read(32'h10);
        $display("  COEFF1 = 0x%h (0x2000)", axi_rdata);
        axi_read(32'h14);
        $display("  COEFF2 = 0x%h (0x2000)", axi_rdata);
        axi_read(32'h18);
        $display("  COEFF3 = 0x%h (0x2000)\n", axi_rdata);

        // send data through the filter
        $display("Sending data through filter");
        $display("Input: [1, 1, 1, 1, -1, -1, -1, -1, ...]");
        $display("Edges are suppoesd to be emphasized\n");

        // send a square wave
        repeat(4) send_sample(16'h7FFF); // +1.0
        repeat(4) send_sample(16'h8000); // -1.0
        repeat(4) send_sample(16'h8000);
        repeat(4) send_sample(16'h8000);

        // wait for the outputs
        repeat(20) @(posedge clk);

        // read the sample counter
        $display("Reading the sample counter");
        axi_read(32'h1C);
        $display("Samples processed: %0d\n", axi_rdata);

        $display("Done");
        $finish;
    end

        // task for axi writing
        task axi_write(input logic [31:0] addr, input logic [31:0] data);
            @(posedge clk);
            // send the address and data at the same time
            axi_awaddr = addr;
            axi_awvalid = 1;
            axi_wdata = data;
            axi_wstrb = 4'hF; // everything is valid
            axi_wvalid = 1;

            // wait for them to be accepted
            @(posedge clk);
            while (!(axi_awready && axi_wready)) @(posedge clk);
            axi_awvalid = 0;
            axi_wvalid = 0;

            // wait for the response
            while (!axi_bvalid) @(posedge clk);
            @(posedge clk);
        endtask

        // task for axi reading
        task axi_read(input logic [31:0] addr);
            @(posedge clk);
            axi_araddr = addr;
            axi_arvalid = 1;

            // wait for the address to be accepted
            @(posedge clk);
            while (!axi_arready) @(posedge clk);
            axi_arvalid = 0;

            // wait for the data
            while (!axi_rvalid) @(posedge clk);
            @(posedge clk);
        endtask

        // task to send the filter sample
        task send_sample(input logic [15:0] sample);
            @(posedge clk);
            valid_in = 1;
            data_in = sample;
            @(posedge clk);
            valid_in = 0;
        endtask

        always @(posedge clk) begin
            if (valid_out) begin
                real output_val;
                output_val = $itor(data_out) / 32768.0;
                $display("Sample %2d: Output = %7.4f (0x%h)", sample_num, output_val, data_out);
                sample_num = sample_num + 1;
            end
        end
endmodule
