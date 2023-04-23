`include "params.vh"


module gcn (
    input   logic clk,
    input   logic rst_n,
    input   logic start,
    input   logic [num_of_cols_fm-1:0] [num_of_elements_in_col*BW-1:0] col_features,
    input   logic [num_of_elements_in_row_wm-1:0] [num_of_rows_wm-1:0] [BW-1:0] row_weights,
    input   logic [1:0] [17:0] coo_mat,
    output  logic [num_of_outs-1:0] [2:0] y,
    output  logic input_re,
    output logic [6:0] input_addr_wm,
    output logic [num_of_cols_fm-1:0] [6:0] input_addr_fm,
    output logic output_we,
    output logic [num_of_outs-1:0] [2:0] output_addr,
    //output logic [num_of_outs-1:0] [9:0] aggregated_out,
    //output logic [num_of_outs-1:0] [6:0] aggregated_address,
    output logic done
);/*
    //debug outputs
    //output logic [num_of_nodes-1:0][9:0] ag1, pre_ag1a, pre_ag1b, ag2, pre_ag2a, pre_ag2b;
    output logic [5:0][2:0][20:0]trans_mat1_o, trans_mat2_o,
    output logic [5:0][2:0][20:0]accum_mat1_o, accum_mat2_o,
    output logic [num_of_nodes-1:0][9:0] ag1_o, ag2_o,
    output logic [5:0][2:0][20:0] capture_mat_o,
    output logic [5:0][20:0] out_mat_o
);*/

    logic [5:0][2:0][20:0]trans_mat1, trans_mat2, next_trans_mat1, next_trans_mat2;
    logic [5:0][2:0][20:0]accum_mat1, accum_mat2, next_accum_mat1, next_accum_mat2;
    logic [num_of_nodes-1:0][9:0] ag1, ag2; 
    logic feat_accum_en;
    logic [5:0][2:0][20:0] capture_mat;
    logic [5:0][20:0] out_mat;
/*
    always_ff @( posedge clk or negedge rst_n ) begin : debug
        if(~rst_n) begin
            for(logic [2:0] x = 0; x<5; x++) begin
                for(logic [2:0] y = 0; y<3; y++) begin
                    trans_mat1_o[x][y]  <= '0;
                    accum_mat1_o[x][y]  <= '0;
                    trans_mat2_o[x][y]  <= '0;
                    accum_mat2_o[x][y]  <= '0;
                    capture_mat_o[x][y]<= '0;
                end
            end     
            for(logic [2:0] x = 0; x<num_of_nodes; x++) begin    
                    ag1_o[x]  <= '0;
                    ag2_o[x]  <= '0;
                    out_mat_o <= '0;
            end
            
        end
        else begin
            trans_mat1_o <= trans_mat1;
            accum_mat1_o <= accum_mat1;
            trans_mat2_o <= trans_mat2;
            accum_mat2_o <= accum_mat2;

            ag1_o <= ag1;
            ag2_o <= ag2;

            capture_mat_o <= capture_mat;
            out_mat_o     <= out_mat; 
        end
    end
*/
    logic [7:0] i, j;
    logic start_r; 
    logic [num_of_cols_fm-1:0] [num_of_elements_in_col-1:0] [BW-1:0]  col_features_r;
    logic [1:0] [2:0] [BW-1:0]  row_weights_r;
    logic [1:0] [5:0] [2:0]  coo_mat_r; 
    logic [num_of_nodes-1:0][9:0] pre_ag1a, pre_ag1b, pre_ag2a, pre_ag2b; //1st/2nd col  vs first
    logic feat_ag_en;
    logic [num_of_outs-1:0] [2:0] pre_y;

    //////////////////////////////////////////////////////////////////////////////////////////////
    //                        Input and output registers
    //////////////////////////////////////////////////////////////////////////////////////////////
    always_ff @( posedge clk or negedge rst_n) begin : in_out_regs
        if(~rst_n) begin
            //for (i=8'b0; i<num_of_cols_fm; i++) begin
                //for (j=8'b0; j<num_of_elements_in_col; j++) begin
            //foreach(col_features_r[i]) begin
                foreach(col_features_r[i,j]) begin
                    col_features_r[i][j]<=5'b0; //i is the column, j is the element in the column
                end
            //end 
            //for (i=8'b0; i<num_of_elements_in_row_wm; i++) begin
                //for (j=8'b0; j<num_of_rows_wm; j++) begin
            //foreach(row_weights_r[i]) begin
                foreach(row_weights_r[i,j]) begin
                    row_weights_r[i][j]<=5'b0; //i is the column, j is the element in the column
                end
            //end 
            //for (i=8'b0; i<2; i++) begin
                //for (j=8'b0; j<6; j++) begin
            //foreach(coo_mat_r[i]) begin
                foreach(coo_mat_r[i,j]) begin
                    coo_mat_r[i][j]<=3'b0; //i is the column, j is the element in the column
                end
            //end
            //for (i=8'b0; i<num_of_outs; i++) begin
            foreach(y[i]) begin
                    y[i]<=3'b0; //i is the column, j is the element in the column
                    output_addr [i] <= i; 
            end
            //done <= 1'b0; 
        end
        else begin
            if(start == 1'b1) begin
                if(input_re == 1'b1) begin
                    coo_mat_r   <= coo_mat;
                    if(feat_ag_en)
                        col_features_r <= col_features;
                end
                if(feat_accum_en) begin
                        row_weights_r[0][0]  <= row_weights[0][0];
                        row_weights_r[0][1]  <= row_weights[0][1];
                        row_weights_r[0][2]  <= row_weights[0][2];

                        row_weights_r[1][0]  <= row_weights[1][0];
                        row_weights_r[1][1]  <= row_weights[1][1];
                        row_weights_r[1][2]  <= row_weights[1][2];
                end
                if(output_we == 1'b1) begin
                    y <= pre_y;
                end
            end
        end
    end

    //////////////////////////////////////////////////////////////////////////////////////////////
    //                        Finite State Machine
    //////////////////////////////////////////////////////////////////////////////////////////////
    typedef enum {init, fetch, adj, feat_ag, feat_ag_trans, feat_trans, feat_accum, out, capture, hold} state_t;
    state_t state, next_state;
    logic adj_en; 
    logic adj_done, adj_done_b;
    logic feat_ag_done;
    logic add_cnt_en, add_rst, out_add_en;
    logic feat_trans_en, feat_trans_done;
    logic out_en; 
    logic out_done;
    logic [2:0] out_cnt;
    logic write_out_en;
    logic feat_accum_done;
    logic [2:0] feat_accum_cnt;
    logic capture_en;

    always_ff @( posedge clk or negedge rst_n ) begin : FSM
        if(~rst_n)
            state <= init;
        else
            state <= next_state; 
    end

    always_comb begin : state_logic
        input_re  = 1'b0; 
        output_we  = 1'b0;
        feat_trans_en = 1'b0;  
        next_state = init;
        adj_en = 1'b0; 
        feat_ag_en = 1'b0; 
        out_en = 1'b0; 
        feat_accum_en = 1'b0;
	    done = 1'b0;
        capture_en = '0;  
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
                    next_state = adj; 
            end
            feat_ag : begin
                //adj_en = 1'b1; 
                feat_ag_en = 1'b1; 
                input_re = 1'b1; 
                if (input_addr_fm[0]>2) begin
                    next_state = feat_ag_trans;
                    //feat_trans_en = 1'b1;
                end
                else 
                    next_state = feat_ag; 
            end
            feat_ag_trans: begin
                feat_ag_en = 1'b1; 
                input_re = 1'b1; 
                feat_trans_en = 1'b1;
                feat_accum_en =1'b1;
                if(feat_ag_done == 1'b1)
                    next_state = feat_trans; 
                else
                    next_state = feat_ag_trans;
            end
            feat_trans : begin
                feat_accum_en =1'b1;
                feat_ag_en = 1'b0; 
                input_re = 1'b1; 
                feat_trans_en = 1'b1; 
                if(feat_trans_done == 1'b1)
                    next_state = feat_accum; 
                else
                    next_state = feat_trans;   
            end
            feat_accum : begin
                feat_accum_en =1'b1;
                if(feat_accum_done)
                    next_state = capture;
                else
                    next_state = feat_accum; 
            end
            capture : begin
                capture_en = '1;
                next_state = out;
            end
            out : begin
                out_en = 1'b1;
                feat_accum_en =1'b0;
                if(out_done) begin
                    next_state = hold;
                    output_we = 1'b1;
                end
                else
                    next_state = out;
            end
            hold : begin
                output_we = 1'b1;
		        done = 1'b1; 
                next_state = hold; 
            end
            default : begin 
                next_state = init; 
            end
        endcase
    end
    assign out_done     = (out_cnt<3'd3)? 1'd0 : 1'd1;
    assign feat_ag_done = (input_addr_fm[0]<7'd96)? 1'b0 : 1'b1; 
    assign feat_trans_done = (input_addr_wm<'d94)? 1'b0 : 1'b1; 
    assign feat_accum_done = (feat_accum_cnt<2)? 1'b0 : 1'b1; 
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
                //for(ix=3'b0; ix<3'd6; ix++) begin
                foreach(adj_mat[i]) begin
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
    logic [5:0][5:0] feat_sel;//, feat_sel1, feat_sel2, feat_sel3, feat_sel4, feat_sel5;
    logic [2:0] mat_cnt ;
    logic [2:0] next_mat_cnt ;
    logic [num_of_elements_in_col-1:0][num_of_nodes-1:0][BW-1:0] elements1, elements2;// //the 1st and 2nd clocked col vs 1st adj_row
    logic [num_of_nodes-1:0][9:0] next_ag1, next_pre_ag1a, next_pre_ag1b, next_ag2, next_pre_ag2a, next_pre_ag2b;
    //logic [num_of_nodes-1:0][9:0] ag1, ag2; //1st/2nd col  vs first
    always_ff @( posedge clk or negedge rst_n ) begin : feat_ag_reg
        if(~rst_n) begin
            //for(jx = 8'd0; jx<6; jx++) begin
                //for(ix=8'd0; ix<num_of_nodes; ix++) begin
            foreach(elements1[j,i]) begin
                elements1[j][i] <= {BW-1{1'b0}}; 
                elements2[j][i] <= {BW-1{1'b0}};
                //end
            end
            //for(ix=8'd0; ix<num_of_nodes; ix++) begin
            foreach(ag1[i]) begin
                ag1[i] <= 10'd0; 
                ag2[i] <= 10'd0;
                pre_ag1a[i] <= 10'b0; 
                pre_ag1b[i] <= 10'b0; 
                pre_ag2a[i] <= 10'b0; 
                pre_ag2b[i] <= 10'b0; 
            end
        end
        else begin
            if(feat_ag_en) begin
                ////////////////////////////////////////////////////////////////////////////////////////////////////////
                //for(jx = 8'd0; jx<6; jx++) begin
                    //for(ix = 8'd0; ix<6; ix++) begin
                foreach(elements1[j,i]) begin
                    if(feat_sel[j][i] == 1'b1) begin
                        elements1[j][i] <= col_features_r[0][i];
                        elements2[j][i] <= col_features_r[1][i];
                    end
                    //end                    
                end 
            end
                pre_ag1a <= next_pre_ag1a;
                pre_ag1b <= next_pre_ag1b;

                pre_ag2a <= next_pre_ag2a;
                pre_ag2b <= next_pre_ag2b;                  
                ////////////////////////////////////////////////////////////////////////////////////////////////////////
                ag1 <= next_ag1;
                ag2 <= next_ag2; 
        end  
    end
    
    always_comb begin : feat_select
        //for(i2=8'b0; i2<6; i2++) begin
        foreach(feat_sel[i]) begin
            feat_sel[i] = adj_mat[i];
        end 
        //for(i2=8'b0; i2<6; i2++) begin
        foreach(next_pre_ag1a[i]) begin
            next_pre_ag1a[i] = elements1[i][0] + elements1[i][1] + elements1[i][2];
            next_pre_ag1b[i] = elements1[i][3] + elements1[i][4] + elements1[i][5]; 
        
            next_pre_ag2a[i] = elements2[i][0] + elements2[i][1] + elements2[i][2];
            next_pre_ag2b[i] = elements2[i][3] + elements2[i][4] + elements2[i][5];

            next_ag1 = pre_ag1a + pre_ag1b;
            next_ag2 = pre_ag2a + pre_ag2b;
        end

    end
        


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

    always_ff @( posedge clk or negedge rst_n ) begin : cnt_regs
        if (~rst_n) begin
                //for (i=2'b0; i<num_of_rows_wm; i++) begin
            input_addr_wm <= 7'd0;
                //end
            //for (ix=7'b0; ix<num_of_cols_fm; ix++) begin
            foreach(input_addr_fm[i]) begin
                input_addr_fm[i] <= i;
            end
        end
        else begin
            if(input_re) begin
               input_addr_fm <= next_input_addr_fm; 
               input_addr_wm <= next_wm_addr;
            end
        end
    end
    

    always_comb begin
        if( feat_ag_en) begin
            next_input_addr_fm[0] = input_addr_fm[0] + 7'd2;
            next_input_addr_fm[1] = input_addr_fm[1] + 7'd2;
        end
        else begin
            next_input_addr_fm[0] = 7'd0;
            next_input_addr_fm[1] = 7'd1;
        end
    end

    always_comb begin

        if(feat_trans_en) begin
            next_wm_addr = input_addr_wm + 7'd2;
        end
        else begin
            next_wm_addr = 7'd0;
        end

    end

//////////////////////////////////////////////////////////////////////////////////////////////
//                        Multiplication and accumulation
//////////////////////////////////////////////////////////////////////////////////////////////
//logic [num_of_nodes-1:0][9:0] ag1, ag2; //1st/2nd col  vs first
//logic [1:0] [2:0] [BW-1:0]  row_weights_r
    //logic [5:0][2:0][20:0]trans_mat1, trans_mat2, next_trans_mat1, next_trans_mat2;
    //logic [5:0][2:0][20:0]accum_mat1, accum_mat2, next_accum_mat1, next_accum_mat2;
    logic [7:0] ii, jj, iii, jjj;
    logic [2:0] next_feat_accum_cnt;
    always_ff @( posedge clk or negedge rst_n) begin : mult_accum
        if(~rst_n) begin
            //for ( ix=7'b0; ix<num_of_outs; ix++) begin
            //    for ( jx=7'b0; jx<num_of_rows_wm; jx++) begin
            foreach(trans_mat1[i,j]) begin
                trans_mat1[i][j] <= 21'b0;
                trans_mat2[i][j] <= 21'b0;
                accum_mat1[i][j] <= 21'b0;
                accum_mat2[i][j] <= 21'b0;
                //end
            end
            feat_accum_cnt <= 2'b00; 
        end
        else begin
            //if(feat_trans_en) begin
            if(feat_accum_en) begin
                trans_mat1 <= next_trans_mat1; 
                trans_mat2 <= next_trans_mat2;
            //end
            
                accum_mat1 <= next_accum_mat1;
                accum_mat2 <= next_accum_mat2;
                feat_accum_cnt <= next_feat_accum_cnt;
            end
        end
    end
assign next_feat_accum_cnt = (feat_accum_en & ~feat_trans_en & ~out_en)? feat_accum_cnt + 1 : 0;

    always_comb begin : multiply
        //for ( ii=7'b0; ii<num_of_outs; ii++) begin
        //    for ( jj=7'b0; jj<num_of_rows_wm; jj++) begin
        foreach(next_trans_mat1[i,j]) begin
            next_trans_mat1[i][j] = ag1[i] * row_weights_r[0][j];
            next_trans_mat2[i][j] = ag2[i] * row_weights_r[1][j];
           //end
        end        
    end

    always_comb begin : accumulate
        //for ( iii=7'b0; iii<num_of_outs; iii++) begin
            //for ( jjj=7'b0; jjj<num_of_rows_wm; jjj++) begin
        foreach(next_accum_mat1[i,j]) begin
            next_accum_mat1[i][j] = trans_mat1[i][j] + trans_mat2[i][j];
            next_accum_mat2[i][j] = accum_mat1[i][j] + accum_mat2[i][j];
            //end
        end
    end
    

//////////////////////////////////////////////////////////////////////////////////////////////
//                        argmax
//////////////////////////////////////////////////////////////////////////////////////////////
    logic [2:0] next_out_cnt, i4, i5;
    //logic [2:0] out_cnt,
    logic [5:0][20:0] next_out_mat;

    //logic [num_of_outs-1:0] [2:0] pre_y, next_pre_y;
    logic [num_of_outs-1:0] [2:0] next_pre_y;

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            out_cnt <= 3'b0; 
            for (i4=3'b0; i4<6; i4++) begin
                for(logic[1:0]x=0; x<3;x++)
                    capture_mat[i4][x] <= '0;
                out_mat[i4] <= '0; 
                pre_y[i4]   <= '0;
                
            end
        end
        else begin
            if(capture_en)
                capture_mat <= accum_mat2;
            //if(feat_accum_done) begin
            if(out_en) begin
                out_mat <= next_out_mat; //this needs to start clking in at 1 clk before the cnter
                pre_y   <= next_pre_y;
            //end
            
                out_cnt <= next_out_cnt;   
            end
        end
    end

    assign next_out_cnt = ((out_cnt<3'd3) && out_en && ~out_done)? out_cnt + 1 : 0;

    always_comb begin
         for (i5 = 3'd0; i5<3'd6; i5++) begin  
            if (out_mat[i5] < capture_mat[i5][out_cnt]) begin 
                next_out_mat[i5] = capture_mat[i5][out_cnt];
                next_pre_y [i5]  = out_cnt; 
            end
            else begin
                next_out_mat[i5] = out_mat[i5];
                next_pre_y[i5]   = pre_y[i5];
            end
        end
    end


endmodule
