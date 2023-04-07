//-------------------------Clk_gen-----------------------------//
task clk_gen();
clk   = 1'b0;
forever begin 
#(clk_period/2)
clk = ~clk;
end
endtask
//-------------------------------------------------------------//

//------------------Task to reset the design-------------------//
task reset_dut();
    if (count ==2) begin
      rst_n=0;
     end
    else begin
     rst_n=1;
     end
endtask
//-------------------------------------------------------------//

/*
logic clk,rst_n,start; // ->
logic [num_of_cols-1:0] [num_of_elements_in_col*BW-1:0] col_features; // Port for feature matrix ->
logic [num_of_rows-1:0] [num_of_elements_in_row*BW-1:0] row_weights; // Port for weight matrix ->
logic [1:0] [17:0] coo_mat; //Port for adjacency matrix ->

logic [no_of_outs-1:0] [2:0] y; //Port for outputs <-
logic input_re; // Port for reading memory from TB <-
logic [num_of_rows-1:0] [num_of_rows_in_w_mem-1:0] input_addr_wm; // Address for selecting 1-3 rows(transoposed cols) of weights. So max val for num_of_rows = 3. <-
logic [num_of_cols-1:0] [num_of_rows_in_f_mem-1:0] input_addr_fm; // Address for selecting 1-6 rows of features. So max val for num_of_cols = 6. <-
logic output_we; // <-
logic [num_of_outs-1:0] output_addr; // <-
logic done; // <-
*/


//-------Task to reset the inptuts--------//
task init_inputs();
if(count==1) begin
start = 0;
// Reset col_features port with for loop
for(i=0;i<num_of_rows_fm;i++) begin
row_features [i] = 0;
end
// Reset row+weights port with for loop
for(i=0;i<num_of_rows_wm;i++) begin
  row_weights [i] = 0;
end

for(i=0;i<num_of_cols_fm;i++) begin
  col_features [i] = 0;
end

coo_mat[0] = 0;
coo_mat[1] = 0;
end
endtask
//---------------------------------------//


//------Task to give the start signal----//
task start_valid();
if(count==5) begin
start = 1'b1;
end
else if (done==1) begin
  start = 1'b0;
  end
endtask
//--------------------------------------//

//--- Task to get the input address----//
task send_features_weights_COO_WB();
if (count>5) begin 
  if(input_re) begin
    get_features_from_memory_looped(); // Rowise decoder for F2F students
    get_features_from_memory_looped_col(); // Colwise decoder for Online students
    get_weights_from_memory_looped();
    get_adj_mat_from_memory();
  end // if input_re

  else begin
    for(i=0;i<num_of_rows_fm;i++) begin
    row_features [i] = 0;
    end
    
    for(i=0;i<num_of_cols_fm;i++) begin
      col_features [i] = 0;
    end

    for(i=0;i<num_of_rows_wm;i++) begin
    row_weights [i] = 0;
    end
  end //else
  write_back();
  write_back_aggregation();
  end //if count
endtask
//-------------------------------------//

// Task to compare the golden outs with the design outputs //
task compare_F2F();
if((done==1'b1) && (count==cycles_to_finish+10)) begin
  for (i=0;i<6;i++) begin
    if(gcn_out_memory[i] == gcn_out_memory_golden[i]) begin
      $display("Correct classification for node %d ",i);
    end
    else begin
      $display("Incorrect classification for node %d ",i);
      $display("Correct value: %d",gcn_out_memory_golden[i]);
      $display("Value from GCN module %d \n",gcn_out_memory[i]);
    end
  end
end
else begin
  if(count==cycles_to_finish+10) begin
    $display("--------------------Warning: Not compared. May be due to inactive Done signal--------------------");
  end
  end
endtask
//-------------------------------------//


//-----Task to compare the golden outs with the design outputs-----//
task compare_online();
if((done==1'b1) && (count==cycles_to_finish+10)) begin
  for (i=0;i<6;i++) begin
    for(j=0;j<96;j++) begin
     if(Aggregated_matrix_memory[i] [j] == Aggregated_matrix_memory_golden[i] [j]) begin
      $display("Correct Aggregation for %d %d ",i,j);
    end
    else begin
      $display("Incorrect Aggregation for %d %d ",i,j);
      $display("Correct value: %d",Aggregated_matrix_memory_golden[i] [j]);
      $display("Value from GCN module %d \n",Aggregated_matrix_memory[i] [j]);
    end
  end
end
end
else begin
  if(count==cycles_to_finish+10) begin
    $display("--------------------Warning: Not compared. May be due to inactive Done signal--------------------");
  end
  end
endtask
//-------------------------------------//