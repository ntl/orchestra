class UtilTest < Minitest::Test
  def test_snake_casing
    assert_equal "foo/bar", Orchestra::Util.to_snake_case("Foo::Bar")
    assert_equal "foo_bar", Orchestra::Util.to_snake_case("FOOBar")
  end

  def test_recursive_symbolizing
    expected_hsh = {
      foo: [{
        bar: { baz: 'qux' },
      },{
        ping: ['pong'],
      }],
    }

    actual_hsh = Orchestra::Util.recursively_symbolize JSON.load JSON.dump expected_hsh

    assert_equal expected_hsh, actual_hsh
  end
end
