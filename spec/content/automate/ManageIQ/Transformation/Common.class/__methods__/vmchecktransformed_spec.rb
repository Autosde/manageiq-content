require_domain_file
require File.join(ManageIQ::Content::Engine.root, 'content/automate/ManageIQ/Transformation/Common.class/__methods__/utils.rb')

describe ManageIQ::Automate::Transformation::Common::VMCheckTransformed do
  let(:user) { FactoryGirl.create(:user_with_email_and_group) }
  let(:group) { FactoryGirl.create(:miq_group) }
  let(:task) { FactoryGirl.create(:service_template_transformation_plan_task) }

  let(:svc_model_user) { MiqAeMethodService::MiqAeServiceUser.find(user.id) }
  let(:svc_model_group) { MiqAeMethodService::MiqAeServiceMiqGroup.find(group.id) }
  let(:svc_model_task) { MiqAeMethodService::MiqAeServiceServiceTemplateTransformationPlanTask.find(task.id) }

  let(:root) do
    Spec::Support::MiqAeMockObject.new(
      'current'             => current_object,
      'user'                => svc_model_user,
      'state_machine_phase' => 'transformation'
    )
  end

  let(:current_object) { Spec::Support::MiqAeMockObject.new }
  let(:ae_service) do
    Spec::Support::MiqAeMockService.new(root).tap do |service|
      current_object = Spec::Support::MiqAeMockObject.new
      current_object.parent = root
      service.object = current_object
    end
  end

  before do
    allow(ManageIQ::Automate::Transformation::Common::Utils).to receive(:task).and_return(svc_model_task)
  end

  describe "#main" do
    context "virtv2v has not started conversion" do
      let(:virtv2v_disks) do
        [
          { :path => '[datastore] test_vm/test_vm.vmdk', :size => 1_234_567, :percent => 0, :weight => 25 },
          { :path => '[datastore] test_vm/test_vm-2.vmdk', :size => 3_703_701, :percent => 0, :weight => 75 }
        ]
      end

      it "returns a message stating conversion has not started" do
        svc_model_task[:options][:virtv2v_disks] = virtv2v_disks
        allow(svc_model_task).to receive(:get_conversion_state).and_return(true)
        allow(svc_model_task).to receive(:get_option).with(:virtv2v_status).and_return('active')
        described_class.new(ae_service).main
        expect(ae_service.get_state_var(:ae_state_progress)).to eq('message' => 'Disks transformation is initializing.', 'percent' => 1.0)
        expect(ae_service.root['ae_result']).to eq('retry')
      end
    end

    context "conversion is still running" do
      let(:virtv2v_disks) do
        [
          { :path => '[datastore] test_vm/test_vm.vmdk', :size => 1_234_567, :percent => 100, :weight => 25 },
          { :path => '[datastore] test_vm/test_vm-2.vmdk', :size => 3_703_701, :percent => 25, :weight => 75 }
        ]
      end

      it "returns a message stating conversion has not started" do
        svc_model_task[:options][:virtv2v_disks] = virtv2v_disks
        allow(svc_model_task).to receive(:get_conversion_state).and_return(true)
        allow(svc_model_task).to receive(:get_option).with(:virtv2v_status).and_return('active')
        described_class.new(ae_service).main
        expect(ae_service.get_state_var(:ae_state_progress)).to eq('message' => 'Converting disk 2 / 2 [43.75%].', 'percent' => 43.75)
        expect(ae_service.root['ae_result']).to eq('retry')
      end
    end

    context "conversion has failed" do
      it "raises with a message stating conversion has failed" do
        ae_service.root['ae_state_retries'] = 2
        allow(svc_model_task).to receive(:get_conversion_state).and_return(true)
        allow(svc_model_task).to receive(:get_option).with(:virtv2v_status).and_return('failed')
        errormsg = 'Disks transformation failed.'
        expect { described_class.new(ae_service).main }.to raise_error(errormsg)
        expect(ae_service.get_state_var(:ae_state_progress)).to eq('message' => errormsg)
      end
    end

    context "conversion has successfuly finished" do
      it "returns a message stating conversion succeeded" do
        allow(svc_model_task).to receive(:get_conversion_state).and_return(true)
        allow(svc_model_task).to receive(:get_option).with(:virtv2v_status).and_return('succeeded')
        described_class.new(ae_service).main
        expect(ae_service.get_state_var(:ae_state_progress)).to eq('message' => 'Disks transformation succeeded.', 'percent' => 100)
      end
    end

    context "get_conversion_state fails" do
      it "sets retry if ae_state_retries is less than or equal to 1" do
        errormsg = 'Unexpected error'
        allow(svc_model_task).to receive(:get_conversion_state).and_raise(errormsg)
        ae_service.root['ae_state_retries'] = 1
        described_class.new(ae_service).main
        expect(ae_service.root['ae_result']).to eq('retry')
      end

      it "raises if ae_state_retries is greater than 2" do
        errormsg = 'Unexpected error'
        allow(svc_model_task).to receive(:get_conversion_state).and_raise(errormsg)
        ae_service.root['ae_state_retries'] = 2
        expect { described_class.new(ae_service).main }.to raise_error(errormsg)
        expect(ae_service.get_state_var(:ae_state_progress)).to eq('message' => errormsg)
      end
    end
  end
end
