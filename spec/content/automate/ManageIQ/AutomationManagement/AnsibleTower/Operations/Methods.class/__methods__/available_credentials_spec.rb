require_domain_file

describe ManageIQ::Automate::AutomationManagement::AnsibleTower::Operations::AvailableCredentials do
  let(:ansible_manager) { FactoryBot.create(:embedded_automation_manager_ansible) }
  let(:playbook) do
    FactoryBot.create(:embedded_playbook, :manager => ansible_manager)
  end
  let(:root_object) do
    Spec::Support::MiqAeMockObject.new('service_template' => svc_service_template)
  end
  let(:method_args) do
    { 'credential_type' => credential_type }
  end

  let(:ae_service) do
    Spec::Support::MiqAeMockService.new(root_object).tap do |service|
      current_object = Spec::Support::MiqAeMockObject.new
      current_object.parent = root_object
      service.object = current_object
      service.inputs = method_args
    end
  end
  let(:options) { {:config_info => {:provision => {:playbook_id => playbook.id}}} }
  let(:svc_template) do
    FactoryBot.create(:service_template_ansible_playbook, :options => options)
  end
  let(:svc_service_template) do
    MiqAeMethodService::MiqAeServiceServiceTemplate.find(svc_template.id)
  end
  let(:mach_cred1) do
    FactoryBot.create(:embedded_ansible_machine_credential, :resource => ansible_manager)
  end
  let(:mach_cred2) do
    FactoryBot.create(:embedded_ansible_machine_credential, :resource => ansible_manager)
  end
  let(:net_cred1) do
    FactoryBot.create(:embedded_ansible_network_credential, :resource => ansible_manager)
  end
  let(:net_cred2) do
    FactoryBot.create(:embedded_ansible_network_credential, :resource => ansible_manager)
  end

  shared_examples_for "#having only default value" do
    let(:default_desc_blank) { "<Default>" }
    it "provides only default value if no credentials" do
      described_class.new(ae_service).main

      expect(ae_service["values"]).to eq(nil => default_desc_blank)
      expect(ae_service["default_value"]).to be_nil
    end
  end

  shared_examples_for "#having specific values based on credential type" do
    it "provides only default value if no credentials" do
      described_class.new(ae_service).main

      expect(ae_service["values"].keys).to match_array(valid_ids)
      expect(ae_service["default_value"]).to be_nil
      expect(ae_service["required"]).to be_falsey
      expect(ae_service["sort_by"]).to eq('description')
      expect(ae_service["sort_order"]).to eq('ascending')
      expect(ae_service["data_type"]).to eq('string')
    end
  end

  context "credentials" do
    before do
      mach_cred1
      mach_cred2
      net_cred1
      net_cred2
    end

    context "machine" do
      let(:credential_type) do
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential"
      end
      let(:valid_ids) { [mach_cred1.id, mach_cred2.id, nil] }

      it_behaves_like "#having specific values based on credential type"
    end

    context "network" do
      let(:credential_type) do
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::NetworkCredential"
      end
      let(:valid_ids) { [net_cred1.id, net_cred2.id, nil] }

      it_behaves_like "#having specific values based on credential type"
    end

    context "no service template" do
      let(:ansible_manager) { FactoryBot.create(:embedded_automation_manager_ansible) }
      let(:root_object) do
        Spec::Support::MiqAeMockObject.new
      end
      let(:credential_type) do
        "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential"
      end
      let(:method_args) do
        { 'credential_type' => credential_type, 'embedded_ansible' => true }
      end
      let(:valid_ids) { [mach_cred1.id, mach_cred2.id, nil] }

      it_behaves_like "#having specific values based on credential type"
    end
  end

  context "no credentials" do
    context "machine" do
      let(:credential_type) { nil }

      it_behaves_like "#having only default value"
    end
  end
end
