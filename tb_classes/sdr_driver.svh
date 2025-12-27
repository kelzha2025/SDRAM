// UVM driver: drives Wishbone/SDRAM signals via sdrctrlinterface_bfm
class sdr_driver extends uvm_driver #(sdr_seq_item);
  `uvm_component_utils(sdr_driver)

  virtual sdrctrlinterface_bfm bfm;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual sdrctrlinterface_bfm)::get(this, "", "bfm", bfm)) begin
      `uvm_fatal("NOVIF", "BFM interface not set for sdr_driver")
    end
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      sdr_seq_item req;
      seq_item_port.get_next_item(req);
      if (req.cmd == sdr_seq_item::SDR_WRITE) begin
        drive_write(req.addr, req.burst_len, req.data_q);
      end else begin
        drive_read(req.addr, req.burst_len);
      end
      seq_item_port.item_done();
    end
  endtask

  task drive_write(logic [31:0] addr, logic [7:0] bl, logic [31:0] data_q[$]);
    @(negedge bfm.sys_clk);
    for (int i = 0; i < bl; i++) begin
      bfm.write_done      = 1'b0;
      bfm.wb_stb_i        = 1'b1;
      bfm.wb_cyc_i        = 1'b1;
      bfm.wb_we_i         = 1'b1;
      bfm.wb_sel_i        = 4'b1111;
      bfm.wb_addr_i       = addr[31:2] + i;
      bfm.wb_dat_i        = (i < data_q.size()) ? data_q[i] : $urandom();
      do @(posedge bfm.sys_clk); while (bfm.wb_ack_o == 1'b0);
      @(negedge bfm.sys_clk);
    end
    bfm.write_done      = 1'b1;
    bfm.wb_stb_i        = 1'b0;
    bfm.wb_cyc_i        = 1'b0;
    bfm.wb_we_i         = 1'bx;
    bfm.wb_sel_i        = 4'bxxxx;
    bfm.wb_addr_i       = 'hx;
    bfm.wb_dat_i        = 'hx;
  endtask

  task drive_read(logic [31:0] addr, logic [7:0] bl);
    @(negedge bfm.sys_clk);
    bfm.read_init = 1'b1;
    for (int j = 0; j < bl; j++) begin
      bfm.wb_stb_i  = 1'b1;
      bfm.wb_cyc_i  = 1'b1;
      bfm.wb_we_i   = 1'b0;
      bfm.wb_addr_i = addr[31:2] + j;
      do @(posedge bfm.sys_clk); while (bfm.wb_ack_o == 1'b0 && bfm.FLAG == 1'b0);
      @(negedge bfm.sdram_clk);
    end
    bfm.read_init  = 1'b0;
    bfm.wb_stb_i   = 1'b0;
    bfm.wb_cyc_i   = 1'b0;
    bfm.wb_we_i    = 1'bx;
    bfm.wb_addr_i  = 'hx;
  endtask
endclass
