class NodeTest < Minitest::Test
  def test_performing_a_node
    node = build_simple_node

    assert_equal(
      { :bar => 4 },
      node.perform(:foo => 2, :bar => 2),
    )
  end

  def test_providing_a_single_hash
    node = Orchestra::Node::InlineNode.new(
      :dependencies => [:foo],
      :provides => [:bar],
      :perform_block => lambda { { :bar => (foo * 2) } },
    )

    assert_equal(
      { :bar => 4 },
      node.perform(:foo => 2),
    )
  end

  def test_providing_a_single_hash_that_is_not_the_output
    node = Orchestra::Node::InlineNode.new(
      :dependencies => [:foo],
      :provides => [:bar],
      :perform_block => lambda { { :baz => (foo * 2) } },
    )

    assert_equal(
      { :bar => { :baz => 4 } },
      node.perform(:foo => 2),
    )
  end

  def test_performing_a_collection_node
    node = Orchestra::Node::InlineNode.new(
      :dependencies => [:foo],
      :provides => [:bar],
      :perform_block => lambda { |e| e * 2 },
      :collection => :foo,
    )

    assert_equal(
      { :bar => [2, 4, 6, 8] },
      node.perform(:foo => [1, 2, 3, 4]),
    )
  end

  def test_defaulting
    node = build_simple_node

    assert_equal(
      { :bar => 8 },
      node.perform(:foo => 2),
    )
  end

  def test_introspecting_dependencies
    node = build_simple_node

    assert_equal [:foo, :bar], node.dependencies
  end

  def test_introspecting_mandatory_dependencies
    node = build_simple_node

    assert_equal [:foo], node.required_dependencies
  end

  def test_node_fails_to_supply_provisions
    node = Orchestra::Node::InlineNode.new(
      :provides => [:foo, :bar, :baz],
      :perform_block => lambda { nil },
    )

    error = assert_raises Orchestra::MissingProvisionError do node.perform end

    assert_equal(
      "failed to supply output: :foo, :bar and :baz",
      error.message,
    )
  end

  def test_cannot_return_nil
    node = Orchestra::Node::InlineNode.new(
      :provides => [:foo],
      :perform_block => lambda do nil end
    )

    error = assert_raises Orchestra::MissingProvisionError do node.perform end

    assert_equal(
      "failed to supply output: :foo",
      error.message,
    )
  end

  def test_node_provides_extra_provisions
    node = Orchestra::Node::InlineNode.new(
      :provides => [:foo],
      :perform_block => lambda do { :foo => :bar, :baz => :qux } end,
    )

    assert_equal(
      { :foo => :bar },
      node.perform,
    )
  end

  private

  def build_simple_node
     Orchestra::Node::InlineNode.new(
      :defaults => { :bar => lambda { 4 } },
      :dependencies => [:foo, :bar],
      :provides => [:bar],
      :perform_block => lambda { foo * bar },
    )
  end
end
