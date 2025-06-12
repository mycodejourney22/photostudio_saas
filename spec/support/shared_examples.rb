# spec/support/shared_examples.rb
RSpec.shared_examples "requires authentication" do
  it "redirects to sign in page" do
    subject
    expect(response).to redirect_to(new_user_session_path)
  end
end

RSpec.shared_examples "requires tenant" do
  it "redirects to main site without tenant" do
    subject
    expect(response).to redirect_to("http://localhost:3000")
  end
end

RSpec.shared_examples "validates presence of" do |field|
  it "validates presence of #{field}" do
    subject.send("#{field}=", nil)
    expect(subject).not_to be_valid
    expect(subject.errors[field]).to include("can't be blank")
  end
end
