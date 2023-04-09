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
                if (adj_done == 1'b1)
                   next_state = feat_ag;
                else 
                    next_state <= adj; 

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
logic [5:0] feat_sel1, feat_sel2, feat_sel3, feat_sel4, feat_sel5, feat_sel6;
logic [2:0] mat_cnt ;
logic [2:0] next_mat_cnt ;
logic [num_of_nodes-1:0][BW-1:0] elements10, elements20;//, elements3, elements4, elements5, elements6; //the first and second clocked col vs adj_row
logic en11, en12, en13, en14, en15, en16; 
logic en21, en22, en23, en24, en25, en26;
//logic [BW-1:0] element21, element22, element23, element24, element25, element26; /the first clocked col vs element in col
logic [7:0] ag_cnt, next_ag_cnt; 
logic [num_of_nodes-1:0][9:0] ag1, ag2; //1st/2nd col  vs first
always_ff @( posedge clk or negedge rst_n ) begin : feat_ag_reg
    if(~rst_n) begin
        for(i=8'd0; i<num_of_nodes; i++) begin
            elements10[i] <= {BW-1{1'b0}}; 
            elements20[i] <= {BW-1{1'b0}}; 
            ag1[i] <= 10'd0; 
            ag2[i] <= 10'd0; 
        end
        ag_cnt <= 8'd0; 
    end
    else begin
        if(feat_ag_en) begin
            if(feat_sel1[0] == 1) begin
                elements10[0] <= col_features_r[0][0];
                elements20[0] <= col_features_r[1][0];
            end
            if(feat_sel1[1] == 1) begin
                elements10[1] <= col_features_r[0][1];
                elements20[1] <= col_features_r[1][1]; 
            end
            if(feat_sel1[2] == 1) begin
                elements10[2] <= col_features_r[0][2];
                elements20[2] <= col_features_r[1][2]; 
            end
            if(feat_sel1[3] == 1) begin
                elements10[3] <= col_features_r[0][3]; 
                elements20[0] <= col_features_r[1][0];
            end
            if(feat_sel1[4] == 1) begin
                elements10[4] <= col_features_r[0][4];
                elements20[4] <= col_features_r[1][4]; 
            end
            if(feat_sel1[5] == 1) begin
                elements10[5] <= col_features_r[0][5];
                elements20[5] <= col_features_r[1][5];
            end
            ag1[0] <= elements10[0] + elements10[1] + elements10[2] + elements10[3] + elements10[4] + elements10[5]; 
            ag2[0] <= elements20[0] + elements20[1] + elements20[2] + elements20[3] + elements20[4] + elements20[5]; 
        end
    end  
end
assign feat_sel1 = adj_mat[0];
/*assign en11 = feat_sel1[0]; //
assign en12 = feat_sel1[1];
assign en13 = feat_sel1[2];
assign en14 = feat_sel1[3];
assign en15 = feat_sel1[4];
assign en16 = feat_sel1[5];*/

assign feat_sel2 = adj_mat[1];


assign feat_sel3 = adj_mat[2];
assign feat_sel4 = adj_mat[3];
assign feat_sel5 = adj_mat[4];
assign feat_sel6 = adj_mat[5];



//assign next_mat_cnt = mat_cnt + 1'b0; 
assign next_ag_cnt  = ag_cnt + 1'b1; //used to iterate to the next address in the  

//assign feat_ag_done = (mat_cnt > num_of_rows_in_f_mem-1)? 1'b1 : 1'b0; 

endmodule
