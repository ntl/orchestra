class TelemetryRecorder
  def initialize store
    @store = store
    @current_operation = nil
    @embedded = false
  end

  def update message, *payload
    method = "handle_#{message}"
    public_send method, *payload if respond_to? method
  end

  def embedded?
    @embedded
  end

  def handle_performance_started operation_name, input
    return if embedded?
    @nodes = Hash.new do |hsh, key| hsh[key] = {} end
    @store.update(
      :input => input,
      :movements => @nodes,
      :performance_name => operation_name,
      :service_calls => [],
    )
  end

  def handle_performance_finished operation_name, output
    return if embedded?
    @store[:output] = output
  end

  def handle_node_entered name, input
    @nodes[name][:input] = input
  end

  def handle_node_exited name, output
    @nodes[name][:output] = output
  end

  def handle_operation_entered operation
    @embedded = true
  end

  def handle_operation_exited operation
    @embedded = false
  end

  def handle_error_raised error
    @store[:error] = error
  end

  def handle_service_accessed service_name, record
    @store[:service_calls].<< record.merge :service => service_name
  end
end
