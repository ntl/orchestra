class StepTest < Minitest::Test
  def test_invoking_a_step
    step = build_simple_step

    assert_equal(
      { :bar => 4 },
      step.perform(:foo => 2, :bar => 2),
    )
  end

  def test_providing_a_single_hash
    step = Orchestra::Step::InlineStep.new(
      :dependencies => [:foo],
      :provides => [:bar],
      :perform_block => lambda { { :bar => (foo * 2) } },
    )

    assert_equal(
      { :bar => 4 },
      step.perform(:foo => 2),
    )
  end

  def test_providing_a_single_hash_that_is_not_the_output
    step = Orchestra::Step::InlineStep.new(
      :dependencies => [:foo],
      :provides => [:bar],
      :perform_block => lambda { { :baz => (foo * 2) } },
    )

    assert_equal(
      { :bar => { :baz => 4 } },
      step.perform(:foo => 2),
    )
  end

  def test_invoking_a_collection_step
    step = Orchestra::Step::InlineStep.new(
      :dependencies => [:foo],
      :provides => [:bar],
      :perform_block => lambda { |e| e * 2 },
      :collection => :foo,
    )

    assert_equal(
      { :bar => [2, 4, 6, 8] },
      step.perform(:foo => [1, 2, 3, 4]),
    )
  end

  def test_defaulting
    step = build_simple_step

    assert_equal(
      { :bar => 8 },
      step.perform(:foo => 2),
    )
  end

  def test_introspecting_dependencies
    step = build_simple_step

    assert_equal [:foo, :bar], step.dependencies
  end

  def test_introspecting_mandatory_dependencies
    step = build_simple_step

    assert_equal [:foo], step.required_dependencies
  end

  def test_step_fails_to_supply_provisions
    step = Orchestra::Step::InlineStep.new(
      :provides => [:foo, :bar, :baz],
      :perform_block => lambda { nil },
    )

    error = assert_raises Orchestra::MissingProvisionError do step.perform end

    assert_equal(
      "failed to supply output: :foo, :bar and :baz",
      error.message,
    )
  end

  def test_cannot_return_nil
    step = Orchestra::Step::InlineStep.new(
      :provides => [:foo],
      :perform_block => lambda do nil end
    )

    error = assert_raises Orchestra::MissingProvisionError do step.perform end

    assert_equal(
      "failed to supply output: :foo",
      error.message,
    )
  end

  def test_step_provides_extra_provisions
    step = Orchestra::Step::InlineStep.new(
      :provides => [:foo],
      :perform_block => lambda do { :foo => :bar, :baz => :qux } end,
    )

    assert_equal(
      { :foo => :bar },
      step.perform,
    )
  end

  private

  def build_simple_step
     Orchestra::Step::InlineStep.new(
      :defaults => { :bar => lambda { 4 } },
      :dependencies => [:foo, :bar],
      :provides => [:bar],
      :perform_block => lambda { foo * bar },
    )
  end
end
