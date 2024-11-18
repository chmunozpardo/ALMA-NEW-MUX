set_property PACKAGE_PIN AC11 [get_ports {sscDataN_n[0]}];    # PB2_N - 1 
set_property PACKAGE_PIN AB11 [get_ports {sscDataN_p[0]}];    # PB2_P - 2
set_property PACKAGE_PIN AB13 [get_ports {OWB}];              # PB0_N - 3
#set_property PACKAGE_PIN AB13 [get_ports {OWB}];             # PB1_N - 4
set_property PACKAGE_PIN Y10  [get_ports {sscClkN_n[0] }];    # PB3_N - 7
set_property PACKAGE_PIN W10  [get_ports {sscClkN_p[0] }];    # PB3_P - 8
set_property PACKAGE_PIN AD12 [get_ports {sscSyncN_n[0]}];    # PB1_N - 9
set_property PACKAGE_PIN AC12 [get_ports {sscSyncN_p[0]}];    # PB1_P - 10

set_property PACKAGE_PIN G10 [get_ports {sscDataN_n[1]}];     # LA0_P -> B25_L3_N
set_property PACKAGE_PIN H11 [get_ports {sscDataN_p[1]}];     # LA0_N -> B25_L3_P
set_property PACKAGE_PIN K12 [get_ports {sscClkN_n[1] }];     # LA1_P -> B25_L2_N
set_property PACKAGE_PIN K13 [get_ports {sscClkN_p[1] }];     # LA1_N -> B25_L2_P
set_property PACKAGE_PIN F10 [get_ports {sscSyncN_n[1]}];     # LA2_P -> B25_L5_N
set_property PACKAGE_PIN G11 [get_ports {sscSyncN_p[1]}];     # LA2_N -> B25_L5_P

set_property PACKAGE_PIN J10 [get_ports {sscDataN_n[2]}];     # LA3_P -> B25_L1_N
set_property PACKAGE_PIN J11 [get_ports {sscDataN_p[2]}];     # LA3_N -> B25_L1_P
set_property PACKAGE_PIN J12 [get_ports {sscClkN_p[2] }];     # LA4_P -> B25_L4_P
set_property PACKAGE_PIN H12 [get_ports {sscClkN_n[2] }];     # LA4_N -> B25_L4_N
set_property PACKAGE_PIN D14 [get_ports {sscSyncN_n[2]}];     # LA5_P -> B26_L5_N
set_property PACKAGE_PIN D15 [get_ports {sscSyncN_p[2]}];     # LA5_N -> B26_L5_P

set_property PACKAGE_PIN E13 [get_ports {sscDataN_n[3]}];     # LA6_P -> B26_L6_N
set_property PACKAGE_PIN E14 [get_ports {sscDataN_p[3]}];     # LA6_N -> B26_L6_P
set_property PACKAGE_PIN A10 [get_ports {sscClkN_n[3] }];     # LA7_P -> B25_L10_N
set_property PACKAGE_PIN B11 [get_ports {sscClkN_p[3] }];     # LA7_N -> B25_L10_P
set_property PACKAGE_PIN C12 [get_ports {sscSyncN_n[3]}];     # LA8_P -> B25_L12_N
set_property PACKAGE_PIN D12 [get_ports {sscSyncN_p[3]}];     # LA8_N -> B25_L12_P

set_property PACKAGE_PIN A11 [get_ports {sscDataN_n[4]}];     # LA9_P -> B25_L11_N
set_property PACKAGE_PIN A12 [get_ports {sscDataN_p[4]}];     # LA9_N -> B25_L11_P
set_property PACKAGE_PIN A13 [get_ports {sscClkN_n[4] }];     # LA10_P -> B26_L3_N
set_property PACKAGE_PIN B13 [get_ports {sscClkN_p[4] }];     # LA10_N -> B26_L3_P
set_property PACKAGE_PIN H13 [get_ports {sscSyncN_n[4]}];     # LA11_P -> B26_L10_N
set_property PACKAGE_PIN H14 [get_ports {sscSyncN_p[4]}];     # LA11_N -> B26_L10_P

set_property PACKAGE_PIN E15 [get_ports {sscDataN_n[5]}];     # LA12_P -> B26_L8_N
set_property PACKAGE_PIN F15 [get_ports {sscDataN_p[5]}];     # LA12_N -> B26_L8_P
set_property PACKAGE_PIN G13 [get_ports {sscClkN_p[5] }];     # LA13_P -> B26_L7_P
set_property PACKAGE_PIN F13 [get_ports {sscClkN_n[5] }];     # LA13_N -> B26_L7_N
set_property PACKAGE_PIN C13 [get_ports {sscSyncN_n[5]}];     # LA14_P -> B26_L4_N
set_property PACKAGE_PIN C14 [get_ports {sscSyncN_p[5]}];     # LA14_N -> B26_L4_P

set_property PACKAGE_PIN A15  [get_ports {sscDataN_n[6]}];     # LA15_P -> B26_L1_N
set_property PACKAGE_PIN B15  [get_ports {sscDataN_p[6]}];     # LA15_N -> B26_L1_P
set_property PACKAGE_PIN L13  [get_ports {sscClkN_n[6] }];     # LA16_P -> B26_L12_N
set_property PACKAGE_PIN L14  [get_ports {sscClkN_p[6] }];     # LA16_N -> B26_L12_P
set_property PACKAGE_PIN AF11 [get_ports {sscSyncN_p[6]}];     # LA17_P -> B44_L2_P
set_property PACKAGE_PIN AG11 [get_ports {sscSyncN_n[6]}];     # LA17_N -> B44_L2_N

set_property PACKAGE_PIN AD15 [get_ports {emio_can0_phy_tx}]; # LA18_P -> B24_L5_P
set_property PACKAGE_PIN AD14 [get_ports {emio_can0_phy_rx}]; # LA18_N -> B24_L5_N

set_property IOSTANDARD LVCMOS33    [get_ports {emio_can0_phy_tx}];
set_property IOSTANDARD LVCMOS33    [get_ports {emio_can0_phy_rx}];
set_property IOSTANDARD LVCMOS33    [get_ports {OWB}];

set_property IOSTANDARD DIFF_HSTL_I_18    [get_ports ssc*];