require File.dirname(__FILE__) + '/../test_helper'

class OrganismTest < Test::Unit::TestCase
  fixtures :taxons, :organisms

  def setup
    @organism = Organism.find(1)
  end

  # Replace this with your real tests.
  def test_truth
    assert_kind_of Organism,  @organism
  end
end
