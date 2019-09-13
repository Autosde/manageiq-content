require_domain_file

describe ManageIQ::Automate::Cloud::Orchestration::Provisioning::StateMachines::CheckProvisioned do
  let(:deploy_result)           { "deploy result" }
  let(:deploy_reason)           { "deploy reason" }
  let(:failure_msg)             { "failure message" }
  let(:long_failure_msg)        { "t" * 300 }
  let(:request)                 { FactoryBot.create(:service_template_provision_request, :requester => user) }
  let(:service_orchestration)   { FactoryBot.create(:service_orchestration, :orchestration_manager => ems_amazon) }
  let(:user)                    { FactoryBot.create(:user_with_group) }

  let(:ems_amazon) do
    ems = FactoryBot.create(:ems_amazon, :last_refresh_date => Time.now.getlocal - 100)
    ems.authentications << FactoryBot.create(:authentication, :status => "Valid")
    ems
  end

  let(:miq_request_task) do
    FactoryBot.create(:miq_request_task,
                       :destination => service_orchestration,
                       :miq_request => request)
  end

  let(:amazon_stack) do
    FactoryBot.create(:orchestration_stack_amazon)
  end

  let(:svc_model_orchestration_manager) do
    MiqAeMethodService::MiqAeServiceExtManagementSystem.find(ems_amazon.id)
  end

  let(:svc_model_amazon_stack) do
    MiqAeMethodService::MiqAeServiceOrchestrationStack.find(amazon_stack.id)
  end

  let(:svc_model_service) do
    MiqAeMethodService::MiqAeServiceService.find(service_orchestration.id)
  end

  let(:svc_model_miq_request_task) do
    MiqAeMethodService::MiqAeServiceMiqRequestTask.find(miq_request_task.id)
  end

  let(:root_hash) do
    { 'service_template' => MiqAeMethodService::MiqAeServiceService.find(service_orchestration.id) }
  end

  let(:root_object) do
    obj = Spec::Support::MiqAeMockObject.new(root_hash)
    obj["service_template_provision_task"] = svc_model_miq_request_task
    obj
  end

  let(:ae_service) do
    Spec::Support::MiqAeMockService.new(root_object).tap do |service|
      current_object = Spec::Support::MiqAeMockObject.new
      current_object.parent = root_object
      service.object = current_object
    end
  end

  before do
    allow(svc_model_miq_request_task).to receive(:destination).and_return(svc_model_service)
  end

  it "waits for the deployment to complete" do
    allow(svc_model_service).to receive(:orchestration_stack_status) { ['CREATING', nil] }
    described_class.new(ae_service).main
    expect(ae_service.root['ae_result']).to eq('retry')
  end

  it "catches the error during stack deployment" do
    allow(svc_model_service).to receive(:orchestration_stack_status).and_return(['CREATE_FAILED', failure_msg])
    described_class.new(ae_service).main
    expect(ae_service.root['ae_result']).to eq('error')
    expect(ae_service.root['ae_reason']).to eq(failure_msg)
    expect(request.reload.message).to eq(failure_msg)
  end

  it "truncates the error message that exceeds 255 characters" do
    allow(svc_model_service).to receive(:orchestration_stack_status).and_return(['CREATE_FAILED', long_failure_msg])
    described_class.new(ae_service).main
    expect(ae_service.root['ae_result']).to eq('error')
    expect(ae_service.root['ae_reason']).to eq(long_failure_msg)
    expect(request.reload.message).to eq('t' * 252 + '...')
  end

  it "considers rollback as provision error" do
    allow(svc_model_service)
      .to receive(:orchestration_stack_status) { ['ROLLBACK_COMPLETE', 'Stack was rolled back'] }
    described_class.new(ae_service).main
    expect(ae_service.root['ae_result']).to eq('error')
    expect(ae_service.root['ae_reason']).to eq('Stack was rolled back')
  end

  context "refresh" do
    before do
      allow(svc_model_service).to receive(:orchestration_stack).and_return(svc_model_amazon_stack)
    end

    it "refreshes the provider and waits for it to complete" do
      allow(svc_model_service).to receive(:orchestration_manager).and_return(svc_model_orchestration_manager)
      allow(svc_model_service)
        .to receive(:orchestration_stack_status) { ['CREATE_COMPLETE', nil] }
      expect(MiqAeMethodService::MiqAeServiceOrchestrationStack).to(
        receive(:refresh).with(svc_model_orchestration_manager.id, amazon_stack.ems_ref)
      )
      described_class.new(ae_service).main
      expect(ae_service.root['ae_result']).to eq('retry')
    end

    it "waits the refresh to complete" do
      ae_service.set_state_var('provider_last_refresh', true)
      amazon_stack.status = "CREATE_IN_PROGRESS"
      amazon_stack.save
      described_class.new(ae_service).main
      expect(ae_service.root['ae_result']).to eq("retry")
    end

    it "does not need to wait for refresh completes if the stack has been removed from provider" do
      ae_service.set_state_var('provider_last_refresh', true)
      ae_service.set_state_var('deploy_result', 'error')
      allow(svc_model_service)
        .to receive(:orchestration_stack_status) { ['check_status_failed', 'stack does not exist'] }
      amazon_stack.update(:ems_ref => nil)
      described_class.new(ae_service).main
      expect(ae_service.root['ae_result']).to eq('error')
    end

    it "completes check_provisioned step when refresh is done" do
      ae_service.set_state_var('provider_last_refresh', true)
      ae_service.set_state_var('deploy_result', deploy_result)
      ae_service.set_state_var('deploy_reason', deploy_reason)
      amazon_stack.status = "success"
      amazon_stack.save
      described_class.new(ae_service).main
      expect(ae_service.root['ae_result']).to eq(deploy_result)
    end
  end

  context "exceptions" do
    context "with nil service" do
      let(:root_hash) { {} }
      let(:svc_model_service) { nil }

      it "raises the service is nil exception" do
        expect { described_class.new(ae_service).main }.to raise_error('Service is nil')
      end
    end
  end
end
