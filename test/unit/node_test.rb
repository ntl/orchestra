class NodeTest < Minitest::Test
  def test_inspect
    node = Orchestra::Recording::Node.new(
      Examples::FizzBuzz,
      "Examples::FizzBuzz",
      {},
    )

    assert_equal(
      "#<Orchestra::Node dependencies=[:array, :fizzbuzz, :stdout, :up_to], input={}, name=\"Examples::FizzBuzz\", optional_dependencies=[], provisions=[:__finally__, :array, :fizzbuzz], required_dependencies=[:stdout, :up_to]>",
      node.inspect,
    )
  end
end
