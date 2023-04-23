onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /gcn_tb/DUT/rst_n
add wave -noupdate /gcn_tb/DUT/clk
add wave -noupdate -radix hexadecimal -childformat {{{/gcn_tb/col_features[1]} -radix unsigned} {{/gcn_tb/col_features[0]} -radix unsigned}} -subitemconfig {{/gcn_tb/col_features[1]} {-height 15 -radix unsigned} {/gcn_tb/col_features[0]} {-height 15 -radix unsigned}} /gcn_tb/col_features
add wave -noupdate /gcn_tb/start
add wave -noupdate /gcn_tb/DUT/start_r
add wave -noupdate /gcn_tb/DUT/state
add wave -noupdate /gcn_tb/DUT/input_re
add wave -noupdate -radix unsigned -childformat {{{/gcn_tb/DUT/col_features_r[1]} -radix unsigned} {{/gcn_tb/DUT/col_features_r[0]} -radix unsigned}} -expand -subitemconfig {{/gcn_tb/DUT/col_features_r[1]} {-height 15 -radix unsigned} {/gcn_tb/DUT/col_features_r[0]} {-height 15 -radix unsigned}} /gcn_tb/DUT/col_features_r
add wave -noupdate -radix unsigned -childformat {{{/gcn_tb/DUT/coo_mat_r[1]} -radix unsigned} {{/gcn_tb/DUT/coo_mat_r[0]} -radix unsigned}} -expand -subitemconfig {{/gcn_tb/DUT/coo_mat_r[1]} {-height 15 -radix unsigned} {/gcn_tb/DUT/coo_mat_r[0]} {-height 15 -radix unsigned}} /gcn_tb/DUT/coo_mat_r
add wave -noupdate -radix unsigned /gcn_tb/DUT/top
add wave -noupdate -radix unsigned /gcn_tb/DUT/bot
add wave -noupdate -divider Address
add wave -noupdate -radix unsigned /gcn_tb/DUT/input_addr_fm
add wave -noupdate -radix unsigned /gcn_tb/DUT/input_addr_wm
add wave -noupdate -divider {adjacency matrix}
add wave -noupdate /gcn_tb/DUT/adj_en
add wave -noupdate /gcn_tb/DUT/adj_done
add wave -noupdate -radix unsigned -childformat {{{/gcn_tb/DUT/adj_mat[5]} -radix unsigned} {{/gcn_tb/DUT/adj_mat[4]} -radix unsigned} {{/gcn_tb/DUT/adj_mat[3]} -radix unsigned} {{/gcn_tb/DUT/adj_mat[2]} -radix unsigned} {{/gcn_tb/DUT/adj_mat[1]} -radix unsigned} {{/gcn_tb/DUT/adj_mat[0]} -radix unsigned}} -expand -subitemconfig {{/gcn_tb/DUT/adj_mat[5]} {-height 15 -radix unsigned} {/gcn_tb/DUT/adj_mat[4]} {-height 15 -radix unsigned} {/gcn_tb/DUT/adj_mat[3]} {-height 15 -radix unsigned} {/gcn_tb/DUT/adj_mat[2]} {-height 15 -radix unsigned} {/gcn_tb/DUT/adj_mat[1]} {-height 15 -radix unsigned} {/gcn_tb/DUT/adj_mat[0]} {-height 15 -radix unsigned}} /gcn_tb/DUT/adj_mat
add wave -noupdate /gcn_tb/DUT/feat_sel
add wave -noupdate -radix unsigned /gcn_tb/DUT/elements1
add wave -noupdate -radix unsigned /gcn_tb/DUT/elements2
add wave -noupdate -divider {Feature Aggregation}
add wave -noupdate /gcn_tb/DUT/feat_ag_en
add wave -noupdate /gcn_tb/DUT/feat_ag_done
add wave -noupdate /gcn_tb/DUT/feat_ag_en
add wave -noupdate /gcn_tb/DUT/feat_ag_done
add wave -noupdate -radix unsigned /gcn_tb/DUT/pre_ag1a
add wave -noupdate -radix unsigned /gcn_tb/DUT/pre_ag1b
add wave -noupdate -radix unsigned /gcn_tb/DUT/pre_ag2a
add wave -noupdate -radix unsigned /gcn_tb/DUT/pre_ag2b
add wave -noupdate -radix unsigned /gcn_tb/DUT/ag1
add wave -noupdate -radix unsigned /gcn_tb/DUT/ag2
add wave -noupdate -divider Transformation
add wave -noupdate /gcn_tb/DUT/feat_accum_en
add wave -noupdate /gcn_tb/DUT/feat_accum_done
add wave -noupdate /gcn_tb/DUT/feat_accum_cnt
add wave -noupdate -radix unsigned -childformat {{{/gcn_tb/DUT/row_weights_r[1]} -radix unsigned} {{/gcn_tb/DUT/row_weights_r[0]} -radix unsigned -childformat {{{[2]} -radix unsigned} {{[1]} -radix unsigned} {{[0]} -radix binary}}}} -expand -subitemconfig {{/gcn_tb/DUT/row_weights_r[1]} {-height 15 -radix unsigned} {/gcn_tb/DUT/row_weights_r[0]} {-height 15 -radix unsigned -childformat {{{[2]} -radix unsigned} {{[1]} -radix unsigned} {{[0]} -radix binary}} -expand} {/gcn_tb/DUT/row_weights_r[0][2]} {-radix unsigned} {/gcn_tb/DUT/row_weights_r[0][1]} {-radix unsigned} {/gcn_tb/DUT/row_weights_r[0][0]} {-radix binary}} /gcn_tb/DUT/row_weights_r
add wave -noupdate -radix unsigned /gcn_tb/DUT/trans_mat1
add wave -noupdate -radix unsigned /gcn_tb/DUT/trans_mat2
add wave -noupdate -radix unsigned /gcn_tb/DUT/accum_mat1
add wave -noupdate -radix unsigned -childformat {{{/gcn_tb/DUT/accum_mat2[5]} -radix unsigned} {{/gcn_tb/DUT/accum_mat2[4]} -radix unsigned} {{/gcn_tb/DUT/accum_mat2[3]} -radix unsigned} {{/gcn_tb/DUT/accum_mat2[2]} -radix unsigned} {{/gcn_tb/DUT/accum_mat2[1]} -radix unsigned} {{/gcn_tb/DUT/accum_mat2[0]} -radix unsigned}} -expand -subitemconfig {{/gcn_tb/DUT/accum_mat2[5]} {-height 15 -radix unsigned} {/gcn_tb/DUT/accum_mat2[4]} {-height 15 -radix unsigned} {/gcn_tb/DUT/accum_mat2[3]} {-height 15 -radix unsigned} {/gcn_tb/DUT/accum_mat2[2]} {-height 15 -radix unsigned} {/gcn_tb/DUT/accum_mat2[1]} {-height 15 -radix unsigned} {/gcn_tb/DUT/accum_mat2[0]} {-height 15 -radix unsigned}} /gcn_tb/DUT/accum_mat2
add wave -noupdate -divider Out
add wave -noupdate /gcn_tb/DUT/output_we
add wave -noupdate -radix unsigned /gcn_tb/DUT/out_mat
add wave -noupdate -radix unsigned /gcn_tb/DUT/out_cnt
add wave -noupdate /gcn_tb/DUT/out_en
add wave -noupdate -radix unsigned /gcn_tb/DUT/y
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {8826 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 185
configure wave -valuecolwidth 240
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {5544 ps} {16044 ps}
