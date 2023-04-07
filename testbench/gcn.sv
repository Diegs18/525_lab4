`include "params.vh"

module gcn (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic [num_of_cols_fm-1:0] [num_of_elements_in_col*BW-1:0] col_features,
    input  logic [num_of_rows_wm-1:0] [num_of_elements_in_row*BW-1:0] row_weights,
    input  logic [1:0] [17:0] coo_mat,
    output logic [num_of_outs-1:0] [2:0] y,
    output logic input_re,
    output logic [num_of_rows_wm-1:0] [1:0] input_addr_wm,
    output logic [num_of_cols_fm-1:0] [6:0] input_addr_fm,
    output logic output_we,
    output logic [num_of_outs-1:0] [2:0] output_addr,
    output logic [num_of_outs-1:0] [9:0] aggregated_out,
    output logic [num_of_outs-1:0] [6:0] aggregated_address,
    output logic done
);

    logic [7:0] i, j;
    logic start_r; 
    logic [num_of_cols_fm-1:0] [num_of_elements_in_col-1:0] [BW-1:0]  col_features_r;
    logic [num_of_rows_wm-1:0] [num_of_elements_in_row-1:0] [BW-1:0]  row_weights_r;
    logic [1:0] [5:0] [2:0]  coo_mat_r; 


    //////////////////////////////////////////////////////////////////////////////////////////////
    //                        Input and output registers
    //////////////////////////////////////////////////////////////////////////////////////////////
    always_ff @( posedge clk or negedge rst_n) begin : in_out_regs
        if(~rst_n) begin
            start_r <= 1'b0;
            for (i=8'b0; i<num_of_cols_fm; i++) begin
                for (j=8'b0; j<num_of_elements_in_col; j++) begin
                    col_features_r[i][j]<=5'b0; //i is the column, j is the element in the column
                end
            end 
            for (i=8'b0; i<num_of_rows_wm; i++) begin
                for (j=8'b0; j<num_of_elements_in_row; j++) begin
                    row_weights_r[i][j]<=5'b0; //i is the column, j is the element in the column
                end
            end 
            for (i=8'b0; i<2; i++) begin
                for (j=8'b0; j<6; j++) begin
                    coo_mat_r[i][j]<=18'b0; //i is the column, j is the element in the column
                end
            end
            for (i=8'b0; i<num_of_outs; i++) begin
                    y[i]<=3'b0; //i is the column, j is the element in the column
            end
            for (i=2'b0; i<num_of_rows_wm; i++) begin
                input_addr_wm[i] <= i;
            end
            for (i=7'b0; i<num_of_cols_fm; i++) begin
                input_addr_fm[i] <= i;
            end
            for (i=7'b0; i<num_of_outs; i++) begin
                aggregated_out[i] <= 10'b0;
            end
            done <= 1'b0; 
        end
        else begin
            if(input_re == 1'b1) begin
                col_features_r <= col_features;
                row_weights_r  <= row_weights;
                coo_mat_r   <= coo_mat;
            end
        end
    end

    //////////////////////////////////////////////////////////////////////////////////////////////
    //                        Finite State Machine
    //////////////////////////////////////////////////////////////////////////////////////////////
    typedef enum {init, fetch, adj, feat_ag, hold} state_t;
    state_t state, next_state;
    logic adj_en; 
    logic adj_done, adj_done_b;
    logic feat_ag_en, feat_ag_done;
    always_ff @( posedge clk or negedge rst_n ) begin : FSM
        if(~rst_n)
            state <= init;
        else
            state <= next_state; 
    end

    always_comb begin : state_logic
        input_re  = 1'b0; 
        next_state = init;
        adj_en = 0; 
        feat_ag_en = 0; 
        case (state)
            init : begin //reset state
                if(start==1'b1) 
                    next_state = fetch; 
            end
            fetch : begin //gather the data for use
                input_re = 1'b1; 
                next_state = adj; 
            end
            adj : begin //create the adjaceny matrix
                adj_en = 1'b1; 
                next_state = feat_ag;

            end
            feat_ag : begin
                adj_en = 1'b1; 
                feat_ag_en = 1; 
                if(feat_ag_done == 1'b1)
                    next_state = hold; 
                else
                    next_state <= feat_ag; 
            end
            hold : begin
                next_state = hold; 
            end
            default : begin 
                next_state = init; 
            end
        endcase
    end


    //////////////////////////////////////////////////////////////////////////////////////////////
    //                        Adjaceny Matrix creation
    //////////////////////////////////////////////////////////////////////////////////////////////
    logic [5:0] adj_mat [5:0];
    logic [2:0] top;
    logic [2:0] bot;
    
    logic [3:0] col, next_col; 
    logic [5:0] bit_set1, bit_set2; 
    const bit [5:0] bit1 = 6'b000001;
    const bit [5:0] bit2 = 6'b000010;
    const bit [5:0] bit3 = 6'b000100;
    const bit [5:0] bit4 = 6'b001000;
    const bit [5:0] bit5 = 6'b010000;
    const bit [5:0] bit6 = 6'b100000;
    

    always_ff @(posedge clk or negedge rst_n) begin : ajd_create
        if(~rst_n) begin
                for(i=3'b0; i<3'd6; i++) begin
                    adj_mat[i]<= 6'b0; 
                end
                //top <= 3'b0; 
                //bot <= 3'b0;
                adj_done <= 1'b0; 
                col <= 4'b0;
        end
        else begin
            if(adj_en) begin
                adj_mat[top-1] <= adj_mat[top-1] | bit_set2;
                adj_mat[bot-1] <= adj_mat[bot-1] | bit_set1;
                col <= next_col; 
                adj_done <= adj_done_b;
            end
        end
    end

    assign top = coo_mat_r[0][col-1];
    assign bot = coo_mat_r[1][col-1];
    assign next_col = col + 4'b1;
    assign adj_done_b = (col>4'd5)? 1'b1 : 1'b0;

    always_comb begin
        bit_set1 = 6'b0;  
        case (top)
            3'd0 : begin
                bit_set1 = 6'd0;
            end
            3'd1 : bit_set1 = bit1;
            3'd2 : bit_set1 = bit2;
            3'd3 : bit_set1 = bit3;
            3'd4 : bit_set1 = bit4;
            3'd5 : bit_set1 = bit5;
            3'd6 : bit_set1 = bit6;
            default: begin
                bit_set1 = 6'hFF;  
            end
        endcase
    end

    always_comb begin
        bit_set2 = 6'b0;
        case (bot)
            3'd0 : bit_set2 = 6'd0;
            3'd1 : bit_set2 = bit1;
            3'd2 : bit_set2 = bit2;
            3'd3 : bit_set2 = bit3;
            3'd4 : bit_set2 = bit4;
            3'd5 : bit_set2 = bit5;
            3'd6 : bit_set2 = bit6;
            default: bit_set2 = 6'hFF;
        endcase
    end

//////////////////////////////////////////////////////////////////////////////////////////////
//                        Feature aggregation
//////////////////////////////////////////////////////////////////////////////////////////////
logic [5:0] feat_sel;
logic [2:0] mat_cnt ;
logic [2:0] next_mat_cnt ;
logic [5:0][BW-1:0] element1, element2, element13, element14, element15, element16; 
logic en1, en2, en3, en4, en5, en6; 
logic [BW-1:0] element21, element22, element23, element24, element25, element26;
logic [7:0] ag_cnt, next_ag_cnt; 

always_ff @( posedge clk or negedge rst_n ) begin : feat_ag_reg
    if(~rst_n) begin
        feat_sel <= 6'd0;
        mat_cnt <= 3'b0;
        element11 <= 6'd0;
        element12 <= 6'd0;
        element13 <= 6'd0;
        element14 <= 6'd0;
        element15 <= 6'd0;
        element16 <= 6'd0;

        element21 <= 6'd0;
        element22 <= 6'd0;
        element23 <= 6'd0;
        element24 <= 6'd0;
        element25 <= 6'd0;
        element26 <= 6'd0;

        ag_cnt <= 8'd0; 
    end
    else begin
        if(feat_ag_en) begin
            feat_sel <= adj_mat[mat_cnt];
            mat_cnt <= next_mat_cnt;
            if(en1 == 1) begin
                element11 <= col_features_r[0][0]; 
                element21 <= col_features_r[1][0]; 
            end
            if(en2 == 1) begin
                element12 <= col_features_r[0][1]; 
                element22 <= col_features_r[1][1];
            end
            if(en3 == 1) begin
                element13 <= col_features_r[0][2]; 
                element23 <= col_features_r[1][2];
            end
            if(en4 == 1) begin
                element14 <= col_features_r[0][3]; 
                element24 <= col_features_r[1][3];
            end
            if(en5 == 1) begin
                element15 <= col_features_r[0][4]; 
                element25 <= col_features_r[1][4];
            end
            if(en6 == 1) begin
                element16 <= col_features_r[0][5]; 
                element26 <= col_features_r[1][5];
            end
        end
    end
    
end
assign en1 = feat_sel[0]; 
assign en2 = feat_sel[1];
assign en3 = feat_sel[2];
assign en4 = feat_sel[3];
assign en5 = feat_sel[4];
assign en6 = feat_sel[5];

assign next_mat_cnt = mat_cnt + 1'b0; 
assign next_ag_cnt  = ag_cnt + 1'b1; //used to iterate to the next address in the  

//assign feat_ag_done = (mat_cnt > num_of_rows_in_f_mem-1)? 1'b1 : 1'b0; 

endmodule
