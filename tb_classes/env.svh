/******************************************************/
//				  Manasa Gurrala
//				  Naveen Yalla
// Description	: This creates the environment for the test. It invokes all the classes required
// 				  It has the stimulus class sending the commands and test cases to be tested to 
//				  the DUT. Coverage and scoreboard are monitors working in DUV to meet its own fuctionality.  
/******************************************************/
class env extends uvm_env;
   `uvm_component_utils(env);

   sdr_agent     agent_h;
   coverage      coverage_h;
   scoreboard    scoreboard_h;
   cov_adapter   cov_adpt_h;

   function void build_phase(uvm_phase phase);
      agent_h      = sdr_agent::type_id::create("agent_h", this);
      coverage_h   = coverage::type_id::create("coverage_h", this);
      scoreboard_h = scoreboard::type_id::create("scoreboard_h", this);
      cov_adpt_h   = cov_adapter::type_id::create("cov_adpt_h", this);
   endfunction : build_phase

   function void connect_phase(uvm_phase phase);
      agent_h.ap.connect(scoreboard_h.analysis_export);
      agent_h.ap.connect(cov_adpt_h.analysis_export);
   endfunction : connect_phase

   function new (string name, uvm_component parent);
      super.new(name,parent);
   endfunction : new

endclass
   
   
   
