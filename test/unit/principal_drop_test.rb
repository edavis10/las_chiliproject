require File.expand_path('../../test_helper', __FILE__)

class PrincipalDropTest < ActiveSupport::TestCase
  def setup
    @principal = Principal.generate!
    @drop = PrincipalDrop.new(@principal)
  end

  context "#name" do
    should "return the name" do
      assert_equal @principal.name, @drop.name
    end
  end
end
