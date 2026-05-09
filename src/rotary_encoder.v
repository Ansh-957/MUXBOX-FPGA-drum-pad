module rotary_encoder (
    input wire clk,
    input wire reset,
    input wire encoder_clk,    // CLK pin from KY-040
    input wire encoder_dt,     // DT pin from KY-040
    input wire encoder_sw,     // SW pin from KY-040 (not used)
    output reg [4:0] volume,   // 0-31 volume level (5 bits)
    output reg mute,           // Not used, kept for compatibility
    output wire clk_raw,       // Debug: raw CLK signal
    output wire dt_raw         // Debug: raw DT signal
);


// Output raw signals for debugging
assign clk_raw = encoder_clk;
assign dt_raw = encoder_dt;


// 3-stage synchronizer for metastability prevention
reg [2:0] clk_sync;
reg [2:0] dt_sync;


// Debounce counters
reg [11:0] clk_debounce_count;
reg [11:0] dt_debounce_count;
reg clk_stable;
reg dt_stable;


// Previous stable state
reg clk_prev;
reg dt_prev;


// Detect clean rising edge on CLK
wire clk_rising_edge = (clk_stable && !clk_prev);


/***************************************************************************** 
 * Input Synchronization
 *****************************************************************************/ 
always @(posedge clk) begin
    if (reset) begin
        clk_sync <= 3'b111;
        dt_sync <= 3'b111;
    end else begin
        clk_sync <= {clk_sync[1:0], encoder_clk};
        dt_sync <= {dt_sync[1:0], encoder_dt};
    end
end


/***************************************************************************** 
 * Debouncing - require signal stability for ~81.9μs (4096 cycles @ 50MHz)
 *****************************************************************************/ 
always @(posedge clk) begin
    if (reset) begin
        clk_stable <= 1'b1;
        clk_debounce_count <= 12'd0;
    end else begin
        if (clk_sync[2] == clk_stable) begin
            clk_debounce_count <= 12'd0;
        end else if (clk_debounce_count == 12'd4095) begin
            clk_stable <= clk_sync[2];
            clk_debounce_count <= 12'd0;
        end else begin
            clk_debounce_count <= clk_debounce_count + 1'b1;
        end
    end
end


always @(posedge clk) begin
    if (reset) begin
        dt_stable <= 1'b1;
        dt_debounce_count <= 12'd0;
    end else begin
        if (dt_sync[2] == dt_stable) begin
            dt_debounce_count <= 12'd0;
        end else if (dt_debounce_count == 12'd4095) begin
            dt_stable <= dt_sync[2];
            dt_debounce_count <= 12'd0;
        end else begin
            dt_debounce_count <= dt_debounce_count + 1'b1;
        end
    end
end


/***************************************************************************** 
 * Volume Control - Only change on clean CLK rising edge
 *****************************************************************************/ 
always @(posedge clk) begin
    if (reset) begin
        volume <= 5'd10;        // Start at volume 10
        clk_prev <= 1'b1;
        dt_prev <= 1'b1;
        mute <= 1'b0;
    end else begin
        clk_prev <= clk_stable;
        dt_prev <= dt_stable;
        
        // Only act on rising edge of CLK
        if (clk_rising_edge) begin
            // Check DT state to determine direction
            if (dt_stable == 1'b0) begin
                // Clockwise - volume up
                if (volume < 5'd31)
                    volume <= volume + 1'b1;
            end else begin
                // Counter-clockwise - volume down  
                if (volume > 5'd0)
                    volume <= volume - 1'b1;
            end
        end
    end
end


endmodule