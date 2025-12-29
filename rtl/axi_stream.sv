module axi_stream #(
    parameter data_width = 16,
    parameter axi_addr_width = 32,
    parameter axi_data_width = 32
)(
    input logic clk,
    input logic rst_n,

    // slave stuff
    input logic s_axis_tvalid,
    output logic s_axis_tready,
    input logic [data_width-1:0] s_axis_tdata,

    // master stuff
    output logic m_axis_tvalid,
    input logic m_axis_tready,
    output logic [data_width-1:0] m_axis_tdata,

    // lite stuff
    input  logic [axi_addr_width-1:0] s_axi_awaddr,
    input  logic [2:0] s_axi_awprot,
    input  logic s_axi_awvalid,
    output logic s_axi_awready,
    
    input  logic [axi_data_width-1:0] s_axi_wdata,
    input  logic [3:0] s_axi_wstrb,
    input  logic s_axi_wvalid,
    output logic s_axi_wready,
    
    output logic [1:0] s_axi_bresp,
    output logic s_axi_bvalid,
    input  logic s_axi_bready,
    
    input  logic [axi_addr_width-1:0] s_axi_araddr,
    input  logic [2:0] s_axi_arprot,
    input  logic s_axi_arvalid,
    output logic s_axi_arready,
    
    output logic [axi_data_width-1:0] s_axi_rdata,
    output logic [1:0] s_axi_rresp,
    output logic s_axi_rvalid,
    input  logic s_axi_rready
);

    // stuff between adapters and axi
    logic internal_valid;
    logic signed [data_width-1:0] internal_data;
    logic internal_valid_out;
    logic signed [data_width-1:0] internal_data_out;

    // input adapter
    // transfer only when both are valid and ready
    assign internal_valid = s_axis_tvalid && s_axis_tready;
    assign internal_data = s_axis_tdata;
    assign s_axis_tready = 1'b1; // always ready to accept the input

    // output adapter
    // hold output until it gets accepted
    logic output_pending;
    logic signed [data_width-1:0] output_buffer;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_tvalid <= 1'b0;
            m_axis_tdata <= '0;
            output_pending <= 1'b0;
            output_buffer <= '0;
        end else begin
            // if there's a pending output and ready to receive, transfer it
            if (output_pending && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                output_pending <= 1'b0;
            end
            
            // if the filter produces a new output, then store it until it's ready for transfer
            if (internal_valid_out) begin
                output_buffer <= internal_data_out;
                m_axis_tdata <= internal_data_out;
                m_axis_tvalid <= 1'b1;
                output_pending <= 1'b1;
            end
        end
    end

    // current axi (at the time of building this, I had axi4-lite, and I'm adding stream right now)
    axi #(
        .data_width(data_width),
        .axi_addr_width(axi_addr_width),
        .axi_data_width(axi_data_width)
    ) axi_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // valid/data
        .valid_in(internal_valid),
        .data_in(internal_data),
        .valid_out(internal_valid_out),
        .data_out(internal_data_out),
        
        // axi4-lite
        .axi_awaddr(s_axi_awaddr),
        .axi_awprot(s_axi_awprot),
        .axi_awvalid(s_axi_awvalid),
        .axi_awready(s_axi_awready),
        .axi_wdata(s_axi_wdata),
        .axi_wstrb(s_axi_wstrb),
        .axi_wvalid(s_axi_wvalid),
        .axi_wready(s_axi_wready),
        .axi_bresp(s_axi_bresp),
        .axi_bvalid(s_axi_bvalid),
        .axi_bready(s_axi_bready),
        .axi_araddr(s_axi_araddr),
        .axi_arprot(s_axi_arprot),
        .axi_arvalid(s_axi_arvalid),
        .axi_arready(s_axi_arready),
        .axi_rdata(s_axi_rdata),
        .axi_rresp(s_axi_rresp),
        .axi_rvalid(s_axi_rvalid),
        .axi_rready(s_axi_rready)
    );
endmodule