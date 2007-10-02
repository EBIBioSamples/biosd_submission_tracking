require File.dirname(__FILE__) + '/../test_helper'

class DesignTest < Test::Unit::TestCase
  fixtures :designs

  # Replace this with your real tests.
  def test_truth
    assert_kind_of Design, designs(:first)
  end
end
