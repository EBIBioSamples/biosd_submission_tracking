require File.dirname(__FILE__) + '/../test_helper'

class TaxonTest < Test::Unit::TestCase
  fixtures :taxons

  def setup
    @taxon = Taxon.find(1)
  end

  # Replace this with your real tests.
  def test_truth
    assert_kind_of Taxon,  @taxon
  end
end
