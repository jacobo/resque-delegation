Resque::Plugins::Loner::Helpers.class_eval do

  def self.unique_job_queue_key(queue, item)
    klass = constantize(item[:class] || item["class"])
    job_key =
      if is_resque_delegation?(klass)
        (item[:args] || item["args"]).first #meta_id
      else
        klass.redis_key(item)
      end
    "loners:queue:#{queue}:job:#{job_key}"
  end

  def self.item_is_a_unique_job?(item)
    begin
      klass = constantize(item[:class] || item["class"])
      klass.ancestors.include?(::Resque::Plugins::Loner::UniqueJob) || is_resque_delegation?(klass)
    rescue
      false # Resque testsuite also submits strings as job classes while Resque.enqueue'ing,
    end     # so resque-loner should not start throwing up when that happens.
  end

  private

  def self.is_resque_delegation?(klass)
    class << klass
      self.included_modules.include?(Resque::Plugins::Delegation)
    end
  end

end