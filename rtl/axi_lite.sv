module axi #(
    parameter data_width = 16, // filter data width
    parameter axi_addr_width = 32, // axi address width
    parameter axi_data_width = 32 // axi data width
)(
    input logic clk,
    input logic rst_n,

    // write address channel
    // NOTE: IF YOU TEST THIS, THE PROT'S WILL SHOW UP AS X ON THE WAVEFORM THAT'S NORMAL
    input logic [axi_addr_width-1:0] axi_awaddr,
    input logic [2:0] axi_awprot, // protection but usually it gets ignored
    input logic axi_awvalid,
    output logic axi_awready,

    // write data channel
    input logic [axi_data_width-1:0] axi_wdata,
    input logic [3:0] axi_wstrb, // byte enables
    input logic axi_wvalid,
    output logic axi_wready,

    // write response channel
    output logic [1:0] axi_bresp,
    output logic axi_bvalid,
    input logic axi_bready,

    // read address channel
    input logic [axi_addr_width-1:0] axi_araddr,
    input logic [2:0] axi_arprot,
    input logic axi_arvalid,
    output logic axi_arready,

    // read data channel
    output logic [axi_data_width-1:0] axi_rdata,
    output logic [1:0] axi_rresp,
    output logic axi_rvalid,
    input logic axi_rready,

    // fir stuff
    input logic valid_in,
    input logic signed [data_width-1:0] data_in,
    output logic valid_out,
    output logic signed [data_width-1:0] data_out
);

    // register map
    logic [31:0] ctrl_reg; // 0x00
    logic [31:0] status_reg; // 0x04
    logic [31:0] num_taps_reg; // 0x08 and so on
    logic signed [15:0] coeff0;
    logic signed [15:0] coeff1;
    logic signed [15:0] coeff2;
    logic signed [15:0] coeff3;
    logic [31:0] sample_count; // last address at 0x1C

    // axi writing state machine
    typedef enum logic [1:0] {
        write_idle,
        write_data,
        write_resp
    } write_state_t;

    write_state_t write_state;
    logic [axi_addr_width-1:0] write_addr;

    // axi reading state machine
    typedef enum logic [1:0] {
        read_idle,
        read_setup,
        read_data
    } read_state_t;

    read_state_t read_state;
    logic [axi_addr_width-1:0] read_addr;

    // axi writing
    logic write_addr_accepted;
    logic write_data_accepted;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_addr_accepted <= 1'b0;
            write_data_accepted <= 1'b0;
            axi_awready <= 1'b1;
            axi_wready <= 1'b1;
            axi_bvalid <= 1'b0;
            axi_bresp <= 2'b00;
            
            coeff0 <= 16'h2000; // 0.25 decimal
            coeff1 <= 16'h2000;
            coeff2 <= 16'h2000;
            coeff3 <= 16'h2000;
            ctrl_reg <= 32'h0000_0001; // enabled by default
            sample_count <= 0;

        end else begin
            // not sending a response by default
            axi_bvalid <= 1'b0;
            
            if (write_addr_accepted && write_data_accepted) begin
                // address and data were accepted, so a response can be sent now
                axi_bvalid <= 1'b1;
                axi_bresp <= 2'b00;
                
                if (axi_bready) begin
                    // the response was accepted, so now get ready for the next write
                    write_addr_accepted <= 1'b0;
                    write_data_accepted <= 1'b0;
                    axi_awready <= 1'b1;
                    axi_wready <= 1'b1;
                end
            end 
            // write address
            else if (!write_addr_accepted && axi_awvalid && axi_awready) begin
                // accept address
                write_addr <= axi_awaddr;
                write_addr_accepted <= 1'b1;
                axi_awready <= 1'b0;
            end
            // write data  
            else if (!write_data_accepted && axi_wvalid && axi_wready) begin
                // accept data
                // figure out the address and send it to the register
                case(write_addr[7:0]) // gonna use the lower 8 bits
                    8'h00: ctrl_reg <= axi_wdata;
                    8'h0C: coeff0 <= axi_wdata[15:0]; // here lower 16 bits
                    8'h10: coeff1 <= axi_wdata[15:0];
                    8'h14: coeff2 <= axi_wdata[15:0];
                    8'h18: coeff3 <= axi_wdata[15:0];
                    default: ; // if it's invalid, just ignore it
                endcase
                write_data_accepted <= 1'b1;
                axi_wready <= 1'b0;
            end
        end
    end

    // axi reading
    logic read_in_progress;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_in_progress <= 1'b0;
            axi_arready <= 1'b1;
            axi_rvalid <= 1'b0;
            axi_rdata <= '0;
            axi_rresp <= 2'b00;
        end else begin
            axi_rvalid <= 1'b0;
            
            if (read_in_progress) begin
                // processing a read
                axi_rvalid <= 1'b1;
                axi_rresp <= 2'b00;
                
                if (axi_rready) begin
                    // data was accepted by the master
                    read_in_progress <= 1'b0;
                    axi_arready <= 1'b1;
                end
            end else begin
                // ready for a read
                axi_arready <= 1'b1;
                
                if (axi_arvalid) begin
                    // accept the read
                    read_addr <= axi_araddr;
                    read_in_progress <= 1'b1;
                    axi_arready <= 1'b0;
                    
                    // figure out the address and read from that register
                    case(axi_araddr[7:0])
                        8'h00: axi_rdata <= ctrl_reg;
                        8'h04: axi_rdata <= status_reg;
                        8'h08: axi_rdata <= num_taps_reg;
                        8'h0C: axi_rdata <= {16'h0000, coeff0}; // pad it to 32 bits
                        8'h10: axi_rdata <= {16'h0000, coeff1};
                        8'h14: axi_rdata <= {16'h0000, coeff2};
                        8'h18: axi_rdata <= {16'h0000, coeff3};
                        8'h1C: axi_rdata <= sample_count;
                        default: axi_rdata <= 32'hDEADBEEF; // there was an error
                    endcase
                end
            end
        end
    end
    
    // status register
    assign num_taps_reg = 32'd4; // constantly 4
    assign status_reg = {31'h0, ~valid_out}; // bit 0 = idle which is the inverse of valid_out

    // count how many samples were processed
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_count <= '0;
        end else if (valid_out) begin
            sample_count <= sample_count + 1;
        end
    end

   fir_config #(
    .data_width(data_width)
) fir_inst(
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(valid_in),
    .data_in(data_in),
    .valid_out(valid_out),
    .data_out(data_out),
    .h0(coeff0),
    .h1(coeff1),
    .h2(coeff2),
    .h3(coeff3)
);
endmodule