require "rails_helper"

describe EstablishClaim do
  before do
    Timecop.freeze(Time.utc(2015, 1, 1, 12, 0, 0))
  end

  let(:appeal) do
    Generators::Appeal.build(
      vacols_record: vacols_record,
      dispatched_to_station: dispatched_to_station,
      vamc: special_issues[:vamc],
      radiation: special_issues[:radiation]
    )
  end

  let(:establish_claim) do
    EstablishClaim.new(
      appeal: appeal,
      aasm_state: aasm_state,
      completion_status: completion_status,
      claim_establishment: claim_establishment,
      outgoing_reference_id: outgoing_reference_id,
      user: assigned_user
    )
  end

  let(:claim_establishment) do
    ClaimEstablishment.new(
      ep_code: ep_code,
      email_ro_id: email_ro_id,
      email_recipient: email_recipient
    )
  end

  let(:vacols_record) { :remand_decided }
  let(:dispatched_to_station) { "RO98" }
  let(:aasm_state) { :unassigned }
  let(:completion_status) { nil }
  let(:email_ro_id) { nil }
  let(:email_recipient) { nil }
  let(:special_issues) { {} }
  let(:ep_code) { nil }
  let(:outgoing_reference_id) { nil }
  let(:user) { Generators::User.create(full_name: "Robert Smith") }
  let(:assigned_user) { nil }

  context "#should_invalidate?" do
    subject { establish_claim.should_invalidate? }
    it { is_expected.to be_falsey }

    context "appeal status is active" do
      let(:vacols_record) { { template: :remand_decided, status: "Active" } }
      it { is_expected.to be_truthy }
    end

    context "appeal decision date is nil" do
      let(:vacols_record) { { template: :remand_decided, decision_date: nil } }
      it { is_expected.to be_truthy }
    end

    context "appeal not found in VACOLS" do
      before do
        establish_claim
        Fakes::AppealRepository.clean!
      end

      it { is_expected.to be_truthy }
    end

    context "appeal decision type is nil" do
      let(:vacols_record) { { template: :full_grant_decided, issues: [] } }

      it { is_expected.to be_truthy }
    end
  end

  context "#prepare_with_decision!" do
    subject { establish_claim.prepare_with_decision! }

    let(:appeal) do
      Generators::Appeal.create(
        vacols_record: { template: :partial_grant_decided, decision_date: decision_date },
        documents: documents
      )
    end
    let(:decision_date) { 7.days.ago }
    let(:documents) { [] }
    let(:aasm_state) { :unprepared }

    context "if the task is invalid" do
      let(:decision_date) { nil }

      it "returns :invalid and invalidates the task" do
        is_expected.to eq(:invalid)
        expect(establish_claim.reload).to be_invalidated
      end
    end

    context "if the task's appeal has no decisions" do
      it { is_expected.to eq(:missing_decision) }
    end

    context "if the task's appeal has decisions" do
      let(:documents) { [Generators::Document.build(type: "BVA Decision", received_at: 7.days.ago)] }
      let(:filename) { appeal.decisions.first.file_name }

      context "if the task's appeal errors out on decision content load" do
        before do
          expect(VBMSService).to receive(:fetch_document_file).and_raise("VBMS 500")
          establish_claim.save!
        end

        it "propogates exception and does not prepare" do
          expect { subject }.to raise_error("VBMS 500")
          expect(establish_claim.reload).to_not be_unassigned
        end
      end

      context "if the task caches decision content successfully" do
        before do
          expect(VBMSService).to receive(:fetch_document_file) { "yay content!" }
        end

        it "prepares task and caches decision document content" do
          expect(subject).to eq(:success)

          expect(establish_claim.reload).to be_unassigned
          expect(S3Service.files[filename]).to eq("yay content!")
        end
      end
    end
  end

  context "#perform!" do
    # Stub the id of the end product being created
    before do
      Fakes::VBMSService.end_product_claim_id = "12345"
    end

    let(:claim_params) do
      {
        date: "03/03/2017",
        end_product_code: "172BVAG",
        end_product_label: "BVA Grant",
        end_product_modifier: claim_modifier,
        gulf_war_registry: false,
        suppress_acknowledgement_letter: false,
        station_of_jurisdiction: "499"
      }
    end

    let(:dispatched_to_station) { nil }
    let(:aasm_state) { :started }
    let(:claim_modifier) { "170" }

    subject { establish_claim.perform!(claim_params) }

    context "when claim is valid" do
      it "sets status to reviewed and saves appropriate records" do
        subject

        expect(establish_claim.reload.reviewed?).to be_truthy
        expect(establish_claim.outgoing_reference_id).to eq("12345")
        expect(appeal.reload.dispatched_to_station).to eq("499")
        expect(claim_establishment.reload.ep_code).to eq("172BVAG")
      end
    end

    context "when claim is invalid" do
      let(:claim_modifier) { nil }

      it "raises InvalidEndProductError and rolls back DB changes" do
        expect { subject }.to raise_error(EstablishClaim::InvalidEndProductError)
      end
    end

    context "when VBMS throws an error" do
      before do
        allow(VBMSService).to receive(:establish_claim!).and_raise(vbms_error)

        # Save objects to test DB rollback stuff
        establish_claim.save!
        appeal.save!
      end

      let(:vbms_error) { VBMS::HTTPError.new("500", "some error") }

      it "rolls back DB changes" do
        expect { subject }.to raise_error(VBMS::HTTPError)

        expect(establish_claim.reload).to_not be_reviewed
        expect(establish_claim.outgoing_reference_id).to be_nil
        expect(appeal.reload.dispatched_to_station).to be_nil
        expect(claim_establishment.reload.ep_code).to be_nil
      end

      context "EP already exists error" do
        let(:vbms_error) do
          VBMS::HTTPError.new("500", "<faultstring>Claim not established. " \
            "A duplicate claim for this EP code already exists in CorpDB. Please " \
            "use a different EP code modifier. GUID: 13fcd</faultstring>")
        end

        it "raises duplicate_ep VBMSError" do
          expect { subject }.to raise_error do |error|
            expect(error).to be_a(EstablishClaim::VBMSError)
            expect(error.error_code).to eq("duplicate_ep")
          end
        end
      end

      context "EP already exists in BGS error" do
        let(:vbms_error) do
          VBMS::HTTPError.new("500", "<faultstring>Claim not established." \
            " BGS code; PIF is already in use.</faultstring>")
        end

        it "raises duplicate_ep VBMSError" do
          expect { subject }.to raise_error do |error|
            expect(error).to be_a(EstablishClaim::VBMSError)
            expect(error.error_code).to eq("duplicate_ep")
          end
        end
      end

      context "Veteran missing SSN error" do
        let(:vbms_error) do
          VBMS::HTTPError.new("500", "<faultstring>The PersonalInfo " \
            "SSN must not be empty.</faultstring>")
        end

        it "raises missing_ssn VBMSError" do
          expect { subject }.to raise_error do |error|
            expect(error).to be_a(EstablishClaim::VBMSError)
            expect(error.error_code).to eq("missing_ssn")
          end
        end
      end
    end
  end

  context "#complete_with_review!" do
    subject { establish_claim.complete_with_review!(vacols_note: vacols_note) }

    let(:assigned_user) { user }
    let(:aasm_state) { :reviewed }
    let(:vacols_note) { "This is my note." }
    let(:vacols_update) { Fakes::AppealRepository.vacols_dispatch_update }

    it "completes the task" do
      subject
      expect(establish_claim.reload).to be_completed
    end

    it "updates VACOLS" do
      subject

      expect(vacols_update[:appeal]).to eq(appeal)
      expect(vacols_update[:vacols_note]).to eq("This is my note.")
    end

    it "updates the claim establishment" do
      establish_claim.appeal.outcoding_date = 17.days.ago
      subject

      expect(claim_establishment.reload.outcoding_date).to eq(17.days.ago)
    end

    context "when an ep was created" do
      let(:outgoing_reference_id) { "123YAY" }

      context "when appeal has special issues" do
        let(:special_issues) { { vamc: true } }

        it "completes the task as routed_to_ro" do
          subject
          expect(establish_claim.completion_status).to eq("routed_to_ro")
        end
      end

      context "when appeal doesn't have special issues" do
        it "completes the task as routed_to_arc" do
          subject
          expect(establish_claim.completion_status).to eq("routed_to_arc")
        end
      end
    end

    context "when an ep wasn't created" do
      it "completes the task as special_issue_vacols_routed" do
        subject
        expect(establish_claim.completion_status).to eq("special_issue_vacols_routed")
      end
    end

    context "when VACOLS raises exception" do
      before do
        allow(Appeal.repository).to receive(:update_vacols_after_dispatch!).and_raise("VACOLS Error")
      end

      it "rolls back DB changes" do
        # Save the objects so we can reload them
        establish_claim.save!
        claim_establishment.save!
        establish_claim.appeal.outcoding_date = 17.days.ago

        expect { subject }.to raise_error("VACOLS Error")

        expect(claim_establishment.reload.outcoding_date).to_not eq(17.days.ago)
        expect(establish_claim.reload).to_not be_completed
        expect(establish_claim.completion_status).to be_nil
      end
    end
  end

  context "#complete_with_email!" do
    subject { establish_claim.complete_with_email!(params) }

    let(:params) { { email_recipient: "shane@va.gov", email_ro_id: "RO22" } }
    let(:aasm_state) { :started }
    let(:assigned_user) { user }

    it "completes the task" do
      subject

      expect(establish_claim.reload).to be_completed
      expect(establish_claim.completion_status).to eq("special_issue_emailed")
    end

    it "updates the claim establishment" do
      establish_claim.appeal.outcoding_date = 17.days.ago

      subject

      expect(claim_establishment.reload).to have_attributes(
        outcoding_date: 17.days.ago,
        email_recipient: "shane@va.gov",
        email_ro_id: "RO22"
      )
    end

    context "when completing the task raises an exception" do
      before do
        allow(establish_claim).to receive(:complete!).and_raise("Error")
      end

      it "rolls back DB changes" do
        # Save the objects so we can reload them
        establish_claim.save!
        claim_establishment.save!

        expect { subject }.to raise_error("Error")

        expect(claim_establishment.reload.email_recipient).to_not eq("shane@va.gov")
        expect(establish_claim.reload).to_not be_completed
        expect(establish_claim.completion_status).to be_nil
      end
    end
  end

  context "#assign_existing_end_product!" do
    subject { establish_claim.assign_existing_end_product!(end_product_id) }
    let(:end_product_id) { "123YAY" }
    let(:aasm_state) { :started }
    let(:assigned_user) { user }

    it "completes the task and sets reference to end product" do
      subject

      expect(establish_claim.reload).to be_completed
      expect(establish_claim.completion_status).to eq("assigned_existing_ep")
      expect(establish_claim.outgoing_reference_id).to eq("123YAY")
    end

    it "updates VACOLS location" do
      subject

      expect(Fakes::AppealRepository.location_updated_for).to eq(appeal)
    end

    it "updates associated claim establishment" do
      establish_claim.appeal.outcoding_date = 23.days.ago
      subject

      expect(claim_establishment.reload.outcoding_date).to eq(23.days.ago)
    end

    context "when not started" do
      let(:aasm_state) { :completed }

      it "raises InvalidTransition" do
        expect { subject }.to raise_error(AASM::InvalidTransition)

        expect(Fakes::AppealRepository.location_updated_for).to_not eq(appeal)
      end
    end

    context "when VACOLS update raises error" do
      before do
        allow(Appeal.repository).to receive(:update_location_after_dispatch!).and_raise("VACOLS Error")
      end

      it "rolls back DB changes" do
        # Save the objects so we can reload them
        establish_claim.save!
        claim_establishment.save!
        establish_claim.appeal.outcoding_date = 17.days.ago

        expect { subject }.to raise_error("VACOLS Error")

        expect(claim_establishment.reload.outcoding_date).to_not eq(17.days.ago)
        expect(establish_claim.reload).to_not be_completed
        expect(establish_claim.completion_status).to be_nil
      end
    end
  end

  context "#actions_taken" do
    subject { establish_claim.actions_taken }

    context "when complete" do
      let(:aasm_state) { :completed }
      let(:completion_status) { :routed_to_arc }

      context "when appeal is a Remand or Partial Grant" do
        let(:vacols_record) { :remand_decided }

        it { is_expected.to include("Reviewed Remand decision") }
        it { is_expected.to include("VACOLS Updated: Changed Location to 98") }

        context "when an EP was established for ARC" do
          let(:ep_code) { "170RMDAMC" }
          let(:outgoing_reference_id) { "VBMS123" }
          let(:dispatched_to_station) { "397" }

          it { is_expected.to include("Established EP: 170RMDAMC - ARC-Remand for Station 397 - ARC") }
          it { is_expected.to_not include(/Added Diary Note/) }
        end

        context "when the appeal was routed to an RO in VACOLS" do
          let(:special_issues) { { vamc: true } }

          it { is_expected.to include("VACOLS Updated: Changed Location to 54") }
          it { is_expected.to include("VACOLS Updated: Added Diary Note on VAMC") }
        end
      end

      context "when appeal is a Full Grant" do
        let(:vacols_record) { :full_grant_decided }

        it { is_expected.to include("Reviewed Full Grant decision") }
        it { is_expected.to_not include(/VACOLS Updated/) }

        context "when an EP was established" do
          let(:outgoing_reference_id) { "VBMS123" }
          let(:ep_code) { "172BVAG" }
          let(:dispatched_to_station) { "351" }

          it { is_expected.to include("Established EP: 172BVAG - BVA Grant for Station 351 - Muskogee") }

          context "when a VBMS Note was added to the EP" do
            let(:special_issues) { { vamc: true, radiation: true } }

            it { is_expected.to include("Added VBMS Note on Radiation; VAMC") }
          end
        end

        context "when processed via email" do
          let(:completion_status) { :special_issue_emailed }
          let(:email_ro_id) { "RO84" }
          let(:email_recipient) { "appealcoach@va.gov" }
          let(:special_issues) { { radiation: true } }

          it do
            is_expected
              .to include("Sent email to: appealcoach@va.gov in Philadelphia COWAC, PA - re: Radiation Issue(s)")
          end
        end

        context "when processed outside of caseflow" do
          let(:completion_status) { :special_issue_not_emailed }

          it { is_expected.to include("Processed case outside of Caseflow") }
        end
      end
    end

    context "when not complete" do
      let(:aasm_status) { :unassigned }

      it { is_expected.to eq([]) }
    end
  end

  context "#completion_status_text" do
    subject { establish_claim.completion_status_text }

    context "when completion status is routed_to_ro" do
      let(:completion_status) { :routed_to_ro }
      let(:dispatched_to_station) { "344" }

      it { is_expected.to eq("EP created for RO Station 344 - Los Angeles") }
    end

    context "when completion status is special_issue_emailed" do
      let(:completion_status) { :special_issue_emailed }
      let(:special_issues) { { vamc: true, radiation: true } }

      it { is_expected.to eq("Emailed - Radiation; VAMC Issue(s)") }
    end

    context "when completion_status doesn't need additional information" do
      let(:completion_status) { :routed_to_arc }

      it "uses value from Task#completion_status_text" do
        is_expected.to eq("EP created for ARC - 397")
      end
    end
  end

  context "#past_weeks" do
    before do
      establish_claim.update(completed_at: Time.zone.today - 2.weeks)
    end

    it "returns tasks completed in the specified range" do
      expect(EstablishClaim.past_weeks(2).count).to eql(1)
    end

    it "returns no tasks outside the specified range" do
      expect(EstablishClaim.past_weeks(1).count).to eql(0)
    end
  end
end
