//----------------------To Dump vpd for DVE--------------------//
task dump_vpd();
    $vcdplusfile("wave.vpd");
    $vcdplusmemon();
    $vcdpluson(0,gcn_tb);
endtask
//-------------------------------------------------------------//

//---------------------To Dump VCD-----------------------------//
task dump_vcd();
    $dumpfile("gcn.vcd");
    $dumpvars(0,gcn_tb);
endtask
//-------------------------------------------------------------//