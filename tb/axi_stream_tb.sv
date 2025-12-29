`timescale 1ns/1ps

module axi_stream_tb;
    logic clk;
    logic rst_n;
    
    // AXI4-Stream input
    logic s_axis_tvalid;
    logic s_axis_tready;
    logic [15:0] s_axis_tdata;
    
    // AXI4-Stream output
    logic m_axis_tvalid;
    logic m_axis_tready;
    logic [15:0] m_axis_tdata;

    // AXI4-Lite
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

    axi_stream dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tdata(s_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .s_axi_awaddr(axi_awaddr),
        .s_axi_awprot(axi_awprot),
        .s_axi_awvalid(axi_awvalid),
        .s_axi_awready(axi_awready),
        .s_axi_wdata(axi_wdata),
        .s_axi_wstrb(axi_wstrb),
        .s_axi_wvalid(axi_wvalid),
        .s_axi_wready(axi_wready),
        .s_axi_bresp(axi_bresp),
        .s_axi_bvalid(axi_bvalid),
        .s_axi_bready(axi_bready),
        .s_axi_araddr(axi_araddr),
        .s_axi_arprot(axi_arprot),
        .s_axi_arvalid(axi_arvalid),
        .s_axi_arready(axi_arready),
        .s_axi_rdata(axi_rdata),
        .s_axi_rresp(axi_rresp),
        .s_axi_rvalid(axi_rvalid),
        .s_axi_rready(axi_rready)
    );

    integer sample_num = 0;
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    initial begin
        // reset
        rst_n = 0;
        // AXI4-Stream initialization
        s_axis_tvalid = 0;
        s_axis_tdata = 0;
        m_axis_tready = 1;  // always ready to receive output
        // AXI4-Lite initialization
        axi_awvalid = 0;
        axi_wvalid = 0;
        axi_bready = 1;
        axi_arvalid = 0;
        axi_rready = 1;

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
        $display("  COEFF1 = 0x%h (0xE000)", axi_rdata);
        axi_read(32'h14);
        $display("  COEFF2 = 0x%h (0xE000)", axi_rdata);
        axi_read(32'h18);
        $display("  COEFF3 = 0x%h (0x2000)\n", axi_rdata);

        // send data through the filter
        $display("Sending data through filter via AXI4-Stream");
        $display("Input: [1, 1, 1, 1, -1, -1, -1, -1, ...]");
        $display("Edges are supposed to be emphasized\n");

        // send a square wave
        repeat(4) send_sample(16'h7FFF); // +1.0
        repeat(4) send_sample(16'h8000); // -1.0
        repeat(4) send_sample(16'h7FFF);
        repeat(4) send_sample(16'h8000);

        // wait for the outputs
        repeat(10) @(posedge clk);

        // read the sample counter
        $display("\nReading the sample counter");
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
            while (!axi_arready) begin
                @(posedge clk);
            end
            axi_arvalid = 0;
            
            // wait for the data
            while (!axi_rvalid) begin
                @(posedge clk);
            end
            @(posedge clk);
        endtask 

        // task to send filter sample via AXI4-Stream
        task send_sample(input logic [15:0] sample);
            @(posedge clk);
            s_axis_tdata = sample;
            s_axis_tvalid = 1;
            
            // wait for ready (AXI4-Stream handshake)
            while (!s_axis_tready) @(posedge clk);
            @(posedge clk);
            
            s_axis_tvalid = 0;
        endtask

        // monitor outputs from AXI4-Stream
        always @(posedge clk) begin
            // transfer happens when both valid and ready
            if (m_axis_tvalid && m_axis_tready) begin
                real output_val;
                output_val = real'($signed(m_axis_tdata)) / 32768.0;
                $display("Sample %2d: Output = %7.4f (0x%h)", sample_num, output_val, m_axis_tdata);
                sample_num = sample_num + 1;
            end
        end
endmodule