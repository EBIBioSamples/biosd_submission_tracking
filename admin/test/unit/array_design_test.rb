require File.dirname(__FILE__) + '/../test_helper'

class ArrayDesignTest < Test::Unit::TestCase
  fixtures :array_designs

  def setup
    @array_design = ArrayDesign.find(1)
  end

  # Replace this with your real tests.
  def test_truth
    assert_kind_of ArrayDesign, @array_design
  end
end
