module master
(
input logic rst, clk, rw, /*1:read, 0:write*/ dataValid,
input logic [6:0] addr,
input din,
output dout,
inout tri sda, scl,
output busy, ackErr, done
);
 //Hi 
endmodule
