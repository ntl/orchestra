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

  def handle_operation_entered operation, input
    return if embedded?
    @steps = Hash.new do |hsh, key| hsh[key] = {} end
    @store.update(
      :input => input,
      :movements => @steps,
      :operation_name => operation.name,
      :service_calls => [],
    )
    @embedded = true
  end

  def handle_operation_exited operation, output
    @store[:output] = output
    @embedded = false
  end

  def handle_step_entered step, input
    @steps[step.name][:input] = input
  end

  def handle_step_exited step, output
    @steps[step.name][:output] = output
  end

  def handle_error_raised error
    @store[:error] = error
  end

  def handle_service_accessed service_name, record
    @store[:service_calls].<< record.merge :service => service_name
  end
end
