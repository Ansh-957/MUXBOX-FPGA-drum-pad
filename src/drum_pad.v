module drum_pad (
    // Inputs
    CLOCK_50,
    KEY,
    SW,
    AUD_ADCDAT,
    GPIO_1,
    
    // Bidirectionals
    AUD_BCLK,
    AUD_ADCLRCK,
    AUD_DACLRCK,
    FPGA_I2C_SDAT,
    
    // Outputs
    AUD_XCK,
    AUD_DACDAT,
    FPGA_I2C_SCLK,
    GPIO_0,
    LEDR,
    HEX0,
    HEX1
);


// PORT DECLARATIONS                                                          
// Inputs
input CLOCK_50;
input [3:0] KEY;
input [9:0] SW;
input AUD_ADCDAT;
input [35:0] GPIO_1;


// Bidirectionals
inout AUD_BCLK;
inout AUD_ADCLRCK;
inout AUD_DACLRCK;
inout FPGA_I2C_SDAT;


// Outputs
output AUD_XCK;
output AUD_DACDAT;
output FPGA_I2C_SCLK;
output [35:0] GPIO_0;
output [9:0] LEDR;
output [6:0] HEX0;  // Display volume ones digit
output [6:0] HEX1;  // Display volume tens digit


// INTERNAL WIRES AND REGISTER DECLARATIONS                         
// Audio Controller Interface
wire audio_in_available;
wire audio_out_allowed;
wire [31:0] left_channel_audio_out;
wire [31:0] right_channel_audio_out;
reg write_audio_out;


// Debounced GPIO signals
wire [35:18] GPIO_1_debounced;


wire waiting_for_save_clear;


// ROM data outputs - 10 drum sounds (16-bit mono)
wire [15:0] retrolaser2_data;
wire [15:0] snareKilla_data;
wire [15:0] retrolaser_data;
wire [15:0] tomFar1_data;
wire [15:0] snareFarm_data;
wire [15:0] snareroot_data;
wire [15:0] kickFare_data;
wire [15:0] openhat_data;
wire [15:0] snare94_data;
wire [15:0] tomFar2_data;
wire [15:0] kickKilla_data;
wire [15:0] hatScath_data;


// LED rotation counter for waiting state
reg [25:0] led_rotate_counter;  // Counter for LED rotation timing
reg [1:0] led_rotate_state;     // Which LED is currently on (0, 1, or 2)


// Metronome
wire [31:0] metronome_data;
wire metronome_beat;
wire metronome_enable;


reg metronome_enable_reg;
reg metronome_button_prev;
wire metronome_button_trigger;


// Volume Control
wire [4:0] volume_level;  // 0-31 (5 bits)
wire volume_mute;


// Debug signals from encoder
wire encoder_clk_raw;
wire encoder_dt_raw;


wire [11:0] trigger_bus = {
    hatScath_trigger,
    kickKilla_trigger,
    tomFar2_trigger,
    snare94_trigger,
    openhat_trigger,
    kickFare_trigger,
    snareroot_trigger,
    snareFarm_trigger,
    tomFar1_trigger,
    retrolaser_trigger,
    snareKilla_trigger,
    retrolaser2_trigger
};


// Event recorder signals
wire [11:0] playback_triggers;
wire recorder_recording;
wire recorder_playing;
wire recorder_has_saved;


// Reset
wire reset;
assign reset = ~KEY[0];


// Playback control for each sound
reg retrolaser2_playing, snareKilla_playing, retrolaser_playing, tomFar1_playing;
reg snareFarm_playing, snareroot_playing, kickFare_playing, openhat_playing;
reg snare94_playing, tomFar2_playing, kickKilla_playing, hatScath_playing;


// Address counters for each sound
reg [12:0] retrolaser2_addr;
reg [14:0] snareKilla_addr;
reg [11:0] retrolaser_addr;
reg [13:0] tomFar1_addr;
reg [13:0] snareFarm_addr;
reg [14:0] snareroot_addr;
reg [13:0] kickFare_addr;
reg [12:0] openhat_addr;
reg [14:0] snare94_addr;
reg [13:0] tomFar2_addr;
reg [13:0] kickKilla_addr;
reg [13:0] hatScath_addr;


// Sample rate control (downsampling to 24kHz)
reg enable;


// Key edge detection - 12 triggers
reg [11:0] key_prev;
wire retrolaser2_trigger;        // GPIO_1[18]
wire snareKilla_trigger;     // GPIO_1[29]
wire retrolaser_trigger;     // GPIO_1[19]
wire tomFar1_trigger;        // GPIO_1[20]
wire snareFarm_trigger;      // GPIO_1[31]
wire snareroot_trigger;      // GPIO_1[21]
wire kickFare_trigger;       // GPIO_1[22]
wire openhat_trigger;        // GPIO_1[33]
wire snare94_trigger;        // GPIO_1[23]
wire tomFar2_trigger;        // GPIO_1[24]
wire kickKilla_trigger;      // GPIO_1[35]
wire hatScath_trigger;       // GPIO_1[25]


// Metronome control
assign metronome_enable = waiting_for_save_clear ? 1'b0 : metronome_enable_reg;
wire [8:0] tempo_setting = 9'd160;  // Fixed at 120 BPM


// Maximum addresses for each sound (depth - 1, since 16-bit mono)
parameter RETROLASER2_MAX = 13'd7575;
parameter SNAREKILLA_MAX = 15'd18227;
parameter RETROLASER_MAX = 12'd2660;
parameter TOMFAR1_MAX = 14'd8940;
parameter SNAREFARM_MAX = 14'd8399;
parameter SNAREROOT_MAX = 15'd30494;
parameter KICKFARE_MAX = 14'd14594;
parameter OPENHAT_MAX = 13'd7832;
parameter SNARE94_MAX = 14'd15332;
parameter TOMFAR2_MAX = 14'd9350;
parameter KICKKILLA_MAX = 14'd13670;
parameter HATSCATH_MAX = 14'd10587;


// LED assignments
assign GPIO_0[0] = waiting_for_save_clear ? (led_rotate_state == 2'd2) : metronome_enable;
assign GPIO_0[2] = waiting_for_save_clear ? (led_rotate_state == 2'd1) : recorder_recording;
assign GPIO_0[4] = waiting_for_save_clear ? (led_rotate_state == 2'd0) : recorder_playing;


assign LEDR[9] = recorder_has_saved;
assign LEDR[0] = GPIO_1[32];
assign LEDR[1] = GPIO_1[34];
assign LEDR[2] = GPIO_1[30];
assign LEDR[3] = GPIO_1[28];
assign LEDR[4] = GPIO_1[26];


// EDGE DETECTION LOGIC
assign retrolaser2_trigger     = ~key_prev[0]  & GPIO_1_debounced[18];
assign snareKilla_trigger  = ~key_prev[1]  & GPIO_1_debounced[29];
assign retrolaser_trigger  = ~key_prev[2]  & GPIO_1_debounced[19];
assign tomFar1_trigger     = ~key_prev[3]  & GPIO_1_debounced[20];
assign snareFarm_trigger   = ~key_prev[4]  & GPIO_1_debounced[31];
assign snareroot_trigger   = ~key_prev[5]  & GPIO_1_debounced[21];
assign kickFare_trigger    = ~key_prev[6]  & GPIO_1_debounced[22];
assign openhat_trigger     = ~key_prev[7]  & GPIO_1_debounced[33];
assign snare94_trigger     = ~key_prev[8]  & GPIO_1_debounced[23];
assign tomFar2_trigger     = ~key_prev[9]  & GPIO_1_debounced[24];
assign kickKilla_trigger   = ~key_prev[10] & GPIO_1_debounced[35];
assign hatScath_trigger    = ~key_prev[11] & GPIO_1_debounced[25];


// Metronome button edge detection (rising edge = button press)
assign metronome_button_trigger = ~metronome_button_prev & GPIO_1_debounced[30];


always @(posedge CLOCK_50) begin
    if (reset) begin
        metronome_button_prev <= 1'b0;
    end else begin
        metronome_button_prev <= GPIO_1_debounced[30];
    end
end


// Metronome toggle control
always @(posedge CLOCK_50) begin
    if (reset) begin
        metronome_enable_reg <= 1'b0;  // Start with metronome OFF
    end else if (metronome_button_trigger) begin
        metronome_enable_reg <= ~metronome_enable_reg;  // Toggle on button press
    end
end


always @(posedge CLOCK_50) begin
    if (reset) begin
        key_prev <= 12'hFFF;
    end else begin
        key_prev[0]  <= GPIO_1_debounced[18];
        key_prev[1]  <= GPIO_1_debounced[29];
        key_prev[2]  <= GPIO_1_debounced[19];
        key_prev[3]  <= GPIO_1_debounced[20];
        key_prev[4]  <= GPIO_1_debounced[31];
        key_prev[5]  <= GPIO_1_debounced[21];
        key_prev[6]  <= GPIO_1_debounced[22];
        key_prev[7]  <= GPIO_1_debounced[33];
        key_prev[8]  <= GPIO_1_debounced[23];
        key_prev[9]  <= GPIO_1_debounced[24];
        key_prev[10] <= GPIO_1_debounced[35];
        key_prev[11] <= GPIO_1_debounced[25];
    end
end


// LED rotation for waiting state (creates loading bar effect)
always @(posedge CLOCK_50) begin
    if (reset || !waiting_for_save_clear) begin
        led_rotate_counter <= 26'b0;
        led_rotate_state <= 2'd0;
    end else begin
        // Rotate every ~0.33 seconds
        if (led_rotate_counter >= 26'd16_666_667) begin
            led_rotate_counter <= 26'b0;
            if (led_rotate_state >= 2'd2)
                led_rotate_state <= 2'd0;
            else
                led_rotate_state <= led_rotate_state + 1'b1;
        end else begin
            led_rotate_counter <= led_rotate_counter + 1'b1;
        end
    end
end


// EVENT RECORDER MODULE
event_recorder recorder_inst (
    .clk(CLOCK_50),
    .reset(reset),
    .record_button(GPIO_1_debounced[28]),   // GPIO_1[28] for record
    .save_button(GPIO_1_debounced[32]),     // GPIO_1[32] for save
    .play_button(GPIO_1_debounced[26]),     // GPIO_1[26] for play/stop
    .clear_button(GPIO_1_debounced[34]),    // GPIO_1[34] for clear
    .metronome_button(GPIO_1_debounced[30]), // GPIO_1[30] for metronome
    .trigger_bus(trigger_bus),
    .playback_triggers(playback_triggers),
    .recording(recorder_recording),
    .playing(recorder_playing),
    .has_saved_recording(recorder_has_saved),
    .waiting_for_save_clear(waiting_for_save_clear)
);


// SAMPLE RATE CONTROL
always @(posedge CLOCK_50) begin
    if (reset) begin
        enable <= 1'b0;
    end else if (audio_out_allowed) begin
        enable <= 1'b1;
    end else begin
        enable <= 1'b0;
    end
end




// LASER2 PLAYBACK
always @(posedge CLOCK_50) begin
    if (reset) begin
        retrolaser2_playing <= 1'b0;
        retrolaser2_addr <= 13'b0;
    end else if (!waiting_for_save_clear && (retrolaser2_trigger || playback_triggers[0])) begin
        retrolaser2_playing <= 1'b1;
        retrolaser2_addr <= 13'b0;
    end else if (audio_out_allowed && retrolaser2_playing && enable) begin
        if (retrolaser2_addr >= RETROLASER2_MAX) begin
            retrolaser2_playing <= 1'b0;
            retrolaser2_addr <= 13'b0;
        end else begin
            retrolaser2_addr <= retrolaser2_addr + 1'b1;
        end
    end
end


// SNAREKILLA PLAYBACK CONTROL
always @(posedge CLOCK_50) begin
    if (reset) begin
        snareKilla_playing <= 1'b0;
        snareKilla_addr <= 15'b0;
    end else if (!waiting_for_save_clear && (snareKilla_trigger || playback_triggers[1])) begin
        snareKilla_playing <= 1'b1;
        snareKilla_addr <= 15'b0;
    end else if (audio_out_allowed && snareKilla_playing && enable) begin
        if (snareKilla_addr >= SNAREKILLA_MAX) begin
            snareKilla_playing <= 1'b0;
            snareKilla_addr <= 15'b0;
        end else begin
            snareKilla_addr <= snareKilla_addr + 1'b1;
        end
    end
end


// RETROLASER PLAYBACK CONTROL
always @(posedge CLOCK_50) begin
    if (reset) begin
        retrolaser_playing <= 1'b0;
        retrolaser_addr <= 12'b0;
    end else if (!waiting_for_save_clear && (retrolaser_trigger || playback_triggers[2])) begin
        retrolaser_playing <= 1'b1;
        retrolaser_addr <= 12'b0;
    end else if (audio_out_allowed && retrolaser_playing && enable) begin
        if (retrolaser_addr >= RETROLASER_MAX) begin
            retrolaser_playing <= 1'b0;
            retrolaser_addr <= 12'b0;
        end else begin
            retrolaser_addr <= retrolaser_addr + 1'b1;
        end
    end
end


// TOMFAR1 PLAYBACK CONTROL
always @(posedge CLOCK_50) begin
    if (reset) begin
        tomFar1_playing <= 1'b0;
        tomFar1_addr <= 14'b0;
    end else if (!waiting_for_save_clear && (tomFar1_trigger || playback_triggers[3])) begin
        tomFar1_playing <= 1'b1;
        tomFar1_addr <= 14'b0;
    end else if (audio_out_allowed && tomFar1_playing && enable) begin
        if (tomFar1_addr >= TOMFAR1_MAX) begin
            tomFar1_playing <= 1'b0;
            tomFar1_addr <= 14'b0;
        end else begin
            tomFar1_addr <= tomFar1_addr + 1'b1;
        end
    end
end


// SNARE FARM PLAYBACK CONTROL
always @(posedge CLOCK_50) begin
    if (reset) begin
        snareFarm_playing <= 1'b0;
        snareFarm_addr <= 14'b0;
    end else if (!waiting_for_save_clear && (snareFarm_trigger || playback_triggers[4])) begin
        snareFarm_playing <= 1'b1;
        snareFarm_addr <= 14'b0;
    end else if (audio_out_allowed && snareFarm_playing && enable) begin
        if (snareFarm_addr >= SNAREFARM_MAX) begin
            snareFarm_playing <= 1'b0;
            snareFarm_addr <= 14'b0;
        end else begin
            snareFarm_addr <= snareFarm_addr + 1'b1;
        end
    end
end


// SNAREROOT PLAYBACK
always @(posedge CLOCK_50) begin
    if (reset) begin
        snareroot_playing <= 1'b0;
        snareroot_addr <= 15'b0;
    end else if (!waiting_for_save_clear && (snareroot_trigger || playback_triggers[5])) begin
        snareroot_playing <= 1'b1;
        snareroot_addr <= 15'b0;
    end else if (audio_out_allowed && snareroot_playing && enable) begin
        if (snareroot_addr >= SNAREROOT_MAX) begin
            snareroot_playing <= 1'b0;
            snareroot_addr <= 15'b0;
        end else begin
            snareroot_addr <= snareroot_addr + 1'b1;
        end
    end
end


// KICK FAR PLAYBACK
always @(posedge CLOCK_50) begin
    if (reset) begin
        kickFare_playing <= 1'b0;
        kickFare_addr <= 14'b0;
    end else if (!waiting_for_save_clear && (kickFare_trigger || playback_triggers[6])) begin
        kickFare_playing <= 1'b1;
        kickFare_addr <= 14'b0;
    end else if (audio_out_allowed && kickFare_playing && enable) begin
        if (kickFare_addr >= KICKFARE_MAX) begin
            kickFare_playing <= 1'b0;
            kickFare_addr <= 14'b0;
        end else begin
            kickFare_addr <= kickFare_addr + 1'b1;
        end
    end
end


// OPENHAT PLAYBACK
always @(posedge CLOCK_50) begin
    if (reset) begin
        openhat_playing <= 1'b0;
        openhat_addr <= 13'b0;
    end else if (!waiting_for_save_clear && (openhat_trigger || playback_triggers[7])) begin
        openhat_playing <= 1'b1;
        openhat_addr <= 13'b0;
    end else if (audio_out_allowed && openhat_playing && enable) begin
        if (openhat_addr >= OPENHAT_MAX) begin
            openhat_playing <= 1'b0;
            openhat_addr <= 13'b0;
        end else begin
            openhat_addr <= openhat_addr + 1'b1;
        end
    end
end


// SNARE 94 PLAYBACK
always @(posedge CLOCK_50) begin
    if (reset) begin
        snare94_playing <= 1'b0;
        snare94_addr <= 14'b0;
    end else if (!waiting_for_save_clear && (snare94_trigger || playback_triggers[8])) begin
        snare94_playing <= 1'b1;
        snare94_addr <= 14'b0;
    end else if (audio_out_allowed && snare94_playing && enable) begin
        if (snare94_addr >= SNARE94_MAX) begin
            snare94_playing <= 1'b0;
            snare94_addr <= 14'b0;
        end else begin
            snare94_addr <= snare94_addr + 1'b1;
        end
    end
end


// TOMFAR PLAYBACK
always @(posedge CLOCK_50) begin
    if (reset) begin
        tomFar2_playing <= 1'b0;
        tomFar2_addr <= 14'b0;
    end else if (!waiting_for_save_clear && (tomFar2_trigger || playback_triggers[9])) begin
        tomFar2_playing <= 1'b1;
        tomFar2_addr <= 14'b0;
    end else if (audio_out_allowed && tomFar2_playing && enable) begin
        if (tomFar2_addr >= TOMFAR2_MAX) begin
            tomFar2_playing <= 1'b0;
            tomFar2_addr <= 14'b0;
        end else begin
            tomFar2_addr <= tomFar2_addr + 1'b1;
        end
    end
end


// KICKKILLA PLAYBACK
always @(posedge CLOCK_50) begin
    if (reset) begin
        kickKilla_playing <= 1'b0;
        kickKilla_addr <= 14'b0;
    end else if (!waiting_for_save_clear && (kickKilla_trigger || playback_triggers[10])) begin
        kickKilla_playing <= 1'b1;
        kickKilla_addr <= 14'b0;
    end else if (audio_out_allowed && kickKilla_playing && enable) begin
        if (kickKilla_addr >= KICKKILLA_MAX) begin
            kickKilla_playing <= 1'b0;
            kickKilla_addr <= 14'b0;
        end else begin
            kickKilla_addr <= kickKilla_addr + 1'b1;
        end
    end
end


// HATSCATH PLAYBACK
always @(posedge CLOCK_50) begin
    if (reset) begin
        hatScath_playing <= 1'b0;
        hatScath_addr <= 14'b0;
    end else if (!waiting_for_save_clear && (hatScath_trigger || playback_triggers[11])) begin
        hatScath_playing <= 1'b1;
        hatScath_addr <= 14'b0;
    end else if (audio_out_allowed && hatScath_playing && enable) begin
        if (hatScath_addr >= HATSCATH_MAX) begin
            hatScath_playing <= 1'b0;
            hatScath_addr <= 14'b0;
        end else begin
            hatScath_addr <= hatScath_addr + 1'b1;
        end
    end
end


// AUDIO MIXING LOGIC
// 16-bit mono samples - directly use ROM data
wire signed [15:0] retrolaser2_sample = retrolaser2_playing ? retrolaser2_data : 16'sd0;
wire signed [15:0] snareKilla_sample = snareKilla_playing ? snareKilla_data : 16'sd0;
wire signed [15:0] retrolaser_sample = retrolaser_playing ? retrolaser_data : 16'sd0;
wire signed [15:0] tomFar1_sample = tomFar1_playing ? tomFar1_data : 16'sd0;
wire signed [15:0] snareFarm_sample = snareFarm_playing ? snareFarm_data : 16'sd0;
wire signed [15:0] snareroot_sample = snareroot_playing ? snareroot_data : 16'sd0;
wire signed [15:0] kickFare_sample = kickFare_playing ? kickFare_data : 16'sd0;
wire signed [15:0] openhat_sample = openhat_playing ? openhat_data : 16'sd0;
wire signed [15:0] snare94_sample = snare94_playing ? snare94_data : 16'sd0;
wire signed [15:0] tomFar2_sample = tomFar2_playing ? tomFar2_data : 16'sd0;
wire signed [15:0] kickKilla_sample = kickKilla_playing ? kickKilla_data : 16'sd0;
wire signed [15:0] hatScath_sample = hatScath_playing ? hatScath_data : 16'sd0;


wire signed [15:0] metronome_sample_full = metronome_data[31:16];
wire signed [15:0] metronome_sample = metronome_sample_full >>> 4;


// Mix all 10 drum samples together in stages
// Need wider bit width to prevent overflow
wire signed [19:0] drum_mix_part1 = retrolaser2_sample + snareKilla_sample + retrolaser_sample + tomFar1_sample;
wire signed [19:0] drum_mix_part2 = snareFarm_sample + snareroot_sample + kickFare_sample + openhat_sample;
wire signed [19:0] drum_mix_part3 = snare94_sample + tomFar2_sample + kickKilla_sample + hatScath_sample;


// Combine all drum mixes
wire signed [21:0] drum_mix_total = drum_mix_part1 + drum_mix_part2 + drum_mix_part3;


// Add metronome if enabled
wire signed [21:0] total_mix = metronome_enable ? 
    (drum_mix_total + metronome_sample) : drum_mix_total;


wire signed [18:0] mixed_sample_pre_volume = total_mix >>> 2; // Divide by 4


// VOLUME CONTROL APPLICATION
// Apply volume scaling: multiply by volume_level (0-31) and shift right by 5
// This gives us a range from 0% (muted) to 100% volume
wire signed [23:0] volume_multiplied = mixed_sample_pre_volume * $signed({1'b0, volume_level});
wire signed [15:0] mixed_sample_with_volume = volume_multiplied >>> 5; // Divide by 32


wire signed [15:0] clamped_audio;
wire signed [16:0] extended_sample = mixed_sample_with_volume; // Sign-extend for comparison


assign clamped_audio = (extended_sample > 17'sd28000) ? 16'sd28000 :      // Soft limit at ~85% max
                       (extended_sample < -17'sd28000) ? -16'sd28000 :
                       mixed_sample_with_volume;


// Apply mute - also mute when waiting for save/clear decision
wire signed [15:0] final_audio = (volume_mute || waiting_for_save_clear) ? 16'sd0 : clamped_audio;


// Output audio to both channels
assign left_channel_audio_out = {final_audio, 16'b0};
assign right_channel_audio_out = {final_audio, 16'b0};


// WRITE CONTROL
always @(posedge CLOCK_50) begin
    if (reset) begin
        write_audio_out <= 1'b0;
    end else if (audio_out_allowed) begin
        write_audio_out <= 1'b1;
    end else begin
        write_audio_out <= 1'b0;
    end
end


// VOLUME DISPLAY
wire [3:0] volume_ones = volume_level % 10;
wire [3:0] volume_tens = volume_level / 10;


seven_seg_decoder ones_digit (
    .digit(volume_ones),
    .segments(HEX0)
);


seven_seg_decoder tens_digit (
    .digit(volume_tens),
    .segments(HEX1)
);


// ROTARY ENCODER MODULE CALL
rotary_encoder volume_control (
    .clk(CLOCK_50),
    .reset(reset),
    .encoder_clk(GPIO_1[0]),   // CLK pin
    .encoder_dt(GPIO_1[2]),    // DT pin
    .encoder_sw(GPIO_1[4]),    // SW pin (button)
    .volume(volume_level),
    .mute(volume_mute),
    .clk_raw(encoder_clk_raw),  // Debug output
    .dt_raw(encoder_dt_raw)     // Debug output
);


// METRONOME MODULE CALL
metronome metronome_inst (
    .CLOCK_50(CLOCK_50),
    .reset(reset),
    .enable(metronome_enable),
    .tempo_setting(tempo_setting),
    .audio_out_allowed(audio_out_allowed),
    .sample_enable(enable),
    .metronome_out(metronome_data),
    .beat_indicator(metronome_beat)
);


// DEBOUNCE MODULE CALLS
debounce #(.DELAY(1_000_000)) debounce_18 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[18]), .button_out(GPIO_1_debounced[18])
);


debounce #(.DELAY(1_000_000)) debounce_28 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[28]), .button_out(GPIO_1_debounced[28])
);


debounce #(.DELAY(1_000_000)) debounce_19 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[19]), .button_out(GPIO_1_debounced[19])
);


debounce #(.DELAY(1_000_000)) debounce_20 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[20]), .button_out(GPIO_1_debounced[20])
);


debounce #(.DELAY(1_000_000)) debounce_21 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[21]), .button_out(GPIO_1_debounced[21])
);


debounce #(.DELAY(1_000_000)) debounce_22 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[22]), .button_out(GPIO_1_debounced[22])
);


debounce #(.DELAY(1_000_000)) debounce_23 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[23]), .button_out(GPIO_1_debounced[23])
);


debounce #(.DELAY(1_000_000)) debounce_24 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[24]), .button_out(GPIO_1_debounced[24])
);


debounce #(.DELAY(1_000_000)) debounce_25 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[25]), .button_out(GPIO_1_debounced[25])
);


debounce #(.DELAY(1_000_000)) debounce_26 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[26]), .button_out(GPIO_1_debounced[26])
);


debounce #(.DELAY(1_000_000)) debounce_29 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[29]), .button_out(GPIO_1_debounced[29])
);


debounce #(.DELAY(1_000_000)) debounce_30 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[30]), .button_out(GPIO_1_debounced[30])
);


debounce #(.DELAY(1_000_000)) debounce_31 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[31]), .button_out(GPIO_1_debounced[31])
);


debounce #(.DELAY(1_000_000)) debounce_32 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[32]), .button_out(GPIO_1_debounced[32])
);


debounce #(.DELAY(1_000_000)) debounce_33 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[33]), .button_out(GPIO_1_debounced[33])
);


debounce #(.DELAY(1_000_000)) debounce_34 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[34]), .button_out(GPIO_1_debounced[34])
);


debounce #(.DELAY(1_000_000)) debounce_35 (
    .clk(CLOCK_50), .reset(reset),
    .button_in(GPIO_1[35]), .button_out(GPIO_1_debounced[35])
);


// ROM INSTANTIATIONS
snareKilla_rom snareKilla_rom_inst (
    .address(snareKilla_addr[14:0]),
    .clock(CLOCK_50),
    .q(snareKilla_data)
);


retrolaser_rom retrolaser_rom_inst (
    .address(retrolaser_addr[11:0]),
    .clock(CLOCK_50),
    .q(retrolaser_data)
);


retrolaser2_rom retrolaser2_rom_inst (
    .address(retrolaser2_addr[12:0]),
    .clock(CLOCK_50),
    .q(retrolaser2_data)
);


snareroot_rom snareroot_rom_inst (
    .address(snareroot_addr[14:0]),
    .clock(CLOCK_50),
    .q(snareroot_data)
);


tomFar1_rom tomFar1_rom_inst (
    .address(tomFar1_addr[13:0]),
    .clock(CLOCK_50),
    .q(tomFar1_data)
);


snareFarm_rom snareFarm_rom_inst (
    .address(snareFarm_addr[13:0]),
    .clock(CLOCK_50),
    .q(snareFarm_data)
);


kickFare_rom kickFare_rom_inst (
    .address(kickFare_addr[13:0]),
    .clock(CLOCK_50),
    .q(kickFare_data)
);


openhat_rom openhat_rom_inst (
    .address(openhat_addr[12:0]),
    .clock(CLOCK_50),
    .q(openhat_data)
);


snare94_rom snare94_rom_inst (
    .address(snare94_addr[13:0]),
    .clock(CLOCK_50),
    .q(snare94_data)
);


tomFar2_rom tomFar2_rom_inst (
    .address(tomFar2_addr[13:0]),
    .clock(CLOCK_50),
    .q(tomFar2_data)
);


kickKilla_rom kickKilla_rom_inst (
    .address(kickKilla_addr[13:0]),
    .clock(CLOCK_50),
    .q(kickKilla_data)
);


hatScath_rom hatScath_rom_inst (
    .address(hatScath_addr[13:0]),
    .clock(CLOCK_50),
    .q(hatScath_data)
);


// AUDIO CONTROLLER
Audio_Controller Audio_Controller (
    .CLOCK_50(CLOCK_50),
    .reset(reset),
    .clear_audio_in_memory(),
    .read_audio_in(),
    .clear_audio_out_memory(),
    .left_channel_audio_out(left_channel_audio_out),
    .right_channel_audio_out(right_channel_audio_out),
    .write_audio_out(write_audio_out),
    .AUD_ADCDAT(AUD_ADCDAT),
    .AUD_BCLK(AUD_BCLK),
    .AUD_ADCLRCK(AUD_ADCLRCK),
    .AUD_DACLRCK(AUD_DACLRCK),
    .audio_in_available(audio_in_available),
    .left_channel_audio_in(),
    .right_channel_audio_in(),
    .audio_out_allowed(audio_out_allowed),
    .AUD_XCK(AUD_XCK),
    .AUD_DACDAT(AUD_DACDAT)
);


// AUDIO CODEC CONFIG
avconf #(.USE_MIC_INPUT(1)) avc (
    .FPGA_I2C_SCLK(FPGA_I2C_SCLK),
    .FPGA_I2C_SDAT(FPGA_I2C_SDAT),
    .CLOCK_50(CLOCK_50),
    .reset(reset)
);


endmodule


// SEVEN SEGMENT DECODER MODULE
module seven_seg_decoder (
    input [3:0] digit,
    output reg [6:0] segments
);


always @(*) begin
    case (digit)
        4'd0: segments = 7'b1000000; // 0
        4'd1: segments = 7'b1111001; // 1
        4'd2: segments = 7'b0100100; // 2
        4'd3: segments = 7'b0110000; // 3
        4'd4: segments = 7'b0011001; // 4
        4'd5: segments = 7'b0010010; // 5
        4'd6: segments = 7'b0000010; // 6
        4'd7: segments = 7'b1111000; // 7
        4'd8: segments = 7'b0000000; // 8
        4'd9: segments = 7'b0010000; // 9
        default: segments = 7'b1111111; // blank
    endcase
end


endmodule