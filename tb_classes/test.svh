/******************************************************/
// Description	: This is the top class to test required functionalities in the design
//				  This class is invoked using the UVM_TESTNAME in run.do. Based on the 
//				  test required the stimulus tester is overwritten in this class and calls
//				  the UVM environment class. 
/******************************************************/
class test extends uvm_test;
	`uvm_component_utils(test)
	
	env env_h;
    sdr_sequence seq_h;
	
	function void build_phase(uvm_phase phase);
	  env_h     = env::type_id::create("env_h",this);
	 endfunction :build_phase

   task run_phase(uvm_phase phase);
      seq_h = sdr_sequence::type_id::create("seq_h");
      phase.raise_objection(this);
      seq_h.start(env_h.agent_h.seqr_h);
      phase.drop_objection(this);
   endtask
 
	function new (string name, uvm_component parent);
      super.new(name,parent);
   endfunction : new
   
	 
  endclass
