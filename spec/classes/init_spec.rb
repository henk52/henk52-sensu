require 'spec_helper'
describe 'sensu' do

  context 'with defaults for all parameters' do
    it { should contain_class('sensu') }
  end
end
