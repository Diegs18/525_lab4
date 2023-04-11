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
    //output logic [num_of_outs-1:0] [9:0] aggregated_out,
    //output logic [num_of_outs-1:0] [6:0] aggregated_address,
    output logic done
);

    logic [7:0] i, j;
    logic start_r; 
    logic [num_of_cols_fm-1:0] [num_of_elements_in_col-1:0] [BW-1:0]  col_features_r;
    logic [1:0] [2:0] [BW-1:0]  row_weights_r;
    logic [1:0] [5:0] [2:0]  coo_mat_r; 
    logic [num_of_nodes-1:0][9:0] ag1, ag2; //1st/2nd col  vs first
    logic [6:0] wm_addr;
    logic feat_ag_en;

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
            done <= 1'b0; 
        end
        else begin
            if(input_re == 1'b1) begin
                col_features_r <= col_features;
                coo_mat_r   <= coo_mat;
            end
            if(feat_ag_en) begin
                for(i=0; i<num_of_rows_wm ; i++) begin 
                    row_weights_r[0][i]  <= row_weights[i][wm_addr-:6];
                    row_weights_r[1][i]  <= row_weights[i][wm_addr+6'd5-:6];
                end
            end
            if(output_we == 1'b1) begin
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
    logic feat_ag_done;
    logic add_cnt_en, add_rst, out_add_en, ag_add_en;
    always_ff @( posedge clk or negedge rst_n ) begin : FSM
        if(~rst_n)
            state <= init;
        else
            state <= next_state; 
    end

    always_comb begin : state_logic
        input_re  = 1'b0; 
        output_we  = 1'b0; 
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
                feat_ag_en = 1'b1; 
                //output_we = 1'b1;
                input_re = 1'b1; 
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
    assign adj_done_b = (col>4'd4)? 1'b1 : 1'b0;

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
    logic [5:0] feat_sel0, feat_sel1, feat_sel2, feat_sel3, feat_sel4, feat_sel5;
    logic [2:0] mat_cnt ;
    logic [2:0] next_mat_cnt ;

    logic [num_of_nodes-1:0][BW-1:0] elements10, elements20;// //the 1st and 2nd clocked col vs 1st adj_row
    logic [num_of_nodes-1:0][BW-1:0] elements11, elements21;// //the 1st and 2nd clocked col vs 2nd adj_row
    logic [num_of_nodes-1:0][BW-1:0] elements12, elements22;// //the 1st and 2nd clocked col vs 3rd adj_row
    logic [num_of_nodes-1:0][BW-1:0] elements13, elements23;// //the 1st and 2nd clocked col vs 4th adj_row
    logic [num_of_nodes-1:0][BW-1:0] elements14, elements24;// //the 1st and 2nd clocked col vs 5th adj_row
    logic [num_of_nodes-1:0][BW-1:0] elements15, elements25;// //the 1st and 2nd clocked col vs 6th adj_row

    //logic [num_of_nodes-1:0][9:0] ag1, ag2; //1st/2nd col  vs first
    always_ff @( posedge clk or negedge rst_n ) begin : feat_ag_reg
        if(~rst_n) begin
            for(i=8'd0; i<num_of_nodes; i++) begin
                elements10[i] <= {BW-1{1'b0}}; 
                elements20[i] <= {BW-1{1'b0}};
                elements11[i] <= {BW-1{1'b0}}; 
                elements21[i] <= {BW-1{1'b0}};
                elements12[i] <= {BW-1{1'b0}}; 
                elements22[i] <= {BW-1{1'b0}};
                elements13[i] <= {BW-1{1'b0}}; 
                elements23[i] <= {BW-1{1'b0}};
                elements14[i] <= {BW-1{1'b0}}; 
                elements24[i] <= {BW-1{1'b0}};
                elements15[i] <= {BW-1{1'b0}}; 
                elements25[i] <= {BW-1{1'b0}};
                ag1[i] <= 10'd0; 
                ag2[i] <= 10'd0; 
            end
        end
        else begin
            if(feat_ag_en) begin
                
                ////////////////////////////////////////////////////////////////////////////////////////////////////////

                if(feat_sel0[0] == 1) begin
                    elements10[0] <= col_features_r[0][0];
                    elements20[0] <= col_features_r[1][0];
                end
                if(feat_sel0[1] == 1) begin
                    elements10[1] <= col_features_r[0][1];
                    elements20[1] <= col_features_r[1][1]; 
                end
                if(feat_sel0[2] == 1) begin
                    elements10[2] <= col_features_r[0][2];
                    elements20[2] <= col_features_r[1][2]; 
                end
                if(feat_sel0[3] == 1) begin
                    elements10[3] <= col_features_r[0][3]; 
                    elements20[0] <= col_features_r[1][0];
                end
                if(feat_sel0[4] == 1) begin
                    elements10[4] <= col_features_r[0][4];
                    elements20[4] <= col_features_r[1][4]; 
                end
                if(feat_sel0[5] == 1) begin
                    elements10[5] <= col_features_r[0][5];
                    elements20[5] <= col_features_r[1][5];
                end
                ag1[0] <= elements10[0] + elements10[1] + elements10[2] + elements10[3] + elements10[4] + elements10[5]; 
                ag2[0] <= elements20[0] + elements20[1] + elements20[2] + elements20[3] + elements20[4] + elements20[5]; 
                
                ////////////////////////////////////////////////////////////////////////////////////////////////////////

                if(feat_sel1[0] == 1) begin
                    elements11[0] <= col_features_r[0][0];
                    elements21[0] <= col_features_r[1][0];
                end
                if(feat_sel1[1] == 1) begin
                    elements11[1] <= col_features_r[0][1];
                    elements21[1] <= col_features_r[1][1]; 
                end
                if(feat_sel1[2] == 1) begin
                    elements11[2] <= col_features_r[0][2];
                    elements21[2] <= col_features_r[1][2]; 
                end
                if(feat_sel1[3] == 1) begin
                    elements11[3] <= col_features_r[0][3]; 
                    elements21[0] <= col_features_r[1][3];
                end
                if(feat_sel1[4] == 1) begin
                    elements11[4] <= col_features_r[0][4];
                    elements21[4] <= col_features_r[1][4]; 
                end
                if(feat_sel1[5] == 1) begin
                    elements11[5] <= col_features_r[0][5];
                    elements21[5] <= col_features_r[1][5];
                end
                ag1[1] <= elements11[0] + elements11[1] + elements11[2] + elements11[3] + elements10[4] + elements11[5]; 
                ag2[1] <= elements21[0] + elements21[1] + elements21[2] + elements21[3] + elements20[4] + elements21[5]; 

                ////////////////////////////////////////////////////////////////////////////////////////////////////////

                if(feat_sel2[0] == 1) begin
                    elements12[0] <= col_features_r[0][0];
                    elements22[0] <= col_features_r[1][0];
                end
                if(feat_sel2[1] == 1) begin
                    elements12[1] <= col_features_r[0][1];
                    elements22[1] <= col_features_r[1][1]; 
                end
                if(feat_sel2[2] == 1) begin
                    elements12[2] <= col_features_r[0][2];
                    elements22[2] <= col_features_r[1][2]; 
                end
                if(feat_sel2[3] == 1) begin
                    elements12[3] <= col_features_r[0][3]; 
                    elements22[0] <= col_features_r[1][3];
                end
                if(feat_sel2[4] == 1) begin
                    elements12[4] <= col_features_r[0][4];
                    elements22[4] <= col_features_r[1][4]; 
                end
                if(feat_sel2[5] == 1) begin
                    elements12[5] <= col_features_r[0][5];
                    elements22[5] <= col_features_r[1][5];
                end
                ag1[2] <= elements12[0] + elements12[1] + elements12[2] + elements12[3] + elements12[4] + elements12[5]; 
                ag2[2] <= elements22[0] + elements22[1] + elements22[2] + elements22[3] + elements22[4] + elements22[5]; 

                ////////////////////////////////////////////////////////////////////////////////////////////////////////

                if(feat_sel3[0] == 1) begin
                    elements13[0] <= col_features_r[0][0];
                    elements23[0] <= col_features_r[1][0];
                end
                if(feat_sel3[1] == 1) begin
                    elements13[1] <= col_features_r[0][1];
                    elements23[1] <= col_features_r[1][1]; 
                end
                if(feat_sel3[2] == 1) begin
                    elements13[2] <= col_features_r[0][2];
                    elements23[2] <= col_features_r[1][2]; 
                end
                if(feat_sel3[3] == 1) begin
                    elements13[3] <= col_features_r[0][3]; 
                    elements23[0] <= col_features_r[1][3];
                end
                if(feat_sel3[4] == 1) begin
                    elements13[4] <= col_features_r[0][4];
                    elements23[4] <= col_features_r[1][4]; 
                end
                if(feat_sel3[5] == 1) begin
                    elements13[5] <= col_features_r[0][5];
                    elements23[5] <= col_features_r[1][5];
                end
                ag1[3] <= elements13[0] + elements13[1] + elements13[2] + elements13[3] + elements13[4] + elements13[5]; 
                ag2[3] <= elements23[0] + elements23[1] + elements23[2] + elements23[3] + elements23[4] + elements23[5]; 

                ////////////////////////////////////////////////////////////////////////////////////////////////////////

                if(feat_sel4[0] == 1) begin
                    elements14[0] <= col_features_r[0][0];
                    elements24[0] <= col_features_r[1][0];
                end
                if(feat_sel4[1] == 1) begin
                    elements14[1] <= col_features_r[0][1];
                    elements24[1] <= col_features_r[1][1]; 
                end
                if(feat_sel4[2] == 1) begin
                    elements14[2] <= col_features_r[0][2];
                    elements24[2] <= col_features_r[1][2]; 
                end
                if(feat_sel4[3] == 1) begin
                    elements14[3] <= col_features_r[0][3]; 
                    elements24[0] <= col_features_r[1][3];
                end
                if(feat_sel4[4] == 1) begin
                    elements14[4] <= col_features_r[0][4];
                    elements24[4] <= col_features_r[1][4]; 
                end
                if(feat_sel4[5] == 1) begin
                    elements14[5] <= col_features_r[0][5];
                    elements24[5] <= col_features_r[1][5];
                end
                ag1[4] <= elements14[0] + elements14[1] + elements14[2] + elements14[3] + elements14[4] + elements14[5]; 
                ag2[4] <= elements24[0] + elements24[1] + elements24[2] + elements24[3] + elements24[4] + elements24[5]; 

                ////////////////////////////////////////////////////////////////////////////////////////////////////////

                if(feat_sel5[0] == 1) begin
                    elements15[0] <= col_features_r[0][0];
                    elements25[0] <= col_features_r[1][0];
                end
                if(feat_sel5[1] == 1) begin
                    elements15[1] <= col_features_r[0][1];
                    elements25[1] <= col_features_r[1][1]; 
                end
                if(feat_sel5[2] == 1) begin
                    elements15[2] <= col_features_r[0][2];
                    elements25[2] <= col_features_r[1][2]; 
                end
                if(feat_sel5[3] == 1) begin
                    elements15[3] <= col_features_r[0][3]; 
                    elements25[0] <= col_features_r[1][3];
                end
                if(feat_sel5[4] == 1) begin
                    elements15[4] <= col_features_r[0][4];
                    elements25[4] <= col_features_r[1][4]; 
                end
                if(feat_sel5[5] == 1) begin
                    elements15[5] <= col_features_r[0][5];
                    elements25[5] <= col_features_r[1][5];
                end
                ag1[5] <= elements15[0] + elements15[1] + elements15[2] + elements15[3] + elements15[4] + elements15[5]; 
                ag2[5] <= elements25[0] + elements25[1] + elements25[2] + elements25[3] + elements25[4] + elements25[5]; 

            end
        end  
    end
    assign feat_sel0 = adj_mat[0];
    assign feat_sel1 = adj_mat[1];
    assign feat_sel2 = adj_mat[2];
    assign feat_sel3 = adj_mat[3];
    assign feat_sel4 = adj_mat[4];
    assign feat_sel5 = adj_mat[5];


//////////////////////////////////////////////////////////////////////////////////////////////
//                        Address Counter
//////////////////////////////////////////////////////////////////////////////////////////////
//    output logic [num_of_rows_wm-1:0] [1:0] input_addr_wm,
//    output logic [num_of_cols_fm-1:0] [6:0] input_addr_fm,
//    output logic output_we,
//    output logic [num_of_outs-1:0] [2:0] output_addr,
//    output logic [num_of_nodes*num_of_cols_fm-1:0] [9:0] aggregated_out,
//assign feat_ag_done = (mat_cnt > num_of_rows_in_f_mem-1)? 1'b1 : 1'b0; 
//logic input_re, output_we;
//logic add_cnt_en, add_rst, out_add_en, agg_add_en;
logic [num_of_cols_fm-1:0][6:0] next_input_addr_fm; 
logic [6:0] next_wm_addr;
logic [2:0] i3; 
    always_ff @( posedge clk or negedge rst_n ) begin : cnt_regs
        if (~rst_n) begin
                for (i=2'b0; i<num_of_rows_wm; i++) begin
                    input_addr_wm[i] <= i;
                end
                for (i=7'b0; i<num_of_cols_fm; i++) begin
                    input_addr_fm[i] <= i;
                end
                wm_addr <= 7'd5; 
        end
        else begin
            if(output_we) begin

            end
            if(input_re) begin
               input_addr_fm <= next_input_addr_fm; 
               wm_addr <= next_wm_addr;
            end
        end
    end


    always_comb begin

        next_input_addr_fm[0] = 7'd0;
        next_input_addr_fm[1] = 7'd0;
      
        next_wm_addr = 7'd5;

        if(input_re) begin
            next_input_addr_fm[0] = input_addr_fm[0] + 7'd2;
            next_input_addr_fm[1] = input_addr_fm[1] + 7'd2;
        end
        if(feat_ag_en) begin
            next_wm_addr = wm_addr + 7'd10;
        end

    end
     

endmodule
