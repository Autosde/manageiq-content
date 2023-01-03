describe "check_pre_retirement Method Validation" do
  let(:user) { FactoryBot.create(:user_with_group) }
  let(:zone) { FactoryBot.create(:zone) }

  context "Infrastructure" do
    let(:ems) { FactoryBot.create(:ems_vmware, :zone => zone) }
    let(:vm) do
      FactoryBot.create(:vm_vmware,
                        :raw_power_state => "poweredOff",
                        :ems_id          => ems.id)
    end
    let(:ws) do
      MiqAeEngine.instantiate("/Infrastructure/VM/Retirement/StateMachines/Methods/CheckPreRetirement?" \
                              "Vm::vm=#{vm.id}#vmware", user)
    end

    it "returns 'ok' for a vm in powered_off state" do
      expect(ws.root['vm'].power_state).to eq("off")
      expect(ws.root['ae_result']).to eq("ok")
    end

    it "errors for a template" do
      vm.update_attribute(:template, true)

      expect(vm.state).to eq("never")
      expect { ws }.to raise_error(MiqAeException::ServiceNotFound)
    end

    it "retries for a vm in powered_on state" do
      vm.update_attribute(:raw_power_state, "poweredOn")

      expect(ws.root['ae_result']).to eq("retry")
      expect(ws.root['vm'].power_state).to eq("on")
    end

    it "returns 'ok' for a vm in unknown state" do
      vm.update_attribute(:raw_power_state, "unknown")

      expect(ws.root['vm'].power_state).to eq("unknown")
      expect(ws.root['ae_result']).to eq("ok")
    end
  end

  context "Cloud" do
    let(:ems) { FactoryBot.create(:ems_google, :zone => zone) }
    let(:vm)  do
      FactoryBot.create(:vm_google,
                         :raw_power_state => "stopping",
                         :ems_id          => ems.id)
    end

    let(:ws) do
      MiqAeEngine.instantiate("/Cloud/VM/Retirement/StateMachines/Methods/CheckPreRetirement?" \
                              "Vm::vm=#{vm.id}#google", user)
    end

    it "returns 'ok' for a instance in powered_off state" do
      expect(ws.root['vm'].power_state).to eq("off")
      expect(ws.root['ae_result']).to eq("ok")
    end

    it "retries for an instance in powered_on state" do
      vm.update_attribute(:raw_power_state, "Running")

      expect(ws.root['ae_result']).to eq("retry")
      expect(ws.root['vm'].power_state).to eq("on")
    end

    it "returns 'ok' for an instance in unknown state" do
      vm.update_attribute(:raw_power_state, "unknown")

      expect(ws.root['vm'].power_state).to eq("unknown")
      expect(ws.root['ae_result']).to eq("ok")
    end

    it "returns 'ok' for an instance with no ems" do
      vm.update_attribute(:ems_id, nil)

      expect(ws.root['vm'].power_state).to eq("off")
      expect(ws.root['ae_result']).to be_nil
    end
  end
end
