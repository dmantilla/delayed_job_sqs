module Delayed
  module MessageSending
    def send_later(sqs_queue, method, *args)
      delayed_method = Delayed::PerformableMethod.new(self, method.to_sym, args)

      # If an actual queue was provided and the message size is less than 8K, it's appended to the queue
      if sqs_queue.is_a?(RightAws::SqsGen2::Queue) && delayed_method.to_yaml.size < 8192
        Delayed::Job.enqueue(sqs_queue, delayed_method)
      else
        # else the method is executed, no queueing
        self.send method.to_sym, *args #.map{|a| a}
      end
    end

    module ClassMethods
      def handle_asynchronously(method)
        without_name = "#{method}_without_send_later"
        define_method("#{method}_with_send_later") do |*args|
          send_later(without_name, *args)
        end
        alias_method_chain method, :send_later
      end
    end
  end
end