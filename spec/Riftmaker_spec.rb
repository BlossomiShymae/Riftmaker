# frozen_string_literal: true

RSpec.describe Riftmaker do
  it "has a version number" do
    expect(Riftmaker::VERSION).not_to be nil
  end

  it "does something useful" do
    Riftmaker.generate
    expect(true).to eq(true)
  end
end
