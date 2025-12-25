module axi #(
    parameter data_width = 16, // filter data width
    parameter axi_addr_width = 32, // axi address width
    parameter axi_data_width = 32 // axi data width
)(
    input logic clk,
    input logic rst_n,

    // write address channel
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
        read_data
    } read_state_t;

    read_state_t read_state;
    logic [axi_addr_width-1:0] read_addr;

    // axi writing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_state <= write_idle;
            write_addr <= '0;
            axi_awready <= 1'b0;
            axi_wready <=1'b0;
            axi_bvalid <= 1'b0;
            axi_bresp <= 2'b00;

            coeff0 <= 16'h2000; // 0.25 decimal
            coeff1 <= 16'h2000;
            coeff2 <= 16'h2000;
            coeff3 <= 16'h2000;

            ctrl_reg <= 32'h0000_0001; // enabled by default
            sample_count <= 0;

        end else begin
            case (write_state)
                write_idle: begin
                    axi_awready <= 1'b1; // ready for an address
                    axi_wready <= 1'b0;
                    axi_bvalid <= 1'b0;

                    // wait for address valid
                    if (axi_awvalid && axi_awready) begin
                        write_addr <= axi_awaddr; // get the address
                        axi_awready <= 1'b0;
                        write_state <= write_data;
                    end
                end

                write_data: begin
                    axi_wready <= 1'b1; // ready for a data

                    // wait for data valid
                    if (axi_wvalid && axi_wready) begin
                        // figure out the address and send it to the register
                        case(write_addr[7:0]) // gonna use the lower 8 bits
                            8'h00: ctrl_reg <= axi_wdata;
                            8'h0C: coeff0 <= axi_wdata[15:0]; // here lower 16 bits
                            8'h10: coeff1 <= axi_wdata[15:0];
                            8'h14: coeff2 <= axi_wdata[15:0];
                            8'h18: coeff3 <= axi_wdata[15:0];
                            default: ; // if it's invalid, just ignore it
                        endcase

                        axi_wready <= 1'b0;
                        write_state <= write_resp;
                    end
                end

                write_resp: begin
                    axi_bvalid <= 1'b1; // valid response
                    axi_bresp <= 2'b00; // response is ok

                    // wait for the master to accept the response
                    if (axi_bvalid && axi_bready) begin
                        axi_bvalid <= 1'b0;
                        write_state <= write_idle;
                    end
                end
                default: write_state <= write_idle; // set the default to idle
            endcase
        end
    end

    // axi reading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_state <= read_idle;
            read_addr <= '0;
            axi_arready <= 1'b0;
            axi_rvalid <= 1'b0;
            axi_rdata <= '0;
            axi_rresp <= 2'b00;
        end else begin
            case (read_state)
                read_idle: begin
                    axi_arready <= 1'b1; // ready to accept an address
                    axi_rvalid <= 1'b0;

                    // wait for address valid
                    if (axi_arvalid && axi_arready) begin
                        read_addr <= axi_araddr; // get the address
                        axi_arready <= 1'b0;
                        read_state <= read_data;
                    end
                end

                read_data: begin
                    // figure out the address and read from that register
                    case(read_addr[7:0])
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

                    axi_rvalid <= 1'b1; // data was valid
                    axi_rresp <= 2'b00; // ok

                    // wait for the master to accept the data
                    if (axi_rvalid && axi_rready) begin
                        axi_rvalid <= 1'b0;
                        read_state <= read_idle;
                    end
                end
                default: read_state <= read_idle; // default to idle
            endcase
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