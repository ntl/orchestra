class NodeTest < Minitest::Test
  def test_inspect
    node = Orchestra::Node.new Examples::FizzBuzz, "Examples::FizzBuzz", {}

    assert_equal(
      "#<Orchestra::Node dependencies=[:array, :fizzbuzz, :io, :up_to], input={}, name=\"Examples::FizzBuzz\", optional_dependencies=[], provisions=[:array, :fizzbuzz, :print], required_dependencies=[:io, :up_to]>",
      node.inspect,
    )
  end
end
