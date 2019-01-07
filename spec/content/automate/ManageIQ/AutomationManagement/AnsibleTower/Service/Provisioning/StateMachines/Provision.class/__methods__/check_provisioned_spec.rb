require_domain_file

describe ManageIQ::Automate::AutomationManagement::AnsibleTower::Service::Provisioning::StateMachines::Provision::CheckProvisioned do
  let(:admin) { FactoryGirl.create(:user_admin) }
  let(:request) { FactoryGirl.create(:service_template_provision_request, :requester => admin) }
  let(:service_ansible_tower) { FactoryGirl.create(:service_ansible_tower) }
  let(:task) { FactoryGirl.create(:service_template_provision_task, :destination => service_ansible_tower, :miq_request => request) }
  let(:svc_task) { MiqAeMethodService::MiqAeServiceServiceTemplateProvisionTask.find(task.id) }
  let(:root_object) { Spec::Support::MiqAeMockObject.new('service_template_provision_task' => svc_task) }
  let(:ae_service) { Spec::Support::MiqAeMockService.new(root_object) }
  let(:job_class) { MiqAeMethodService::MiqAeServiceManageIQ_Providers_AnsibleTower_AutomationManager_Job }
  let(:job) { FactoryGirl.create(:ansible_tower_job) }
  let(:workflow_job_class) { MiqAeMethodService::MiqAeServiceManageIQ_Providers_AnsibleTower_AutomationManager_WorkflowJob }
  let(:workflow_job) { FactoryBot.create(:ansible_tower_workflow_job) }
  let(:ok_status) { %w(create_complete ok) }
  let(:running_status) { %w(running ok) }
  let(:bad_status) { %w(create_failed bad) }

  describe 'check provision status' do
    before { allow_any_instance_of(ServiceAnsibleTower).to receive(:job).and_return(job) }

    context 'ansible tower job completed' do
      before { allow_any_instance_of(job_class).to receive(:normalized_live_status).and_return(ok_status) }
      it "refreshes the job status" do
        expect(job).to receive(:refresh_ems)
        described_class.new(ae_service).main
        expect(ae_service.root['ae_result']).to eq('ok')
      end
    end

    context 'ansible tower job is running' do
      before { allow_any_instance_of(job_class).to receive(:normalized_live_status).and_return(running_status) }
      it "retries the step" do
        described_class.new(ae_service).main
        expect(ae_service.root['ae_result']).to eq('retry')
      end
    end

    context 'ansible tower job failed' do
      before { allow_any_instance_of(job_class).to receive(:normalized_live_status).and_return(bad_status) }
      it "signals error" do
        expect(job).to receive(:refresh_ems)
        expect(job).to receive(:raw_stdout)
        described_class.new(ae_service).main
        expect(ae_service.root['ae_result']).to eq('error')
        expect(ae_service.root['ae_reason']).to eq('bad')
      end
    end

    context 'ansible tower workflow job failed' do
      before do
        allow_any_instance_of(ServiceAnsibleTower).to receive(:job).and_return(workflow_job)
        allow_any_instance_of(workflow_job_class).to receive(:normalized_live_status).and_return(bad_status)
      end

      it "signals error" do
        expect(workflow_job).to receive(:refresh_ems)
        expect(workflow_job).not_to receive(:raw_stdout)
        described_class.new(ae_service).main
        expect(ae_service.root['ae_result']).to eq('error')
        expect(ae_service.root['ae_reason']).to eq('bad')
      end
    end
  end
end
