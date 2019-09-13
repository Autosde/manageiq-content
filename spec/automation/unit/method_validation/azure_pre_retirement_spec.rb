describe "azure_pre_retirement Method Validation" do
  before do
    @user = FactoryBot.create(:user_with_group)
    @zone = FactoryBot.create(:zone)
    @ems  = FactoryBot.create(:ems_azure, :zone => @zone)
    @vm   = FactoryBot.create(:vm_azure,
                               :name => "AZURE",   :raw_power_state => "VM Running",
                               :ems_id => @ems.id, :registered => true)
    @ins  = "/Cloud/VM/Retirement/StateMachines/Methods/PreRetirement"
  end

  it "call suspend for running instances" do
    MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#Azure", @user)
    expect(MiqQueue.exists?(:method_name => 'stop', :instance_id => @vm.id, :role => 'ems_operations')).to be_truthy
  end

  it "does not call suspend for powered off instances" do
    @vm.update(:raw_power_state => 'VM Stopped')
    MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#Azure", @user)
    expect(MiqQueue.exists?(:method_name => 'stop', :instance_id => @vm.id, :role => 'ems_operations')).to be_falsey
  end
end
