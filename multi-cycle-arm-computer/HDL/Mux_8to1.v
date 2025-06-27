module Mux_8to1 #(parameter WIDTH=4)
    (
	  input [2:0] select,
	  input [WIDTH-1:0] input_0, input_1, input_2, input_3, input_4, input_5, input_6, input_7,
      output reg [WIDTH-1:0] output_value
    );

always@(*) begin
	case(select)
		3'b000:output_value = input_0;
		3'b001:output_value = input_1;
		3'b010:output_value = input_2;
		3'b011:output_value = input_3;

		3'b100:output_value = input_4;
		3'b101:output_value = input_5;
		3'b110:output_value = input_6;
		3'b111:output_value = input_7;

		default: output_value = {WIDTH{1'b0}};
	endcase
end

endmodule
